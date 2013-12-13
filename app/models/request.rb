# encoding: utf-8

require 'zlib'
require 'open-uri'

class Request < ActiveRecord::Base
  has_one :reads
  has_one :gtf

  def self.crawl_data
    # Test if the script is already running using a .lock file. This is a stupid hack
    # because i can't find a way to make the command found here:
    # http://stackoverflow.com/questions/661684/how-do-i-ensure-only-one-instance-of-a-ruby-script-is-running-at-a-time
    # work correctly (flock doesn't work as expected when i run Request.crawl_data with
    # whenever, maybe the lock is tested on the same pid?)
    #
    # This hack works because i know that this script runs every minute and that
    # the time between 'exists?' and 'new' should be some order of magnitude
    # smaller
    exit if File.exists?("tmp/crawler.lock")
    begin
      flk = File.new("tmp/crawler.lock", "w+")
      flk.close
      requests = self.find(:all, :conditions => {:status => RequestsController::NEWREQ})
      requests.each do |r|
        r.status = RequestsController::COMPUTING
        r.save!
        if r.reads.stored == false
          r.reads.path = ReadsUploader.new
          # Force download from remote url
          r.reads.remote_path_url = r.reads.url
          r.reads.stored = true
          r.reads.save
        end
        # Do the same with r.gtf!
        if r.gtf.stored == false
          r.gtf.path = GtfUploader.new
          # Force download from remote url
          r.gtf.remote_path_url = r.gtf.url
          r.gtf.stored = true
          r.gtf.save
        end
        r.status = RequestsController::READY
        r.save
      end
    ensure
      # Release lock
      File.delete("tmp/crawler.lock")
    end
  end
    
end
