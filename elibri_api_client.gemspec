# -*- encoding: utf-8 -*-
require File.expand_path('../lib/elibri_api_client/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Marcin Urba\305\204ski"]
  gem.email         = ["marcin@urbanski.vdl.pl"]
  gem.description   = %q{API client for elibri.com.pl publishing system}
  gem.summary       = %q{API client for elibri.com.pl publishing system}
  gem.homepage      = "http://github.com/elibri/elibri_api_client"
  gem.date = %q{2011-12-19}

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "elibri_api_client"
  gem.require_paths = ["lib"]
  gem.licenses = ["MIT"]
  gem.version       = Elibri::ApiClient::VERSION
  
  gem.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]
  
  gem.add_runtime_dependency "httparty", ">= 0.8.1"
  gem.add_runtime_dependency "nokogiri", "~> 1.5.0"
  gem.add_runtime_dependency 'activesupport', '>= 2.3.5'
  gem.add_runtime_dependency 'elibri_onix', '>= 0.1.11'

  gem.add_development_dependency "pry"
  gem.add_development_dependency "mocha"
  gem.add_development_dependency "minitest", ">= 0"
  gem.add_development_dependency "bundler"
  gem.add_development_dependency "jeweler", "~> 1.6.2"
  gem.add_development_dependency "rdoc"

#  gem.add_development_dependency "rcov", ">= 0"
  
end
