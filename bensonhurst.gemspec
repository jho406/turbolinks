require File.expand_path('../lib/bensonhurst/version', __FILE__)

Gem::Specification.new do |s|
  s.name     = 'bensonhurst'
  s.version  = Bensonhurst::VERSION
  s.author   = 'Johny Ho'
  s.email    = 'jho406@gmail.com'
  s.license  = 'MIT'
  s.homepage = 'https://github.com/jho406/bensonhurst/'
  s.summary  = 'Turbolinks for react and rails'
  s.files    = Dir["lib/assets/javascripts/*.coffee", "lib/bensonhurst.rb", "lib/bensonhurst/*.rb", "README.md", "MIT-LICENSE", "test/*"]
  s.test_files = Dir["test/*"]

  s.add_dependency 'coffee-rails'
  s.add_dependency 'jbuilder'
  s.add_dependency 'actionpack', '>= 4.0'

  s.add_development_dependency 'rake'
end
