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

  def test_redirect_to_returns_a_truthy_value
    get :redirect_to_and_return
    assert_redirected_to '/path'
  end

  def test_redirect_to_url_string_with_turbolinks
    get :redirect_to_url_string_with_turbolinks
    assert_turbolinks_visit 'http://example.com'
  end

  def test_redirect_to_url_hash_with_turbolinks
    get :redirect_to_url_hash_with_turbolinks
    assert_turbolinks_visit 'http://test.host/redirect/action'
  end

  def test_redirect_to_url_string_via_xhr_and_post_redirects_via_turbolinks
    xhr :post, :redirect_to_url_string
    assert_turbolinks_visit 'http://example.com'
  end

  def test_redirect_to_url_hash_via_xhr_and_put_redirects_via_turbolinks
    xhr :put, :redirect_to_url_hash
    assert_turbolinks_visit 'http://test.host/redirect/action'
  end

  def test_redirect_to_path_and_custom_status_via_xhr_and_delete_redirects_via_turbolinks
    xhr :delete, :redirect_to_path_and_custom_status
    assert_turbolinks_visit 'http://test.host/path'
  end

  def test_redirect_to_via_xhr_and_post_with_turbolinks_false_does_normal_redirect
    xhr :post, :redirect_to_path_with_turbolinks_false
    assert_redirected_to 'http://test.host/path'
  end

  def test_redirect_to_via_xhr_and_get_does_normal_redirect
    xhr :get, :redirect_to_path_and_custom_status
    assert_response 303
    assert_redirected_to 'http://test.host/path'
  end

  def test_redirect_to_via_post_and_not_xhr_does_normal_redirect
    post :redirect_to_url_hash
    assert_redirected_to 'http://test.host/redirect/action'
  end

  def test_redirect_to_via_put_and_not_xhr_does_normal_redirect
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
