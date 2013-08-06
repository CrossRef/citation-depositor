# -*- coding: utf-8 -*-
require 'json'
require 'faraday'
require 'nokogiri'

require_relative 'recorded_job'
require_relative 'config'
require_relative 'resolve'
require_relative 'coins'

module CitationDepositor

  class Extract < RecordedJob
    include Coins

    @queue = :extract

    def job_kind
      :extractions
    end

    def self.perform url, pdf_filename, xml_filename, name
      Extract.new(url, pdf_filename, xml_filename, name).perform
    end

    def initialize url, pdf_filename, xml_filename, name
      @url = url
      @pdf_filename = pdf_filename
      @xml_filename = xml_filename
      @name = name
    end

    def resolve_citations citations
      @@search_service ||= Faraday.new(:url => 'http://search.crossref.org')
      res = @@search_service.post do |req|
        req.options[:timeout] = 600
        req.options[:open_timeout] = 600
        req.url('/links')
        req.headers['Content-Type'] = 'application/json'
        req.body = citations.to_json
      end

      if res.status == 200
        json = JSON.parse(res.body)
        if json['query_ok']
          json['results'].each do |result|
            if result['match']
              result['coins'] = unpack_coins(result['coins'])
            end
          end
          json['results']
        end
      end
    end

    def parse_citations
      @@pdfx_service ||= Faraday.new(:url => 'http://pdfx.cs.man.ac.uk')
      res = @@pdfx_service.post do |req|
        req.options[:timeout] = 600
        req.options[:open_timeout] = 600
        req.url('/')
        req.headers['Content-Type'] = 'application/pdf'
        File.open(@pdf_filename, 'rb') {|file| req.body = file.read}
      end

      if res.status == 200
        File.open(@xml_filename, 'w') {|file| file.write(res.body)}
        doc = Nokogiri::XML(res.body)
        doc.css('ref').map {|ref_loc| ref_loc.text.sub(/\A\d+\.\s*/, '').sub(/\A\[\w+\]\s*/, '')}
      end
    end

    def perform
      mark_started({:url => @url, :filename => @pdf_filename, :xml_filename => @xml_filename, :name => @name})
      mark_pdf_status(@name, :extracting)

      begin
        conn = Faraday.new
        response = conn.get do |req|
          req.url(@url)
          req.options[:timeout] = 600
          req.options[:open_timeout] = 600
        end
        File.open(@pdf_filename, 'wb') do |file|
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
