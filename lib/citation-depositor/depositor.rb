# -*- coding: utf-8 -*-
require 'resque'
require 'securerandom'
require 'rack/multipart/parser'
require 'faraday'
require 'nokogiri'
require 'open-uri'

require_relative 'config'
require_relative 'extract'
require_relative 'deposit'
require_relative 'recorded_job'

# TODO Requires auth and licence

module CitationDepositor
  module Depositor

    module Helpers
      def ensure_extraction pdf
        if pdf[:extraction_job]
          RecordedJob.get(pdf[:extraction_job])
        else
          id = Resque.enqueue(Extract, pdf[:filename])
          pdf[:extraction_job] = id
          Config.collection('pdfs').save(pdf)
          RecordedJob.get(id)
        end
      end

      def fetch_method error_result
        begin
          yield
        rescue TimeoutError => e
          error_result
        rescue StandardError => e
          error_result
        end
      end

      def fetch_owner_name owner_prefix
        fetch_method('') do
          resp = settings.cr_service.get("/getPrefixPublisher/?prefix=#{owner_prefix}")

          if resp.status != 200
            ''
          else
            doc = Nokogiri::XML(resp.body)
            doc.at_css('publisher_name').text
          end
        end
      end

      def fetch_owner_prefix doi
        fetch_method('') do
          resp = settings.doi_data_service.get("/#{doi}")

          if resp.status != 200
            ""
          else
            doc = Nokogiri::XML(resp.body)
            doc.at_css('doi_record')['owner']
          end
        end
      end

      def fetch_doi_info doi
        fetch_method({}) do
          resp = settings.search_service.get('/dois', :q => doi)
          result = {}

          if resp.status == 200
            doi_json = JSON.parse(resp.body)
            result = doi_json.first unless doi_json.count.zero?
          end

          result
        end
      end

      def fetch_citations doi
        fetch_method([]) do
          resp = settings.doi_data_service.get("/#{doi}")

          if resp.status != 200
            []
          else
            doc = Nokogiri::XML(resp.body)
            doc.css('citation')
          end
        end
      end
    end

    def self.registered app
      app.helpers Depositor::Helpers

      data_service = Faraday.new('http://data.crossref.org')
      data_service.headers[:accept] = 'application/vnd.crossref.unixref+xml'

      app.set :repo_path, File.join(app.settings.root, 'pdfs')
      app.set :search_service, Faraday.new('http://search.labs.crossref.org')
      app.set :doi_data_service, data_service
      app.set :cr_service, Faraday.new('http://www.crossref.org')

      app.get '/deposit', :auth => true, :licence => true do
        erb :upload
      end

      app.post '/deposit', :auth => true, :licence => true do
        pdf_url = params[:url]
        pdf_upload_filename = params[:filename]
        pdf_name = SecureRandom.uuid
        pdf_filename = File.join(settings.repo_path, pdf_name)
        now = Time.now

        doc = {
          :name => pdf_name,
          :uploaded_at => now,
          :user => auth_info['user'],
          :local_filename => pdf_filename,
          :upload_filename => pdf_upload_filename,
          :status => :uploaded,
          :status_at => now
        }

        Config.collection('pdfs').insert(doc)
        Resque.enqueue(Extract, pdf_url, pdf_filename, pdf_name)

        json({:pdf_name => pdf_name})
      end

      app.get '/deposit/:name', :auth => true, :licence => true do
        name = params[:name]
        pdfs = Config.collection('pdfs')
        pdf = pdfs.find_one({:name => name})

        # Put us in the right place depending on where in the process
        # this deposit has got to in the past.
        if pdf.nil?
          error 404
        else
          extraction_job = RecordedJob.get_where('extractions', {:name => name})
          deposit_job = RecordedJob.get_where('deposits', {:name => name})

          if deposit_job
            # If the pdf has a deposit job then show the result page.
            # This will indicate either a complete deposit or
            # processing deposit.
            redirect "/deposit/#{name}/deposit"
          elsif extraction_job && pdf['doi']
            # If the pdf has an extraction job and DOI then show the citations
            # page. This will show either citations or a loading
            # indicator if the extraction job hasn't yet finished.
            redirect "/deposit/#{name}/citations"
          elsif extraction_job
            # If the pdf has no DOI but has an extraction job, we must
            # ask for a DOI.
            redirect "/deposit/#{name}/doi"
          elsif pdf['uploaded_at']
            # If the pdf has no jobs but has been uploaded it is time
            # to start an extraction job and ask for a DOI.
            redirect "/deposit/#{name}/doi"
          else
            redirect '/deposit'
          end
        end
      end

      app.get '/deposit/:name/doi', :auth => true, :licence => true do
        name = params[:name]
        pdfs = Config.collection('pdfs')
        pdf = pdfs.find_one({:name => name})
        extraction_job = RecordedJob.get_where('extractions', {:name => name})
        locals = {}

        if extraction_job && extraction_job['doi']
          locals[:extracted_doi] = extraction_job['doi']
        end

        if pdf['doi']
          locals[:doi] = pdf['doi']
        else
          locals[:doi] = ''
        end

        erb :doi, :locals => locals
      end

      app.post '/deposit/:name/doi', :auth => true, :licence => true do
        pdfs = Config.collection('pdfs')
        pdf = pdfs.find_one({:name => params[:name]})

        if pdf.nil?
          redirect '/deposit'
        else
          pdf[:doi] = params[:doi]
          pdfs.save pdf
          redirect("/deposit/#{params[:name]}/citations")
        end
      end

      app.get '/deposit/:name/citations', :auth => true, :licence => true do
        name = params[:name]
        pdfs = Config.collection('pdfs')
        pdf = pdfs.find_one({:name => name})
        extraction_job = RecordedJob.get_where('extractions', {:name => name})
        locals = {}

        if extraction_job
          locals[:citations] = extraction_job['citations']
          locals[:status] = extraction_job['status']
        else
          locals[:citations] = []
          locals[:status] = :no_extraction
        end

        erb :citations, :locals => locals
      end

      app.get '/deposit/:name/deposit', :auth => true, :licence => true do
        name = params[:name]
        deposit = RecordedJob.get_where('deposits', {:name => name})

        erb :deposit, :locals => {:deposit => deposit}
      end

      app.post '/deposit/:name/deposit', :auth => true, :licence => true do
        name = params[:name]
        extraction = RecordedJob.get_where('extractions', {:name => name})
        pdf = Config.collection('pdfs').find_one({:name => name})

        unless extraction.nil? || !extraction.has_key?('citations')
          Resque.enqueue(Deposit,
                         name,
                         auth_info['user'],
                         auth_info['pass'],
                         pdf['doi'],
                         extraction['citations'])
        end

        erb :deposit
      end

      app.get '/deposit/:name/citations/:index', :auth => true, :licence => true do
        name = params[:name]
        index = params[:index].to_i
        extraction_job = RecordedJob.get_where('extractions', {:name => name})
        locals = {:name => name, :index => index}

        if extraction_job && extraction_job.has_key?('citations')
          locals[:citation] = extraction_job['citations'][index]
        end

        erb :citation, :locals => locals
      end

      app.post '/deposit/:name/citations/:index', :auth => true, :licence => true do
        name = params[:name]
        index = params[:index].to_i
        extraction_job = RecordedJob.get_where('extractions', {:name => name})

        extraction_job['citations'][index]['text'] = params[:text]
        extraction_job['citations'][index]['modified_at'] = Time.now

        if params.has_key?('doi') && !params[:doi].strip.empty?
          extraction_job['citations'][index]['doi'] = params[:doi]
        end

        Config.collection('extractions').save(extraction_job)

        redirect "/deposit/#{name}/citations"
      end

      app.get '/deposit/:name/status' do
        name = params[:name]
        extraction_job = RecordedJob.get_where('extractions', {:name => name})
        result = {}

        if extraction_job
          result[:status] = extraction_job['status']
        else
          result[:status] = :no_extraction
        end

        json({:status => extraction_job['status']})
      end

      app.get '/activity', :auth => true, :licence => true do
        opts = {:sort => [[:status_at, -1]]}
        pdfs = Config.collection('pdfs')
        deposited_pdfs = pdfs.find({:user => auth_info['user'], :status => :deposited}, opts)
        undeposited_pdfs = pdfs.find({:user => auth_info['user'], :status => {'$ne' => :deposited}}, opts)

        erb :activity, :locals => {:deposited => deposited_pdfs, :undeposited => undeposited_pdfs}
      end

      # Shadow doi search
      app.get '/dois/search' do
        res = settings.search_service.get('/dois', :q => params[:q])
        content_type 'application/json', :charset => 'utf-8'
        status res.status
        res.body
      end

      # Shadow data proxy
      app.get '/dois/info' do
        response_data = {}
        doi = params[:doi]
        owner_prefix = fetch_owner_prefix(doi)
        owner_name = fetch_owner_name(owner_prefix)
        doi_info = fetch_doi_info(doi)

        if owner_name.empty? || doi_info.empty?
          json({:status => 'error'})
        else
          doc = {
            :status => 'ok',
            :owner_name => owner_name,
            :owner_prefix => owner_prefix,
            :info => doi_info
          }
          json(doc)
        end
      end

      app.get '/help/widget' do
        erb :widget_help
      end

      app.get '/help/check' do
        page_url = params[:url]
        page_url = "http://#{page_url}" if !(params[:url] =~ /\Ahttps?:\/\//)

        html = Nokogiri::HTML(open(page_url))
        result = {}

        # We're going to check the page for a DOI meta tag, then check for a script
        # tag with the correct src. Finally, if we find a meta tag, we'll check
        # the DOI for citations.

        metas = html.css('meta')
        dci_metas = metas.reject {|meta| meta['name'].nil? || meta['name'].downcase != 'dc.identifier'}
        doi = dci_metas.map {|meta| meta['content'].sub('info:doi/', '').sub('doi:', '')}.first

        scripts = html.css('script')
        widgets = scripts.reject do |script|
          script['src'].nil? || script['src'] != 'http://depositor.labs.crossref.org/js/widget.js'
        end

        result[:has_citations] = !fetch_citations(doi).empty? unless doi.nil?
        result[:has_citations] = false if doi.nil?
        result[:has_widget] = !widgets.empty?
        result[:has_meta] = !doi.nil?
        result[:doi] = doi

        json(result)
      end

      app.get '/help' do
        erb :help
      end
    end

  end
end

