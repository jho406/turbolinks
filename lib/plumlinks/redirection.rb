module Plumlinks
  module Redirection
    def redirect_to(url = {}, response_status = {})
      plumlinks = response_status.delete(:plumlinks)
      plumlinks = (request.xhr? && !request.get?) if plumlinks.nil?

      if plumlinks
        response.content_type = Mime[:js]
      end

      return_value = super(url, response_status)

      if plumlinks
        self.status = 200
        self.response_body = "Plumlinks.visit('#{location}');"
      end

      return_value
    end

    def render(*args, &block)
      render_options = args.extract_options!
      plumlinks = render_options.delete(:plumlinks)
      plumlinks = {} if plumlinks == true

      if plumlinks
        render_options[:locals] ||= {}
        render_options[:locals][:plumlinks] = plumlinks
      end

      if plumlinks && request.format == :html
         original_formats = self.formats

         @plumlinks = render_to_string(*args, render_options.merge(formats: [:js]))
         self.formats = original_formats
         render_options.reverse_merge!(formats: original_formats, template: 'plumlinks/response')
      end

      super(*args, render_options, &block)

      if plumlinks && (request.xhr? && !request.get?) && request.format == :js
        @plumlinks = self.response_body[0]
        self.response_body = [plumlinks_snippet]
      end

      self.response_body
    end
  end
end
