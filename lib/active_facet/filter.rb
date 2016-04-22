# Maps filters to resource classes without adding methods to the resource classes directly
module ActiveFacet
  class Filter

    # filters holds the resource/filter map for each resource
    # registered_filters holds the resource/filter map for each resource and all superclasses
    # global_filters queues a collection of filters that can be defined
    #   on any resource classes having called included and called acts_as_active_facet_options
    cattr_accessor :filters, :registered_filters, :global_filters
    self.filters, self.registered_filters, self.global_filters = {}, {}, {}

    # Queues a filter to be applied to resource classes
    # @param filter_name [Symbol]
    # @param filter_method [Proc] method body code which implements the filter
    # @return [Proc] for chaining
    def self.register_global(filter_name, filter_method)
      global_filters[filter_name.to_sym] = filter_method
    end

    # Tells that the receiver class implements a filter
    # @param receiver [Class] resource class
    # @param filter_name [Symbol]
    # @param filter_method_name [Symbol] name of method defined on receiver instances which implments the filter
    # @return [Class] for chaining
    def self.register(receiver, filter_name, filter_method_name)
      raise ActiveFacet::Errors::ConfigurationError.new(ActiveFacet::Errors::ConfigurationError::ACTS_AS_ERROR_MSG) unless filterable?(receiver)
      receiver_filters = filters[receiver.name] ||= {}
      receiver_filters[filter_name.to_sym] = filter_method_name.to_sym
      receiver
    end

    # Register queued filters for given resource class
    # @param receiver [Class] resource class
    # @return [Class] for chaining
    def self.apply_globals_to(receiver)
      raise ActiveFacet::Errors::ConfigurationError.new(ActiveFacet::Errors::ConfigurationError::ACTS_AS_ERROR_MSG) unless filterable?(receiver)
      global_filters.each do |filter_name, filter_method|
        filter_method_name = receiver.acts_as_active_facet_options[:filter_method_name]
        receiver.send(filter_method_name, filter_name, filter_method)
      end
      receiver
    end

    # (Memoized) Returns the list of filters the resource class implements
    # @param receiver [Class] resource class
    # @return [Hash] all filters registered on this resource (and superclass)
    def self.registered_filters_for(receiver)
      registered_filters[receiver.name] ||= begin
        receiver_filters = filters[receiver.name] ||= {}
        receiver_filters.reverse_merge!(registered_filters_for(receiver.superclass)) if filterable?(receiver.superclass)
        receiver_filters
      end
    end

    # Tells if any filters can be registered for the given resource class
    # @param receiver [Class] resource class
    # @return [Boolean]
    def self.filterable?(receiver)
      receiver.ancestors.include? ActiveFacet::ActsAsActiveFacet
    end
  end
end