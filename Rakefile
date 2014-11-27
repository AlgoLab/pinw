# Rakefile
require "./main"
require "sinatra/activerecord/rake"

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:test)do |t|
    t.pattern = "test/*.rb"
  end
rescue LoadError
  # no rspec available
end