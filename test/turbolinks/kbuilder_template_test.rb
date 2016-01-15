require_relative "test_helper"
require "mocha/setup"
require "active_model"
require "action_view"
require "action_view/testing/resolvers"
require "active_support/cache"
require "turbolinks/kbuilder_template"

BLOG_POST_PARTIAL = <<-JBUILDER
  json.extract! blog_post, :id, :body
  json.author do
    first_name, last_name = blog_post.author_name.split(nil, 2)
    json.first_name first_name
    json.last_name last_name
  end
JBUILDER

COLLECTION_PARTIAL = <<-JBUILDER
  json.extract! collection, :id, :name
JBUILDER

PROFILE_PARTIAL = <<-JBUILDER
  json.email email
JBUILDER

FOOTER_PARTIAL = <<-JBUILDER
  json.terms "You agree"
JBUILDER

BlogPost = Struct.new(:id, :body, :author_name)
Collection = Struct.new(:id, :name)
blog_authors = [ "David Heinemeier Hansson", "Pavel Pravosud" ].cycle
BLOG_POST_COLLECTION = Array.new(10){ |i| BlogPost.new(i+1, "post body #{i+1}", blog_authors.next) }
COLLECTION_COLLECTION = Array.new(5){ |i| Collection.new(i+1, "collection #{i+1}") }

ActionView::Template.register_template_handler :kbuilder, Turbolinks::KbuilderHandler

PARTIALS = {
  "_partial.js.kbuilder"  => "foo ||= 'hello'; json.content foo",
  "_blog_post.js.kbuilder" => BLOG_POST_PARTIAL,
  "_profile.js.kbuilder" => PROFILE_PARTIAL,
  "_footer.js.kbuilder" => FOOTER_PARTIAL,
  "_collection.js.kbuilder" => COLLECTION_PARTIAL
}

def strip_format(str)
  str.strip_heredoc.gsub(/\n\s*/, "")
end

