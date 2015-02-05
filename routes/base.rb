# encoding: utf-8


class PinW < Sinatra::Application

    # Auth checks:
    before '/home/?*' do
        halt redirect to '/' unless session[:user]
        current_user = User.find(session[:user].id) # blargh
        unless current_user.enabled
            session[:user] = nil
            halt redirect to '/?err=2'
        end
        session[:user] = current_user
    end



    get '/' do
        redirect to '/home' if session[:user] and session[:user].enabled
        
        erb :index
    end

    get '/home/?' do
        redirect to '/jobs'
    end

    get '/job_notification_callback' do 
        job = Job.find params[:job_id]
        # Test if the token is correct:
        return 500 unless job.callback_token == params[:token]

        # Check the server in a separated process:
        # ActiveRecords::Base.disconnect
        # spid = Process.fork do
            # PinWFetch.new db_settings
        # end
        # Process.detatch spid


    end

end

require_relative 'auth'
require_relative 'jobs'
require_relative 'results'
require_relative 'admin/base'
