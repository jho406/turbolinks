module Plumlinks
  module Helpers
    def plumlinks_tag
      if defined?(@plumlinks) && @plumlinks
        "<script type='text/javascript'>Plumlinks.replace(#{@plumlinks});</script>".html_safe
      end
    end

    def plumlinks_snippet
      if defined?(@plumlinks) && @plumlinks
        "Plumlinks.replace(#{@plumlinks});".html_safe
      end
    end

    def use_plumlinks_html
      @_use_plumlinks_html = true
    end
  end
end
