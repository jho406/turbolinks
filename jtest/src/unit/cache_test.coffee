QUnit.module "Cache"

testWithSession "cache can only be set the first time", (assert) ->
  @Plumlinks.cache('cachekey','hit')
  assert.equal(@Plumlinks.cache('cachekey'), 'hit')

  @Plumlinks.cache('cachekey','miss')
  assert.equal(@Plumlinks.cache('cachekey'), 'hit')
