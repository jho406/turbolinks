assert = chai.assert

suite 'Plumlinks.cache()', ->
  setup (done) ->
    @iframe = document.createElement('iframe')
    @iframe.style.display = 'none'
    @iframe.setAttribute('src', 'iframe.html')
    document.body.appendChild(@iframe)
    @iframe.onload = =>
      @window = @iframe.contentWindow
      @document = @window.document
      @Plumlinks = @window.Plumlinks
      @$ = (selector) => @document.querySelector(selector)
      done()

  teardown ->
    document.body.removeChild(@iframe)

  test "cache can only be set the first time", (done) ->
    @Plumlinks.cache('cachekey','hit')
    assert.equal(@Plumlinks.cache('cachekey'), 'hit')

    @Plumlinks.cache('cachekey','miss')
    assert.equal(@Plumlinks.cache('cachekey'), 'hit')
    done()
