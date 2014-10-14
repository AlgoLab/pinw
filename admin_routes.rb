# encoding: utf-8
class PinW < Sinatra::Application
	get '/admin/?', :auth => [:admin] do
		erb :admin
	end


	get '/admin/settings/?', :auth => [:admin] do
		erb :admin_settings
	end

	get '/admin/users/?', :auth => [:admin] do
		user_list = User.all.to_a
		erb :admin_users, :locals => { :user_list => user_list }
	end

	post '/admin/users/new', :auth => [:admin]  do
		new_user = User.new
		
		puts params
		new_user.nickname = params[:InputUser]
		puts 'NICKNAME', new_user.nickname
		return 'bad nick' unless new_user.nickname =~ /[A-Za-z0-9._\-\@]{3,50}/ and new_user.nickname != SUPERADMIN.nickname

		new_user.password = params[:InputPassword]
		return 'bad psdw' unless new_user.password.length.between? 5, 50

		new_user.admin = true if params[:InputAdmin]

		new_user.max_fs = params[:InputMaxFS]
		new_user.max_cput = params[:InputMaxCPUT]
		new_user.max_ql = params[:InputMaxQL]
		
		return "invalid user" unless new_user.valid?
		new_user.save
		redirect to '/admin/users'
	end

	post '/admin/users/edit' do
	end

	post '/admin/users/delete' do
	end


	get '/admin/jobs/?', :auth => [:admin] do
		erb :admin_users
	end

	get '/admin/archive/?', :auth => [:admin] do
		erb :admin_users
	end
end