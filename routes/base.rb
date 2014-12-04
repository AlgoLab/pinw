# encoding: utf-8


class PinW < Sinatra::Application
    get '/' do
        redirect to '/home' if session[:user]
        
        erb :index
    end

    get '/home/?' do
    	raise 'AuthError'
        erb :home
    end

    get '/archive/?' do
      "elenco risultati"
    end


end

require_relative 'auth'
require_relative 'jobs'
require_relative 'admin/base'
