# -*- coding: utf-8 -*-
require 'resque'
require 'securerandom'
require 'rack/multipart/parser'
require 'faraday'

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
    end

    def self.registered app
      app.helpers Depositor::Helpers

      app.set :repo_path, File.join(app.settings.root, 'pdfs')
      app.set :search_service, Faraday.new('http://search.labs.crossref.org')

      app.get '/deposit', :auth => true, :licence => true do
        erb :upload
      end

      app.post '/deposit', :auth => true, :licence => true do
        pdf_url = params[:url]
        pdf_name = SecureRandom.uuid
        pdf_filename = File.join(settings.repo_path, pdf_name)
        Config.collection('pdfs').insert({:name => pdf_name, :uploaded_at => Time.now})
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

        if extraction_job && extraction_job.has_key?('citations')
          locals[:citations] = extraction_job['citations']
        else
          locals[:citations] = []
        end

        erb :citations, :locals => locals
      end

      app.get '/deposit/:name/deposit', :auth => true, :licence => true do
        erb :deposit
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

      # Shadow cr-search /dois
      app.get '/search/dois' do
        res = settings.search_service.get('/dois', :q => params[:q])
        content_type 'application/json', :charset => 'utf-8'
        status res.status
        res.body
      end
    end

  end
end

