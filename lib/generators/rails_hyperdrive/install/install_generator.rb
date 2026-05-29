require "rails/generators"
require "rails/generators/base"
require "rails_hyperdrive"
require "rails_hyperdrive/stack_profile"
require "rails_hyperdrive/skill_discovery"
require "rails_hyperdrive/audit_header"

module Rails
  module Generators
    module RailsHyperdrive
      # Backs `bin/rails hyperdrive:init`.
      class InstallGenerator < ::Rails::Generators::Base
        SHIPPED_ARCH_SKILLS = %w[rails-way service-objects query-objects form-objects].freeze
        ENGINE_MOUNT_TOKEN = "Rails::Hyperdrive::Engine"
        DEFAULT_MOUNT_AT = "/_hyperdrive".freeze

        source_root File.expand_path("templates", __dir__)

        class_option :yes,          type: :boolean, default: false, desc: "Non-interactive: accept heuristic skill selection."
        class_option :mount_at,     type: :string,  default: DEFAULT_MOUNT_AT, desc: "Engine mount path."
        class_option :skip_skills,  type: :boolean, default: false, desc: "Skip writing any SKILL.md files and CLAUDE.md."
        class_option :dry_run,      type: :boolean, default: false, desc: "Show what would change; write nothing."
        class_option :force_install, type: :boolean, default: false, desc: "Overwrite existing files without prompting."

        def verify_environment
          unless defined?(::Rails) && ::Rails.respond_to?(:root) && ::Rails.root
            say_status :error, "must be run inside a Rails app", :red
            raise Thor::Error, "rails_hyperdrive: not in a Rails app"
          end
          unless ::Rails.respond_to?(:env) && ::Rails.env.development?
            env = ::Rails.respond_to?(:env) ? ::Rails.env.to_s : "unknown"
            warn "rails_hyperdrive: hyperdrive:init must run with Rails.env=development (current: #{env})"
            raise Thor::Error, "rails_hyperdrive: refuse to run outside development (Rails.env=#{env})"
          end
          # Thor's create_file / inject_into_file / template all honor
          # `options[:pretend]`. Translate our user-facing --dry-run to that.
          if options[:dry_run]
            self.options = options.merge(pretend: true).freeze
          end
        end

        def parse_stack_profile
          @stack_profile = ::Rails::Hyperdrive::StackProfile.from_lockfile(
            ::Rails.root.join("Gemfile.lock").to_s
          )
        end

        def heuristic_arch_selection
          @arch_default = ["rails-way"]
          @arch_default << "service-objects" if Dir.exist?(::Rails.root.join("app/services"))
          @arch_default << "query-objects"   if Dir.exist?(::Rails.root.join("app/queries"))
          @arch_default << "form-objects"    if Dir.exist?(::Rails.root.join("app/forms"))
        end

        def prompt_for_arch_skills
          if options[:skip_skills]
            @selected_arch_skills = []
            return
          end

          if options[:yes] || !$stdin.tty?
            @selected_arch_skills = @arch_default
            say_status :selected, "architecture skills: #{@selected_arch_skills.join(", ")}", :cyan
            return
          end

          require "tty-prompt"
          prompt = TTY::Prompt.new(quiet: true)
          choices = SHIPPED_ARCH_SKILLS.map do |name|
            { name: arch_label(name), value: name }
          end
          # TTY::Prompt raises Interrupt on Ctrl-C; we translate that into a
          # clean Thor::Error below so the generator exits without writing.
          @selected_arch_skills = prompt.multi_select(
            "Which architecture style does this app use? (space to toggle, enter to accept, ctrl-c to abort)",
            choices,
            default: @arch_default.map { |n| SHIPPED_ARCH_SKILLS.index(n) + 1 }
          )
        rescue LoadError
          say_status :warn, "tty-prompt not available, using heuristic selection", :yellow
          @selected_arch_skills = @arch_default
        rescue TTY::Reader::InputInterrupt, Interrupt
          say_status :abort, "user aborted; no files written", :red
          raise Thor::Error, "rails_hyperdrive: aborted by user"
        end

        def discover_gem_skills
          @discovered_gem_skills =
            if options[:skip_skills]
              []
            else
              ::Rails::Hyperdrive::SkillDiscovery.discover
            end
        end

        def write_mcp_json
          template "mcp.json.tt", ".mcp.json"
        end

        def write_claude_md
          return if options[:skip_skills]
          template "claude.md.tt", "CLAUDE.md"
        end

        def write_arch_skills
          return if options[:skip_skills]
          @selected_arch_skills.each do |name|
            src = File.expand_path("../../../rails_hyperdrive/skills/#{name}/SKILL.md", __dir__)
            dest = ".claude/skills/#{name}/SKILL.md"
            if File.exist?(src)
              create_file_if_changed(dest, File.read(src))
            end
          end
        end

        def write_gem_skills
          return if options[:skip_skills]
          @discovered_gem_skills.each do |skill|
            audit = ::Rails::Hyperdrive::AuditHeader.build(
              source_gem: skill.gem,
              version: skill.spec_version,
              body: skill.body
            )
            body = ::Rails::Hyperdrive::AuditHeader.inject_into_frontmatter(skill.body, audit)
            dest = ".claude/skills/#{skill.name}/SKILL.md"
            create_file_if_changed(dest, body)
            say_status :write, "#{dest}  (from #{skill.gem} #{skill.spec_version})", :green
          end
        end

        def write_initializer
          return if mount_path == DEFAULT_MOUNT_AT
          template "initializer.rb.tt", "config/initializers/rails_hyperdrive.rb"
        end

        def mount_engine
          routes_file = "config/routes.rb"
          unless File.exist?(::Rails.root.join(routes_file))
            say_status :skip, "no #{routes_file} found; skipping engine mount", :yellow
            return
          end

          contents = File.read(::Rails.root.join(routes_file))
          if contents.include?(ENGINE_MOUNT_TOKEN)
            say_status :identical, "#{routes_file} (engine already mounted)", :blue
            return
          end

          snippet = "  mount Rails::Hyperdrive::Engine => \"#{mount_path}\" if Rails.env.development?\n"
          inject_into_file routes_file, snippet, after: /Rails\.application\.routes\.draw do\s*\n/
        end

        def print_summary
          say ""
          say_status :done, "rails_hyperdrive initialized", :green
          say ""
          say "  Files:"
          say "    - .mcp.json"
          say "    - CLAUDE.md" unless options[:skip_skills]
          @selected_arch_skills&.each { |s| say "    - .claude/skills/#{s}/SKILL.md" }
          @discovered_gem_skills&.each { |s| say "    - .claude/skills/#{s.name}/SKILL.md  (#{s.gem} #{s.spec_version})" }
          say "    - config/initializers/rails_hyperdrive.rb" if mount_path != DEFAULT_MOUNT_AT
          say "  Mount: #{mount_path} (in config/routes.rb)"
          say ""
          say "  Next steps:"
          say "    1. bin/rails server"
          say "    2. Open Claude Code in this directory; it will read .mcp.json"
          say "    3. Verify the connection: curl http://localhost:3000#{mount_path}/mcp"
        end

        # ---------- helpers ----------

        no_tasks do
          # Normalize the user-supplied mount path:
          #   - prepend `/` if missing
          #   - strip any trailing `/` so `/_hyperdrive/` and `/_hyperdrive` are the same
          def mount_path
            raw = options[:mount_at].to_s
            raw = "/" + raw unless raw.start_with?("/")
            raw.length > 1 ? raw.chomp("/") : raw
          end

          def stack
            @stack_profile.to_h
          end

          def selected_arch_skills
            @selected_arch_skills || []
          end

          def discovered_gem_skills
            @discovered_gem_skills || []
          end

          def arch_label(name)
            extras = []
            extras << "(suggested: app/services/ found)" if name == "service-objects" && Dir.exist?(::Rails.root.join("app/services"))
            extras << "(suggested: app/queries/ found)"  if name == "query-objects"   && Dir.exist?(::Rails.root.join("app/queries"))
            extras << "(suggested: app/forms/ found)"    if name == "form-objects"    && Dir.exist?(::Rails.root.join("app/forms"))
            extras << "(DHH conventions)"                 if name == "rails-way"
            [name, *extras].join("  ")
          end

          # Write a file unless its on-disk content already matches; respects
          # --dry-run and --force.
          def create_file_if_changed(dest, body)
            abs = ::Rails.root.join(dest)
            if File.exist?(abs) && File.read(abs) == body
              say_status :identical, dest, :blue
              return
            end
            if File.exist?(abs) && !options[:force_install] && !options[:pretend]
              say_status :skip, "#{dest} (exists; pass --force-install to overwrite)", :yellow
              return
            end
            # `create_file` respects `options[:pretend]` automatically.
            create_file dest, body, force: options[:force_install]
          end
        end
      end
    end
  end
end
