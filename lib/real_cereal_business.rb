require 'real_cereal_business/attribute_serializer/base'
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
require 'performance_monitor'

module RealCerealBusiness
  mattr_accessor :opts_key,
    :fields_key,
    :field_overrides_key,
    :version_key,
    :filters_key,
    :cache_force_key,
    :preload_associations,
    :cache_enabled,
    :default_cache_options,
    :document_cache,
    :default_version

  self.default_version                = 1.0
  self.opts_key                       = :rsb_opts
  self.fields_key                     = :fields
  self.field_overrides_key            = :field_overrides
  self.version_key                    = :version
  self.filters_key                    = :filters
  self.cache_force_key                = :cache_force0

  self.preload_associations           = false
  self.cache_enabled                  = false
  self.default_cache_options          = { expires_in: 5.minutes }
  self.document_cache                 = RealCerealBusiness::DocumentCache

  def self.configure
    yield(self)
    ActiveRecord::Base.register_filters
  end

  def self.global_filter(name)
    RealCerealBusiness::Extensions::ActiveRecord.filters[name] = Proc.new
  end

  def self.resource_mapper
    RealCerealBusiness::ResourceManager.resource_mapper = Proc.new
  end

  def self.serializer_mapper
    RealCerealBusiness::ResourceManager.serializer_mapper = Proc.new
  end
end

ActiveRecord::Base.send :include, RealCerealBusiness::Extensions::ActiveRecord
ActiveRecord::Relation.send :include, RealCerealBusiness::Extensions::ActiveRelation


