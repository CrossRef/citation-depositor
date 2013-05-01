module CitationDepositor
  module Breadcrumb

    def erb_with_crumbs template, opts
      if opts.has_key?(:crumbs)
        crumbs = opts[:crumbs].each_slice(2).map do |slice| 
          {
            'label' => slice[0],
            'href' => slice[1]
          }
        end
        puts crumbs
        opts[:locals] ||= {}
        opts[:locals][:crumbs] = crumbs
      end
      erb(template, opts)
    end

  end
end
