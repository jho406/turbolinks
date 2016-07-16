class window.Attribute
  constructor: (target, opts={})->
    @useNativeEncoding = opts.useNativeEncoding ? true
    @target = target
    @payload = null

    if target.tagName == 'A'
      @httpRequestType = @getTGAttribute(target, 'plumlinks-remote') || 'GET'
    if target.tagName == 'FORM'
      @httpRequestType = target.getAttribute('method') || @getTGAttribute(target, 'plumlinks-remote')

    @httpUrl = target.getAttribute('href') || target.getAttribute('action')
    @actualRequestType = if @httpRequestType?.toLowerCase() == 'get' then 'GET' else 'POST'

    @payload = @createPayload(target)
    # if @payload && !(@payload instanceof FormData)
    #   @httpUrl = @httpUrl + "?#{@payload}"
    #

  createPayload: (form) ->
    if form
      if @useNativeEncoding || form.querySelectorAll("[type='file'][name]").length > 0
        formData = @nativeEncodeForm(form)
      else # for much smaller payloads
        formData = @uriEncodeForm(form)
    else
      formData = ''

    if formData not instanceof FormData
      @contentType = "application/x-www-form-urlencoded; charset=UTF-8"
      formData = @formAppend(formData, "_method", @httpRequestType) if formData.indexOf("_method") == -1 && @httpRequestType && @actualRequestType != 'GET'

    formData

  formAppend: (uriEncoded, key, value) ->
    uriEncoded += "&" if uriEncoded.length
    uriEncoded += "#{encodeURIComponent(key)}=#{encodeURIComponent(value)}"

  uriEncodeForm: (form) ->
    formData = ""
    @_iterateOverFormInputs form, (input) =>
      formData = @formAppend(formData, input.name, input.value)
    formData

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
    disabledNodes = Array::slice.call(@querySelectorAllTGAttribute(form, 'plumlinks-remote-noserialize'))

    return inputs unless disabledNodes.length

    disabledInputs = disabledNodes
    for node in disabledNodes
      disabledInputs = disabledInputs.concat(Array::slice.call(node.querySelectorAll(selector)))

    enabledInputs = []
    for input in inputs when disabledInputs.indexOf(input) < 0
      enabledInputs.push(input)
    enabledInputs

  tgAttribute: (attr) ->
    tgAttr = if attr[0...10] == 'plumlinks-'
      "data-#{attr}"
    else
      "data-plumlinks-#{attr}"

  getTGAttribute: (node, attr) ->
    tgAttr = @tgAttribute(attr)
    node.getAttribute(tgAttr) || node.getAttribute(attr)

  querySelectorAllTGAttribute: (node, attr, value = null) ->
    tgAttr = @tgAttribute(attr)
    if value
      node.querySelectorAll("[#{tgAttr}=#{value}], [#{attr}=#{value}]")
    else
      node.querySelectorAll("[#{tgAttr}], [#{attr}]")
