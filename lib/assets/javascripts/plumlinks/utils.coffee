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

browserSupportsPlumlinks = -> browserSupportsPushState and !browserIsBuggy and requestMethodIsSafe

intersection = (a, b) ->
  [a, b] = [b, a] if a.length > b.length
  value for value in a when value in b

@Utils = 
  reverseMerge: reverseMerge
  merge: merge
  clone: clone
  withDefaults: withDefaults
  browserSupportsPlumlinks: browserSupportsPlumlinks
  intersection: intersection


