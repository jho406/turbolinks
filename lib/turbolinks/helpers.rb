module Turbolinks
  module Helpers
    def turbolinks_tag
      if defined?(@turbolinks) && @turbolinks
        "<script type='text/javascript'>Turbolinks.replace(#{@turbolinks});</script>".html_safe
      end
    end
  end
end
