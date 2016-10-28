QUnit.module "Cache"

testWithSession "cache can only be set the first time", (assert) ->
  @Bensonhurst.cache('cachekey','hit')
  assert.equal(@Bensonhurst.cache('cachekey'), 'hit')

  @Bensonhurst.cache('cachekey','miss')
  assert.equal(@Bensonhurst.cache('cachekey'), 'hit')
