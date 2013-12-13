# encoding: utf-8

class RequestsController < ApplicationController
  NEWREQ = 0
  COMPUTING = 1
  READY = 2

  def new
  end

  def create
    @request = Request.new( request_params )

    gtf_path= params[:request][:gtf][:path]
    gtf_url=  params[:request][:gtf][:url]

    reads_path= params[:request][:reads][:path]
    reads_url=  params[:request][:reads][:url]
    
    flash[ :error ] = []

    if not (gtf_path.nil? ^ gtf_url.empty?)
      flash[ :error ] << "Please choose one and only one option for the gtf file."
    end
    if not( reads_path.nil? ^ reads_url.empty? )
      flash[ :error ] << "Please choose one and only one option for the reads file."
    end

    if not flash[ :error ].empty?
      render 'new'
    else
      gtf_stored = ( not gtf_path.nil? )
      reads_stored = ( not reads_path.nil? )

      @request.status = NEWREQ

      @gtf = @request.build_gtf( path: gtf_path, url: gtf_url, stored: gtf_stored,
                                 request_id: params[ :id ] )

      @reads = @request.build_reads( path: reads_path, url: reads_url,
                                     stored: reads_stored, request_id: params[ :id ] )

      if @request.save
        flash[ :added_request_id ] =  @request.id
        redirect_to action: 'index'
      else
        render 'new'
      end
    end
  end

  def index
    @requests = Request.all
  end

private
  def request_params
    params.require( :request ).permit( :hugo_name )
  end
end
