# Implements varius methods that bind serializers and resources together
module ActiveFacet
  class Helper
    # Memoizes resource_mapper results
    cattr_accessor :memoized_resource_map
    self.memoized_resource_map = {}

    # Memoizes serializer_mapper results
    cattr_accessor :memoized_serializers
    self.memoized_serializers = {}

    # Default resource mapping scheme, can be replaced with a custom implementation
    # @param resource_class [Class]
    # @return [Array] of Strings for use by filters and field configurations
    def self.default_resource_mapper(resource_class)
      map = []
      until(resource_class.superclass == BasicObject) do
        map << resource_class.name.tableize
        resource_class = resource_class.superclass
      end
      map
    end

    # Holds reference to resource_mapper method (configurable)
    cattr_accessor :resource_mapper
    self.resource_mapper = method(:default_resource_mapper)

    # Fetches the set of keys the resource_class might appear as for Filters and Fields
    # Memoized
    # @param resource_class [Object]
    # @return [Array] of Strings
    def self.resource_map(resource_class)
      memoized_resource_map[resource_class] ||= begin
        resource_mapper.call(resource_class)
      end
    end

    # Default serializer mapping scheme, can be overrided with config
    # Memoized
    # @param resource_class [Class]
    # @return [Serializer::Base | Class]
    def self.default_serializer_mapper(resource_class, serializer, type, version, options)
      key = [resource_class.name, serializer.to_s, type.to_s.camelcase, version].join(".")
      return memoized_serializers[key] if memoized_serializers.key?(key)
      memoized_serializers[key] = internal_serializer_mapper(resource_class, serializer, type, version, options)
    end

    # Holds reference to serializer_mapper method (configurable)
    cattr_accessor :serializer_mapper
    self.serializer_mapper = method(:default_serializer_mapper)

    # TODO --jdc implement recursive superclass/parentclass lookup
    # Default serializer mapping scheme, can be overrided with config
    # @param resource_class [Class]
    # @return [Serializer::Base | Class]
    def self.internal_serializer_mapper(resource_class, serializer, type, version, options)
      case type
      when :serializer
        [
          'V' + version.to_i.to_s + '::' + resource_class.name.camelcase + '::' + resource_class.name.camelcase + type.to_s.camelcase,
          'V' + version.to_i.to_s + '::' + resource_class.name.camelcase + type.to_s.camelcase,
        ].each { |name|
          klass = name.safe_constantize
          return klass.instance if klass.present?
        }
      else
        [
          'V' + version.to_i.to_s + '::' + resource_class.name.camelcase + '::' + serializer + type.to_s.camelcase,
          'V' + version.to_i.to_s + '::' + serializer + type.to_s.camelcase,
        ].find { |name|
          klass = name.safe_constantize
          return klass if klass.present?
        }
      end
    end

    # Fetches the serializer registered for a resource_class
    # @param resource_class [Object] to find serializer for
    # @param options [Hash] context
    # @return [Serializer::Base]
    def self.serializer_for(resource_class, options)
      fetch_serializer(resource_class, resource_class.name.demodulize.to_s.camelcase, :serializer, options)
    end

    # Fetches the attribute serializer registered for the given resource_class
    # @param resource_class [Object] to find attribute serializer class for
    # @param attribute_class_name [String] to find attribute serializer class for
    # @param options [Hash] context
    # @return [Class]
    def self.attribute_serializer_class_for(resource_class, attribute_name, options)
      fetch_serializer(resource_class, attribute_name.to_s.camelcase, :attribute_serializer, options)
    end

    # Retrieves the first serializer successfully described by the parameters
    # @param resource_class [Class] the class of the resource to serialize
    # @param serializer [String] name of the base_class of the resource to serialize
    # @param type [String] type of serializer to look for (attribute vs. resource)
    # @param options [Hash] context
    # @return [Serializer::Base | Class]
    def self.fetch_serializer(resource_class, serializer, type, options)
      version = extract_version_from_opts(options)
      unless result = serializer_mapper.call(resource_class, serializer, type, version, options)
        error_message = "Unable to locate serializer for:: " + [resource_class.name, serializer, type, version].to_s
        Rails.logger.debug error_message
        raise ActiveFacet::Errors::LookupError.new(error_message) if ActiveFacet.strict_lookups
      end
      result
    end

    # Safely extracts version from options hash
    # @param options [Hast] including opts
    # @return [Numeric]
    def self.extract_version_from_opts(options)
      ((options.try(:[], ActiveFacet.opts_key) || {})[ActiveFacet.version_key] || ActiveFacet.default_version).to_f
    end

    # Safely extracts fields from options hash
    # @param options [Hast] including opts
    # @return [Facet]
    def self.fields_from_options(options)
      (options[ActiveFacet.opts_key] || {})[ActiveFacet.fields_key]
    end

    # Safely injects fields into options hash
    # @param options [Hast] including opts
    # @param fields [Symbol]
    # @return [Hash]
    def self.options_with_fields(options, fields)
      (options[ActiveFacet.opts_key] ||= {})[ActiveFacet.fields_key] = fields
      options
    end

    # Resets the given key in options[opts_key] to original value after
    # injecting value provided and executing block
    # @param options [Hast] including opts
    # @param key [Symbol]
    # @param value [Object]
    # @return [Hash]
    def self.restore_opts_after(options, key, value)
      opts = (options[ActiveFacet.opts_key] ||= {})
      old = opts[key]
      opts[key] = value
      yield
    ensure
      opts[key] = old
    end

    # Safe alternative to dup!
    # @param o [Object]
    # @return [o] full memory copy of o
    def self.deep_copy(o)
      Marshal.load(Marshal.dump(o))
    end

  end
end
