# encoding: utf-8

require 'sinatra/base'
require 'sinatra/activerecord'
require 'yaml'



########################
### SINATRA SETTINGS ###
class PinW < Sinatra::Application
  register Sinatra::ActiveRecordExtension

  # database.yml is in config/ so is loaded automatically
  # set :database_file, "path/to/database.yml"

  # TODO: env variable
  set :session_secret, 'ACTTGTGATAGTACGTGT'

  # Cookie based sessions:
  # enable :sessions

  # In-memory sessions:
  use Rack::Session::Pool

  not_found do
    erb :'404'
  end
  
  set(:auth) do |*roles|   
    condition do
      roles.each do |role|
        if role == :admin
          redirect to '/login' unless session[:user] and session[:user].admin
        elsif role == :user
          redirect to '/login' unless session[:user]
        # elsif role ==
        end
      end  
    end
  end

  after do
    ActiveRecord::Base.connection.close
  end


end

# Models:
require_relative 'models/base'

# Routes:
require_relative 'routes/base'

PinW.run! if PinW.app_file == $0
