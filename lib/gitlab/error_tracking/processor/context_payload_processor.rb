# frozen_string_literal: true

module Gitlab
  module ErrorTracking
    module Processor
      class ContextPayloadProcessor < ::Raven::Processor
        # This processor is added to inject application context into Sentry
        # events generated by Sentry built-in integrations. When the
        # integrations are re-implemented and use Gitlab::ErrorTracking, this
        # processor should be removed.
        def process(payload)
          context_payload = Gitlab::ErrorTracking::ContextPayloadGenerator.generate(nil, {})
          payload.deep_merge!(context_payload)
        end
      end
    end
  end
end