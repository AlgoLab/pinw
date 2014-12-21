# encoding: utf-8

class PinW < Sinatra::Application
	
    # Auth checks:
    before '/results/*' do
        session[:user] = nil
        current_user = User.find(session[:user].id) unless session[:user]
        if current_user
            session[:user] = current_user
        end
    end

    get '/results/?' do
        organism_list = Organism.where(enabled: true)
        erb :'results', locals: {organism_list: organism_list}
    end    
end
