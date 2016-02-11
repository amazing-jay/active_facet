#TODO --jdc rebuild this class to either not use an explicit singleton pattern or use a factory pattern
#TODO --jdc refactor this class so lookups are not coupled with lib/honest/serializers file structure
module RealCerealBusiness
  class ResourceManager

    cattr_accessor :resource_mapper

    # Default resource mapping scheme, can be overrided with config
    def self.default_resource_mapper(resource_class)
      [].tap do |map|
        until(resource_class.superclass == BasicObject) do
          map << resource_class.name.tableize
          resource_class = resource_class.superclass
        end
      end
    end
    self.resource_mapper = method(:default_resource_mapper)

    # Singleton
    # @return [ResourceManager]
    def self.new
      @instance ||= super
    end

    # (Memoized) Associate a serializer with a resource_class
    # @param resource_class [Object]
    # @param serializer [Serializer::Base]
    # @param namespace [String] (TODO --jdc currently unused)
    # @return [Array]
    def register(resource_class, serializer, namespace = nil)
      registry[resource_class] = [serializer, namespace]
    end

    # Fetches the serializer registered for the resource_class
    # @param resource_class [Object] to find serializer for
    # @return [Serializer::Base]
    def serializer_for(resource_class)
      fetch_serializer_class(resource_class, resource_class.name.demodulize.to_s.camelcase, 'Serializer').try(:new)
    end

    # Fetches the attribute serializer registered for the given resource_class
    # @param resource_class [Object] to find attribute serializer class for
    # @param attribute_class_name [String] to find attribute serializer class for
    # @return [AttributeSerializer::Base]
    def attribute_serializer_class_for(resource_class, attribute_name)
      fetch_serializer_class(resource_class, attribute_name.to_s.camelcase, 'AttributeSerializer')
    end

    # Fetches the resource class registered for the serializer
    # @param serializer [Serializer::Base] to find resource class for
    # @return [Object]
    def resource_class_for(serializer)
      registry.each_pair do |resource_class, entry|
        return resource_class if serializer == entry[0]
      end
      nil
    end

    # Fetches the set of filter and field override indexes for resource_class
    # @param resource_class [Object]
    # @return [Array] of string indexes
    def resource_map(resource_class)
      memoized_resource_map[resource_class] ||= begin
        self.class.resource_mapper.call(resource_class)
      end
    end

    private

    attr_accessor :registry, :memoized_serializers, :memoized_resource_map

    # @return [ResourceManager]
    def initialize
      self.registry = {}
      self.memoized_serializers = {}
      self.memoized_resource_map = {}
    end

    # Retrieves serializer class from memory or lookup
    # @param resource_class [Class] the class of the resource to serialize
    # @param klass_name [String] name of the base_class of the resource to serialize
    # @param klass_type [String] type of serializer to look for (attribute vs. basic, etc.)
    # @return [Class] the first Class successfully described
    def fetch_serializer_class(resource_class, klass_name, klass_type)
      class_name = resource_class.name
      base_class_name = resource_class.base_class.name

      key = [base_class_name, class_name, klass_name, klass_type].join(".")
      return memoized_serializers[key] if memoized_serializers.key?(key)
      memoized_serializers[key] = lookup_serializer_class(base_class_name, class_name, klass_name, klass_type)
    end

    # Retrieves serializer class from lookup
    # @param base_class_name [String] name of the base_class of the resource to serialize
    # @param class_name [String] name of the class of the resource to serialize
    # @param klass_name [String] name of the base_class of the resource to serialize
    # @param klass_type [String] type of serializer to look for (attribute vs. basic, etc.)
    # @return [Class] the first Class successfully described
    def lookup_serializer_class(base_class_name, class_name, klass_name, klass_type)
      # NOTE:: lookup order matters
      # STI converts Bundle to Product
      klass_id = "#{klass_name}#{klass_type}"
      sti_klass_id = "#{base_class_name.demodulize}#{klass_type}"
      base_class_sti_klass_id = "#{base_class_name}::#{sti_klass_id}"

      lookups = [
        "#{klass_id}"
      ]

      explode_namespaced_paths(base_class_name, klass_id, lookups)
      explode_namespaced_paths(class_name, klass_id, lookups)

      if klass_type == 'Serializer'
        lookups.push base_class_sti_klass_id unless lookups.include? base_class_sti_klass_id
        lookups.push sti_klass_id unless lookups.include? sti_klass_id
      end

      lookup_serializer(lookups, klass_type == 'Serializer')
    end

    # Returns the first Class successfully described
    # @param lookups [Array] strings identifying possible classes
    # @param strict [Boolean] verify the constantized class is a v1 serializer
    # @return [Class]
    def lookup_serializer(lookups, strict)
      lookups.uniq.each do |lookup|
        klass = "::Honest::Serializers::#{lookup}".safe_constantize
        return klass if klass.present? && (!strict || klass.ancestors.include?(RealCerealBusiness::Serializer::Base))
      end
      nil
    end

    # Prepends several paths onto the collection
    # @param paths [String] namespace module chain to explode as prefixes
    # @param path [String] the suffix to append to each prefix chain
    # @param collection [Array] strings identifying possible classes
    # @return [Array]
    def explode_namespaced_paths(paths, path, collection)
      namespaces = paths.split("::")
      namespaces.inject("") do |ns, base|
        ns = ns.blank? ? base : [ns,base].join("::")
        prepend_namespaced_path "#{ns}::#{path}", collection
        ns
      end
    end

    # Prepends a path onto the collection if it doesn't exist already
    # @param path [String] the suffix to append to each prefix chain
    # @param collection [Array] strings identifying possible classes
    # @return [Array]
    def prepend_namespaced_path(path, collection)
      collection.unshift path unless collection.include? path
    end

  end
end
