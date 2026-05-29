require "rails/hyperdrive/mcp_server"

Rails::Hyperdrive::Engine.routes.draw do
  mount Rails::Hyperdrive::McpServer.rack_app => "/mcp", as: :mcp
end
