class window.ParallelQueue
  constructor: ->
    @dll = new DoublyLinkedList
    @active = true

  push:(xhr)->
    @dll.push(xhr)
    xhr._originalOnLoad = xhr.onload.bind(xhr)

    xhr.onload = =>
      if !@active
        return

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
    # this doesnt work quite well with recent reqest canceling...
    # i may not even need the queue? the last request should always win...
    # but how do i handle multi forms?
    # is it a unreconciblale tradeoff? 
    # get requests should always take precendence?
    # tempoary state!
    # data-precendence
    # async allowed as long as its the same root component.
    @active = false
    node = @dll.head
    while(node)
      qxhr = node.element
      qxhr.abort()
      node = node.next
    @dll = new DoublyLinkedList

