class window.ParallelQueue
  constructor: ->
    @dll = new DoublyLinkedList

  push:(xhr)->
    @dll.push(xhr)
    xhr._originalOnLoad = xhr.onload.bind(xhr)

    xhr.onload = =>
      xhr._isDone = true
      node = @dll.head
      while(node)
        qxhr = node.element
        if !qxhr._isDone
          node = null
        else
          node = node.next
          @dll.shift()
          qxhr._originalOnLoad()

  drain: ->
    @dll.each (xhr)->
      xhr.abort()
    @dll.reset()

