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
  setDelay: (value) -> progressBar.setDelay(value)
  start: (options) -> ProgressBarAPI.enable().start(options)
  advanceTo: (value) -> progressBar?.advanceTo(value)
  done: -> progressBar?.done()

initializePlumlinks = ->
  ProgressBarAPI.enable()
  controller.progressBar = progressBar

  window.addEventListener 'hashchange', controller.history.rememberCurrentUrlAndState, false
  window.addEventListener 'popstate', controller.history.onHistoryChange, false

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
tgAttribute = (attr) ->
  tgAttr = if attr[0...10] == 'plumlinks-'
    "data-#{attr}"
  else
    "data-plumlinks-#{attr}"

hasTGAttribute = (node, attr) ->
  tgAttr = tgAttribute(attr)
  node.getAttribute(tgAttr)? || node.getAttribute(attr)?

hasClass = (node, search) ->
  node.classList.contains(search)

nodeIsDisabled = (node) ->
   node.getAttribute('disabled') || hasClass(node, 'disabled')

setupRemoteFromTarget = (target) ->
  dataAttr = new Remote(target)

  if dataAttr.isValid()
    url = dataAttr.url
    method = dataAttr.actualRequestType
    payload = dataAttr.payload
    controller.remote(url, method, payload)
  else
    throw new Error(
      "Turbograft developer error: The element may be missing a method or action"
    )

remoteMethodHandler = (ev) ->
  target = ev.clickTarget
  return unless hasTGAttribute(target, 'plumlinks-remote')

  ev.preventDefault()

  setupRemoteFromTarget(target)
  return

remoteFormHandler = (ev) ->
  target = ev.target
  return unless hasTGAttribute(target, 'plumlinks-remote')

  ev.preventDefault()

  setupRemoteFromTarget(target)
  return

documentListenerForButtons = (eventType, handler, useCapture = false) ->
  document.addEventListener eventType, (ev) ->
    target = ev.target
    while target != document && target?
      if target.nodeName == "A" || target.nodeName == "BUTTON"
        isNodeDisabled = nodeIsDisabled(target)
        ev.preventDefault() if isNodeDisabled
        unless isNodeDisabled
          ev.clickTarget = target
          handler(ev)
          return

      target = target.parentNode

documentListenerForButtons('click', remoteMethodHandler, true)

document.addEventListener "submit", (ev) ->
  remoteFormHandler(ev)
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
  pagesCached: controller.history.pagesCached,
  enableTransitionCache: controller.enableTransitionCache,
  disableRequestCaching: controller.disableRequestCaching,
  ProgressBar: ProgressBarAPI,
  allowLinkExtensions: Link.allowExtensions,
  supported: Utils.browserSupportsPlumlinks(),
  EVENTS: Utils.clone(EVENTS)
}
