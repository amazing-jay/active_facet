# Adds interface methods to resource classes
# NOTE:: methods are dynamically defined to achieve minimal method footprint because this mixes into ActiveRecord
module ActiveFacet
  module ActsAsActiveFacet
    extend ActiveSupport::Concern
    included do
    end

    module ClassMethods
      def acts_as_active_facet(options = {})
        raise ActiveFacet::Errors::ConfigurationError.new(ActiveFacet::Errors::ConfigurationError::DUPLICATE_ACTS_AS_ERROR_MSG) if respond_to?(:acts_as_active_facet_options)
        cattr_accessor :acts_as_active_facet_options

        # save to a local variable so its in scope during instance_eval below
        acts_as_active_facet_options = options.deep_dup
        acts_as_active_facet_options[:includes_method_name]          ||= :facet_includes
        acts_as_active_facet_options[:apply_includes_method_name]    ||= :apply_facet_includes
        acts_as_active_facet_options[:filter_method_name]            ||= :facet_filter
        acts_as_active_facet_options[:apply_filters_method_name]     ||= :apply_facet_filters
        acts_as_active_facet_options[:unserialize_method_name]       ||= :from_json
        acts_as_active_facet_options[:serialize_method_name]         ||= :as_json

        self.acts_as_active_facet_options = acts_as_active_facet_options

        (class << self; self; end).instance_eval do

          # Translates a Facet into a deeply nested hash of included associations suitable for use by includes
          # @param facet [Object]
          # @param options [Hash]
          # @return [Hash]
          define_method(acts_as_active_facet_options[:includes_method_name]) do |facet = :basic, options = {}|
            ActiveFacet::Helper.serializer_for(self, options).includes(facet)
          end

          # Invokes includes with all deeply nested associations found in the given Facet
          # @param facet [Object]
          # @param options [Hash]
          # @return [ProxyCollection]
          define_method(acts_as_active_facet_options[:apply_includes_method_name]) do |facet = :basic, options = {}|
            includes(self.send(acts_as_active_facet_options[:includes_method_name], facet, options))
          end

          # Registers a Filter for this resource
          # @param filter_name [Symbol]
          # @param filter_method_name [Symbol]
          # @return [Class] for chaining
          define_method(acts_as_active_facet_options[:filter_method_name]) do |filter_name, filter_method_name = nil, &filter_method|
            filter_method, filter_method_name = filter_method_name, nil if filter_method_name.is_a?(Proc)
            filter_method_name ||= "registered_filter_#{filter_name}"
            define_singleton_method(filter_method_name, filter_method) if filter_method
            ActiveFacet::Filter.register(self, filter_name, filter_method_name)
          end

          # Applies all filters registered for this resource
          # Arguments for filters are looked up by resource type, then without namespace
          # @param filter_values [Hash] keys = registerd filter name, values = filter arguments
          # @return [ProxyCollection]
          define_method(acts_as_active_facet_options[:apply_filters_method_name]) do |filter_values = nil|
            filter_values = (filter_values || {}).with_indifferent_access
            ActiveFacet::Filter.registered_filters_for(self).inject(scoped) do |scope, (filter_name, filter_method_name)|
              filter_resource_name = ActiveFacet::Helper.resource_map(self).detect { |filter_resource_name|
                filter_values.keys.include? "#{filter_name}_#{filter_resource_name}"
              }
              args = filter_values["#{filter_name}_#{filter_resource_name}"] || filter_values[filter_name]
              scope.send(filter_method_name, *args) || scope
            end
          end

          # Builds a new resource instance and unserializes it
          # @param attributes [Hash]
          # @param options [Hash]
          # @return [Resource]
          define_method(acts_as_active_facet_options[:unserialize_method_name]) do |attributes, options = {}|
            self.new.send(acts_as_active_facet_options[:unserialize_method_name], attributes, options)
          end
        end

        # Unserializes a resource
        # @param attributes [Hash]
        # @param options [Hash]
        # @return [Resource]
        define_method(acts_as_active_facet_options[:unserialize_method_name]) do |attributes, options = {}|
          ActiveFacet::Helper.serializer_for(self.class, options).unserialize(self, attributes)
        end

        # Serializes a resource with given Facets
        # Falls back to default behavior when key is not present
        # @param options [Hash]
        # @return [Hash]
        define_method(acts_as_active_facet_options[:serialize_method_name]) do |options = nil|
          if options.present? && options.key?(ActiveFacet.opts_key) &&
              (serializer = ActiveFacet::Helper.serializer_for(self.class, options)).present?
            serializer.serialize(self, options)
          else
            super(options)
          end
        end
      end
    end
  end
end