module Bensonhurst
  module Render
    def render(*args, &block)
      render_options = args.extract_options!
      bensonhurst = render_options.delete(:bensonhurst)
      bensonhurst = {} if bensonhurst == true || @_use_bensonhurst_html

      if bensonhurst
        view_parts = _prefixes.reverse.push(action_name)[1..-1]
        view_name = view_parts.map(&:camelize).join

        bensonhurst[:view] ||= view_name
        render_options[:locals] ||= {}
        render_options[:locals][:bensonhurst] = bensonhurst
      end

      if @_use_bensonhurst_html && request.format == :html
         original_formats = self.formats

         @bensonhurst = render_to_string(*args, render_options.merge(formats: [:js]))
         self.formats = original_formats
         render_options.reverse_merge!(formats: original_formats, template: 'bensonhurst/response')
      end

      super(*args, render_options, &block)
    end
  end
end
