module Plumlinks
  module Render
    def redirect_to(args)
      if request.headers["X-SILENT"]
        head :ok
      else
        super
      end
    end

    def render(*args, &block)
      render_options = args.extract_options!
      plumlinks = render_options.delete(:plumlinks)
      plumlinks = {} if plumlinks == true || @_use_plumlinks_html

      if plumlinks
        view_parts = _prefixes.reverse.push(action_name)[1..-1]
        view_name = view_parts.map(&:camelize).join

        plumlinks[:view] ||= view_name
        render_options[:locals] ||= {}
        render_options[:locals][:plumlinks] = plumlinks
      end

      if @_use_plumlinks_html && request.format == :html
         original_formats = self.formats

         @plumlinks = render_to_string(*args, render_options.merge(formats: [:js]))
         self.formats = original_formats
         render_options.reverse_merge!(formats: original_formats, template: 'plumlinks/response')
      end

      super(*args, render_options, &block)
    end
  end
end
