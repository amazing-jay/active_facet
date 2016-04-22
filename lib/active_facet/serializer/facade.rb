# Serializes Facets of a given resource using an ActiveFacet::Serializer::Base serializer
module ActiveFacet
  module Serializer
    class Facade
      delegate :resource_class, to: :serializer

      attr_accessor :serializer,  # Serializer:Base
        :resource,                # Object to delegate to
        :options,                 # Options Hash passed to as_json
        :opts,                    # RCB specific options inside Options Hash
        :fields,                  # Facets to apply
        :field_overrides,         # Field Overrides to apply
        :overrides,               # Field Overrides specific to resource
        :version,                 # Serializer version to apply
        :filters,                 # Filters to apply
        :filters_enabled          # Apply Filters, override global setting

      # @return [Serializer::Facade]
      def initialize(serializer, resource, options = {})
        self.serializer       = serializer
        self.resource         = resource
        self.options          = options
        self.opts             = options[ActiveFacet.opts_key] || {}

        self.fields           = opts[ActiveFacet.fields_key]
        self.field_overrides  = opts[ActiveFacet.field_overrides_key] || {}
        self.overrides        = ActiveFacet::Helper.resource_map(resource_class).inject({}) { |overrides, map_entry|
          overrides.merge(field_overrides[map_entry] || {})
        }

        self.version          = opts[ActiveFacet.version_key]
        self.filters          = opts[ActiveFacet.filters_key]
        self.filters_enabled  = opts.key?(ActiveFacet.filters_force_key) ? opts[ActiveFacet.filters_force_key] : ActiveFacet.filters_enabled
      end

      # This method returns a JSON of hash values representing the resource
      # @param resource [ActiveRecord || Array] CollectionProxy object ::or:: a collection of resources
      # @param opts [Hash] collection of values required that are not available in lexical scope
      # @return [JSON] representing the values returned by {resource.serialize} method
      def as_json
        ActiveFacet.document_cache.fetch(self) {
          serialize!
        }
      end

      # @return [String] a cache key that can be used to identify this resource
      def cache_key
        version.to_s +
        resource.cache_key +
        fields.to_s +
        field_overrides.to_s +
        filters.to_s
      end

      # Returns a resource instance updated with the attributes given
      # @param attributes [Hash] a subset of the values returned by {resource.as_json}
      # @return [Class] resource
      def from_hash(attributes)
        hydrate! ActiveFacet::Helper.deep_copy(attributes)
      end

      private

      # @return [Config]
      def config
        @config ||= serializer.config
      end

      # @return [Boolean]
      def allowed_field?(field)
        overrides.blank? || overrides[field.to_sym]
      end

      # Tells if expression is a relation that is valid have filters applied to it
      # @param expression [Symbol]
      # @return [Boolean]
      def is_expression_scopeable?(expression)
        resource.persisted? && is_active_relation?(expression) && is_relation_scopeable?(expression)
      end

      # Tells if expression is a relation
      # @return [Boolean]
      def is_active_relation?(expression)
        #NOTE -jdc let me know if anyone finds a better way to identify Proxy objects
        #NOTE:: Proxy Collections use method missing for most actions; .scoped is the only reliable test
        expression.is_a?(ActiveRecord::Relation) || (expression.is_a?(Array) && expression.respond_to?(:scoped))
      end

      # Tells if filters are enabled for expression
      # @return [Boolean]
      def is_relation_scopeable?(expression)
        filters_enabled
      end

      # This method returns JSON of resource representing the facets provided
      # @return [JSON]
      def serialize!
        json = {}.with_indifferent_access
        config.facet_itterator(fields) do |scope, nested_scopes|
          begin
            json[scope] = get_resource_attribute scope, nested_scopes if allowed_field?(scope)
          rescue ActiveFacet::Errors::AttributeError => e
            # Deliberately do nothing. Ignore scopes that do not map to resource methods (or aliases)
          end
        end
        apply_custom_serializers! json
      end

      # Gets serialized field from the resource
      # @param field [Symbol]
      # @param facet [Facet] to pass for relations
      # @return [Mixed]
      def get_resource_attribute(field, facet)
        if config.namespaces.key? field
          if ns = get_resource_attribute!(config.namespaces[field])
            ns[serializer.resource_attribute_name(field).to_s]
          else
            nil
          end
        elsif config.extensions.key?(field)
          field
        elsif config.is_association?(field)
          get_association_attribute(field, facet)
        else
          get_resource_attribute!(serializer.resource_attribute_name(field))
        end
      end

      # Invokes a method on the resource to retrieve the attribute value
      # @param attribute [Symbol]
      # @return [Object]
      def get_resource_attribute!(attribute)
        raise ActiveFacet::Errors::AttributeError.new("#{resource.class.name}.#{attribute} missing") unless resource.respond_to?(attribute,true)
        resource.send(attribute)
      end

      # Retrieves scoped association from cache or record
      # @param field [Symbol] attribute to get
      # @param facet [Facet] to pass for relations
      # @return [Array | ActiveRelation] of ActiveRecord
      def get_association_attribute(field, facet)
        association = serializer.resource_attribute_name(field)

        ActiveFacet.document_cache.fetch_association(self, association, opts) do
          attribute = resource.send(association)
          attribute = attribute.scope_filters(filters) if is_expression_scopeable?(attribute)
          ActiveFacet::Helper.restore_opts_after(options, ActiveFacet.fields_key, facet) do
            attribute.as_json(options)
          end
        end
      end

      # Modifies json by reference by applying custom serializers to all attributes registered with custom serializers
      # @param json [JSON] structure
      # @return [JSON]
      def apply_custom_serializers!(json)
        config.serializers.each do |scope, type|
          scope_s = scope
          json[scope_s] = ActiveFacet::Helper.restore_opts_after(options, ActiveFacet.fields_key, fields) do
            serializer.get_custom_serializer_class(type, options).serialize(json[scope_s], resource, options)
          end if json.key? scope_s
        end

        json
      end

      # Returns the resource instance updated to match hash attibutes
      # @param attributes [JSON] subset of the values returned by {serialize}
      # @return [ActiveRecord] resource
      def hydrate!(attributes)
        filter_allowed_keys! attributes, serializer.exposed_aliases
        hydrate_scopes! attributes
        attributes.each do |scope, value|
          set_resource_attribute scope, value
        end

        resource
      end

      # Modifies json in place, removing all attributes which aren't explicitely exposed
      # @param json [JSON] structure
      # @param keys [Array] of attributes
      # @return [JSON]
      def filter_allowed_keys!(json, keys)
        values = json.with_indifferent_access
        json.replace ( keys.inject({}.with_indifferent_access) { |results, key|
          results[key] = values[key] if values.key?(key)
          results
        } )
      end

      # Modifies json in place, applying custom hydration to all fields registered with custom serializers
      # @param json [JSON] structure
      # @return [JSON]
      def hydrate_scopes!(json)
        config.serializers.each do |scope, type|
          scope_s = scope
          json[scope_s] = serializer.get_custom_serializer_class(type, options).hydrate(json[scope], resource, options) if json.key? scope_s
        end
        json
      end

      # Sets the specified attribute on the resource
      # @param field [Symbol] to set
      # @param value [Mixed] to set
      # @return [Mixed] for chaining
      def set_resource_attribute(field, value)
        if config.namespaces.key? field
          resource.send(config.namespaces[field].to_s+"=", {}) unless resource.send(config.namespaces[field]).present?
          resource.send(config.namespaces[field])[serializer.resource_attribute_name(field,:to).to_s] = value
        else
          resource.send("#{serializer.resource_attribute_name(field,:to)}=", value)
        end
      end
    end
  end
end
