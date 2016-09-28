QUnit.module "CSRF Token test"

createTarget = (html) ->
  testDiv = @document.createElement('div')
  testDiv.innerHTML = html
  return testDiv.firstChild

testWithSession "#get return the current CSRF token", (assert) ->
  tokenTag = @document.querySelector 'meta[name="csrf-token"]'
  tokenTag.setAttribute 'content', 'someToken123'

  token = @window.CSRFToken.get(@document).token
  assert.equal token, 'someToken123'

testWithSession "#update sets a new CSRF token on the page", (assert) ->
  tokenTag = @document.querySelector 'meta[name="csrf-token"]'
  tokenTag.setAttribute 'content', 'someToken123'

  csrf = new @window.CSRFToken
  token = @window.CSRFToken.get(@document).token
  assert.equal token, 'someToken123'

  @window.CSRFToken.update('newToken123')
  token = @window.CSRFToken.get(@document).token
  assert.equal token, 'newToken123'
