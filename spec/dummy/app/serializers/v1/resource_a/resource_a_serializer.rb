module V1
  module ResourceA
    class ResourceASerializer
      include ActiveFacets::Serializer::Base
      include BaseSerializer
      resource_class ::ResourceA
    end
  end
end
