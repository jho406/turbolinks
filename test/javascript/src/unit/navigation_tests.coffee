QUnit.module "Navigation"

testWithSession "a successful visit", (assert) ->
  done = assert.async()

  bensonhurstClickFired = requestFinished = requestStared = false
  @document.addEventListener 'bensonhurst:click', =>
    assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token'
    bensonhurstClickFired = true

  @document.addEventListener 'bensonhurst:request-start', =>
    requestStared = true

  @document.addEventListener 'bensonhurst:request-end', =>
    state = bensonhurst: true, url: "#{location.protocol}//#{location.host}/fixtures/session"
    assert.propEqual @history.state, state
    assert.ok bensonhurstClickFired
    assert.ok requestStared
    requestFinished = true

  @document.addEventListener 'bensonhurst:load', (event) =>
    assert.ok requestFinished
    assert.propEqual event.data.data, { heading: "Some heading 2" }
    state = bensonhurst: true, url: "#{location.protocol}//#{location.host}/fixtures/success"
    assert.propEqual @history.state, state
    assert.equal @location.href, state.url
    assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token'
    done()

  @Bensonhurst.visit('success')

testWithSession "asset refresh", (assert) ->
  done = assert.async()
  @window.addEventListener 'unload', =>
    assert.ok true
    done()
  @Bensonhurst.visit('success_with_new_assets')

testWithSession "error fallback", (assert) ->
  done = assert.async()

  unloadFired = false
  @window.addEventListener 'unload', =>
    unloadFired = true
    setTimeout =>
      try
        assert.equal @window.location.href, "#{@window.location.protocol}//#{@window.location.host}/does_not_exist"
      catch e
        throw e unless /denied/.test(e.message) # IE
      done()
    , 0
  @Bensonhurst.visit('/does_not_exist')


testWithSession "with different-origin URL, forces a normal redirection", (assert) ->
  done = assert.async()
  @window.addEventListener 'unload', =>
    assert.ok true
    done()
  @Bensonhurst.visit("http://example.com")

testWithSession "calling preventDefault on the before-change event cancels the visit", (assert) ->
  done = assert.async()
  @document.addEventListener 'bensonhurst:click', (event) ->
    event.preventDefault()
    assert.ok true
    setTimeout (-> done?()), 0
  @document.addEventListener 'bensonhurst:request-start', =>
    done new Error("visit wasn't cancelled")
    done = null
  @Bensonhurst.visit('success')

testWithSession "doesn't pushState when URL is the same", (assert) ->
  done = assert.async()
  # Get rid of history.back() sideeffect
  @history.pushState({}, "", "session");

  load = 0
  @document.addEventListener 'bensonhurst:load', =>
    load += 1
    if load is 1
      assert.equal @history.length, @originalHistoryLength
      setTimeout (=> @Bensonhurst.visit('session#test')), 0
    else if load is 2
      setTimeout (=>
        assert.equal @history.length, @originalHistoryLength + 1
        done()
      ), 0
  @originalHistoryLength = @history.length
  @Bensonhurst.visit('session')

testWithSession "with #anchor and history.back()", (assert) ->
  done = assert.async()
  hashchange = 0
  load = 0

  @window.addEventListener 'hashchange', =>
    hashchange += 1
  @document.addEventListener 'bensonhurst:load', =>
    load += 1
    if load is 1
      assert.equal hashchange, 1
      setTimeout (=> @history.back()), 0
  @document.addEventListener 'bensonhurst:restore', =>
    assert.equal hashchange, 1
    done()
  @location.href = "#{@location.href}#change"
  setTimeout (=> @Bensonhurst.visit('success#permanent')), 0

testWithSession "js responses with Bensonhurst.cache caches correctly", (assert) ->
  done = assert.async()
  @window.addEventListener 'bensonhurst:load', (event) =>
    assert.equal(event.data.data.footer, 'some cached content')
    assert.equal(@Bensonhurst.cache('cachekey'), 'some cached content')
    done()
  @Bensonhurst.visit('success_with_russian_doll')

testWithSession "the async option allows request to run seperate from the main XHR", (assert) ->
  done = assert.async()
  @document.addEventListener 'bensonhurst:load', =>
    console.log('hi')
    assert.equal @Bensonhurst.controller.http, null
    done()

  @Bensonhurst.visit('session', isAsync: true)

testWithSession "the async options will use a parallel queue that onloads in order", (assert) ->
  done = assert.async()

  response = '''
    (function() {
      return {
        data: { heading: 'Some heading' },
        title: 'title',
        csrf_token: 'token',
        assets: ['application-123.js', 'application-123.js']
      };
    })();
  '''
  xhr = sinon.useFakeXMLHttpRequest()
  @window.XMLHttpRequest = xhr
  requests = []
  xhr.onCreate = (xhr) ->
    requests.push(xhr)

  @Bensonhurst.visit('/', isAsync: true)
  @Bensonhurst.visit('/', isAsync: true)
  assert.equal @Bensonhurst.controller.pq.dll.length, 2
  requests[1].respond(200, { "Content-Type": "application/javascript" }, response)

  assert.equal @Bensonhurst.controller.pq.dll.length, 2
  requests[0].respond(200, { "Content-Type": "application/javascript" }, response)

  assert.equal @Bensonhurst.controller.pq.dll.length, 0
  done()

testWithSession "the async options will use a parallel queue that onloads in order 2", (assert) ->
  done = assert.async()
  response = '''
    (function() {
      return {
        data: { heading: 'Some heading' },
        title: 'title',
        csrf_token: 'token',
        assets: ['application-123.js', 'application-123.js']
      };
    })();
  '''
  xhr = sinon.useFakeXMLHttpRequest()
  @window.XMLHttpRequest = xhr
  requests = []
  xhr.onCreate = (xhr) ->
    requests.push(xhr)

  @Bensonhurst.visit('/', isAsync: true)
  @Bensonhurst.visit('/', isAsync: true)
  assert.equal @Bensonhurst.controller.pq.dll.length, 2
  requests[0].respond(200, { "Content-Type": "application/javascript" }, response)

  assert.equal @Bensonhurst.controller.pq.dll.length, 1
  requests[1].respond(200, { "Content-Type": "application/javascript" }, response)

  assert.equal @Bensonhurst.controller.pq.dll.length, 0
  done()




