require_relative 'test_helper'

class RenderController < TestController
  require 'action_view/testing/resolvers'

  append_view_path(ActionView::FixtureResolver.new(
    'render/action.js.bath' => 'json.author "john smith"',
    'render/action.html.erb' => 'john smith',
    'layouts/application.html.erb' => "<html><head><%=bensonhurst_tag%></head><body><%=yield%></body></html>"
  ))

  layout 'application'

  before_action do
    @_use_bensonhurst_html = false
  end

  before_action :use_bensonhurst_html, only: [:simple_render_with_bensonhurst]

  def render_action
    render :action
  end

  def simple_render_with_bensonhurst
    render :action
  end

  def render_action_with_bensonhurst_false
    render :action, bensonhurst: false
  end

  def form_authenticity_token
    "secret"
  end
end

class RenderTest < ActionController::TestCase
  tests RenderController


  setup do
    Bensonhurst.configuration.track_assets = ['app.js']
  end

  teardown do
    Bensonhurst.configuration.track_assets = []
  end

  test "render action via get" do
    get :render_action
    assert_normal_render 'john smith'
  end

  test "simple render with bensonhurst" do
    get :simple_render_with_bensonhurst
    assert_bensonhurst_html({author: "john smith"})
  end

  test "simple render with bensonhurst via get js" do
    @request.accept = 'application/javascript'
    get :simple_render_with_bensonhurst
    assert_bensonhurst_js({author: "john smith"})
  end

  test "render action via xhr and get js" do
    @request.accept = 'application/javascript'
    get :simple_render_with_bensonhurst, xhr: true
    assert_bensonhurst_js({author: "john smith"})
  end

  # test "render action via xhr and put js" do
  #   @request.accept = 'application/javascript'
  #   xhr :put, :simple_render_with_bensonhurst
  #   assert_bensonhurst_replace_js({author: "john smith"})
  # end

  test "render with bensonhurst false" do
    get :render_action_with_bensonhurst_false
    assert_normal_render("john smith")
  end

  test "render with bensonhurst false via xhr get" do
    @request.accept = 'text/html'
    get :render_action_with_bensonhurst_false, xhr: true
    assert_normal_render("john smith")
  end

  test "render action via xhr and put" do
    @request.accept = 'text/html'
    put :render_action, xhr: true
    assert_normal_render 'john smith'
  end

  private

  def assert_bensonhurst_html(content)
    assert_response 200
    assert_equal "<html><head><script type='text/javascript'>Bensonhurst.replace((function(){return ({\"data\":#{content.to_json},\"view\":\"RenderSimpleRenderWithBensonhurst\",\"csrf_token\":\"secret\",\"assets\":[\"/app.js\"]});})());</script></head><body></body></html>", @response.body
    assert_equal 'text/html', @response.content_type
  end

  def assert_bensonhurst_js(content)
    assert_response 200
    assert_equal '(function(){return ({"data":' + content.to_json + ',"view":"RenderSimpleRenderWithBensonhurst","csrf_token":"secret","assets":["/app.js"]});})()', @response.body
    assert_equal 'text/javascript', @response.content_type
  end

  def assert_bensonhurst_replace_js(content)
    assert_response 200
    assert_equal 'Bensonhurst.replace((function(){return ({"data":' + content.to_json + ',"csrf_token":"secret","assets":["/app.js"]});})());', @response.body
    assert_equal 'text/javascript', @response.content_type
  end

  def assert_normal_render(content)
    assert_response 200
    assert_equal "<html><head></head><body>#{content}</body></html>", @response.body
    assert_equal 'text/html', @response.content_type
  end
end
