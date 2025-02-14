# frozen_string_literal: true

module QA
  module Page
    module Component
      module InviteMembersModal
        extend QA::Page::PageConcern

        def self.included(base)
          super

          base.view 'app/assets/javascripts/invite_members/components/invite_members_modal.vue' do
            element :invite_button
            element :access_level_dropdown
            element :invite_members_modal_content
          end

          base.view 'app/assets/javascripts/invite_members/components/group_select.vue' do
            element :group_select_dropdown_search_field
          end

          base.view 'app/assets/javascripts/invite_members/components/members_token_select.vue' do
            element :members_token_select_input
          end

          base.view 'app/assets/javascripts/invite_members/components/invite_group_trigger.vue' do
            element :invite_a_group_button
          end

          base.view 'app/assets/javascripts/invite_members/components/invite_members_trigger.vue' do
            element :invite_members_button
          end
        end

        def open_invite_members_modal
          click_element :invite_members_button
        end

        def open_invite_group_modal
          click_element :invite_a_group_button
        end

        def add_member(username, access_level = 'Developer')
          open_invite_members_modal

          within_element(:invite_members_modal_content) do
            fill_element :members_token_select_input, username
            Support::WaitForRequests.wait_for_requests
            click_button username
            set_access_level(access_level)
          end

          send_invite
        end

        def invite_group(group_name, access_level = 'Guest')
          open_invite_group_modal

          within_element(:invite_members_modal_content) do
            click_button 'Select a group'

            # Helps stabilize race condition with concurrent group API calls while searching
            # TODO: Replace with `fill_element :group_select_dropdown_search_field, group_name` when this bug is resolved: https://gitlab.com/gitlab-org/gitlab/-/issues/349379
            send_keys_to_element(:group_select_dropdown_search_field, group_name)

            Support::WaitForRequests.wait_for_requests
            click_button group_name
            set_access_level(access_level)
          end

          send_invite
        end

        private

        def set_access_level(access_level)
          # Guest option is selected by default, skipping these steps if desired option is 'Guest'
          unless access_level == 'Guest'
            click_element :access_level_dropdown
            click_button access_level
          end
        end

        def send_invite
          click_element :invite_button
          Support::WaitForRequests.wait_for_requests
          page.refresh
        end
      end
    end
  end
end
