# encoding: utf-8


class PinW < Sinatra::Application

    get '/admin/users/?' do
        user_list = User.all.to_a
        erb :'admin/users', locals: { user_list: user_list }
    end

    post '/admin/users/new' do
        new_user = User.new
        
        new_user.nickname = params[:InputUser]
        redirect to '/admin/users?err=1' unless new_user.nickname =~ /[A-Za-z0-9._\-\@]{3,50}/

        new_user.password = params[:InputPassword]
        redirect to '/admin/users?err=2' unless new_user.password.length.between? 5, 50

        new_user.email = params[:InputEmail]
        redirect to '/admin/users?err=3' unless new_user.email =~ /^([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})$/i

        new_user.admin = true if params[:InputAdmin]

        new_user.max_fs = params[:InputMaxFS]
        new_user.max_cput = params[:InputMaxCPUT]
        new_user.max_ql = params[:InputMaxQL]
        
        return "invalid user" unless new_user.valid?
        new_user.save
        redirect to '/admin/users'
    end

    post '/admin/users/edit' do
        user = User.find params[:user_id]


        changes = []
        
        if user.nickname != params[:InputUser]
            changes << "(nickname) #{user.nickname} -> #{params[:InputUser]}"
        end
        user.nickname = params[:InputUser]
        redirect to "/admin/users/edit/#{params[:user_id]}?err=1" unless user.nickname =~ /[A-Za-z0-9._\-\@]{3,50}/ 


        user.password = params[:InputPassword]
        redirect to "/admin/users/edit/#{params[:user_id]}?err=2" unless user.password.length.between? 5, 50


        if user.nickname != params[:InputEmail]
            changes << "(email) #{user.email} -> #{params[:InputEmail]}"
        end
        user.email = params[:InputEmail]
        redirect to "/admin/users/edit/#{params[:user_id]}?err=3" unless user.email =~ /^([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})$/i


        if not (User.where("admin = \"t\"").length == 1 and user.admin)
            user.admin = !!params[:InputAdmin] 
        end

        if user.nickname == 'guest'
            user.admin = false
        end        

        user.max_fs = params[:InputMaxFS]
        user.max_cput = params[:InputMaxCPUT]
        user.max_ql = params[:InputMaxQL]

        redirect to "/admin/users/edit/#{params[:user_id]}?err=4" unless user.valid?




        user.save

        UserHistory.create :admin_id => session[:user].id, :subject_id => user.id, :message => changes.join("\n")
        redirect to '/admin/users?ok=1'
    end

    get '/admin/users/edit/:user_id' do
        user = User.find params[:user_id]
        return 404 unless user 
        erb :'admin/user_edit', :locals => {:user => user}
    end

    get '/admin/users/history/:user_id' do
        user = User.find params[:user_id]
        return 404 unless user 
        erb :'admin/user_history', :locals => {:user => user}
    end

    post '/admin/users/enable' do 
         User.update params[:user_id], :enabled => true
        redirect to '/admin/users'
    end

    post '/admin/users/disable' do 
         User.update params[:user_id], :enabled => false unless User.find(params[:user_id]).admin and User.where("admin = \"t\" AND enabled = \"t\"").length == 1
        redirect to '/admin/users'
    end

    # post '/admin/users/delete',:auth => [:admin]  do
    #      User.destroy params[:user_id]
    #     redirect to '/admin/users'
    # end
end