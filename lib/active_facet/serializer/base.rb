# Mixin providing DSL for ActiveFacet Serializers and a handful of public methods which reflect on the DSL
module ActiveFacet
  module Serializer
    module Base
      extend ActiveSupport::Concern
      included do
        include ActiveFacet::ResourceInflector
        delegate :resource_class, :resource_attribute_name, to: :config
      end

      module ClassMethods
        # ###
        # DSL
        # ###

        # DSL Defines a transform to rename or reformat an attribute
        # @param facet [Symbol] name of the attribute
        # @param options [Hash]
        # @option options [Symbol] :as internal method name to call on the resource for serialization and hydration
        # @option options [Symbol] :from internal method name to call on the resource for serialization
        # @option options [Symbol] :to internal method name to call on the resource for hydration
        # @option options [Symbol] :with name of a CustomAttributeSerializer Class for serialization and hydration
        # @option options [Symbol] :within name of nested json attribute to serialize/hyrdrate within
        def transform(facet, options = {})
          if options[:as].present?
            config.transforms_from[facet]  = options[:as]
            config.transforms_to[facet] = options[:as]
          end
          if options[:from].present?
            config.transforms_from[facet] = options[:from]
            config.transforms_to[facet] ||= options[:from]
          end
          if options[:to].present?
            config.transforms_from[facet] ||= options[:to]
            config.transforms_to[facet] = options[:to]
          end
          config.serializers[facet] = options[:with]    if options[:with].present?
          config.namespaces[facet]  = options[:within]  if options[:within].present?
          expose facet
        end

        # DSL Defines an extension for decoration of serialized output
        # @param facet [Symbol] name of the attribute
        def extension(facet)
          config.extensions[facet] = true
          config.serializers[facet] = facet.to_sym
          expose facet
        end

        # DSL Defines an alias that can be used in lieu of an explicit Facet
        # @param facet [Symbol] the alias name
        # @param options [Hash]
        # @option as [MIXED] a nested facet collection
        def expose(facet, options = {})
          facet = facet.to_sym
          raise ActiveFacet::Errors::ConfigurationError.new(ActiveFacet::Errors::ConfigurationError::ALL_ATTRIBUTES_ERROR_MSG) if facet == :all_attributes
          raise ActiveFacet::Errors::ConfigurationError.new(ActiveFacet::Errors::ConfigurationError::ALL_FIELDS_ERROR_MSG) if facet == :all
          config.alias_facet(facet, options.key?(:as) ? options[:as] : facet)
        end

        #DSL Defines an alias for common ActiveRecord attributes
        def expose_timestamps
          transform :created_at, with: :time
          transform :updated_at, with: :time
          expose :timestamps, as: [:id, :created_at, :updated_at]
        end

        #DSL Registers the class type this serializer describes
        def resource_class(klass)
          config.resource_class = klass
        end

        # ###
        # Public Interface
        # ###

        # Singleton
        # @return [Serializer::Base]
        def instance
          @instance ||= new
        end

        # Memoized class getter
        # @return [Config]
        def config
          @config ||= ActiveFacet::Config.new
        end
      end

      # INSTANCE METHODS

      # TODO --jdc reimplement and rename
      # This method returns a hash suitable to pass into ActiveRecord.includes to avoid N+1
      # @param facet [Facet] collections of fields to be serialized from this resource later
      # given:
      #  :basic is a defined collection
      #  :extended is a defined collection
      #  :orders is a defined association
      #  :line_items is a defined association on OrderSerializer
      # examples:
      #  :basic
      #  [:basic]
      #  {basic: nil}
      #  [:basic, :extended]
      #  [:basic, :extended, :orders]
      #  [:basic, :extended, {orders: :basic}]
      #  [:basic, :extended, {orders: [:basic, :extended]}]
      #  [:basic, :extended, {orders: [:basic, :line_items]}]
      #  [:basic, :extended, {orders: [:basic, {line_items: :extended}]}]
      # @return [Hash]
      def scoped_includes(facet = nil, options = {})
        result = {}
        config.facet_itterator(facet) do |field, nested_facet|
          case value = scoped_include(field, nested_facet, options)
          when nil
          when Hash
            result.deep_merge! value
          else
            result[value] ||= nil
          end
        end
        result
      end

      # TODO --jdc reimplement and rename
      # Gets flattened fields from a Facet Alias
      # @param facet [Symbol] to retrieve fields for
      # @param include_relations [Boolean]
      # @param include_nested_facets [Boolean]
      # @return [Array] of symbols
      def exposed_aliases(facet = :all, include_relations = false, include_nested_facets = false)
        return include_nested_facets ? facet : [facet] unless normalized_facets = config.normalized_facets[facet]
        result = normalized_facets[include_relations ? :fields : :attributes]
        return result if include_nested_facets
        result.keys.map(&:to_sym).sort
      end

      # Returns a resource instance updated with the attributes given
      # @param resource [Class] to hydrate
      # @param attributes [Hash] a subset of the values returned by {resource.as_json}
      # @param options [Hash] collection of values required that are not available in lexical facet
      # @return [Class] resource
      def from_hash(resource, attributes, options = {})
        ActiveFacet::Serializer::Facade.new(self, resource, options).from_hash(attributes)
      end

      # This method returns a JSON of hash values representing the resource(s)
      # @param resources [Class || Array] CollectionProxy object ::or:: a collection of resources
      # @param options [Hash] collection of values required that are not available in lexical facet
      # @return [JSON] fields defined by the facet
      def as_json(resources, options = {})
        resource_itterator(resources) do |resource|
          facade = ActiveFacet::Serializer::Facade.new(self, resource, options)
          facade.as_json
        end
      end

      # Memoized instance getter
      # @return [Config]
      def config
        @config ||= self.class.config
      end

      protected

      # @return [Serializer::Base]
      def initialize
        config.compile!
      rescue SystemStackError => e
        raise ActiveFacet::Errors::ConfigurationError.new(ActiveFacet::Errors::ConfigurationError::STACK_ERROR_MSG)
      end

      # Iterates a resource collection invoking block
      # @param resource [ActiveRecord || Array] to traverse
      # @param block [Block] to call for each resource
      def resource_itterator(resource)
        if resource.is_a?(Array)
          resource.map do |resource|
            yield resource
          end.compact
        else
          yield resource
        end
      end

      # TODO --jdc reimplement and rename
      # Returns fully normalized facet
      # @param field [Field]
      # @param nested_facet [Field]
      # @param options [Hash] collection of values required that are not available in lexical facet
      # @return [Facet]
      def scoped_include(field, nested_facet, options)
        if is_association? field
          attribute = resource_attribute_name(field)
          if nested_facet
            serializer_class = get_association_serializer_class(field, options)
            attribute = { attribute => serializer_class.present? ? serializer_class.scoped_includes(nested_facet, options) : nested_facet }
          end
          attribute
        else
          custom_includes(field, options)
        end
      end

      # TODO --jdc reimplement and rename
      # Returns fully normalized facet for custom attribute serializers & extensions
      # @param field [Field]
      # @param options [Hash] collection of values required that are not available in lexical facet
      # @return [Facet]
      def custom_includes(field, options)
        attribute = resource_attribute_name(field)
        custom_serializer_name = config.serializers[attribute]

        if custom_serializer_name
          custom_serializer = get_custom_serializer_class(custom_serializer_name, options)
          if custom_serializer.respond_to? :custom_scope
            custom_serializer.custom_scope
          else
            options[:return_attribute].present? ? attribute : nil
          end
        else
          options[:return_attribute].present? ? attribute : nil
        end
      end
    end
  end
end