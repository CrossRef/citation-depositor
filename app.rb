# -*- coding: utf-8 -*-
require 'sinatra/base'
require 'erb'

require_relative 'lib/citation-depositor/labs'
require_relative 'lib/citation-depositor/auth'
require_relative 'lib/citation-depositor/licence'
require_relative 'lib/citation-depositor/depositor'

class App < Sinatra::Base
  register CitationDepositor::LabsBase
  register CitationDepositor::SimpleSessionAuth
  register CitationDepositor::Licence
  register CitationDepositor::Depositor

  set(:alive) { true }
  set(:stats) { {} }
  set(:authorized) { |user, pass| true }

  get '/' do
    erb :index
  end
end

