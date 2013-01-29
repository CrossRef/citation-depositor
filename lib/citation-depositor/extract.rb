# -*- coding: utf-8 -*-
require 'pdf-extract'
require 'json'
require 'faraday'
require 'nokogiri'

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

    def resolve_citations citations
      @@search_service ||= Faraday.new(:url => 'http://search.labs.crossref.org')
      res = @@search_service.post do |req|
        req.url('/links')
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

    def parse_citations
      @@pdfx_service ||= Faraday.new(:url => 'http://pdfx.cs.man.ac.uk')
      res = @@pdfx_service.post do |req|
        req.url('/')
        req.headers['Content-Type'] = 'application/pdf'
        File.open(@filename, 'rb') {|file| req.body = file.read}
      end

      if res.status == 200
        puts res.body
        doc = Nokogiri::XML(res.body)
        doc.css('ref').map {|ref_loc| ref_loc.text}
      end
    end

    def perform
      mark_started({:url => @url, :filename => @filename, :name => @name})
      mark_pdf_status(@name, :extracting)

      begin
        conn = Faraday.new
        response = conn.get @url
        File.open(@filename, 'wb') do |file|
          file.write(response.body)
        end

        citations = resolve_citations(parse_citations)

        #mark_finished(:citations => citations,
        #              :doi => result[:dois].first)
        # TODO Find doi once doi spatial implemented in
        # pdf-extract.
        mark_finished(:citations => citations)
        mark_pdf_status(@name, :extracted)
      rescue StandardError => e
        mark_failed(e)
        mark_pdf_status(@name, :extract_failed)
      end
    end
  end

end
