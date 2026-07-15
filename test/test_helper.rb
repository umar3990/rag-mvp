ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :webmock
  # Record a cassette once per test run if it doesn't exist yet; never
  # re-hit the real API for a cassette that's already there.
  config.default_cassette_options = { record: :once }

  # Strip real secrets out of recorded cassettes before they touch disk —
  # cassettes get committed, API keys must not.
  config.filter_sensitive_data("<ANTHROPIC_API_KEY>") { ENV["ANTHROPIC_API_KEY"] }
  config.filter_sensitive_data("<OPENAI_API_KEY>") { ENV["OPENAI_API_KEY"] }
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
