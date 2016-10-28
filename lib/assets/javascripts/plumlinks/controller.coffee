PAGE_CACHE_SIZE = 20

class window.Controller
  constructor: ->
    @atomCache = {}
    @history = new Snapshot(this)
    @transitionCacheEnabled = false
    @requestCachingEnabled = true

    @progressBar = new ProgressBar 'html'
    @pq = new ParallelQueue
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
    restorePoint = @history.transitionCacheFor(url.absolute)

    if @transitionCacheEnabled and restorePoint
      @history.reflectNewUrl(url)
      @restore(restorePoint)
      options.showProgressBar = false

    options.cacheRequest ?= @requestCachingEnabled
    options.showProgressBar ?= true

    Utils.triggerEvent Bensonhurst.EVENTS.FETCH, url: url.absolute

    if options.isAsync
      options.showProgressBar = false
      req = @createRequest(url, options)
      req.onError = -> {} # for now do nothing on errors
      @pq.push(req)
      req.send(options.payload)
    else
      @pq.drain()
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
    Utils.triggerEvent Bensonhurst.EVENTS.RESTORE
    Utils.triggerEvent Bensonhurst.EVENTS.LOAD, cachedPage

  replace: (nextPage, options = {}) =>
    Utils.withDefaults(nextPage, @history.currentBrowserState)
    @history.changePage(nextPage, options)
    Utils.triggerEvent Bensonhurst.EVENTS.LOAD, @currentPage()

  crossOriginRedirect: =>
    redirect = @http.getResponseHeader('Location')
    crossOrigin = (new ComponentUrl(redirect)).crossOrigin()

    if redirect? and crossOrigin
      redirect

  pageChangePrevented: (url) =>
    !Utils.triggerEvent Bensonhurst.EVENTS.BEFORE_CHANGE, url: url

  cache: (key, value) =>
    return @atomCache[key] if value == null
    @atomCache[key] ||= value

  updateContentByKeypath: (keypath, node)=>
    for k, v in @history.pageCache
      keypath = 'data.' + keypath
      @history.pageCache[k] = Utils.updateCurrentBrowserState(keypath, node, v)
    Utils.triggerEvent Bensonhurst.EVENTS.LOAD, @currentPage()

  # Events
  onLoadEnd: => @http = null

  onLoad: (xhr, url, options) =>
    Utils.triggerEvent Bensonhurst.EVENTS.RECEIVE, url: url.absolute
    nextPage =  @processResponse(xhr)

    if xhr.status == 0
      return

    if nextPage
      if options.isAsync && url.pathname != @currentPage().url
        console.warn("async response path is different from current page path")
        return

      @history.reflectNewUrl url
      Utils.withDefaults(nextPage, @history.currentBrowserState)
      @history.changePage(nextPage, options)
      Utils.triggerEvent Bensonhurst.EVENTS.LOAD, @currentPage()

      if options.showProgressBar
        @progressBar?.done()
      @history.constrainPageCacheTo()
    else
      @progressBar?.done()
      document.location.href = @crossOriginRedirect() or url.absolute

  onProgress: (event) =>
    @progressBar.advanceFromEvent(event)

  onError: (url) =>
    document.location.href = url.absolute

  createRequest: (url, opts)=>
    jsAccept = 'text/javascript, application/x-javascript, application/javascript'
    requestMethod = opts.requestMethod || 'GET'

    xhr = new XMLHttpRequest
    xhr.open requestMethod, url.formatForXHR(cache: opts.cacheRequest), true
    xhr.setRequestHeader 'Accept', jsAccept
    xhr.setRequestHeader 'X-XHR-Referer', document.location.href
    xhr.setRequestHeader 'X-Silent', opts.silent if opts.silent
    xhr.setRequestHeader 'X-Requested-With', 'XMLHttpRequest'
    xhr.setRequestHeader 'Content-Type', opts.contentType if opts.contentType

    csrfToken = CSRFToken.get().token
    xhr.setRequestHeader('X-CSRF-Token', csrfToken) if csrfToken

    if !opts.silent
      xhr.onload = =>
        self = ` this `
        redirectedUrl = self.getResponseHeader 'X-XHR-Redirected-To'
        actualUrl = redirectedUrl || url
        @onLoad(self, actualUrl, opts)

    xhr.onprogress = @onProgress if @progressBar and opts.showProgressBar
    xhr.onloadend = @onLoadEnd
    xhr.onerror = =>
      @onError(url)
    xhr

  processResponse: (xhr) ->
    if @hasValidResponse(xhr)
      return @responseContent(xhr)

  hasValidResponse: (xhr) ->
    not @clientOrServerError(xhr) and @validContent(xhr) and not @downloadingFile(xhr)

  responseContent: (xhr) ->
    new Function("'use strict'; return " + xhr.responseText )()

  clientOrServerError: (xhr) ->
    400 <= xhr.status < 600

  validContent: (xhr) ->
    contentType = xhr.getResponseHeader('Content-Type')
    jsContent = /^(?:text\/javascript|application\/x-javascript|application\/javascript)(?:;|$)/

    contentType? and contentType.match jsContent

  downloadingFile: (xhr) ->
    (disposition = xhr.getResponseHeader('Content-Disposition'))? and
      disposition.match /^attachment/


