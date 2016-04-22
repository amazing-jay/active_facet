module ActiveFacet
  module Errors
    class ConfigurationError < StandardError

      RESOURCE_ERROR_MSG            = 'unable to identify resource class'
      STACK_ERROR_MSG               = "self referencing facet declaration"
      ALL_ATTRIBUTES_ERROR_MSG      = "expose facet (:all_attributes) reserved"
      ALL_FIELDS_ERROR_MSG          = "expose facet (:all) reserved"
      COMPILED_ERROR_MSG            = "serializer configuration not compiled"
      FACET_ERROR_MSG               = "invalid facet"
      ACTS_AS_ERROR_MSG             = "filters can only be defined on acts_as_active_facet resources"
      DUPLICATE_ACTS_AS_ERROR_MSG   = "acts_as_active_facet_options already exists"

    end
  end
end
