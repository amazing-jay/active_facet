WG.configure do |config|
  config_file_path = File.join(Rails.root, 'config', 'w_g.yml')
  environment = ENV["RAILS_ENV"] || ENV["RACK_ENV"] || 'development'

  @config_file = YAML::load_file(config_file_path)
  @env_config = (@config_file['default'] || {}).merge(@config_file[environment] || {})
  @env_config['tracing'] = ENV['WG_TRACING'] if ENV.key?('WG_TRACING')
  @env_config['profiling'] = ENV['WG_PROFILING'] if ENV.key?('WG_PROFILING')
  @env_config['measuring'] = ENV['WG_MEASURING'] if ENV.key?('WG_MEASURING')
  @env_config['reporting_threshold'] = ENV['WG_REPORTING_THRESHOLD'] if ENV.key?('WG_REPORTING_THRESHOLD')


  # Tell if the block stack should output while measuring. Defaults to false
  config.tracing @env_config['tracing']

  # Tell if profiling blocks are active. Defaults to false
  config.profiling @env_config['profiling']

  # Tell if measuring blocks are active. Defaults to false
  config.measuring @env_config['measuring']

  # Tell minimum threshold of milliseconds required for a block to be considered long running
  config.reporting_threshold @env_config['reporting_threshold']

  config.decorate_method( { decorator: :measure_decorator, instance_methods: true, target: 'ActiveFacets::Serializer::Base'} )
  config.decorate_method( { decorator: :measure_decorator, instance_methods: true, target: 'ActiveFacets::Serializer::Base::ClassMethods'} )
  config.decorate_method( { decorator: :measure_decorator, instance_methods: true, class_methods: true, target: 'ActiveFacets::Serializer::Facade'} )
  config.decorate_method( { decorator: :measure_decorator, instance_methods: true, class_methods: true, target: 'ActiveFacets::Config'} )
  config.decorate_method( { decorator: :measure_decorator, instance_methods: true, class_methods: true, target: 'ActiveFacets::ResourceManager'} )
  config.decorate_method( { decorator: :measure_decorator, instance_methods: true, class_methods: true, target: 'ActiveFacets::DocumentCache'} )

  config.decorate_method( { decorator: :measure_decorator, instance_methods: :to_json, target: 'ActiveRecord::Base'} )
  config.decorate_method( { decorator: :measure_decorator, instance_methods: [:to_a, :as_json], target: 'ActiveRecord::Relation'} )

  config.decorate_method( { decorator: :measure_decorator, instance_methods: [
    :build_json, :render_json, :render, :cache_result, :cache_render, :cache_render_updated_at
  ], target: 'Api::V1::ApiBaseController'} )

  # Decorate application with profiling measures
  config.decorate_application if @env_config['measuring']
end

