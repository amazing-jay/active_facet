# ActiveFacet

ActiveFacet is a Rails plugin that enables custom as_json serialization intended for APIs. It is designed for speed, and is orders of magnitude faster than jbuilder.

The framework supports:
* fields - define the fields you want to serialize, by resource type
* field groups - configure sets of fields you want to refer to by alias, by resource type
* versioning - describe serialization of resources by version, with automatic fallback
* caching - optomize performance by composing documents from smaller documents
* nested resources - serialize models and associations with one call chain
* filters - restrict records from associations with custom scopes

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_facet'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install active_facet

## Configuration

And then execute:

    $ rails g active_facet:install

To add an initializer to your application.

## Usage

```ruby
Parent.limit(2).as_json(af_opts: {
  version: "2.3.8",
  cache_force: true,
  fields: [:basic, :extended, { children: [:minimal, :extension] }]
  field_overrides: {
    parent: [:id, :children, :foo, :bar],
    child: [:fizz, :buzz]
  },
  filters: {
    single_parent: true,
    with_children_parent: 3,
    active: :disabled
  }
})
# =>
[ {
    id: 1,
    created_at: 2343242342,
    updated_at: "2014-03-23 00:23:32",
    weight: 2432252,
    children: [ {
      fizz: 'care bear'
    }, {
      fizz: 'hello',
      buzz: 'world'
    } ]
  }, {
    id: 2,
    created_at: 2343242777,
    updated_at: "2014-04-24 01:34:25",
    children: [ {
      fizz: 'tamato'
    } ]
  }
}
```

### Defaults

All options are optional

#### :version
Version of serializer to marshal resources with. Defaults to:
```ruby
"1.0"
```

#### :cache_force
Force serializers to ignore cached documents. Defaults to:
```ruby
false
```

#### :fields
Attributes to marshal. See Field Sets. Defaults to:
```ruby
:basic
```

#### :field_overrides
Attributes to marshal, by resource type. See Field Sets. Defaults to:
```ruby
{}
```

#### :filters
Filters to apply when marshalling associations. See Field Sets. Defaults to:
```ruby
{}
```

### Serializer DSL

```ruby
class ParentSerializer
  include ActiveFacet::Serializer::Base

  # TRANSFORMS

  # Transforms rename attributes and apply custom serializers to attributes data.

  # Renames parent.kid_trackings to json['trackings'] on parent.as_json...
  transform :trackings,               from: :kid_trackings

  # Renames json['trackings'] to parent.kid_trackings on parent.from_hash...:
  transform :trackings,               to: :kid_trackings

  # Renames parent.kid_trackings to json['trackings'] on parent.as_json... & parent.from_hash...
  transform :trackings,               as: :kid_trackings

  # Converts json['created_at'] with TimeCustomAttributeSerializer on parent.as_json... & parent.from_hash...
  transform :created_at,              with: :time

  # Renames json['created_at'] to parent.data['weight'] on parent.as_json... & parent.from_hash...
  transform :weight,                  within: :data

  # Renames json['weighed'] to parent.data['weighed_at'] using TimeCustomAttributeSerializer converter on parent.as_json... & parent.from_hash...
  transform :weighed,                 within: :data, with: :time, as: :wieghed_at



  # EXTENSIONS

  # Extensions decorate the json response when attribute data is not directly accessible from the resource.

  # Decorates json['free_shipping_minimum'] on parent.as_json...
  extension :free_shipping_minimum



  # FIELD SETS

  # Field sets indicate the desired fields to serialize for a given resource type.
  # Field sets can be aliased, and reference aliases, recursively.
  # Field sets can reference Field Sets defined for ActiveRecord Association resource types in a hierarchical structure

  # NOTE:: make sure to define :basic and :minimal Field Sets for all resources
  # :basic is implicitely added to all Field Sets that do not inclue :minimal during serialization

  # Arrays map to collections
  expose :timestamps,                 as: [:id, :created_at, :updated_at]
  expose :basic,                      as: [:timestamps, :name]

  # Hashes map to relations and the Field Sets declared on the relation
  expose :deep,                       as: { trackings: :basic }

  # Composite structures can be formed from Symbols, Arrays, and Hashes
  expose :deep_basic,                 as: [:timestamps, :basic, { trackings: [:basic, :extended] }]



  # EXPOSE_TIMESTAMPS

  # expose_timestamps is equivalent to
  # transform :created_at, with: :time
  # transform :updated_at, with: :time
  # expose :timestamps, as: [:id, :created_at, :updated_at]
  expose_timestamps

end
```

## Development

After checking out the repo, run `./bin/setup` to install dependencies. Then, run `rspec spec` to run the tests. You can also run `./bin/console` for an interactive prompt that will allow you to experiment. To work with an interactive prompt including a dummy host application, run `bin/rails c` or `rails c` from the spec/dummy directory.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

To push or update an unreleased version, without pushing the `.gem` file, run `bin/update_version`.

To configure a host application to use a local version of the gem without modifying the host application's Gemfile run from the root directory of the host application `bundle config local.active_facet /path/to/local/git/repository`

To unconfigure a local version of the gem, run `bundle config --delete local.active_facet`

## Roadmap
Available at /blob/master/ROADMAP.md


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/honest/active_facet. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

