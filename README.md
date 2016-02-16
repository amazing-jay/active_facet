# TODO

# - implement controller versioning in www

# - implement serializer versioning in CORE-92
# -- clone all serializers and attribute serializers using inheritance
# --- use old signature for from_hash & attribute.serialize in old serializers
# --- use new signature for from_hash & attribute.serialize in new serializers
# -- add back serializer_base_new
# --- patch extentions to trigger SBN when version is 1.0

# - implement versioning
# -- remove direct references to group_includes in gem
# --- move group_includes into context
# --- rename context something more unique (rcb_opts)

# - merge document_cache branch  & test( CORE-113 )

# - test RCB
# -- move configured serializer class to explicit files
# -- finish facade tests
# -- add extention tests
# -- add attribute serializer tests
# -- add document cache tests
# -- add resource manager tests

# - performance: remove indifferent access in config
# - implement psuedo containers for non AR resources

# ?-- make the facade the primary kickoff point
# ?- implement registry based resource manager
# ?- extract performance monitor into a gem
# ?- add client test helpers
# ?- create a config generator


# RealCerealBusiness

RealCerealBusiness is a Rails plugin that enables custom as_json serialization. It is designed for speed, and is magnatudes of order faster than tools like jbuilder.

The framework supports:
* fields - define the fields you want to serialize, by resource type
* field groups - configure sets of fields you want to refer to by alias, by resource type
* versioning - describe serialization of resources by version, with automatic fallback
* caching - optomize performance by composing documents from smaller documents
* nested resources - serialize models and associations with one call chain

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'real_cereal_business'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install real_cereal_business

## Configuration

Add an initializer to your application:

```ruby
require 'real_cereal_business'

RealCerealBusiness.configure do |config|

  # The symbol which acts as the options key that designates context for serialization. :rsb_opts by default.
  config.opts_key                       = :context

  # The symbol which acts as the context key that designates fields for serialization. :fields by default.
  # config.fields_key                     = :fields

  # The symbol which acts as the context key that designates field overrides for serialization. :field_overrides by default.
  # config.field_overrides_key            = :field_overrides

  # The symbol which acts as the context key that designates version for serialization. :version by default.
  # config.version_key                    = :version

  # The symbol which acts as the context key that designates filters for serialization. :filters by default.
  # config.filters_key                    = :filters

  # The symbol which acts as the context key that designates force for cache. :cache_force by default.
  config.cache_force_key                = :bypass_cache

  # Tell if associations should be preloaded to mitigate N+1 problems. False by default.
  # config.preload_associations           = false

  # Tell document cache to cache
  # config.cache_enabled                  = false

  # Default options for Rails.cache.fetch
  # config.default_cache_options          = { expires_in: 5.minutes }

  # Tell document cache adaptor to use
  # config.document_cache = ::RealCerealBusiness::DocumentCache

  # Tell which filters and field_overrides apply to a given resource
  # config.resource_mapper { |resource_class|
  #   [].tap do |map|
  #     until(resource_class.superclass == BasicObject) do
  #       map << resource_class.name.tableize
  #       resource_class = resource_class.superclass
  #     end
  #   end
  # }

  # Applies scope to relation chains based on availability of active filter scopes
  config.global_filter(:active) do |state = Honest::Models::SerializationExtensions::DEFAULT_ACTIVE_FILTER|
    case state.to_sym
    when :enabled, :active
      if respond_to?(:enabled)
        enabled
      elsif respond_to?(:active)
        active
      end
    when :disabled, :inactive
      if respond_to?(:disabled)
        disabled
      elsif respond_to?(:inactive)
        inactive
      end
    end
  end

  #FIX --jdc was this really intended to be declared for all models, or just some?
  config.global_filter(:slice) do |name = :none|
    return if name.nil?
    if name.to_sym == :mobile_app
      if respond_to?(:enabled_for_app)
        enabled_for_app
      elsif respond_to?(:enabled)
        enabled
      elsif respond_to?(:active)
        active
      end
    elsif respond_to?(name.to_sym)
      name.constantize
    end
  end
end
```

## Usage

