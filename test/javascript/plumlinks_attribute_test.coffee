assert = chai.assert

createTarget = (html) ->
  testDiv = @document.createElement('div')
  testDiv.innerHTML = html
  return testDiv.firstChild

suite 'Plumlinks.Attribute', ->
  setup (done) ->
    @iframe = document.createElement('iframe')
    @iframe.setAttribute('scrolling', 'yes')
    @iframe.setAttribute('style', 'visibility: hidden;')
    @iframe.setAttribute('src', 'iframe_with_link')

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

  test "link with plumlinks-remote set to nothing", (done) ->
    html = """
      <a href="/test" data-plumlinks-remote></a>
    """
    target = createTarget(html)
    remote = new @window.Attribute(target)
    assert.equal remote.httpUrl, '/test'
    assert.equal remote.actualRequestType, 'GET'
    assert.equal remote.httpRequestType, 'GET'
    done()

  test "link with plumlinks-remote attribute set to GET", (done) ->
    html = """
      <a href="/test" data-plumlinks-remote></a>
    """
    target = createTarget(html)
    remote = new @window.Attribute(target)
    assert.equal remote.httpUrl, '/test'
    assert.equal remote.actualRequestType, 'GET'
    assert.equal remote.httpRequestType, 'GET'
    done()

  test "link with plumlinks-remote attribute set to POST or other", (done) ->
    html = """
      <a href="/test" data-plumlinks-remote='POST'></a>
    """
    target = createTarget(html)
    remote = new @window.Attribute(target)
    assert.equal remote.httpUrl, '/test'
    assert.equal remote.actualRequestType, 'POST'
    assert.equal remote.httpRequestType, 'POST'
    done()

  test "form with plumlinks-remote ", (done) ->
    html = """
      <form data-plumlinks-remote method='post'>
        <input type='file' name='foo'><input type='text' name='bar' value='fizzbuzz'>
      </form>
    """
    target = createTarget(html)
    remote = new @window.Attribute(target)
    payload = remote.payload
    assert.isTrue (payload instanceof @window.FormData)
    assert.equal payload.get('bar'), 'fizzbuzz'
    done()

  test "form with plumlinks-remote with nativeEncodingFalse", (done) ->
    html = """
      <form data-plumlinks-remote action='/test' method='post'>
        <input type='text' name='foo'><input type='text' name='bar' value='fizzbuzz'>
      </form>
    """
    target = createTarget(html)
    remote = new @window.Attribute(target, {useNativeEncoding: false})
    payload = remote.payload
    assert.isFalse (payload instanceof @window.FormData)
    assert.equal remote.httpUrl, '/test?foo=&bar=fizzbuzz&_method=post'
    done()
