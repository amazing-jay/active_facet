module Helpers

  def make_options(options)
    {
      ActiveFacets.opts_key => {
        ActiveFacets.fields_key => options[:fields],
        ActiveFacets.field_overrides_key => options[:field_overrides],
        ActiveFacets.version_key => options[:version],
        ActiveFacets.filters_key => options[:filters]
      }
    }
  end
end