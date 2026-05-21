require "mcp"

module Rails
  module Boost
    module Resources
      # boost://skills/{name} → the SKILL.md body installed at
      # .claude/skills/<name>/SKILL.md inside the host app.
      module Skill
        URI_TEMPLATE = "boost://skills/{name}"
        URI_PREFIX = "boost://skills/"
        # Skill names follow the SKILL.md/.claude convention: lowercase letters,
        # digits, hyphens. Anything else is rejected to prevent path traversal
        # via `boost://skills/../../etc/passwd`.
        NAME_PATTERN = /\A[a-z0-9][a-z0-9_\-]*\z/.freeze

        module_function

        def template
          ::MCP::ResourceTemplate.new(
            uri_template: URI_TEMPLATE,
            name: "Installed skill",
            description: "Markdown body of an installed .claude/skills/<name>/SKILL.md",
            mime_type: "text/markdown"
          )
        end

        # Enumerated once at server build time, so skills installed by a fresh
        # `boost:init` only appear after a dev-server restart.
        def installed_resources
          return [] unless defined?(::Rails) && ::Rails.respond_to?(:root) && ::Rails.root
          skills_root = ::Rails.root.join(".claude", "skills")
          return [] unless Dir.exist?(skills_root)
          Dir.glob(skills_root.join("*", "SKILL.md")).sort.map do |path|
            name = File.basename(File.dirname(path))
            next unless name.match?(NAME_PATTERN)
            ::MCP::Resource.new(
              uri: "#{URI_PREFIX}#{name}",
              name: name,
              description: "Skill: #{name}",
              mime_type: "text/markdown"
            )
          end.compact
        end

        def read(params)
          uri = params[:uri] || params["uri"]
          name = uri.to_s.sub(URI_PREFIX, "")
          unless name.match?(NAME_PATTERN)
            raise ::MCP::Server::RequestHandlerError.new(
              "Resource not found: #{uri}", params, error_type: :invalid_params
            )
          end
          path = ::Rails.root.join(".claude", "skills", name, "SKILL.md")
          unless File.exist?(path)
            raise ::MCP::Server::RequestHandlerError.new(
              "Resource not found: #{uri}", params, error_type: :invalid_params
            )
          end
          [{ uri: uri, mimeType: "text/markdown", text: File.read(path) }]
        end
      end
    end
  end
end
