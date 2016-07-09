PAGE_CACHE_SIZE = 20

class window.Controller
  constructor: ->
    @atomCache = {}
    @history = new Pistory(this)
    @transitionCacheEnabled = false
    @requestCachingEnabled = true

    @progressBar = null

    @referer = null
    @http = null

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

  remote: (options, form, target) =>
    data = @createPayload(form, options.actualRequestType, options.httpRequestType)
    @fetch(options.httpUrl, {payload: data})

  fetchReplacement: (url, options) =>
    options.cacheRequest ?= @requestCachingEnabled
    options.showProgressBar ?= true

    Utils.triggerEvent Plumlinks.EVENTS.FETCH, url: url.absolute
    @http?.abort()
    @http = new Remote(url, @referer, @, options)
    @http.send(options.payload)

  restore: (cachedPage, options = {}) =>
    @http?.abort()
    @history.changePage(cachedPage, options)

    @progressBar?.done()
    Utils.triggerEvent Plumlinks.EVENTS.RESTORE
    Utils.triggerEvent Plumlinks.EVENTS.LOAD, cachedPage

  replace: (nextPage, options = {}) =>
    Utils.withDefaults(nextPage, @history.currentBrowserState)
    @history.changePage(nextPage, options)
    Utils.triggerEvent Plumlinks.EVENTS.LOAD, @currentPage()

  crossOriginRedirect: =>
    redirect if (redirect = @http.xhr.getResponseHeader('Location'))? and (new ComponentUrl(redirect)).crossOrigin()

  rememberReferer: =>
    @referer = document.location.href

  pageChangePrevented: (url) =>
    !Utils.triggerEvent Plumlinks.EVENTS.BEFORE_CHANGE, url: url

  processResponse: ->
    if @http.hasValidResponse()
      return @http.content()

  cache: (key, value) =>
    return @atomCache[key] if value == null
    @atomCache[key] ||= value

  # Events
  onLoadEnd: => @http = null

  onLoad: (url, options) =>
    Utils.triggerEvent Plumlinks.EVENTS.RECEIVE, url: url.absolute

    if nextPage = @processResponse()
      @history.reflectNewUrl url
      @history.reflectRedirectedUrl(@http.xhr)
      Utils.withDefaults(nextPage, @history.currentBrowserState)
      @history.changePage(nextPage, options)
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

  # other
  #

  formAppend: (uriEncoded, key, value) ->
    uriEncoded += "&" if uriEncoded.length
    uriEncoded += "#{encodeURIComponent(key)}=#{encodeURIComponent(value)}"

  formDataAppend: (formData, input) ->
    if input.type == 'file'
      for file in input.files
        formData.append(input.name, file)
    else
      formData.append(input.name, input.value)
    formData

  nativeEncodeForm: (form) ->
    formData = new FormData
    @_iterateOverFormInputs form, (input) =>
      formData = @formDataAppend(formData, input)
    formData

  _iterateOverFormInputs: (form, callback) ->
    inputs = @_enabledInputs(form)
    for input in inputs
      inputEnabled = !input.disabled
      radioOrCheck = (input.type == 'checkbox' || input.type == 'radio')

      if inputEnabled && input.name
        if (radioOrCheck && input.checked) || !radioOrCheck
          callback(input)

  _enabledInputs: (form) ->
    selector = "input:not([type='reset']):not([type='button']):not([type='submit']):not([type='image']), select, textarea"
    inputs = Array::slice.call(form.querySelectorAll(selector))

    return inputs

  createPayload: (form, requestType, actualRequestType) ->
    if form
      if @useNativeEncoding || form.querySelectorAll("[type='file'][name]").length > 0
        formData = @nativeEncodeForm(form)
      else # for much smaller payloads
        formData = @uriEncodeForm(form)
    else
      formData = ''

    if formData not instanceof FormData
      formData = @formAppend(formData, "_method", requestType) if formData.indexOf("_method") == -1 && requestType && actualRequestType != 'GET'

  uriEncodeForm: (form) ->
    formData = ""
    @_iterateOverFormInputs form, (input) =>
      formData = @formAppend(formData, input.name, input.value)
    formData
