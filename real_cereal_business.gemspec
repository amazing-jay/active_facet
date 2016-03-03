# coding: utf-8
$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "real_cereal_business/version"

Gem::Specification.new do |s|
  s.name          = "real_cereal_business"
  s.version       = RealCerealBusiness::VERSION
  s.authors       = ["The Honest Company", "Jay Crouch"]
  s.email         = ["i.jaycrouch@gmail.com"]

  s.summary       = "Inline JSON serializer"
  s.description   = "Fast JSON serializer for nested PORO and ActiveRecord Objects supporting decoration, field filters, record filters and caching"
  s.homepage      = "https://github.com/honest/real_cereal_business"
  s.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if s.respond_to?(:metadata)
    s.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  s.files = Dir["{lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", "~> 3.2.22"
  s.add_dependency 'watchful_guerilla', '~> 0.2.0'

  s.add_development_dependency "bundler", "~> 1.11"
  s.add_development_dependency "sqlite3"
  #s.add_development_dependency "rspec"
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "test-unit"
  #s.add_development_dependency "rspec-json_expectations"
  s.add_development_dependency "factory_girl_rails"
  s.add_development_dependency "database_cleaner"
  s.add_development_dependency "ffaker"

  #Nicer rspec formatting
  s.add_development_dependency "fivemat"
  s.add_development_dependency "fuubar"
  # use all cores to run tests
  s.add_development_dependency "parallel_tests"
  s.add_development_dependency "pry"
  s.add_development_dependency "pry-rails"
  s.add_development_dependency "pry-nav"
  s.add_development_dependency "pry-stack_explorer"
  s.add_development_dependency "rapido"
end
