require 'net/http'
require 'uri'
require 'json'

class InvalidResponseError < RuntimeError; end

# Ensembl REST API, to see all Endpoint and documentation visit: http://rest.ensembl.org/
class EnsemblApi

  BASE_ENDPOINT = 'http://rest.ensembl.org'
  url = URI.parse(BASE_ENDPOINT)
  @http = Net::HTTP.new(url.host, url.port)


  # Return Ensembl id given species(organism) and gene name
  # For more information visit: http://rest.ensembl.org/documentation/info/xref_external
  def self.get_ensembl_id(species,gene_name)
  	path_for_id = "/xrefs/symbol/#{species}/#{gene_name}?"
  	begin
  		request = Net::HTTP::Get.new(path_for_id, {'Content-Type' => 'application/json'})
  		response = @http.request(request)

      # If response is not 200 we encountered an error
      raise InvalidResponseError if response.code != "200"

  		result = JSON.parse(response.body)
  		# The id is in first position
  		ensembl_id = result[0]["id"]
  	end
  	ensembl_id.to_s
  end


  # Return fasta file given species (organism) and ensembl id
  # For more information visit: http://rest.ensembl.org/documentation/info/sequence_id
  def self.get_and_save_fasta_file(species,ensembl_id,genomics_filepath)
    path_for_fasta = "/sequence/id/#{ensembl_id}?type=genomic;species=#{species}"

    begin
    	request = Net::HTTP::Get.new(path_for_fasta, {'Content-Type' => 'text/x-fasta'})
      response = @http.request(request)
        # If response is not 200 we encountered an error
      raise InvalidResponseError if response.code != "200"

      File.open(genomics_filepath, 'w') do |f|
          f.write(response.body)
      end
    end
  end

end
