# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'redis-sentinel/version'

Gem::Specification.new do |gem|
  gem.name          = "redis-sentinel"
  gem.version       = Redis::Sentinel::VERSION
  gem.authors       = ["Richard Huang"]
  gem.email         = ["flyerhzm@gmail.com"]
  gem.description   = %q{another redis automatic master/slave failover solution for ruby by using built-in redis sentinel}
  gem.summary       = %q{another redis automatic master/slave failover solution for ruby by using built-in redis sentinel}
  gem.homepage      = "https://github.com/flyerhzm/redis-sentinel"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "redis"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "eventmachine"
  gem.add_development_dependency "em-synchrony"
end
