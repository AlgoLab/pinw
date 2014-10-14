# encoding: utf-8
class PinW < Sinatra::Application
	get '/login/?' do
		 erb :login
	end

	post '/login/?' do
		if params[:InputUser] == SUPERADMIN.nickname 
			return 404 unless params[:InputPassword] == SUPERADMIN.password
	      	session[:user] = SUPERADMIN
	      	redirect to '/home'
	    else
	    	db_user = User.find_by_nickname(params[:InputUser])
	    	return 404 unless db_user

	    	return 404 unless db_user.passowrd == params[:InputPassword]
	    	session[:user] = db_user
	    	redirect to '/home'

	    end
		redirect to '/login'
	end

	get '/logout/?' do
		 session[:user] = nil
		 redirect to '/'
	end

	##############
	### CLIENT ###

	get '/' do
		redirect to '/home' if session[:user]
		
		erb :index
	end

	get '/home/?', :auth => [:user] do
		erb :home
	end

	get '/jobs/active/?', :auth => [:admin] do
	  "elenco roba"
	end

	get '/jobs/complete/?' do
	  "elenco roba terminata"
	end

	get '/archive/?' do
	  "elenco risultati"
	end

	post '/jobs/new/?' do
	  "nuovo robo"
	end


	
end