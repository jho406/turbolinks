assert = chai.assert

suite 'Turbolinks.cache()', ->
  setup (done) ->
    @iframe = document.createElement('iframe')
    @iframe.style.display = 'none'
    @iframe.setAttribute('src', 'iframe.html')
    document.body.appendChild(@iframe)
    @iframe.onload = =>
      @window = @iframe.contentWindow
      @document = @window.document
      @Turbolinks = @window.Turbolinks
      @$ = (selector) => @document.querySelector(selector)
      done()

  teardown ->
    document.body.removeChild(@iframe)

  test "cache can only be set the first time", (done) ->
    @Turbolinks.cache('cachekey','hit')
    assert.equal(@Turbolinks.cache('cachekey'), 'hit')

    @Turbolinks.cache('cachekey','miss')
    assert.equal(@Turbolinks.cache('cachekey'), 'hit')
    done()
