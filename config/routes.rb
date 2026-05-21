require "rails_boost/mcp_server"

Rails::Boost::Engine.routes.draw do
  mount Rails::Boost::McpServer.rack_app => "/mcp", as: :mcp
end
