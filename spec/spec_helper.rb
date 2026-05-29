require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/lib/generators/hyperdrive/install/templates/"
end

ENV["RAILS_ENV"] ||= "development"

require "bundler/setup"
require "combustion"

Combustion.path = "spec/internal"

Combustion.initialize! :active_record

require "rspec/rails"
require "rack/test"
require "rails/hyperdrive"
require "rails/hyperdrive/mcp_server"

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    ::Rails::Hyperdrive::StackProfile.reset! if ::Rails::Hyperdrive::StackProfile.respond_to?(:reset!)
    ::Rails::Hyperdrive::McpServer.reset!
  end
end
