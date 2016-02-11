require 'spec_helper'

describe RealCerealBusiness::Serializer::Base do

  include TestHarness

  let(:resource_serializer_class) { build_resource_serializer_class }
  let(:association_serializer_class) { build_association_serializer_class }
  let(:attribute_serializer_class) { build_attribute_serializer_class }
  let(:configure_serializers) { configure_serializer_class resource_serializer_class, association_serializer_class, attribute_serializer_class }
  let(:instance) { resource_serializer_class.new }
  let(:resource) { test_resource_class.new }

  describe "#new" do
    context "instanciation should compile shared config" do
      it { expect(resource_serializer_class.config.compiled).to be_false }
      context 'instance' do
        subject { instance }
        it { expect{subject}.to_not raise_error }
        it { expect(resource_serializer_class.config.compiled).to be_true}
        it { expect(resource_serializer_class.config).to eq(subject.config)}
      end
    end

    context "singleton" do
      it { expect(resource_serializer_class.new).to eq(resource_serializer_class.new)}
    end
  end

  describe "#config" do
    subject { resource_serializer_class.config }
    it { expect(subject.class).to be(RealCerealBusiness::Config)}
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
      it { expect(config.serializers[attribute]).to be_blank }
      it { expect(config.namespaces[attribute]).to be_blank }
    end

    context("from") do
      let(:options) { {from: :bar} }
      it { expect(config.transforms(:to)).to eq({attribute.to_s => :bar}) }
      it { expect(config.transforms(:from)).to eq({attribute.to_s => :bar}) }
      it { expect(config.serializers[attribute]).to be_blank }
      it { expect(config.namespaces[attribute]).to be_blank }
    end

    context("to") do
      let(:options) { {to: :bar} }
      it { expect(config.transforms(:to)).to eq({attribute.to_s => :bar}) }
      it { expect(config.transforms(:from)).to eq({attribute.to_s => :bar}) }
      it { expect(config.serializers[attribute]).to be_blank }
      it { expect(config.namespaces[attribute]).to be_blank }
    end

    context("with") do
      let(:options) { {with: :bar} }
      it { expect(config.serializers[attribute]).to eq(:bar) }
      it { expect(config.namespaces[attribute]).to be_blank }
    end

    context("within") do
      let(:options) { {within: :bar} }
      it { expect(config.transforms(:to)).to eq({}) }
      it { expect(config.transforms(:from)).to eq({}) }
      it { expect(config.serializers[attribute]).to be_blank }
      it { expect(config.namespaces[attribute]).to eq(:bar) }
    end

    context("as + from") do
      let(:options) { {as: :bar, from: :barbar} }
      it { expect(config.transforms(:to)).to eq({attribute.to_s => :bar}) }
      it { expect(config.transforms(:from)).to eq({attribute.to_s => :barbar}) }
      it { expect(config.serializers[attribute]).to be_blank }
      it { expect(config.namespaces[attribute]).to be_blank }
    end

    context("as + to") do
      let(:options) { {as: :bar, to: :barbar} }
      it { expect(config.transforms(:to)).to eq({attribute.to_s => :barbar}) }
      it { expect(config.transforms(:from)).to eq({attribute.to_s => :bar}) }
      it { expect(config.serializers[attribute]).to be_blank }
      it { expect(config.namespaces[attribute]).to be_blank }
    end

    context("from + to") do
      let(:options) { {from: :bar, to: :barbar} }
      it { expect(config.transforms(:to)).to eq({attribute.to_s => :barbar}) }
      it { expect(config.transforms(:from)).to eq({attribute.to_s => :bar}) }
      it { expect(config.serializers[attribute]).to be_blank }
      it { expect(config.namespaces[attribute]).to be_blank }
    end

    context("all") do
      let(:options) { {as: :bar, to: :barto, from: :barfrom, with: :with, within: :within} }
      it { expect(config.transforms(:to)).to eq({attribute.to_s => :barto}) }
      it { expect(config.transforms(:from)).to eq({attribute.to_s => :barfrom}) }
      it { expect(config.serializers[attribute]).to eq(:with) }
      it { expect(config.namespaces[attribute]).to eq(:within) }
    end

    context("relations") do
      pending "should raise error if envoked on a relation"
    end
  end

  describe "#extension" do
    subject { resource_serializer_class.extension(attribute) }
    let(:config) { resource_serializer_class.config }
    let(:attribute) { :foo }
    before do
      subject
    end

    it { expect(config.extensions[attribute]).to be_true }
    it { expect(config.serializers[attribute]).to eq(attribute.to_sym) }
  end

  describe "#expose" do
    subject { resource_serializer_class.expose(field_set_name, options) }
    let(:config) { resource_serializer_class.config }
    let(:field_set_name) { :foo }
    let(:field_set) { :bar }
    let(:options) { { as: field_set } }

    context 'valid' do
      before do
        subject
        instance
      end

      it { expect(config.normalized_field_sets[field_set_name]["fields"].keys).to match_array([field_set.to_s]) }
      it { expect(instance.config.normalized_field_sets[field_set_name]["fields"].keys).to match_array([field_set.to_s]) }

      context "none" do
        subject { resource_serializer_class.expose(field_set_name) }
        it { expect(config.normalized_field_sets[field_set_name]["fields"].keys).to match_array([field_set_name.to_s]) }
        it { expect(instance.config.normalized_field_sets[field_set_name]["fields"].keys).to match_array([field_set_name.to_s]) }
      end
    end

    context "all" do
      let(:field_set_name) { :all }
      it { expect{subject}.to raise_error(RealCerealBusiness::Errors::ConfigurationError,RealCerealBusiness::Errors::ConfigurationError::ALL_FIELDS_ERROR_MSG) }
    end
    context "all_attributes" do
      let(:field_set_name) { :all_attributes }
      it { expect{subject}.to raise_error(RealCerealBusiness::Errors::ConfigurationError,RealCerealBusiness::Errors::ConfigurationError::ALL_ATTRIBUTES_ERROR_MSG) }
    end
  end

  describe "#expose_timestamps" do
    subject { resource_serializer_class.expose_timestamps }
    let(:config) { resource_serializer_class.config }

    before do
      subject
      instance
    end

    it { expect(config.serializers[:created_at]).to eq(:time) }
    it { expect(config.serializers[:updated_at]).to eq(:time) }
    it { expect(config.normalized_field_sets[:timestamps]["fields"].keys).to match_array(['id', 'created_at', 'updated_at']) }
  end

  describe "instance methods" do
    before do
      configure_serializers
    end

    describe ".scoped_includes" do
      subject { instance.scoped_includes(field_set) }
      let(:field_set) { [{delegates: :one, alias_relation: :one}, :deep_relations, :extras] }
      it { expect(subject).to eq([:delegates, :child, :owner, :extras, {:parent=>:child}]) }
    end

    describe ".exposed_aliases" do
      subject { instance.exposed_aliases(field_set_alias, include_relations, include_nested_field_sets) }
      let(:field_set_alias) { :all }
      let(:include_relations) { false }
      let(:include_nested_field_sets) { false }

      context "all attributes" do
        it { expect(subject).to eq([:alias_attr, :alias_relation, :compound_attr, :custom_attr, :dynamic_attr, :explicit_attr, :from_attr, :implicit_attr, :nested_attr, :nested_compound_attr, :private_attr, :to_attr]) }
      end

      context "all fields" do
        #TODO --jdc fix so that relations get dealiased (alias_relation should not be in this set)
        let(:include_relations) { true }
        it { expect(subject).to eq([:alias_attr, :alias_relation, :child, :compound_attr, :custom_attr, :delegates, :dynamic_attr, :explicit_attr, :from_attr, :implicit_attr, :nested_attr, :nested_compound_attr, :others, :owner, :parent, :private_attr, :to_attr]) }
      end

      context "all nested" do
        let(:include_relations) { true }
        let(:include_nested_field_sets) { true }
        it { expect(subject).to eq({"explicit_attr"=>{}, "implicit_attr"=>{}, "dynamic_attr"=>{}, "private_attr"=>{}, "alias_attr"=>{}, "to_attr"=>{}, "from_attr"=>{}, "nested_attr"=>{}, "nested_compound_attr"=>{}, "custom_attr"=>{}, "compound_attr"=>{}, "parent"=>{"child"=>{"attr"=>{}}}, "child"=>{"attrs"=>{}}, "owner"=>{}, "delegates"=>{"minimal"=>{}}, "others"=>{}, "alias_relation"=>{"implicit_attr"=>{}}}) }
      end

      context "named attributes" do
        let(:field_set_alias) { :attrs }
        it { expect(subject).to eq([:alias_attr, :dynamic_attr, :explicit_attr, :from_attr, :implicit_attr, :private_attr, :to_attr]) }
      end

      context "named nested" do
        let(:field_set_alias) { :attrs }
        let(:include_nested_field_sets) { true }
        it { expect(subject).to eq({"explicit_attr"=>{}, "implicit_attr"=>{}, "dynamic_attr"=>{}, "private_attr"=>{}, "alias_attr"=>{}, "to_attr"=>{}, "from_attr"=>{}}) }
      end
    end

    describe ".from_hash" do
      before do
        allow_any_instance_of(RealCerealBusiness::Serializer::Facade).to receive(:from_hash) { |attributes| attributes }
      end
      subject { instance.from_hash(resource, { foo: :bar }) }
      it { expect(subject).to eq({ foo: :bar }) }
      it { expect(RealCerealBusiness::Serializer::Facade).to receive(:new).once }
    end

    describe ".as_json" do
      before do
        allow_any_instance_of(RealCerealBusiness::Serializer::Facade).to receive(:as_json) { { foo: :bar } }
      end
      subject { instance.as_json(resouces, options) }
      let(:options) { {a: :b} }
      let(:resouces) { resource }
      it { expect(subject).to eq({ foo: :bar }) }
      it { expect(RealCerealBusiness::Serializer::Facade).to receive(:new).once }

      context 'collection' do
        let(:resouces) { [resource, resource] }
        it { expect(subject).to eq([{ foo: :bar }, { foo: :bar }]) }
        it { expect(RealCerealBusiness::Serializer::Facade).to receive(:new).twice }
      end
    end

    describe ".config" do
      subject { instance.config }
      it { expect(subject.class).to be(RealCerealBusiness::Config)}
      context "memoized" do
        it { expect(subject).to be(instance.config)}
      end
    end

    describe ".resource_class" do
      subject { instance.resource_class }
      it { expect(subject).to be(test_resource_class)}
    end

    describe ".get_association_reflection" do
      subject { instance.get_association_reflection(field) }

      context "relation" do
        let(:field) { :parent }
        it { expect(subject.class).to be(ActiveRecord::Reflection::AssociationReflection) }
      end

      context "field" do
        let(:field) { :explicit_attr }
        it { expect(subject).to be_nil }
      end
    end

    describe ".get_association_serializer_class" do
      subject { instance.get_association_serializer_class(field) }
      context "self association" do
        let(:field) { :parent }
        it { expect(subject).to be(resource_serializer_class.new) }
      end

      context "association" do
        let(:field) { :owner }
        it { expect(subject).to be(association_serializer_class.new) }
      end

      context "attribute" do
        let(:field) { :explicit_attr }
        it { expect(subject).to be_nil }
      end
    end

    describe ".get_custom_serializer_class" do
      subject { instance.get_custom_serializer_class(field) }
      context "registered" do
        let(:field) { :customizer }
        it { expect(subject).to be(attribute_serializer_class) }
      end

      context "unregistered" do
        let(:field) { :unregistered }
        it { expect(subject).to be_nil }
      end
    end

    describe ".is_association?" do
      subject { instance.is_association?(field) }
      context "registered" do
        let(:field) { :parent }
        it { expect(subject).to be_true }
      end

      context "unregistered" do
        let(:field) { :extras }
        it { expect(subject).to be_true }
      end

      context "attribute" do
        let(:field) { :explicit_attr }
        it { expect(subject).to be_false }
      end
    end

    describe ".resource_attribute_name" do
      subject { instance.resource_attribute_name(field, direction) }

      context "from" do
        let(:direction) { :from }
        let(:field) { :from_attr }
        it { expect(subject).to eq(:from_accessor) }

        context "as" do
          let(:field) { :alias_attr }
          it { expect(subject).to eq(:aliased_accessor) }
        end

        context "none" do
          let(:field) { :explicit_attr }
          it { expect(subject).to eq(:explicit_attr) }
        end
      end

      context "to" do
        let(:direction) { :to }
        let(:field) { :to_attr }
        it { expect(subject).to eq(:to_accessor) }

        context "as" do
          let(:field) { :aliased_accessor }
          it { expect(subject).to eq(:aliased_accessor) }
        end

        context "none" do
          let(:field) { :explicit_attr }
          it { expect(subject).to eq(:explicit_attr) }
        end
      end
    end
  end
end