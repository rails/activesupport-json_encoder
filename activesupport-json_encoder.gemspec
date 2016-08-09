# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |gem|
  gem.name          = 'activesupport-json_encoder'
  gem.version       = '1.1.0'
  gem.authors       = ["David Heinemeier Hansson"]
  gem.email         = ["david@loudthinking.com"]
  gem.description   = 'A pure-Ruby ActiveSupport JSON encoder'
  gem.summary       = 'A pure-Ruby ActiveSupport JSON encoder (extracted from core in Rails 4.1)'
  gem.homepage      = 'https://github.com/rails/activesupport-json_encoder'
  gem.license       = 'MIT'

  gem.required_ruby_version = '>= 1.9.3'

  gem.files         = Dir['MIT-LICENSE', 'README.md', 'lib/**/*']
  gem.test_files    = Dir['test/**/*.rb']
  gem.require_paths = ['lib']

  gem.add_dependency 'activesupport', '>= 4.1.0'

  gem.add_development_dependency 'rake'
end
