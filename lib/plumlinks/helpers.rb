module Bensonhurst
  module Helpers
    def plumlinks_tag
      if defined?(@plumlinks) && @plumlinks
        "<script type='text/javascript'>Bensonhurst.replace(#{@plumlinks});</script>".html_safe
      end
    end

    def plumlinks_snippet
      if defined?(@plumlinks) && @plumlinks
        "Bensonhurst.replace(#{@plumlinks});".html_safe
      end
    end

    def use_plumlinks_html
      @_use_plumlinks_html = true
    end

    def plumlinks_silient?
      !!controller.request.headers["X-SILENT"]
    end
  end
end
