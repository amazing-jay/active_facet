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
end