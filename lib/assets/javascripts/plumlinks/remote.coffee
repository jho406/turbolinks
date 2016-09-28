class window.Remote
  constructor: (target, opts={})->
    @target = target
    @payload = ''

    if target.tagName == 'A'
      @contentType = "text/plain; charset=UTF-8"
      @httpRequestType = @getTGAttribute(target, 'plumlinks-remote')
      @httpRequestType ?= ''
      @httpRequestType = @httpRequestType.toUpperCase()

      if @httpRequestType.toUpperCase() not in ['GET', 'PUT', 'POST', 'DELETE']
         @httpRequestType = 'GET'

    if target.tagName == 'FORM'
      @httpRequestType = target.getAttribute('method') || @getTGAttribute(target, 'plumlinks-remote')
      @httpRequestType ?= ''
      @httpRequestType = @httpRequestType.toUpperCase()

      if @httpRequestType.toUpperCase() not in ['GET', 'PUT', 'POST', 'DELETE']
         @httpRequestType = 'POST'

      @payload = @nativeEncodeForm(target)


    @isAsync =  @getTGAttribute(target, 'plumlinks-remote-async') || false

    @httpUrl = target.getAttribute('href') || target.getAttribute('action')
    @actualRequestType = if @httpRequestType?.toLowerCase() == 'get' then 'GET' else 'POST'

    if @payload not instanceof FormData
      if @payload.indexOf("_method") == -1 && @httpRequestType && @actualRequestType != 'GET'
        @contentType = "application/x-www-form-urlencoded; charset=UTF-8"
        @payload = @formAppend(@payload, "_method", @httpRequestType)
    else
      if '_method' not in Array.from(@payload.keys()) && @httpRequestType && @actualRequestType != 'GET'
        @payload = @formAppend(@payload, "_method", @httpRequestType)

  isValid: =>
   @isValidLink() || @isValidForm()

  isValidLink: =>
    if @target.tagName != 'A'
      return false

    @hasTGAttribute(@target, 'plumlinks-remote')

  isValidForm: =>
    if @target.tagName != 'FORM'
      return false
    @hasTGAttribute(@target, 'plumlinks-remote') &&
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


  hasTGAttribute: (node, attr) ->
    tgAttr = @tgAttribute(attr)
    node.getAttribute(tgAttr)? || node.getAttribute(attr)?
