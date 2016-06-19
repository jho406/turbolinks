#= require_tree ./plumlinks
#= require_self

atomCache               = {}
pageCache               = {}
pageCacheSize           = 20

transitionCacheEnabled  = false
requestCachingEnabled   = true
progressBar             = null
progressBarDelay        = 400

currentPage             = null
currentBrowserState     = null
loadedAssets            = null

referer                 = null

remote                  = null

EVENTS =
  BEFORE_CHANGE:  'plumlinks:click'
  FETCH:          'plumlinks:request-start'
  RECEIVE:        'plumlinks:request-end'
  LOAD:           'plumlinks:load'
  RESTORE:        'plumlinks:restore'

fetch = (url, options = {}) ->
  url = new ComponentUrl url

  return if pageChangePrevented(url.absolute)

  if url.crossOrigin()
    document.location.href = url.absolute
    return

  cacheCurrentPage()

  rememberReferer()
  progressBar?.start(delay: progressBarDelay)
  if transitionCacheEnabled and restorePoint = transitionCacheFor(url.absolute)
    reflectNewUrl(url)
    fetchHistory restorePoint
    options.showProgressBar = false
    # options.scroll = false

  fetchReplacement url, options

transitionCacheFor = (url) ->
  return if url is currentBrowserState.url
  cachedPage = pageCache[url]
  cachedPage if cachedPage and !cachedPage.transitionCacheDisabled

enableTransitionCache = (enable = true) ->
  transitionCacheEnabled = enable

disableRequestCaching = (disable = true) ->
  requestCachingEnabled = not disable
  disable

onLoadEnd = => remote = null

onLoadSuccess = (url, options) =>
  triggerEvent EVENTS.RECEIVE, url: url.absolute

  if nextPage = processResponse()
    reflectNewUrl url
    reflectRedirectedUrl()
    Utils.withDefaults(nextPage, currentBrowserState)
    changePage(nextPage, options)
    #updateScrollPosition(options.scroll)
    triggerEvent EVENTS.LOAD, currentPage

    if options.showProgressBar
      progressBar?.done()
    constrainPageCacheTo(pageCacheSize)
  else
    progressBar?.done()
    document.location.href = crossOriginRedirect() or url.absolute

onProgress = (event) =>
  percent = if event.lengthComputable
    event.loaded / event.total * 100
  else
    progressBar.value + (100 - progressBar.value) / 10
  
  progressBar.advanceTo(percent)

onError = =>
  document.location.href = url.absolute

fetchReplacement = (url, options) ->
  options.cacheRequest ?= requestCachingEnabled
  options.showProgressBar ?= true

  delegate = {}
  delegate.onerror = onError
  delegate.onloadend = onLoadEnd
  delegate.onload = () ->
    onLoadSuccess(url, options)

  triggerEvent EVENTS.FETCH, url: url.absolute
  remote?.abort()
  remote = new Remote(url, delegate, cache: options.cacheRequest, referer: referer)
  remote.send()

fetchHistory = (cachedPage, options = {}) ->
  remote?.abort()
  changePage(cachedPage, options)

  progressBar?.done()
  # updateScrollPosition(options.scroll)
  triggerEvent EVENTS.RESTORE
  triggerEvent EVENTS.LOAD, cachedPage

cacheCurrentPage = ->
  return unless currentPage
  currentUrl = new ComponentUrl currentBrowserState.url

  Utils.merge currentPage,
    cachedAt: new Date().getTime()
    positionY: window.pageYOffset
    positionX: window.pageXOffset
    url: currentUrl.relative

  pageCache[currentUrl.absolute] = currentPage

removeCurrentPageFromCache = ->
  delete pageCache[new ComponentUrl(currentBrowserState.url).absolute]

pagesCached = (size = pageCacheSize) ->
  pageCacheSize = parseInt(size) if /^[\d]+$/.test size

constrainPageCacheTo = (limit) ->
  pageCacheKeys = Object.keys pageCache

  cacheTimesRecentFirst = pageCacheKeys.map (url) ->
    pageCache[url].cachedAt
  .sort (a, b) -> b - a

  for key in pageCacheKeys when pageCache[key].cachedAt <= cacheTimesRecentFirst[limit]
    delete pageCache[key]

replace = (nextPage, options = {}) ->
  Utils.withDefaults(nextPage, currentBrowserState)
  changePage(nextPage, options)
  triggerEvent EVENTS.LOAD, currentPage

changePage = (nextPage, options) ->
  if currentPage and assetsChanged(nextPage)
    document.location.reload()
    return

  currentPage = nextPage
  currentPage.title = options.title ? currentPage.title
  document.title = currentPage.title if currentPage.title isnt false

  CSRFToken.update currentPage.csrf_token if currentPage.csrf_token?
  currentBrowserState = window.history.state

