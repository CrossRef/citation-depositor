require 'pony'

module CitationDepositor
  class ActivateLicence
    @queue = :licence

    def self.perform user
      Pony.mail(:to => 'depositlicence@crossref.org',
                :from => 'labs@crossref.org',
                :subject => "Account #{user} has accepted the citation deposit licence.",
                :body => "Account #{user} has acepted the citation deposit licence.")
    end
  end
end
