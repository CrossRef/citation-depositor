# -*- coding: utf-8 -*-
require 'sinatra/base'
require 'erb'

require_relative 'lib/citation-depositor/labs_app'

class App
  use CitationDepositor::LabsBase
  use CitationDepositor::SimpleSessionAuth

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
  end

  # The UI

  get '/' do
    erb :index
  end

  get '/depositor/licence', :auth => true do
    if auth_doc[:licence_accepted]
      redirect '/depositor/upload'
    elsif params.has_key?(:accept)
      members = Config.collection('members')
      members.insert({:user => auth_doc[:user], :licence_accepted => true})
      redirect '/depositor/upload'
    else
      erb :licence
    end
  end

  get '/depositor/upload', :auth => true do
  end

  get '/depositor/doi', :auth => true do
  end

  get '/depositor/citations', :auth => true do
  end

  get '/depositor/edit', :auth => true do
  end

  get '/depositor/result', :auth => true do
  end

  get '/depositor/download', :auth => true do
  end

  # Some API

  api :get, '/jobs/:id' do
  end

  
end



