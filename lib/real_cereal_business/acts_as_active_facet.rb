#NOTE:: strive for minimal method footprint because this mixes into ActiveRecord

require 'active_support/all'
require 'active_record'

# TODO --jdc, change serializer scoped_includes, as_json & from_hash to be generic and add voerrides in initializer for www
#  when serializing, access cattr to determine method name to invoke
# add tests for the this module

module RealCerealBusiness
  module ActsAsActiveFacet
    extend ActiveSupport::Concern
      included do
      end

      module Filters
        mattr_accessor :filters, :global_filters
        self.filters, self.global_filters = {}, {}

        def self.apply_globals_to(receiver)
          global_filters.each do |filter_name, filter_method|
            filter_method_name = receiver.acts_as_active_facet_options[:filter_method_name]
            receiver.send(filter_method_name, filter_name, &filter_method)
          end
        end

        # @return [Hash] all filters registered on this resource (and superclass)
        def self.registered_filters_for(receiver)
          receiver_filters = filters[receiver.name] ||= {}
          receiver_filters.reverse_merge(registered_filters_for(receiver.superclass)) if has_registered_filters_for?(receiver.superclass)
          receiver_filters
        end

        def self.register_filter_for(receiver, filter_name, filter_method_name)
          receiver_filters = filters[receiver.name] ||= {}
          receiver_filters[filter_name.to_sym] = filter_method_name.to_sym
          receiver_filters
        end

        def self.has_registered_filters_for?(receiver)
          filters.key? receiver.name
        end

      end

      module ClassMethods
        def acts_as_active_facet(options = {})
          cattr_accessor :acts_as_active_facet_options

          acts_as_active_facet_options = options.deep_dup
          acts_as_active_facet_options[:unserialize_method_name]       ||= :from_json
          acts_as_active_facet_options[:unserialize_class_method_name] ||= :from_json
          acts_as_active_facet_options[:serialize_method_name]         ||= :as_json
          acts_as_active_facet_options[:includes_method_name]          ||= :facet_includes
          acts_as_active_facet_options[:apply_includes_method_name]    ||= :apply_facet_includes
          acts_as_active_facet_options[:filter_method_name]            ||= :facet_filter
          acts_as_active_facet_options[:apply_filters_method_name]     ||= :apply_facet_filters

          class_eval do
            # Builds a new resource instance and unserializes it
            # @param attributes [Hash]
            # @param options [Hash]
            # @return [Resource]
            define_method(acts_as_active_facet_options[:unserialize_class_method_name]) do |attributes, options = {}|
              self.new.hydrate(attributes, options)
            end
          end

          # Unserializes a resource
          # @param attributes [Hash]
          # @param options [Hash]
          # @return [Resource]
          define_method(acts_as_active_facet_options[:unserialize_method_name]) do |attributes, options = {}|
            RealCerealBusiness::ResourceManager.instance.serializer_for(self.class, options).from_hash(self, attributes)
          end

          # Serializes a resource using facets
          # Falls back to default behavior when RCB key is not present
          # @param options [Hash]
          # @return [Hash]
          define_method(acts_as_active_facet_options[:serialize_method_name]) do |options = nil|
            if options.present? && options.key?(RealCerealBusiness.opts_key) &&
                (serializer = RealCerealBusiness::ResourceManager.instance.serializer_for(self.class, options)).present?
              serializer.as_json(self, options)
            else
              super(options)
            end
          end

          # Invokes ProxyCollection.includes with a safe translation of field_set
          # @param facets [Object]
          # @param options [Hash]
          # @return [ProxyCollection]
          define_method(acts_as_active_facet_options[:includes_method_name]) do |facets = :basic, options = {}|
            RealCerealBusiness::ResourceManager.instance.serializer_for(self, options).scoped_includes(facets)
          end

          # Invokes ProxyCollection.includes with a safe translation of field_set
          # @param field_set [Object]
          # @param options [Hash]
          # @return [ProxyCollection]
          define_method(acts_as_active_facet_options[:apply_includes_method_name]) do |facets = :basic, options = {}|
            includes(self.send(includes_method_name, facets, options))
          end

          # Registers a scope filter on this resource and subclasses
          # @param filter_name [Symbol] filter name
          # @param filter_method_name [Symbol] scope name
          define_method(acts_as_active_facet_options[:filter_method_name]) do |filter_name, filter_method_name = nil, &filter_method|
            filter_method_name ||= "registered_filter_#{filter_name}"
            define_singleton_method(filter_method_name, filter_method) if filter_method

            RealCerealBusiness::ActsAsActiveFacet::Filters.register_filter_for(receiver, filter_name, filter_method_name)
          end

          # Applies all filters registered with this resource on a ProxyCollection
          # @param filter_values [Hash] keys = registerd filter name, values = filter arguments
          define_method(acts_as_active_facet_options[:apply_filters_method_name]) do |filter_values = nil|
            filter_values = (filter_values || {}).with_indifferent_access
            RealCerealBusiness::ActsAsActiveFacet::Filters.registered_filters_for(self).inject(self) do |result, (k,v)|
              filter = RealCerealBusiness::ResourceManager.instance.resource_map(self).detect { |map_entry|
                filter_values.keys.include? "#{k}_#{map_entry}"
              }
              args = filter_values["#{k}_#{filter}"] || filter_values[k]
              result.send(v, *args) || result
            end
          end
        end
      end
    end
  end
end