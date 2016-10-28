require File.expand_path('../lib/plumlinks/version', __FILE__)

Gem::Specification.new do |s|
  s.name     = 'plumlinks'
  s.version  = Plumlinks::VERSION
  s.author   = 'David Heinemeier Hansson'
  s.email    = 'david@loudthinking.com'
  s.license  = 'MIT'
  s.homepage = 'https://github.com/rails/plumlinks/'
  s.summary  = 'Plumlinks makes following links in your web application faster (use with Rails Asset Pipeline)'
  s.files    = Dir["lib/assets/javascripts/*.coffee", "lib/plumlinks.rb", "lib/plumlinks/*.rb", "README.md", "MIT-LICENSE", "test/*"]
  s.test_files = Dir["test/*"]

  s.add_dependency 'coffee-rails'
  s.add_dependency 'jbuilder'
  s.add_dependency 'actionpack', '>= 4.0'

  s.add_development_dependency 'rake'
end
