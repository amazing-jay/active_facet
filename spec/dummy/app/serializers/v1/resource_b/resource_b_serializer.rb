module V1
  module ResourceB
    class ResourceBSerializer
      include ActiveFacets::Serializer::Base
      resource_class ::ResourceB
    end
  end
end
