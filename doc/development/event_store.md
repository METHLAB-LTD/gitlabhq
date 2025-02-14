---
stage: none
group: unassigned
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# GitLab EventStore

## Background

The monolithic GitLab project is becoming larger and more domains are being defined.
As a result, these domains are becoming entangled with each others due to temporal coupling.

An emblematic example is the [`PostReceive`](https://gitlab.com/gitlab-org/gitlab/blob/master/app/workers/post_receive.rb)
worker where a lot happens across multiple domains. If a new behavior reacts to
a new commit being pushed, then we add code somewhere in `PostReceive` or its sub-components
(`Git::ProcessRefChangesService`, for example).

This type of architecture:

- Is a violation of the Single Responsibility Principle.
- Increases the risk of adding code to a codebase you are not familiar with.
  There may be nuances you don't know about which may introduce bugs or a performance degradation.
- Violates domain boundaries. Inside a specific namespace (for example `Git::`) we suddenly see
  classes from other domains chiming in (like `Ci::` or `MergeRequests::`).

## What is EventStore?

`Gitlab:EventStore` is a basic pub-sub system built on top of the existing Sidekiq workers and observability we have today.
We use this system to apply an event-driven approach when modeling a domain while keeping coupling
to a minimum.

This essentially leaves the existing Sidekiq workers as-is to perform asynchronous work but inverts
the dependency.

### EventStore example

When a CI pipeline is created we update the head pipeline for any merge request matching the
pipeline's `ref`. The merge request can then display the status of the latest pipeline.

#### Without the EventStore

We change `Ci::CreatePipelineService` and add logic (like an `if` statement) to check if the
pipeline is created. Then we schedule a worker to run some side-effects for the `MergeRequests::` domain.

This style violates the [Open-Closed Principle](https://en.wikipedia.org/wiki/Open%E2%80%93closed_principle)
and unnecessarily add side-effects logic from other domains, increasing coupling:

```mermaid
graph LR
  subgraph ci[CI]
    cp[CreatePipelineService]
  end

  subgraph mr[MergeRequests]
    upw[UpdateHeadPipelineWorker]
  end

  subgraph no[Namespaces::Onboarding]
    pow[PipelinesOnboardedWorker]
  end

  cp -- perform_async --> upw
  cp -- perform_async --> pow
```

#### With the EventStore

`Ci::CreatePipelineService` publishes an event `Ci::PipelineCreatedEvent` and its responsibility stops here.

The `MergeRequests::` domain can subscribe to this event with a worker `MergeRequests::UpdateHeadPipelineWorker`, so:

- Side-effects are scheduled asynchronously and don't impact the main business transaction that
  emits the domain event.
- More side-effects can be added without modifying the main business transaction.
- We can clearly see what domains are involved and their ownership.
- We can identify what events occur in the system because they are explicitly declared.

With `Gitlab::EventStore` there is still coupling between the subscriber (Sidekiq worker) and the schema of the domain event.
This level of coupling is much smaller than having the main transaction (`Ci::CreatePipelineService`) coupled to:

- multiple subscribers.
- multiple ways of invoking subscribers (including conditional invocations).
- multiple ways of passing parameters.

```mermaid
graph LR
  subgraph ci[CI]
    cp[CreatePipelineService]
    cp -- publish --> e[PipelineCreateEvent]
  end

  subgraph mr[MergeRequests]
    upw[UpdateHeadPipelineWorker]
  end

  subgraph no[Namespaces::Onboarding]
    pow[PipelinesOnboardedWorker]
  end

  upw -. subscribe .-> e
  pow -. subscribe .-> e
```

Each subscriber, being itself a Sidekiq worker, can specify any attributes that are related
to the type of work they are responsible for. For example, one subscriber could define
`urgency: high` while another one less critical could set `urgency: low`.

The EventStore is only an abstraction that allows us to have Dependency Inversion. This helps
separating a business transaction from side-effects (often executed in other domains).

When an event is published, the EventStore calls `perform_async` on each subscribed worker,
passing in the event information as arguments. This essentially schedules a Sidekiq job on each
subscriber's queue.

This means that nothing else changes with regards to how subscribers work, as they are just
Sidekiq workers. For example: if a worker (subscriber) fails to execute a job, the job is put
back into Sidekiq to be retried.

## EventStore advantages

- Subscribers (Sidekiq workers) can be set to run quicker by changing the worker weight
  if the side-effect is critical.
- Automatically enforce the fact that side-effects run asynchronously.
  This makes it safe for other domains to subscribe to events without affecting the performance of the
  main business transaction.

## Define an event

An `Event` object represents a domain event that occurred in a bounded context.
Notify other bounded contexts about something
that happened by publishing events, so that they can react to it.

Define new event classes under `app/events/<namespace>/` with a name representing something that happened in the past:

```ruby
class Ci::PipelineCreatedEvent < Gitlab::EventStore::Event
  def schema
    {
      'type' => 'object',
      'required' => ['pipeline_id'],
      'properties' => {
        'pipeline_id' => { 'type' => 'integer' },
        'ref' => { 'type' => 'string' }
      }
    }
  end
end
```

The schema is validated immediately when we initialize the event object so we can ensure that
publishers follow the contract with the subscribers.

We recommend using optional properties as much as possible, which require fewer rollouts for schema changes.
However, `required` properties could be used for unique identifiers of the event's subject. For example:

- `pipeline_id` can be a required property for a `Ci::PipelineCreatedEvent`.
- `project_id` can be a required property for a `Projects::ProjectDeletedEvent`.

Publish only properties that are needed by the subscribers without tailoring the payload to specific subscribers.
The payload should fully represent the event and not contain loosely related properties. For example:

```ruby
Ci::PipelineCreatedEvent.new(data: {
  pipeline_id: pipeline.id,
  # unless all subscribers need merge request IDs,
  # this is data that can be fetched by the subscriber.
  merge_request_ids: pipeline.all_merge_requests.pluck(:id)
})
```

Publishing events with more properties provides the subscribers with the data
they need in the first place. Otherwise subscribers have to fetch the additional data from the database.
However, this can lead to continuous changes to the schema and possibly adding properties that may not
represent the single source of truth.
It's best to use this technique as a performance optimization. For example: when an event has many
subscribers that all fetch the same data again from the database.

### Update the schema

Changes to the schema require multiple rollouts. While the new version is being deployed:

- Existing publishers can publish events using the old version.
- Existing subscribers can consume events using the old version.
- Events get persisted in the Sidekiq queue as job arguments, so we could have 2 versions of the schema during deployments.

As changing the schema ultimately impacts the Sidekiq arguments, please refer to our
[Sidekiq style guide](sidekiq_style_guide.md#changing-the-arguments-for-a-worker) with regards to multiple rollouts.

#### Add properties

1. Rollout 1:
   - Add new properties as optional (not `required`).
   - Update the subscriber so it can consume events with and without the new properties.
1. Rollout 2:
   - Change the publisher to provide the new property
1. Rollout 3: (if the property should be `required`):
   - Change the schema and the subscriber code to always expect it.

#### Remove properties

1. Rollout 1:
   - If the property is `required`, make it optional.
   - Update the subscriber so it does not always expect the property.
1. Rollout 2:
   - Remove the property from the event publishing.
   - Remove the code from the subscriber that processes the property.

#### Other changes

For other changes, like renaming a property, use the same steps:

1. Remove the old property
1. Add the new property

## Publish an event

To publish the event from the [previous example](#define-an-event):

```ruby
Gitlab::EventStore.publish(
  Ci::PipelineCreatedEvent.new(data: { pipeline_id: pipeline.id })
)
```

## Create a subscriber

A subscriber is a Sidekiq worker that includes the `Gitlab::EventStore::Subscriber` module.
This module takes care of the `perform` method and provides a better abstraction to handle
the event safely via the `handle_event` method. For example:

```ruby
module MergeRequests
  class UpdateHeadPipelineWorker
    include ApplicationWorker
    include Gitlab::EventStore::Subscriber

    def handle_event(event)
      Ci::Pipeline.find_by_id(event.data[:pipeline_id]).try do |pipeline|
        # ...
      end
    end
  end
end
```

## Register the subscriber to the event

To subscribe the worker to a specific event in `lib/gitlab/event_store.rb`,
add a line like this to the `Gitlab::EventStore.configure!` method:

```ruby
module Gitlab
  module EventStore
    def self.configure!
      Store.new.tap do |store|
        # ...

        store.subscribe ::MergeRequests::UpdateHeadPipelineWorker, to: ::Ci::PipelineCreatedEvent

        # ...
      end
    end
  end
end
```

Subscriptions are stored in memory when the Rails app is loaded and they are immediately frozen.
It's not possible to modify subscriptions at runtime.

### Conditional dispatch of events

A subscription can specify a condition when to accept an event:

```ruby
store.subscribe ::MergeRequests::UpdateHeadPipelineWorker,
  to: ::Ci::PipelineCreatedEvent, 
  if: -> (event) { event.data[:merge_request_id].present? }
```

This tells the event store to dispatch `Ci::PipelineCreatedEvent`s to the subscriber if
the condition is met.

This technique can avoid scheduling Sidekiq jobs if the subscriber is interested in a
small subset of events.

WARNING:
When using conditional dispatch it must contain only cheap conditions because they are 
executed synchronously every time the given event is published.

For complex conditions it's best to subscribe to all the events and then handle the logic
in the `handle_event` method of the subscriber worker.
