
QUnit.module "Utils"

testWithSession "without transitio", (assert) ->
  page = {}
  clone = @window.Utils.cloneByKeypath('a.b.c', 0 ,page)
  assert.strictEqual page, clone


testWithSession "without transitio", (assert) ->
  page = a: b: c: 3
  clone = @window.Utils.cloneByKeypath('a.b.c', page)
  assert.strictEqual page, clone

testWithSession "without transitio", (assert) ->
  page = a: b: c: 4
  clone = @window.Utils.cloneByKeypath('a.b.c', page)
  assert.strictEqual page, clone

testWithSession "adds a new graph", (assert) ->
  page = a: b: c: d: 5
  clone = @window.Utils.cloneByKeypath('a.b.c', foo: 'bar', page)
  assert.notStrictEqual page, clone
  assert.propEqual clone, a: b: c: foo: 'bar'

testWithSession "adds a new graph", (assert) ->
  graft1 = c: d: e: 5
  graft2 = i: j: k: 10

  page = a:
    b: graft1
    h: graft2

  clone = @window.Utils.cloneByKeypath('a.b.c.d', foo: 'bar', page)
  assert.notStrictEqual clone.a.b, graft1
  assert.strictEqual clone.a.h, graft2

  assert.propEqual clone,
    a:
      b: c: d: foo: 'bar'
      h: i: j: k: 10

testWithSession "cloneing by array id", (assert) ->
  page = a: b: [
    {id: 1},
    {id: 2},
    {id: 3}
  ]

  clone = @window.Utils.cloneByKeypath('a.b.id=2', {id:2, foo: 'bar'}, page)
  assert.notStrictEqual page, clone
  assert.strictEqual page.a.b[0], clone.a.b[0]
  assert.strictEqual page.a.b[2], clone.a.b[2]
  assert.propEqual clone,  a: b: [
    {id: 1},
    {id: 2, foo: 'bar'},
    {id: 3}
  ]

