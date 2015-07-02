# encoding: utf-8

class PinW < Sinatra::Application
    require 'will_paginate'
    require 'will_paginate/active_record'
    WillPaginate.per_page = 10
	
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

        results = Result.all()
        r = Result.arel_table

        # ORGANISM
        if params[:InputOrganism] and params[:InputOrganism] != '-1'
            results = results.where(organism_id: params[:InputOrganism])
        end

        # VALIDATION
        if params[:InputValidated]
            results = results.where(validated: (params[:InputValidated] != nil))
        end

        # GENE MATCHES
        if params[:InputGeneName] && params[:InputGeneName].length > 0
            gene_query = params[:InputGeneName].split.map{|x| r[:gene_name].matches('%' + x + '%')}.reduce{|m, x| m.or(x)}
            results = results.where(gene_query)
        end

        # REF_SEQ MATCHES
        if params[:InputRefSeq] && params[:InputRefSeq].length > 0
            ref_query = params[:InputRefSeq].split.map{|x| r[:ref_sequence].matches('%' + x + '%')}.reduce{|m, x| m.or(x)}
            results = results.where(ref_query)
        end

        erb :'results', locals: {organism_list: organism_list, results: results.paginate(:page => params[:page]).order('id DESC')}
    end 

    get '/result/:result_id' do
        result = Result.find(params[:result_id])
        erb :'result', locals: { result: result }
    end    
end
