# -*- coding: utf-8 -*-
require 'resque'
require 'securerandom'
require 'rack/multipart/parser'

require_relative 'config'
require_relative 'extract'
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

      app.get '/deposit', :auth => true, :licence => true do
        erb :upload
      end

      app.post '/deposit', :auth => true, :licence => true do
        Rack::Multipart::Parser.new(env).parse
        
        pdf_name = SecureRandom.uuid
        temp_file = params[:file][:tempfile]
        repo_file = File.join(settings.repo_path, pdf_name)

        File.open(repo_file, 'w') do |file|
          while buff = temp_file.read(65536)
            file << buff
          end
        end
      
        Config.collection('pdfs').insert({:name => pdf_name, :uploaded_at => Time.now})
        Resque.enqueue(Extract, repo_file, pdf_name)

        # TODO Once async, do this instead:
        # json({:id => pdf_name})

        redirect("/deposit/#{pdf_name}")
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
            redirect "/deposit/#{name}/status"
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
        end

        erb :doi, :locals => locals
      end

      app.get '/deposit/:id/citations', :auth => true, :licence => true do
        pdfs = Config.collection('pdfs')
        pdf = pdfs.find_one({:id => params[:id]})
      end

      app.get '/deposit/:id/status', :auth => true, :licence => true do
      end

      app.get '/deposit/:id/citations/:index', :auth => true, :licence => true do
      end
    end

  end
end

