class window.Snapshot
  constructor: (@delegate) ->
    @pageCache = {}
    @currentBrowserState = null
    @pageCacheSize = 20
    @currentPage = null
    @loadedAssets= null

  onHistoryChange: (event) =>
    if event.state?.plumlinks && event.state.url != @currentBrowserState.url
      previousUrl = new ComponentUrl(@currentBrowserState.url)
      newUrl = new ComponentUrl(event.state.url)

      if restorePoint = @pageCache[newUrl.absolute]
        @cacheCurrentPage()
        @currentPage = restorePoint
        @delegate.restore(@currentPage)
      else
        @fetch event.target.location.href

  constrainPageCacheTo: (limit = 20) =>
    pageCacheKeys = Object.keys @pageCache

    cacheTimesRecentFirst = pageCacheKeys.map (url) =>
      @pageCache[url].cachedAt
    .sort (a, b) -> b - a

    for key in pageCacheKeys when @pageCache[key].cachedAt <= cacheTimesRecentFirst[limit]
      delete @pageCache[key]

  transitionCacheFor: (url) =>
    return if url is @currentBrowserState.url
    cachedPage = @pageCache[url]
    cachedPage if cachedPage and !cachedPage.transitionCacheDisabled

  removeCurrentPageFromCache: =>
    delete @pageCache[new ComponentUrl(@currentBrowserState.url).absolute]

  pagesCached: (size = @pageCacheSize) =>
    @pageCacheSize = parseInt(size) if /^[\d]+$/.test size

  cacheCurrentPage: =>
    return unless @currentPage
    currentUrl = new ComponentUrl @currentBrowserState.url

    Utils.merge @currentPage,
      cachedAt: new Date().getTime()
      positionY: window.pageYOffset
      positionX: window.pageXOffset
      url: currentUrl.relative

    @pageCache[currentUrl.absolute] = @currentPage

  reflectRedirectedUrl: (xhr)=>
    if location = xhr.getResponseHeader 'X-XHR-Redirected-To'
      location = new ComponentUrl location
      preservedHash = if location.hasNoHash() then document.location.hash else ''
      window.history.replaceState window.history.state, '', location.href + preservedHash

  rememberCurrentUrlAndState: =>
    window.history.replaceState { plumlinks: true, url: document.location.href }, '', document.location.href
    @currentBrowserState = window.history.state

  reflectNewUrl: (url) =>
    if (url = new ComponentUrl url).absolute != document.location.href
      window.history.pushState { plumlinks: true, url: url.absolute }, '', url.absolute

  updateCurrentBrowserState: =>
    @currentBrowserState = window.history.state

  changePage: (nextPage, options) =>
    if @currentPage and @assetsChanged(nextPage)
      document.location.reload()
      return

    @currentPage = nextPage
    @currentPage.title = options.title ? @currentPage.title
    document.title = @currentPage.title if @currentPage.title isnt false

    CSRFToken.update @currentPage.csrf_token if @currentPage.csrf_token?
    @updateCurrentBrowserState()

  assetsChanged: (nextPage) =>
    @loadedAssets ||= @currentPage.assets
    fetchedAssets = nextPage.assets
    fetchedAssets.length isnt @loadedAssets.length or Utils.intersection(fetchedAssets, @loadedAssets).length isnt @loadedAssets.length

