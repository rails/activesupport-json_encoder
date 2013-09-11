require 'active_support/core_ext/kernel/reporting'

silence_warnings do
  Encoding.default_internal = "UTF-8"
  Encoding.default_external = "UTF-8"
end

require 'bundler/setup'
require 'minitest/autorun'
require 'active_support'
require 'active_support/test_case'
require 'active_support/testing/autorun'

Thread.abort_on_exception = true

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true
