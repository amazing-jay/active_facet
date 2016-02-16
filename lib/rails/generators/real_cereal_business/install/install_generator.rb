# encoding: utf-8

module RealCerealBusiness
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc 'Creates a RealCerealBusiness gem configuration file at config/real_cereal_business.yml, and an initializer at config/initializers/real_cereal_business.rb'

      def self.source_root
        @_sugarcrm_source_root ||= File.expand_path("../templates", __FILE__)
      end

      def create_config_file
        template 'real_cereal_business.yml', File.join('config', 'real_cereal_business.yml')
      end

      def create_initializer_file
        template 'initializer.rb', File.join('config', 'initializers', 'real_cereal_business.rb')
      end
    end
  end
end
