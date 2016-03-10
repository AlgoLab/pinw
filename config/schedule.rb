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

PROJECT_BASE_PATH ||= File.expand_path('../../', __FILE__) + '/'
PROJECT_DATA_PATH ||=  File.expand_path("..", Dir.pwd) + '/data/'


set :output, PROJECT_DATA_PATH + 'pinw.log'

every 1.minutes do
    command "ruby " + PROJECT_BASE_PATH + '/cron/pinw-fetch.rb'
    command "sleep 25s && ruby " + PROJECT_BASE_PATH + '/cron/pinw-dispatch.rb'
end
