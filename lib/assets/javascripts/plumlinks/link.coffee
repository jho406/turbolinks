
# The Link class derives from the ComponentUrl class, but is built from an
# existing link element.  Provides verification functionality for Plumlinks
# to use in determining whether it should process the link when clicked.
class window.Link extends ComponentUrl
  @HTML_EXTENSIONS: []

  @allowExtensions: (extensions...) ->
    Link.HTML_EXTENSIONS.push extension for extension in extensions
    Link.HTML_EXTENSIONS

  constructor: (@link) ->
    return @link if @link.constructor is Link
    @original = @link.href
    @originalElement = @link
    @link = @link.cloneNode false
    super

  shouldIgnore: ->
    @crossOrigin() or
      @_anchored() or
      @_nonHtml() or
      @_optOut() or
      @_target()

  _anchored: ->
    (@hash.length > 0 or @href.charAt(@href.length - 1) is '#') and
      (@withoutHash() is (new ComponentUrl).withoutHash())

  _nonHtml: ->
    @pathname.match(/\.[a-z]+$/g) and not @pathname.match(new RegExp("\\.(?:#{Link.HTML_EXTENSIONS.join('|')})?$", 'g'))

  _optOut: ->
    link = @originalElement
    until enabled or link is document
      enabled = link.getAttribute('data-plumlinks')?
      link = link.parentNode
    !enabled

  _target: ->
    @link.target.length isnt 0
