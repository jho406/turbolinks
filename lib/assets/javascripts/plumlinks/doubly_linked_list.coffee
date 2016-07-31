class window.DoublyLinkedList
  constructor: ->
    @head = @tail = null
    @length = 0

  createNode: (obj) ->
    return {prev: null, element: obj, next: null}

  push: (obj) ->
    if (@tail)
      ele = @createNode(obj)
      ele.prev = @tail
      @tail = @tail.next = ele

      @length += 1
    else
      @head = @tail = @createNode(obj)
      @length += 1

  pop: ()->
    if (@tail)
      element = @tail
      @tail = element.prev
      element.prev = null
      if (@tail)
        @tail.next = null
      @length -= 1

      return element.element
    else
      return null

  shift: ()->
    if (@head)
      element = @head
      @head = element.next
      element.next = null
      if (@head)
        @head.prev = null
      @length -= 1

      return element.element
    else
      return null

  unshift: (obj)->
    if (@head)
      ele = @createNode(obj)
      ele.next = @head
      @head = @head.prev = ele

      @length += 1
    else
      @head = @tail = @createNode(obj)
      @length += 1
