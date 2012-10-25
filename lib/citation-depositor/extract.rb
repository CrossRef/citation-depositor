require 'pdfextract'

require_relative 'recorded_job'

module CitationDepositor

  class Extract < RecordedJob
    @queue = :extract
    @kind = :extractions

    def self.perform filename
      Extract.new(filename).perform
    end

    def initialize filename
      @filename = filename
    end

    def perform filename
      mark_started({:filename => filename})

      begin
        result = PdfExtract.parse(filename) do |pdf| 
          pdf.references
          pdf.dois
        end
        mark_finished(:citations => result[:references], 
                      :doi => result[:dois].first)
      rescue StandardError => e
        mark_failed(e)
      end      
    end
  end

end
