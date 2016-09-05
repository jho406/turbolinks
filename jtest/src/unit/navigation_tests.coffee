QUnit.module "Navigation"

testWithSession "a successful visit", (assert) ->
  done = assert.async()

  plumlinksClickFired = requestFinished = requestStared = false
  @document.addEventListener 'plumlinks:click', =>
    assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token'
    plumlinksClickFired = true

  @document.addEventListener 'plumlinks:request-start', =>
    requestStared = true

  @document.addEventListener 'plumlinks:request-end', =>
    state = plumlinks: true, url: "#{location.protocol}//#{location.host}/fixtures/session"
    assert.propEqual @history.state, state
    assert.ok plumlinksClickFired
    assert.ok requestStared
    requestFinished = true

  @document.addEventListener 'plumlinks:load', (event) =>
    assert.ok requestFinished
    assert.propEqual event.data.data, { heading: "Some heading 2" }
    state = plumlinks: true, url: "#{location.protocol}//#{location.host}/fixtures/success"
    assert.propEqual @history.state, state
    assert.equal @location.href, state.url
    assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token'
    done()

  @Plumlinks.visit('success')

testWithSession "asset refresh", (assert) ->
  done = assert.async()
  @window.addEventListener 'unload', =>
    assert.ok true
    done()
  @Plumlinks.visit('success_with_new_assets')

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
  @Plumlinks.visit('/does_not_exist')

testWithSession "without transition cache", (assert) ->
  done = assert.async()
  load = 0
  restoreCalled = false
  @document.addEventListener 'plumlinks:load', =>
    load += 1
    console.log(load)
    if load is 1
      assert.equal @document.title, 'title 2'
      setTimeout (=>
        console.log('here')
        @Plumlinks.visit('session')), 0
    else if load is 2
      assert.notOk restoreCalled
      assert.equal @document.title, 'title'
      location = @window.location
      state = plumlinks: true, url: "#{location.protocol}//#{location.host}/fixtures/session"
      assert.propEqual @history.state, state
      done()
  @document.addEventListener 'plumlinks:restore', =>
    restoreCalled = true
  @Plumlinks.visit('success')

testWithSession "with same URL, skips transition cache", (assert) ->
  done = assert.async()
  restoreCalled = false
  @document.addEventListener 'plumlinks:restore', =>
    restoreCalled = true
  @document.addEventListener 'plumlinks:load', =>
    assert.notOk restoreCalled
    done()
  @Plumlinks.enableTransitionCache()
  @Plumlinks.visit('session')

testWithSession "history.back() cache hit", (assert) ->
  done = assert.async()
  change = 0
  fetchCalled = false
  @document.addEventListener 'plumlinks:load', =>
    change += 1
    if change is 1
      @document.addEventListener 'plumlinks:request-start', -> fetchCalled = true
      assert.equal @document.title, 'title 2'
      setTimeout =>
        @history.back()
      , 0
    else if change is 2
      assert.notOk fetchCalled
      assert.equal @document.title, 'title'
      done()
  @Plumlinks.visit('success')

testWithSession "history.back() cache miss", (assert) ->
  done = assert.async()
  change = 0
  @document.addEventListener 'plumlinks:load', =>
    change += 1
    if change is 1
      assert.equal @document.title, 'title 2'
      setTimeout =>
        @history.back()
      , 0
    else if change is 2
      assert.equal @document.title, 'title'
      done()
  @Plumlinks.pagesCached(0)
  @Plumlinks.visit('success')

testWithSession "with different-origin URL, forces a normal redirection", (assert) ->
  done = assert.async()
  @window.addEventListener 'unload', =>
    assert.ok true
    done()
  @Plumlinks.visit("http://example.com")

testWithSession "calling preventDefault on the before-change event cancels the visit", (assert) ->
  done = assert.async()
  @document.addEventListener 'plumlinks:click', (event) ->
    event.preventDefault()
    assert.ok true
    setTimeout (-> done?()), 0
  @document.addEventListener 'plumlinks:request-start', =>
    done new Error("visit wasn't cancelled")
    done = null
  @Plumlinks.visit('success')

testWithSession "doesn't pushState when URL is the same", (assert) ->
  done = assert.async()
  # Get rid of history.back() sideeffect
  @history.pushState({}, "", "session");

  load = 0
  @document.addEventListener 'plumlinks:load', =>
    load += 1
    if load is 1
      assert.equal @history.length, @originalHistoryLength
      setTimeout (=> @Plumlinks.visit('session#test')), 0
    else if load is 2
      setTimeout (=>
        assert.equal @history.length, @originalHistoryLength + 1
        done()
      ), 0
  @originalHistoryLength = @history.length
  @Plumlinks.visit('session')

testWithSession "with #anchor and history.back()", (assert) ->
  done = assert.async()
  hashchange = 0
  load = 0

  @window.addEventListener 'hashchange', =>
    hashchange += 1
  @document.addEventListener 'plumlinks:load', =>
    load += 1
    if load is 1
      assert.equal hashchange, 1
      setTimeout (=> @history.back()), 0
  @document.addEventListener 'plumlinks:restore', =>
    assert.equal hashchange, 1
    done()
  @location.href = "#{@location.href}#change"
  setTimeout (=> @Plumlinks.visit('success#permanent')), 0

testWithSession "js responses with Plumlinks.cache caches correctly", (assert) ->
  done = assert.async()
  @window.addEventListener 'plumlinks:load', (event) =>
    assert.equal(event.data.data.footer, 'some cached content')
    assert.equal(@Plumlinks.cache('cachekey'), 'some cached content')
    done()
  @Plumlinks.visit('success_with_russian_doll')

testWithSession "the async option allows request to run seperate from the main XHR", (assert) ->
  done = assert.async()
  @document.addEventListener 'plumlinks:load', =>
    console.log('hi')
    assert.equal @Plumlinks.controller.http, null
    done()

  @Plumlinks.visit('session', isAsync: true)

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

  @Plumlinks.visit('/', isAsync: true)
  @Plumlinks.visit('/', isAsync: true)
  assert.equal @Plumlinks.controller.pq.dll.length, 2
  requests[1].respond(200, { "Content-Type": "application/javascript" }, response)

  assert.equal @Plumlinks.controller.pq.dll.length, 2
  requests[0].respond(200, { "Content-Type": "application/javascript" }, response)

  assert.equal @Plumlinks.controller.pq.dll.length, 0
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

  @Plumlinks.visit('/', isAsync: true)
  @Plumlinks.visit('/', isAsync: true)
  assert.equal @Plumlinks.controller.pq.dll.length, 2
  requests[0].respond(200, { "Content-Type": "application/javascript" }, response)

  assert.equal @Plumlinks.controller.pq.dll.length, 1
  requests[1].respond(200, { "Content-Type": "application/javascript" }, response)

  assert.equal @Plumlinks.controller.pq.dll.length, 0
  done()




