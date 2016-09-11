QUnit.module "Remote Attribute"

createTarget = (html) ->
  testDiv = @document.createElement('div')
  testDiv.innerHTML = html
  return testDiv.firstChild

testWithSession "link with plumlinks-remote set to nothing", (assert) ->
  done = assert.async()
  html = """
    <a href="/test" data-plumlinks-remote></a>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.equal remote.httpUrl, '/test'
  assert.equal remote.actualRequestType, 'GET'
  assert.equal remote.httpRequestType, 'GET'
  done()

testWithSession "link with plumlinks-remote attribute set to GET", (assert) ->
  done = assert.async()
  html = """
    <a href="/test" data-plumlinks-remote="GET"></a>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.equal remote.httpUrl, '/test'
  assert.equal remote.actualRequestType, 'GET'
  assert.equal remote.httpRequestType, 'GET'
  done()

testWithSession "link with plumlinks-remote attribute set to POST or other", (assert) ->
  done = assert.async()
  html = """
    <a href="/test" data-plumlinks-remote='POST'></a>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.equal remote.httpUrl, '/test'
  assert.equal remote.actualRequestType, 'POST'
  assert.equal remote.httpRequestType, 'POST'
  done()

testWithSession "form with plumlinks-remote ", (assert) ->
  done = assert.async()
  html = """
    <form data-plumlinks-remote method='post' action='/'>
      <input type='file' name='foo'><input type='text' name='bar' value='fizzbuzz'>
    </form>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  payload = remote.payload
  assert.ok (payload instanceof @window.FormData)
  assert.equal payload.get('bar'), 'fizzbuzz'
  assert.equal remote.httpUrl, '/'
  done()

testWithSession "isValid with a valid form", (assert) ->
  done = assert.async()
  html = """
    <form data-plumlinks-remote method='post' action='/'>
      <input type='file' name='foo'><input type='text' name='bar' value='fizzbuzz'>
    </form>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.ok remote.isValid()
  done()

testWithSession "isValid with an invalid form (missing action)", (assert) ->
  done = assert.async()
  html = """
    <form data-plumlinks-remote method='post'>
      <input type='file' name='foo'><input type='text' name='bar' value='fizzbuzz'>
    </form>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.notOk remote.isValid()
  done()

testWithSession "isValid with an invalid form (missing data-plumlinks-remote)", (assert) ->
  done = assert.async()
  html = """
    <form method='post' action='/'>
      <input type='file' name='foo'><input type='text' name='bar' value='fizzbuzz'>
    </form>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.notOk remote.isValid()
  done()

testWithSession "isValid with a valid link", (assert) ->
  done = assert.async()
  html = """
    <a href="/test" data-plumlinks-remote='POST'></a>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.ok remote.isValid()
  done()

testWithSession "isValid with a invalid link (missing data-plumlinks-remoet)", (assert) ->
  done = assert.async()
  html = """
    <a href="/test"></a>
  """
  target = createTarget(html)
  remote = new @window.Remote(target)
  assert.notOk remote.isValid()
  done()

