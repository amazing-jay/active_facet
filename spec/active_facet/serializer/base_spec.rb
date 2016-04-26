require 'spec_helper'

describe ActiveFacet::Serializer::Base do

  include TestHarnessHelper

  let(:resource_serializer_class) { build_resource_serializer_class }
  let(:association_serializer_class) { build_association_serializer_class }
  let(:attribute_serializer_class) { build_attribute_serializer_class }
  let(:instance) { resource_serializer_class.instance }
  let(:resource) { test_resource_class.new }

  describe "#new" do
    context "instanciation should compile shared config" do
      it { expect(resource_serializer_class.config.compiled).to be false }
      context 'instance' do
        subject { instance }
        it { expect{subject}.to_not raise_error }
        it { expect(resource_serializer_class.config.compiled).to be true}
        it { expect(resource_serializer_class.config).to eq(subject.config)}
      end
    end

    context "singleton" do
      it { expect(resource_serializer_class.instance).to eq(resource_serializer_class.instance)}
    end

    context "reflector" do
      it { expect(resource_serializer_class.instance_methods).to include(
        :resource_class,
        :resource_attribute_name,
        :get_association_reflection,
        :get_association_serializer_class,
        :get_custom_serializer_class,
        :is_association?
      )}
    end
  end

  describe "#config" do
    subject { resource_serializer_class.config }
    it { expect(subject.class).to be(ActiveFacet::Config)}
    it { expect(subject).to be(resource_serializer_class.config) }
    it { expect(subject).to be(instance.config) }
  end

  describe "#transform" do
    subject { resource_serializer_class.transform(attribute, options) }
    let(:config) { resource_serializer_class.config }
    let(:attribute) { :foo }
    let(:options) { {} }

    before do
      subject
    end

    context("as") do
      let(:options) { {as: :bar} }
      it { expect(config.transforms(:to)).to eq({attribute.to_s => :bar}) }
      it { expect(config.transforms(:from)).to eq({attribute.to_s => :bar}) }
      it { expect(config.custom_serializers[attribute]).to be_blank }
      it { expect(config.namespaces[attribute]).to be_blank }
    end

    context("from") do
      let(:options) { {from: :bar} }
      it { expect(config.transforms(:to)).to eq({attribute.to_s => :bar}) }
      it { expect(config.transforms(:from)).to eq({attribute.to_s => :bar}) }
      it { expect(config.custom_serializers[attribute]).to be_blank }
      it { expect(config.namespaces[attribute]).to be_blank }
    end

    context("to") do
      let(:options) { {to: :bar} }
      it { expect(config.transforms(:to)).to eq({attribute.to_s => :bar}) }
      it { expect(config.transforms(:from)).to eq({attribute.to_s => :bar}) }
      it { expect(config.custom_serializers[attribute]).to be_blank }
      it { expect(config.namespaces[attribute]).to be_blank }
    end

    context("with") do
      let(:options) { {with: :bar} }
      it { expect(config.custom_serializers[attribute]).to eq(:bar) }
      it { expect(config.namespaces[attribute]).to be_blank }
    end

    context("within") do
      let(:options) { {within: :bar} }
      it { expect(config.transforms(:to)).to eq({}) }
      it { expect(config.transforms(:from)).to eq({}) }
      it { expect(config.custom_serializers[attribute]).to be_blank }
      it { expect(config.namespaces[attribute]).to eq(:bar) }
    end

    context("as + from") do
      let(:options) { {as: :bar, from: :barbar} }
      it { expect(config.transforms(:to)).to eq({attribute.to_s => :bar}) }
      it { expect(config.transforms(:from)).to eq({attribute.to_s => :barbar}) }
      it { expect(config.custom_serializers[attribute]).to be_blank }
      it { expect(config.namespaces[attribute]).to be_blank }
    end

    context("as + to") do
      let(:options) { {as: :bar, to: :barbar} }
      it { expect(config.transforms(:to)).to eq({attribute.to_s => :barbar}) }
      it { expect(config.transforms(:from)).to eq({attribute.to_s => :bar}) }
      it { expect(config.custom_serializers[attribute]).to be_blank }
      it { expect(config.namespaces[attribute]).to be_blank }
    end

    context("from + to") do
      let(:options) { {from: :bar, to: :barbar} }
      it { expect(config.transforms(:to)).to eq({attribute.to_s => :barbar}) }
      it { expect(config.transforms(:from)).to eq({attribute.to_s => :bar}) }
      it { expect(config.custom_serializers[attribute]).to be_blank }
      it { expect(config.namespaces[attribute]).to be_blank }
    end

    context("all") do
      let(:options) { {as: :bar, to: :barto, from: :barfrom, with: :with, within: :within} }
      it { expect(config.transforms(:to)).to eq({attribute.to_s => :barto}) }
      it { expect(config.transforms(:from)).to eq({attribute.to_s => :barfrom}) }
      it { expect(config.custom_serializers[attribute]).to eq(:with) }
      it { expect(config.namespaces[attribute]).to eq(:within) }
    end

    context("relations") do
      skip "should work if envoked on a relation"
    end
  end

  describe "#extension" do
    subject { resource_serializer_class.extension(attribute) }
    let(:config) { resource_serializer_class.config }
    let(:attribute) { :foo }
    before do
      subject
    end

    it { expect(config.extensions[attribute]).to be true }
    it { expect(config.custom_serializers[attribute]).to eq(attribute.to_sym) }
  end

  describe "#expose" do
    subject { resource_serializer_class.expose(facet_name, options) }
    let(:config) { resource_serializer_class.config }
    let(:facet_name) { :foo }
    let(:facet) { :bar }
    let(:options) { { as: facet } }

    context 'valid' do
      before do
        subject
        instance
      end

      it { expect(config.normalized_facets[facet_name]["fields"].keys).to match_array([facet.to_s]) }
      it { expect(instance.config.normalized_facets[facet_name]["fields"].keys).to match_array([facet.to_s]) }

      context "none" do
        subject { resource_serializer_class.expose(facet_name) }
        it { expect(config.normalized_facets[facet_name]["fields"].keys).to match_array([facet_name.to_s]) }
        it { expect(instance.config.normalized_facets[facet_name]["fields"].keys).to match_array([facet_name.to_s]) }
      end
    end

    context "all" do
      let(:facet_name) { :all }
      it { expect{subject}.to raise_error(ActiveFacet::Errors::ConfigurationError,ActiveFacet::Errors::ConfigurationError::ALL_FIELDS_ERROR_MSG) }
    end
    context "all_attributes" do
      let(:facet_name) { :all_attributes }
      it { expect{subject}.to raise_error(ActiveFacet::Errors::ConfigurationError,ActiveFacet::Errors::ConfigurationError::ALL_ATTRIBUTES_ERROR_MSG) }
    end
  end

  describe "#expose_timestamps" do
    subject { resource_serializer_class.expose_timestamps }
    let(:config) { resource_serializer_class.config }

    before do
      subject
      instance
    end

    it { expect(config.custom_serializers[:created_at]).to eq(:time) }
    it { expect(config.custom_serializers[:updated_at]).to eq(:time) }
    it { expect(config.normalized_facets[:timestamps]["fields"].keys).to match_array(['id', 'created_at', 'updated_at']) }
  end

  describe "instance methods" do
    around(:each) do |example|
      setup_serializer_classes(resource_serializer_class, association_serializer_class, attribute_serializer_class)
      example.run
      reset_serializer_classes
    end

    describe ".includes" do
      skip "todo: fix so that relations get dealiased (others should be in this set)"

      subject { instance.includes(facet) }
      let(:facet) { [{children: :one, alias_relation: :one}, :deep_relations, :extras] }
      it { expect(subject).to eq({:children=>{}, :parent=>{:children=>{}}, :master=>{}, :extras=>{}}) }
    end

    describe ".explode" do
      subject { instance.explode(facet_alias) }
      let(:facet_alias) { :all }

      context "all attributes" do
        skip "todo: fix so that relations get dealiased (alias_relation should not be in this set)"
        it { expect(subject).to eq({:explicit_attr=>nil, :alias_attr=>nil, :from_attr=>nil, :to_attr=>nil, :nested_attr=>nil, :custom_attr=>nil, :compound_attr=>nil, :nested_compound_attr=>nil, :extension_attr=>nil, :implicit_attr=>nil, :dynamic_attr=>nil, :private_attr=>nil, :parent=>{:children=>{:attr=>nil, :explicit_attr=>nil, :nested_attr=>nil}, :explicit_attr=>nil, :nested_attr=>nil}, :master=>{:basic=>nil}, :leader=>{"basic"=>nil}, :children=>{:nested_attr=>nil, :nested_compound_attr=>nil, :explicit_attr=>nil}, :others=>{"basic"=>nil}, :extras=>{:minimal=>nil}, :alias_relation=>nil}) }
      end

      context "named nested" do
        let(:facet_alias) { :attrs }
        let(:include_nested_facets) { true }
        it { expect(subject).to eq({:explicit_attr=>nil, :implicit_attr=>nil, :dynamic_attr=>nil, :private_attr=>nil, :alias_attr=>nil, :to_attr=>nil, :from_attr=>nil, :nested_attr=>nil}) }
      end
    end

    describe ".unserialize" do
      before do
        allow_any_instance_of(ActiveFacet::Serializer::Facade).to receive(:unserialize) { |attributes| attributes }
      end
      subject { instance.unserialize(resource, { foo: :bar }) }
      it { expect(subject).to eq({ foo: :bar }) }
      it { expect(ActiveFacet::Serializer::Facade).to receive(:new).once }
    end

    describe ".serialize" do
      before do
        allow_any_instance_of(ActiveFacet::Serializer::Facade).to receive(:serialize) { { foo: :bar } }
      end
      subject { instance.serialize(resources, options) }
      let(:options) { {a: :b} }
      let(:resources) { resource }
      it { expect(subject).to eq({ foo: :bar }) }
      it { expect(ActiveFacet::Serializer::Facade).to receive(:new).once }

      context 'collection' do
        let(:resources) { [resource, resource] }
        it { expect(subject).to eq([{ foo: :bar }, { foo: :bar }]) }
        it { expect(ActiveFacet::Serializer::Facade).to receive(:new).twice }
      end
    end

    describe ".config" do
      subject { instance.config }
      it { expect(subject.class).to be(ActiveFacet::Config)}
      context "memoized" do
        it { expect(subject).to be(instance.config)}
      end
    end

    skip "test explode_field"

    describe ".field_includes" do
      subject { instance.send(:field_includes, facet, nested_facet, options) }
      let(:facet) { :parent }
      let(:nested_facet) { :children }
      let(:options) { {} }
      it { expect(subject).to eq({:parent=>{:children=>{}}}) }
    end

    describe ".custom_field_includes" do
      subject { instance.send(:custom_field_includes, field, options) }
      let(:field) { :custom_attr }
      let(:options) { {} }

      context "not implemented" do
        it { expect(subject).to eq({}) }
      end

      context "not found" do
        let(:field) { :foo }
        it { expect(subject).to eq({}) }
      end

      context "implemented" do
        before do
          attribute_serializer_class.class_eval { def self.includes(options); :bar; end }
        end
        it { expect(subject).to eq(:bar) }
      end
    end
  end
end