# encoding: utf-8


class PinW < Sinatra::Application

	# Auth checks:
	before '/admin/*' do
		halt "must be logged in to access the admin panel" unless session[:user]
	  	current_user = User.find(session[:user].id) # blargh
	 	unless current_user.enabled
	 		session[:user] = nil
	 		halt "account disabled"
	 	end
	 	unless current_user.admin
	 		halt 404
	 	end
	end

	get '/admin/?' do
		erb :'admin/index'
	end


	get '/admin/settings/?' do
		erb :'admin/settings'
	end
	

	get '/admin/archive/?' do
		erb :'admin/users'
	end

end

require_relative 'users'