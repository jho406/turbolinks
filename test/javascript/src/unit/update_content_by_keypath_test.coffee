QUnit.module "Replace test"

testWithSession "updating content node and rendering", (assert) ->
  done = assert.async()
  update1 = contact:
    firstName: 'john'
    address:
      zip: 10002

  load = 0
  @window.addEventListener 'bensonhurst:load', (event) =>
    data = event.data.data
    load +=1
    if load == 1
      assert.propEqual data, update1
      @Bensonhurst.graftByKeypath('data.contact.firstName', 'sully')
    else if load == 2
      assert.strictEqual data.contact.address, update1.contact.address
      assert.notStrictEqual event.data.contact, update1.contact
      done()
  newData = data: heading: 'new data'
  @Bensonhurst.graftByKeypath('data', update1)
