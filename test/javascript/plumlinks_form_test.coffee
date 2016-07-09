assert = chai.assert

suite 'Plumlinks.visit()', ->
  setup (done) ->
    @iframe = document.createElement('iframe')
    @iframe.setAttribute('scrolling', 'yes')
    @iframe.setAttribute('style', 'visibility: hidden;')
    @iframe.setAttribute('src', 'iframe_with_form')
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
      state = plumlinks: true, url: "#{location.protocol}//#{location.host}/javascript/iframe_with_link"
      assert.deepEqual @history.state, state
      assert.ok plumlinksClickFired
      assert.ok requestStared
      requestFinished = true
    @document.addEventListener 'plumlinks:load', (event) =>
      assert.ok requestFinished
      assert.deepEqual event.data.data, { heading: "Some heading" }
      state = plumlinks: true, url: "#{location.protocol}//#{location.host}/javascript/iframe_with_link"
      assert.deepEqual @history.state, state
      assert.equal @location.href, state.url
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token'
      done()
    @document.getElementById('form-submit').click()

