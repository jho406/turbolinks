require_relative 'test_helper'

class RenderController < TestController
  require 'action_view/testing/resolvers'

  append_view_path(ActionView::FixtureResolver.new(
    'render/action.js.kbuilder' => 'json.author "john smith"',
    'render/action.html.erb' => 'john smith',
    'layouts/application.html.erb' => "<html><head><%=turbolinks_js_tag%></head><body><%=yield%></body></html>"
  ))

  layout 'application'

  def render_action
    render :action
  end

  def simple_render_with_turbolinks
    render :action, turbolinks: true
  end

  def render_action_with_turbolinks_false
    render :action, turbolinks: false
  end

  def form_authenticity_token
    "secret"
  end
end

class RenderTest < ActionController::TestCase
  tests RenderController


  setup do
    Turbolinks.configuration.track_assets = ['app.js']
  end

  teardown do
    Turbolinks.configuration.track_assets = []
  end

  def test_render_action_via_get
    get :render_action
    assert_normal_render 'john smith'
  end

  def test_simple_render_with_turbolinks
    get :simple_render_with_turbolinks
    assert_turbolinks_html({author: "john smith"})
  end

  def test_simple_render_with_turbolinks_via_get_js
    @request.accept = 'application/javascript'
    get :simple_render_with_turbolinks
    assert_turbolinks_js({author: "john smith"})
  end

  def test_render_action_via_xhr_and_get_js
    @request.accept = 'application/javascript'
    xhr :get, :simple_render_with_turbolinks
    assert_turbolinks_js({author: "john smith"})
  end

  def test_render_action_via_xhr_and_put_js
    @request.accept = 'application/javascript'
    xhr :put, :simple_render_with_turbolinks
    assert_turbolinks_js({author: "john smith"})
  end

  def test_render_with_turbolinks_false
    get :render_action_with_turbolinks_false
    assert_normal_render("john smith")
  end

  def test_render_with_turbolinks_false_via_xhr_get
    @request.accept = 'text/html'
    xhr :get, :render_action_with_turbolinks_false
    assert_normal_render("john smith")
  end

  def test_render_action_via_xhr_and_put
    @request.accept = 'text/html'
    xhr :put, :render_action
    assert_normal_render 'john smith'
  end

  private

  def assert_turbolinks_html(content)
    assert_response 200
    assert_equal "<html><head><script type='text/javascript'>Turbolinks.replace({\"data\":#{content.to_json},\"turbolinks\":{\"csrf_token\":\"secret\",\"assets\":[\"/app.js\"]}});</script></head><body></body></html>", @response.body
    assert_equal 'text/html', @response.content_type
  end

  def assert_turbolinks_js(content)
    assert_response 200
    assert_equal 'Turbolinks.replace({"data":' + content.to_json + ',"turbolinks":{"csrf_token":"secret","assets":["/app.js"]}});', @response.body
    assert_equal 'text/javascript', @response.content_type
  end

  def assert_normal_render(content)
    assert_response 200
    assert_equal "<html><head></head><body>#{content}</body></html>", @response.body
    assert_equal 'text/html', @response.content_type
  end
end
