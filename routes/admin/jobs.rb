class PinW < Sinatra::Application

	get '/admin/jobs/?' do
	    server_list = Server.all.to_a
	    organism_list = Organism.where(enabled: true)
	    erb :jobs, locals: {server_list: server_list, organism_list: organism_list, admin_view: true}
	end

end