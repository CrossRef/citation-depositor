# -*- coding: utf-8 -*-
require_relative 'config'
require_relative 'activate'

# TODO requires SimpleSessionAuth to be reigstered first.

module CitationDepositor
  module Licence

    module Helpers
      def licence_info
        request.env[:licence]
      end

      def is_licenced?
        !licence_info.nil? && licence_info['active']
      end

      def activate_licence!
        user = auth_info['user']
        Resque.enqueue(CitationDepositor::ActivateLicence, user)
        licences = Config.collection('licences')
        licences.update({:user => user},
                        {:user => user, :active => true, :activated_at => Time.now},
                        {:upsert => true})
      end
    end

    def self.registered app
      app.helpers Licence::Helpers

      app.set :licence_fail_redirect, '/licence'
      app.set :licence_ok_redirect, '/deposit'

      app.set(:licence) do |val|
        condition do
          if is_licenced?
            true
          else
            redirect(settings.licence_fail_redirect)
            false
          end
        end
      end

      app.before do
        unless auth_info.nil?
          licences = Config.collection('licences')
          request.env[:licence] = licences.find_one({:user => auth_info['user']})
        end
      end

      app.get '/licence', :auth => true do
        if licence_info && licence_info['active']
          redirect(settings.licence_ok_redirect)
        elsif params.has_key?('accept') && params['accept'] == 'true'
          activate_licence!
          redirect(settings.licence_ok_redirect)
        else
          erb :licence
        end
      end
    end

  end
end
