# frozen_string_literal: true

module API
  # Deployments RESTful API endpoints
  class Deployments < ::API::Base
    include PaginationParams

    before { authenticate! }

    feature_category :continuous_delivery

    params do
      requires :id, type: String, desc: 'The project ID'
    end
    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Get all deployments of the project' do
        detail 'This feature was introduced in GitLab 8.11.'
        success Entities::Deployment
      end
      params do
        use :pagination
        optional :order_by, type: String, values: DeploymentsFinder::ALLOWED_SORT_VALUES, default: DeploymentsFinder::DEFAULT_SORT_VALUE, desc: 'Return deployments ordered by specified value'
        optional :sort, type: String, values: DeploymentsFinder::ALLOWED_SORT_DIRECTIONS, default: DeploymentsFinder::DEFAULT_SORT_DIRECTION, desc: 'Sort by asc (ascending) or desc (descending)'
        optional :updated_after, type: DateTime, desc: 'Return deployments updated after the specified date'
        optional :updated_before, type: DateTime, desc: 'Return deployments updated before the specified date'
        optional :environment,
          type: String,
          desc: 'The name of the environment to filter deployments by'

        optional :status,
          type: String,
          values: Deployment.statuses.keys,
          desc: 'The status to filter deployments by'
      end

      get ':id/deployments' do
        authorize! :read_deployment, user_project

        deployments =
          DeploymentsFinder.new(params.merge(project: user_project))
            .execute.with_api_entity_associations

        present paginate(deployments), with: Entities::Deployment
      rescue DeploymentsFinder::InefficientQueryError => e
        bad_request!(e.message)
      end

      desc 'Gets a specific deployment' do
        detail 'This feature was introduced in GitLab 8.11.'
        success Entities::Deployment
      end
      params do
        requires :deployment_id, type: Integer, desc: 'The deployment ID'
      end
      get ':id/deployments/:deployment_id' do
        authorize! :read_deployment, user_project

        deployment = user_project.deployments.find(params[:deployment_id])

        present deployment, with: Entities::Deployment
      end

      desc 'Creates a new deployment' do
        detail 'This feature was introduced in GitLab 12.4'
        success Entities::Deployment
      end
      params do
        requires :environment,
          type: String,
          desc: 'The name of the environment to deploy to'

        requires :sha,
          type: String,
          desc: 'The SHA of the commit that was deployed'

        requires :ref,
          type: String,
          desc: 'The name of the branch or tag that was deployed'

        requires :tag,
          type: Boolean,
          desc: 'A boolean indicating if the deployment ran for a tag'

        requires :status,
          type: String,
          desc: 'The status of the deployment',
          values: %w[running success failed canceled]
      end
      post ':id/deployments' do
        authorize!(:create_deployment, user_project)
        authorize!(:create_environment, user_project)

        environment = user_project
          .environments
          .find_or_create_by_name(params[:environment])

        unless environment.persisted?
          render_validation_error!(deployment)
        end

        authorize!(:create_deployment, environment)

        service = ::Deployments::CreateService
          .new(environment, current_user, declared_params)

        deployment = service.execute

        if deployment.persisted?
          present(deployment, with: Entities::Deployment, current_user: current_user)
        else
          render_validation_error!(deployment)
        end
      end

      desc 'Updates an existing deployment' do
        detail 'This feature was introduced in GitLab 12.4'
        success Entities::Deployment
      end
      params do
        requires :status,
          type: String,
          desc: 'The new status of the deployment',
          values: %w[running success failed canceled]
      end
      put ':id/deployments/:deployment_id' do
        authorize!(:read_deployment, user_project)

        deployment = user_project.deployments.find(params[:deployment_id])

        authorize!(:update_deployment, deployment)

        if deployment.deployable
          forbidden!('Deployments created using GitLab CI can not be updated using the API')
        end

        service = ::Deployments::UpdateService.new(deployment, declared_params)

        if service.execute
          present(deployment, with: Entities::Deployment, current_user: current_user)
        else
          render_validation_error!(deployment)
        end
      end

      helpers Helpers::MergeRequestsHelpers

      desc 'Get all merge requests of a deployment' do
        detail 'This feature was introduced in GitLab 12.7.'
        success Entities::MergeRequestBasic
      end
      params do
        use :pagination
        requires :deployment_id, type: Integer, desc: 'The deployment ID'
        use :merge_requests_base_params
      end

      get ':id/deployments/:deployment_id/merge_requests' do
        authorize! :read_deployment, user_project

        mr_params = declared_params.merge(deployment_id: params[:deployment_id])
        merge_requests = MergeRequestsFinder.new(current_user, mr_params).execute

        present paginate(merge_requests), { with: Entities::MergeRequestBasic, current_user: current_user }
      end
    end
  end
end

API::Deployments.prepend_mod
