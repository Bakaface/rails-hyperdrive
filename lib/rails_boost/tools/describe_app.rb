require_relative "base"
require_relative "../stack_profile"

module Rails
  module Boost
    module Tools
      class DescribeApp < Base
        tool_name "describe_app"
        description "Snapshot of Rails/Ruby/DB versions plus the full StackProfile (test, jobs, frontend, auth, authz, db_gems, gem_skills)."

        input_schema(properties: {})

        def self.call(server_context: nil)
          with_dev_guard do
            respond_json(Rails::Boost::StackProfile.current.to_h)
          end
        end
      end
    end
  end
end
