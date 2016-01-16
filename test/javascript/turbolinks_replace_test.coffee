assert = chai.assert

suite 'Turbolinks.replace()', ->
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

  test "default", (done) ->
    doc =
      data: { heading: 'some data' }
      title: 'new title'
      csrf_token: 'new-token'
      assets: ['application-123.js', 'application-123.js']

    assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token'
    assert.equal @document.title, 'title'
    @document.addEventListener 'turbolinks:load', (event) =>
      assert.equal @document.title, 'new title'
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'new-token'
      assert.deepEqual event.data.data, { heading: "some data" } # body is replaced
      done()
    @Turbolinks.replace(doc)

  test "with :title set to a value replaces the title with the value", (done) ->
    doc =
      data: { heading: 'some data' }
      title: 'new title'
      csrf_token: 'new-token'
      assets: ['application-123.js', 'application-123.js']

    body = @$('body')
    @document.addEventListener 'turbolinks:load', (event) =>
      assert.equal @document.title, 'specified title'
      done()
    @Turbolinks.replace(doc, title: 'specified title')

  test "with :title set to false doesn't replace the title", (done) ->
    doc =
      data: { heading: 'some data' }
      title: 'new title'
      csrf_token: 'new-token'
      assets: ['application-123.js', 'application-123.js']

    @document.addEventListener 'turbolinks:load', (event) =>
      assert.equal @document.title, 'title'
      done()
    @Turbolinks.replace(doc, title: false)

  test "with different assets refreshes the page", (done) ->
    doc =
      data: { heading: 'some data' }
      title: 'new title'
      csrf_token: 'new-token'
      assets: ['application-789.js']

    @window.addEventListener 'unload', =>
      done()
    @Turbolinks.replace(doc, title: 'specified title')
