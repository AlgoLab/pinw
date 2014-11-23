# encoding: utf-8


class PinW < Sinatra::Application

    # Auth checks:
    before '/admin/*' do
        halt redirect to '/' unless session[:user]
        current_user = User.find(session[:user].id) # blargh
        unless current_user.enabled
            session[:user] = nil
            halt "account disabled"
        end
        unless current_user.admin
            halt redirect to '/'
        end
    end

    get '/admin/?' do
        erb :'admin/index'
    end
    
    get '/admin/archive/?' do
        erb :'admin/users'
    end

end

require_relative 'users'
require_relative 'servers'
require_relative 'settings'