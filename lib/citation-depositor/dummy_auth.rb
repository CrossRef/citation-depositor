require 'faraday'
require 'uri'

module CitationDepositor
  module DummyAuth

    def self.doi_service
      @@doi_service ||= Faraday.new(:url => 'http://doi.crossref.org') do |conn|
        conn.request :multipart
        conn.request :url_encoded
        conn.adapter :net_http
      end
    end

    def self.can_auth? user, pass
      params = {
        :operation => 'doMDUpload',
        :login_id => user,
        :login_passwd => pass,
        :area => 'live'
      }

      query = params.map {|k, v| "#{k}=#{URI.escape(v)}"}.join('&')
      url = "/servlet/deposit?#{query}"
      file = Faraday::UploadIO.new('dummy.xml', 'application/xml')
      res = doi_service.post url, {:fname => file}

      res.status == 200
    end

  end
end
