# -*- coding: utf-8 -*-
require_relative 'config'

# TODO Requires auth and licence

module CitationDepositor
  module Depositor

    module Helpers
      def ensure_extraction pdf
        if pdf[:extraction_job]
          RecordedJob.get(pdf[:extraction_job])
        else
          id = Resque.enqueue(CitationDepositor::Extract, pdf[:filename])
          pdf[:extraction_job] = id
          Config.collection('pdfs').save(pdf)
        RecordedJob.get(id)
        end
      end
    end

    def self.registered app
      app.helpers Depositor::Helpers

      app.get '/deposit', :auth => true, :licence => true do
        erb :upload
      end

      app.get '/deposit/:id', :auth => true, :licence => true do
        pdfs = Config.collection('pdfs')
        pdf = pdfs.find_one({:id => params[:id]})
    
        # Put us in the right place depending on where in the process
        # this deposit has got to in the past.
        if pdf.nil?
          error 404
        elsif pdf[:deposit_job]
          # If the pdf has a deposit job then show the result page.
          # This will indicate either a complete deposit or
          # processing deposit.
          redirect "/deposit/#{params[:id]}/status"
        elsif pdf[:extraction_job] && pdf[:doi]
          # If the pdf has an extraction job and DOI then show the citations
          # page. This will show either citations or a loading
          # indicator if the extraction job hasn't yet finished.
          redirect "/deposit/#{params[:id]}/citations"
        elsif pdf[:extraction_job]
          # If the pdf has no DOI but has an extraction job, we must
          # ask for a DOI.
          redirect "/deposit/#{params[:id]}/doi"
        elsif pdf[:uploaded_at]
          # If the pdf has no jobs but has been uploaded it is time
          # to start an extraction job and ask for a DOI.
          redirect "/deposit/#{params[:id]}/doi"
        else
          redirect '/deposit'
        end
      end

      app.get '/deposit/:id/doi', :auth => true, :licence => true do
        pdfs = Config.collection('pdfs')
        pdf = pdfs.find_one({:id => params[:id]})
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

