reverseMerge = (dest, obj) ->
  for k, v of obj
    dest[k] = v if !dest.hasOwnProperty(k)
  dest

merge = (dest, obj) ->
  for k, v of obj
    dest[k] = v
  dest

clone = (original) ->
  return original if not original? or typeof original isnt 'object'
  copy = new original.constructor()
  copy[key] = clone value for key, value of original
  copy

withDefaults = (page, state) =>
    currentUrl = new ComponentUrl state.url

    reverseMerge page,
      url: currentUrl.relative
      cachedAt: new Date().getTime()
      assets: []
      data: {}
      title: ''
      positionY: 0
      positionX: 0
      csrf_token: null

browserIsBuggy = () ->
# Copied from https://github.com/Modernizr/Modernizr/blob/master/feature-detects/history.js
  ua = navigator.userAgent
  (ua.indexOf('Android 2.') != -1 or ua.indexOf('Android 4.0') != -1) and
    ua.indexOf('Mobile Safari') != -1 and
    ua.indexOf('Chrome') == -1 and
    ua.indexOf('Windows Phone') == -1

browserSupportsPushState = () ->
  window.history and 'pushState' of window.history and 'state' of window.history

popCookie = (name) ->
  value = document.cookie.match(new RegExp(name+"=(\\w+)"))?[1].toUpperCase() or ''
  document.cookie = name + '=; expires=Thu, 01-Jan-70 00:00:01 GMT; path=/'
  value

requestMethodIsSafe = -> popCookie('request_method') in ['GET','']

browserSupportsPlumlinks = ->
  browserSupportsPushState() and !browserIsBuggy() and requestMethodIsSafe()

intersection = (a, b) ->
  [a, b] = [b, a] if a.length > b.length
  value for value in a when value in b


triggerEvent = (name, data) =>
  event = document.createEvent 'Events'
  event.data = data if data
  event.initEvent name, true, true
  document.dispatchEvent event

documentListenerForLinks = (eventType, handler) ->
  document.addEventListener eventType, (ev) ->
    target = ev.target
    while target != document && target?
      if target.nodeName == "A"
        isNodeDisabled = target.getAttribute('disabled')
        ev.preventDefault() if target.getAttribute('disabled')
        unless isNodeDisabled
          handler(ev)
          return

      target = target.parentNode

isObject = (val) ->
  Object.prototype.toString.call(val) is '[object Object]'

isArray = (val) ->
  Object.prototype.toString.call(val) is '[object Array]'

cloneByKeypath = (path, leaf, obj, opts={}) ->
  if typeof path is "string"
    path = path.split('.')
    return cloneByKeypath(path, leaf, obj, opts)
  return obj unless obj?

  head = path[0]
  child = obj[head]
  remaining = path.slice(1)

  if path.length is 0
    if opts.append? and isArray(obj)
      copy = []
      for child in obj
        copy.push child

      copy.push leaf
      return copy
    else
      return leaf

  if isObject(obj)
    copy = {}
    found = false
    for key, value of obj
      if key is head
        node = cloneByKeypath(remaining, leaf, child, opts)
        found = true unless child is node
        copy[key] = node
      else
        copy[key] = value

    return if found then copy else obj

  else if isArray(obj)
    [attr, id] = head.split('=')
    id = parseInt(id) || 0
    copy = []
    found = false
    for child in obj
      if child[attr] == id
        node = cloneByKeypath(remaining, leaf, child, opts)
        found = true unless child is node
        copy.push node
      else
        copy.push child

    return if found then copy else obj
  else
    obj



@Utils =
  cloneByKeypath:cloneByKeypath
  documentListenerForLinks: documentListenerForLinks
  reverseMerge: reverseMerge
  merge: merge
  clone: clone
  withDefaults: withDefaults
  browserSupportsPlumlinks: browserSupportsPlumlinks
  intersection: intersection
  triggerEvent: triggerEvent


