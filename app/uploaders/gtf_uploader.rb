# encoding: utf-8

require 'zlib'
require 'open-uri'

class GtfUploader < CarrierWave::Uploader::Base

  # Choose what kind of storage to use for this uploader:
  storage :file
  # storage :fog

  after :store, :convert_file

  def convert_file upfile
    if self.filename.ends_with?( 'gz' )
      zipped_file = open( self.file.path )
      unzipped_file = open( self.file.path.chomp( 'gz') + 'gtf', 'w' )
      gz = Zlib::GzipReader.new( zipped_file )
      gz.each_line do |line|
        unzipped_file << line
      end
      File.delete self.file.path
      model.local_file = unzipped_file.path
      zipped_file.close
      unzipped_file.close
    else
      model.local_file = self.file.path
    end
    model.save
  end

  # Override the directory where uploaded files will be stored.
  # This is a sensible default for uploaders that are meant to be mounted:
  def store_dir
    "uploads/#{model.request_id}"
  end

  # -----
  # # Same as ReadsUploader
  # process :unzip, :if => :zipped?
  # process :notzip, :if => :not_zipped?

  # def zipped? model
  #   [ '.gz', '.zip' ].include? File.extname( model.original_filename )
  # end

  # def not_zipped? model
  #   not zipped? model
  # end

  # def unzip
  #   zipped_path = 'public/' + model.path.cache_dir + '/' + model.path.cache_name 
  #   unzipped_path = ['public/uploads', model.request_id, model.path.filename.chomp( 'gz' ) + 'gtf'].join('/')
  #   infile = open( zipped_path )
  #   outfile = open( unzipped_path, 'w' )
  #   gz = Zlib::GzipReader.new( infile )
  #   gz.each_line do |line|
  #     outfile << line
  #   end
  #   outfile.close
  #   infile.close
  #   model.local_file = unzipped_path
  #   CarrierWave.clean_cached_files!
  # end

  # def notzip
    
  # end


  # Provide a default URL as a default if there hasn't been a file uploaded:
  # def default_url
  #   # For Rails 3.1+ asset pipeline compatibility:
  #   # ActionController::Base.helpers.asset_path("fallback/" + [version_name, "default.png"].compact.join('_'))
  #
  #   "/images/fallback/" + [version_name, "default.png"].compact.join('_')
  # end

  # Process files as they are uploaded:
  # process :scale => [200, 300]
  #
  # def scale(width, height)
  #   # do something
  # end

  # Create different versions of your uploaded files:
  # version :thumb do
  #   process :scale => [50, 50]
  # end

  # Add a white list of extensions which are allowed to be uploaded.
  # For images you might use something like this:
  def extension_white_list
    %w(gff gtf gz zip)
  end

  # Override the filename of the uploaded files:
  # Avoid using model.id or version_name here, see uploader/store.rb for details.
  # def filename
  #   "transcript.gtf" if original_filename
  # end

end
