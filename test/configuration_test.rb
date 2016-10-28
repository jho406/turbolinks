require_relative 'test_helper'

class ConfigurationTest < ActiveSupport::TestCase
  def restore_default_config
    Bensonhurst.configuration = nil
    Bensonhurst.configure {}
  end

  setup do
    restore_default_config
  end

  test 'configuration with an empty block defaults to application.js and application.css' do
    Bensonhurst.configure do |config|
    end

    track_assets = ['application.js', 'application.css']
    assert_equal track_assets, Bensonhurst.configuration.track_assets
  end

  test 'configuration with track_assets specified' do
    Bensonhurst.configure do |config|
      config.track_assets = ['app.js']
    end

    default_track_assets = ['app.js']
    assert_equal default_track_assets, Bensonhurst.configuration.track_assets
  end
end
