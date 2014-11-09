require 'net/ssh'

# Models:
require_relative 'models/users'
require_relative 'models/servers'
require_relative 'models/results'
require_relative 'models/jobs'

# Load settings:
settings = YAML.load(File.read('config.yml'))

# Setup DB:
ActiveRecord::Base.logger = Logger.new(STDERR)
ActiveRecord::Base.establish_connection({
  :adapter => settings['database']['adapter'],
  :database => settings['database']['name'],
})

# Get the job queue:
job_queue = Job.get_queued

def dispatch_job (job, server)

end












server_list = Server.where('enabled = "t"')
server_list.each do |server|
# Cleanup server (acknowledge finished jobs, mark dead processes as failed, ecc)
	# connect
	# delete old response.yml if present
	# run script
	# grab result
	# based on result mark jobs as completed / failed and perform required cleanup
	# 

# Dispatch new job (file transfer, script execution, mark job as dispatched)
	# transfer files
	# launch script & disown process

end














Server.all.each do |server|
	Net::SSH.start(server) do |ssh|
		server.active_jobs.each do |job|
			# begin transaction
			# ssh check pid
			# ssh check files
			# ssh update records
			# end transaction
		end
		if not server.active_jobs 
			# ssh load new job
		end
		# update server record
	end
end