# encoding: utf-8
class PinW < Sinatra::Application
	# get '/login/?' do
	# 	 erb :login
	# end

	post '/login/?' do
		redirect to '/home' if session[:user]

    	db_user = User.find_by_nickname params[:InputUser]
    	redirect to '/?err=1' unless db_user and (db_user.password == params[:InputPassword])
    	redirect to '/?err=2' unless db_user.enabled
    	session[:user] = db_user
    	redirect to '/home'
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

	get '/jobs/active/?', :auth => [:user] do
		job_list = Job.all.to_a

	  	erb :jobs_active, :locals => {:job_list => job_list}
	end

	post '/jobs/new' do
	  job = Job.new
	  job.user = session[:user].id
	  job.server = session[:InputServer]
	  job.save
	  redirect to '/jobs/active'
	end

	get '/jobs/complete/?' do
	  erb :jobs_complete
	end

	get '/archive/?' do
	  "elenco risultati"
	end



	not_found do
	  erb :'404'
	end

	
end