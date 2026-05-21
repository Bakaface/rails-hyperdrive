require "rails/engine"

module Rails
  module Boost
    # Dev-only Rails engine that mounts the MCP server.
    #
    # The engine itself loads in any environment (so that running
    # `bin/rails console -e production` doesn't blow up if `rails_boost`
    # was accidentally added to a non-dev group). Actual request handling
    # is gated by `Rails::Boost::Safety::RackMiddleware`, which returns
    # 403 outside development.
    class Engine < ::Rails::Engine
      isolate_namespace Rails::Boost

      config.rails_boost = ActiveSupport::OrderedOptions.new
      config.rails_boost.mount_path = "/_boost"

      initializer "rails_boost.warn_outside_development" do
        unless Rails::Boost.dev_mode?
          msg = "[rails_boost] loaded outside development (Rails.env=#{::Rails.env}); MCP endpoints will return 403"
          if ::Rails.logger
            ::Rails.logger.warn(msg)
          else
            warn(msg)
          end
        end
      end

      # Rake tasks are picked up from lib/tasks/*.rake automatically by
      # Rails::Engine's task discovery; no explicit `rake_tasks` block.
      # Engine routes are picked up from config/routes.rb at the gem root by
      # Rails::Engine's `add_routing_paths` initializer.
    end
  end
end
