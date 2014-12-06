class Settings < ActiveRecord::Base
    self.table_name = "settings"
    self.primary_key = 'key'
    serialize :value

    def Settings._get_or_create_max_active_downloads
        Settings.find_or_create_by!(key: 'MAX_ACTIVE_DOWNLOADS') do |max_active_downloads|
            max_active_downloads.value = 0
            max_active_downloads.name = "Max active downloads"
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
            max_remote_transfers.name = "Max remote transfers"
            max_remote_transfers.description = "Maximum number of concurrently active transfers from/to servers marked as located in a remote network."
        end
    end

    def Settings.get_max_remote_transfers
        value = Settings._get_or_create_max_remote_transfers.value
        return 20 unless value.between? 0, 500
        return value
    end

end