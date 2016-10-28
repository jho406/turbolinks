#= export Bensonhurst
#= require_tree ./bensonhurst
#= require_self
#
EVENTS =
  BEFORE_CHANGE:  'bensonhurst:click'
  FETCH:          'bensonhurst:request-start'
  RECEIVE:        'bensonhurst:request-end'
  LOAD:           'bensonhurst:load'
  RESTORE:        'bensonhurst:restore'

controller = new Controller
progressBar = controller.progressBar

ProgressBarAPI =
  enable: ->
    progressBar.install()
  disable: ->
    progressBar.uninstall()
  setDelay: (value) -> progressBar.setDelay(value)
  start: (options) -> progressBar.start(options)
  advanceTo: (value) -> progressBar.advanceTo(value)
  done: -> progressBar.done()

remoteHandler = (ev) ->
  target = ev.target
  remote = new Remote(target)
  return unless remote.isValid()
  ev.preventDefault()

  controller.request remote.httpUrl,
    requestMethod: remote.actualRequestType
    payload: remote.payload
    contentType: remote.contentType
    silent: remote.silent

browserSupportsCustomEvents =
  document.addEventListener and document.createEvent

initializeBensonhurst = ->
  ProgressBarAPI.enable()
  window.addEventListener 'hashchange', controller.history.rememberCurrentUrlAndState, false
  window.addEventListener 'popstate', controller.history.onHistoryChange, false
  Utils.documentListenerForLinks 'click', remoteHandler
  document.addEventListener "submit", remoteHandler

if Utils.browserSupportsBensonhurst()
  visit = controller.request
  initializeBensonhurst()
else
  visit = (url = document.location.href) -> document.location.href = url

@Bensonhurst = {
  controller,
  updateContentByKeypath: controller.history.updateContentByKeypath,
  visit,
  replace: controller.replace,
  cache: controller.cache,
  pagesCached: controller.history.pagesCached,
  enableTransitionCache: controller.enableTransitionCache,
  disableRequestCaching: controller.disableRequestCaching,
  ProgressBar: ProgressBarAPI,
  supported: Utils.browserSupportsBensonhurst(),
  EVENTS: Utils.clone(EVENTS)
}