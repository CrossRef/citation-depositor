require 'json'
require 'securerandom'

require_relative 'config'

module CitationDepositor
  module SimpleSessionAuth

    module Helpers
      def has_authed?
        !auth_info.nil?
      end

      def auth_info
        request.env[:session]
      end
    end

    def self.registered app
      app.helpers SimpleSessionAuth::Helpers

      app.set :auth_ok_redirect, '/'
      app.set :auth_failed_redirect, '/'
      app.set :auth_logout_redirect, '/'
      
      app.set(:auth) do |val| 
        condition do 
          if has_authed?
            true
          else
            redirect(settings.auth_failed_redirect)
            false
          end
        end
      end

      app.before do
        sessions = Config.collection 'sessions'
        token = request.cookies['token']
        request.env[:session] = sessions.find_one({:token => token})
      end

      app.post '/auth/login' do
        if settings.authorize(params[:user], params[:pass])
          token = SecureRandom.uuid
          sessions = Config.collection 'sessions'
          sessions.update({:user => params[:user]},
                          {:user => params[:user], :pass => params[:pass], :token => token},
                          {:upsert => true})
          response.set_cookie('token', {:value => token, :path => '/'})

          redirect(params[:to] || settings.auth_redirect)
        else
          redirect(settings.auth_failed_redirect)
        end
      end

      app.get '/auth/logout' do
        response.delete_cookie('token')
        redirect(params[:to] || settings.auth_logout_redirect)
      end

      app.get '/auth/me' do
        auth_info.to_json
      end
    end
  end
end

