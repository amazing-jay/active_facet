module RealCerealBusiness
  module Serializer
    class Facade
      attr_accessor :serializer,  # Serializer:Base
        :resource,                # Object to delegate to
        :options,                 # Options Hash passed to as_json
        :opts,                    # RCB specific options inside Options Hash
        :fields,                  # Field Sets to apply
        :field_overrides,         # Field Overrides to apply
        :overrides,               # Field Overrides specific to resource
        :version,                 # Serializer version to apply
        :filters                  # Filters to apply

      # @return [Serializer::Facade]
      def initialize(serializer, resource, options = {})
        self.serializer       = serializer
        self.resource         = resource
        self.options          = options
        self.opts             = options[RealCerealBusiness.opts_key] || {}

        self.fields           = opts[RealCerealBusiness.fields_key]
        self.field_overrides  = opts[RealCerealBusiness.field_overrides_key] || {}
        self.overrides        = RealCerealBusiness::ResourceManager.new.resource_map(resource_class).inject({}) { |overrides, map_entry|
          overrides.merge(field_overrides[map_entry] || {})
        }

        self.version          = opts[RealCerealBusiness.version_key]
        self.filters          = opts[RealCerealBusiness.filters_key]
      end

      # This method returns a JSON of hash values representing the resource
      # @param resource [ActiveRecord || Array] CollectionProxy object ::or:: a collection of resources
      # @param opts [Hash] collection of values required that are not available in lexical scope
      # @return [JSON] representing the values returned by {resource.serialize} method
      def as_json
        RealCerealBusiness.document_cache.fetch(self) { serialize! }
      end

      # @return [String] a cache key that can be used to identify this resource
      def cache_key
        [
          resource.cache_key,
          fields,
          field_overrides,
          filters
        ].to_s
      end

      # This method returns a ActiveRecord model updated to match a JSON of hash values
      # @param resource [ActiveRecord] to hydrate
      # @param attribute [Hash] subset of the values returned by {resource.as_json}
      # @return [ActiveRecord] resource
      def from_hash(attributes)
        hydrate! deep_copy(attributes)
      end

      private

      def deep_copy(o)
        Marshal.load(Marshal.dump(o))
      end

      # @return [Config]
      def config
        @config ||= serializer.config
      end

      # @return [Boolean]
      def allowed_field?(field)
        overrides.blank? || overrides[field.to_sym]
      end

      # Checks field to see if it is a relation that is valid have Field Sets applied to it
      # @param expression [Symbol]
      # @return [Boolean]
      def is_expression_scopeable?(expression)
        resource.persisted? && is_active_relation?(expression)
      end

      # Checks field to see if expression is a relation
      # @return [Boolean]
      def is_active_relation?(expression)
        #TODO -jdc let me know if anyone finds a better way to identify Proxy objects
        #NOTE:: Proxy Collections use method missing for most actions; .scoped is the only reliable test
        expression.is_a?(ActiveRecord::Relation) || (expression.is_a?(Array) && expression.respond_to?(:scoped))
      end

      #TODO --jdc this is a hack for assets. fix by making this class the primary entry point
      # rather than serializers and pass in resource class, or better yet, enforce pseudo resource classes
      # @return [Class]
      def resource_class
        resource.is_a?(ActiveRecord::Base) ? resource.class : serializer.resource_class
      end

      # This method returns a JSON of hash values representing the resource
      # @return [JSON]
      def serialize!
        json = {}.with_indifferent_access
        ::PerformanceMonitor.measure("scope_itteration") do
          config.field_set_itterator(fields) do |scope, nested_scopes|
            ::PerformanceMonitor.measure("attribute retrieval wrapper", self.class.name, scope, (resource.is_a?(Array) ? resource : resource.id)) do
              begin
                json[scope] = get_resource_attribute scope, nested_scopes if allowed_field?(scope)
              rescue RealCerealBusiness::Errors::AttributeError => e
                # Deliberately do nothing. Ignore scopes that do not map to resource methods (or aliases)
              end
            end
          end
        end

        serialize_scopes! json

        json
      end

      # Gets serialized field from the resource
      # @param field [Symbol]
      # @param nested_scope [Mixed] Field Set to pass for relations
      # @return [Mixed]
      def get_resource_attribute(field, nested_field_set)
        if config.namespaces.key? field
          ::PerformanceMonitor.measure("namespaced resource") do
            if ns = get_resource_attribute!(config.namespaces[field])
              ns[serializer.resource_attribute_name(field).to_s]
            else
              nil
            end
          end
        elsif config.extensions.key?(field)
          ::PerformanceMonitor.measure("extended resource") do
            field
          end
        elsif serializer.is_association?(field)
          attribute = ::PerformanceMonitor.measure("N+1 association loading", serializer.class.name, field, resource.try(:id)) do
            get_association_attribute(field)
          end
          ::PerformanceMonitor.measure("nested serialization", serializer.class.name, field, resource.try(:id)) do
            #TODO --jdc do we need to deep copy?
            #o = deep_copy(options)
            old_field_set = options[RealCerealBusiness.opts_key][RealCerealBusiness.fields_key]
            options[RealCerealBusiness.opts_key][RealCerealBusiness.fields_key] = nested_field_set
            json = attribute.as_json(options)
            options[RealCerealBusiness.opts_key][RealCerealBusiness.fields_key] = old_field_set
            json
          end
        else
          #TODO: consider serializing everything instead of only associations.
          # Order#shipping_address, for example, is an ActiveRecord but not an association
          ::PerformanceMonitor.measure("basic resource", serializer.class.name, field, (resource.is_a?(Array) ? resource : resource.id)) do
            get_resource_attribute!(serializer.resource_attribute_name(field))
          end
        end
      end

      # Invokes a method on the resource to retrieve the attribute value
      # @param attribute [Symbol] identifies
      # @return [Object]
      def get_resource_attribute!(attribute)
        raise RealCerealBusiness::Errors::AttributeError.new("#{resource.class.name}.#{attribute} missing") unless ::PerformanceMonitor.measure(:attribute_reflection, self.class.name, attribute, (resource.is_a?(Array) ? resource : resource.id)) do
          resource.respond_to?(attribute,true)
        end
        ::PerformanceMonitor.measure(resource.is_a?(ActiveRecord::Base) && resource.class.attribute_names.include?(attribute.to_s) ? "native attribute" : "virtual attribute", self.class.name, attribute, (resource.is_a?(Array) ? resource : resource.id)) do
          resource.send(attribute)
        end
      end

      # Retrieves scoped association from cache or record
      # @param field [Symbol] attribute to get
      # @return [Array | ActiveRelation] of ActiveRecord
      def get_association_attribute(field)
        attribute = serializer.resource_attribute_name(field)
        key = [attribute, filters].to_s
        association = resource.send(attribute)
        association = association.scope_filters(filters) if is_expression_scopeable?(association)
        association
      end

      # Modifies json by reference by applying custom serializers to all attributes registered with custom serializers
      # @param json [JSON] structure
      # @return [JSON]
      def serialize_scopes!(json)
        config.serializers.each do |scope, type|
          ::PerformanceMonitor.measure(config.extensions.key?(scope) ? "extension" : "custom serializer", self.class.name, scope, (resource.is_a?(Array) ? resource : resource.id)) do
            scope_s = scope
            #TODO --jdc add as_json(options) to this call
            json[scope_s] = serializer.get_custom_serializer_class(type, options).serialize(json[scope_s], resource, options) if json.key? scope_s
          end
        end
        Hash[json.sort]
      end

      # This method returns a ActiveRecord model updated to match a JSON of hash values
      # @param json [JSON] attributes identical to the values returned by {serialize}
      # @return [ActiveRecord] resource
      def hydrate!(json)
        filter_allowed_keys! json, serializer.exposed_aliases
        hydrate_scopes! json
        json.each do |scope, value|
          set_resource_attribute scope, value
        end

        resource
      end

      # Modifies json by reference to remove all attributes from json which aren't exposed
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

      # Modifies json by reference by applying custom hydration to all fields registered with custom serializers
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