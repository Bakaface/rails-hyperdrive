module Rails
  module Generators
    module Hyperdrive
      # Shared helper for the install + discover generators: idempotently ensure
      # a single line exists in the app's `.gitignore`.
      #
      # Included as a module, so its methods are NOT registered as Thor commands
      # (Thor's `method_added` hook fires only for methods defined directly on
      # the generator class, not for inherited ones).
      module GitignoreSupport
        GITIGNORE = ".gitignore".freeze

        # Append `rule` to `.gitignore` unless it is already present. Ignores the
        # specific file/line — never the directory. Honors Thor's `pretend`.
        def ensure_gitignored(rule)
          abs = ::Rails.root.join(GITIGNORE)
          unless File.exist?(abs)
            create_file GITIGNORE, "#{rule}\n"
            return
          end

          body = File.read(abs)
          return if body.split("\n").any? { |line| line.strip == rule }

          prefix = body.end_with?("\n") || body.empty? ? "" : "\n"
          append_to_file GITIGNORE, "#{prefix}#{rule}\n"
        end
      end
    end
  end
end
