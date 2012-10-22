# -*- coding: utf-8 -*-
require 'sinatra/base'
require 'erb'
require 'pony'

require_relative 'lib/citation-depositor/labs'
require_relative 'lib/citation-depositor/auth'

class App
  use CitationDepositor::LabsBase
  use CitationDepositor::SimpleSessionAuth

  set :licence_addr, 'citationlicence@crossref.org'

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
    
    def activate_licence!
      member = auth_doc[:user]

      Pony.mail(:to => settings.licence_addr,
                :from => 'labs@crossref.org',
                :subject => "Member #{member} has accepted the citation deposit licence.",
                :body => "Member #{member} has acepted the citation deposut licence.")

      member_doc = {
        :licence_activated => true,
        :licence_accepted => true,
      }
      
      members = Config.collection('members')
      members.update({:user => member}, member_doc)
    end

    def accept_licence!
      member_doc = {
        :licence_accepted => true,
        :licence_activated => false
      }

      members = Config.collection('members')
      members.update({:user => auth_doc[:user]}, member_doc)
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
      accept_licence!
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
    members = Config.collection('members')
    members.update({:user => auth_doc[:user]}, {:licence_activated => true})
  end

  get '/depositor/download', :auth => true do
  end

  # Some API

  api :get, '/jobs/:id' do
  end

end



