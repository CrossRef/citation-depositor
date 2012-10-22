require 'sinatra/base'
require 'json'
require 'securerandom'

module CitationDepositor
  class SimpleSessionAuth < Sinatra::Base
    set :sessions, true
    set :auth_redirect, '/'

    set :auth do
      condition do
        has_authdoc?
      end
    end

    before do
      sessions = Config.collection 'sessions'
      request.env[:authdoc] = sessions.find_one({:token => session[:token]})
    end

    helpers do
      def has_authdoc?
        !request.env[:authdoc].nil?
      end

      def authdoc
        request.env[:authdoc]
      end

      def authorized? user, pass
        raise StandardError.new('Please override authorize helper')
      end
    end

    post '/auth/login' do
      if authorized?(params[:user], params[:pass])
        token = SecureRandom.uuid
        sessions = Config.collection 'sessions'
        sessions.insert({:user => params[:user], :pass => params[:pass], :token => token})
        session[:token] = token
      end

      redirect(params[:to] || settings.auth_redirect)
    end

    post '/auth/logout' do
      session[:token] = nil
      redirect(params[:to] || settings.auth_redirect)
    end

    get '/auth/me' do
      request.env[:session].to_json
    end
  end
end

