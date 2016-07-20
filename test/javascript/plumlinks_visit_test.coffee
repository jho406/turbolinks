assert = chai.assert

suite 'Plumlinks.visit()', ->
  setup (done) ->
    @iframe = document.createElement('iframe')
    @iframe.setAttribute('scrolling', 'yes')
    @iframe.setAttribute('style', 'visibility: hidden;')
    @iframe.setAttribute('src', 'iframe')
    document.body.appendChild(@iframe)
    @iframe.onload = =>
      @iframe.onload = null
      @window = @iframe.contentWindow
      @document = @window.document
      @Plumlinks = @window.Plumlinks
      @location = @window.location
      @history = @window.history
      @Plumlinks.disableRequestCaching()
      @$ = (selector) => @document.querySelector(selector)
      done()

  teardown ->
    document.body.removeChild(@iframe)

  test "successful", (done) ->
    plumlinksClickFired = requestFinished = requestStared = false
    @document.addEventListener 'plumlinks:click', =>
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token'
      plumlinksClickFired = true
    @document.addEventListener 'plumlinks:request-start', =>
      requestStared = true
    @document.addEventListener 'plumlinks:request-end', =>
      state = plumlinks: true, url: "#{location.protocol}//#{location.host}/javascript/iframe"
      assert.deepEqual @history.state, state
      assert.ok plumlinksClickFired
      assert.ok requestStared
      requestFinished = true
    @document.addEventListener 'plumlinks:load', (event) =>
      assert.ok requestFinished
      assert.deepEqual event.data.data, { heading: "Some heading 2" }
      state = plumlinks: true, url: "#{location.protocol}//#{location.host}/javascript/iframe2"
      assert.deepEqual @history.state, state
      assert.equal @location.href, state.url
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token2'
      done()

    @Plumlinks.visit('iframe2')

  test "asset refresh", (done) ->
    @window.addEventListener 'unload', =>
      done()
    @Plumlinks.visit('iframe3')

  test "error fallback", (done) ->
    unloadFired = false
    @window.addEventListener 'unload', =>
      unloadFired = true
      setTimeout =>
        try
          assert.equal @iframe.contentWindow.location.href, "#{location.protocol}//#{location.host}/404"
        catch e
          throw e unless /denied/.test(e.message) # IE
        done()
      , 0
    @Plumlinks.visit('/404')

  test "without transition cache", (done) ->
    load = 0
    restoreCalled = false
    @document.addEventListener 'plumlinks:load', =>
      load += 1
      if load is 1
        assert.equal @document.title, 'title 2'
        setTimeout (=> @Plumlinks.visit('iframe')), 0
      else if load is 2
        assert.notOk restoreCalled
        assert.equal @document.title, 'title'
        state = plumlinks: true, url: "#{location.protocol}//#{location.host}/javascript/iframe"
        assert.deepEqual @history.state, state
        done()
    @document.addEventListener 'plumlinks:restore', =>
      restoreCalled = true
    @Plumlinks.visit('iframe2')

  test "with transition cache", (done) ->
    load = 0
    restoreCalled = false
    @document.addEventListener 'plumlinks:load', (event) =>
      load += 1
      if load is 1
        assert.deepEqual event.data.data, { heading: "Some heading 2" }
        assert.equal @document.title, 'title 2'
        setTimeout (=> @Plumlinks.visit('iframe')), 0
      else if load is 2
        assert.ok restoreCalled
        assert.equal @document.title, 'title'
        state = plumlinks: true, url: "#{location.protocol}//#{location.host}/javascript/iframe"
        assert.deepEqual @history.state, state
        assert.equal @history.length, @historyLengthOnRestore
        done()
    @document.addEventListener 'plumlinks:restore', =>
      assert.equal load, 1
      assert.equal @document.title, 'title'
      assert.equal @window.location.pathname.substr(-6), 'iframe'
      @historyLengthOnRestore = @history.length
      restoreCalled = true

    @Plumlinks.enableTransitionCache()
    @Plumlinks.visit('iframe2')

  test "with same URL, skips transition cache", (done) ->
    restoreCalled = false
    @document.addEventListener 'plumlinks:restore', =>
      restoreCalled = true
    @document.addEventListener 'plumlinks:load', =>
      assert.notOk restoreCalled
      done()
    @Plumlinks.enableTransitionCache()
    @Plumlinks.visit('iframe')

  test "history.back() cache hit", (done) ->
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
    @Plumlinks.visit('iframe2')

  test "history.back() cache miss", (done) ->
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
    @Plumlinks.visit('iframe2')

  test "with different-origin URL, forces a normal redirection", (done) ->
    @window.addEventListener 'unload', ->
      done()
    @Plumlinks.visit("http://example.com")

  test "calling preventDefault on the before-change event cancels the visit", (done) ->
    @document.addEventListener 'plumlinks:click', (event) ->
      event.preventDefault()
      setTimeout (-> done?()), 0
    @document.addEventListener 'plumlinks:request-start', =>
      done new Error("visit wasn't cancelled")
      done = null
    @Plumlinks.visit('iframe2')

  test "doesn't pushState when URL is the same", (done) ->
    # Get rid of history.back() sideeffect
    @history.pushState({}, "", "iframe");

    load = 0
    @document.addEventListener 'plumlinks:load', =>
      load += 1
      if load is 1
        assert.equal @history.length, @originalHistoryLength
        setTimeout (=> @Plumlinks.visit('iframe#test')), 0
      else if load is 2
        setTimeout (=>
          assert.equal @history.length, @originalHistoryLength + 1
          done()
        ), 0
    @originalHistoryLength = @history.length
    @Plumlinks.visit('iframe')

  test "with #anchor and history.back()", (done) ->
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
    setTimeout (=> @Plumlinks.visit('iframe2#permanent')), 0

  # Temporary until mocha fixes skip() in async tests or PhantomJS fixes scrolling inside iframes.
  return if navigator.userAgent.indexOf('PhantomJS') != -1

  test "js responses with Plumlinks.cache caches correctly", (done) ->
    @window.addEventListener 'plumlinks:load', (event) =>
      assert.equal(event.data.data.footer, 'legal footer')
      assert.equal(@Plumlinks.cache('cachekey'), 'legal footer')
      done()
    @Plumlinks.visit('iframe4')

  test "the async option allows request to run seperate from the main XHR", (done) ->
    @document.addEventListener 'plumlinks:load', =>
      assert.equal @Plumlinks.controller.http, null
      done()

    @Plumlinks.visit('iframe2', isAsync: true)
