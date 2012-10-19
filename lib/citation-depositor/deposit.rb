require 'faraday'

require_relative 'recorded_job'

module CitationDepositor

  class Deposit < RecordedJob
    @queue = :deposit
    @kind = :deposits

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
        @@doi_service ||= Faraday.new(:url => 'http://doi.crosref.org')
        @@doi_service.get do |req|
          req.url '/servlet/deposit'
          req.params[:operation] = 'doDOICitUpload'
          req.params[:area] = 'live'
          req.params[:login_id] = @user
          req.params[:login_passwd] = @passwd
          req.body = to_deposit_xml
        end

        mark_finished
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
              
            }
          }
        }
      end

      builder.to_s
    end
  end

end