assetsChanged = (nextPage) ->
  loadedAssets ||= currentPage.assets
  fetchedAssets  = nextPage.assets
  fetchedAssets.length isnt loadedAssets.length or Utils.intersection(fetchedAssets, loadedAssets).length isnt loadedAssets.length

reflectNewUrl = (url) ->
  if (url = new ComponentUrl url).absolute not in [referer, document.location.href]
    window.history.pushState { plumlinks: true, url: url.absolute }, '', url.absolute

reflectRedirectedUrl = ->
  if location = remote.xhr.getResponseHeader 'X-XHR-Redirected-To'
    location = new ComponentUrl location
    preservedHash = if location.hasNoHash() then document.location.hash else ''
    window.history.replaceState window.history.state, '', location.href + preservedHash

crossOriginRedirect = ->
  redirect if (redirect = remote.xhr.getResponseHeader('Location'))? and (new ComponentUrl(redirect)).crossOrigin()

rememberReferer = ->
  referer = document.location.href

rememberCurrentUrlAndState = ->
  window.history.replaceState { plumlinks: true, url: document.location.href }, '', document.location.href
  currentBrowserState = window.history.state

updateScrollPosition = (position) ->
  if Array.isArray(position)
    window.scrollTo position[0], position[1]
  else if position isnt false
    if document.location.hash
      document.location.href = document.location.href
      rememberCurrentUrlAndState()
    else
      window.scrollTo 0, 0

triggerEvent = (name, data) ->
  if typeof Prototype isnt 'undefined'
    Event.fire document, name, data, true

  event = document.createEvent 'Events'
  event.data = data if data
  event.initEvent name, true, true
  document.dispatchEvent event

pageChangePrevented = (url) ->
  !triggerEvent EVENTS.BEFORE_CHANGE, url: url

processResponse = ->
  if remote.hasValidResponse()
    return remote.content()

cache = (key, value) ->
  return atomCache[key] if value == null
  atomCache[key] ||= value

ProgressBarAPI =
  enable: ->
    progressBar ?= new ProgressBar 'html'
  disable: ->
    progressBar?.uninstall()
    progressBar = null
  setDelay: (value) -> progressBarDelay = value
  start: (options) -> ProgressBarAPI.enable().start(options)
  advanceTo: (value) -> progressBar?.advanceTo(value)
  done: -> progressBar?.done()

onHistoryChange = (event) ->
  if event.state?.plumlinks && event.state.url != currentBrowserState.url
    previousUrl = new ComponentUrl(currentBrowserState.url)
    newUrl = new ComponentUrl(event.state.url)

    if newUrl.withoutHash() is previousUrl.withoutHash()
      # updateScrollPosition()
    else if restorePoint = pageCache[newUrl.absolute]
      cacheCurrentPage()
      currentPage = restorePoint
      fetchHistory currentPage, scroll: [currentPage.positionX, currentPage.positionY]
    else
      visit event.target.location.href

initializePlumlinks = ->
  rememberCurrentUrlAndState()
  ProgressBarAPI.enable()

  document.addEventListener 'click', Click.installHandlerLast, true
  window.addEventListener 'hashchange', rememberCurrentUrlAndState, false
  window.addEventListener 'popstate', onHistoryChange, false

browserSupportsCustomEvents =
  document.addEventListener and document.createEvent

if Utils.browserSupportsPlumlinks
  visit = fetch
  initializePlumlinks()
else
  visit = (url = document.location.href) -> document.location.href = url

# Public API
#   Plumlinks.visit(url)
#   Plumlinks.replace(html)
#   Plumlinks.pagesCached()
#   Plumlinks.pagesCached(20)
#   Plumlinks.enableTransitionCache()
#   Plumlinks.disableRequestCaching()
#   Plumlinks.ProgressBar.enable()
#   Plumlinks.ProgressBar.disable()
#   Plumlinks.ProgressBar.start()
#   Plumlinks.ProgressBar.advanceTo(80)
#   Plumlinks.ProgressBar.done()
#   Plumlinks.allowLinkExtensions('md')
#   Plumlinks.supported
#   Plumlinks.EVENTS
@Plumlinks = {
  visit,
  replace,
  cache,
  pagesCached,
  enableTransitionCache,
  disableRequestCaching,
  ProgressBar: ProgressBarAPI,
  allowLinkExtensions: Link.allowExtensions,
  supported: Utils.browserSupportsPlumlinks(),
  EVENTS: Utils.clone(EVENTS)
}
