module BaseAttributeSerializer
  extend ActiveSupport::Concern

  module ClassMethods

    def serialize(attribute, resource, options)
      "serialized_#{attribute}"
    end

    def unserialize(attribute, resource, options)
      "unserialized_#{attribute}"
    end
  end
end
