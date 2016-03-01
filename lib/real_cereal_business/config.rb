# Field = Symbol representing a json attribute that corresponds to resource attributes or extensions

# Field Set = Nested, Mixed Collection of Fields, Aliases, and Relations (Strings, Symbols, Arrays and Hashes)
#  e.g. [:a, {b: "c"}]

# Normalized Field Set = Field Set with all Strings converted to Symbols, Aliases dealiased, and Arrays converted to Hashes

# Field Set Alias = Symbol representing a Field Set

module RealCerealBusiness
  class Config

    #TODO --decouple this class completely from serializer by moving reflection to resource_manager

    # Boolean: state
    attr_reader :compiled

    # Serializer::Base
    attr_reader :serializer

    # Hash: compiled field sets
    attr_reader :normalized_field_sets

    # Hash: keys are public API attribute names, values are resource attribute names
    attr_reader :transforms_from, :transforms_to

    # Hash: API attribute names requiring custom serialization
    attr_reader :serializers

    # Hash: keys are resource attribute names storing nested JSON, values are nested attribute names
    attr_reader :namespaces

    # Hash: keys are defined extension values
    attr_reader :extensions

    def alias_field_set(field_set_alias, field_set)
      self.compiled = false
      field_sets[field_set_alias] = field_set
    end

    # Returns Field to resource attribute map
    # @param direction [Symbol]
    # @return [Hash]
    def transforms(direction = :from)
      direction == :from ? transforms_from : transforms_to
    end

    # (Memoized) Normalizes all Field Set Aliases
    # @param serializer [Serializer::Base]
    # @return [Config]
    def compile!(serializer)
      self.serializer = serializer
      self.normalized_field_sets = { all: {} }.with_indifferent_access

      #aggregate all compiled field_sets into the all collection
      normalized_field_sets[:all][:fields] = field_sets.inject({}) do |result, (field_set_alias, field_set)|
        result = merge_field_sets(result, dealias_field_set!(field_set, field_set_alias)[:fields])
      end

      #filter all compiled field_sets into a corresponding attributes collection
      normalized_field_sets.each do |field_set_alias, normalized_field_set|
        normalized_field_set[:attributes] = normalized_field_set[:fields].reject { |field_set, nested_field_sets|
          serializer.send :is_association?, field_set
        }
      end

      self.compiled = true
      self
    end

    # Merges all ancestor accessors into self
    # @return [Config]
    def merge! config
      self.compiled = false
      transforms_from.merge!  config.transforms_from
      transforms_to.merge!    config.transforms_to
      serializers.merge!      config.serializers
      namespaces.merge!       config.namespaces
      field_sets.merge!       config.field_sets
      extensions.merge!       config.extensions

      self
    end

    # Invokes block on a Field Set with recursive, depth first traversal
    # @param field_set [Field Set] to traverse
    # @param block [Block] to call for each field
    # @return [Hash] injection of block results
    def field_set_itterator(field_set)
      raise RealCerealBusiness::Errors::ConfigurationError.new(RealCerealBusiness::Errors::ConfigurationError::COMPILED_ERROR_MSG) unless compiled
      internal_field_set_itterator(dealias_field_set!(default_field_set(field_set))[:fields], Proc.new)
    end

    protected

    attr_accessor :field_sets

    attr_writer :compiled, :serializer, :normalized_field_sets, :transforms_from, :transforms_to,
      :serializers, :namespaces, :extensions

    private

    #TODO --jdc change Serializer::Base to convert all Strings to Symbols and remove indifferent_access
    def initialize
      self.compiled = false
      self.transforms_from  = {}.with_indifferent_access
      self.transforms_to    = {}.with_indifferent_access
      self.serializers      = {}.with_indifferent_access
      self.namespaces       = {}.with_indifferent_access
      self.field_sets       = {}.with_indifferent_access
      self.extensions       = {}.with_indifferent_access
    end

    # (Memoized) Convert all Field Set Aliases to their declarations and Normalize Field Set
    # @param field_set [Symbol] to evaluate
    # @param field_set_alias [String] key to associate the evaluated field set with
    # @return [Normalized Field Set]
    def dealias_field_set!(field_set, field_set_alias = nil)
      field_set_alias ||= field_set.to_s.to_sym
      normalized_field_sets[field_set_alias] ||= begin
        PerformanceMonitor.measure("--:: dealias_field_set!") do
          { fields: normalize_field_set(dealias_field_set field_set) }
        end
      end
    end

    # Converts all Field Set Aliases in a Field Set into their declarations (see Serializer::Base DSL)
    # Recursively evaluates all aliases embedded within declaration
    # - Does not recursively evalute associations
    # @param field_set [Symbol] to evaluate
    # @return [Mixed]
    def dealias_field_set(field_set)
      case field_set
      when :all
        dealias_field_set serializer.exposed_aliases(:all, true, true)
      when :all_attributes
        dealias_field_set serializer.exposed_aliases
      when Symbol, String
        field_set = field_set.to_sym
        aliased_field_set?(field_set) ? dealias_field_set(field_sets[field_set]) : field_set
      when Array
        field_set.map do |s|
          dealias_field_set(s)
        end
      when Hash
        field_set.inject({}) { |result, (k,v)|
          v.blank? ? inject_field_set(result, dealias_field_set(k)) : result[k] = v #todo: symbolize
          result
        }
      end
    end

    # Converts Field Set into a Normalized Field Set that can be idempotently itterated
    # @param field_set [Symbol] to normalize
    # @return [Normalized Field Set]
    def normalize_field_set(field_set)
      case field_set
      when nil
        {}
      when Symbol, String
        {field_set.to_sym => nil}
      when Array
        field_set.flatten.compact.inject({}) do |result, s|
          result = merge_field_sets(result, s)
        end
      when Hash
        field_set.inject({}) { |result, (k,v)| result[k.to_sym] = v; result }
      end
    end

    # Adds :basic to a Field Set unless minimal is specified
    # @param field_set [Field Set] field set to be serialized
    # @return [Field Set]
    def default_field_set(field_set)
      minimal = detect_field_set(field_set, :minimal)
      case field_set
      when nil
        :basic
      when Symbol, String
        minimal ? field_set.to_sym : [field_set.to_sym, :basic]
      when Array
        minimal ? field_set : field_set + [:basic]
      when Hash
        field_set[:basic] = nil unless minimal
        field_set
      else
        raise RealCerealBusiness::Errors::ConfigurationError.new(RealCerealBusiness::Errors::ConfigurationError::FIELD_SET_ERROR_MSG)
      end
    end

    # Iterrates the first level of Field Set checking for key
    # @param field_set [Field Set]
    # @return [Boolean]
    def detect_field_set(field_set, key)
      case field_set
      when nil
        false
      when Symbol
        field_set == key
      when String
        field_set.to_sym == key
      when Array
        field_set.detect { |s| detect_field_set(s, key) }
      when Hash
        field_set.detect { |s, n| detect_field_set(s, key) }.try(:[], 0)
      else
        raise RealCerealBusiness::Errors::ConfigurationError.new(RealCerealBusiness::Errors::ConfigurationError::FIELD_SET_ERROR_MSG)
      end
    end

    # Invokes block on Fields in a Field Set with recursive, depth first traversal
    # Skips fields already processed
    # @param field_set [Field Set] to traverse
    # @param block [Block] to call for each field_set
    # @return [Hash] injection of block results
    def internal_field_set_itterator(field_set, block)
      array, hash = [], {}
      field_set.each do |field, nested_field_set|
        case value = block.call(field, nested_field_set)
        when nil
        when Hash
          #flatten nested hashes
          hash.merge! value
        else
          hash[value] ||= nil
        end
      end
      hash.reject! do |field, nested_field_set|
        if nested_field_set.blank?
          array << field
          true
        else
          false
        end
      end
      array << hash unless hash.blank?
      array.size > 1 ? array : array.first
    end

    # Adds a Field into a Normalized Field Set
    # @param field_set [Normalized Field Set]
    # @param key [Field Set]
    # @return [Hash]
    def inject_field_set(field_set, key)
      case key
      when Symbol, String
        field_set[key.to_sym] = {}
      when Hash
        field_set.merge! key
      when Array
        key.each { |k| inject_field_set(field_set, k) }
      end
    end

    # Tells if the Field is a Field Set Alias
    # @param field_set [Symbol] to evaluate
    # @return [Boolean]
    def aliased_field_set?(field_set)
      return false unless field_sets.key? field_set
      v = field_sets[field_set]
      !v.is_a?(Symbol) || v != field_set
    end

    # Recursively merges two Field Sets
    # @param a [Symbol] to merge
    # @param b [Symbol] to merge
    # @return [Field Set]
    def merge_field_sets(a, b)
      na = normalize_field_set(a)
      nb = normalize_field_set(b)
      nb.inject(na.dup) do |result, (field_set, nested_field_sets)|
        result[field_set] = merge_field_sets(na[field_set], nested_field_sets)
        result
      end
    end

  end
end