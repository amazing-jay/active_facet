# Wishlist Items

## Abstraction

### Non-AR resources
#### Extend the project to work with non-AR resource classes by refactoring extensions and serializer lookups


## Performance

### Dynamic Code Generation
#### Eliminate conditional logic that occurs during serialization by generating methods which perform the serialization given a specific facet, e.g.

```ruby
class Serializer::V2::DynamicSerializer2523

  def self.product_as_json(product, options)
    {
      attr1: product.attr1,
      attr2: product.attr3,
      attr4: product.attr4[:nested_attr],
      attr5: CustomAttributeSerializer.serialize(product.attr5, product, options),
      attr6: product.association.map { |variant|
        variant_as_json(variant, options)
      }
    }
  end

  def self.variant_as_json(variant, options)
    {
      attr1: variant.attr1,
      attr2: variant.attr3
    }
  end

  def self.from_hash(resource, json)
    ... tbd
  end
end
```

### Memoize Dealiased Facets
#### Reduce conditional logic by memoizing dealised facets for subsequent calls.

## Refactor

### Single Responsibility
#### Move reflection methods from base to config, and cleanup resource manager

### Dependency Injection
#### Provide constants in RCB so all objects can be easily swapped for consumers

### Encapsulate Filters
#### Extract Filters into their own classes

### Naming
#### Rename field_group to facet

## Other
### Write a blog article about this