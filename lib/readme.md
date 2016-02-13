#TODO --jdc
# - add unit tests
# - add integration tests
# - clone all serializers and attribute serializers
# - reset serializer_base_new
# - implement version switch in resource manager
# - implement version switch in routes
# - performance
# -- remove indifferent access in config
# - update this document and move it into the main readme

# ?- implement psuedo containers for non AR resources
# ?-- make the facade the primary kickoff point
# ?- implement registry based resource manager
# ?- rename scopes to fields & field_groups
# ?- remove direct references to group_includes
# ?-- move group_includes into context
# ?-- rename context something more unique (rcb_opts)
# ?- add client test helpers






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

## USAGES

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
