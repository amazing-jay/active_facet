#TODO --jdc remove this hack after decoupling serializers from filesystem
module Support
  module RealCerealBusiness
    module TestHarnessHelper

      class TestTableless < ActiveRecord::Base
        def self.columns() @columns ||= []; end

        def self.column(name, sql_type = nil, default = nil, null = true)
          columns << ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, sql_type.to_s, null)
        end

        # Override the save method to prevent exceptions.
        def save(validate = true)
          validate ? valid? : true
        end
      end

      #declaration first
      class TestResource < TestTableless
      end

      class TestAssocation < TestTableless
      end

      module TestObj
        extend ActiveSupport::Concern

        included do
          attr_accessor :explicit_attr,
            :implicit_attr,
            :custom_attr,
            :nested_accessor,
            :dynamic_accessor,
            :private_accessor,
            :aliased_accessor,
            :from_accessor,
            :to_accessor,
            :compound_accessor,
            :nested_compound_accessor,
            :unexposed_attr

          belongs_to :parent, class_name: TestResource.name
          has_one :child, class_name: TestResource.name
          belongs_to :owner, class_name: TestAssocation.name
          has_many :delegates, class_name: TestAssocation.name
          has_many :others, class_name: TestAssocation.name
          has_many :extras, class_name: TestAssocation.name
        end

        def method_missing(method_sym, *arguments, &block)
          if method_sym == :dynamic_attr
            return dynamic_accessor
          elsif method_sym == :dynamic_attr=
            self.dynamic_accessor = arguments[0]
          end
        end

        private

        def private_attr
          private_accessor
        end

        def private_attr=(value)
          self.private_accessor = value
        end
      end

      #reopen class to avoid declaration sequence loop
      class TestResource
        include TestObj
      end

      class TestAssocation < TestTableless
        include TestObj
      end


      def test_resource_class
        ::Support::RealCerealBusiness::TestHarnessHelper::TestResource
      end

      def test_association_class
        ::Support::RealCerealBusiness::TestHarnessHelper::TestAssocation
      end

      def build_resource_serializer_class
        Class.new {
          include ::RealCerealBusiness::Serializer::Base

          #TODO --jdc remove this hack after decoupling serializers from filesystem
          def self.name
            '::Support::RealCerealBusiness::TestHarnessHelper::TestResourceSerializer'
          end

          def resource_class
            ::Support::RealCerealBusiness::TestHarnessHelper::TestResource
          end
        }
      end

      def build_association_serializer_class
        Class.new {
          include ::RealCerealBusiness::Serializer::Base

          #TODO --jdc remove this hack after decoupling serializers from filesystem
          def self.name
            '::Support::RealCerealBusiness::TestHarnessHelper::TestAssocationSerializer'
          end

          def resource_class
            ::Support::RealCerealBusiness::TestHarnessHelper::TestAssocation
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
        allow(::RealCerealBusiness::ResourceManager.new).to receive(:serializer_for) { nil }
        allow(::RealCerealBusiness::ResourceManager.new).to receive(:serializer_for).with(test_resource_class) {  resource_serializer_class.new }
        allow(::RealCerealBusiness::ResourceManager.new).to receive(:serializer_for).with(test_association_class) { association_serializer_class.new }
        allow(::RealCerealBusiness::ResourceManager.new).to receive(:attribute_serializer_class_for) { nil }
        allow(::RealCerealBusiness::ResourceManager.new).to receive(:attribute_serializer_class_for).with(test_resource_class, :customizer) { attribute_serializer_class }
        allow(::RealCerealBusiness::ResourceManager.new).to receive(:attribute_serializer_class_for).with(test_resource_class, :extension_attr) { attribute_serializer_class }

        resource_serializer_class
      end
    end
  end
end
