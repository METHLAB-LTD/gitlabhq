# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GithubImport::ImportPullRequestMergedByWorker do
  it { is_expected.to include_module(Gitlab::GithubImport::ObjectImporter) }

  describe '#representation_class' do
    it { expect(subject.representation_class).to eq(Gitlab::GithubImport::Representation::PullRequest) }
  end

  describe '#importer_class' do
    it { expect(subject.importer_class).to eq(Gitlab::GithubImport::Importer::PullRequestMergedByImporter) }
  end

  describe '#counter_name' do
    it { expect(subject.counter_name).to eq(:github_importer_imported_pull_requests_merged_by) }
  end

  describe '#counter_description' do
    it { expect(subject.counter_description).to eq('The number of imported GitHub pull requests merged by') }
  end
end
