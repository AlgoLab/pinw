# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever
require 'sinatra/base'

PROJECT_BASE_PATH ||= File.expand_path('../../', __FILE__) + '/'
PROJECT_DATA_PATH ||= File.expand_path("..", PROJECT_BASE_PATH) + '/data/'

set :output, PROJECT_DATA_PATH + 'pinw.log'

params = if Sinatra::Application.development? then ' --debug' else '--production' end

every 1.minutes do
    command "ruby " + PROJECT_BASE_PATH + "cron/pinw-fetch.rb #{params}"
    command "sleep 25s && ruby " + PROJECT_BASE_PATH + "cron/pinw-dispatch.rb #{params}"
end
