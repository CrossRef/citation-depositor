# -*- coding: utf-8 -*-
require 'sinatra/base'
require 'json'

# LabsBase provides a heartbeat route and a self-documenting API construction 
# helper.

module CitationDepositor
  class LabsBase < Sinatra::Base 
    @api_routes = {}

    def api type, version, path, &block
      @api_routes[version] ||= []
      @api_routes[version] << {
        :type => type,
        :path => path
      }

      send(type.to_sym, File.join('/api', "v#{version}", path), &block)
    end

    helpers do
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
      
    get '/heartbeat' do
      if alive?
        json({:status => 'ok'}.merge(stats))
      else
        json({:status => 'bad'}.merge(stats), 400)
      end
    end

    get '/doc' do
      erb :documentation, :locals => {:routes => @api_routes}
    end
  end
end
  
