# encoding: utf-8
require 'sinatra/base'
require 'yaml'
require 'active_record'

##################
### DB PREPARE ###

settings = YAML.load(File.read('config.yml'))

ActiveRecord::Base.logger = Logger.new(STDERR)
ActiveRecord::Base.establish_connection({
  :adapter => settings['database']['adapter'],
  :database => settings['database']['name'],
  :timeout => 300000
})


########################
### SINATRA SETTINGS ###
class PinW < Sinatra::Application

  #TODO: env variable
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
require_relative 'models/users'
require_relative 'models/servers'
require_relative 'models/results'
require_relative 'models/jobs'

# Routes:
require_relative 'routes/base'

PinW.run! if PinW.app_file == $0
