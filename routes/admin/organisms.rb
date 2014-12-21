# encoding: utf-8
require "sinatra/json"

class PinW < Sinatra::Application

    get '/admin/organisms/?' do
        organism_list = Organism.order(name: :asc)
        erb :'admin/organisms', locals: { organism_list: organism_list }
    end


    post '/admin/organisms/new' do
        organism = Organism.new

        organism.name = params[:InputName]
        organism.ensembl_id = params[:InputEnsembl]
        organism.description =  params[:InputDescription]

        organism.enabled = true

        redirect to '/admin/organisms?err=1' unless organism.valid?
        
        organism.save

        redirect to '/admin/organisms?ok=1'
    end

    post '/admin/organisms/enable' do 
         Organism.update params[:organism_id], :enabled => true
        redirect to '/admin/organisms'
    end


    post '/admin/organisms/disable' do 
         Organism.update params[:organism_id], :enabled => false
        redirect to '/admin/organisms'
    end

end
