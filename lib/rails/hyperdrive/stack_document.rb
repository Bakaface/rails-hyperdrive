require "yaml"
require_relative "stack_profile"

module Rails
  module Hyperdrive
    # Renders stack.md — rails-hyperdrive's own generated guideline, the only
    # content a zero-companion install produces. Body-only markdown (no YAML
    # frontmatter); the installer adds the HTML-comment audit header.
    #
    # Content = facts (Rails/Ruby/DB) + per-bucket steering (from
    # stack_steering.yml) + a trailing "## MCP tools" section.
    module StackDocument
      STEERING_PATH = File.expand_path("data/stack_steering.yml", __dir__)

      # Buckets are rendered in this fixed order.
      BUCKET_ORDER = %i[jobs auth authz test frontend].freeze

      MCP_TOOLS = <<~MD.freeze
        ## MCP tools
        - Prefer `run_ruby` for inspecting live state.
        - Use `run_sql` for read-only DB queries (SELECT/WITH/EXPLAIN/SHOW only).
        - Use `locate_source` to find where things are defined before guessing.
        - Use `list_models` and `list_routes` to map the app instead of grepping.
      MD

      module_function

      def steering_config
        @steering_config ||= YAML.load_file(STEERING_PATH) || {}
      end

      def labels
        steering_config["labels"] || {}
      end

      def steering
        steering_config["steering"] || {}
      end

      # Render the body-only markdown for the given StackProfile hash.
      def render(profile)
        lines = ["## Stack"]
        lines.concat(fact_lines(profile))
        BUCKET_ORDER.each do |bucket|
          line = bucket_line(bucket, profile[bucket] || [])
          lines << line if line
        end
        "#{lines.join("\n")}\n\n#{MCP_TOOLS}"
      end

      # ---- internals ----

      def fact_lines(profile)
        out = []
        if (v = profile.dig(:rails, :version))
          out << "- **Rails:** #{v}"
        end
        if (v = profile.dig(:ruby, :version))
          out << "- **Ruby:** #{v}"
        end
        if (a = profile.dig(:database, :adapter))
          out << "- **Database:** #{a}"
        end
        out
      end

      def bucket_line(bucket, entries)
        return nil if entries.empty?

        label = labels[bucket.to_s] || bucket.to_s.capitalize
        members = entries.map { |e| display_member(e) }

        if entries.size == 1
          gem_name = gem_name_for(entries.first)
          clause = steering[gem_name]
          base = "- **#{label}:** #{members.first}"
          clause ? "#{base} — #{clause}" : base
        else
          "- **#{label}:** #{members.join(", ")}"
        end
      end

      # "<gem> <version>" (or just "<gem>" when no single version is known,
      # e.g. the rolled-up hotwire entry).
      def display_member(entry)
        name = gem_name_for(entry)
        version = entry[:version]
        version ? "#{name} #{version}" : name
      end

      def gem_name_for(entry)
        entry[:key].to_s
      end
    end
  end
end
