require_relative 'test_helper'

class EngineTest < ActiveSupport::TestCase
  test "does not include itself in action controller base when plumlinks auto include is false" do
    refute ActionController::Base.included_modules.any? { |m| m.name && m.name.include?('Plumlinks') }
  end
end