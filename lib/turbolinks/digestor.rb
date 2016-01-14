require 'action_view'
require 'action_view/digestor'

Turbolinks::KbuilderTemplate.class_eval do
  private

    if ::Rails.version >= '4.1'
      def _partial_digestor(options)
        name = options[:name]
        finder = options[:finder]
        ::ActionView::PartialDigestor.new(name: name, finder: finder).digest
      end
    elsif ::Rails.version >= '4.0'
      def _partial_digestor(options={})
        name = options[:name]
        finder = options[:finder]
        ::ActionView::PartialDigestor.new(name, finder.formats.last, finder).digest
      end
    end
end
