module Helpers

  def make_options(options)
    {
      RealCerealBusiness.opts_key => {
        RealCerealBusiness.fields_key => options[:fields],
        RealCerealBusiness.field_overrides_key => options[:field_overrides],
        RealCerealBusiness.version_key => options[:version],
        RealCerealBusiness.filters_key => options[:filters]
      }
    }
  end
end