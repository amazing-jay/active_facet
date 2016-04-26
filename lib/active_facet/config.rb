### Legend ###
# Attribute [Symbol] a getter/setter method defined on a resource
# Relation [Symbol] an association defined on an ActiveRecord resource
# Extension [Symbol] data that relates to a resource, but can not be accessed via Attribute
# Field [Symbol] a json value that corresponds to a resource Attribute, Relation or Extension
# Facet [Mixed] collection of Fields & nested Facets (Strings, Symbols, Arrays and Hashes)
#  e.g. [:a, {b: "c"}]
# Facet Alias [Facet] a Facet saved for later use
# Normalized Facet [Facet] with
#  Strings converted to Hashes of Symbols
#  Aliases converted to Hashes of Fields
#  Arrays converted to Hashes
#  and Duplicate Fields merged

module ActiveFacet
  class Config
    include ActiveFacet::ResourceInflector

    # Boolean: state
    attr_accessor :compiled

    # Hash: compiled Facets
    attr_accessor :normalized_facets

    # Hash: keys are public API attribute names, values are resource attribute names
    attr_accessor :transforms_from, :transforms_to

    # Hash: API attribute names requiring custom serialization
    attr_accessor :custom_serializers

    # Hash: keys are resource attribute names storing nested JSON, values are nested attribute names
    attr_accessor :namespaces

    # Hash: keys are defined extension values
    attr_accessor :extensions

    # Class: Resource Class to serialize
    attr_accessor :resource_class

    #TODO --jdc make setters for all config above symbolize
    #TODO --jdc iterate over facet and symbolize all strings
    # Store Facet
    # @param facet_alias [Symbol]
    # @param facet [Facet]
    def alias_facet(facet_alias, facet)
      self.compiled = false
      facets[facet_alias.to_sym] = facet
    end

    # Returns Field to resource attribute map
    # @param direction [Symbol]
    # @return [Hash]
    def transforms(direction = :from)
      direction == :from ? transforms_from : transforms_to
    end

    # (Memoized) Normalizes all Facet Aliases
    # @return [Config]
    def compile!
      self.normalized_facets = { all: {} }.with_indifferent_access

      #aggregate all compiled facets into the all collection
      normalized_facets[:all][:fields] = facets.inject({}) do |result, (facet_alias, facet)|
        result.deep_merge! dealias_facet!(facet, facet_alias)[:fields]
      end

      #filter all compiled facets into a corresponding attributes collection
      normalized_facets.each do |facet_alias, normalized_facet|
        normalized_facet[:attributes] = normalized_facet[:fields].reject { |facet, nested_facets|
          is_association?(facet)
        }
      end

      self.compiled = true
      self
    end

    # Merges all ancestor accessors into self
    # @param config [Config]
    # @return [Config]
    def merge!(config)
      self.compiled = false
      self.resource_class     ||= config.resource_class
      transforms_from.merge!      config.transforms_from
      transforms_to.merge!        config.transforms_to
      custom_serializers.merge!   config.custom_serializers
      namespaces.merge!           config.namespaces
      facets.merge!               config.facets #TODO --jdc change to a deep_merge!
      extensions.merge!           config.extensions

      self
    end

    # Invokes block for each field in Normalized Facet
    # Recursively evaluates all Aliases embedded within Facet
    # - Does not recursively evalute associations
    # @param facet [Facet]
    # @param block [Block] to call for each field
    # @return [Hash] injection of block results
    def facet_itterator(facet)
      raise ActiveFacet::Errors::ConfigurationError.new(ActiveFacet::Errors::ConfigurationError::COMPILED_ERROR_MSG) unless compiled
      internal_facet_itterator(dealias_facet!(default_facet(facet))[:fields], Proc.new)
    end

    # Translates Field into Attribute
    # @param field [Symbol]
    # @param direction [Symbol] (getter/setter)
    # @return [Symbol]
    def resource_attribute_name(field, direction = :from)
      (transforms(direction)[field] || field).to_sym
    end

    protected

    attr_accessor :facets

    private

    #TODO --jdc change Serializer::Base to convert all Strings to Symbols and remove indifferent_access
    def initialize
      self.compiled = false
      self.transforms_from          = {}.with_indifferent_access
      self.transforms_to            = {}.with_indifferent_access
      self.custom_serializers       = {}.with_indifferent_access
      self.namespaces               = {}.with_indifferent_access
      self.facets                   = {}.with_indifferent_access
      self.extensions               = {}.with_indifferent_access
    end

    # (Memoized) Convert all Facet Aliases into Fields and Normalize Facet
    # Recursively evaluates all Aliases embedded within Facet
    # - Does not recursively evalute associations
    # @param facet [Symbol] to evaluate
    # @param facet_alias [String] key to memoize the Normalized Facet with
    # @return [Normalized Facet]
    def dealias_facet!(facet, facet_alias = nil)
      facet_alias ||= facet.to_s.to_sym
      normalized_facets[facet_alias] ||= begin
        { fields: dealias_facet(facet) }
      end
    end

    # Convert all Facet Aliases into Fields and Normalize Facet
    # Recursively evaluates all Aliases embedded within Facet
    # - Does not recursively evalute associations
    # @param facet [Facet]
    # @return [Normalized Facet]
    def dealias_facet(facet)
      case facet
      when :all, 'all'
        normalized_facets[:all][:fields]
      when :all_attributes, 'all_attributes'
        normalized_facets[:all][:attributes]
      when Symbol, String
        facet = facet.to_sym
        aliased_facet?(facet) ? dealias_facet(facets[facet]) : { facet => {} }
      when Array
        facet.inject({}) do |result, f|
          result.deep_merge! dealias_facet(f)
        end
      when Hash
        facet.inject({}) { |result, (f, nf)|
          dealias_facet(f).each { |i_f, i_nf|
            result.deep_merge!({ i_f => merge_facets(i_nf, nf) })
          }
          result
        }
      end
    end

    # Converts Facet into a Normalized Facet that can be itterated easily
    # @param facet [Symbol]
    # @return [Normalized Facet]
    def normalize_facet(facet)
      case facet
      when nil
        {}
      when Symbol, String
        {facet.to_sym => nil}
      when Array
        facet.flatten.compact.inject({}) do |result, s|
          result = merge_facets(result, s)
        end
      when Hash
        facet.inject({}) { |result, (k,v)| result[k.to_sym] = v; result }
      end
    end

    # TODO --jdc add configuration for this
    # Adds :basic to a Facet unless minimal is specified
    # @param facet [Facet]
    # @return [Facet]
    def default_facet(facet)
      minimal = detect_facet(facet, :minimal)
      case facet
      when nil
        :basic
      when Symbol, String
        minimal ? facet.to_sym : [facet.to_sym] | [:basic]
      when Array
        minimal ? facet : facet | [:basic]
      when Hash
        facet[:basic] = nil unless minimal
        facet
      else
        raise ActiveFacet::Errors::ConfigurationError.new(ActiveFacet::Errors::ConfigurationError::FACET_ERROR_MSG)
      end
    end

    # Tells if a Facets containts a Field or Alias
    # Recursively evaluates all Aliases embedded within Facet
    # - Does not recursively evalute associations
    # @param facet [Facet]
    # @param key [Symbol]
    # @return [Boolean]
    def detect_facet(facet, key)
      case facet
      when nil
        false
      when Symbol
        facet == key
      when String
        facet.to_sym == key
      when Array
        facet.detect { |s| detect_facet(s, key) }
      when Hash
        facet.detect { |s, n| detect_facet(s, key) }.try(:[], 0)
      else
        raise ActiveFacet::Errors::ConfigurationError.new(ActiveFacet::Errors::ConfigurationError::FACET_ERROR_MSG)
      end
    end

    # Invokes block for each Field in a Facet
    # @param facet [Facet] to traverse
    # @param block [Block] to call for each facet
    # @return [Hash] injection of block results
    def internal_facet_itterator(facet, block)
      facet.each do |field, nested_facet|
        block.call(field, nested_facet)
      end
    end

    # Adds a Field to a Normalized Facet
    # @param facet [Normalized Facet]
    # @param key [Facet]
    # @return [Normalized Facet]
    def inject_facet(facet, key)
      case key
      when Symbol, String
        facet[key.to_sym] = {}
      when Hash
        facet.deep_merge! key
      when Array
        key.each { |k| inject_facet(facet, k) }
      end
      facet
    end

    # Tells if the Field is a Facet Alias
    # @param facet [Symbol] to evaluate
    # @return [Boolean]
    def aliased_facet?(facet)
      return false unless facets.key? facet
      v = facets[facet]
      !v.is_a?(Symbol) || v != facet
    end

    # Recursively merges two Normalized Facets (deep)
    # @param a [Normalized Facet] to merge
    # @param b [Normalized Facet] to merge
    # @return [Normalized Facet]
    def merge_facets(a, b)
      na = normalize_facet(a)
      nb = normalize_facet(b)
      nb.inject(na.dup) do |result, (facet, nested_facets)|
        result[facet] = merge_facets(na[facet], nested_facets)
        result
      end
    end
  end
end