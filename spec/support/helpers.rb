module Helpers

  def make_options(options)
    {
      ActiveFacet.opts_key => {
        ActiveFacet.fields_key => options[:fields],
        ActiveFacet.field_overrides_key => options[:field_overrides],
        ActiveFacet.version_key => options[:version],
        ActiveFacet.filters_key => options[:filters]
      }
    }
  end

  def reset_filter_memoization
    ActiveFacet::Filter.filters = {}
    ActiveFacet::Filter.registered_filters = {}
    ActiveFacet::Filter.global_filters = {}
  end

  def reset_serializer_mapper_memoization
    ActiveFacet::Helper.memoized_serializers = {}
  end

  def reset_resource_mapper_memoization
    ActiveFacet::Helper.send :memoized_resource_map=, {}
  end
end