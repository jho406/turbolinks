#= require ./controller
#= require ./remote
#= require ./utils

EVENTS =
  BEFORE_CHANGE:  'bensonhurst:click'
  FETCH:          'bensonhurst:request-start'
  RECEIVE:        'bensonhurst:request-end'
  LOAD:           'bensonhurst:load'
  RESTORE:        'bensonhurst:restore'

controller = new Bensonhurst.Controller
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
  remote = new Bensonhurst.Remote(target)
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
  Bensonhurst.Utils.documentListenerForLinks 'click', remoteHandler
  document.addEventListener "submit", remoteHandler

if Bensonhurst.Utils.browserSupportsBensonhurst()
  visit = controller.request
  initializeBensonhurst()
else
  visit = (url = document.location.href) -> document.location.href = url

Bensonhurst.controller = controller
Bensonhurst.updateContentByKeypath = controller.history.updateContentByKeypath
Bensonhurst.visit = visit
Bensonhurst.replace = controller.replace
Bensonhurst.cache = controller.cache
Bensonhurst.pagesCached = controller.history.pagesCached
Bensonhurst.enableTransitionCache = controller.enableTransitionCache
Bensonhurst.disableRequestCaching = controller.disableRequestCaching
Bensonhurst.ProgressBar = ProgressBarAPI
Bensonhurst.supported = Bensonhurst.Utils.browserSupportsBensonhurst()
Bensonhurst.EVENTS = Bensonhurst.Utils.clone(EVENTS)

