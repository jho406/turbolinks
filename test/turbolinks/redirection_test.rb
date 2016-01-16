require_relative 'test_helper'

class RedirectController < TestController
  def redirect_to_url_string
    redirect_to 'http://example.com'
  end

  def redirect_to_and_return
    redirect_to '/path' and return
    raise "redirect_to should return a truthy value"
  end

  def redirect_to_url_string_with_turbolinks
    redirect_to 'http://example.com', turbolinks: true
  end

  def redirect_to_url_hash
    redirect_to action: 'action'
  end

  def redirect_to_url_hash_with_turbolinks
    redirect_to({action: 'action'}, turbolinks: true)
  end

  def redirect_to_path_with_turbolinks_false
    redirect_to '/path', turbolinks: false
  end

  def redirect_to_path_and_custom_status
    redirect_to '/path', status: 303
  end
end

class RedirectionTest < ActionController::TestCase
  tests RedirectController

  test "redirect to returns a truthy value" do
    get :redirect_to_and_return
    assert_redirected_to '/path'
  end

  test "redirect to url string with turbolinks" do
    get :redirect_to_url_string_with_turbolinks
    assert_turbolinks_visit 'http://example.com'
  end

  test "redirect to url hash with turbolinks" do
    get :redirect_to_url_hash_with_turbolinks
    assert_turbolinks_visit 'http://test.host/redirect/action'
  end

  test "redirect to url string via xhr and post redirects via turbolinks" do
    xhr :post, :redirect_to_url_string
    assert_turbolinks_visit 'http://example.com'
  end

  test "test redirect to url hash via xhr and put redirects via turbolinks" do
    xhr :put, :redirect_to_url_hash
    assert_turbolinks_visit 'http://test.host/redirect/action'
  end

  test "redirect to path and custom status via xhr and delete redirects via turbolinks" do
    xhr :delete, :redirect_to_path_and_custom_status
    assert_turbolinks_visit 'http://test.host/path'
  end

  test "redirect to via xhr and post with turbolinks false does normal redirect" do
    xhr :post, :redirect_to_path_with_turbolinks_false
    assert_redirected_to 'http://test.host/path'
  end

  test "redirect to via xhr and get does normal redirect" do
    xhr :get, :redirect_to_path_and_custom_status
    assert_response 303
    assert_redirected_to 'http://test.host/path'
  end

  test "redirect to via post and not xhr does normal redirect" do
    post :redirect_to_url_hash
    assert_redirected_to 'http://test.host/redirect/action'
  end

  test "redirect to via put and not xhr does normal redirect" do
    put :redirect_to_url_string
    assert_redirected_to 'http://example.com'
  end

  private

  def assert_turbolinks_visit(url, change = nil)
    change = ", #{change}" if change
    assert_response 200
    assert_equal "Turbolinks.visit('#{url}'#{change});", @response.body
    assert_equal 'text/javascript', @response.content_type
  end
end
