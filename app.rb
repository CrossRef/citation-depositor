# -*- coding: utf-8 -*-
require 'sinatra/base'
require 'erb'
require 'time'

require_relative 'lib/citation-depositor/labs'
require_relative 'lib/citation-depositor/auth'
require_relative 'lib/citation-depositor/licence'
require_relative 'lib/citation-depositor/depositor'
require_relative 'lib/citation-depositor/widget'

require_relative 'lib/citation-depositor/dummy_auth'

class App < Sinatra::Base
  register CitationDepositor::LabsBase
  register CitationDepositor::SimpleSessionAuth
  register CitationDepositor::Licence
  register CitationDepositor::Depositor
  register CitationDepositor::Widget

  set(:alive) { true }
  set(:stats) { {} }
  set(:authorize) { |user, pass| CitationDepositor::DummyAuth.can_auth?(user, pass) }

  get '/' do
    if has_authed?
      redirect '/activity'
    else
      erb :index
    end
  end
end

