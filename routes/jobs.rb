# encoding: utf-8


class PinW < Sinatra::Application
    # Auth checks:
    before '/jobs/*' do
        halt "must be logged in to access the job panel" unless session[:user]
        current_user = User.find(session[:user].id) # blargh
        unless current_user.enabled
            session[:user] = nil
            halt "account disabled"
        end
    end

    get '/jobs/active/?' do
        job_list = Job.all.to_a
        server_list = Server.all.to_a
        erb :'jobs/active', :locals => {:job_list => job_list, :server_list => server_list}
    end

    post '/jobs/new' do
        job = Job.new
        job.user_id = session[:user].id
        if session[:user].admin
            job.server_id = params[:InputServer]
        end
        job.description = params[:InputDescription]
        job.ensembl = params[:InputEnsembl]
        job.genome = params[:InputGenomeURL]
        job.readsURLs = params[:InputURLs].join("\n")

        job.save
        redirect to '/jobs/active'
    end

    get '/jobs/complete/?' do

        erb :'jobs/complete'
    end
end