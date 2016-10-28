# This was taken from jbuilder

dependency_tracker = false

begin
  require 'action_view'
  require 'action_view/dependency_tracker'
  dependency_tracker = ::ActionView::DependencyTracker
rescue LoadError
  begin
    require 'cache_digests'
    dependency_tracker = ::CacheDigests::DependencyTracker
  rescue LoadError
  end
end

if dependency_tracker
  class Bensonhurst::BathTemplate
    module DependencyTrackerMethods
      # Matches:
      #   json.partial! partial: "comments/comment"
      #   json.comments @post.comments, partial: "comments/comment", as: :comment
      #   json.array! @posts, partial: "posts/post", as: :post
      #   = render partial: "account"
      #
      INDIRECT_RENDERS = /
        (?::partial\s*=>|partial:)  # partial: or :partial =>
        \s*                         # optional whitespace
        (['"])([^'"]+)\1            # quoted value
      /x

      def dependencies
        indirect_dependencies + explicit_dependencies
      end

      private

      def indirect_dependencies
        source.scan(INDIRECT_RENDERS).map(&:second)
      end
    end
  end

  ::Bensonhurst::DependencyTracker = Class.new(dependency_tracker::ERBTracker)
  ::Bensonhurst::DependencyTracker.send :include, ::Bensonhurst::BathTemplate::DependencyTrackerMethods
  dependency_tracker.register_tracker :plum, ::Bensonhurst::DependencyTracker
end
