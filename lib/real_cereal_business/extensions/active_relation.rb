require 'active_support/all'
require 'active_record/relation'

#NOTE:: strive for minimal method footprint over strict OO because this mixes into Rails Core
module RealCerealBusiness
  module Extensions
    module ActiveRelation
      extend ActiveSupport::Concern

      included do
        alias_method_chain :as_json, :real_cereal_business_caching
      end

      # Overrides default as_json behavior when RCB key is present, serializer is registered.
      # Caches serialized results
      # @param options [Hash]
      # @return [JSON]
      def as_json_with_real_cereal_business_caching(options = nil)
        if options.present? && options.key?(RealCerealBusiness.json_attribute_key) &&
            (serializer = RealCerealBusiness::ResourceManager.new.serializer_for(self.klass)).present?
          collection = PerformanceMonitor.measure(:active_record) { to_a }
          serializer.association_cache.perform(collection) do
            collection.as_json(options)
          end
        else
          as_json_without_real_cereal_business_caching(options)
        end
      end
    end
  end
end