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

    get '/result/:result_id' do
        result = params[:result_id]
        erb :'result', locals: { result: result }
    end    
end
