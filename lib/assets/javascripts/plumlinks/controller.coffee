PAGE_CACHE_SIZE = 20

class window.Controller
  constructor: ->
    @atomCache = {}
    @pageCache = {}
    @pageCacheSize = PAGE_CACHE_SIZE

    @transitionCacheEnabled = false
    @requestCachingEnabled = true

    @progressBar = null
    @progressBarDelay = 400

    @currentPage = null
    @currentBrowserState = null
    @loadedAssets = null

    @referer = null
    @remote = null

    @rememberCurrentUrlAndState()

  fetch: (url, options = {}) =>
    url = new ComponentUrl url

    return if @pageChangePrevented(url.absolute)

    if url.crossOrigin()
      document.location.href = url.absolute
      return

    @cacheCurrentPage()

    @rememberReferer()
    @progressBar?.start(delay: @progressBarDelay)
    if @transitionCacheEnabled and restorePoint = @transitionCacheFor(url.absolute)
      @reflectNewUrl(url)
      @fetchHistory restorePoint
      options.showProgressBar = false
      # options.scroll = false

    @fetchReplacement url, options

  transitionCacheFor: (url) =>
    return if url is @currentBrowserState.url
    cachedPage = @pageCache[url]
    cachedPage if cachedPage and !cachedPage.transitionCacheDisabled

  enableTransitionCache: (enable = true) =>
    @transitionCacheEnabled = enable

  disableRequestCaching: (disable = true) =>
    @requestCachingEnabled = not disable
    disable

  onLoadEnd: => @remote = null

  onLoadSuccess: (url, options) =>
    @triggerEvent Plumlinks.EVENTS.RECEIVE, url: url.absolute

    if nextPage = @processResponse()
      @reflectNewUrl url
      @reflectRedirectedUrl()
      Utils.withDefaults(nextPage, @currentBrowserState)
      @changePage(nextPage, options)
      #updateScrollPosition(options.scroll)
      @triggerEvent Plumlinks.EVENTS.LOAD, @currentPage

      if options.showProgressBar
        @progressBar?.done()
      @constrainPageCacheTo(@pageCacheSize)
    else
      @progressBar?.done()
      document.location.href = @crossOriginRedirect() or url.absolute

  onProgress: (event) =>
    percent = if event.lengthComputable
      event.loaded / event.total * 100
    else
      @progressBar.value + (100 - @progressBar.value) / 10
    
    @progressBar.advanceTo(percent)

  onError: =>
    document.location.href = url.absolute

  fetchReplacement: (url, options) =>
    options.cacheRequest ?= @requestCachingEnabled
    options.showProgressBar ?= true

    delegate = {}
    delegate.onerror = @onError
    delegate.onloadend = @onLoadEnd
    delegate.onload = () =>
      @onLoadSuccess(url, options)

    @triggerEvent Plumlinks.EVENTS.FETCH, url: url.absolute
    @remote?.abort()
    @remote = new Remote(url, delegate, cache: options.cacheRequest, referer: @referer)
    @remote.send()

  fetchHistory: (cachedPage, options = {}) =>
    @remote?.abort()
    @changePage(cachedPage, options)

    @progressBar?.done()
    # updateScrollPosition(options.scroll)
    @triggerEvent Plumlinks.EVENTS.RESTORE
    @triggerEvent Plumlinks.EVENTS.LOAD, cachedPage

  cacheCurrentPage: =>
    return unless @currentPage
    currentUrl = new ComponentUrl @currentBrowserState.url

    Utils.merge @currentPage,
      cachedAt: new Date().getTime()
      positionY: window.pageYOffset
      positionX: window.pageXOffset
      url: currentUrl.relative

    @pageCache[currentUrl.absolute] = @currentPage

  removeCurrentPageFromCache: =>
    delete @pageCache[new ComponentUrl(@currentBrowserState.url).absolute]

  pagesCached: (size = @pageCacheSize) =>
    @pageCacheSize = parseInt(size) if /^[\d]+$/.test size

  constrainPageCacheTo: (limit) =>
    pageCacheKeys = Object.keys @pageCache

    cacheTimesRecentFirst = pageCacheKeys.map (url) =>
      @pageCache[url].cachedAt
    .sort (a, b) -> b - a

    for key in pageCacheKeys when @pageCache[key].cachedAt <= cacheTimesRecentFirst[limit]
      delete @pageCache[key]

  replace: (nextPage, options = {}) =>
    Utils.withDefaults(nextPage, @currentBrowserState)
    @changePage(nextPage, options)
    @triggerEvent Plumlinks.EVENTS.LOAD, @currentPage

  changePage: (nextPage, options) =>
    if @currentPage and @assetsChanged(nextPage)
      document.location.reload()
      return

    @currentPage = nextPage
    @currentPage.title = options.title ? @currentPage.title
    document.title = @currentPage.title if @currentPage.title isnt false

    CSRFToken.update @currentPage.csrf_token if @currentPage.csrf_token?
    @currentBrowserState = window.history.state

  assetsChanged: (nextPage) =>
    @loadedAssets ||= @currentPage.assets
    fetchedAssets = nextPage.assets
    fetchedAssets.length isnt @loadedAssets.length or Utils.intersection(fetchedAssets, @loadedAssets).length isnt @loadedAssets.length

  reflectNewUrl: (url) =>
    if (url = new ComponentUrl url).absolute not in [@referer, document.location.href]
      window.history.pushState { plumlinks: true, url: url.absolute }, '', url.absolute

  reflectRedirectedUrl: =>
    if location = @remote.xhr.getResponseHeader 'X-XHR-Redirected-To'
      location = new ComponentUrl location
      preservedHash = if location.hasNoHash() then document.location.hash else ''
      window.history.replaceState window.history.state, '', location.href + preservedHash

  crossOriginRedirect: =>
    redirect if (redirect = @remote.xhr.getResponseHeader('Location'))? and (new ComponentUrl(redirect)).crossOrigin()

  rememberReferer: =>
    @referer = document.location.href

  rememberCurrentUrlAndState: =>
    window.history.replaceState { plumlinks: true, url: document.location.href }, '', document.location.href
    @currentBrowserState = window.history.state

  updateScrollPosition: (position) =>
    if Array.isArray(position)
      window.scrollTo position[0], position[1]
    else if position isnt false
      if document.location.hash
        document.location.href = document.location.href
        @rememberCurrentUrlAndState()
      else
        window.scrollTo 0, 0

  triggerEvent: (name, data) =>
    if typeof Prototype isnt 'undefined'
      Event.fire document, name, data, true

    event = document.createEvent 'Events'
    event.data = data if data
    event.initEvent name, true, true
    document.dispatchEvent event

  pageChangePrevented: (url) =>
    !@triggerEvent Plumlinks.EVENTS.BEFORE_CHANGE, url: url

  processResponse: ->
    if @remote.hasValidResponse()
      return @remote.content()

  cache: (key, value) =>
    return @atomCache[key] if value == null
    @atomCache[key] ||= value

  onHistoryChange: (event) =>
    if event.state?.plumlinks && event.state.url != @currentBrowserState.url
      previousUrl = new ComponentUrl(@currentBrowserState.url)
      newUrl = new ComponentUrl(event.state.url)

      if newUrl.withoutHash() is previousUrl.withoutHash()
        # updateScrollPosition()
      else if restorePoint = @pageCache[newUrl.absolute]
        @cacheCurrentPage()
        @currentPage = restorePoint
        @fetchHistory @currentPage, scroll: [@currentPage.positionX, @currentPage.positionY]
      else
        @fetch event.target.location.href

