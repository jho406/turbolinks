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
    doc = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>new title</title>
        <meta content="new-token" name="csrf-token">
        <script>var headScript = true</script>
      </head>
      <body new-attribute>
        <div id="new-div"></div>
        <div id="permanent" data-turbolinks-permanent>new content</div>
        <div id="temporary" data-turbolinks-temporary>new content</div>
        <script>window.j = window.j || 0; window.j++;</script>
        <script data-turbolinks-eval="false">var bodyScriptEvalFalse = true</script>
      </body>
      </html>
    """
    body = @$('body')
    permanent = @$('#permanent')
    permanent.addEventListener 'click', -> done()
    beforeUnloadFired = partialLoadFired = false
    @document.addEventListener 'page:before-unload', =>
      assert.isUndefined @window.j
      assert.notOk @$('#new-div')
      assert.notOk @$('body').hasAttribute('new-attribute')
      assert.ok @$('#div')
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'token'
      assert.equal @document.title, 'title'
      assert.equal @$('body'), body
      beforeUnloadFired = true
    @document.addEventListener 'page:load', (event) =>
      assert.ok beforeUnloadFired
      assert.deepEqual event.data, [@document.body]
      assert.equal @window.j, 1
      assert.isUndefined @window.headScript
      assert.isUndefined @window.bodyScriptEvalFalse
      assert.ok @$('#new-div')
      assert.ok @$('body').hasAttribute('new-attribute')
      assert.notOk @$('#div')
      assert.equal @$('#permanent').textContent, 'permanent content'
      assert.equal @$('#temporary').textContent, 'new content'
      assert.equal @document.title, 'new title'
      assert.equal @$('meta[name="csrf-token"]').getAttribute('content'), 'new-token'
      assert.notEqual @$('body'), body # body is replaced
      assert.equal @$('#permanent'), permanent # permanent nodes are transferred
      @$('#permanent').click() # event listeners on permanent nodes should not be lost
    @Turbolinks.replace(doc)

  test "with :flush", (done) ->
    doc = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title></title>
      </head>
      <body>
        <div id="permanent" data-turbolinks-permanent>new content</div>
      </body>
      </html>
    """
    body = @$('body')
    beforeUnloadFired = partialLoadFired = false
    @document.addEventListener 'page:before-unload', =>
      assert.equal @$('#permanent').textContent, 'permanent content'
      beforeUnloadFired = true
    @document.addEventListener 'page:change', =>
      assert.ok beforeUnloadFired
      assert.notOk partialLoadFired
      assert.equal @$('#permanent').textContent, 'new content'
      done()
    @Turbolinks.replace(doc, flush: true)

  test "with :keep", (done) ->
    doc = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title></title>
      </head>
      <body>
        <div id="div">new content</div>
      </body>
      </html>
    """
    body = @$('body')
    div = @$('#div')
    div.addEventListener 'click', -> done()
    beforeUnloadFired = partialLoadFired = false
    @document.addEventListener 'page:before-unload', =>
      assert.equal @$('#div').textContent, 'div content'
      beforeUnloadFired = true
    @document.addEventListener 'page:change', =>
      assert.ok beforeUnloadFired
      assert.equal @$('#div').textContent, 'div content'
      assert.equal @$('#div'), div # :keep nodes are transferred
      @$('#div').click() # event listeners on :keep nodes should not be lost
    @Turbolinks.replace(doc, keep: ['div'])


  test "with :title set to a value replaces the title with the value", (done) ->
    doc = """
      <!DOCTYPE html>
      <html>
      <head>
        <title>new title</title>
      </head>
      <body new-attribute>
        <div id="new-div"></div>
      </body>
      </html>
    """
    body = @$('body')
    @document.addEventListener 'page:load', (event) =>
      assert.equal @document.title, 'specified title'
      done()
    @Turbolinks.replace(doc, title: 'specified title')

  test "with :title set to false doesn't replace the title", (done) ->
    doc = """
      <!DOCTYPE html>
      <html>
      <head>
        <title>new title</title>
      </head>
      <body new-attribute>
        <div id="new-div"></div>
      </body>
      </html>
    """
    body = @$('body')
    @document.addEventListener 'page:load', (event) =>
      assert.equal @document.title, 'title'
      done()
    @Turbolinks.replace(doc, title: false)

  # https://connect.microsoft.com/IE/feedback/details/811408/
  test "IE textarea placeholder bug", (done) ->
    doc = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>title</title>
      </head>
      <body>
        <div id="form">
          <textarea placeholder="placeholder" id="textarea1"></textarea>
          <textarea placeholder="placeholder" id="textarea2">placeholder</textarea>
          <textarea id="textarea3">value</textarea>
        </div>
        <div id="permanent" data-turbolinks-permanent><textarea placeholder="placeholder" id="textarea-permanent"></textarea></div>
      </body>
      </html>
    """
    change = 0
    @document.addEventListener 'page:change', =>
      change += 1
      if change is 1
        assert.equal @$('#textarea1').value, ''
        assert.equal @$('#textarea2').value, 'placeholder'
        assert.equal @$('#textarea3').value, 'value'
        assert.equal @$('#textarea-permanent').value, ''
        @Turbolinks.visit('iframe2.html')
      else if change is 2
        assert.equal @$('#textarea-permanent').value, ''
        setTimeout =>
          @window.history.back()
        , 0
      else if change is 3
        assert.equal @$('#textarea1').value, ''
        assert.equal @$('#textarea2').value, 'placeholder'
        assert.equal @$('#textarea3').value, 'value'
        assert.equal @$('#textarea-permanent').value, ''
        @$('#textarea-permanent').value = 'test'
        @Turbolinks.replace(doc, change: ['form'])
      else if change is 4
        assert.equal @$('#textarea1').value, ''
        assert.equal @$('#textarea2').value, 'placeholder'
        assert.equal @$('#textarea3').value, 'value'
        assert.equal @$('#textarea-permanent').value, 'test'
        assert.equal @$('#form').ownerDocument, @document
        done()
    @Turbolinks.replace(doc, flush: true)


  test "works with :keep key of node that also has data-turbolinks-permanent", (done) ->
    html = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>title</title>
      </head>
      <body>
        <div id="permanent" data-turbolinks-permanent></div>
      </body>
      </html>
    """
    permanent = @$('#permanent')
    @document.addEventListener 'page:change', =>
      assert.equal @$('#permanent'), permanent
      done()
    @Turbolinks.replace(html, keep: ['permanent'])
