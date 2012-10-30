require 'pdf-extract'

require_relative 'recorded_job'
require_relative 'config'

module CitationDepositor

  class Extract < RecordedJob
    @queue = :extract
    @kind = :extractions

    def self.perform filename, name
      Extract.new(filename).perform
    end

    def initialize filename, name
      @filename = filename
      @name = name
    end

    def perform filename, name
      mark_started({:filename => filename, :name => name})

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
