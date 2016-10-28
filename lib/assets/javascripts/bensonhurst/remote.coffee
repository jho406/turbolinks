class window.Remote
  SUPPORTED_METHODS = ['GET', 'PUT', 'POST', 'DELETE', 'PATCH']
  FALLBACK_LINK_METHOD = 'GET'
  FALLBACK_FORM_METHOD = 'POST'

  constructor: (target, opts={})->
    @target = target
    @payload = ''
    @contentType = null
    @setRequestType(target)
    @isAsync =  @getBHAttribute(target, 'bh-remote-async') || false
    @httpUrl = target.getAttribute('href') || target.getAttribute('action')
    @silent = @getBHAttribute(target, 'bh-silent') || false
    @setPayload(target)

  setRequestType: (target)=>
    if target.tagName == 'A'
      @httpRequestType = @getBHAttribute(target, 'bh-remote')
      @httpRequestType ?= ''
      @httpRequestType = @httpRequestType.toUpperCase()

      if @httpRequestType not in SUPPORTED_METHODS
        @httpRequestType = FALLBACK_LINK_METHOD

    if target.tagName == 'FORM'
      formActionMethod = target.getAttribute('method')
      @httpRequestType = formActionMethod || @getBHAttribute(target, 'bh-remote')
      @httpRequestType ?= ''
      @httpRequestType = @httpRequestType.toUpperCase()

      if @httpRequestType not in SUPPORTED_METHODS
        @httpRequestType = FALLBACK_FORM_METHOD

    @actualRequestType = if @httpRequestType == 'GET' then 'GET' else 'POST'

  setPayload: (target)=>
    if target.tagName == 'FORM'
      @payload = @nativeEncodeForm(target)

    if @payload not instanceof FormData
      if @payload.indexOf("_method") == -1 && @httpRequestType && @actualRequestType != 'GET'
        @contentType = "application/x-www-form-urlencoded; charset=UTF-8"
        @payload = @formAppend(@payload, "_method", @httpRequestType)
    else
      if '_method' not in Array.from(@payload.keys()) && @httpRequestType not in ['GET', 'POST']
        @payload.append("_method", @httpRequestType)

  isValid: =>
    @isValidLink() || @isValidForm()

  isValidLink: =>
    if @target.tagName != 'A'
      return false

    @hasBHAttribute(@target, 'bh-remote')

  isValidForm: =>
    if @target.tagName != 'FORM'
      return false
    @hasBHAttribute(@target, 'bh-remote') &&
    @target.getAttribute('action')?

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
    disabledNodes = Array::slice.call(@querySelectorAllBHAttribute(form, 'bh-remote-noserialize'))

    return inputs unless disabledNodes.length

    disabledInputs = disabledNodes
    for node in disabledNodes
      disabledInputs = disabledInputs.concat(Array::slice.call(node.querySelectorAll(selector)))

    enabledInputs = []
    for input in inputs when disabledInputs.indexOf(input) < 0
      enabledInputs.push(input)
    enabledInputs

  bhAttribute: (attr) ->
    bhAttr = if attr[0...3] == 'bh-'
      "data-#{attr}"
    else
      "data-bh-#{attr}"

  getBHAttribute: (node, attr) ->
    bhAttr = @bhAttribute(attr)
    (node.getAttribute(bhAttr) || node.getAttribute(attr))

  querySelectorAllBHAttribute: (node, attr, value = null) ->
    bhAttr = @bhAttribute(attr)
    if value
      node.querySelectorAll("[#{bhAttr}=#{value}], [#{attr}=#{value}]")
    else
      node.querySelectorAll("[#{bhAttr}], [#{attr}]")

  hasBHAttribute: (node, attr) ->
    bhAttr = @bhAttribute(attr)
    node.getAttribute(bhAttr)? || node.getAttribute(attr)?