module V1
  module ResourceA
    class ResourceASerializer
      include ActiveFacet::Serializer::Base
      include BaseSerializer
      resource_class ::ResourceA
    end
  end
end
