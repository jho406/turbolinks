PAGE_CACHE_SIZE = 20

class window.Controller
  constructor: ->
    @atomCache = {}
    @history = new Snapshot(this)
    @transitionCacheEnabled = false
    @requestCachingEnabled = true

    @progressBar = new ProgressBar 'html'

    @http = null

    @history.rememberCurrentUrlAndState()

  currentPage: =>
    @history.currentPage

  request: (url, options = {}) =>
    url = new ComponentUrl url
    return if @pageChangePrevented(url.absolute)

    if url.crossOrigin()
      document.location.href = url.absolute
      return

    @history.cacheCurrentPage()
    @progressBar?.start()

    if @transitionCacheEnabled and restorePoint = @history.transitionCacheFor(url.absolute)
      @history.reflectNewUrl(url)
      @restore(restorePoint)
      options.showProgressBar = false

    options.cacheRequest ?= @requestCachingEnabled
    options.showProgressBar ?= true

    Utils.triggerEvent Plumlinks.EVENTS.FETCH, url: url.absolute

    if options.isAsync
      options.showProgressBar = false
      @createRequest(url, options)
        .send(options.payload)
    else
      @http?.abort()
      @http = @createRequest(url, options)
      @http.send(options.payload)

  enableTransitionCache: (enable = true) =>
    @transitionCacheEnabled = enable

  disableRequestCaching: (disable = true) =>
    @requestCachingEnabled = not disable
    disable

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
    redirect if (redirect = @http.getResponseHeader('Location'))? and (new ComponentUrl(redirect)).crossOrigin()

  pageChangePrevented: (url) =>
    !Utils.triggerEvent Plumlinks.EVENTS.BEFORE_CHANGE, url: url

  processResponse: (xhr) ->
    if @hasValidResponse(xhr)
      return @responseContent(xhr)

  cache: (key, value) =>
    return @atomCache[key] if value == null
    @atomCache[key] ||= value

  # Events
  onLoadEnd: => @http = null

  onLoad: (xhr, url, options) =>
    Utils.triggerEvent Plumlinks.EVENTS.RECEIVE, url: url.absolute
    if nextPage = @processResponse(xhr)
      @history.reflectNewUrl url
      @history.reflectRedirectedUrl(xhr)
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
    @progressBar.advanceFromEvent(event)

  onError: =>
    document.location.href = url.absolute

  createRequest: (url, opts)=>
    requestMethod = opts.requestMethod || 'GET'
    xhr = new XMLHttpRequest
    xhr.open requestMethod, url.formatForXHR(cache: opts.cacheRequest), true
    xhr.setRequestHeader 'Accept', 'text/javascript, application/x-javascript, application/javascript'
    xhr.setRequestHeader 'X-XHR-Referer', document.location.href
    xhr.setRequestHeader 'X-Requested-With', 'XMLHttpRequest'
    xhr.onload = =>
      @onLoad(` this `, url, opts)
    xhr.onprogress = @onProgress if @progressBar and opts.showProgressBar
    xhr.onloadend = @onLoadEnd
    xhr.onerror = @onError
    xhr

  hasValidResponse: (xhr) ->
    not @clientOrServerError(xhr) and @validContent(xhr) and not @downloadingFile(xhr)

  responseContent: (xhr) ->
    new Function("'use strict'; return " + xhr.responseText )();

  clientOrServerError: (xhr) ->
    400 <= xhr.status < 600

  validContent: (xhr) ->
    (contentType = xhr.getResponseHeader('Content-Type'))? and
      contentType.match /^(?:text\/javascript|application\/x-javascript|application\/javascript)(?:;|$)/

  downloadingFile: (xhr) ->
    (disposition = xhr.getResponseHeader('Content-Disposition'))? and
      disposition.match /^attachment/


