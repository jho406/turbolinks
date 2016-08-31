QUnit.module "Navigation"

testWithSession = (desc, callback) ->
  session = {}
  QUnit.test desc, (assert)->
    session.iframe = document.createElement('iframe')
    session.iframe.setAttribute('scrolling', 'yes')
    session.iframe.setAttribute('style', 'visibility: hidden;')
    session.iframe.setAttribute('src', "fixtures/session.html")
    document.body.appendChild(session.iframe)
    stop()

    session.iframe.onload = =>
      session.iframe.onload = null
      session.window = session.iframe.contentWindow
      session.document = session.window.document
      session.Plumlinks = session.window.Plumlinks
      session.location = session.window.location
      session.history = session.window.history
      session.Plumlinks.disableRequestCaching()
      session.$ = (selector) => session.document.querySelector(selector)

      start()
      callback(session, assert)
      document.body.removeChild(session.iframe)


testWithSession "hello test", ( session, assert ) ->
  {document, history, location, $} = session

  response = '''
    (function() {
      return {
        data: { heading: 'Some heading 2' },
        title: 'title',
        csrf_token: 'token',
        assets: ['application-123.js', 'application-123.js']
      };
    })();
  '''

  xhr = sinon.useFakeXMLHttpRequest()
  session.window.XMLHttpRequest = xhr
  requests = []
  xhr.onCreate = (xhr) ->
    requests.push(xhr)

  done = assert.async()
  plumlinksClickFired = requestFinished = requestStared = false
  document.addEventListener 'plumlinks:click', =>
    assert.equal $('meta[name="csrf-token"]').getAttribute('content'), 'token'
    plumlinksClickFired = true

  document.addEventListener 'plumlinks:request-start', =>
    requestStared = true

  document.addEventListener 'plumlinks:request-end', =>
    state = plumlinks: true, url: "#{location.protocol}//#{location.host}/fixtures/session.html"
    assert.propEqual history.state, state
    assert.ok plumlinksClickFired
    assert.ok requestStared
    requestFinished = true

  document.addEventListener 'plumlinks:load', (event) =>
    assert.ok requestFinished
    assert.propEqual event.data.data, { heading: "Some heading 2" }
    state = plumlinks: true, url: "#{location.protocol}//#{location.host}/fixtures/next"
    assert.propEqual history.state, state
    assert.equal location.href, state.url
    assert.equal $('meta[name="csrf-token"]').getAttribute('content'), 'token'
    done()

  session.Plumlinks.visit('next')
  requests[0].respond(200, { "Content-Type": "application/javascript" }, response)
