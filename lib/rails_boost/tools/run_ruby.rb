require_relative "base"
require_relative "../console_executor"

module Rails
  module Boost
    module Tools
      class RunRuby < Base
        tool_name "run_ruby"
        description "Eval Ruby in the booted Rails process with timeout and stdout/stderr capture. Returns { result, stdout, stderr, elapsed_ms, exception }."

        MAX_TIMEOUT_SECONDS = 120

        input_schema(
          properties: {
            code: { type: "string", description: "Ruby source to eval at TOPLEVEL_BINDING." },
            timeout: { type: "integer", description: "Timeout in seconds (default 30, max 120)." }
          },
          required: ["code"]
        )

        def self.call(code:, timeout: Rails::Boost::ConsoleExecutor::DEFAULT_TIMEOUT_SECONDS, server_context: nil)
          with_dev_guard do
            t = [[timeout.to_i, 1].max, MAX_TIMEOUT_SECONDS].min
            result = Rails::Boost::ConsoleExecutor.eval(code, timeout: t)
            respond_json(result.to_h)
          end
        end
      end
    end
  end
end
