# frozen_string_literal: true

module QA
  RSpec.describe 'Create' do
    context 'Design Management' do
      let(:design) do
        Resource::Design.fabricate! do |design|
          design.filename = 'tanuki.jpg'
        end
      end

      before do
        Flow::Login.sign_in
      end

      it 'user adds a design and modifies it', testcase: 'https://gitlab.com/gitlab-org/quality/testcases/-/issues/273' do
        design.issue.visit!

        Page::Project::Issue::Show.perform do |issue|
          expect(issue).to have_created_icon
        end

        Page::Project::Issue::Show.perform do |issue|
          issue.update_design(design.filename)
          expect(issue).to have_modified_icon
        end
      end
    end
  end
end