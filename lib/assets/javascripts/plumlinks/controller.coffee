PAGE_CACHE_SIZE = 20

class window.Controller
  constructor: ->
    @atomCache = {}
    @history = new Pistory(this)
    @transitionCacheEnabled = false
    @requestCachingEnabled = true

    @progressBar = null

    @http = null

    @history.rememberCurrentUrlAndState()

  currentPage: =>
    @history.currentPage

  fetch: (url, options = {}) =>
    url = new ComponentUrl url
    return if @pageChangePrevented(url.absolute)

    if url.crossOrigin()
      document.location.href = url.absolute
      return

    @history.cacheCurrentPage()
    @history.rememberReferer()
    @progressBar?.start()

    if @transitionCacheEnabled and restorePoint = @history.transitionCacheFor(url.absolute)
      @history.reflectNewUrl(url)
      @restore(restorePoint)
      options.showProgressBar = false

    options.cacheRequest ?= @requestCachingEnabled
    options.showProgressBar ?= true

    Utils.triggerEvent Plumlinks.EVENTS.FETCH, url: url.absolute

    @http?.abort()
    @http = new Remote(url, @history.referer, @, options)
    @http.send(options.payload)

  enableTransitionCache: (enable = true) =>
    @transitionCacheEnabled = enable

  disableRequestCaching: (disable = true) =>
    @requestCachingEnabled = not disable
    disable

  remote: (url, method, data) =>
    @fetch(url, {payload: data, requestMethod: method})

  restore: (cachedPage, options = {}) =>
    @http?.abort()
    @history.changePage(cachedPage, options)

    @progressBar?.done()
    Utils.triggerEvent Plumlinks.EVENTS.RESTORE
    Utils.triggerEvent Plumlinks.EVENTS.LOAD, cachedPage

  replace: (nextPage, options = {}) =>
    Utils.withDefaults(nextPage, @history.currentBrowserState)
    @history.changePage(nextPage, options)
    Utils.triggerEvent Plumlinks.EVENTS.LOAD, @currentPage()

  crossOriginRedirect: =>
    redirect if (redirect = @http.xhr.getResponseHeader('Location'))? and (new ComponentUrl(redirect)).crossOrigin()

  pageChangePrevented: (url) =>
    !Utils.triggerEvent Plumlinks.EVENTS.BEFORE_CHANGE, url: url

  processResponse: ->
    if @http.hasValidResponse()
      return @http.content()

  cache: (key, value) =>
    return @atomCache[key] if value == null
    @atomCache[key] ||= value

  # Events
  onLoadEnd: => @http = null

  onLoad: (url, options) =>
    Utils.triggerEvent Plumlinks.EVENTS.RECEIVE, url: url.absolute

    if nextPage = @processResponse()
      @history.reflectNewUrl url
      @history.reflectRedirectedUrl(@http.xhr)
      Utils.withDefaults(nextPage, @history.currentBrowserState)
      @history.changePage(nextPage, options)
      Utils.triggerEvent Plumlinks.EVENTS.LOAD, @currentPage()

      if options.showProgressBar
        @progressBar?.done()
      @history.constrainPageCacheTo
    else
      @progressBar?.done()
      document.location.href = @crossOriginRedirect() or url.absolute

  onProgress: (event) =>
    @progress.advanceFromEvent(event)

  onError: =>
    document.location.href = url.absolute

