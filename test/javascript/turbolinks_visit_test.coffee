assert = chai.assert

suite 'Turbolinks.visit()', ->
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
      @Turbolinks = @window.Turbolinks
      @location = @window.location
      @history = @window.history
      @Turbolinks.disableRequestCaching()
      @$ = (selector) => @document.querySelector(selector)
      done()

  teardown ->
    document.body.removeChild(@iframe)

  test "successful", (done) ->
    turbolinksClickFired = requestFinished = requestStared = false
    @document.addEventListener 'turbolinks:click', =>
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token'
      turbolinksClickFired = true
    @document.addEventListener 'turbolinks:request-start', =>
      requestStared = true
    @document.addEventListener 'turbolinks:request-end', =>
      state = turbolinks: true, url: "#{location.protocol}//#{location.host}/javascript/iframe"
      assert.deepEqual @history.state, state
      assert.ok turbolinksClickFired
      assert.ok requestStared
      requestFinished = true
    @document.addEventListener 'turbolinks:load', (event) =>
      assert.ok requestFinished
      assert.deepEqual event.data.data, { heading: "Some heading 2" }
      state = turbolinks: true, url: "#{location.protocol}//#{location.host}/javascript/iframe2"
      assert.deepEqual @history.state, state
      assert.equal @location.href, state.url
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token2'
      done()

    @Turbolinks.visit('iframe2')

  test "asset refresh", (done) ->
    @window.addEventListener 'unload', =>
      done()
    @Turbolinks.visit('iframe3')

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
    @Turbolinks.visit('/404')

  test "without transition cache", (done) ->
    load = 0
    restoreCalled = false
    @document.addEventListener 'turbolinks:load', =>
      load += 1
      if load is 1
        assert.equal @document.title, 'title 2'
        setTimeout (=> @Turbolinks.visit('iframe')), 0
      else if load is 2
        assert.notOk restoreCalled
        assert.equal @document.title, 'title'
        state = turbolinks: true, url: "#{location.protocol}//#{location.host}/javascript/iframe"
        assert.deepEqual @history.state, state
        done()
    @document.addEventListener 'turbolinks:restore', =>
      restoreCalled = true
    @Turbolinks.visit('iframe2')

  test "with transition cache", (done) ->
    load = 0
    restoreCalled = false
    @document.addEventListener 'turbolinks:load', (event) =>
      load += 1
      if load is 1
        assert.deepEqual event.data.data, { heading: "Some heading 2" }
        assert.equal @document.title, 'title 2'
        setTimeout (=> @Turbolinks.visit('iframe')), 0
      else if load is 2
        assert.ok restoreCalled
        assert.equal @document.title, 'title'
        state = turbolinks: true, url: "#{location.protocol}//#{location.host}/javascript/iframe"
        assert.deepEqual @history.state, state
        assert.equal @history.length, @historyLengthOnRestore
        done()
    @document.addEventListener 'turbolinks:restore', =>
      assert.equal load, 1
      assert.equal @document.title, 'title'
      assert.equal @window.location.pathname.substr(-6), 'iframe'
      @historyLengthOnRestore = @history.length
      restoreCalled = true

    @Turbolinks.enableTransitionCache()
    @Turbolinks.visit('iframe2')

  test "with same URL, skips transition cache", (done) ->
    restoreCalled = false
    @document.addEventListener 'turbolinks:restore', =>
      restoreCalled = true
    @document.addEventListener 'turbolinks:load', =>
      assert.notOk restoreCalled
      done()
    @Turbolinks.enableTransitionCache()
    @Turbolinks.visit('iframe')

  test "history.back() cache hit", (done) ->
    change = 0
    fetchCalled = false
    @document.addEventListener 'turbolinks:load', =>
      change += 1
      if change is 1
        @document.addEventListener 'turbolinks:request-start', -> fetchCalled = true
        assert.equal @document.title, 'title 2'
        setTimeout =>
          @history.back()
        , 0
      else if change is 2
        assert.notOk fetchCalled
        assert.equal @document.title, 'title'
        done()
    @Turbolinks.visit('iframe2')

  test "history.back() cache miss", (done) ->
    change = 0
    @document.addEventListener 'turbolinks:load', =>
      change += 1
      if change is 1
        assert.equal @document.title, 'title 2'
        setTimeout =>
          @history.back()
        , 0
      else if change is 2
        assert.equal @document.title, 'title'
        done()
    @Turbolinks.pagesCached(0)
    @Turbolinks.visit('iframe2')

  test "with different-origin URL, forces a normal redirection", (done) ->
    @window.addEventListener 'unload', ->
      done()
    @Turbolinks.visit("http://example.com")

  test "calling preventDefault on the before-change event cancels the visit", (done) ->
    @document.addEventListener 'turbolinks:click', (event) ->
      event.preventDefault()
      setTimeout (-> done?()), 0
    @document.addEventListener 'turbolinks:request-start', =>
      done new Error("visit wasn't cancelled")
      done = null
    @Turbolinks.visit('iframe2')

  test "doesn't pushState when URL is the same", (done) ->
    # Get rid of history.back() sideeffect
    @history.pushState({}, "", "iframe");

    load = 0
    @document.addEventListener 'turbolinks:load', =>
      load += 1
      if load is 1
        assert.equal @history.length, @originalHistoryLength
        setTimeout (=> @Turbolinks.visit('iframe#test')), 0
      else if load is 2
        setTimeout (=>
          assert.equal @history.length, @originalHistoryLength + 1
          done()
        ), 0
    @originalHistoryLength = @history.length
    @Turbolinks.visit('iframe')

  test "with #anchor and history.back()", (done) ->
    hashchange = 0
    load = 0

    @window.addEventListener 'hashchange', =>
      hashchange += 1
    @document.addEventListener 'turbolinks:load', =>
      load += 1
      if load is 1
        assert.equal hashchange, 1
        setTimeout (=> @history.back()), 0
    @document.addEventListener 'turbolinks:restore', =>
      assert.equal hashchange, 1
      done()
    @location.href = "#{@location.href}#change"
    setTimeout (=> @Turbolinks.visit('iframe2#permanent')), 0

  # Temporary until mocha fixes skip() in async tests or PhantomJS fixes scrolling inside iframes.
  return if navigator.userAgent.indexOf('PhantomJS') != -1

  test "scrolls to target or top by default", (done) ->
    @window.scrollTo(42, 42)
    assert.closeTo @window.pageXOffset, 42, 1
    assert.closeTo @window.pageYOffset, 42, 1
    load = 0
    @document.addEventListener 'turbolinks:load', =>
      load += 1
      if load is 1
        assert.closeTo @window.pageYOffset, @$('#change').offsetTop, 100
        setTimeout (=> @Turbolinks.visit('iframe', scroll: null)), 0
      else if load is 2
        assert.equal @window.pageXOffset, 0
        assert.equal @window.pageYOffset, 0
        done()
    @Turbolinks.visit('iframe2#change', scroll: undefined)

  test "restores scroll position on history.back() cache hit", (done) ->
    load = 0
    @document.addEventListener 'turbolinks:load', =>
      load += 1
      if load is 1
        @window.scrollTo(100, 100)
        assert.closeTo @window.pageXOffset, 100, 1
        setTimeout (=> @history.back()), 0
    @document.addEventListener 'turbolinks:restore', =>
      assert.closeTo @window.pageXOffset, 42, 1
      assert.closeTo @window.pageYOffset, 42, 1
      done()
    @window.scrollTo(42, 42)
    @Turbolinks.visit('iframe2')

  test "doesn't restore scroll position on history.back() cache miss", (done) ->
    load = 0
    @document.addEventListener 'turbolinks:load', =>
      load += 1
      assert.equal @window.pageXOffset, 0
      assert.equal @window.pageYOffset, 0
      if load is 1
        setTimeout (=> @history.back()), 0
      else if load is 2
        done()
    @window.scrollTo(42, 42)
    @Turbolinks.pagesCached(0)
    @Turbolinks.visit('iframe2')

  test "scrolls to top on transition cache hit", (done) ->
    load = 0
    restoreCalled = false
    @document.addEventListener 'turbolinks:load', =>
      load += 1
      if load is 1
        @window.scrollTo(8, 8)
        setTimeout (=> @Turbolinks.visit('iframe')), 0
      else if load is 2
        assert.ok restoreCalled
        assert.closeTo @window.pageXOffset, 16, 1
        assert.closeTo @window.pageYOffset, 16, 1
        done()
    @document.addEventListener 'turbolinks:restore', =>
      assert.equal @window.pageXOffset, 0
      assert.equal @window.pageYOffset, 0
      @window.scrollTo(16, 16)
      restoreCalled = true
    @window.scrollTo(4, 4)
    @Turbolinks.enableTransitionCache()
    @Turbolinks.visit('iframe2')

  test "doesn't scroll to top with scroll: false", (done) ->
    @window.scrollTo(42, 42)
    @document.addEventListener 'turbolinks:load', =>
      assert.closeTo @window.pageXOffset, 42, 1
      assert.closeTo @window.pageYOffset, 42, 1
      done()
    @Turbolinks.visit('iframe2', scroll: false)

  test "js responses with Turbolinks.cache caches correctly", (done) ->
    @window.addEventListener 'turbolinks:load', (event) =>
      assert.equal(event.data.data.footer, 'legal footer')
      assert.equal(@Turbolinks.cache('cachekey'), 'legal footer')
      done()
    @Turbolinks.visit('iframe4')
