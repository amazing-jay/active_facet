module RealCerealBusiness
  class DocumentCache
    CACHE_PREFIX = 'rcb_doc_cache'

    # Fetches from Rails Cache or invokes block on miss or force
    # @param serializer [Object] to cache
    # @param options [Hash] for Rails.cache.fetch
    # @param &block [Proc] for cache miss
    # @return [Object]
    def self.fetch(serializer, options = {})
      return yield unless cacheable?(serializer)

      options[:force] ||= serializer.opts[RealCerealBusiness.cache_force_key]
      cache_key = digest_key(serializer)
      if options[:force] || !(result = Rails.cache.fetch(cache_key))
        result = yield
        Rails.cache.write(cache_key, Oj.dump(result), RealCerealBusiness::default_cache_options.merge(options))
        result
      else
        Oj.load(result)
      end

      # force = options[:force] || serializer.opts[RealCerealBusiness.cache_force_key]

      # # didn't use Rails.cache.fetch(cache_key, because it be slower with interprelation
      # #TODO --jdc fetch larger documents and pluck field_overrides
      # #TODO --integrate Oj here for both load and dump
      # if force.blank? && Rails.cache.exist?(cache_key)
      #   JSON.parse Rails.cache.fetch(cache_key)
      # else
      #   result = yield
      #   Rails.cache.write(cache_key, result.to_json, RealCerealBusiness::default_cache_options.merge(options))
      #   result
      # end
    end

    private

    # Salts and hashes serializer cache_key
    # @param serializer [Facade] to generate key for
    # @return [String]
    def self.digest_key(serializer)
      Digest::MD5.hexdigest(CACHE_PREFIX + serializer.cache_key.to_s)
    end

    # Tells if the resource to be serialized can be cached
    # @param serializer [Facade] to inspect
    # @return [Boolean]
    def self.cacheable?(serializer)
      RealCerealBusiness.cache_enabled
    end
  end
end