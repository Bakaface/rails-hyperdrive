require "digest"
require "time"

module Rails
  module Hyperdrive
    # Builds and strips the provenance ("audit") header injected into every
    # installed artifact. The header records the source gem, a content hash of
    # the install-ready body, and an install timestamp.
    #
    # Two syntaxes, by file type:
    #
    #   Skills (frontmatter KEPT) — YAML comments inside the frontmatter:
    #     # hyperdrive: source=rails-hyperdrive-sidekiq@1.2.0
    #     # hyperdrive: sha256=ab12cd34...
    #     # hyperdrive: installed_at=2026-05-21T15:42:11Z
    #
    #   Guidelines + stack.md (NO frontmatter) — a leading HTML-comment block:
    #     <!-- hyperdrive: source=rails-hyperdrive-sidekiq@1.2.0 -->
    #     <!-- hyperdrive: sha256=ab12cd34... -->
    #     <!-- hyperdrive: installed_at=2026-05-21T15:42:11Z -->
    #
    # The sha256 is computed over the install-ready body *before* injection, so
    # `SHA256(strip(installed_file))` reproduces it exactly (see StackProfile /
    # lockfile drift detection).
    module AuditHeader
      YAML_LINE = /\A#\s*hyperdrive:/.freeze
      HTML_LINE = /\A<!--\s*hyperdrive:.*-->\s*\z/.freeze

      module_function

      # The three provenance fields, without comment syntax.
      def fields(source_gem:, version:, body:, installed_at: Time.now.utc)
        [
          "source=#{source_gem}@#{version}",
          "sha256=#{Digest::SHA256.hexdigest(body.to_s)}",
          "installed_at=#{installed_at.iso8601}"
        ]
      end

      # YAML-comment header block (skills — frontmatter kept).
      def build(source_gem:, version:, body:, installed_at: Time.now.utc)
        fields(source_gem: source_gem, version: version, body: body, installed_at: installed_at)
          .map { |f| "# hyperdrive: #{f}" }
          .join("\n")
      end

      # HTML-comment header block (guidelines + stack.md — no frontmatter).
      def build_html(source_gem:, version:, body:, installed_at: Time.now.utc)
        fields(source_gem: source_gem, version: version, body: body, installed_at: installed_at)
          .map { |f| "<!-- hyperdrive: #{f} -->" }
          .join("\n")
      end

      # Insert a YAML-comment block just before the closing `---` of the
      # frontmatter (skills). Falls back to wrapping the body in fresh
      # frontmatter when none exists.
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

      # Prepend an HTML-comment block to a frontmatter-less body
      # (guidelines + stack.md), separated by one blank line.
      def prepend_html(body, header_block)
        "#{header_block}\n\n#{body}"
      end

      # Inverse of the two builders: remove the injected provenance block and
      # return the original install-ready body. Recognizes both variants and
      # strips ONLY the contiguous injected block, never stray `# hyperdrive:`
      # or `<!-- -->` lines elsewhere.
      def strip(body)
        lines = body.lines
        if lines.first&.strip == "---"
          strip_yaml(lines)
        else
          strip_html(lines)
        end
      end

      # ---- internals ----

      # Remove the contiguous run of `# hyperdrive:` comment lines that lives
      # inside the frontmatter (between the opening and closing `---`).
      def strip_yaml(lines)
        closing_index = lines[1..].index { |l| l.strip == "---" }
        return lines.join unless closing_index

        absolute_closing = closing_index + 1
        first = (1...absolute_closing).find { |i| lines[i] =~ YAML_LINE }
        return lines.join unless first

        last = first
        last += 1 while last < absolute_closing && lines[last] =~ YAML_LINE
        (lines[0...first] + lines[last..]).join
      end

      # Remove the leading run of `<!-- hyperdrive: ... -->` lines plus the
      # single blank separator line that `prepend_html` inserted.
      def strip_html(lines)
        return lines.join unless lines.first =~ HTML_LINE

        i = 0
        i += 1 while lines[i] =~ HTML_LINE
        i += 1 if lines[i] && lines[i].strip.empty?
        lines[i..].join
      end
    end
  end
end
