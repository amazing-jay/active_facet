require 'w_g'
require 'real_cereal_business/errors/attribute_error'
require 'real_cereal_business/errors/configuration_error'
require 'real_cereal_business/errors/lookup_error'
require 'real_cereal_business/extensions/active_record'
require 'real_cereal_business/extensions/active_relation'
require 'real_cereal_business/serializer/base'
require 'real_cereal_business/serializer/facade'
require 'real_cereal_business/config'
require 'real_cereal_business/document_cache'
require 'real_cereal_business/resource_manager'
require 'real_cereal_business/version'

module RealCerealBusiness
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
  self.opts_key                       = :rcb_opts
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
  self.document_cache                 = RealCerealBusiness::DocumentCache

  def self.configure
    yield(self)
    ActiveRecord::Base.acts_as_active_facet if RealCerealBusiness.acts_as_active_facet_enabled
  end

  def self.global_filter(name)
    RealCerealBusiness::ActsAsActiveFacet.Filters[name] = Proc.new
  end

  def self.resource_mapper
    RealCerealBusiness::ResourceManager.resource_mapper = Proc.new
  end

  def self.serializer_mapper
    RealCerealBusiness::ResourceManager.serializer_mapper = Proc.new
  end

  def self.fields_from_options(options)
    (options[RealCerealBusiness.opts_key] || {})[RealCerealBusiness.fields_key]
  end

  def self.options_with_fields(options, fields)
    (options[RealCerealBusiness.opts_key] ||= {})[RealCerealBusiness.fields_key] = fields
    options
  end

  def self.restore_opts_after(options, key, value)
    opts = (options[RealCerealBusiness.opts_key] ||= {})
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

ActiveRecord::Base.send :include, RealCerealBusiness::ActsAsActiveFacet



