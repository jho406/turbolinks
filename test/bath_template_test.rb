require "test_helper"
require "mocha/setup"
require "active_model"
require "action_view"
require "action_view/testing/resolvers"
require "active_support/cache"
require "bensonhurst/plum_template"
require "rails/version"

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

ActionView::Template.register_template_handler :plum, Bensonhurst::KbuilderHandler

PARTIALS = {
  "_partial.js.plum"  => "foo ||= 'hello'; json.content foo",
  "_blog_post.js.plum" => BLOG_POST_PARTIAL,
  "_profile.js.plum" => PROFILE_PARTIAL,
  "_footer.js.plum" => FOOTER_PARTIAL,
  "_collection.js.plum" => COLLECTION_PARTIAL
}

def strip_format(str)
  str.strip_heredoc.gsub(/\n\s*/, "")
end

class PlumTemplateTest < ActionView::TestCase
  setup do
    self.request_forgery = false
    Bensonhurst.configuration.track_assets = []

    # this is a stub. Normally this would be set by the
    # controller locals
    self.bensonhurst = {}

    @context = self
    Rails.cache.clear
  end

  cattr_accessor :request_forgery, :bensonhurst
  self.request_forgery = false

  def jbuild(source)
    @rendered = []
    partials = PARTIALS.clone
    partials["test.js.plum"] = source
    resolver = ActionView::FixtureResolver.new(partials)
    lookup_context.view_paths = [resolver]
    lookup_context.formats = [:js]
    template = ActionView::Template.new(source, "test", Bensonhurst::KbuilderHandler, virtual_path: "test")
    template.render(self, {}).strip
  end

  def cache_keys
    major_v = Rails::VERSION::MAJOR
    minor_v = Rails::VERSION::MINOR
    rails_v = "rails#{major_v}#{minor_v}"
    path = File.expand_path("../fixtures/cache_keys.yaml", __FILE__)
    keys = YAML.load_file(path)
    keys[method_name][rails_v]
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
    Bensonhurst.configuration.track_assets = ['test.js', 'test.css']

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

  test "wrapping jbuilder contents inside Bensonhurst with additional options" do
    Bensonhurst.configuration.track_assets = ['test.js', 'test.css']
    self.bensonhurst = { title: 'this is fun' }

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
        Bensonhurst.cache("#{cache_keys[0]}", {"email":"test@test.com"});
        return ({"data":{"profile":Bensonhurst.cache("#{cache_keys[0]}")}});
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
        Bensonhurst.cache("#{cache_keys[0]}", {"terms":"You agree"});
        Bensonhurst.cache("#{cache_keys[1]}", {"terms":"You agree"});
        return ({"data":[Bensonhurst.cache("#{cache_keys[0]}"),Bensonhurst.cache("#{cache_keys[1]}")]});
      })()
    JS

    assert_equal expected, result
  end

  # test "render collection as collections" do
  #   #keep
  #   result = jbuild(<<-JBUILDER)
  #     json.collection collection: BLOG_POST_COLLECTION, partial: "collection", as: :collection
  #   JBUILDER
  #   expected = "Bensonhurst.replace([{\"id\":1,\"body\":\"post body 1\",\"author\":{\"first_name\":\"David\",\"last_name\":\"Heinemeier Hansson\"}},{\"id\":2,\"body\":\"post body 2\",\"author\":{\"first_name\":\"Pavel\",\"last_name\":\"Pravosud\"}},{\"id\":3,\"body\":\"post body 3\",\"author\":{\"first_name\":\"David\",\"last_name\":\"Heinemeier Hansson\"}},{\"id\":4,\"body\":\"post body 4\",\"author\":{\"first_name\":\"Pavel\",\"last_name\":\"Pravosud\"}},{\"id\":5,\"body\":\"post body 5\",\"author\":{\"first_name\":\"David\",\"last_name\":\"Heinemeier Hansson\"}},{\"id\":6,\"body\":\"post body 6\",\"author\":{\"first_name\":\"Pavel\",\"last_name\":\"Pravosud\"}},{\"id\":7,\"body\":\"post body 7\",\"author\":{\"first_name\":\"David\",\"last_name\":\"Heinemeier Hansson\"}},{\"id\":8,\"body\":\"post body 8\",\"author\":{\"first_name\":\"Pavel\",\"last_name\":\"Pravosud\"}},{\"id\":9,\"body\":\"post body 9\",\"author\":{\"first_name\":\"David\",\"last_name\":\"Heinemeier Hansson\"}},{\"id\":10,\"body\":\"post body 10\",\"author\":{\"first_name\":\"Pavel\",\"last_name\":\"Pravosud\"}}]);"
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
        Bensonhurst.cache("#{cache_keys[0]}", 32);
        return ({"data":{"hello":Bensonhurst.cache("#{cache_keys[0]}")}});
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
        Bensonhurst.cache("#{cache_keys[0]}", {"top":"hello4"});
        Bensonhurst.cache("#{cache_keys[1]}", {"top":"hello5"});
        return ({"data":{"hello":[Bensonhurst.cache("#{cache_keys[0]}"),Bensonhurst.cache("#{cache_keys[1]}")]}});
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
        Bensonhurst.cache("#{cache_keys[0]}", {"top":"hello"});
        Bensonhurst.cache("#{cache_keys[1]}", {"top":"hello"});
        Bensonhurst.cache("#{cache_keys[2]}", {"bottom":"hello"});
        Bensonhurst.cache("#{cache_keys[3]}", {"bottom":"hello"});
        return ({"data":{"hello":[Bensonhurst.cache("#{cache_keys[0]}"),Bensonhurst.cache("#{cache_keys[1]}"),3,4,Bensonhurst.cache("#{cache_keys[2]}"),Bensonhurst.cache("#{cache_keys[3]}")]}});
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
        Bensonhurst.cache("#{cache_keys[0]}", {"subcontent":"inner"});
        Bensonhurst.cache("#{cache_keys[1]}", {"subcontent":"other"});
        Bensonhurst.cache("#{cache_keys[2]}", {"content":Bensonhurst.cache("#{cache_keys[0]}"),"other":Bensonhurst.cache("#{cache_keys[1]}")});
        return ({"data":{"hello":Bensonhurst.cache("#{cache_keys[2]}")}});
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
        Bensonhurst.cache("#{cache_keys[0]}", {"content":"hello"});
        return ({"data":{"comments":[Bensonhurst.cache("#{cache_keys[0]}"),{"content":"world"}]}});
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
        Bensonhurst.cache("#{cache_keys[0]}", {"name":"Cache"});
        return ({"data":{"post":Bensonhurst.cache("#{cache_keys[0]}")}});
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
        Bensonhurst.cache("#{cache_keys[0]}", ["a","b","c"]);
        return ({"data":{"content":Bensonhurst.cache("#{cache_keys[0]}")}});
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
        Bensonhurst.cache("#{cache_keys[0]}", {"id":1,"body":"post body 1","author":{"first_name":"David","last_name":"Heinemeier Hansson"}});
        return ({"data":{"post":Bensonhurst.cache("#{cache_keys[0]}")}});
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
        Bensonhurst.cache("#{cache_keys[0]}", {"id":1,"body":"hit","author":{"first_name":"John","last_name":"Smith"}});
        return ({"data":{"post":Bensonhurst.cache("#{cache_keys[0]}")}});
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
        Bensonhurst.cache("#{cache_keys[0]}", {"id":1,"body":"post body 1","author":{"first_name":"David","last_name":"Heinemeier Hansson"}});
        Bensonhurst.cache("#{cache_keys[1]}", {"id":2,"body":"post body 2","author":{"first_name":"Pavel","last_name":"Pravosud"}});
        Bensonhurst.cache("#{cache_keys[2]}", {"id":3,"body":"post body 3","author":{"first_name":"David","last_name":"Heinemeier Hansson"}});
        Bensonhurst.cache("#{cache_keys[3]}", {"id":4,"body":"post body 4","author":{"first_name":"Pavel","last_name":"Pravosud"}});
        Bensonhurst.cache("#{cache_keys[4]}", {"id":5,"body":"post body 5","author":{"first_name":"David","last_name":"Heinemeier Hansson"}});
        Bensonhurst.cache("#{cache_keys[5]}", {"id":6,"body":"post body 6","author":{"first_name":"Pavel","last_name":"Pravosud"}});
        Bensonhurst.cache("#{cache_keys[6]}", {"id":7,"body":"post body 7","author":{"first_name":"David","last_name":"Heinemeier Hansson"}});
        Bensonhurst.cache("#{cache_keys[7]}", {"id":8,"body":"post body 8","author":{"first_name":"Pavel","last_name":"Pravosud"}});
        Bensonhurst.cache("#{cache_keys[8]}", {"id":9,"body":"post body 9","author":{"first_name":"David","last_name":"Heinemeier Hansson"}});
        Bensonhurst.cache("#{cache_keys[9]}", {"id":10,"body":"post body 10","author":{"first_name":"Pavel","last_name":"Pravosud"}});
        return ({"data":[Bensonhurst.cache("#{cache_keys[0]}"),Bensonhurst.cache("#{cache_keys[1]}"),Bensonhurst.cache("#{cache_keys[2]}"),Bensonhurst.cache("#{cache_keys[3]}"),Bensonhurst.cache("#{cache_keys[4]}"),Bensonhurst.cache("#{cache_keys[5]}"),Bensonhurst.cache("#{cache_keys[6]}"),Bensonhurst.cache("#{cache_keys[7]}"),Bensonhurst.cache("#{cache_keys[8]}"),Bensonhurst.cache("#{cache_keys[9]}")]});
      })()
    JS

    assert_equal expected, result
  end
end
