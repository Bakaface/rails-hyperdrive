require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/lib/rails_boost/skills/"
  add_filter "/lib/generators/rails_boost/install/templates/"
end

ENV["RAILS_ENV"] ||= "development"

require "bundler/setup"
require "combustion"

Combustion.path = "spec/internal"

Combustion.initialize! :active_record

require "rspec/rails"
require "rack/test"
require "rails_boost"
require "rails_boost/mcp_server"

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    ::Rails::Boost::StackProfile.reset! if ::Rails::Boost::StackProfile.respond_to?(:reset!)
    ::Rails::Boost::McpServer.reset!
  end
end
