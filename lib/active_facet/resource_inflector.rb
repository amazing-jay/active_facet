module ActiveFacet
  module ResourceInflector
    extend ActiveSupport::Concern

    # Abstract method, ensure target implements
    # def resource_class
    #   raise 'abstract method (implement me!)'
    # end

    # Abstract method, ensure target implements
    # def resource_attribute_name(field)
    #   raise 'abstract method (implement me!)'
    # end

    # Constantizes an appropriate resource serializer class for relations
    # @param field [Symbol] to find relation reflection for
    # @return [Reflection | nil]
    def get_association_reflection(field)
      @association_reflections ||= {}
      @association_reflections[field] ||= resource_class.reflect_on_association(resource_attribute_name(field).to_sym)
    end

    # Constantizes an appropriate resource serializer class
    # @param field [Symbol] to test as relation and find serializer class for
    # @param options [Hash]
    # @return [Class | nil]
    def get_association_serializer_class(field, options)
      @association_serializers ||= {}
      unless @association_serializers.key? field
        @association_serializers[field] = nil
        #return nil if field isn't an association
        if reflection = get_association_reflection(field)
          #return nil if association doesn't have a custom class
          @association_serializers[field] = ActiveFacet::Helper.serializer_for(reflection.klass, options)
        end
      end
      @association_serializers[field]
    end

    # Constantizes an appropriate attribute serializer class
    # @param attribute [Symbol] base_name of attribute serializer class to find
    # @param options [Hash]
    # @return [Class | nil]
    def get_custom_serializer_class(attribute, options)
      @custom_serializers ||= {}
      @custom_serializers[attribute] ||= ActiveFacet::Helper.attribute_serializer_class_for(resource_class, attribute, options)
    end

    # Determines if public attribute maps to a private relation
    # @param field [Symbol] public attribute name
    # @return [Boolean]
    def is_association?(field)
      !!get_association_reflection(field)
    end
  end
end
