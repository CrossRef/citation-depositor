require 'pony'
require 'erb'

module CitationDepositor
  class ActivateLicence
    @queue = :licence

    def self.perform user
      template = ERB.new(File.open('../../views/licence_email.erb').read)

      to = 'Susan'
      from = 'D.A.V.E.'

      Pony.mail(:to => 'scollins@crossref.org',
                :from => 'labs@crossref.org',
                :subject => "#{user} has accepted the citation deposit licence",
                :body => template.result)
    end
  end
end
