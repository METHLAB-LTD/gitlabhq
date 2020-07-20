# frozen_string_literal: true

module QA
  module Page
    module Component
      module Snippet
        extend QA::Page::PageConcern

        def self.included(base)
          super

          base.view 'app/assets/javascripts/snippets/components/snippet_title.vue' do
            element :snippet_title_content, required: true
          end

          base.view 'app/assets/javascripts/snippets/components/snippet_description_view.vue' do
            element :snippet_description_content
          end

          base.view 'app/assets/javascripts/snippets/components/snippet_header.vue' do
            element :snippet_container
          end

          base.view 'app/assets/javascripts/blob/components/blob_header_filepath.vue' do
            element :file_title_content
          end

          base.view 'app/assets/javascripts/vue_shared/components/blob_viewers/simple_viewer.vue' do
            element :file_content
          end

          base.view 'app/assets/javascripts/blob/components/blob_content.vue' do
            element :file_content
          end

          base.view 'app/assets/javascripts/snippets/components/snippet_header.vue' do
            element :snippet_action_button
            element :delete_snippet_button
          end

          base.view 'app/assets/javascripts/snippets/components/snippet_blob_view.vue' do
            element :clone_button
          end

          base.view 'app/assets/javascripts/vue_shared/components/clone_dropdown.vue' do
            element :copy_http_url_button
            element :copy_ssh_url_button
          end

          base.view 'app/views/shared/notes/_comment_button.html.haml' do
            element :comment_button
          end

          base.view 'app/views/shared/notes/_form.html.haml' do
            element :note_field
          end

          base.view 'app/views/snippets/notes/_actions.html.haml' do
            element :edit_comment_button
          end

          base.view 'app/views/shared/notes/_edit_form.html.haml' do
            element :edit_note_field
            element :save_comment_button
          end

          base.view 'app/views/shared/notes/_note.html.haml' do
            element :note_content
            element :note_author_content
          end

          base.view 'app/views/projects/notes/_more_actions_dropdown.html.haml' do
            element :more_actions_dropdown
            element :delete_comment_button
          end
        end

        def has_snippet_title?(snippet_title)
          has_element? :snippet_title_content, text: snippet_title
        end

        def has_snippet_description?(snippet_description)
          has_element? :snippet_description_content, text: snippet_description
        end

        def has_no_snippet_description?
          has_no_element?(:snippet_description_field)
        end

        def has_visibility_type?(visibility_type)
          within_element(:snippet_container) do
            has_text?(visibility_type)
          end
        end

        def has_file_name?(file_name)
          within_element(:file_title_content) do
            has_text?(file_name)
          end
        end

        def has_file_content?(file_content)
          finished_loading?
          within_element(:file_content) do
            has_text?(file_content)
          end
        end

        def click_edit_button
          finished_loading?
          click_element(:snippet_action_button, action: 'Edit')
        end

        def click_delete_button
          finished_loading?
          click_element(:snippet_action_button, action: 'Delete')
          click_element(:delete_snippet_button)
          # wait for the page to reload after deletion
          wait_until(reload: false) do
            has_no_element?(:delete_snippet_button) &&
                has_no_element?(:snippet_action_button, action: 'Delete')
          end
        end

        def get_repository_uri_http
          finished_loading?
          click_element(:clone_button)
          Git::Location.new(find_element(:copy_http_url_button)['data-clipboard-text']).uri.to_s
        end

        def get_repository_uri_ssh
          finished_loading?
          click_element(:clone_button)
          Git::Location.new(find_element(:copy_ssh_url_button)['data-clipboard-text']).uri.to_s
        end

        def add_comment(comment)
          finished_loading?
          fill_element(:note_field, comment)
          click_element(:comment_button)
        end

        def has_comment_author?(author_username)
          finished_loading?
          within_element(:note_author_content) do
            has_text?('@' + author_username)
          end
        end

        def has_comment_content?(comment_content)
          finished_loading?
          within_element(:note_content) do
            has_text?(comment_content)
          end
        end

        def has_syntax_highlighting?(language)
          within_element(:file_content) do
            find('.line')['lang'].to_s == language
          end
        end

        def edit_comment(comment)
          finished_loading?
          click_element(:edit_comment_button)
          fill_element(:edit_note_field, comment)
          click_element(:save_comment_button)
        end

        def delete_comment(comment)
          finished_loading?
          click_element(:more_actions_dropdown)
          accept_alert do
            click_element(:delete_comment_button)
          end
        end
      end
    end
  end
end