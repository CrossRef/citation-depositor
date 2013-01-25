# -*- coding: utf-8 -*-
require 'pdf-extract'
require 'json'
require 'faraday'

require_relative 'recorded_job'
require_relative 'config'
require_relative 'resolve'

module CitationDepositor

  class Extract < RecordedJob
    @queue = :extract

    def job_kind
      :extractions
    end

    def self.perform url, filename, name
      Extract.new(url, filename, name).perform
    end

    def initialize url, filename, name
      @url = url
      @filename = filename
      @name = name
    end

    def resolve citations
      @@search_service ||= Faraday.new(:url => 'http://search.labs.crossref.org')
      res = @@search_service.post do |req|
        req.url '/links'
        req.headers['Content-Type'] = 'application/json'
        req.body = citations.to_json
      end

      if res.status == 200
        json = JSON.parse(res.body)
        if json['query_ok']
          json['results']
        end
      end
    end

    def perform
      mark_started({:url => @url, :filename => @filename, :name => @name})

      begin
        conn = Faraday.new
        response = conn.get @url
        File.open(@filename, 'wb') do |file|
          file.write(response.body)
        end

        result = PdfExtract.parse(@filename) do |pdf|
          pdf.references
          #pdf.dois
        end

        unresolved_citations = result.spatial_objects[:references].map {|r| r[:content]}
        citations = resolve(unresolved_citations)

        #mark_finished(:citations => citations,
        #              :doi => result[:dois].first)
        # TODO Find doi once doi spatial implemented in
        # pdf-extract.
        mark_finished(:citations => citations)
      rescue StandardError => e
        mark_failed(e)
      end
    end
  end

end
