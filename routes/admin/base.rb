# encoding: utf-8


class PinW < Sinatra::Application

    # Auth checks:
    before '/admin/*' do
        halt redirect to '/' unless session[:user]
        current_user = User.find(session[:user].id) # blargh
        unless current_user.enabled
            session[:user] = nil
            halt redirect to '/?err=2'
        end
        unless current_user.admin
            halt redirect to '/'
        end
        session[:user] = current_user
    end

    get '/admin/?' do
       latest_jobs = Job.last(5)
       latest_results = Result.last(5)
       # erb :'admin/index', locals: {pending_update: true, pending_update_action: nil, pending_update_date: nil }
       erb :'admin/index', locals: { latest_jobs: latest_jobs, latest_results: latest_results }
    end
    
    get '/admin/archive/?' do
        erb :'admin/users'
    end

end

require_relative 'users'
require_relative 'jobs'
require_relative 'servers'
require_relative 'organisms'
require_relative 'settings'
