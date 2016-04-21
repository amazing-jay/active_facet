require 'spec_helper'

describe ActiveFacet::ResourceManager do

  describe "public attributes" do
    it { expect(described_class.methods).to include(
      :resource_mapper,
      :serializer_mapper,
      :memoized_serializers
    )}
  end

  describe "class methods" do

    describe "resource_mapper" do
      subject { described_class.resource_mapper }
      it { expect(subject == described_class.method(:default_resource_mapper)).to be true }
    end

    describe "default_resource_mapper" do
      subject { described_class.default_resource_mapper(resource_class) }
      let(:resource_class) { ResourceA }
      it { expect(subject).to eq(["resource_as", "active_record/bases"]) }
    end

    describe "serializer_mapper" do
      subject { described_class.serializer_mapper }
      it { expect(subject == described_class.method(:default_serializer_mapper)).to be true }
    end

    describe "default_serializer_mapper" do
      subject { described_class.default_serializer_mapper(resource_class, serializer, type, version, options) }
      let(:resource_class) { ResourceA }
      let(:serializer) { resource_class.name.demodulize.to_s.camelcase }
      let(:type) { :serializer }
      let(:version) { 1.0 }
      let(:options) { {} }

      before do
        reset_serializer_mapper_memoization
        allow(described_class).to receive(:internal_serializer_mapper).and_call_original
        described_class.default_serializer_mapper(resource_class, serializer, type, version, options)
        subject
      end

      context 'not found serializer' do
        let(:type) { :else }
        let(:serializer) { 'Customizer' }
        it { expect(described_class).to have_received(:internal_serializer_mapper).once }
        it { expect(subject).to eq(nil) }
      end

      context 'resource serializer' do
        it { expect(described_class).to have_received(:internal_serializer_mapper).once }
        it { expect(subject).to eq(V1::ResourceA::ResourceASerializer.new) }
        context 'versioned serializer' do
          let(:version) { 2.0 }
          it { expect(described_class).to have_received(:internal_serializer_mapper).once }
          it { expect(subject).to eq(V2::ResourceA::ResourceASerializer.new) }
        end
      end

      context 'attribute serializer' do
        let(:type) { :attribute_serializer }
        let(:serializer) { 'Customizer' }
        it { expect(described_class).to have_received(:internal_serializer_mapper).once }
        it { expect(subject).to eq(V1::CustomizerAttributeSerializer) }

        context 'versioned attribute serializer' do
          let(:version) { 2.0 }
          it { expect(described_class).to have_received(:internal_serializer_mapper).once }
          it { expect(subject).to eq(V2::CustomizerAttributeSerializer) }
        end
      end

    end

    describe "internal_serializer_mapper" do
      subject { described_class.internal_serializer_mapper(resource_class, serializer, type, version, options) }
      let(:resource_class) { ResourceA }
      let(:serializer) { resource_class.name.demodulize.to_s.camelcase }
      let(:type) { :serializer }
      let(:version) { 1.0 }
      let(:options) { {} }

      context 'not found serializer' do
        let(:type) { :else }
        let(:serializer) { 'Customizer' }
        it { expect(subject).to eq(nil) }
      end

      context 'resource serializer' do
        it { expect(subject).to eq(V1::ResourceA::ResourceASerializer.new) }
        context 'versioned serializer' do
          let(:version) { 2.0 }
          it { expect(subject).to eq(V2::ResourceA::ResourceASerializer.new) }
        end
      end

      context 'attribute serializer' do
        let(:type) { :attribute_serializer }
        let(:serializer) { 'Customizer' }
        it { expect(subject).to eq(V1::CustomizerAttributeSerializer) }

        context 'versioned attribute serializer' do
          let(:version) { 2.0 }
          it { expect(subject).to eq(V2::CustomizerAttributeSerializer) }
        end
      end

    end
  end

  describe "serializer_for" do
    let(:instance) { described_class.instance }
    subject { instance.serializer_for(resource_class, options) }
    let(:resource_class) { ResourceA }
    let(:options) { {} }

    it { expect(subject).to eq(V1::ResourceA::ResourceASerializer.new) }
    context "versioned" do
      let(:options) { make_options version: 2.0 }
      it { expect(subject).to eq(V2::ResourceA::ResourceASerializer.new) }
    end
  end

  describe "attribute_serializer_class_for" do
    let(:instance) { described_class.instance }
    subject { instance.attribute_serializer_class_for(resource_class, attribute_name, options) }
    let(:resource_class) { ResourceA }
    let(:attribute_name) { 'Customizer' }
    let(:options) { {} }

    it { expect(subject).to eq(V1::CustomizerAttributeSerializer) }
    context "versioned" do
      let(:options) { make_options version: 2.0 }
      it { expect(subject).to eq(V2::CustomizerAttributeSerializer) }
    end
  end

  describe "resource_map" do
    let(:instance) { described_class.instance }
    subject { instance.resource_map(resource_class) }
    let(:resource_class) { ResourceA }

    before do
      reset_resource_mapper_memoization
      allow(described_class).to receive(:resource_mapper).and_call_original
      instance.resource_map(resource_class)
      subject
    end

    it { expect(described_class).to have_received(:resource_mapper).once }
    it { expect(subject).to eq(["resource_as", "active_record/bases"]) }
  end

  describe "extract_version_from_opts" do
    let(:instance) { described_class.instance }
    subject { instance.extract_version_from_opts(options) }

    context "nil" do
      let(:options) { nil }
      it { expect(subject).to eq(1.0) }
    end

    context "empty" do
      let(:options) { {} }
      it { expect(subject).to eq(1.0) }
    end

    context "nested empty" do
      let(:options) { make_options({}) }
      it { expect(subject).to eq(1.0) }
    end

    context "present" do
      let(:options) { make_options version: 2.0 }
      it { expect(subject).to eq(2.0) }
    end
  end

  describe "instance attributes" do
    it { expect(described_class.private_instance_methods).to include(
      :memoized_resource_map
    )}
  end

  describe "fetch_serializer" do
    subject { instance.send(:fetch_serializer, resource_class, serializer, type, options) }
    let(:instance) { described_class.instance }
    let(:resource_class) { ResourceA }
    let(:serializer) { resource_class.name.demodulize.to_s.camelcase }
    let(:type) { :serializer }
    let(:version) { 1.0 }
    let(:options) { {} }

    before do
      allow(described_class).to receive(:serializer_mapper).and_call_original
    end

    context 'not found serializer' do
      let(:type) { :else }
      let(:serializer) { 'Customizer' }
      let(:error_message) { "Unable to locate serializer for:: " + [resource_class.name, serializer, type, version].to_s }

      context 'not strict_lookups' do
        before do
          subject
        end

        it { expect(described_class).to have_received(:serializer_mapper).once }
        it { expect(subject).to eq(nil) }
      end

      context 'strict_lookups' do
        around do |example|
          ActiveFacet.strict_lookups = true
          example.run
          ActiveFacet.strict_lookups = false
        end

        it { expect{subject}.to raise_error(ActiveFacet::Errors::LookupError, error_message) }
      end
    end

    context 'resource serializer' do
      before do
        subject
      end

      it { expect(described_class).to have_received(:serializer_mapper).once }
      it { expect(subject).to eq(V1::ResourceA::ResourceASerializer.new) }
    end
  end
end