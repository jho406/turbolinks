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

xhr                     = null

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
    options.scroll = false

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

withDefaults = (page) =>
    currentUrl = new ComponentUrl currentBrowserState.url

    reverseMerge page,
      url: currentUrl.relative
      cachedAt: new Date().getTime()
      assets: []
      data: {}
      title: ''
      positionY: 0
      positionX: 0
      csrf_token: null

fetchReplacement = (url, options) ->
  options.cacheRequest ?= requestCachingEnabled
  options.showProgressBar ?= true

  triggerEvent EVENTS.FETCH, url: url.absolute

  xhr?.abort()
  xhr = new XMLHttpRequest
  xhr.open 'GET', url.formatForXHR(cache: options.cacheRequest), true
  xhr.setRequestHeader 'Accept', 'text/javascript, application/x-javascript, application/javascript'
  xhr.setRequestHeader 'X-XHR-Referer', referer
  xhr.setRequestHeader 'X-Requested-With', 'XMLHttpRequest'

  xhr.onload = ->
    triggerEvent EVENTS.RECEIVE, url: url.absolute

    if nextPage = processResponse()
      reflectNewUrl url
      reflectRedirectedUrl()
      withDefaults(nextPage)
      changePage(nextPage, options)
      updateScrollPosition(options.scroll)
      triggerEvent EVENTS.LOAD, currentPage

      if options.showProgressBar
        progressBar?.done()
      constrainPageCacheTo(pageCacheSize)
    else
      progressBar?.done()
      document.location.href = crossOriginRedirect() or url.absolute

  if progressBar and options.showProgressBar
    xhr.onprogress = (event) =>
      percent = if event.lengthComputable
        event.loaded / event.total * 100
      else
        progressBar.value + (100 - progressBar.value) / 10
      progressBar.advanceTo(percent)

  xhr.onloadend = -> xhr = null
  xhr.onerror   = -> document.location.href = url.absolute
  xhr.send()

fetchHistory = (cachedPage, options = {}) ->
  xhr?.abort()
  changePage(cachedPage, options)

  progressBar?.done()
  updateScrollPosition(options.scroll)
  triggerEvent EVENTS.RESTORE
  triggerEvent EVENTS.LOAD, cachedPage

cacheCurrentPage = ->
  return unless currentPage
  currentUrl = new ComponentUrl currentBrowserState.url

  merge currentPage,
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
  withDefaults(nextPage)
  changePage(nextPage, options)
  triggerEvent EVENTS.LOAD, currentPage

reverseMerge = (dest, obj) ->
  for k, v of obj
    dest[k] = v if !dest.hasOwnProperty(k)
  dest

merge = (dest, obj) ->
  for k, v of obj
    dest[k] = v
  dest

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
  fetchedAssets.length isnt loadedAssets.length or intersection(fetchedAssets, loadedAssets).length isnt loadedAssets.length

intersection = (a, b) ->
  [a, b] = [b, a] if a.length > b.length
  value for value in a when value in b

reflectNewUrl = (url) ->
  if (url = new ComponentUrl url).absolute not in [referer, document.location.href]
    window.history.pushState { plumlinks: true, url: url.absolute }, '', url.absolute

reflectRedirectedUrl = ->
  if location = xhr.getResponseHeader 'X-XHR-Redirected-To'
    location = new ComponentUrl location
    preservedHash = if location.hasNoHash() then document.location.hash else ''
    window.history.replaceState window.history.state, '', location.href + preservedHash

crossOriginRedirect = ->
  redirect if (redirect = xhr.getResponseHeader('Location'))? and (new ComponentUrl(redirect)).crossOrigin()

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

clone = (original) ->
  return original if not original? or typeof original isnt 'object'
  copy = new original.constructor()
  copy[key] = clone value for key, value of original
  copy

popCookie = (name) ->
  value = document.cookie.match(new RegExp(name+"=(\\w+)"))?[1].toUpperCase() or ''
  document.cookie = name + '=; expires=Thu, 01-Jan-70 00:00:01 GMT; path=/'
  value

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
  clientOrServerError = ->
    400 <= xhr.status < 600
  validContent = ->
    (contentType = xhr.getResponseHeader('Content-Type'))? and
      contentType.match /^(?:text\/javascript|application\/x-javascript|application\/javascript)(?:;|$)/
  downloadingFile = ->
    (disposition = xhr.getResponseHeader('Content-Disposition'))? and
      disposition.match /^attachment/

  if not clientOrServerError() and validContent() and not downloadingFile()
    return new Function("'use strict'; return " + xhr.responseText )();

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
      updateScrollPosition()
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

browserSupportsPushState = window.history and 'pushState' of window.history and 'state' of window.history

# Copied from https://github.com/Modernizr/Modernizr/blob/master/feature-detects/history.js
ua = navigator.userAgent
browserIsBuggy =
  (ua.indexOf('Android 2.') != -1 or ua.indexOf('Android 4.0') != -1) and
  ua.indexOf('Mobile Safari') != -1 and
  ua.indexOf('Chrome') == -1 and
  ua.indexOf('Windows Phone') == -1

requestMethodIsSafe = popCookie('request_method') in ['GET','']

browserSupportsPlumlinks = browserSupportsPushState and !browserIsBuggy and requestMethodIsSafe

browserSupportsCustomEvents =
  document.addEventListener and document.createEvent

if browserSupportsPlumlinks
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
  supported: browserSupportsPlumlinks,
  EVENTS: clone(EVENTS)
}
