# This is a really dump cache interface that caches everything when enabled
# Extend and conditionally cache independent documents
module ActiveFacet
  class DocumentCache
    CACHE_PREFIX = 'af_doc_cache'

    # Fetches a JSON document representing the facade
    # @param facade [Object] to cache
    # @param options [Hash] for Rails.cache.fetch
    # @param &block [Proc] for cache miss
    # @return [Object]
    def self.fetch(facade, options = {})
      return yield unless cacheable?(facade)

      force = facade.opts[ActiveFacet.cache_force_key] || options[:force] || ActiveFacet::default_cache_options[:force]
      cache_key = digest_key(facade)
      if force || !(result = Rails.cache.fetch(cache_key))
        result = yield
        Rails.cache.write(cache_key, ::Oj.dump(result), ActiveFacet::default_cache_options.merge(options).merge(force: force))
        result
      else
        ::Oj.load(result)
      end
    end

    # Fetches a JSON document representing the association specified for the resource in the facade
    # @param facade [Object] to cache
    # @param options [Hash] for Rails.cache.fetch
    # @param &block [Proc] for cache miss
    # @return [Object]
    def self.fetch_association(facade, association, options = {})
      # override and implement
      yield
    end

    private

    # Salts and hashes facade cache_key
    # @param facade [Facade] to generate key for
    # @return [String]
    def self.digest_key(facade)
      Digest::MD5.hexdigest(CACHE_PREFIX + facade.cache_key.to_s)
    end

    # Tells if the resource to be serialized can be cached
    # @param facade [Facade] to inspect
    # @return [Boolean]
    def self.cacheable?(facade)
      ActiveFacet.cache_enabled && facade.opts[ActiveFacet.cache_bypass_key].blank?
    end
  end
end