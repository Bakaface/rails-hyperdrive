require "stringio"
require "timeout"

module Rails
  module Boost
    module ConsoleExecutor
      DEFAULT_TIMEOUT_SECONDS = 30

      Result = Struct.new(:result, :stdout, :stderr, :elapsed_ms, :exception, keyword_init: true) do
        def to_h
          {
            result: result.inspect,
            stdout: stdout,
            stderr: stderr,
            elapsed_ms: elapsed_ms,
            exception: exception && {
              class: exception.class.name,
              message: exception.message,
              backtrace: Array(exception.backtrace).first(20)
            }
          }
        end
      end

      module_function

      def eval(code, timeout: DEFAULT_TIMEOUT_SECONDS)
        original_stdout = $stdout
        original_stderr = $stderr
        captured_out = StringIO.new
        captured_err = StringIO.new
        $stdout = captured_out
        $stderr = captured_err

        started_at = monotonic_now
        result = nil
        exception = nil

        begin
          ::Timeout.timeout(timeout.to_f) do
            result = TOPLEVEL_BINDING.eval(code, "(rails_boost run_ruby)", 1)
          end
        rescue Exception => e # rubocop:disable Lint/RescueException
          exception = e
        end

        Result.new(
          result: result,
          stdout: captured_out.string,
          stderr: captured_err.string,
          elapsed_ms: ((monotonic_now - started_at) * 1000).round,
          exception: exception
        )
      ensure
        $stdout = original_stdout
        $stderr = original_stderr
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
