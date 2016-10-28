QUnit.module "Remote Attribute"

createTarget = (html) ->
  testDiv = @document.createElement('div')
  testDiv.innerHTML = html
  return testDiv.firstChild

testWithSession "#httpRequestType returns GET link with bh-remote set to nothing", (assert) ->
  html = """
    <a href="/test" data-bh-remote></a>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.equal remote.httpUrl, '/test'
  assert.equal remote.actualRequestType, 'GET'

testWithSession "#httpRequestType returns a VERB link with bh-remote set to a valid verb", (assert) ->
  html = """
    <a href="/test" data-bh-remote='post'></a>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.equal remote.httpUrl, '/test'
  assert.equal remote.actualRequestType, 'POST'

testWithSession "#httpRequestType returns GET link with bh-remote set to an invalid verb", (assert) ->
  html = """
    <a href="/test" data-bh-remote='invalid'></a>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.equal remote.httpUrl, '/test'
  assert.equal remote.actualRequestType, 'GET'

testWithSession "#httpRequestType returns the form method by default", (assert) ->
  html = """
    <form data-bh-remote method='post'>
      <input type='file' name='foo'><input type='text' name='bar' value='fizzbuzz'>
    </form>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.equal remote.actualRequestType, 'POST'

testWithSession "#httpRequestType uses the data-bh-remote when method is not set", (assert) ->
  html = """
    <form data-bh-remote>
      <input type='file' name='foo'><input type='text' name='bar' value='fizzbuzz'>
    </form>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.equal remote.actualRequestType, 'POST'

testWithSession "#httpRequestType is set to method even if data-bh-remote is set", (assert) ->
  html = """
    <form data-bh-remote='get' method='post'>
      <input type='file' name='foo'><input type='text' name='bar' value='fizzbuzz'>
    </form>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.equal remote.actualRequestType, 'POST'

testWithSession "#httpRequestType is set to POST when method is not set and data-bh-remote is present", (assert) ->
  html = """
    <form data-bh-remote>
      <input type='file' name='foo'><input type='text' name='bar' value='fizzbuzz'>
    </form>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.equal remote.actualRequestType, 'POST'

testWithSession "#httpRequestType is set to data-bh-remote when used with a value, and when method is not set", (assert) ->
  html = """
    <form data-bh-remote='get'>
      <input type='file' name='foo'><input type='text' name='bar' value='fizzbuzz'>
    </form>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.equal remote.actualRequestType, 'GET'

testWithSession "#payload will contain a _method when data-bh-remote is set to verbs unsupported by the browser (PUT, DELETE)", (assert) ->
  html = """
    <a href="/test" data-bh-remote='put'></a>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.equal remote.httpUrl, '/test'
  assert.equal remote.actualRequestType, 'POST'
  assert.equal remote.payload, "_method=PUT"


testWithSession "#payload will contain a _method when data-bh-remote on a form is set to verbs unsupported by the browser (PUT, DELETE)", (assert) ->
  html = """
    <form data-bh-remote method='PUT'>
      <input type='file' name='foo'><input type='text' name='bar' value='fizzbuzz'>
    </form>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  payload = Array.from(remote.payload.keys())
  assert.equal remote.actualRequestType, 'POST'
  assert.ok "_method" in payload

testWithSession "#contentType returns null", (assert) ->
  html = """
    <a href="/test" data-bh-remote></a>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.equal remote.contentType, null

testWithSession "#contentType returns form-urlencoded on non-GET links", (assert) ->
  html = """
    <a href="/test" data-bh-remote='put'></a>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.equal remote.contentType, 'application/x-www-form-urlencoded; charset=UTF-8'


testWithSession "#contentType returns null on forms regardless of verb", (assert) ->
  html = """
    <form data-bh-remote>
      <input type='file' name='foo'><input type='text' name='bar' value='fizzbuzz'>
    </form>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.equal remote.contentType, null

  html = """
    <form data-bh-remote='GET'>
      <input type='file' name='foo'><input type='text' name='bar' value='fizzbuzz'>
    </form>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.equal remote.contentType, null

  html = """
    <form data-bh-remote='PUT'>
      <input type='file' name='foo'><input type='text' name='bar' value='fizzbuzz'>
    </form>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.equal remote.contentType, null

  html = """
    <form data-bh-remote='DELETE'>
      <input type='file' name='foo'><input type='text' name='bar' value='fizzbuzz'>
    </form>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.equal remote.contentType, null

testWithSession "#isValid returns true with a valid form", (assert) ->
  html = """
    <form data-bh-remote method='post' action='/'>
      <input type='file' name='foo'><input type='text' name='bar' value='fizzbuzz'>
    </form>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.ok remote.isValid()

testWithSession "#isValid returns false with an invalid form (missing action)", (assert) ->
  html = """
    <form data-bh-remote method='post'>
      <input type='file' name='foo'><input type='text' name='bar' value='fizzbuzz'>
    </form>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.notOk remote.isValid()

testWithSession "#isValid returns false with an invalid form (missing data-bh-remote)", (assert) ->
  html = """
    <form method='post' action='/'>
      <input type='file' name='foo'><input type='text' name='bar' value='fizzbuzz'>
    </form>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.notOk remote.isValid()

testWithSession "#isValid returns true with a valid link", (assert) ->
  html = """
    <a href="/test" data-bh-remote='POST'></a>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.ok remote.isValid()

testWithSession "#isValid returns false with a invalid link (missing data-bh-remote)", (assert) ->
  html = """
    <a href="/test"></a>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.notOk remote.isValid()

testWithSession "#isValid returns true with bh-remote (sans data-)", (assert) ->
  html = """
    <a href="/test" bh-remote='POST'></a>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.ok remote.isValid()

testWithSession "#payload returns captured input fields", (assert) ->
  html = """
    <form data-bh-remote method='post' action='/'>
      <input type='file' name='foo'><input type='text' name='bar' value='fizzbuzz'>
    </form>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  payload = remote.payload
  assert.ok (payload instanceof @window.FormData)
  assert.equal payload.get('bar'), 'fizzbuzz'
  assert.equal remote.httpUrl, '/'

testWithSession "#payload won't include form inputs with bh-remote-noserialize", (assert) ->
  html = """
    <form data-bn-remote method='post' action='/'>
      <input type='file' name='foo'><input type='text' name='bar' value='fizzbuzz' bh-remote-noserialize>
    </form>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  payload = remote.payload
  assert.ok (payload instanceof @window.FormData)
  assert.propEqual Array.from(payload.keys()), []
  assert.equal remote.httpUrl, '/'

