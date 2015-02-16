class Settings < ActiveRecord::Base
    self.table_name = "settings"
    self.primary_key = 'key'
    serialize :value

    def Settings._get_or_create_max_active_downloads
        Settings.find_or_create_by!(key: 'MAX_ACTIVE_DOWNLOADS') do |max_active_downloads|
            max_active_downloads.value = 0
            max_active_downloads.name = "Max active downloads"
            max_active_downloads.html_field_type = 'number'
            max_active_downloads.description = "Maximum number of concurrently active downloads."
        end
    end

    def Settings.get_max_active_downloads
        value = Settings._get_or_create_max_active_downloads.value
        return 20 unless value.between? 0, 500
        return value
    end

    def Settings._get_or_create_max_remote_transfers
        Settings.find_or_create_by!(key: 'MAX_REMOTE_TRANSFERS') do |max_remote_transfers|
            max_remote_transfers.value = 0
            max_remote_transfers.html_field_type = 'number'
            max_remote_transfers.name = "Max remote transfers"
            max_remote_transfers.description = "Maximum number of concurrently active transfers from/to servers marked as located in a remote network."
        end
    end

    def Settings.get_max_remote_transfers
        value = Settings._get_or_create_max_remote_transfers.value
        return 20 unless value.between? 0, 500
        return value
    end

    def Settings._get_or_create_ssh_keys
        require 'sshkey'
        
        k = SSHKey.generate(type: "RSA", bits: 2048, comment: "PinW")
        private_key = Settings.find_or_create_by(key: 'SSH_PRIVATE_KEY') do |ssh_key|
            ssh_key.name = 'PinW SSH private key'
            ssh_key.description = "Used for public key authentication."
            ssh_key.value = k.private_key
        end

        public_key = Settings.find_or_create_by(key: 'SSH_PUBLIC_KEY') do |ssh_key|
            ssh_key.name = 'PinW SSH Public Key'
            ssh_key.description = "To be placed on remote hosts using public key authentication."
            ssh_key.value = k.ssh_public_key
        end 
        return {private_key: private_key.value, public_key: public_key.value}       
    end

    def Settings.get_ssh_keys
        return Settings._get_or_create_ssh_keys
    end

    # Init settings
    Settings.get_ssh_keys
    Settings.get_max_active_downloads
    Settings.get_max_remote_transfers


end