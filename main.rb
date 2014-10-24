# encoding: utf-8
require 'sinatra/base'


########################
### SINATRA SETTINGS ###
class PinW < Sinatra::Application

  #TODO: env variable
  set :session_secret, 'ACTTGTGATAGTACGTGT'

  # Cookie based sessions:
  # enable :sessions

  # In-memory sessions:
  use Rack::Session::Pool


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

require_relative 'routes'
require_relative 'admin_routes'
require_relative 'models'


PinW.run! 
