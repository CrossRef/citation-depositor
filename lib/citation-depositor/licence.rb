# -*- coding: utf-8 -*-
require 'pony'

require_relative 'config'

# TODO requires SimpleSessionAuth to be reigstered first.

module CitationDepositor
  module Licence

    module Helpers
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
    end

    def self.registered app
      app.helpers Licence::Helpers

      set :licence_addr_to, 'citationlicence@crossref.org'
      set :licence_addr_from, 'labs@crossref.org'
      set :licence_fail_redirect, '/licence'
      set :licence_ok_redirect, '/deposit'

      app.set(:licence) { |val| condition { is_licenced? } }

      app.before do
        unless auth_info.nil?
          licences = Config.collection('licences')
          request.env[:licence] = licences.find_one({:user => auth_info[:user]})
        end
      end

      app.get '/licence', :auth => true do
        if licence_info && licence_info[:active]
          redirect(settings.licence_ok_redirect)
        elsif params.has_key?(:accept)
          activate_licence!
          redirect(settings.licence_ok_redirect)
        else
          erb :licence
        end
      end
    end

  end
end
