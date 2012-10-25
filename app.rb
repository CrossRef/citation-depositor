# -*- coding: utf-8 -*-
require 'sinatra/base'
require 'erb'
require 'pony'

require_relative 'lib/citation-depositor/labs'
require_relative 'lib/citation-depositor/auth'

class App < Sinatra::Base
  register CitationDepositor::LabsBase
  register CitationDepositor::SimpleSessionAuth

  set :licence_addr_to, 'citationlicence@crossref.org'
  set :licence_addr_from, 'labs@crossref.org'
  set(:licence) { |val| condition { is_licenced? } }

  helpers do
    def alive?
      # TODO Perform a few checks and return true or false
      true
    end

    def stats
      # TODO Some more interesting stats
      {:some => 'response'}
    end

    def authorized? user, pass
      # TODO Eventually, when it is possible, check these
      # creds against the deposit system without performing
      # a deposit.
      true
    end

    # Helpers related to licencing

    def licence_info
      request.env[:licence]
    end

    def is_licenced?
      !licence_info.nil? && licence_info[:active]
    end
    
    def activate_licence!
      user = auth_info[:user]

      Pony.mail(:to => settings.licence_addr_to,
                :from => settings.licence_addr_from,
                :subject => "Account #{user} has accepted the citation deposit licence.",
                :body => "Account #{user} has acepted the citation deposit licence.")

      licences = Config.collection('licences')
      licences.update({:user => user}, {:active => true})
    end

    # Job helpers

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

  # Get licence info if the user is logged in

  before do
    unless auth_info.nil?
      licences = Config.collection('licences')
      request.env[:licence] = licences.find_one({:user => auth_info[:user]})
    end
  end

  # The UI

  get '/' do
    erb :index
  end

  get '/licence', :auth => true do
    if auth_doc[:licence_accepted]
      redirect '/deposit'
    elsif params.has_key?(:accept)
      activate_licence!
      redirect '/deposit'
    else
      erb :licence
    end
  end

  get '/deposit', :auth => true, :licence => true do
    erb :upload
  end

  get '/deposit/:id', :auth => true, :licence => true do
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

  get '/deposit/:id/doi', :auth => true, :licence => true do
    pdfs = Config.collection('pdfs')
    pdf = pdfs.find_one({:id => params[:id]})
  end

  get '/deposit/:id/citations', :auth => true, :licence => true do
    pdfs = Config.collection('pdfs')
    pdf = pdfs.find_one({:id => params[:id]})
  end

  get '/deposit/:id/status', :auth => true, :licence => true do
  end

  get '/deposit/:id/citations/:index', :auth => true, :licence => true do
  end

  

end



