# encoding: utf-8

require 'zlib'
require 'open-uri'

class ReadsUploader < CarrierWave::Uploader::Base

  # Choose what kind of storage to use for this uploader:
  storage :file

  after :store, :convert_file

  def convert_file upfile
    if self.filename.ends_with?( 'gz' )
      zipped_file = open( self.file.path )
      unzipped_file = open( self.file.path.chomp( 'gz') + 'fa', 'w' )
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

  # # Override the directory where uploaded files will be stored.
  # # This is a sensible default for uploaders that are meant to be mounted:
  def store_dir
    "uploads/#{model.request_id}"
  end

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
  #   unzipped_path = [ 'tmp', model.path.filename.chomp( 'gz' ) + 'fa' ].join( '/' )
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

  # Add a white list of extensions which are allowed to be uploaded.
  # For images you might use something like this:
  def extension_white_list
    %w(fa fasta fq fastq gz tar.gz)
  end

  # Override the filename of the uploaded files:
  # Avoid using model.id or version_name here, see uploader/store.rb for details.
  # def filename
  #   "reads.fa" if original_filename
  # end

end
