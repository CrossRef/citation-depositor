module CitationDepositor
  module Coins

    def parse_coins s
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

  end
end
        
