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
      VIRT_HELPERS = ['alive?', 'stats']

      def json o, status = 200
        [status, {'Content-Type' => 'application/json'}, o.to_json]
      end

      VIRT_HELPERS.each do |name|
        define_method name.to_sym do
          raise StandardError.new("Must override helper #{name}")
        end
      end
    end

    def self.registered app
      app.helpers LabsBase::Helpers
      
      app.get '/heartbeat' do
        if alive?
          json({:status => 'ok'}.merge(stats))
        else
          json({:status => 'bad'}.merge(stats), 400)
        end
      end
      
      app.get '/doc' do
        erb :documentation, :locals => {:routes => @api_routes}
      end
    end
  end
end
  
