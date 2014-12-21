class ProcessingState < ActiveRecord::Base
    self.table_name = "processing_status"
    self.primary_key = 'key'
    serialize :value

    ## ACTIVE DOWNLOADS ##
    def ProcessingState._get_or_create_active_downloads
        return ProcessingState.find_or_create_by(key: 'ACTIVE_DOWNLOADS') do |active_downloads|
            active_downloads.value = {}
        end
    end

    def ProcessingState.get_active_downloads
        return ProcessingState._get_or_create_active_downloads.value
    end

    def ProcessingState.add_active_download url
        ProcessingState.transaction do
            adl = ProcessingState._get_or_create_active_downloads
            return if adl.value[url]
            adl.value[Process.pid] = url
            adl.save
        end
    end

    def ProcessingState.remove_active_download
        ProcessingState.transaction do
            adl = ProcessingState._get_or_create_active_downloads
            adl.value.delete(Process.pid)
            adl.save
        end
    end

    ## REMOTE TRANSFERS ##
    def ProcessingState._get_or_create_remote_transfers
        return ProcessingState.find_or_create_by(key: 'REMOTE_TRANSFERS') do |remote_transfers|
            remote_transfers.value = {}
        end
    end

    def ProcessingState.get_remote_transfers
        return ProcessingState._get_or_create_remote_transfers.value
    end

    def ProcessingState.add_remote_transfer ident
        ProcessingState.transaction do
            adl = ProcessingState._get_or_create_remote_transfers
            return if adl.value[ident]
            adl.value[Process.pid] = ident
            adl.save
        end
    end

    def ProcessingState.remove_remote_transfer
        ProcessingState.transaction do
            adl = ProcessingState._get_or_create_remote_transfers
            adl.value.delete(Process.pid)
            adl.save
        end
    end



end