require_relative 'test_helper'

class RenderController < TestController
  require 'action_view/testing/resolvers'

  append_view_path(ActionView::FixtureResolver.new(
    'render/action.js.plum' => 'json.author "john smith"',
    'render/action.html.erb' => 'john smith',
    'layouts/application.html.erb' => "<html><head><%=plumlinks_tag%></head><body><%=yield%></body></html>"
  ))

  layout 'application'
  before_action :use_plumlinks_html, only: [:simple_render_with_plumlinks]

  def render_action
    render :action
  end

  def simple_render_with_plumlinks
    render :action
  end

  def render_action_with_plumlinks_false
    render :action, plumlinks: false
  end

  def form_authenticity_token
    "secret"
  end
end

class RenderTest < ActionController::TestCase
  tests RenderController


  setup do
    Plumlinks.configuration.track_assets = ['app.js']
  end

  teardown do
    Plumlinks.configuration.track_assets = []
  end

  test "render action via get" do
    get :render_action
    assert_normal_render 'john smith'
  end

  test "simple render with plumlinks" do
    get :simple_render_with_plumlinks
    assert_plumlinks_html({author: "john smith"})
  end

  test "simple render with plumlinks via get js" do
    @request.accept = 'application/javascript'
    get :simple_render_with_plumlinks
    assert_plumlinks_js({author: "john smith"})
  end

  test "render action via xhr and get js" do
    @request.accept = 'application/javascript'
    xhr :get, :simple_render_with_plumlinks
    assert_plumlinks_js({author: "john smith"})
  end

  # test "render action via xhr and put js" do
  #   @request.accept = 'application/javascript'
  #   xhr :put, :simple_render_with_plumlinks
  #   assert_plumlinks_replace_js({author: "john smith"})
  # end

  test "render with plumlinks false" do
    get :render_action_with_plumlinks_false
    assert_normal_render("john smith")
  end

  test "render with plumlinks false via xhr get" do
    @request.accept = 'text/html'
    xhr :get, :render_action_with_plumlinks_false
    assert_normal_render("john smith")
  end

  test "render action via xhr and put" do
    @request.accept = 'text/html'
    xhr :put, :render_action
    assert_normal_render 'john smith'
  end

  private

  def assert_plumlinks_html(content)
    assert_response 200
    assert_equal "<html><head><script type='text/javascript'>Plumlinks.replace((function(){return ({\"data\":#{content.to_json},\"view\":\"RenderSimpleRenderWithPlumlinks\",\"csrf_token\":\"secret\",\"assets\":[\"/app.js\"]});})());</script></head><body></body></html>", @response.body
    assert_equal 'text/html', @response.content_type
  end

  def assert_plumlinks_js(content)
    assert_response 200
    assert_equal '(function(){return ({"data":' + content.to_json + ',"view":"RenderSimpleRenderWithPlumlinks","csrf_token":"secret","assets":["/app.js"]});})()', @response.body
    assert_equal 'text/javascript', @response.content_type
  end

  def assert_plumlinks_replace_js(content)
    assert_response 200
    assert_equal 'Plumlinks.replace((function(){return ({"data":' + content.to_json + ',"csrf_token":"secret","assets":["/app.js"]});})());', @response.body
    assert_equal 'text/javascript', @response.content_type
  end

  def assert_normal_render(content)
    assert_response 200
    assert_equal "<html><head></head><body>#{content}</body></html>", @response.body
    assert_equal 'text/html', @response.content_type
  end
end
