# encoding: utf-8


class PinW < Sinatra::Application
    post '/login/?' do
        redirect to '/home' if session[:user]

        db_user = User.find_by_nickname params[:InputUser]
        redirect to '/?err=1' unless db_user and (db_user.password == params[:InputPassword])
        redirect to '/?err=2' unless db_user.enabled
        session[:user] = db_user
        redirect to '/home'
    end

    get '/logout/?' do
         session[:user] = nil
         redirect to '/'
    end

    get '/quick_new_job/?' do
        redirect to '/home' if session[:user]
        guest = User.find_by_nickname 'guest'
        redirect to '/?err=3' unless guest.enabled
        session[:user] = guest
        redirect to '/jobs?auto=1'
    end
end