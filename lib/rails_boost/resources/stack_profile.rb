require "mcp"
require "json"
require_relative "../stack_profile"

module Rails
  module Boost
    module Resources
      # boost://stack-profile → JSON of the resolved StackProfile.
      module StackProfile
        URI = "boost://stack-profile"

        module_function

        def resource
          ::MCP::Resource.new(
            uri: URI,
            name: "Stack Profile",
            description: "Parsed Gemfile.lock + categorization (rails, ruby, database, test, jobs, frontend, auth, authz, db_gems, gem_skills).",
            mime_type: "application/json"
          )
        end

        def read(_params)
          [{
            uri: URI,
            mimeType: "application/json",
            text: JSON.pretty_generate(Rails::Boost::StackProfile.current.to_h)
          }]
        end
      end
    end
  end
end
