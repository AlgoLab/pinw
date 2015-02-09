class Init < ActiveRecord::Migration
  def change

      ## JOBS ##
      create_table :jobs do |table|
      #table.column :status,         :string, default: 'QUEUED_DOWNLOAD'

      table.column :gene_name,         :string
      table.column :quality_threshold, :integer, default: 33
      table.column :description,       :string


      table.column :paused, :boolean, default: false

      
      table.column :awaiting_download, :boolean, default: false

      # table.column :ensembl_enabled,     :boolean,     default: true
      table.column :ensembl,            :string
      table.column :ensembl_pid,        :integer, 	default: nil
      table.column :ensembl_lock,       :datetime,  default: Time.at(0)
      table.column :ensembl_last_retry, :datetime,  default: Time.at(0)
      table.column :ensembl_retries,    :integer,   default: 0
      table.column :ensembl_last_error, :string
      table.column :ensembl_ok,         :boolean, 	default: false
      table.column :ensembl_failed,     :boolean, 	default: false


      table.column :genomics_ensembl,     :boolean,   default: false
      table.column :genomics_url,         :string
      table.column :genomics_pid,         :integer,	  default: nil
      table.column :genomics_lock,        :datetime,  default: Time.at(0)
      table.column :genomics_last_retry,  :datetime,  default: Time.at(0)
      table.column :genomics_retries,     :integer,   default: 0
      table.column :genomics_last_error,  :string
      table.column :genomics_ok,          :boolean, 	default: false
      table.column :genomics_failed,      :boolean, 	default: false
      
      table.column :reads_last_error,   :string
      table.column :all_reads_ok,       :boolean, default: false
      table.column :some_reads_failed,  :boolean, default: false

      table.column :downloads_completed_at, :datetime, default: nil


      table.column :awaiting_dispatch, :boolean, default: false

      table.column :processing_dispatch_pid,    :integer, default: nil
      table.column :processing_dispatch_lock,   :datetime, default: Time.at(0)
      table.column :processing_dispatched_at,   :datetime, default: Time.at(0)
      table.column :processing_dispatch_error,  :string 
      table.column :processing_dispatch_ok,     :boolean, default: false

      table.column :processing_metrics,  :string
      table.column :processing_error, :string # pids are stored on the remote machine and polling is peformed by another script


      
      table.references :server
      table.references :user
      table.references :organism
      table.references :result,    :index => true
      table.timestamps

      # table.index :results_id, :unique => true
    end


    ## JOB READ URLS ##
    create_table :jobs_reads do |table|
      table.references :job

      table.column :url,        :string
      table.column :retries,    :integer,   default: 0
      table.column :last_retry, :datetime,  default: Time.at(0)
      table.column :pid,        :integer
      table.column :lock,       :datetime,  default: Time.at(0)
      table.column :ok,         :boolean,   default: false
      table.column :failed,     :boolean,   default: false
      table.column :last_error, :string

      table.timestamps
    end



    ## PROCESSING STATUS ##
    create_table :processing_status do |table|
      table.column :key, :string
      table.column :value, :text
      table.column :name, :string
      table.timestamps
    end


    ## RUNTIME SETTINGS ##
    create_table :settings do |table|
      table.column :key, :string
      table.column :value, :text
      table.column :name, :string
      table.column :description, :string
      table.column :html_field_type, :string
      table.timestamps
    end


    ## RESULTS ##
    create_table :results do |table|
      table.column :TODO,      :string
      table.references :user
      table.references :server
      table.references :job

      table.index :job_id, unique: true
      table.timestamps
    end



    ## SERVERS ##
    create_table :servers do |table|
      table.column :priority,     :integer           

      table.column :name,     :string, null: false           
      table.column :host,     :string, null: false           
      table.column :port,     :string
      table.column :username, :string, null: false


      table.column :password,           :string
      table.column :client_certificate, :string
      table.column :client_passphrase,  :string       

      table.column :ssh_proxy_command,    :string         
      table.column :working_dir,      :string            

      table.column :use_callback,  :boolean, default: true
      table.column :callback_url,  :string            

      table.column :local_network, :boolean, default: true
      table.column :enabled,       :boolean, default: true


      table.column :check_lock, :datetime, default: Time.at(0)
      table.column :check_last_at, :datetime, default: Time.at(0)
      table.column :check_pid, :integer
      table.column :last_check_error, :string
      table.timestamps

      table.index :name, unique: true


      table.index :priority, :unique => true
    end



    ## USERS ##
    create_table :users do |table|
      table.column :nickname, :string
      table.column :password, :string
      table.column :email,    :string
      table.column :admin,    :boolean, :default => false
      table.column :enabled,  :boolean, :default => true
      table.column :max_fs,   :integer, :default => -1
      table.column :max_cput, :integer, :default => -1
      table.column :max_ql,   :integer, :default => -1
      table.timestamps

      table.index :nickname, :unique => true
    end



    ## USER EDIT HISTORY ##
    create_table :user_history do |table|
      table.references :admin
      table.references :subject
      table.column :message, :string
      table.timestamps
    end

    ## ORGANISMS ##
    create_table :organisms do |table|
      table.column :name, :string
      table.column :ensembl_id, :string
      table.column :description, :string
      table.column :enabled, :boolean, default: true
    end


  end
end
