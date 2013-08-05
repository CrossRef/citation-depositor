# -*- coding: utf-8 -*-
require 'resque'
require 'securerandom'
require 'rack/multipart/parser'
require 'faraday'
require 'nokogiri'
require 'open-uri'

require_relative 'config'
require_relative 'extract'
require_relative 'deposit'
require_relative 'recorded_job'
require_relative 'coins'
require_relative 'breadcrumb'

module CitationDepositor
  module Depositor

    module Helpers
      include Breadcrumb
      include Coins

      def fetch_method error_result
        begin
          yield
        rescue TimeoutError => e
          error_result
        rescue StandardError => e
          error_result
        end
      end

      def fetch_owner_name owner_prefix
        fetch_method('') do
          resp = settings.cr_service.get("/getPrefixPublisher/?prefix=#{owner_prefix}")

          if resp.status != 200
            ''
          else
            doc = Nokogiri::XML(resp.body)
            doc.at_css('publisher_name').text
          end
        end
      end

      def fetch_owner_prefix doi
        fetch_method('') do
          resp = settings.doi_data_service.get("/#{doi}")

          if resp.status != 200
            ""
          else
            doc = Nokogiri::XML(resp.body)
            doc.at_css('doi_record')['owner']
          end
        end
      end

      def fetch_citations doi
        fetch_method([]) do
          resp = settings.doi_data_service.get("/#{doi}")

          if resp.status != 200
            []
          else
            doc = Nokogiri::XML(resp.body)
            doc.css('citation')
          end
        end
      end

      def resolve_citation citation
        resolved_citation = citation.merge({:match => false, :reason => 'No match attempt'})

        fetch_method(resolved_citation) do
          res = settings.search_service.post do |req|
            req.url('/links')
            req.headers['Content-Type'] = 'application/json'
            req.body = [citation[:text]].to_json
          end

          if res.status == 200
            json = JSON.parse(res.body)
            resolved_citation = json['results'].first if json['query_ok']
          end

          resolved_citation
        end
      end

      def resolve_pdf_metadata pdf_name
        pdfs = Config.collection('pdfs')
        pdf = pdfs.find_one({:name => pdf_name})

        if pdf['metadata'].nil?
          res = settings.csl_service.get('/' + pdf['doi'])
          if res.status == 200
            pdf['metadata'] = JSON.parse(res.body)
            pdfs.save(pdf)
          end
        end
      end
    end

    def self.registered app
      app.helpers Depositor::Helpers

      data_service = Faraday.new('http://data.crossref.org')
      data_service.headers[:accept] = 'application/vnd.crossref.unixref+xml'

      csl_service = Faraday.new('http://data.crossref.org')
      csl_service.headers[:accept] = 'application/vnd.citationstyles.csl+json'

      app.set :pdf_repo_path, File.join(app.settings.root, 'pdfs')
      app.set :xml_repo_path, File.join(app.settings.root, 'xmls')
      app.set :search_service, Faraday.new('http://search.crossref.org')
      app.set :doi_data_service, data_service
      app.set :csl_service, csl_service
      app.set :cr_service, Faraday.new('http://www.crossref.org')

      app.get '/deposit', :auth => true, :licence => true do
        erb :upload
      end

      app.post '/deposit', :auth => true, :licence => true do
        pdf_url = params[:url]
        pdf_upload_filename = params[:filename]
        article_doi = params[:article_doi]
        pdf_name = SecureRandom.uuid
        pdf_filename = File.join(settings.pdf_repo_path, pdf_name)
        xml_filename = File.join(settings.xml_repo_path, pdf_name)
        now = Time.now

        doc = {
          :name => pdf_name,
          :uploaded_at => now,
          :user => auth_info['user'],
          :local_filename => pdf_filename,
          :xml_filename => xml_filename,
          :upload_filename => pdf_upload_filename,
          :status => :uploaded,
          :status_at => now,
          :doi => article_doi
        }

        Config.collection('pdfs').insert(doc)
        resolve_pdf_metadata(doc['name'])
        Resque.enqueue(Extract, pdf_url, pdf_filename, xml_filename, pdf_name)

        json({:pdf_name => pdf_name})
      end

      app.get '/deposit/:name', :auth => true, :licence => true do
        name = params[:name]
        pdfs = Config.collection('pdfs')
        pdf = pdfs.find_one({:name => name})
        extraction_job = RecordedJob.get_where('extractions', {:name => name})
        deposit_job = RecordedJob.get_where('deposits', {:name => name})

        locals = {
          :name => name,
          :deposit => deposit_job,
          :pdf => pdf,
          :extraction => extraction_job
        }

        if extraction_job && extraction_job['doi']
          locals[:extracted_doi] = extraction_job['doi']
        end

        if pdf['doi'] && !pdf['doi'].empty? && doi_info
          locals[:doi] = pdf['doi']
         
          owner_prefix = fetch_owner_prefix(pdf['doi'])
          owner_name = fetch_owner_name(owner_prefix)

          if owner_name.empty?
            json({:status => 'owner_missing'})
          else
            doc = {
              :status => 'ok',
              :owner_name => owner_name,
              :owner_prefix => owner_prefix,
            }
            locals = locals.merge(doc)
          end
        else
          locals[:doi] = ''
          locals[:status] = 'doi_missing'
        end

        erb_with_crumbs :deposit, {
          :locals => locals,
          :crumbs => ['Deposits', '/deposits',
                      pdf['upload_filename'], "#"]
        }
      end

      app.post '/deposit/:name/doi', :auth => true, :licence => true do
        pdfs = Config.collection('pdfs')
        pdf = pdfs.find_one({:name => params[:name]})

        if pdf.nil?
          redirect '/deposit'
        else
          pdf[:doi] = params['article_doi']
          pdfs.save pdf
          resolve_pdf_metadata(pdf['name'])
          redirect("/deposit/#{params[:name]}/doi")
        end
      end

      app.get '/deposit/:name/citations', :auth => true, :licence => true do
        name = params[:name]
        pdfs = Config.collection('pdfs')
        pdf = pdfs.find_one({:name => name})
        extraction_job = RecordedJob.get_where('extractions', {:name => name})
        locals = {}

        if extraction_job
          locals[:citations] = extraction_job['citations']
          locals[:status] = extraction_job['status']
        else
          locals[:citations] = []
          locals[:status] = :no_extraction
        end

        erb_with_crumbs :citations, {
          :locals => locals,
          :crumbs => ['Deposits', '/deposits',
                      pdf['upload_filename'], "/deposit/#{pdf['name']}/doi",
                      'Edit Citations', '#']
        }
      end

      app.post '/deposit/:name/deposit', :auth => true, :licence => true do
        name = params[:name]
        extraction = RecordedJob.get_where('extractions', {:name => name})
        pdf = Config.collection('pdfs').find_one({:name => name})

        unless extraction.nil? || !extraction.has_key?('citations')
          Resque.enqueue(Deposit,
                         name,
                         auth_info['user'],
                         auth_info['pass'],
                         pdf['doi'],
                         extraction['citations'])
        end

        locals = {
          :pdf => pdf,
          :extraction => extraction,
          :deposit => nil
        }

        redirect "/deposit/#{name}"
      end

      app.get '/deposit/:name/citations/:index', :auth => true, :licence => true do
        name = params[:name]
        index = params[:index].to_i
        extraction_job = RecordedJob.get_where('extractions', {:name => name})
        pdf = Config.collection('pdfs').find_one({:name => name})
        locals = {:name => name, :index => index, :pdf => pdf}

        if extraction_job && extraction_job.has_key?('citations')
          locals[:citation] = extraction_job['citations'][index]
        end

        erb_with_crumbs :citation, {
          :locals => locals,
          :crumbs => ['Deposits', '/deposits',
                      pdf['upload_filename'], "/deposit/#{pdf['name']}/doi",
                      'Edit Citations', "/deposit/#{pdf['name']}/citations",
                      "#{(index+1)}", "#"]
        }
      end

      app.post '/deposit/:name/citations/:index', :auth => true, :licence => true do
        name = params[:name]
        index = params[:index].to_i
        extraction_job = RecordedJob.get_where('extractions', {:name => name})

        extraction_job['citations'][index]['text'] = params[:text]
        extraction_job['citations'][index]['modified_at'] = Time.now

        if params.has_key?('doi') && !params[:doi].strip.empty?
          extraction_job['citations'][index]['doi'] = params[:doi]
        end

        Config.collection('extractions').save(extraction_job)

        redirect "/deposit/#{name}/citations"
      end

      app.post '/deposit/:name/citations/:index/insert', :auth => true, :licence => true do
        name = params[:name]
        index = params[:index].to_i
        text = params[:text]
        extraction_job = RecordedJob.get_where('extractions', {:name => name})
        citation = resolve_citation({:text => text, :modified_at => Time.now})

        if index >= extraction_job['citations'].count
          # Append to end
          extraction_job['citations'] << citation
        else
          # Insert before index
          extraction_job['citations'].insert(index, citation)
        end

        Config.collection('extractions').save(extraction_job)

        json({:status => 'ok', :citation => citation})
      end

      app.get '/deposit/:name/citations/:index/remove', :auth => true, :licence => true do
        name = params[:name]
        index = params[:index].to_i
        extraction_job = RecordedJob.get_where('extractions', {:name => name})

        extraction_job['citations'][index]['removed'] = true
        Config.collection('extractions').save(extraction_job)

        json({:status => 'ok'})
      end

      app.get '/deposit/:name/citations/:index/unremove', :auth => true, :licence => true do
        name = params[:name]
        index = params[:index].to_i
        extraction_job = RecordedJob.get_where('extractions', {:name => name})

        extraction_job['citations'][index]['removed'] = false
        Config.collection('extractions').save(extraction_job)

        json({:status => 'ok'})
      end

      app.get '/deposit/:name/status' do
        name = params[:name]
        extraction_job = RecordedJob.get_where('extractions', {:name => name})
        result = {}

        if extraction_job
          result[:status] = extraction_job['status']
        else
          result[:status] = :no_extraction
        end

        json({:status => extraction_job['status']})
      end

      app.get '/deposits', :auth => true, :licence => true do
        opts = {:sort => [[:status_at, -1]]}
        pdfs = Config.collection('pdfs')
        deposited_pdfs = pdfs.find({:user => auth_info['user'], :status => :deposited}, opts)
        undeposited_pdfs = pdfs.find({:user => auth_info['user'], :status => {'$ne' => :deposited}}, opts)

        deposited_pdfs.each do |pdf|
          resolve_pdf_metadata(pdf['name'])
        end

        undeposited_pdfs.each do |pdf|
          resolve_pdf_metadata(pdf['name'])
        end

        deposited_pdfs = pdfs.find({:user => auth_info['user'], :status => :deposited}, opts)
        undeposited_pdfs = pdfs.find({:user => auth_info['user'], :status => {'$ne' => :deposited}}, opts)

        erb_with_crumbs :deposits, {
          :locals => {:deposited => deposited_pdfs, :undeposited => undeposited_pdfs},
          :crumbs => ['Deposits', '#']
        }
      end

      # Shadow doi search with an erb response
      app.get '/dois/search' do
        res = settings.search_service.get('/dois', :q => params[:q])
        status res.status
        results = unpack_coins(JSON.parse(res.body))
        erb :match_results, :locals => {:results => results}, :layout => false
      end
    end

  end
end

