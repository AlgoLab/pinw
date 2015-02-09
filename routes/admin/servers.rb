# encoding: utf-8
require "sinatra/json"

class PinW < Sinatra::Application

    get '/admin/servers/?' do
        server_list = Server.order(priority: :asc)
        erb :'admin/servers', locals: { server_list: server_list }
    end


    post '/admin/servers/new' do
        server = Server.new

        server.priority = (Server.maximum(:priority) or 0) + 1
        server.name = params[:InputName]
        server.host = params[:InputHost]
        server.port =  params[:InputPort]
        server.username = params[:InputUsername]

        # PASSWORD OR KEY
        case params[:type]
        when '1'
            server.password = params[:InputPassword]
        when '2'
            server.client_certificate = params[:InputCertificate]
            server.client_passphrase = params[:InputPassphrase] if params[:InputPassphrase].length > 0
        end

        # PROXY COMMAND
        server.ssh_proxy_command = params[:InputProxyCommand] 


        # ENV SETTINGS
        server.working_dir = params[:InputWorkingDir]
        server.use_callback = params[:InputUseCallback]
        server.callback_url = params[:InputCallbackURL]
        
        server.local_network = params[:InputLocalNetwork]
        server.enabled = true
        
        redirect to '/admin/servers?err=2' unless server.valid?

        server.save

        redirect to '/admin/servers?ok=1'
    end

    post '/admin/servers/test' do
        server = Server.new
        server.host = params[:InputHost]
        server.port = params[:InputPort]

        server.username = params[:InputUsername]
        case params[:type]
        when '1'
            server.password = params[:InputPassword]
        when '2'
            server.client_certificate = params[:InputCertificate]
            server.client_passphrase = params[:InputPassphrase]
        end

        # PROXY COMMAND
        server.ssh_proxy_command = params[:InputProxyCommand]

        # ENV SETTINGS
        server.working_dir = params[:InputWorkingDir]
        server.use_callback = params[:InputUseCallback]
        server.callback_url = params[:InputCallbackURL]
        return json server.test_configuration
    end

    get '/admin/servers/edit/:server_id' do
        server = Server.find params[:server_id]
        return 404 unless server
        erb :'admin/server_edit', locals: { server: server }
    end


    post '/admin/servers/edit' do
        server = Server.find(params[:server_id])
        redirect to '/admin/servers?err=2' unless server

        server.priority = (Server.maximum(:priority) or 0) + 1
        server.name = params[:InputName]
        server.host = params[:InputHost]
        server.port =  params[:InputPort]
        server.username = params[:InputUsername]

        # PASSWORD OR KEY
        case params[:type]
        when '1'
            server.password = params[:InputPassword]
        when '2'
            server.client_certificate = params[:InputCertificate]
            server.client_passphrase = params[:InputPassphrase]
        end

        # PROXY COMMAND
        server.ssh_proxy_command = params[:InputProxyCommand]

        # ENV SETTINGS
        server.working_dir = params[:InputWorkingDir]
        server.use_callback = params[:InputUseCallback]
        server.callback_url = params[:InputCallbackURL]
        
        server.local_network = params[:InputLocalNetwork]
        
        redirect to '/admin/servers?err=2' unless server.valid?

        server.save

        redirect to '/admin/servers?ok=3'
    end


    post '/admin/servers/enable' do 
         Server.update params[:server_id], :enabled => true
        redirect to '/admin/servers'
    end


    post '/admin/servers/disable' do 
         Server.update params[:server_id], :enabled => false
        redirect to '/admin/servers'
    end

    post '/admin/servers/up' do
        Server.transaction do
            server = Server.find params[:server_id]
            if server.priority == 1
                redirect to '/admin/servers?err=3'
            end
            oldPriority = server.priority
            newPriority = oldPriority - 1
            tempServer = Server.find_by priority: newPriority
            server.update priority: 0
            tempServer.update priority: oldPriority 
            server.update priority: newPriority
        end
        redirect to '/admin/servers'
    end

    post '/admin/servers/down' do
        Server.transaction do
            server = Server.find params[:server_id]
            if server.priority == Server.maximum(:priority)
                redirect to '/admin/servers?err=4'
            end
            oldPriority = server.priority
            newPriority = oldPriority + 1
            tempServer = Server.find_by priority: newPriority
            server.update priority: 0
            tempServer.update priority: oldPriority 
            server.update priority: newPriority
        end
        redirect to '/admin/servers'
    end

    post '/admin/servers/delete' do
        Server.transaction do
            server = Server.find params[:server_id]
            server.destroy
            Server.reindex
        end
        redirect to '/admin/servers?ok=2'
    end
end