# -*- coding: utf-8 -*-
require 'json'

# LabsBase provides a heartbeat route and a self-documenting API construction 
# helper.

module CitationDepositor
  module LabsBase 
    @api_routes = {}

    def api type, version, path, &block
      @api_routes[version] ||= []
      @api_routes[version] << {
        :type => type,
        :path => path
      }

      send(type.to_sym, File.join('/api', "v#{version}", path), &block)
    end

    module Helpers
      def json o, status = 200
        [status, {'Content-Type' => 'application/json'}, o.to_json]
      end
    end

    def self.registered app
      app.helpers LabsBase::Helpers

      app.set(:alive) { true }
      app.set(:stats) { {} }
      
      app.get '/heartbeat' do
        if settings.alive
          json({:status => 'ok'}.merge(settings.stats))
        else
          json({:status => 'bad'}.merge(settings.stats), 400)
        end
      end
      
      app.get '/doc' do
        erb :documentation, :locals => {:routes => @api_routes}
      end
    end
  end
end
  
