module V2
  module ResourceA
    class ResourceASerializer
      include RealCerealBusiness::Serializer::Base
      include BaseSerializer
      resource_class ::ResourceA
    end
  end
end
