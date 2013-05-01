module CitationDepositor
  module Coins

    def self.parse_coins s
      s = CGI.unescapeHTML(s)
      m = {}
      kvs = s.split('&')
      kvs.each do |kv|
        k, v = kv.split('=')
        v = CGI.unescape(v)
        if k.start_with?('rft.')
          key = k.sub('rft.', '')
          if key == 'au'
            m[key] ||= []
            m[key] << v
          else
            m[key] = v
          end
        end
      end
      puts m
      m
    end

    def self.unpack_coins results
      results.map do |result|
        puts result['coins']
        result.merge(parse_coins(result['coins']))
      end
    end
  end
end
        
