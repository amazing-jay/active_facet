module RealCerealBusiness
  module Serializer
    module Base
      extend ActiveSupport::Concern

      module ClassMethods

        # ###
        # DSL
        # ###

        # See Readme.md

        # DSL Defines a transform to rename or reformat an attribute
        # @param api_attribute [Symbol] name of the attribute
        # @param options [Hash]
        # @option options [Symbol] :as internal method name to call on the resource for serialization and hydration
        # @option options [Symbol] :from internal method name to call on the resource for serialization
        # @option options [Symbol] :to internal method name to call on the resource for hydration
        # @option options [Symbol] :with name of a CustomAttributeSerializer Class for serialization and hydration
        # @option options [Symbol] :within name of nested json attribute to serialize/hyrdrate within
        def transform(api_attribute, options = {})
          if options[:as].present?
            config.transforms_from[api_attribute]  = options[:as]
            config.transforms_to[api_attribute] = options[:as]
          end
          if options[:from].present?
            config.transforms_from[api_attribute] = options[:from]
            config.transforms_to[api_attribute] ||= options[:from]
          end
          if options[:to].present?
            config.transforms_from[api_attribute] ||= options[:to]
            config.transforms_to[api_attribute] = options[:to]
          end
          config.serializers[api_attribute] = options[:with]    if options[:with].present?
          config.namespaces[api_attribute]  = options[:within]  if options[:within].present?
        end

        # DSL Defines an attribute extension available for decoration and serialization
        # @param api_attribute [Symbol] name of the attribute
        def extension(api_attribute)
          config.extensions[api_attribute] = true
          config.serializers[api_attribute] = api_attribute.to_sym
        end

        # DSL Defines an alias that can be used instead of a Field Set
        # @param field_set_name [Symbol] the alias name
        # @param options [Hash]
        # @option as [MIXED] a nested field_set collection
        def expose(field_set_name, options = {})
          field_set_name = field_set_name.to_sym
          raise RealCerealBusiness::Errors::ConfigurationError.new(RealCerealBusiness::Errors::ConfigurationError::ALL_ATTRIBUTES_ERROR_MSG) if field_set_name == :all_attributes
          raise RealCerealBusiness::Errors::ConfigurationError.new(RealCerealBusiness::Errors::ConfigurationError::ALL_FIELDS_ERROR_MSG) if field_set_name == :all
          config.alias_field_set(field_set_name, options.key?(:as) ? options[:as] : field_set_name)
        end

        #DSL Defines an alias for common ActiveRecord attributes
        def expose_timestamps
          transform :created_at, with: :time
          transform :updated_at, with: :time
          expose :timestamps, as: [:id, :created_at, :updated_at]
        end

        # ###
        # Public Interface
        # ###

        # Singleton
        # @return [Serializer::Base]
        def new
          @instance ||= super
        end

        # Memoized class getter
        # @return [Config]
        def config
          @config ||= RealCerealBusiness::Config.new
        end

      end

      # INSTANCE METHODS

      # This method returns a hash suitable to pass into ActiveRecord.includes to avoid N+1
      # @param field_set [Field Set] collections of fields to be serialized from this resource later
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
      def scoped_includes(field_set = nil, options = {})
        config.field_set_itterator(field_set) do |field_set, nested_field_sets|
          if is_association? field_set
            attribute = resource_attribute_name(field_set)
            if nested_field_sets
              serializer_class = get_association_serializer_class(field_set, options)
              attribute = { attribute => serializer_class.present? ? serializer_class.scoped_includes(nested_field_sets, options) : nested_field_sets }
            end
            attribute
          else
            nil
          end
        end
      end

      # Gets flattened fields from a Field Set Alias
      # @param field_set_alias [Symbol] to retrieve aliased field_sets for
      # @param include_relations [Boolean]
      # @param include_nested_field_sets [Boolean]
      # @return [Array] of symbols
      def exposed_aliases(field_set_alias = :all, include_relations = false, include_nested_field_sets = false)
        return include_nested_field_sets ? field_set_alias : [field_set_alias] unless normalized_field_sets = config.normalized_field_sets[field_set_alias]
        result = normalized_field_sets[include_relations ? :fields : :attributes]
        return result if include_nested_field_sets
        result.keys.map(&:to_sym).sort
      end

      # This method returns a ActiveRecord model updated to match a JSON of hash values
      # @param resource [ActiveRecord] to hydrate
      # @param attribute [Hash] subset of the values returned by {resource.as_json}
      # @return [ActiveRecord] resource
      def from_hash(resource, attributes, options = {})
        RealCerealBusiness::Serializer::Facade.new(self, resource, options).from_hash(attributes)
      end

      # This method returns a JSON of hash values representing the resource(s)
      # @param resource [ActiveRecord || Array] CollectionProxy object ::or:: a collection of resources
      # @param options [Hash] collection of values required that are not available in lexical field_set
      # @return [JSON] representing the resource
      def as_json(resources, options = {})
        ::WatchfulGuerilla.measure("(SBN): resource_itterator") do
          resource_itterator(resources) do |resource|
            facade = ::WatchfulGuerilla.measure("(SBN): facade") do
              RealCerealBusiness::Serializer::Facade.new(self, resource, options)
            end
            facade.as_json
          end
        end
      end

      # Memoized instance getter
      # @return [Config]
      def config
        @config ||= self.class.config
      end

      ### TODO --jdc ^^ START REFLECTOR
      # decouple this from the /lib/honest/serializers dependency using resource manager

      # Constantizes the appropriate resource serializer class
      # @return [Class]
      def resource_class
        @resource_class ||= constantize_resource_class(self.class.name.split("::")[2..-2],-1)
      end

      # Constantizes an appropriate resource serializer class for relations
      # @param field [Symbol] to find relation reflection for
      # @return [Reflection | nil]
      def get_association_reflection(field)
        @association_reflections ||= {}
        @association_reflections[field] ||= resource_class.reflect_on_association(resource_attribute_name(field).to_sym)
      end

      # Constantizes an appropriate resource serializer class
      # @param field [Symbol] to test as relation and find serializer class for
      # @return [Class | nil]
      def get_association_serializer_class(field, options)
        @association_serializers ||= {}
        unless @association_serializers.key? field
          @association_serializers[field] = nil
          #return nil if field isn't an association
          if reflection = get_association_reflection(field)
            #return nil if association doesn't have a custom class
            @association_serializers[field] = RealCerealBusiness::ResourceManager.new.serializer_for(reflection.klass, options)
          end
        end
        @association_serializers[field]
      end

      # Constantizes an appropriate attribute serializer class
      # @param attribute [Symbol] base_name of attribute serializer class to find
      # @param options [Hash]
      # @return [Class | nil]
      def get_custom_serializer_class(attribute, options)
        @custom_serializers ||= {}
        @custom_serializers[attribute] ||= RealCerealBusiness::ResourceManager.new.attribute_serializer_class_for(resource_class, attribute, options)
      end

      # Determines if public attribute maps to a private relation
      # @param field [Symbol] public attribute name
      # @return [Boolean]
      def is_association?(field)
        !!get_association_reflection(field)
      end

      # Renames attribute between resource.attribute_name and json.attribute_name
      # @param field [Symbol] attribute name
      # @param direction [Symbol] to apply translation
      # @return [Symbol]
      def resource_attribute_name(field, direction = :from)
        (config.transforms(direction)[field] || field).to_sym
      end

      ### TODO ^^ END REFLECTOR

      protected

      # @return [Serializer::Base]
      def initialize
        ::WatchfulGuerilla.measure("(SBN): initialize_scopes (cached in production)") do
          config.compile! self
        end
      rescue SystemStackError => e
        raise RealCerealBusiness::Errors::ConfigurationError.new(RealCerealBusiness::Errors::ConfigurationError::STACK_ERROR_MSG)
      end

      # Itterates a resource collection invoking block
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

      # Removes self.class_name from the end of self.module_name
      # @return [String]
      def module_base_name
        @module_base_name ||= module_name.deconstantize
      end

      # Removes self.class_name from the end of self.class.name
      # @return [String]
      def module_name
        @module_name ||= self.class.name.deconstantize
      end

      # Constantizes an appropriate resource serializer class
      # raises exception if not successful
      # @param names [Array] of strings attempt constantize
      # @param index [Integer] recursive cursor
      # @return [Class]
      def constantize_resource_class(names, index)
        raise RealCerealBusiness::Errors::ConfigurationError.new(RealCerealBusiness::Errors::ConfigurationError::RESOURCE_ERROR_MSG) if names.blank? || -index > names.size
        klass = names[index..-1].join("::").safe_constantize
        klass = constantize_resource_class(names, index-1) unless klass.present? && klass < ActiveRecord::Base
        klass
      end
    end
  end
end