class KbuilderTemplateTest < ActionView::TestCase
  setup do
    self.request_forgery = false
    Turbolinks.configuration.track_assets = []
    self.turbolinks = {}

    @context = self
    Rails.cache.clear
  end

  cattr_accessor :request_forgery, :turbolinks
  self.request_forgery = false

  def jbuild(source)
    @rendered = []
    partials = PARTIALS.clone
    partials["test.js.kbuilder"] = source
    resolver = ActionView::FixtureResolver.new(partials)
    lookup_context.view_paths = [resolver]
    lookup_context.formats = [:js]
    template = ActionView::Template.new(source, "test", Turbolinks::KbuilderHandler, virtual_path: "test")
    template.render(self, {}).strip
  end

  def undef_context_methods(*names)
    self.class_eval do
      names.each do |name|
        undef_method name.to_sym if method_defined?(name.to_sym)
      end
    end
  end

  def protect_against_forgery?
    self.request_forgery
  end

  def form_authenticity_token
    "secret"
  end

  test "rendering" do
    result = jbuild(<<-JBUILDER)
      json.content "hello"
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        return ({"data":{"content":"hello"}});
      })()
    JS

    assert_equal expected, result
  end

  test "render with asset tracking" do
    Turbolinks.configuration.track_assets = ['test.js', 'test.css']
    self.turbolinks = {}

    result = jbuild(<<-TEMPLATE)
      json.content "hello"
    TEMPLATE

    expected = strip_format(<<-JS)
      (function(){
        return ({"data":{"content":"hello"},"assets":["/test.js","/test.css"]});
      })()
    JS

    assert_equal expected, result
  end


  test "render with csrf token when request forgery is on" do
    self.request_forgery = true
    # csrf_meta_tags also delegate authenticity tokens to the controller
    # here we provide a simple mock to the context

    result = jbuild(<<-TEMPLATE)
      json.content "hello"
    TEMPLATE

    expected = strip_format(<<-JS)
      (function(){
        return ({"data":{"content":"hello"},"csrf_token":"secret"});
      })()
    JS

    assert_equal expected, result
  end

  test "wrapping jbuilder contents inside Turbolinks with additional options" do
    Turbolinks.configuration.track_assets = ['test.js', 'test.css']
    self.turbolinks = { title: 'this is fun' }

    result = jbuild(<<-TEMPLATE)
      json.content "hello"
    TEMPLATE

    expected = strip_format(<<-JS)
      (function(){
        return ({"data":{"content":"hello"},"title":"this is fun","assets":["/test.js","/test.css"]});
      })()
    JS

    assert_equal expected, result
  end

  test "key_format! with parameter" do
    result = jbuild(<<-JBUILDER)
      json.key_format! camelize: [:lower]
      json.camel_style "for JS"
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        return ({"data":{"camelStyle":"for JS"}});
      })()
    JS

    assert_equal expected, result
  end

  test "key_format! propagates to child elements" do
    result = jbuild(<<-JBUILDER)
      json.key_format! :upcase
      json.level1 "one"
      json.level2 do
        json.value "two"
      end
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        return ({"data":{
          "LEVEL1":"one",
          "LEVEL2":{"VALUE":"two"}
        }});
      })()
    JS

    assert_equal expected, result
  end

  test "renders partial via the option through set!" do
    @post = BLOG_POST_COLLECTION.first
    Rails.cache.clear

    result = jbuild(<<-JBUILDER)
      json.post @post, partial: "blog_post", as: :blog_post
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        return ({"data":{"post":{
          "id":1,
          "body":"post body 1",
          "author":{"first_name":"David","last_name":"Heinemeier Hansson"}
        }}});
      })()
    JS

    assert_equal expected, result
  end

  test "renders a partial with no locals" do
    result = jbuild(<<-JBUILDER)
      json.footer partial: "footer"
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        return ({"data":{"footer":{"terms":"You agree"}}});
      })()
    JS
    assert_equal expected, result
  end

  test "renders a partial with locals" do
    result = jbuild(<<-JBUILDER)
      json.profile partial: "profile", locals: {email: "test@test.com"}
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        return ({"data":{"profile":{"email":"test@test.com"}}});
      })()
    JS
    assert_equal expected, result
  end

  test "renders a partial with locals and caches" do
    result = jbuild(<<-JBUILDER)
      json.profile 32, cache: "cachekey", partial: "profile", locals: {email: "test@test.com"}
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        Turbolinks.setCache("fbf68bd43dba9d0054ad02b65b7bb4aa", {"email":"test@test.com"});
        return ({"data":{"profile":Turbolinks.cache["fbf68bd43dba9d0054ad02b65b7bb4aa"]}});
      })()
    JS

    assert_equal expected, result
  end

  test "renders a partial even without a :as to the value, this usage is rare" do
    result = jbuild(<<-JBUILDER)
      json.profile 32, partial: "profile", locals: {email: "test@test.com"}
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        return ({"data":{"profile":{"email":"test@test.com"}}});
      })()
    JS

    assert_equal expected, result
  end

  test "render array of partials without an :as to a member, this usage is very rare" do
    result = jbuild(<<-JBUILDER)
      json.array! [1,2], partial: "footer"
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        return ({"data":[{"terms":"You agree"},{"terms":"You agree"}]});
      })()
    JS

    assert_equal expected, result
  end

  test "render array of partials without an :as to a member and cache" do
    result = jbuild(<<-JBUILDER)
      json.array! [1,2], partial: "footer", cache: ->(i){ ['a', i] }
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        Turbolinks.setCache("0d6be77bebdef3fee771f21b49d51806", {"terms":"You agree"});
        Turbolinks.setCache("c88c9332e539d4f3740f3c44575a1ebc", {"terms":"You agree"});
        return ({"data":[Turbolinks.cache["0d6be77bebdef3fee771f21b49d51806"],Turbolinks.cache["c88c9332e539d4f3740f3c44575a1ebc"]]});
      })()
    JS

    assert_equal expected, result
  end

  # test "render collection as collections" do
  #   #keep
  #   result = jbuild(<<-JBUILDER)
  #     json.collection collection: BLOG_POST_COLLECTION, partial: "collection", as: :collection
  #   JBUILDER
  #   expected = "Turbolinks.replace([{\"id\":1,\"body\":\"post body 1\",\"author\":{\"first_name\":\"David\",\"last_name\":\"Heinemeier Hansson\"}},{\"id\":2,\"body\":\"post body 2\",\"author\":{\"first_name\":\"Pavel\",\"last_name\":\"Pravosud\"}},{\"id\":3,\"body\":\"post body 3\",\"author\":{\"first_name\":\"David\",\"last_name\":\"Heinemeier Hansson\"}},{\"id\":4,\"body\":\"post body 4\",\"author\":{\"first_name\":\"Pavel\",\"last_name\":\"Pravosud\"}},{\"id\":5,\"body\":\"post body 5\",\"author\":{\"first_name\":\"David\",\"last_name\":\"Heinemeier Hansson\"}},{\"id\":6,\"body\":\"post body 6\",\"author\":{\"first_name\":\"Pavel\",\"last_name\":\"Pravosud\"}},{\"id\":7,\"body\":\"post body 7\",\"author\":{\"first_name\":\"David\",\"last_name\":\"Heinemeier Hansson\"}},{\"id\":8,\"body\":\"post body 8\",\"author\":{\"first_name\":\"Pavel\",\"last_name\":\"Pravosud\"}},{\"id\":9,\"body\":\"post body 9\",\"author\":{\"first_name\":\"David\",\"last_name\":\"Heinemeier Hansson\"}},{\"id\":10,\"body\":\"post body 10\",\"author\":{\"first_name\":\"Pavel\",\"last_name\":\"Pravosud\"}}]);"
  #   assert_equal expected, result
  # end
  #

  test "render array of partials" do
    result = jbuild(<<-JBUILDER)
      json.array! BLOG_POST_COLLECTION, partial: "blog_post", as: :blog_post
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        return ({"data":[
          {"id":1,"body":"post body 1","author":{"first_name":"David","last_name":"Heinemeier Hansson"}},
          {"id":2,"body":"post body 2","author":{"first_name":"Pavel","last_name":"Pravosud"}},
          {"id":3,"body":"post body 3","author":{"first_name":"David","last_name":"Heinemeier Hansson"}},
          {"id":4,"body":"post body 4","author":{"first_name":"Pavel","last_name":"Pravosud"}},
          {"id":5,"body":"post body 5","author":{"first_name":"David","last_name":"Heinemeier Hansson"}},
          {"id":6,"body":"post body 6","author":{"first_name":"Pavel","last_name":"Pravosud"}},
          {"id":7,"body":"post body 7","author":{"first_name":"David","last_name":"Heinemeier Hansson"}},
          {"id":8,"body":"post body 8","author":{"first_name":"Pavel","last_name":"Pravosud"}},
          {"id":9,"body":"post body 9","author":{"first_name":"David","last_name":"Heinemeier Hansson"}},
          {"id":10,"body":"post body 10","author":{"first_name":"Pavel","last_name":"Pravosud"}}
        ]});
      })()
    JS

    assert_equal expected, result
  end

  test "renders array of partials as empty array with nil-collection" do
    result = jbuild(<<-JBUILDER)
      json.array! nil, partial: "blog_post", as: :blog_post
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        return ({"data":[]});
      })()
    JS

    assert_equal expected, result
  end

  test "renders array of partials via set!" do
    result = jbuild(<<-JBUILDER)
      json.posts BLOG_POST_COLLECTION, partial: "blog_post", as: :blog_post
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        return ({"data":{"posts":[
          {"id":1,"body":"post body 1","author":{"first_name":"David","last_name":"Heinemeier Hansson"}},
          {"id":2,"body":"post body 2","author":{"first_name":"Pavel","last_name":"Pravosud"}},
          {"id":3,"body":"post body 3","author":{"first_name":"David","last_name":"Heinemeier Hansson"}},
          {"id":4,"body":"post body 4","author":{"first_name":"Pavel","last_name":"Pravosud"}},
          {"id":5,"body":"post body 5","author":{"first_name":"David","last_name":"Heinemeier Hansson"}},
          {"id":6,"body":"post body 6","author":{"first_name":"Pavel","last_name":"Pravosud"}},
          {"id":7,"body":"post body 7","author":{"first_name":"David","last_name":"Heinemeier Hansson"}},
          {"id":8,"body":"post body 8","author":{"first_name":"Pavel","last_name":"Pravosud"}},
          {"id":9,"body":"post body 9","author":{"first_name":"David","last_name":"Heinemeier Hansson"}},
          {"id":10,"body":"post body 10","author":{"first_name":"Pavel","last_name":"Pravosud"}}
        ]}});
      })()
    JS

    assert_equal expected, result
  end

  test "render as empty array if partials as a nil value" do
    result = jbuild <<-JBUILDER
      json.posts nil, partial: "blog_post", as: :blog_post
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        return ({"data":{"posts":[]}});
      })()
    JS
    assert_equal expected, result
  end

  test "caching a value at a node" do
    undef_context_methods :fragment_name_with_digest, :cache_fragment_name

    result = jbuild(<<-JBUILDER)
      json.hello(32, cache: ['b', 'c'])
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        Turbolinks.setCache("420dd59aa351baf103b4184869dfe516", 32);
        return ({"data":{"hello":Turbolinks.cache["420dd59aa351baf103b4184869dfe516"]}});
      })()
    JS

    assert_equal expected, result
  end

  test "caching elements in a list" do
    undef_context_methods :fragment_name_with_digest, :cache_fragment_name

    result = jbuild(<<-JBUILDER)
      json.hello do
        json.array! [4,5], cache: ->(i){ ['a', i] } do |x|
          json.top "hello" + x.to_s
        end
      end
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        Turbolinks.setCache("31a0b2d69da777bb2dcf027350566f1d", {"top":"hello4"});
        Turbolinks.setCache("e9b9b9b98dafc029c4e814b091e90a7a", {"top":"hello5"});
        return ({"data":{"hello":[Turbolinks.cache["31a0b2d69da777bb2dcf027350566f1d"],Turbolinks.cache["e9b9b9b98dafc029c4e814b091e90a7a"]]}});
      })()
    JS

    assert_equal expected, result
  end

  test "list elements (cached and non cached) merges in the same scope" do
    undef_context_methods :fragment_name_with_digest, :cache_fragment_name

    result = jbuild(<<-JBUILDER)
      json.hello do
        json.array! [4,5], cache: ->(i){ ['a', i] } do |x|
          json.top 'hello'
        end
        json.array! [3,4]
        json.array! [1,2], cache: ->(i){ ['a', i] } do |x|
          json.bottom 'hello'
        end
      end
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        Turbolinks.setCache("31a0b2d69da777bb2dcf027350566f1d", {"top":"hello"});
        Turbolinks.setCache("e9b9b9b98dafc029c4e814b091e90a7a", {"top":"hello"});
        Turbolinks.setCache("4237e6f58bfe464b27ee270b55c12e84", {"bottom":"hello"});
        Turbolinks.setCache("34cfb415aba6256e9aaf661a8697248c", {"bottom":"hello"});
        return ({"data":{"hello":[Turbolinks.cache["31a0b2d69da777bb2dcf027350566f1d"],Turbolinks.cache["e9b9b9b98dafc029c4e814b091e90a7a"],3,4,Turbolinks.cache["4237e6f58bfe464b27ee270b55c12e84"],Turbolinks.cache["34cfb415aba6256e9aaf661a8697248c"]]}});
      })()
    JS

    assert_equal expected, result
  end

  test "nested caching generates a depth-first list of cache nodes" do
    undef_context_methods :fragment_name_with_digest, :cache_fragment_name

    result = jbuild(<<-JBUILDER)
      json.hello(cache: ['a', 'b']) do
        json.content(cache: ['d', 'z'])  do
          json.subcontent 'inner'
        end
        json.other(cache: ['e', 'z'])  do
          json.subcontent 'other'
        end
      end
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        Turbolinks.setCache("527312c467060937453434d11496f10f", {"subcontent":"inner"});
        Turbolinks.setCache("423c34f3270addc1369ee6d95d662c04", {"subcontent":"other"});
        Turbolinks.setCache("64af83f0566cd020f44ca0b25121fc58", {"content":Turbolinks.cache["527312c467060937453434d11496f10f"],"other":Turbolinks.cache["423c34f3270addc1369ee6d95d662c04"]});
        return ({"data":{"hello":Turbolinks.cache["64af83f0566cd020f44ca0b25121fc58"]}});
      })()
    JS

    assert_equal expected, result
  end

  test "caching an empty block generates no cache and no errors" do
    undef_context_methods :fragment_name_with_digest, :cache_fragment_name

    result = nil

    assert_nothing_raised do
        result = jbuild(<<-JBUILDER)
          json.hello do
            json.array! [4,5], cache: ->(i){['a', i]} do |x|
            end
          end
        JBUILDER
    end

    expected = strip_format(<<-JS)
      (function(){
        return ({\"data\":{\"hello\":[]}});
      })()
    JS

    assert_equal expected, result
  end

  test "child! accepts cache options" do
    undef_context_methods :fragment_name_with_digest, :cache_fragment_name

    result = jbuild(<<-JBUILDER)
      json.comments do
        json.child!(cache: ['e', 'z']) { json.content "hello" }
        json.child! { json.content "world" }
      end
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        Turbolinks.setCache("423c34f3270addc1369ee6d95d662c04", {"content":"hello"});
        return ({"data":{"comments":[Turbolinks.cache["423c34f3270addc1369ee6d95d662c04"],{"content":"world"}]}});
      })()
    JS

    assert_equal expected, result
  end

  test "fragment caching" do
    undef_context_methods :fragment_name_with_digest, :cache_fragment_name

    jbuild(<<-JBUILDER)
      json.post(cache: 'cachekey') do
        json.name "Cache"
      end
    JBUILDER

    result = jbuild(<<-JBUILDER)
      json.post(cache: 'cachekey') do
        json.name "Miss"
      end
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        Turbolinks.setCache("c6eb1da804069b92da0553e647a6770a", {"name":"Cache"});
        return ({"data":{"post":Turbolinks.cache["c6eb1da804069b92da0553e647a6770a"]}});
      })()
    JS

    assert_equal expected, result
  end

  test "fragment caching deserializes an array" do
    undef_context_methods :fragment_name_with_digest, :cache_fragment_name

    result = jbuild <<-JBUILDER
      json.content(cache: "cachekey") do
        json.array! %w[a b c]
      end
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        Turbolinks.setCache("c6eb1da804069b92da0553e647a6770a", ["a","b","c"]);
        return ({"data":{"content":Turbolinks.cache["c6eb1da804069b92da0553e647a6770a"]}});
      })()
    JS

    assert_equal expected, result
  end

  test "fragment caching works with previous version of cache digests" do
    undef_context_methods :cache_fragment_name

    @context.expects :fragment_name_with_digest

    jbuild <<-JBUILDER
      json.content(cache: "cachekey") do
        json.name "Cache"
      end
    JBUILDER
  end

  test "fragment caching works with current cache digests" do
    undef_context_methods :fragment_name_with_digest

    @context.expects :cache_fragment_name
    ActiveSupport::Cache.expects :expand_cache_key

    jbuild <<-JBUILDER
      json.content(cache: "cachekey") do
        json.name "Cache"
      end
    JBUILDER
  end

  test "current cache digest option accepts options through the last element hash" do
    undef_context_methods :fragment_name_with_digest

    @context.expects(:cache_fragment_name)
      .with(["cachekey"], skip_digest: true)
      .returns("cachekey")

    ActiveSupport::Cache.expects :expand_cache_key

    jbuild <<-JBUILDER
      json.content(cache: ["cachekey", skip_digest: true]) do
        json.name "Cache"
      end
    JBUILDER
  end

  test "does not perform caching when controller.perform_caching is false" do
    controller.perform_caching = false

    result = jbuild <<-JBUILDER
      json.content(cache: "cachekey") do
        json.name "Cache"
      end
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        return ({"data":{"content":{"name":"Cache"}}});
      })()
    JS

    assert_equal expected, result
  end

  test "invokes templates via params via set! and caches" do
    @post = BLOG_POST_COLLECTION.first

    result = jbuild(<<-JBUILDER)
      json.post @post, partial: "blog_post", as: :blog_post, cache: ['a', 'b']
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        Turbolinks.setCache("fedd00e5759ffda2b4ac1aeb6f2a7dde", {"id":1,"body":"post body 1","author":{"first_name":"David","last_name":"Heinemeier Hansson"}});
        return ({"data":{"post":Turbolinks.cache["fedd00e5759ffda2b4ac1aeb6f2a7dde"]}});
      })()
    JS

    assert_equal expected, result
  end

  test "shares partial caches (via the partial's digest) across multiple templates" do
    @hit = BlogPost.new(1, "hit", "John Smith")
    @miss = BlogPost.new(2, "miss", "John Smith")

    jbuild(<<-JBUILDER)
      json.post @hit, partial: "blog_post", as: :blog_post, cache: ['a', 'b']
    JBUILDER

    result = jbuild(<<-JBUILDER)
      json.post @miss, partial: "blog_post", as: :blog_post, cache: ['a', 'b']
    JBUILDER

    expected = strip_format(<<-JS)
      (function(){
        Turbolinks.setCache("fedd00e5759ffda2b4ac1aeb6f2a7dde", {"id":1,"body":"hit","author":{"first_name":"John","last_name":"Smith"}});
        return ({"data":{"post":Turbolinks.cache["fedd00e5759ffda2b4ac1aeb6f2a7dde"]}});
      })()
    JS

    assert_equal expected, result
  end


  test "render array of partials and caches" do
    result = jbuild(<<-JBUILDER)
      json.array! BLOG_POST_COLLECTION, partial: "blog_post", as: :blog_post, cache: ->(d){ ['a', d.id] }
    JBUILDER
    Rails.cache.clear

    expected = strip_format(<<-JS)
      (function(){
        Turbolinks.setCache("0d6be77bebdef3fee771f21b49d51806", {"id":1,"body":"post body 1","author":{"first_name":"David","last_name":"Heinemeier Hansson"}});
        Turbolinks.setCache("c88c9332e539d4f3740f3c44575a1ebc", {"id":2,"body":"post body 2","author":{"first_name":"Pavel","last_name":"Pravosud"}});
        Turbolinks.setCache("f693f9f35d5cd7fa1df4d6cb05f0dd64", {"id":3,"body":"post body 3","author":{"first_name":"David","last_name":"Heinemeier Hansson"}});
        Turbolinks.setCache("306d22c07d0ed0080656222b634a23fd", {"id":4,"body":"post body 4","author":{"first_name":"Pavel","last_name":"Pravosud"}});
        Turbolinks.setCache("599510241b78966805152d3f10379bdc", {"id":5,"body":"post body 5","author":{"first_name":"David","last_name":"Heinemeier Hansson"}});
        Turbolinks.setCache("37741607162f895d17d45ec9ff75d4dc", {"id":6,"body":"post body 6","author":{"first_name":"Pavel","last_name":"Pravosud"}});
        Turbolinks.setCache("65e8f91af9ffe9989cb759345dcb7d26", {"id":7,"body":"post body 7","author":{"first_name":"David","last_name":"Heinemeier Hansson"}});
        Turbolinks.setCache("ca627b17e0fe8b9560ec1e0911099762", {"id":8,"body":"post body 8","author":{"first_name":"Pavel","last_name":"Pravosud"}});
        Turbolinks.setCache("63543700a921958662967cc003f0dc06", {"id":9,"body":"post body 9","author":{"first_name":"David","last_name":"Heinemeier Hansson"}});
        Turbolinks.setCache("277a88c729950f01f14013d13dedf37d", {"id":10,"body":"post body 10","author":{"first_name":"Pavel","last_name":"Pravosud"}});
        return ({"data":[Turbolinks.cache["0d6be77bebdef3fee771f21b49d51806"],Turbolinks.cache["c88c9332e539d4f3740f3c44575a1ebc"],Turbolinks.cache["f693f9f35d5cd7fa1df4d6cb05f0dd64"],Turbolinks.cache["306d22c07d0ed0080656222b634a23fd"],Turbolinks.cache["599510241b78966805152d3f10379bdc"],Turbolinks.cache["37741607162f895d17d45ec9ff75d4dc"],Turbolinks.cache["65e8f91af9ffe9989cb759345dcb7d26"],Turbolinks.cache["ca627b17e0fe8b9560ec1e0911099762"],Turbolinks.cache["63543700a921958662967cc003f0dc06"],Turbolinks.cache["277a88c729950f01f14013d13dedf37d"]]});
      })()
    JS

    assert_equal expected, result
  end
end
