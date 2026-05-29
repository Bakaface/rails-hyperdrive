require "mcp"
require "json"

module Rails
  module Hyperdrive
    module Tools
      class Base < ::MCP::Tool
        class << self
          def respond_text(text)
            ::MCP::Tool::Response.new([{ type: "text", text: text.to_s }])
          end

          def respond_json(object)
            respond_text(JSON.pretty_generate(object))
          end

          def respond_error(message)
            ::MCP::Tool::Response.new(
              [{ type: "text", text: message.to_s }],
              error: true
            )
          end

          # Defense in depth: the Rack middleware already gates the HTTP
          # transport; this catches direct in-process invocations (specs, rake
          # tasks) that bypass it.
          def with_dev_guard
            unless Rails::Hyperdrive.dev_mode?
              return respond_error("rails_hyperdrive tools are disabled outside Rails.env.development?")
            end
            yield
          rescue => e
            respond_error("#{e.class}: #{e.message}")
          end
        end
      end
    end
  end
end
