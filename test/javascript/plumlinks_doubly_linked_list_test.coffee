assert = chai.assert

suite 'Plumlinks link test', ->
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

  test "a new ddl starts off with 0 element", (done) ->
    ddl = new @window.DoublyLinkedList
    assert.equal ddl.length, 0
    done()

  test "push inserts an element", (done) ->
    ddl = new @window.DoublyLinkedList
    element = {}
    ddl.push(element)
    assert.equal ddl.length, 1
    assert.equal ddl.tail.element, element
    assert.equal ddl.head.element, element

    element2 = {}
    ddl.push(element2)
    assert.equal ddl.length, 2
    assert.equal ddl.tail.element, element2
    assert.equal ddl.head.element, element
    done()

  test "unshift inserts an element in the beginning", (done) ->
    ddl = new @window.DoublyLinkedList
    element = {}
    ddl.unshift(element)
    assert.equal ddl.length, 1
    assert.equal ddl.tail.element, element
    assert.equal ddl.head.element, element

    element2 = {}
    ddl.unshift(element2)
    assert.equal ddl.length, 2
    assert.equal ddl.tail.element, element
    assert.equal ddl.head.element, element2
    done()

  test "pop removes the last element", (done) ->
    ddl = new @window.DoublyLinkedList
    element = {}
    element2 = {}

    ddl.push(element)
    ddl.push(element2)

    assert.equal ddl.length, 2
    assert.equal ddl.tail.element, element2

    poppedElement = ddl.pop()
    assert.equal ddl.length, 1
    assert.equal poppedElement, element2
    assert.equal ddl.tail.element, element
    done()

  test "array shift removes the first element", (done) ->
    ddl = new @window.DoublyLinkedList
    element = {}
    element2 = {}

    ddl.push(element)
    ddl.push(element2)

    assert.equal ddl.length, 2
    assert.equal ddl.tail.element, element2

    released = ddl.shift()
    assert.equal ddl.length, 1
    assert.equal released, element
    assert.equal ddl.head.element, element2
    done()

  test "each iterates through the nodes and calls passed fn", (done) ->
    ddl = new @window.DoublyLinkedList

    ddl.push(1)
    ddl.push(2)
    sum = 0
    ddl.each (n)->
      sum += n

    assert.equal sum, 3
    done()

  test "async", (done) ->
    xhr = sinon.useFakeXMLHttpRequest();
    requests = []
    xhr.onCreate = (xhr) ->
      requests.push(xhr)

    @Plumlinks.visit('/', isAsync: true)
    @Plumlinks.visit('/', isAsync: true)

    assert.equal @Plumlinks.controller.pq.ddl.length, 2
    request[1].respond(200, { "Content-Type": "application/json" },
                                 '[{ "id": 12, "comment": "Hey there" }]')

    assert.equal @Plumlinks.controller.pq.ddl.length, 2
    request[0].respond(200, { "Content-Type": "application/json" },
                                 '[{ "id": 12, "comment": "Hey there" }]')

    assert.equal @Plumlinks.controller.pq.ddl.length, 0
