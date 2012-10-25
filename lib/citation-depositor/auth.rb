require 'json'
require 'securerandom'

require_relative 'config'

module CitationDepositor
  module SimpleSessionAuth

    module Helpers
      def has_authed?
        !request.env[:session].nil?
      end

      def auth_info
        request.env[:session]
      end

      def authorize? user, pass
        raise StandardError.new('Please override authorize helper')
      end
    end

    def self.registered app
      app.helpers SimpleSessionAuth::Helpers

      app.set :sessions, true
      app.set :auth_redirect, '/'
      app.set(:auth) { |val| condition { has_authed? } }

      app.before do
        sessions = Config.collection 'sessions'
        request.env[:session] = sessions.find_one({:token => session[:token]})
      end

      app.post '/auth/login' do
        if authorize?(params[:user], params[:pass])
          token = SecureRandom.uuid
          sessions = Config.collection 'sessions'
          sessions.insert({:user => params[:user], :pass => params[:pass], :token => token})
          session[:token] = token
        end

        redirect(params[:to] || settings.auth_redirect)
      end

      app.post '/auth/logout' do
        session[:token] = nil
        redirect(params[:to] || settings.auth_redirect)
      end

      app.get '/auth/me' do
        request.env[:session].to_json
      end
    end
  end
end

