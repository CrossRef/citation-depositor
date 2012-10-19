require_relative 'config'

module CitationDepositor

  class RecordedJob
    
    def mark_started info = {}
      status_doc = {
        :status => :started,
        :started_at => Time.now,
      }

      status_doc.merge!(info)
      status_doc[:_id] = @status_id unless @status_id.nil?
      collection = Config.collection(@kind)
      @status_id = collection.save(status_doc)
    end

    def mark_finished info = {}
      update = {
        '$set' => {
          :status => :finished,
          :finished_at => Time.now
        }
      }

      info.each_pair do |k, v|
        update['$set'][k] = v
      end

      collection = Config.collection(@kind)
      collection.find_and_modify({:query => {:_id => @status_id}, :update => update})
    end

    def mark_failed error
      update = {
        '$set' => {
          :status => :failed,
          :failed_at => Time.now,
          :error => error.to_s
        }
      }

      collection = Config.collection(@kind)
      collection.find_and_modify({:query => {:_id => @status_id}, :update => update})
    end
  end

end
      
