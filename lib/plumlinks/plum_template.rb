require 'jbuilder'
require 'digest/md5'
require 'action_view'
require 'plumlinks/digestor'

module Plumlinks
  class PlumTemplate < ::Jbuilder
    include ::Plumlinks::PartialDigestor

    class << self
      attr_accessor :template_lookup_options
    end

    self.template_lookup_options = { handlers: [:plum] }

    class Digest
      def initialize(digest)
        @digest = "Plumlinks.cache(\"#{digest}\")"
      end

      def to_json(*)
        @digest
      end

      def as_json(*)
        self
      end

      def encode_json(*)
        @digest
      end
    end

    def initialize(context, *args)
      @context = context
      @js = []
      super(*args)
    end

    def empty!
      attributes = @attributes
      @attributes = {}
      attributes
    end

    def set!(key, value = BLANK, *args)
      options = args.first || {}

      if (args.none? && ::Hash === value && (_partial_options?(value) || _cache_options?(value)))
        args.push(value)
        return (
          if ::Kernel.block_given?
            set!(key, BLANK, *args, &::Proc.new)
          else
            set!(key, BLANK, *args)
          end
        )
      end

      return _set_inline_partial key, value, options if args.one? && _partial_options?(options)

      return super if !_cache_options?(options)

      cache_args =_cache_args(args.pop)

      result = if ::Kernel.block_given?
        _ensure_valid_key(key)
        _cache(*cache_args) { _scope { yield self } }
      elsif args.empty?
        if ::Jbuilder === value
          # json.age 32
          # json.person another_jbuilder
          # { "age": 32, "person": { ...  }
          _ensure_valid_key(key)
          _cache(*cache_args) { value.attributes! }
        else
          # json.age 32
          # { "age": 32 }
          _ensure_valid_key(key)
          _cache(*cache_args) { value }
        end
      end

      _set_value key, result
    end

    def child!(options = {})
      return super(&::Proc.new) if !_cache_options?(options)

      @attributes = [] unless ::Array === @attributes
      @attributes << _cache(*_cache_args(options)) {
        _scope { yield self }
      }
    end

    def array!(collection = [], *attributes)
      options = attributes.first || {}

      if attributes.one? && _partial_options?(options)
        _render_partial_with_options(options.merge(collection: collection))
      else
        array = if collection.nil?
          []
        elsif ::Kernel.block_given?
          _map_collection(collection, options, &::Proc.new)
        elsif attributes.any?
          _map_collection(collection, options) { |element| extract! element, *attributes }
        else
          collection.to_a
        end

        merge! array
      end
    end

    def target!
      js = _plumlinks_return(@attributes)
      @js.push(js)
      "(function(){#{@js.join}})()"
    end

    private

      def _map_collection(collection, options)
        return super(collection, &::Proc.new) if !_cache_options?(options)

        key_proc, cache_options = _cache_args(options)

        collection.map do |element|
          key = key_proc.call(element)

          _cache(key, cache_options) {
            _scope { yield element }
          }
        end - [BLANK]
      end

      def _cache_key(key, options={})
        key = _fragment_name_with_digest(key, options)
        key = url_for(key).split('://', 2).last if ::Hash === key
        key = ::ActiveSupport::Cache.expand_cache_key(key, :jbuilder)

        ::Digest::MD5.hexdigest(key.to_s).tap do |digest|
          _logger.try :debug, "Cache key :#{key} was digested to #{digest}"
        end
      end

      def _cache(key, options={})
        return yield self unless @context.controller.perform_caching && key

        parent_js = @js
        key = _cache_key(key, options)
        @js = []

        blank_or_value = begin
          ::Rails.cache.fetch(key, options) do
            result = yield self
            if result !=BLANK
              @js << _plumlinks_set_cache(key, result)
              @js.join
            else
              BLANK
            end
          end
        ensure
          @js = parent_js
        end

        if blank_or_value == BLANK
          BLANK
        else
          v = blank_or_value
          @js.push(v)
          Digest.new(key)
        end
      end

      def _plumlinks_set_cache(key, value)
        "Plumlinks.cache(\"#{key}\", #{_dump(value)});"
      end

      def _plumlinks_return(results)
        "return (#{_dump(results)});"
      end

      def _dump(value)
        ::MultiJson.dump(value)
      end

      def _ensure_valid_key(key)
        current_value = _blank? ? BLANK : @attributes.fetch(_key(key), BLANK)
        raise NullError.build(key) if current_value.nil?
      end

      def _cache_args(options)
        args = ::Kernel.Array(options[:cache])
        return if args.empty? || args.nil?

        opts = if ::Hash === args.last
          args.pop
        else
          {}
        end

        if options[:partial]
          opts[:partial] = options[:partial]
        end

        key = args.flatten
        if key.one? && ::Proc === key.first
          key = key.pop
        end

        [key, opts]
      end

      def _render_partial_with_options(options)
        options.reverse_merge! locals: {}
        options.reverse_merge! ::Plumlinks::PlumTemplate.template_lookup_options
        as = options[:as]

        if options.key?(:collection)
          collection = options.delete(:collection)
          locals = options.delete(:locals)

          cache_options = if _cache_options?(options)
            {cache: _cache_args(options)}
          else
            {}
          end

          array! collection, cache_options do |member|
            member_locals = locals.clone
            member_locals.merge! collection: collection
            member_locals.merge! as.to_sym => member if as
            _render_partial options.merge(locals: member_locals)
          end
        else
          _render_partial options
        end
      end

      def _render_partial(options)
        options[:locals].merge! json: self
        @context.render options
      end

      def _fragment_name_with_digest(key, options)
        if options[:partial] && !options[:skip_digest]
          [key, _partial_digest(options[:partial])]
        elsif
          @context.respond_to?(:cache_fragment_name)
          # Current compatibility, fragment_name_with_digest is private again and cache_fragment_name
          # should be used instead.
          @context.cache_fragment_name(key, options)
        elsif @context.respond_to?(:fragment_name_with_digest)
          # Backwards compatibility for period of time when fragment_name_with_digest was made public.
          @context.fragment_name_with_digest(key)
        else
          key
        end
      end

      def _cache_options?(options)
        ::Hash === options && options.key?(:cache)
      end

      def _partial_options?(options)
        ::Hash === options && options.key?(:partial)
      end

      def _set_inline_partial(name, object, options)
        value = if object.nil?
          []
        elsif _is_collection?(object)
          _scope{ _render_partial_with_options options.merge(collection: object) }
        else
          locals = {}
          locals[options[:as]] = object if !_blank?(object) && options.key?(:as)
          locals.merge!(options[:locals]) if options.key? :locals

          if _cache_options?(options)
            _cache(*_cache_args(options)) {
              _scope{ _render_partial options.merge(locals: locals) }
            }
          else
            _scope{ _render_partial options.merge(locals: locals) }
          end
        end

        set! name, value
      end

      def _partial_digest(partial)
        lookup_context = @context.lookup_context
        name = lookup_context.find(partial, lookup_context.prefixes, true).virtual_path
        _partial_digestor({name: name, finder: lookup_context})
      end

      def _logger
        ::ActionView::Base.logger
      end
  end


  class KbuilderHandler
    cattr_accessor :default_format
    self.default_format = Mime[:js]

    def self.call(template)
      # this juggling is required to keep line numbers right in the error
      %{__already_defined = defined?(json); json||=::Plumlinks::PlumTemplate.new(self);#{template.source}
        if !(__already_defined && __already_defined != "method")
        json.merge!({data: json.empty!})
          if defined?(plumlinks) && plumlinks
            plumlinks.each do |k, v|
              json.set! k, v
            end
          end

          if protect_against_forgery?
            json.csrf_token form_authenticity_token
          end

          if ::Plumlinks.configuration.track_assets.any?
            json.assets do
              json.array! (::Plumlinks.configuration.track_assets || []).map{|assets|
                asset_path(assets)
              }
            end
          end

          json.target!
        end
      }
    end
  end
end
