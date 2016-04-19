# encoding: utf-8

module ActiveFacet
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc 'Creates a ActiveFacet gem configuration file at config/active_facet.yml, and an initializer at config/initializers/active_facet.rb'

      def self.source_root
        @_af_source_root ||= File.expand_path("../templates", __FILE__)
      end

      def create_config_file
        template 'active_facet.yml', File.join('config', 'active_facet.yml')
      end

      def create_initializer_file
        template 'initializer.rb', File.join('config', 'initializers', 'active_facet.rb')
      end
    end
  end
end
