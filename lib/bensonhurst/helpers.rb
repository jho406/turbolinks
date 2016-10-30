module Bensonhurst
  module Helpers
    def bensonhurst_tag
      if defined?(@bensonhurst) && @bensonhurst
        "<script type='text/javascript'>Bensonhurst.replace(#{@bensonhurst});</script>".html_safe
      end
    end

    def bensonhurst_snippet
      if defined?(@bensonhurst) && @bensonhurst
        "Bensonhurst.replace(#{@bensonhurst});".html_safe
      end
    end

    def use_bensonhurst_html
      @_use_bensonhurst_html = true
    end

    def bensonhurst_silient?
      !!request.headers["X-SILENT"]
    end
  end
end
