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


