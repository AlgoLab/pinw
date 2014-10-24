# encoding: utf-8


class PinW < Sinatra::Application

	get '/admin/servers/?' do
		server_list = Server.all.to_a
		erb :'admin/servers', :locals => { :server_list => server_list }
	end


	post '/admin/servers/new' do
		server = Server.new
		server.name = params[:InputName]
		server.enabled = true
		server.save
		redirect to '/admin/servers?ok=1'
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