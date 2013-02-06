# -*- coding: utf-8 -*-
require 'nokogiri'

module CitationDepositor
  module Help

    def self.registered app
      app.get '/help/widget' do
        erb :widget_help
      end

      app.get '/help/check' do
        page_url = params[:url]
        page_url = "http://#{page_url}" if !(params[:url] =~ /\Ahttps?:\/\//)

        html = Nokogiri::HTML(open(page_url))
        result = {}

        # We're going to check the page for a DOI meta tag, then check for a script
        # tag with the correct src. Finally, if we find a meta tag, we'll check
        # the DOI for citations.

        metas = html.css('meta')
        dci_metas = metas.reject do |meta|
          meta['name'].nil? || meta['name'].downcase != 'dc.identifier'
        end

        doi = dci_metas.map {|meta| meta['content'].sub('info:doi/', '').sub('doi:', '')}.first

        scripts = html.css('script')
        widgets = scripts.reject do |script|
          script['src'].nil? || script['src'] != 'http://depositor.labs.crossref.org/js/widget.js'
        end

        divs = html.css('div')
        contents = divs.reject {|div| div['id'].nil? || div['id'] != '__depositor'}

        result[:has_citations] = !fetch_citations(doi).empty? unless doi.nil?
        result[:has_citations] = false if doi.nil?
        result[:has_content] = !contents.empty?
        result[:has_widget] = !widgets.empty?
        result[:has_meta] = !doi.nil?
        result[:doi] = doi

        json(result)
      end

      app.get '/help' do
        erb :help
      end
    end

  end
end
