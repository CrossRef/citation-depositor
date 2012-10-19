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
        refs = PdfExtract.parse(filename) { |pdf| pdf.references }
        mark_finished(refs)
      rescue StandardError => e
        mark_failed(e)
      end      
    end
  end

end
