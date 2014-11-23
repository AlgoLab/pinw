require_relative 'jobs'
require_relative 'processing_status'
require_relative 'servers'
require_relative 'settings'
require_relative 'users'


module SqliteTransactionFix
  def begin_db_transaction
    log('begin immediate transaction', nil) { @connection.transaction(:immediate) }
    # log('transaction prevented', nil){}
  end

  # def commit_db_transaction
  #   log('commit prevented', nil){}
  # end
end

module ActiveRecord
  module ConnectionAdapters
    class SQLite3Adapter < AbstractAdapter
      prepend SqliteTransactionFix
    end
  end
end