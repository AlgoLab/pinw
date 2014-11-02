# encoding: utf-8
require "sinatra/json"

class PinW < Sinatra::Application

	get '/admin/servers/?' do
		server_list = Server.all.to_a
		erb :'admin/servers', :locals => { :server_list => server_list }
	end


	post '/admin/servers/new' do
		server = Server.new

		server.priority = Server.maximum(:priority)
		server.name = params[:InputName]
		server.host = params[:InputHost]
		server.port =  params[:InputPort]
		server.username = params[:InputUsername]

		# PASSWORD OR KEY
		case params[:type]
		when '1'
			server.password = params[:InputPassword]
		when '2'
			server.client_certificate = params[:InputCertificate]
			server.client_passphrase = params[:InputPassphrase] if params[:InputPassphrase].length > 0
		end


		# ENV SETTINGS
		server.pintron_path = params[:InputPintronPath]
		server.python_command = params[:InputPythonPath]
		server.working_dir = params[:InputWorkingDir]
		server.use_callback = params[:InputUseCallback]
		server.callback_url = params[:InputCallbackURL]
		
		server.local_network = params[:InputLocalNetwork]
		server.enabled = true
		
		redirect to '/admin/servers?err=2' unless server.valid?

		server.save

		redirect to '/admin/servers?ok=1'
	end

	post '/admin/servers/test' do
		server = Server.new
		server.host = params[:InputHost]
		server.port = params[:InputPort]

		server.username = params[:InputUsername]
		case params[:type]
		when '1'
			server.password = params[:InputPassword]
		when '2'
			server.client_certificate = params[:InputCertificate]
			server.client_passphrase = params[:InputPassphrase] if params[:InputPassphrase].length > 0
		end

		# ENV SETTINGS
		server.pintron_path = params[:InputPintronPath]
		server.python_command = params[:InputPythonPath]
		server.working_dir = params[:InputWorkingDir]
		server.use_callback = params[:InputUseCallback]
		server.callback_url = params[:InputCallbackURL]
		return json server.test_configuration
	end

	get '/admin/servers/edit/:server_id' do
		erb :'admin/servers'
	end


	post '/admin/servers/edit/:server_id' do
		erb :'admin/servers'
	end


	post '/admin/servers/enable' do 
	 	Server.update params[:server_id], :enabled => true
		redirect to '/admin/servers'
	end


	post '/admin/servers/disable' do 
	 	Server.update params[:server_id], :enabled => false
		redirect to '/admin/servers'
	end
end