require_relative 'test_helper'
require "action_view/testing/resolvers"
require "active_support/cache"

class JbuilderTest < ActionView::TestCase
  ActionView::Template.register_template_handler :jbuilder, JbuilderHandler

  module Rails
    def self.cache
      @cache ||= ActiveSupport::Cache::MemoryStore.new
    end
  end

  setup do
    self.request_forgery = false
    self.turbolinks = false

    Turbolinks.configuration.track_assets = []
    @context = self
    Rails.cache.clear
  end

  cattr_accessor :request_forgery, :turbolinks
  self.request_forgery = false

  def jbuild(source)
    partials = {}
    partials["test.js.jbuilder"] = source
    resolver = ActionView::FixtureResolver.new(partials)
    lookup_context.view_paths = [resolver]
    template = lookup_context.find('test')
    template.render(self, {}).strip
  end

  test "wrapping jbuilder contents inside Turbolinks" do
    self.turbolinks = {}
    result = jbuild(<<-TEMPLATE)
      json.content "hello"
    TEMPLATE

    assert_equal 'Turbolinks.replace({"data":{"content":"hello"}});', result
  end


  test "wrapping jbuilder contents inside Turbolinks with asset tracking" do
    Turbolinks.configuration.track_assets = ['test.js', 'test.css']
    self.turbolinks = {}

    result = jbuild(<<-TEMPLATE)
      json.content "hello"
    TEMPLATE
    assert_equal 'Turbolinks.replace({"data":{"content":"hello"},"turbolinks":{"assets":["/test.js","/test.css"]}});', result
  end

  test "including csrf token with request forgery" do
    self.request_forgery = true
    self.turbolinks = {}
    # csrf_meta_tags also delegate authenticity tokens to the controller
    # here we provide a simple mock to the context

    result = jbuild(<<-TEMPLATE)
      json.content "hello"
    TEMPLATE

    assert_equal 'Turbolinks.replace({"data":{"content":"hello"},"turbolinks":{"csrf_token":"secret"}});', result
  end

  test "wrapping jbuilder contents inside Turbolinks with additional options" do
    Turbolinks.configuration.track_assets = ['test.js', 'test.css']
    self.turbolinks = { title: 'this is fun' }

    result = jbuild(<<-TEMPLATE)
      json.content "hello"
    TEMPLATE
    assert_equal 'Turbolinks.replace({"data":{"content":"hello"},"turbolinks":{"title":"this is fun","assets":["/test.js","/test.css"]}});', result
  end

  test "jbuilder works as usual without turbolinks" do
    result = jbuild(<<-TEMPLATE)
      json.content "hello"
    TEMPLATE

    assert_equal '{"content":"hello"}', result
  end


  def protect_against_forgery?
    self.request_forgery
  end

  def form_authenticity_token
    "secret"
  end
end
