require 'json'
require 'mongo'
require 'resque'

module CitationDepositor

  class Config
    def self.init
      filename = File.join(File.dirname(__FILE__), '..', '..', 'config.json')
      @@json = JSON.parse(File.read(filename))

      @@db = Mongo::Connection.new(@@json['mongo_server'])[@@json['mongo_db']]

      Resque.redis = @@json['redis_server']
    end

    def self.collection name
      @@db[name]
    end

    def self.setting name
      if @@json.has_key?(name)
        @@json[name]
      else
        puts "Attempt to use an undefined config key - #{name}"
        nil
      end
    end

    init
  end

end
