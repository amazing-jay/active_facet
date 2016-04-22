module TestHarnessHelper

  def test_resource_class
    ResourceA
  end

  def test_association_class
    ResourceB
  end

  def build_resource_serializer_class
    Class.new {
      include ActiveFacet::Serializer::Base

      resource_class ::ResourceA
    }
  end

  def build_association_serializer_class
    Class.new {
      include ActiveFacet::Serializer::Base
      resource_class ::ResourceB
    }
  end

  def build_attribute_serializer_class
    Class.new {
      include BaseAttributeSerializer
    }
  end

  def reset_serializer_classes
    ActiveFacet::Helper.serializer_mapper = ActiveFacet::Helper.method(:default_serializer_mapper)
  end

  def setup_serializer_classes(resource_serializer_class, association_serializer_class, attribute_serializer_class)
    resource_serializer_class.class_eval do
      include BaseSerializer
    end

    ActiveFacet.serializer_mapper do |resource_class, serializer, type, version, options|
      case type
      when :serializer
        case resource_class.to_s
        when test_resource_class.to_s
          resource_serializer_class.instance
        when test_association_class.to_s
          association_serializer_class.instance
        else
          nil
        end
      when :attribute_serializer
        case serializer
        when 'Customizer'
          attribute_serializer_class
        when 'ExtensionAttr'
          attribute_serializer_class
        else
          nil
        end
      else
        nil
      end
    end

    resource_serializer_class
  end
end
