require_relative 'test_helper'

class TurbolinksController < TestController
  def simple_action
    render text: ' '
  end

  def redirect_to_same_origin
    redirect_to "#{request.protocol}#{request.host}/path"
  end

  def redirect_to_different_host
    redirect_to "#{request.protocol}foo.#{request.host}/path"
  end

  def redirect_to_different_protocol
    redirect_to "#{request.protocol == 'http://' ? 'https://' : 'http://'}#{request.host}/path"
  end

  def redirect_to_back
    redirect_to :back
  end

  def redirect_to_unescaped_path
    redirect_to "#{request.protocol}#{request.host}/foo bar"
  end
end

class TurbolinksTest < ActionController::TestCase
  tests TurbolinksController

  test "request referer returns xhr referer or standard referer" do
    @request.env['HTTP_REFERER'] = 'referer'
    assert_equal 'referer', @request.referer

    @request.env['HTTP_X_XHR_REFERER'] = 'xhr-referer'
    assert_equal 'xhr-referer', @request.referer
  end

  test "url for with back uses xhr referer when available" do
    @request.env['HTTP_REFERER'] = 'referer'
    assert_equal 'referer', @controller.view_context.url_for(:back)

    @request.env['HTTP_X_XHR_REFERER'] = 'xhr-referer'
    assert_equal 'xhr-referer', @controller.view_context.url_for(:back)
  end

  test "redirect to back uses xhr referer when available" do
    @request.env['HTTP_REFERER'] = 'http://test.host/referer'
    get :redirect_to_back
    assert_redirected_to 'http://test.host/referer'

    @request.env['HTTP_X_XHR_REFERER'] = 'http://test.host/xhr-referer'
    get :redirect_to_back
    assert_redirected_to 'http://test.host/xhr-referer'
  end

  test "sets request method cookie on non get requests" do
    post :simple_action
    assert_equal 'POST', cookies[:request_method]
    put :simple_action
    assert_equal 'PUT', cookies[:request_method]
  end

  test "pops request method cookie on get request" do
    cookies[:request_method] = 'TEST'
    get :simple_action
    assert_nil cookies[:request_method]
  end

  test "sets xhr redirected to header on redirect requests coming from turbolinks" do
    get :redirect_to_same_origin
    get :simple_action
    assert_nil @response.headers['X-XHR-Redirected-To']

    @request.env['HTTP_X_XHR_REFERER'] = 'http://test.host/'
    get :redirect_to_same_origin
    @request.env['HTTP_X_XHR_REFERER'] = nil
    get :simple_action
    assert_equal 'http://test.host/path', @response.headers['X-XHR-Redirected-To']
  end

  test "changes status to 403 on turbolinks requests redirecting to different origin" do
    get :redirect_to_different_host
    assert_response :redirect

    get :redirect_to_different_protocol
    assert_response :redirect

    @request.env['HTTP_X_XHR_REFERER'] = 'http://test.host'

    get :redirect_to_different_host
    assert_response :forbidden

    get :redirect_to_different_protocol
    assert_response :forbidden

    get :redirect_to_same_origin
    assert_response :redirect
  end

  test "handles invalid xhr referer on redirection" do
    @request.env['HTTP_X_XHR_REFERER'] = ':'
    get :redirect_to_same_origin
    assert_response :redirect
  end

  test "handles unescaped same origin location on redirection" do
    @request.env['HTTP_X_XHR_REFERER'] = 'http://test.host/'
    get :redirect_to_unescaped_path
    assert_response :redirect
  end

  test "handles unescaped different origin location on redirection" do
    @request.env['HTTP_X_XHR_REFERER'] = 'https://test.host/'
    get :redirect_to_unescaped_path
    assert_response :forbidden
  end
end

class TurbolinksIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @session = open_session
  end

  test "sets xhr redirected to header on redirect requests coming from turbolinks" do
    get '/redirect_hash'
    get response.location
    assert_nil response.headers['X-XHR-Redirected-To']

    get '/redirect_hash', nil, { 'HTTP_X_XHR_REFERER' => 'http://www.example.com/' }
    assert_response :redirect
    assert_nil response.headers['X-XHR-Redirected-To']

    get response.location, nil, { 'HTTP_X_XHR_REFERER' => nil }
    assert_equal 'http://www.example.com/turbolinks/simple_action', response.headers['X-XHR-Redirected-To']
    assert_response :ok

    get '/redirect_path', nil, { 'HTTP_X_XHR_REFERER' => 'http://www.example.com/' }
    assert_response :redirect
    assert_nil response.headers['X-XHR-Redirected-To']

    get response.location, nil, { 'HTTP_X_XHR_REFERER' => nil }
    assert_equal 'http://www.example.com/turbolinks/simple_action', response.headers['X-XHR-Redirected-To']
    assert_response :ok
  end
end
