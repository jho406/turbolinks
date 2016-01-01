module Turbolinks
  module Redirection

    def turbolinks
      @turbolinks ||= {}
    end

    def turbolinks_js_tag
      if @turbolinks_js
        "<script type='text/javascript'>#{@turbolinks_js}</script>".html_safe
      end
    end

    def redirect_to(url = {}, response_status = {})
      turbolinks = response_status.delete(:turbolinks)
      turbolinks = (request.xhr? && !request.get?) if turbolinks.nil?

      if turbolinks
        response.content_type = Mime[:js]
      end

      return_value = super(url, response_status)

      if turbolinks
        self.status = 200
        self.response_body = "Turbolinks.visit('#{location}');"
      end

      return_value
    end

    def render(*args, &block)
      render_options = args.extract_options!
      opts = render_options.delete(:turbolinks)
      opts = {} if opts == true

      if opts
       self.turbolinks.reverse_merge!(opts)

       if request.format == :html
         original_formats = self.formats
         @turbolinks_js = render_to_string(*args, render_options.merge(formats: [:js]))
         self.formats = original_formats
         render_options.reverse_merge!(formats: original_formats, template: 'turbolinks/response')
       end
      end

      super(*args, render_options, &block)
      self.response_body
    end
  end
end
