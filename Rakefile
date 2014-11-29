# Rakefile
require "./main"
require "sinatra/activerecord/rake"

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:test) do |t|
  end

  RSpec::Core::RakeTask.new(:test_verbose) do |t|
  	ENV['PINW_RSPEC_VERBOSE'] = 'true'
  end
rescue LoadError
  # no rspec available
  puts "Install RSpec to enable testing tasks!"
end