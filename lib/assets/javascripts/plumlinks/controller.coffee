PAGE_CACHE_SIZE = 20

class window.Controller
  constructor: ->
    @atomCache = {}
    @history = new Pistory(this)
    @transitionCacheEnabled = false
    @requestCachingEnabled = true

    @progressBar = null

    @loadedAssets = null

    @referer = null
    @remote = null

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

    @rememberReferer()
    @progressBar?.start()

    if @transitionCacheEnabled and restorePoint = @history.transitionCacheFor(url.absolute)
      @history.reflectNewUrl(url)
      @restore(restorePoint)
      options.showProgressBar = false

    @fetchReplacement url, options

  enableTransitionCache: (enable = true) =>
    @transitionCacheEnabled = enable

  disableRequestCaching: (disable = true) =>
    @requestCachingEnabled = not disable
    disable

  fetchReplacement: (url, options) =>
    options.cacheRequest ?= @requestCachingEnabled
    options.showProgressBar ?= true

    Utils.triggerEvent Plumlinks.EVENTS.FETCH, url: url.absolute
    @remote?.abort()
    @remote = new Remote(url, @referer, @, options)
    @remote.send()

  restore: (cachedPage, options = {}) =>
    @remote?.abort()
    @changePage(cachedPage, options)

    @progressBar?.done()
    Utils.triggerEvent Plumlinks.EVENTS.RESTORE
    Utils.triggerEvent Plumlinks.EVENTS.LOAD, cachedPage

  replace: (nextPage, options = {}) =>
    Utils.withDefaults(nextPage, @history.currentBrowserState)
    @changePage(nextPage, options)
    Utils.triggerEvent Plumlinks.EVENTS.LOAD, @currentPage()

  changePage: (nextPage, options) =>
    if @currentPage() and @assetsChanged(nextPage)
      document.location.reload()
      return

    @history.currentPage = nextPage
    @history.currentPage.title = options.title ? @currentPage().title
    document.title = @currentPage().title if @currentPage().title isnt false

    CSRFToken.update @currentPage().csrf_token if @currentPage().csrf_token?
    @history.updateCurrentBrowserState()

  assetsChanged: (nextPage) =>
    @loadedAssets ||= @currentPage().assets
    fetchedAssets = nextPage.assets
    fetchedAssets.length isnt @loadedAssets.length or Utils.intersection(fetchedAssets, @loadedAssets).length isnt @loadedAssets.length

  crossOriginRedirect: =>
    redirect if (redirect = @remote.xhr.getResponseHeader('Location'))? and (new ComponentUrl(redirect)).crossOrigin()

  rememberReferer: =>
    @referer = document.location.href

  pageChangePrevented: (url) =>
    !Utils.triggerEvent Plumlinks.EVENTS.BEFORE_CHANGE, url: url

  processResponse: ->
    if @remote.hasValidResponse()
      return @remote.content()

  cache: (key, value) =>
    return @atomCache[key] if value == null
    @atomCache[key] ||= value

  clickedOrSubmitted: (ev) =>
    target = ev.target
    httpRequestType = getRemoteAttr(target, 'pm-remote')

    valid_link = !(target.nodeName is 'A' and target.href.length isnt 0)

    return unless httpRequestType && valid_link
    ev.preventDefault()

    link = new Link(target)
    fetch(link.href)

#events
  onLoadEnd: => @remote = null

  onLoad: (url, options) =>

    Utils.triggerEvent Plumlinks.EVENTS.RECEIVE, url: url.absolute

    if nextPage = @processResponse()
      @history.reflectNewUrl url
      @history.reflectRedirectedUrl(@remote.xhr)
      Utils.withDefaults(nextPage, @history.currentBrowserState)
      @changePage(nextPage, options)
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

