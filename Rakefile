# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
require './lib/elibri_api_client/version.rb'
Jeweler::Tasks.new do |gem|
  gem.name = "elibri_api_client"
  gem.version = Elibri::ApiClient::Version::STRING
  gem.homepage = "http://github.com/elibri/elibri_api_client"
  gem.license = "MIT"
  gem.summary = %Q{API client for elibri.com.pl publishing system}
  gem.description = %Q{API client for elibri.com.pl publishing system}
  gem.email = "marcin@urbanski.vdl.pl"
  gem.authors = ["Marcin Urbański"]
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

require 'rcov/rcovtask'
Rcov::RcovTask.new do |test|
  test.libs << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
  test.rcov_opts << '--exclude "gems/*"'
end

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = Elibri::ApiClient::Version::STRING

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "elibri_api_client #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
