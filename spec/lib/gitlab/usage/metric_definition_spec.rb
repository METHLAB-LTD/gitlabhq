# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::MetricDefinition do
  let(:attributes) do
    {
      name: 'uuid',
      description: 'GitLab instance unique identifier',
      value_type: 'string',
      product_category: 'collection',
      stage: 'growth',
      status: 'data_available',
      default_generation: 'generation_1',
      full_path: {
        generation_1: 'uuid',
        generation_2: 'license.uuid'
      },
      group: 'group::product analytics',
      time_frame: 'none',
      data_source: 'database',
      distribution: %w(ee ce),
      tier: %w(free starter premium ultimate bronze silver gold)
    }
  end

  let(:path) { File.join('metrics', 'uuid.yml') }
  let(:definition) { described_class.new(path, attributes) }
  let(:yaml_content) { attributes.deep_stringify_keys.to_yaml }

  it 'has all definitons valid' do
    expect { described_class.definitions }.not_to raise_error(Gitlab::Usage::Metric::InvalidMetricError)
  end

  describe '#key' do
    subject { definition.key }

    it 'returns a symbol from name' do
      is_expected.to eq('uuid')
    end
  end

  describe '#validate' do
    using RSpec::Parameterized::TableSyntax

    where(:attribute, :value) do
      :name               | nil
      :description        | nil
      :value_type         | nil
      :value_type         | 'test'
      :status             | nil
      :default_generation | nil
      :group              | nil
      :time_frame         | nil
      :time_frame         | '29d'
      :data_source        | 'other'
      :data_source        | nil
      :distribution       | nil
      :distribution       | 'test'
      :tier               | %w(test ee)
    end

    with_them do
      before do
        attributes[attribute] = value
      end

      it 'raise exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception).at_least(:once).with(instance_of(Gitlab::Usage::Metric::InvalidMetricError))

        described_class.new(path, attributes).validate!
      end
    end
  end

  describe '.load_all!' do
    let(:metric1) { Dir.mktmpdir('metric1') }
    let(:metric2) { Dir.mktmpdir('metric2') }
    let(:definitions) { {} }

    before do
      allow(described_class).to receive(:paths).and_return(
        [
          File.join(metric1, '**', '*.yml'),
          File.join(metric2, '**', '*.yml')
        ]
      )
    end

    subject { described_class.send(:load_all!) }

    it 'has empty list when there are no definition files' do
      is_expected.to be_empty
    end

    it 'has one metric when there is one file' do
      write_metric(metric1, path, yaml_content)

      is_expected.to be_one
    end

    it 'when the same meric is defined multiple times raises exception' do
      write_metric(metric1, path, yaml_content)
      write_metric(metric2, path, yaml_content)

      expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception).with(instance_of(Gitlab::Usage::Metric::InvalidMetricError))

      subject
    end

    after do
      FileUtils.rm_rf(metric1)
      FileUtils.rm_rf(metric2)
    end

    def write_metric(metric, path, content)
      path = File.join(metric, path)
      dir = File.dirname(path)
      FileUtils.mkdir_p(dir)
      File.write(path, content)
    end
  end
end