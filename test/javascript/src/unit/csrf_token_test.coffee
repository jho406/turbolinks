QUnit.module "CSRF Token test"

createTarget = (html) ->
  testDiv = @document.createElement('div')
  testDiv.innerHTML = html
  return testDiv.firstChild

testWithSession "#get return the current CSRF token", (assert) ->
  tokenTag = @document.querySelector 'meta[name="csrf-token"]'
  tokenTag.setAttribute 'content', 'someToken123'

  token = @Bensonhurst.CSRFToken.get(@document).token
  assert.equal token, 'someToken123'

testWithSession "#update sets a new CSRF token on the page", (assert) ->
  tokenTag = @document.querySelector 'meta[name="csrf-token"]'
  tokenTag.setAttribute 'content', 'someToken123'

  csrf = new @Bensonhurst.CSRFToken
  token = @Bensonhurst.CSRFToken.get(@document).token
  assert.equal token, 'someToken123'

  @Bensonhurst.CSRFToken.update('newToken123')
  token = @Bensonhurst.CSRFToken.get(@document).token
  assert.equal token, 'newToken123'
