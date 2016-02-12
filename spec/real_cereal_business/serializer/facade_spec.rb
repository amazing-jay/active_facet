require 'spec_helper'

describe RealCerealBusiness::Serializer::Facade do

  include TestHarnessHelper

  # before do
  #   allow(RealCerealBusiness::ResourceManager.new).to receive(:resource_map) { |resource_class|

  #   }
  # end

  # around(:each) do |example|
  #   mapper = RealCerealBusiness::ResourceManager.resource_mapper
  #   RealCerealBusiness::ResourceManager.resource_mapperRealCerealBusiness::ResourceManager.method(:default_resource_mapper)
  #   example.run
  #   RealCerealBusiness::ResourceManager.resource_mapper = mapper
  # end

  let(:resource_serializer_class) { build_resource_serializer_class }
  let(:association_serializer_class) { build_association_serializer_class }
  let(:attribute_serializer_class) { build_attribute_serializer_class }
  let(:configure_serializers) { configure_serializer_class resource_serializer_class, association_serializer_class, attribute_serializer_class }
  let(:serializer) { resource_serializer_class.new }
  let(:resource) { test_resource_class.new(explicit_attr: 'hello', implicit_attr: 'mcfly') }
  let(:instance) { described_class.new(serializer, resource, options) }
  #TODO remove group_includes after moving to gem
  let(:options) { { RealCerealBusiness.opts_key => opts, group_includes: fields } }
  let(:opts) {
    {
      RealCerealBusiness.fields_key => fields,
      RealCerealBusiness.field_overrides_key => field_overrides,
      RealCerealBusiness.version_key => version,
      RealCerealBusiness.filters_key => filters
    }
  }
  let(:fields) { :fields }
  let(:field_overrides) { :field_overrides }
  let(:version) { :version }
  let(:filters) { :filters }
  let(:overrides) { {explicit_attr: true, implicit_attr: true} }

  describe ".initialize" do
    let(:field_overrides) { { test_resource_class.name.tableize => overrides } }
    subject { instance }
    it { expect(subject.serializer).to eq(serializer) }
    it { expect(subject.resource).to eq(resource) }
    it { expect(subject.options).to eq(options) }
    it { expect(subject.opts).to eq(opts) }
    it { expect(subject.fields).to eq(fields) }
    it { expect(subject.field_overrides).to eq(field_overrides) }
    it { expect(subject.overrides).to eq(overrides) }
    it { expect(subject.version).to eq(version) }
    it { expect(subject.filters).to eq(filters) }
  end

  describe ".cache_key" do
    subject { instance.cache_key }
    it { expect(subject).to eq(
        [
          resource.cache_key,
          fields,
          field_overrides,
          filters
        ].to_s )}
  end

  describe ".as_json" do
        # RealCerealBusiness.document_cache.fetch(self) { serialize! }
  end
  describe ".from_hash(attributes)" do
        # hydrate! deep_copy(attributes)
  end

  describe ".deep_copy(o)" do
    let(:obj) { { a: [:b,:c], d: { e: :f } } }
    subject { instance.send(:deep_copy, obj) }
    before do
      subject[:d][:e] = :g
    end
    it { expect(obj).to eq({ a: [:b,:c], d: { e: :f } }) }
    it { expect(subject).to eq({ a: [:b,:c], d: { e: :g } }) }
  end

  describe ".config" do
    subject { instance.send(:config) }
    it { expect(subject).to eq(serializer.config) }
  end

  describe ".allowed_field?" do
    subject { instance.send(:allowed_field?, :explicit_attr) }
    context "implicit" do
      it { expect(subject).to be true }
    end
    context "explicit" do
      let(:field_overrides) { { test_resource_class.name.tableize => {explicit_attr: true, implicit_attr: true} } }
      it { expect(subject).to be true }
    end
    context "denied" do
      let(:field_overrides) { { test_resource_class.name.tableize => {explicit_attr: false, implicit_attr: true} } }
      it { expect(subject).to be false }
    end
    context "ommitted" do
      let(:field_overrides) { { test_resource_class.name.tableize => {implicit_attr: true} } }
      it { expect(subject).to be nil }
    end
  end

  describe ".is_expression_scopeable?" do
    let(:exp) { ActiveRecord::Relation.new(nil,nil) }
    let(:persisted) { true }
    subject { instance.send(:is_expression_scopeable?, exp) }
    before do
      allow(resource).to receive(:persisted?) { persisted }
    end
    context "persisted relation" do
      it { expect(subject).to be true }
    end
    context "persisted attribute" do
      let(:exp) { :explicit_attr }
      it { expect(subject).to be false }
    end
    context "unpersisted attribute" do
      let(:exp) { :explicit_attr }
      let(:persisted) { false }
      it { expect(subject).to be false }
    end
    context "unpersisted relation" do
      let(:persisted) { false }
      it { expect(subject).to be false }
    end
  end

  describe ".is_active_relation?" do
    let(:exp) { ActiveRecord::Relation.new(nil,nil) }
    subject { instance.send(:is_active_relation?, exp) }
    context "active relation" do
      it { expect(subject).to be true }
    end
    context "array" do
      let(:exp) { [] }
      it { expect(subject).to be false }
      context "proxy" do
        before do
          class << exp; def scoped; true; end; end
        end
        it { expect(subject).to be true }
      end
    end
    context "else" do
      let(:exp) { :explicit_attr }
      it { expect(subject).to be false }
    end
  end

  describe ".resource_class" do
    subject { instance.send(:resource_class) }
    it { expect(subject).to eq(test_resource_class) }
    context "mismatched resource" do
      let(:resource) { test_association_class.new }
      it { expect(subject).to eq(test_association_class) }
    end
    context "abstract resource" do
      let(:resource) { Object.new }
      it { expect(subject).to eq(test_resource_class) }
    end
  end

  describe ".serialize!" do
        # json = {}.with_indifferent_access
        # ::PerformanceMonitor.measure("scope_itteration") do
        #   config.field_set_itterator(fields) do |scope, nested_scopes|
        #     ::PerformanceMonitor.measure("attribute retrieval wrapper", self.class.name, scope, (resource.is_a?(Array) ? resource : resource.id)) do
        #       begin
        #         json[scope] = get_resource_attribute scope, nested_scopes if allowed_field?(scope)
        #       rescue RealCerealBusiness::Errors::AttributeError => e
        #         # Deliberately do nothing. Ignore scopes that do not map to resource methods (or aliases)
        #       end
        #     end
        #   end
        # end

        # serialize_scopes! json

        # json
  end

  describe ".get_resource_attribute(scope, nested_scopes)" do
        # if config.namespaces.key? scope
        #   ::PerformanceMonitor.measure("namespaced resource") do
        #     if ns = get_resource_attribute!(config.namespaces[scope])
        #       ns[serializer.resource_attribute_name(scope).to_s]
        #     else
        #       nil
        #     end
        #   end
        # elsif config.extensions.key?(scope)
        #   ::PerformanceMonitor.measure("extended resource") do
        #     scope
        #   end
        # elsif serializer.is_association?(scope)
        #   attribute = ::PerformanceMonitor.measure("N+1 association loading", serializer.class.name, scope, resource.try(:id)) do
        #     get_association_attribute(scope)
        #   end
        #   ::PerformanceMonitor.measure("nested serialization", serializer.class.name, scope, resource.try(:id)) do
        #     attribute.as_json(options.merge(group_includes: nested_scopes))
        #   end
        # else
        #   #TODO: consider serializing everything instead of only associations.
        #   # Order#shipping_address, for example, is an ActiveRecord but not an association
        #   ::PerformanceMonitor.measure("basic resource", serializer.class.name, scope, (resource.is_a?(Array) ? resource : resource.id)) do
        #     get_resource_attribute!(serializer.resource_attribute_name(scope))
        #   end
        # end
  end

  describe ".get_resource_attribute!" do
    subject { instance.send(:get_resource_attribute!, field) }
    let(:field) { :field }
    context "missing" do
      it { expect{subject}.to raise_error(RealCerealBusiness::Errors::AttributeError) }
    end

    context "private" do
      before do
        class << resource; private; def field; 123; end; end
      end
      it { expect{subject}.to_not raise_error }
      it { expect(subject).to eq(123) }
    end

    context "public" do
      let(:field) { :explicit_attr }
      it { expect(subject).to eq('hello') }
    end
  end

  describe ".get_association_attribute(scope)" do
        # attribute = serializer.resource_attribute_name(scope)
        # key = [attribute, filters].to_s
        # association = preload_association_collection(key, scope)
        # if association.blank?
        #   attribute = resource.send(attribute)
        #   attribute = attribute.scope_filters(filters) if is_attribute_scopeable?(attribute)
        #   attribute
        # else
        #   association[:relation].collection? ? association[:collection] : association[:collection].first
        # end
  end

  describe ".preload_association_collection(key, scope)" do
        # association_serializer = serializer.get_association_serializer_class(scope)
        # relation = serializer.get_association_reflection(scope)
        # association = relation.klass
        # association = association.scope_filters(filters)

        # serializer.association_cache.preload_association_collection(key, resource, association_serializer, relation, association)
  end

  describe ".serialize_scopes!" do
    subject { instance.send(:serialize_scopes!, {'custom_attr' => 'hello', 'explicit_attr' => 'world'}) }
    before do
      configure_serializers
      allow(attribute_serializer_class).to receive(:serialize) { |attribute, resource, options| "serialized_#{attribute}" }
      subject
    end
    it { expect(attribute_serializer_class).to have_received(:serialize).with('hello', resource, options) }
    it { expect(subject).to eq({'custom_attr' => 'serialized_hello', 'explicit_attr' => 'world'}) }
  end

  describe ".hydrate!(json)" do
    subject { instance.send(:hydrate!, json) }
    let(:valid_attrs) {
      {
        explicit_attr: :explicit_attr,
        alias_attr: :alias_attr,
        from_attr: :from_attr,
        to_attr: :to_attr,
        nested_attr: :nested_attr,
        custom_attr: :custom_attr,
        compound_attr: :compound_attr,
        nested_compound_attr: :nested_compound_attr,
        extension_attr: :extension_attr
      }
    }
    let(:json) {
      valid_attrs.merge({
        implicit_attr: :implicit_attr,
        unexposed_attr: :unexposed_attr,
        extras: :extras,
        others: :others
      })
    }
    before do
      configure_serializers
    end
    it { expect(subject.explicit_attr).to eq(:explicit_attr) }
    it { expect(subject.aliased_accessor).to eq(:alias_attr) }
    it { expect(subject.from_accessor).to eq(:from_attr) }
    it { expect(subject.to_accessor).to eq(:to_attr) }
    it { expect(subject.nested_accessor['nested_attr']).to eq(:nested_attr) }
    it { expect(subject.custom_attr).to eq('hydrated_custom_attr') }
    it { expect(subject.compound_accessor).to eq('hydrated_compound_attr') }
    it { expect(subject.nested_compound_accessor['compound_accessor']).to eq('hydrated_nested_compound_attr') }
    it { expect(subject.implicit_attr).to eq(:implicit_attr) }
    it { expect(subject.unexposed_attr).to be nil }
    it { expect(subject.extras).to be_empty }
    it { expect(subject.others).to be_empty }
  end

  describe ".filter_allowed_keys!" do
    subject { instance.send(:filter_allowed_keys!, json, [:a, :b]) }
    let(:json) { {'a' => :foo, :b => :foo, 'c' => :foo} }
    it { expect(subject).to eq({'a' => :foo, 'b' => :foo}) }
    it { expect(json).to eq({'a' => :foo, 'b' => :foo}) }
  end

  describe ".hydrate_scopes!" do
    subject { instance.send(:hydrate_scopes!, {'custom_attr' => 'hello', 'explicit_attr' => 'world'}) }
    before do
      configure_serializers
      allow(attribute_serializer_class).to receive(:hydrate) { |attribute, resource, options| "hydrated_#{attribute}" }
      subject
    end
    it { expect(attribute_serializer_class).to have_received(:hydrate).with('hello', resource, options) }
    it { expect(subject).to eq({'custom_attr' => 'hydrated_hello', 'explicit_attr' => 'world'}) }
  end

  describe ".set_resource_attribute" do
    subject { instance.send(:set_resource_attribute, field, value) }
    before do
      configure_serializers
    end
    let(:value) { :foo }
    before do
      subject
    end
    context 'attribute' do
      let(:field) { :explicit_attr }
      it { expect(resource.explicit_attr).to eq(value) }
    end
    context 'namespaced attribute' do
      let(:field) { :nested_attr }
      it { expect(resource.nested_accessor["nested_attr"]).to eq(value) }
    end
    context 'field' do
      let(:field) { :alias_attr }
      it { expect(resource.aliased_accessor).to eq(value) }
    end
    context 'namespaced field' do
      let(:field) { :nested_compound_attr }
      it { expect(resource.nested_compound_accessor['compound_accessor']).to eq(value) }
    end
  end
end
