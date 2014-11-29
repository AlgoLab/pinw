# Rakefile
require "./main"
require "sinatra/activerecord/rake"

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:test) do |t|
    # t.pattern = "test/*-test.rb"
  end

  RSpec::Core::RakeTask.new(:test_verbose) do |t|
  	ENV['PINW_RSPEC_VERBOSE'] = 'true'
    t.pattern = "test/*-test.rb"
  end
rescue LoadError
  # no rspec available
  puts "Install RSpec to be able testing tasks!"
end