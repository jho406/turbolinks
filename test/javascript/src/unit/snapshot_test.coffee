QUnit.module "Snapshot"

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
  restoreCalled = false

  @document.addEventListener 'plumlinks:restore', =>
    restoreCalled = true

  @document.addEventListener 'plumlinks:load', =>
    change += 1
    if change is 1
      assert.equal @document.title, 'title 2'
      setTimeout =>
        @history.back()
      , 0
    else if change is 2
      assert.equal @document.title, 'title'
      assert.equal restoreCalled, false
      done()
  @Plumlinks.pagesCached(0)
  @Plumlinks.visit('success')
