class window.Remote
  constructor: (url, @delegate, @opts) ->
    @xhr = new XMLHttpRequest
    @xhr.open 'GET', url.formatForXHR(cache: @opts.cacheRequest), true
    @xhr.setRequestHeader 'Accept', 'text/javascript, application/x-javascript, application/javascript'
    @xhr.setRequestHeader 'X-XHR-Referer', @opts.referer
    @xhr.setRequestHeader 'X-Requested-With', 'XMLHttpRequest'
    @xhr.onload = @delegate.onload
    # @xhr.onprogress = @onProgress if progressBar and options.showProgressBar 
    @xhr.onloadend = @delegate.onloadend
    @xhr.onerror = @delegate.onerror

  send: () ->
    @xhr.send()

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

