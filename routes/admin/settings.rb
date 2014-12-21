# encoding: utf-8
require "sinatra/json"

class PinW < Sinatra::Application
    get '/admin/settings/?' do
        erb :'admin/settings', locals: {setting_list: Settings.all}
    end

    post '/admin/settings/?' do
    	Settings.all.each do |setting|
    		setting.value = params[setting.key.to_sym]
    		setting.save
    	end
    	redirect back
    end
end