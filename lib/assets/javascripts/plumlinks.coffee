#= require_tree ./plumlinks
#= require_self
#
EVENTS =
  BEFORE_CHANGE:  'plumlinks:click'
  FETCH:          'plumlinks:request-start'
  RECEIVE:        'plumlinks:request-end'
  LOAD:           'plumlinks:load'
  RESTORE:        'plumlinks:restore'

progressBar = null
controller = new Controller

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

initializePlumlinks = ->
  controller.rememberCurrentUrlAndState()
  ProgressBarAPI.enable()

  document.addEventListener 'click', Click.installHandlerLast, true
  window.addEventListener 'hashchange', controller.rememberCurrentUrlAndState, false
  window.addEventListener 'popstate', controller.onHistoryChange, false

browserSupportsCustomEvents =
  document.addEventListener and document.createEvent

if Utils.browserSupportsPlumlinks()
  visit = controller.fetch
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
  replace: controller.replace,
  cache: controller.cache,
  pagesCached: controller.pagesCached,
  enableTransitionCache: controller.enableTransitionCache,
  disableRequestCaching: controller.disableRequestCaching,
  ProgressBar: ProgressBarAPI,
  allowLinkExtensions: Link.allowExtensions,
  supported: Utils.browserSupportsPlumlinks(),
  EVENTS: Utils.clone(EVENTS)
}
