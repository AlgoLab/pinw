# encoding: utf-8


class PinW < Sinatra::Application
	get '/jobs/active/?', :auth => [:user] do
		job_list = Job.all.to_a

	  	erb :'jobs/active', :locals => {:job_list => job_list}
	end

	post '/jobs/new' do
	  job = Job.new
	  job.user = session[:user].id
	  job.server = session[:InputServer]
	  job.save
	  redirect to '/jobs/active'
	end

	get '/jobs/complete/?' do
	  erb :'jobs/complete'
	end
end