require 'faraday'
require 'stringio'

require_relative 'recorded_job'

module CitationDepositor

  class Deposit < RecordedJob
    @queue = :deposit

    def job_kind
      :deposits
    end

    def initialize user, passwd, doi, citations
      @user = user
      @passwd = passwd
      @doi = doi
      @citations = citations
    end

    def self.perform citations
      Deposit.new(citations).perform
    end

    def perform
      mark_started({:citations => @citations, :user => @user, :doi => @doi})

      begin
        @@doi_service ||= Faraday.new(:url => 'http://doi.crosref.org') do |conn|
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

        query = params.map {|k, v| "#{k}=#{URI.escape(v)}"}.join('&')
        url = "/servlet/deposit?#{query}"
        file = Faraday::UploadIO.new(StringIO.new(to_deposit_xml), 'application/xml')

        res = @@doi_service.post url, {:fname => file}

        if res.status == 200
          mark_finished
        else
          mark_failed(res.status)
        end
      rescue StandardError => e
        mark_failed(e)
      end
    end 

    def to_deposit_xml
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.doi_batch {
          xml.head {
            xml.doi_batch_id @status_id
            xml.depositor 'CrossRef Citation Depositor'
          }
          xml.body {
            xml.doi_citations {
              xml.doi @doi
            }
            xml.citation_list {
              @citations.each do |citation|
                xml.unstructured_citation citation[:text]
                xml.DOI(citation[:doi]) if citation.has_key?(:doi)
              end
            }
          }
        }
      end

      builder.to_s
    end
  end

end

