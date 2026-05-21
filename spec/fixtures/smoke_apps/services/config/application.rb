require_relative "boot"

require "rails"
require "active_record/railtie"
require "action_controller/railtie"

Bundler.require(*Rails.groups)

module SmokeApp
  class Application < Rails::Application
    config.load_defaults [Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f
    config.eager_load = false
    config.api_only = true
  end
end
