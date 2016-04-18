# encoding: utf-8

module ActiveFacets
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc 'Creates a ActiveFacets gem configuration file at config/active_facets.yml, and an initializer at config/initializers/active_facets.rb'

      def self.source_root
        @_af_source_root ||= File.expand_path("../templates", __FILE__)
      end

      def create_config_file
        template 'active_facets.yml', File.join('config', 'active_facets.yml')
      end

      def create_initializer_file
        template 'initializer.rb', File.join('config', 'initializers', 'active_facets.rb')
      end
    end
  end
end
