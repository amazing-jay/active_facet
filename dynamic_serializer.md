

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


Todos

Benchmark a few endpoints after 1st run without caching
Time categories in APIs by extending WD to configure print toggling and log data and nullify last_node


Opportunities

#1

Change Facade.new to Facade.build, which generates a memoized class:

#2

Add a new method to serializers which wraps as_json for use in custom attribute serializers

#3

Calculate field_sets once per call chain and associate with dynamic serializers without lookup


-- can i calculate the field_set just once per call chain?
--- what happens when i hit a non-custom object?
----
-- can i associate dynamic serializers to field_sets without lookup?
-- problems
--- where can i store compiled field_sets?
--- what is passed to CustomAttributeSerializer?
---


---

class ProductSerializer

  transform :custom, with: :customizer

  expose :basic, as: [:foo, :bar, :custom, :varient]
  expose :deep, as: { a: { b: :c } }

  expose :needs_merge, as: [{a: { d: :e}}, :deep]
end

class VariantSerializer

  expose :basic, as: [:a, :b, :option_types]

end

class OptionValuesSerializer

  ...

end

class CustomizerAttributeSerializer

  def custom_includes
    :option_values
  end

  #NOW
  def serialize(resource, attribute, context)
    resource.option_values.as_json(group_includes: :basic)
  end

  #FIXED
  def serialize(resource, attribute, options)
    context = options[:context] || {}
    resource.option_values.as_json(group_includes: :basic)
  end

end

