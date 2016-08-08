# encoding: utf-8
require 'git'

class PinW < Sinatra::Application

    # Auth checks:
    before '/admin*' do
        # If user is not logged we redirect to homepage
        halt redirect to '/?err=4' unless session[:user]
        current_user = User.find(session[:user].id)
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
       git = Git.open(PROJECT_BASE_PATH)
       pinw_hash_commit = git.log.first
       pinw_date_commit = git.log.first.date
       # erb :'admin/index', locals: {pending_update: true, pending_update_action: nil, pending_update_date: nil }
       erb :'admin/index', locals: { latest_jobs: latest_jobs, latest_results: latest_results,
                                     pinw_date_commit: pinw_date_commit, pinw_hash_commit: pinw_hash_commit }
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
