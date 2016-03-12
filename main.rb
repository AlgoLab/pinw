# encoding: utf-8

require 'sinatra/base'
require 'sinatra/activerecord'
require 'yaml'
require 'fileutils'

PROJECT_BASE_PATH ||= File.expand_path('../', __FILE__) + '/'
PROJECT_DATA_PATH ||= File.expand_path("..", Dir.pwd) + '/data/'  # Parent Directory


########################
### SINATRA SETTINGS ###
class PinW < Sinatra::Application
  register Sinatra::ActiveRecordExtension

  FileUtils.mkpath(PROJECT_DATA_PATH)

  set :root, File.dirname(__FILE__)

  # Database config ...
  # database.yml is in config/ so is loaded automatically

  # TODO: env variable
  set :session_secret, 'ACTTGTGATAGTACGTGT'

  set :download_path,  PROJECT_DATA_PATH + 'downloads/'
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
