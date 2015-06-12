require_relative 'organisms'
require_relative 'jobs'
require_relative 'processing_status'
require_relative 'servers'
require_relative 'settings'
require_relative 'users'
require_relative 'results'

# Sqlite3 can't easily handle concurrent access to a DB.
# From the official sqlite site:

# Transactions can be deferred, immediate, or exclusive. 
# The default transaction behavior is deferred. Deferred 
# means that no locks are acquired on the database until 
# the database is first accessed. Thus with a deferred 
# transaction, the BEGIN statement itself does nothing to 
# the filesystem. Locks are not acquired until the first 
# read or write operation. The first read operation against 
# a database creates a SHARED lock and the first write 
# operation creates a RESERVED lock. Because the acquisition
# of locks is deferred until they are needed, it is possible
# that another thread or process could create a separate
# transaction and write to the database after the BEGIN on
# the current thread has executed. If the transaction is 
# immediate, then RESERVED locks are acquired on all databases 
# as soon as the BEGIN command is executed, without waiting for 
# the database to be used.

# This module forces all transactions to be immediate and so
# prevents multiple processes from starting transactions at
# bad times.

module Sqlite3TransactionFix
  def begin_db_transaction
    log('begin immediate transaction', nil) { @connection.transaction(:immediate) }
  end
end

module ActiveRecord
  module ConnectionAdapters
    class SQLite3Adapter < AbstractAdapter
      prepend Sqlite3TransactionFix
    end
  end
end

# On some systems, it seems times lose precision when saved 
# in Sqlite and then parsed back. Rounding allows for correct
# testing for equality (not really used anywhere as of now, tho).

class Time
  def Time.now
    Time.new.round(6)
  end
end