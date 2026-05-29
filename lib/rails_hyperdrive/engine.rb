require "rails/engine"

module Rails
  module Hyperdrive
    # Dev-only Rails engine that mounts the MCP server.
    #
    # The engine itself loads in any environment (so that running
    # `bin/rails console -e production` doesn't blow up if `rails_hyperdrive`
    # was accidentally added to a non-dev group). Actual request handling
    # is gated by `Rails::Hyperdrive::Safety::RackMiddleware`, which returns
    # 403 outside development.
    class Engine < ::Rails::Engine
      isolate_namespace Rails::Hyperdrive

      config.rails_hyperdrive = ActiveSupport::OrderedOptions.new
      config.rails_hyperdrive.mount_path = "/_hyperdrive"

      initializer "rails_hyperdrive.warn_outside_development" do
        unless Rails::Hyperdrive.dev_mode?
          msg = "[rails_hyperdrive] loaded outside development (Rails.env=#{::Rails.env}); MCP endpoints will return 403"
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
