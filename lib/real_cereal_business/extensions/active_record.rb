require 'active_support/all'
require 'active_record'

#NOTE:: strive for minimal method footprint over strict OO because this mixes into Rails Core
module RealCerealBusiness
  module Extensions
    module ActiveRecord
      extend ActiveSupport::Concern

      mattr_accessor :filters
      self.filters = {}

      included do
        RealCerealBusiness::Extensions::ActiveRecord.filters.each do |filter_name, filter_method|
          scope_filter filter_name, &filter_method
        end
      end

      # Extends AR allowing hydration of a model instance
      # @param attributes [Hash]
      # @return [ActiveRecord]
      def hydrate!(attributes)
        RealCerealBusiness::ResourceManager.new.serializer_for(self.class).from_hash(self, attributes)
      end

      # Overrides default serializer behavior when :group_includes option is present
      # @param options [Hash]
      # @return [JSON]
      def as_json(options = nil)
        if options.present? && options.key?(RealCerealBusiness.json_attribute_key) &&
            (serializer = RealCerealBusiness::ResourceManager.new.serializer_for(self.class)).present?
          serializer.association_cache.perform([self]) do
            serializer.as_json(self, options)
          end
        else
          super(options)
        end
      end

      module ClassMethods

        # Applies all filters registered with this resource on a ProxyCollection
        # @param filter_values [Hash] keys = registerd filter name, values = filter arguments
        def scope_filters(filter_values = nil)
          filter_values = (filter_values || {}).with_indifferent_access
          registered_scope_filters.inject(scoped) do |result, (k,v)|
            filter = RealCerealBusiness::ResourceManager.new.resource_map(self).detect { |map_entry|
              filter_values.keys.include? "#{k}_#{map_entry}"
            }
            args = filter_values["#{k}_#{filter}"] || filter_values[k]
            result.send(v, *args) || result
          end
        end

        # Registers a scope filter on this resource and subclasses
        # @param filter_name [Symbol] filter name
        # @param filter_method_name [Symbol] scope name
        def scope_filter(filter_name, filter_method_name = nil, &filter_method)
          filter_method_name ||= "registered_filter_#{filter_name}"
          singleton_class.send(:define_method, filter_method_name, filter_method) if filter_method

          #TODO --jdc remove this from AR namespace

          @inheritable_scope_filters ||= {}
          @inheritable_scope_filters[filter_name.to_sym] = filter_method_name.to_sym
          @inheritable_scope_filters
        end

        # Extends AR allowing hydration of a model class
        # @param attributes [Hash]
        # @return [ActiveRecord]
        def hydrate(attributes)
          self.new.hydrate!(attributes)
        end

        #TODO --jdc rename this

        # Invokes ProxyCollection.includes with a safe translation of groups
        # @param groups [Object]
        # @return [ProxyCollection]
        def group_includes(groups = :basic)
          includes RealCerealBusiness::ResourceManager.new.serializer_for(self).scoped_includes(groups)
        end

        private

        #TODO --jdc remove this from AR namespace

        # @return [Hash] all filters registered on this resource (and superclass)
        def registered_scope_filters
          result = @inheritable_scope_filters || {}
          result = superclass.send(:registered_scope_filters).merge(result) if superclass.respond_to?(:registered_scope_filters, true)
          result
        end
      end
    end
  end
end
