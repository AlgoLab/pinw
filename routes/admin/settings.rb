# encoding: utf-8
require "sinatra/json"

class PinW < Sinatra::Application

	get '/admin/settings/?' do
		erb :'admin/settings', :locals => { :setting_list => [
			{key: 'MAX_CONCURRENT_DOWNLOADS', 
				name: 'Max concurrent DLs', 
				description: 'YOLO', 
				type: 'number',
				value: 35},
			{key: 'MAX_DOWNLOAD_SPEED', 
				name: 'Max DS speed', 
				description: 'blablabla banana', 
				type: 'number',
				value: 5.7},
			{key: 'TITLE_PREFIX', 
				name: 'Site title prefix', 
				description: 'ngrgnegn',
				type: 'text',
				value: "sono una stringa"},
			{key: 'ACCEPT_NEW_JOBS', 
				name: 'Accept new jobs', 
				description: 'Disable acceptance of new jaabs.',
				type: 'checkbox',
				value: true},
			{key: 'ACCEPT_NEW_JOBS_TEST', 
				name: 'Accept new jobs, or other things', 
				description: 'Disable acceptance of new jaabs.',
				type: 'checkbox',
				value: false}
			]}
	end

end