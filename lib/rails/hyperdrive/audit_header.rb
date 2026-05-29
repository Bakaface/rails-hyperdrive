require "digest"
require "time"

module Rails
  module Hyperdrive
    # Builds the audit header injected into a skill file installed from a
    # 3rd-party gem. The header lives inside the YAML frontmatter as comments
    # so it round-trips through skill parsers without breaking the schema:
    #
    #   # hyperdrive: source=sidekiq@7.3.4
    #   # hyperdrive: sha256=ab12cd34...
    #   # hyperdrive: installed_at=2026-05-21T15:42:11Z
    #
    module AuditHeader
      module_function

      def build(source_gem:, version:, body:, installed_at: Time.now.utc)
        sha = Digest::SHA256.hexdigest(body.to_s)
        [
          "# hyperdrive: source=#{source_gem}@#{version}",
          "# hyperdrive: sha256=#{sha}",
          "# hyperdrive: installed_at=#{installed_at.iso8601}"
        ].join("\n")
      end

      def inject_into_frontmatter(body, header_block)
        lines = body.lines
        unless lines.first&.strip == "---"
          return "---\n#{header_block}\n---\n\n#{body}"
        end

        closing_index = lines[1..].index { |l| l.strip == "---" }
        return body unless closing_index

        absolute_closing = closing_index + 1
        lines.insert(absolute_closing, header_block + "\n")
        lines.join
      end
    end
  end
end
