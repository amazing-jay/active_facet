require 'spec_helper'

describe ActiveFacet::Serializer::Facade do
  let(:customizer_attribute_serializer_class) { V1::CustomizerAttributeSerializer }
  let(:extension_attr_attribute_serializer_class) { V1::ExtensionAttrAttributeSerializer }
  let(:serializer) { V1::ResourceA::ResourceASerializer.new }
  let(:resource_class) { ResourceA }
  let(:association_class) { ResourceB }
  let(:resource) { ResourceA.new(explicit_attr: 'hello', implicit_attr: 'mcfly') }
  let(:instance) { described_class.new(serializer, resource, options) }
  let(:options) { { ActiveFacet.opts_key => opts } }
  let(:opts) {
    {
      ActiveFacet.fields_key => fields,
      ActiveFacet.field_overrides_key => field_overrides,
      ActiveFacet.version_key => version,
      ActiveFacet.filters_key => filters
    }
  }
  let(:fields) { :fields }
  let(:field_overrides) { :field_overrides }
  let(:version) { 1.0 }
  let(:filters) { :filters }
  let(:overrides) { {explicit_attr: true, implicit_attr: true} }

  before do
    reset_serializer_mapper_memoization
  end

  describe ".initialize" do
    let(:field_overrides) { { resource_class.name.tableize => overrides } }
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
        version.to_s +
        resource.cache_key +
        fields.to_s +
        field_overrides.to_s +
        filters.to_s
       )}
  end

  describe ".as_json" do
    subject { instance.send(:as_json) }

    before do
      allow(ActiveFacet.document_cache).to receive(:fetch).and_call_original
      allow(instance).to receive(:serialize!).and_call_original
      subject
    end

    it { expect(ActiveFacet.document_cache).to have_received(:fetch) }
    it { expect(instance).to have_received(:serialize!) }
  end

  describe ".from_hash" do
    subject { instance.from_hash(attributes) }
    let(:attributes) {
      {"explicit_attr"=>"explicit_attr", "implicit_attr"=>"implicit_attr", "private_attr"=>"private_accessor", "alias_attr"=>"aliased_accessor", "to_attr"=>"to_accessor", "from_attr"=>"from_accessor", "nested_attr"=>"nested_attr", "nested_compound_attr"=>"nested_compound_attr", "custom_attr"=>"custom_attr", "compound_attr"=>"serialized_compound_accessor", "parent"=>nil, "master"=>{}, "leader"=>nil, "children"=>[{"nested_attr"=>"nested_attr", "nested_compound_attr"=>"serialized_compound_accessor", "explicit_attr"=>"explicit_attr"}, {"nested_attr"=>"nested_attr", "nested_compound_attr"=>"serialized_compound_accessor", "explicit_attr"=>"explicit_attr"}, {"nested_attr"=>"nested_attr", "nested_compound_attr"=>"serialized_compound_accessor", "explicit_attr"=>"explicit_attr"}], "others"=>[], "extras"=>[]}
    }
    let(:other_resource) { create :resource_a }
    it { expect(subject.explicit_attr).to eq(other_resource.explicit_attr) }
    it { expect(subject.implicit_attr).to eq(other_resource.implicit_attr) }
    it { expect(subject.custom_attr).to eq('hydrated_custom_attr') }
    it { expect(subject.nested_accessor).to eq(other_resource.nested_accessor) }
    it { expect(subject.dynamic_accessor).to be_blank }
    it { expect(subject.private_accessor).to eq(other_resource.private_accessor) }
    it { expect(subject.aliased_accessor).to eq(other_resource.aliased_accessor) }
    it { expect(subject.from_accessor).to eq(other_resource.from_accessor) }
    it { expect(subject.to_accessor).to eq(other_resource.to_accessor) }
    it { expect(subject.nested_compound_accessor).to eq({'compound_accessor' => 'hydrated_nested_compound_attr'}) }
    it { expect(subject.unexposed_attr).to_not eq(other_resource.unexposed_attr) }

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
      let(:field_overrides) { { resource_class.name.tableize => {explicit_attr: true, implicit_attr: true} } }
      it { expect(subject).to be true }
    end
    context "denied" do
      let(:field_overrides) { { resource_class.name.tableize => {explicit_attr: false, implicit_attr: true} } }
      it { expect(subject).to be false }
    end
    context "ommitted" do
      let(:field_overrides) { { resource_class.name.tableize => {implicit_attr: true} } }
      it { expect(subject).to be nil }
    end
  end

  describe ".is_expression_scopeable?" do
    subject { instance.send(:is_expression_scopeable?, exp) }
    let(:exp) { ActiveRecord::Relation.new(nil,nil) }
    let(:persisted) { true }
    let(:options) { { ActiveFacet.opts_key => opts.merge(ActiveFacet.filters_force_key => filters_enabled_locally ) } }
    let(:filters_enabled_locally) { true }
    before do
      allow(resource).to receive(:persisted?) { persisted }
    end
    context "persisted relation" do
      it { expect(subject).to be true }
      context "filters disabled" do
        let(:filters_enabled_locally) { false }
        it { expect(subject).to be false }
      end
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

  describe ".is_relation_scopeable?" do
    subject { instance.send(:is_relation_scopeable?, exp) }
    let(:exp) { ActiveRecord::Relation.new(nil,nil) }
    around do |example|
      temp = ActiveFacet::filters_enabled
      ActiveFacet::filters_enabled = filters_enabled_globally
      example.run
      ActiveFacet::filters_enabled = temp
    end

    context "globally disabled" do
      let(:filters_enabled_globally) { false }
      it { expect(subject).to be false }

      context "forced disabled" do
        let(:options) { { ActiveFacet.opts_key => opts.merge(ActiveFacet.filters_force_key => false ) } }
        it { expect(subject).to be false }
      end
      context "forced enabled" do
        let(:options) { { ActiveFacet.opts_key => opts.merge(ActiveFacet.filters_force_key => true ) } }
        it { expect(subject).to be true }
      end
    end

    context "globally enabled" do
      let(:filters_enabled_globally) { true }
      it { expect(subject).to be true }

      context "forced disabled" do
        let(:options) { { ActiveFacet.opts_key => opts.merge(ActiveFacet.filters_force_key => false ) } }
        it { expect(subject).to be false }
      end
      context "forced enabled" do
        let(:options) { { ActiveFacet.opts_key => opts.merge(ActiveFacet.filters_force_key => true ) } }
        it { expect(subject).to be true }
      end
    end
  end

  describe ".resource_class" do
    subject { instance.send(:resource_class) }
    it { expect(subject).to eq(resource_class) }
    context "mismatched resource" do
      let(:resource) { association_class.new }
      it { expect(subject).to eq(association_class) }
    end
    context "abstract resource" do
      let(:resource) { Object.new }
      it { expect(subject).to eq(resource_class) }
    end
  end

  describe ".serialize!" do
    subject { instance.send(:serialize!) }
    let(:resource) { create :resource_a, :with_children, :with_master }

    context "all" do
      let(:fields) { :all }
      let(:filters) { {} }
      it { expect(subject).to eq({"explicit_attr"=>"explicit_attr", "alias_attr"=>"aliased_accessor", "from_attr"=>"from_accessor", "to_attr"=>"to_accessor", "nested_attr"=>"nested_attr", "custom_attr"=>"serialized_custom_attr", "compound_attr"=>"serialized_compound_accessor", "nested_compound_attr"=>"serialized_compound_accessor", "extension_attr"=>"serialized_extension_attr", "implicit_attr"=>"implicit_attr", "private_attr"=>"private_accessor", "parent"=>nil, "master"=>{}, "leader"=>nil, "children"=>[{"nested_attr"=>"nested_attr", "nested_compound_attr"=>"serialized_compound_accessor", "explicit_attr"=>"explicit_attr"}, {"nested_attr"=>"nested_attr", "nested_compound_attr"=>"serialized_compound_accessor", "explicit_attr"=>"explicit_attr"}, {"nested_attr"=>"nested_attr", "nested_compound_attr"=>"serialized_compound_accessor", "explicit_attr"=>"explicit_attr"}], "others"=>[], "extras"=>[]}) }
    end

    context "all_attributes" do
      let(:fields) { :all_attributes }
      let(:filters) { {} }
      it { expect(subject).to eq({"alias_attr"=>"aliased_accessor", "others"=>[], "compound_attr"=>"serialized_compound_accessor", "custom_attr"=>"serialized_custom_attr", "explicit_attr"=>"explicit_attr", "extension_attr"=>"serialized_extension_attr", "from_attr"=>"from_accessor", "implicit_attr"=>"implicit_attr", "nested_attr"=>"nested_attr", "nested_compound_attr"=>"serialized_compound_accessor", "private_attr"=>"private_accessor", "to_attr"=>"to_accessor"}) }
    end

    context "composite" do
      let(:fields) { [:explicit_attr, { children: :implicit_attr}, { master: :minimal}, [ :implicit_attr]] }
      let(:filters) { {} }
      it { expect(subject).to eq({"explicit_attr"=>"explicit_attr", "children"=>[{"implicit_attr"=>"implicit_attr", "explicit_attr"=>"explicit_attr", "nested_attr"=>"nested_attr"}, {"implicit_attr"=>"implicit_attr", "explicit_attr"=>"explicit_attr", "nested_attr"=>"nested_attr"}, {"implicit_attr"=>"implicit_attr", "explicit_attr"=>"explicit_attr", "nested_attr"=>"nested_attr"}], "master"=>{}, "implicit_attr"=>"implicit_attr", "nested_attr"=>"nested_attr"}) }
    end

    context "attrs" do
      let(:fields) { :attrs }
      let(:filters) { {} }
      it { expect(subject).to eq({"explicit_attr"=>"explicit_attr", "implicit_attr"=>"implicit_attr", "private_attr"=>"private_accessor", "alias_attr"=>"aliased_accessor", "to_attr"=>"to_accessor", "from_attr"=>"from_accessor", "nested_attr"=>"nested_attr"}) }
    end

    context "nested" do
      let(:fields) { :nested }
      let(:filters) { {} }
      it { expect(subject).to eq({"nested_attr"=>"nested_attr", "nested_compound_attr"=>"serialized_compound_accessor", "explicit_attr"=>"explicit_attr"}) }
    end

    context "custom" do
      let(:fields) { :custom }
      let(:filters) { {} }
      it { expect(subject).to eq({"custom_attr"=>"serialized_custom_attr", "compound_attr"=>"serialized_compound_accessor", "nested_compound_attr"=>"serialized_compound_accessor", "explicit_attr"=>"explicit_attr", "nested_attr"=>"nested_attr"}) }
    end

    context "minimal" do
      let(:fields) { :minimal }
      let(:filters) { {} }
      it { expect(subject).to eq({"explicit_attr"=>"explicit_attr"}) }
    end

    context "basic" do
      let(:fields) { :basic }
      let(:filters) { {} }
      it { expect(subject).to eq({"explicit_attr"=>"explicit_attr", "nested_attr"=>"nested_attr"}) }
    end

    context "relations" do
      let(:fields) { :relations }
      let(:filters) { {} }
      it { expect(subject).to eq({"parent"=>nil, "master"=>{}, "leader"=>nil, "children"=>[{"explicit_attr"=>"explicit_attr", "nested_attr"=>"nested_attr"}, {"explicit_attr"=>"explicit_attr", "nested_attr"=>"nested_attr"}, {"explicit_attr"=>"explicit_attr", "nested_attr"=>"nested_attr"}], "others"=>[], "extras"=>[], "explicit_attr"=>"explicit_attr", "nested_attr"=>"nested_attr"}) }
    end

    context "alias_relation" do
      let(:fields) { :alias_relation }
      let(:filters) { {} }
      it { expect(subject).to eq({"others"=>[], "explicit_attr"=>"explicit_attr", "nested_attr"=>"nested_attr"}) }
    end

    context "deep_relations" do
      let(:fields) { :deep_relations }
      let(:filters) { {} }
      it { expect(subject).to eq({"parent"=>nil, "children"=>[{"nested_attr"=>"nested_attr", "nested_compound_attr"=>"serialized_compound_accessor", "explicit_attr"=>"explicit_attr"}, {"nested_attr"=>"nested_attr", "nested_compound_attr"=>"serialized_compound_accessor", "explicit_attr"=>"explicit_attr"}, {"nested_attr"=>"nested_attr", "nested_compound_attr"=>"serialized_compound_accessor", "explicit_attr"=>"explicit_attr"}], "master"=>{}, "extras"=>[], "explicit_attr"=>"explicit_attr", "nested_attr"=>"nested_attr"}) }
    end

    context "explicit_attr" do
      let(:fields) { :explicit_attr }
      let(:filters) { {} }
      it { expect(subject).to eq({"explicit_attr"=>"explicit_attr", "nested_attr"=>"nested_attr"}) }
    end

    context "implicit_attr" do
      let(:fields) { :implicit_attr }
      let(:filters) { {} }
      it { expect(subject).to eq({"implicit_attr"=>"implicit_attr", "explicit_attr"=>"explicit_attr", "nested_attr"=>"nested_attr"}) }
    end
  end

  describe ".get_resource_attribute" do
    subject { instance.send(:get_resource_attribute, field, nested_field_set) }
    let(:resource) { create :resource_a, :with_children }
    let(:nested_field_set) { :basic }
    let(:filters) { {} }
    before do
      allow(instance).to receive(:get_resource_attribute!).and_call_original
      allow(resource).to receive(:children).and_call_original
      subject
    end

    context "namespace" do
      let(:field) { :nested_attr }
      it { expect(subject).to eq('nested_attr') }
      it { expect(instance).to have_received(:get_resource_attribute!) }
    end

    context "extension" do
      let(:field) { :extension_attr }
      it { expect(subject).to eq(:extension_attr) }
    end

    context "association" do
      let(:field) { :children }
      let(:children_options) { make_options(fields: :basic) }
      it { expect(subject).to eq(resource.children.as_json(children_options)) }
      it { expect(resource).to have_received(:children).twice }
    end

    context "default" do
      let(:field) { :explicit_attr }
      it { expect(subject).to eq('explicit_attr') }
      it { expect(instance).to have_received(:get_resource_attribute!) }
    end

    context "transformed" do
      let(:field) { :alias_attr }
      it { expect(subject).to eq('aliased_accessor') }
      it { expect(instance).to have_received(:get_resource_attribute!) }
    end
  end

  describe ".get_resource_attribute!" do
    subject { instance.send(:get_resource_attribute!, field) }
    let(:field) { :field }
    context "missing" do
      it { expect{subject}.to raise_error(ActiveFacet::Errors::AttributeError) }
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

  describe ".get_association_attribute" do
    let(:field) { :children }
    let(:resource) { create :resource_a, :with_children }
    let(:nested_field_set) { :basic }
    subject { instance.send(:get_association_attribute, field, nested_field_set ) }

    context 'default' do
      let(:filters) { {} }
      let(:fields) { :basic }
      it { expect(subject).to eq(resource.children.as_json(options)) }
      it { expect(subject).to_not be_empty }
    end

    context 'filtered' do
      let(:filters) { {} }
      skip 'todo: define a filter'
      it { expect(subject).to eq(resource.children.as_json(options)) }
    end

    context 'nil' do
      let(:filters) { {} }
      let(:field) { :others }
      it { expect(subject).to match_array(resource.others) }
      it { expect(subject).to be_empty }
    end
  end

  describe ".apply_custom_serializers!" do
    subject { instance.send(:apply_custom_serializers!, {'custom_attr' => 'hello', 'explicit_attr' => 'world'}) }
    before do
      allow(customizer_attribute_serializer_class).to receive(:serialize) { |attribute, resource, options| "serialized_#{attribute}" }
      allow(extension_attr_attribute_serializer_class).to receive(:serialize) { |attribute, resource, options| "serialized_#{attribute}" }
      subject
    end
    it { expect(customizer_attribute_serializer_class).to have_received(:serialize).with('hello', resource, options) }
    it { expect(extension_attr_attribute_serializer_class).to_not have_received(:serialize).with('hello', resource, options) }
    it { expect(subject).to eq({'custom_attr' => 'serialized_hello', 'explicit_attr' => 'world'}) }
  end

  describe ".hydrate!" do
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
      allow(customizer_attribute_serializer_class).to receive(:hydrate) { |attribute, resource, options| "hydrated_#{attribute}" }
      allow(extension_attr_attribute_serializer_class).to receive(:hydrate) { |attribute, resource, options| "serialized_#{attribute}" }
      subject
    end
    it { expect(customizer_attribute_serializer_class).to have_received(:hydrate).with('hello', resource, options) }
    it { expect(extension_attr_attribute_serializer_class).to_not have_received(:hydrate).with('hello', resource, options) }
    it { expect(subject).to eq({'custom_attr' => 'hydrated_hello', 'explicit_attr' => 'world'}) }
  end

  describe ".set_resource_attribute" do
    subject { instance.send(:set_resource_attribute, field, value) }
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
