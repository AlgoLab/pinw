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

set :output, File.expand_path("../../cron_log.log", __FILE__)

every 1.minutes do 
	command "ruby #{File.expand_path("../../cron/pinw-fetch.rb", __FILE__)}"
	command "sleep 25s && ruby #{File.expand_path("../../cron/pinw-dispatch.rb", __FILE__)}"
end

