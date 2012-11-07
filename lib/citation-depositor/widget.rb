# -*- coding: utf-8 -*-
module CitationDepositor
  module Widget

    def self.registered app
      app.get '/widget/noid' do
        erb :widget_no_id
      end

      app.get '/widget' do
        puts params[:doi]
        doi = params[:doi]
        citations_record = Config.collection('citations').find_one({:doi => doi})
        citations = []
        
        unless citations_record.nil?
          citations = citations_record['citations'].map do |c| 
            hsh = {:text => c['text']}
            hsh[:doi] = c['doi'] if c.has_key?('doi')
            hsh
          end
        end
         
        content = erb :widget_with_id, :locals => {:citations => citations}
        escaped_content = content.gsub('"', '\"').gsub("\n", ' ')
        
        "__depositor_callback(\"#{escaped_content}\");"
      end
    end

  end
end
