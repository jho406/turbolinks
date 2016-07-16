# move this back to controller
# then put all the stuff dealing with dom extraction "others" to 
# remote which replaces link
class window.Remote
  constructor: (url, referer, @delegate, @opts) ->
    requestMethod = @opts.requestMethod || 'GET'
    @xhr = new XMLHttpRequest
    @xhr.open requestMethod, url.formatForXHR(cache: @opts.cacheRequest), true
    @xhr.setRequestHeader 'Accept', 'text/javascript, application/x-javascript, application/javascript'
    @xhr.setRequestHeader 'X-XHR-Referer', @opts.referer
    @xhr.setRequestHeader 'X-Requested-With', 'XMLHttpRequest'
    @xhr.onload = => @delegate.onLoad(url, @opts)
    # @xhr.onprogress = @onProgress if progressBar and options.showProgressBar 
    @xhr.onloadend = @delegate.onLoadEnd
    @xhr.onerror = @delegate.onError

  send: () ->
    @xhr.send.apply(@xhr, arguments)

  abort: () ->
    @xhr.abort()

  hasValidResponse: ->
    not @clientOrServerError() and @validContent() and not @downloadingFile()

  content: ->
    new Function("'use strict'; return " + @xhr.responseText )();

  clientOrServerError: ->
    400 <= @xhr.status < 600

  validContent: ->
    (contentType = @xhr.getResponseHeader('Content-Type'))? and
      contentType.match /^(?:text\/javascript|application\/x-javascript|application\/javascript)(?:;|$)/

  downloadingFile: ->
    (disposition = @xhr.getResponseHeader('Content-Disposition'))? and
      disposition.match /^attachment/

