# encoding: utf-8
require 'sinatra/base'
require_relative 'models'


########################
### SINATRA SETTINGS ###
class PinW < Sinatra::Application

  set :session_secret, 'ACTTGTGATAGTACGTGT'

  SUPERADMIN = User.new(:nickname => 'admin', :password => 'admin', :admin => true)

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


end


require_relative 'routes'
require_relative 'admin_routes'
PinW.run! 
