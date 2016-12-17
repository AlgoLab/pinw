
class Server < ActiveRecord::Base
  validates_uniqueness_of :name, :priority
  validates :name, length: { in: 3..40 }
  validates :host, format: { with: /\A(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])|(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])\z/,
    message: "invalid host" }
  validates :port, numericality: { only_integer: true, greater_than: 0, less_than: 65535 + 1 }
  validates :username, presence: true
  has_many :jobs, :class_name => 'Job', :foreign_key => 'server_id'

  # validates_each :name, :surname do |record, attr, value|

  # end


  def test_configuration
    require 'net/ssh'
    k = Settings.get_ssh_keys
    options = {}
    options[:port] = self.port
    options[:password] = self.password if self.password
    options[:key_data] = [k[:private_key]]
    options[:verbose] = :debug
    # Proxy Command support:
    if self.ssh_proxy_command.length > 0
        debug "instantiating proxy command"
        options[:proxy] = Net::SSH::Proxy::Command.new(self.ssh_proxy_command)
    end
    begin
      Net::SSH.start(self.host, self.username, options) do |ssh|
          return {:success => true, :msg => ssh.exec!('uname -a')}
      end
    rescue => ex
      return {:success => false, :msg => ex.message}
    end
  end

  def active_jobs
    return Jobs.where("server_id = #{self.id} AND status != 'COMPLETE'")
  end

  def self.reindex
    Server.order(priority: :asc).each_with_index do |server, i|
      server.update priority: i + 1
    end
  end
end
