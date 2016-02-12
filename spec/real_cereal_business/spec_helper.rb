module TestHarnessHelper

  def test_resource_class
    ::ResourceA
  end

  def test_association_class
    ::ResourceB
  end

  def build_resource_serializer_class
    Class.new {
      include RealCerealBusiness::Serializer::Base

      #TODO --jdc remove this hack after decoupling serializers from filesystem
      def self.name
        '::ResourceBSerializer'
      end

      def resource_class
        ::ResourceA
      end
    }
  end

  def build_association_serializer_class
    Class.new {
      include RealCerealBusiness::Serializer::Base

      #TODO --jdc remove this hack after decoupling serializers from filesystem
      def self.name
        '::ResourceBSerializer'
      end

      def resource_class
        ::ResourceB
      end
    }
  end

  def build_attribute_serializer_class
    Class.new {
      def self.serialize(attribute, resource, options)
        "serialized_#{attribute}"
      end
      def self.hydrate(attribute, resource, options)
        "hydrated_#{attribute}"
      end
    }
  end

  def configure_serializer_class(resource_serializer_class, association_serializer_class, attribute_serializer_class)
    resource_serializer_class.class_eval do
      transform :explicit_attr, as: :explicit_attr
      transform :alias_attr, as: :aliased_accessor
      transform :from_attr, from: :from_accessor
      transform :to_attr, to: :to_accessor
      transform :nested_attr, within: :nested_accessor
      transform :custom_attr, with: :customizer
      transform :compound_attr, with: :customizer, as: :compound_accessor
      transform :nested_compound_attr, with: :customizer, as: :compound_accessor, within: :nested_compound_accessor
      extension :extension_attr

      expose :attrs, as: [:explicit_attr, :implicit_attr, :dynamic_attr, :private_attr, :alias_attr, :to_attr, :from_attr]
      expose :nested, as: [:nested_attr, :nested_compound_attr]
      expose :custom, as: [:custom_attr, :compound_attr, :nested_compound_attr]
      expose :minimal, as: [:explicit_attr]
      expose :basic, as: [:minimal, :nested_attr]
      expose :relations, as: [:parent, :child, :owner, :delegates]
      expose :alias_relation, as: [:others]
      expose :deep_relations, as: [
        {parent: {child: :attr}},
        {child: :attrs},
        :owner,
        {delegates: :minimal},
        {alias_relation: :implicit_attr}
      ]
    end

    #TODO --jdc remove this hack after decoupling serializers from filesystem
    allow(RealCerealBusiness::ResourceManager.new).to receive(:serializer_for) { nil }
    allow(RealCerealBusiness::ResourceManager.new).to receive(:serializer_for).with(test_resource_class) {  resource_serializer_class.new }
    allow(RealCerealBusiness::ResourceManager.new).to receive(:serializer_for).with(test_association_class) { association_serializer_class.new }
    allow(RealCerealBusiness::ResourceManager.new).to receive(:attribute_serializer_class_for) { nil }
    allow(RealCerealBusiness::ResourceManager.new).to receive(:attribute_serializer_class_for).with(test_resource_class, :customizer) { attribute_serializer_class }
    allow(RealCerealBusiness::ResourceManager.new).to receive(:attribute_serializer_class_for).with(test_resource_class, :extension_attr) { attribute_serializer_class }

    resource_serializer_class
  end
end