```ruby
Kid.new({
  id: 1,
  created_at: "2014-03-23 00:23:32",
  updated_at: "2014-03-23 00:23:32",
  data: { 'weight' => 243 }
}).as_json(group_includes: [:timestamps, :name])
# =>
# {
#   id: 1,
#   created_at: 2343242342,
#   updated_at: "2014-03-23 00:23:32",
#   weight: 2432252
# }

Kid.new.hydrate!({
  id: 1,
  created_at: 2343242342,
  updated_at: "2014-03-23 00:23:32",
  weight: 2432252
})
# =>
# {
#   id: 1,
#   created_at: "2014-03-23 00:23:32",
#   updated_at: "2014-03-23 00:23:32",
#   data: { 'weight' => 243 }
# }

Kid.scoped_includes([:timestamps, :trackings])
# =>
# equivalent to: Kid.includes([:trackings])

Honest::Serializers::Kid::KidSerializer.new.exposed_aliases(:all)
# =>
# [
#    [0] :birth_date,
#    [1] :created_at,
#    [2] :gender,
#    [3] :id,
#    [4] :image,
#    [5] :name,
#    [6] :notes,
#    [7] :updated_at,
#    [8] :weight,
#    [9] :weight_date
# ]

Honest::Serializers::Kid::KidSerializer.new.exposed_aliases(:all,true)
# =>
# [
#    [ 0] :birth_date,
#    [ 1] :created_at,
#    [ 2] :gender,
#    [ 3] :id,
#    [ 4] :image,
#    [ 5] :name,
#    [ 6] :notes,
#    [ 7] :trackings, ##<< relations are included
#    [ 8] :updated_at,
#    [ 9] :weight,
#    [10] :weight_date
# ]
```

# API v1 serializers use the following DSL to configure the serialization & hydration of resources
## Every resource should declare a serializer as follows:
```ruby
module Honest
  module Serializers
    module Kid
      class KidSerializer < ::RealCerealBusiness::Base


          # TRANSFORMS

          # Renames kid.kid_trackings to json['trackings'] on kid.as_json...
          transform :trackings,               from: :kid_trackings

          # Renames json['trackings'] to kid.kid_trackings on Kid.from_hash...:
          transform :trackings,               to: :kid_trackings

          # Renames kid.kid_trackings to json['trackings'] on kid.as_json... & Kid.from_hash...
          transform :trackings,               as: :kid_trackings

          # Converts json['created_at'] with TimeCustomAttributeSerializer on kid.as_json... & Kid.from_hash...
          transform :created_at,              with: :time

          # Renames json['created_at'] to kid.data['weight'] on kid.as_json... & Kid.from_hash...
          transform :weight,                  within: :data

          # Renames json['weighed'] to kid.data['weighed_at'] using TimeCustomAttributeSerializer converter on kid.as_json... & Kid.from_hash...
          transform :weighed,                 within: :data, with: :time, as: :wieghed_at



          # EXTENSIONS

          # Extensions are ONLY to be used when data is not directly accessible from the resource.
          # Use `transform` whenever possible

          # Decorates & serializes json['free_shipping_minimum'] on kid.as_json...
          extension :free_shipping_minimum



          # EXPOSURES

          # Declare an alias that can be used in lieu of a collection of attributes & relation attributes on kid.as_json...

          # Symbols map to resource methods or other aliases

          # NOTE:: ALL RESOURCE METHODS ARE EXPOSED BY DEFAULT
          # expose :name

          # Arrays map to collections of resource methods and aliases
          expose :timestamps,                 as: [:id, :created_at, :updated_at]
          expose :basic,                      as: [:timestamps, :name]

          # Hashes map to relations and attributes/aliases declared on the relation
          expose :deep,                       as: { trackings: :basic }

          # Composite structures can be formed from Symbols, Arrays, and Hashes
          expose :deep_basic,                 as: [:timestamps, :basic, { trackings: [:basic, :extended] }]

          # NOTE:: all serializers must expose a basic collection, as it is added to all composites by default
          expose :deep_basic,                 as: [:timestamps, { trackings: :extended }]



          # BONUSES

          # Equivalent to
          # transform :created_at, with: :time
          # transform :updated_at, with: :time
          # expose :timestamps, as: [:id, :created_at, :updated_at]
          expose_timestamps

      end
    end
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/real_cereal_business. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
