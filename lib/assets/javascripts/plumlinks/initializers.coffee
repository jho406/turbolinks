# tgAttribute = (attr) ->
#   tgAttr = if attr[0...3] == 'tg-'
#     "data-#{attr}"
#   else
#     "data-tg-#{attr}"
#
# getTGAttribute = (node, attr) ->
#   tgAttr = tgAttribute(attr)
#   node.getAttribute(tgAttr) || node.getAttribute(attr)
#
# removeTGAttribute = (node, attr) ->
#   tgAttr = tgAttribute(attr)
#   node.removeAttribute(tgAttr)
#   node.removeAttribute(attr)
#
# hasTGAttribute = (node, attr) ->
#   tgAttr = tgAttribute(attr)
#   node.getAttribute(tgAttr)? || node.getAttribute(attr)?
#
# querySelectorAllTGAttribute = (node, attr, value = null) ->
#   tgAttr = tgAttribute(attr)
#   if value
#     node.querySelectorAll("[#{tgAttr}=#{value}], [#{attr}=#{value}]")
#   else
#     node.querySelectorAll("[#{tgAttr}], [#{attr}]")
#
# hasClass = (node, search) ->
#   node.classList.contains(search)
#
# nodeIsDisabled = (node) ->
#    node.getAttribute('disabled') || hasClass(node, 'disabled')
#
# setupRemoteFromTarget = (target, httpRequestType, form = null) ->
#   httpUrl = target.getAttribute('href') || target.getAttribute('action')
#
#   throw new Error("Turbograft developer error: You did not provide a URL ('#{urlAttribute}' attribute) for data-tg-remote") unless httpUrl
#
#   options =
#     httpRequestType: httpRequestType
#     httpUrl: httpUrl
#
#   new TurboGraft.Remote(options, form, target)
#
# remoteMethodHandler = (ev) ->
#   target = ev.clickTarget
#   httpRequestType = getTGAttribute(target, 'tg-remote')
#
#   return unless httpRequestType
#   ev.preventDefault()
#
#   remote = setupRemoteFromTarget(target, httpRequestType)
#   remote.submit()
#   return
#
# remoteFormHandler = (ev) ->
#   target = ev.target
#   method = target.getAttribute('method')
#
#   return unless hasTGAttribute(target, 'tg-remote')
#   ev.preventDefault()
#
#   remote = setupRemoteFromTarget(target, method, target)
#   remote.submit()
#   return
#
# documentListenerForButtons = (eventType, handler, useCapture = false) ->
#   document.addEventListener eventType, (ev) ->
#     target = ev.target
#
#     while target != document && target?
#       if target.nodeName == "A" || target.nodeName == "BUTTON"
#         isNodeDisabled = nodeIsDisabled(target)
#         ev.preventDefault() if isNodeDisabled
#         unless isNodeDisabled
#           ev.clickTarget = target
#           handler(ev)
#           return
#
#       target = target.parentNode
#
# documentListenerForButtons('click', remoteMethodHandler, true)
#
# document.addEventListener "submit", (ev) ->
#   remoteFormHandler(ev)
