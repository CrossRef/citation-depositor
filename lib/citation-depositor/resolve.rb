require_relative 'recorded_job'

module CitationDepositor

  class Resolve < RecordedJob
    def initialize citations
      @citations = citations
    end

    def self.perform citations
      new(citations).perform
    end

    def perform
      @@search_service ||= Faraday.new(:url => 'http://search.labs.crossref.org')
      res = @@search_service.post do |req|
        req.url '/link'
        req.body = to_search_json
      end

      if res.code == 200
        json = JSON.parse(res.body)
        if json[:query_ok]
          res[:citations]
        end
      end
    end

    def to_search_json
      @citations.to_json
    end
  end

end

