require 'w_g'
require 'active_support/all'
require 'active_record'

require 'active_facets/errors/attribute_error'
require 'active_facets/errors/configuration_error'
require 'active_facets/errors/lookup_error'
require 'active_facets/acts_as_active_facet'
require 'active_facets/serializer/base'
require 'active_facets/serializer/facade'
require 'active_facets/config'
require 'active_facets/document_cache'
require 'active_facets/resource_manager'
require 'active_facets/version'

module ActiveFacets
  mattr_accessor :opts_key,
    :fields_key,
    :field_overrides_key,
    :version_key,
    :filters_key,
    :cache_force_key,
    :filters_force_key,
    :strict_lookups,
    :preload_associations,
    :cache_enabled,
    :acts_as_active_facet_enabled,
    :filters_enabled,
    :default_cache_options,
    :document_cache,
    :default_version

  self.default_version                = 1.0
  self.opts_key                       = :af_opts
  self.fields_key                     = :fields
  self.field_overrides_key            = :field_overrides
  self.version_key                    = :version
  self.filters_key                    = :filters
  self.cache_force_key                = :cache_force
  self.filters_force_key              = :filters_force

  self.strict_lookups                 = false
  self.preload_associations           = false
  self.filters_enabled                = false
  self.cache_enabled                  = false
  self.acts_as_active_facet_enabled   = false
  self.default_cache_options          = { expires_in: 5.minutes }
  self.document_cache                 = ActiveFacets::DocumentCache

  def self.configure
    yield(self)
    ActiveRecord::Base.acts_as_active_facet if ActiveFacets.acts_as_active_facet_enabled
  end

  def self.global_filter(name)
    ActiveFacets::ActsAsActiveFacet.Filters[name] = Proc.new
  end

  def self.resource_mapper
    ActiveFacets::ResourceManager.resource_mapper = Proc.new
  end

  def self.serializer_mapper
    ActiveFacets::ResourceManager.serializer_mapper = Proc.new
  end

  def self.fields_from_options(options)
    (options[ActiveFacets.opts_key] || {})[ActiveFacets.fields_key]
  end

  def self.options_with_fields(options, fields)
    (options[ActiveFacets.opts_key] ||= {})[ActiveFacets.fields_key] = fields
    options
  end

  def self.restore_opts_after(options, key, value)
    opts = (options[ActiveFacets.opts_key] ||= {})
    old = opts[key]
    opts[key] = value
    yield
  ensure
    opts[key] = old
  end

  def self.deep_copy(o)
    Marshal.load(Marshal.dump(o))
  end
end

ActiveRecord::Base.send :include, ActiveFacets::ActsAsActiveFacet



