require 'openssl'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

require 'faraday'
require 'uri'

module CitationDepositor
  module LabsAuth

    LABS_AUTH = Faraday.new(:url => 'https://auth.labs.crossref.org', 
                            :ssl => {:verify => false})

    def self.can_auth? user, pass
      response = LABS_AUTH.get do |request|
        request.url '/login'
        request.headers['CR-USERNAME'] = user
        request.headers['CR-PASSWORD'] = pass
      end

      response.status == 200
    end

  end
end
        
        



       
