#TODO --jdc comment this class
module ActiveFacets
  class Filter
    cattr_accessor :filters, :global_filters
    self.filters, self.global_filters = {}, {}

    def self.register_global(name, proc)
      global_filters[name] = proc
    end

    def self.register(receiver, filter_name, filter_method_name)
      receiver_filters = filters[receiver.name] ||= {}
      receiver_filters[filter_name.to_sym] = filter_method_name.to_sym
      receiver_filters
    end

    def self.apply_globals_to(receiver)
      global_filters.each do |filter_name, filter_method|
        filter_method_name = receiver.acts_as_active_facet_options[:filter_method_name]
        receiver.send(filter_method_name, filter_name, &filter_method)
      end
    end

    #TODO --jdc memoize
    # @return [Hash] all filters registered on this resource (and superclass)
    def self.registered_filters_for(receiver)
      receiver_filters = filters[receiver.name] ||= {}
      receiver_filters.reverse_merge(registered_filters_for(receiver.superclass)) if filters_registered_for?(receiver.superclass)
      receiver_filters
    end

    def self.filters_registered_for?(receiver)
      filters.key?(receiver.name)
    end
  end
end