# -*- coding: utf-8 -*-
require 'faraday'
require 'stringio'

require_relative 'recorded_job'
require_relative 'config'

module CitationDepositor

  class Deposit < RecordedJob
    @queue = :deposit

    def job_kind
      :deposits
    end

    def initialize name, user, passwd, doi, citations
      @name = name
      @user = user
      @passwd = passwd
      @doi = doi
      @citations = citations
    end

    def self.perform name, user, passwd, doi, citations
      Deposit.new(name, user, passwd, doi, citations).perform
    end

    def perform
      mark_started({:citations => @citations, :name => @name, :doi => @doi})
      mark_pdf_status(@name, :depositing)

      begin
        # Store a local copy of final deposited citations.
        citations_coll = Config.collection('citations')
        citations_coll.update({:doi => @doi},
                              {:doi => @doi, :citations => @citations},
                              {:upsert => true})

        @@doi_service ||= Faraday.new(:url => 'http://doi.crossref.org') do |conn|
          conn.request :multipart
          conn.request :url_encoded
          conn.adapter :net_http
        end

        params = {
          :operation => 'doDOICitUpload',
          :login_id => @user,
          :login_passwd => @passwd,
          :area => 'live'
        }

        puts to_deposit_xml

        query = params.map {|k, v| "#{k}=#{URI.escape(v)}"}.join('&')
        url = "/servlet/deposit?#{query}"
        file = Faraday::UploadIO.new(StringIO.new(to_deposit_xml), 'application/xml')

        res = @@doi_service.post url, {:fname => file}

        puts res.status
        puts res.body

        if res.status == 200
          mark_finished
          mark_pdf_status(@name, :deposited)
        else
          # TODO Determine the type of error
          # Must distinguish between "can't deposit for that DOI",
          # service not available, and anything else.
          error_type = :no_ownership # :no_service :other
          mark_failed({:type => error_type, :http_status => res.status})
          mark_pdf_status(@name, :deposit_failed)
        end
      rescue StandardError => e
        mark_failed(e)
        mark_pdf_status(@name, :deposit_failed)
      end
    end

    def to_deposit_xml
      ns = {
        :xmlns => 'http://www.crossref.org/doi_resources_schema/4.3.0',
        :'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
        :version => '4.3.0',
        :'xsi:schemaLocation' => 'http://www.crossref.org/doi_resources_schema/4.3.0 http://www.crossref.org/schema/deposit/doi_resources4.3.0.xsd'
      }

      builder = Nokogiri::XML::Builder.new do |xml|
        xml.doi_batch(ns) {
          xml.head {
            xml.doi_batch_id(@name)
            xml.depositor {
              xml.name('CrossRef Citation Depositor')
              xml.email_address('kward@crossref.org')
            }
          }
          xml.body {
            xml.doi_citations {
              xml.doi(@doi)
              xml.citation_list {
                @citations.each_index do |i|
                  citation = @citations[i]
                  xml.citation(:key => "#{@name}-#{i}") {
                    xml.unstructured_citation(citation['text'])
                    xml.doi(citation['doi']) if citation.has_key?('doi')
                  }
                end
              }
            }
          }
        }
      end

      builder.to_xml
    end
  end

end

