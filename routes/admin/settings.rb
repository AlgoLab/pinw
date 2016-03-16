# encoding: utf-8
require "sinatra/json"
require "yaml"

class PinW < Sinatra::Application
    get '/admin/settings/?' do
        # Init settings:
        Settings.get_ssh_keys
        Settings.get_max_active_downloads
        Settings.get_max_remote_transfers
        erb :'admin/settings', locals: {setting_list: Settings.all}
    end

    post '/admin/settings/?' do
    	Settings.all.each do |setting|
    		setting.value = params[setting.key.to_sym]
    		setting.save
    	end
      redirect to '/admin/settings?ok=1'
    end

    post '/admin/settings/import' do
        if params[:ImportInput]
            File.open("#{PROJECT_DATA_PATH}/pinw_settings.yml", "w") do |f|
                f.write(params[:ImportInput][:tempfile].read)
            end
        end
        if File.exist?("#{PROJECT_DATA_PATH}/pinw_settings.yml")
            settings_file = YAML.load_file("#{PROJECT_DATA_PATH}/pinw_settings.yml")
        else
          redirect to '/admin/settings?err=2'
        end
        Settings.all.each do |setting|
      		setting.value = settings_file[setting.key]
      		setting.save
      	end
      	redirect to '/admin/settings?ok=2'
    end

    post '/admin/settings/export' do
        s = {}
        Settings.all.each do |setting|
            s[setting.key] = setting.value
        end
        File.open("#{PROJECT_DATA_PATH}/pinw_settings.yml","w") do |file|
          file.write s.to_yaml
        end
        redirect to '/admin/settings?err=3'  unless  File.file? "#{PROJECT_DATA_PATH}/pinw_settings.yml"

        send_file "#{PROJECT_DATA_PATH}/pinw_settings.yml", disposition: 'attachment'
    end




end
