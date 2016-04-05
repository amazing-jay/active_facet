module BaseAttributeSerializer
  extend ActiveSupport::Concern

  module ClassMethods

    def serialize(attribute, resource, options)
      "serialized_#{attribute}"
    end

    def hydrate(attribute, resource, options)
      "hydrated_#{attribute}"
    end
  end
end
