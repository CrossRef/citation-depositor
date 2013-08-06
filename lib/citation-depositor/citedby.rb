module CitationDepositor
  module CitedBy

    def parse_citedby_citations doc
      doc.css('body forward_link journal_cite').map do |citation_loc|
        authors = citation_loc.css("contributor[contributor_role='author']").map do |a_loc|
          {:given => a_loc.at_css('given_name'), :family => a_loc.at_css('surname')}
        end

        {
          :issn => citation_loc.at_css('issn').text,
          :'container-title' => citation_loc.at_css('journal_title').text,
          :title => citation_loc.at_css('article_title').text,
          :volume => citation_loc.at_css('volume').text,
          :issue => citation_loc.at_css('issue').text,
          :page => citation_loc.at_css('first_page').text,
          :issued => {:'date-parts' => [[citation_loc.at_css('year')]]},
          :DOI => citation_loc.at_css('doi').text,
          :author => authors
        }
      end
    end

  end
end
      
