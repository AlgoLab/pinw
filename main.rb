# encoding: utf-8

require 'sinatra/base'
require 'sinatra/activerecord'
require 'yaml'

PROJECT_BASE_PATH ||= File.expand_path('../', __FILE__) + '/'
PROJECT_DATA_PATH ||= File.expand_path("..", Dir.pwd) + '/data/'  # Parent Directory

#Return current rack environment
def env
  ENV["RACK_ENV"] || "development"
end

########################
### SINATRA SETTINGS ###
class PinW < Sinatra::Application
  register Sinatra::ActiveRecordExtension

  set :root, File.dirname(__FILE__)

  # We could use database.yml in config/ dir but if we use it, we can't specify Parent Directory
  # We will use it in fetch and dispatch script

   if env == "production"
      db_name = "db/pinw.db"
   elsif env == "development"
       db_name = "db/dev.db"
   elsif env == "test"
      db_name = "db/test.db"
   end
   set :database, {adapter: "sqlite3", database: PROJECT_DATA_PATH + db_name }

  # TODO: env variable
  set :session_secret, 'ACTTGTGATAGTACGTGT'

  # set :download_path, PROJECT_BASE_PATH + 'downloads/'
  set :download_path,  PROJECT_DATA_PATH + 'downloads/' # Data Directory (in Parent Directory)
  set :max_reads_uploads, 5
  set :max_reads_urls, 5


  # Cookie based sessions:
  # enable :sessions

  # In-memory sessions:
  use Rack::Session::Pool

  not_found do
    erb :'404'
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
