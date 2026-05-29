require "json"
require_relative "smoke_helper"

# End-to-end smoke for `bin/rails hyperdrive:init` against three real Rails apps.
# Covers gaps the unit generator spec can't catch:
#   - bin/rails -> rake -> Thor argv plumbing
#   - engine rake-task loading (regression guard for double-load bug)
#   - StackProfile reading a real bundle-resolved Gemfile.lock
#   - Heuristic skill selection based on actual app/services|queries|forms dirs
RSpec.describe "hyperdrive:init smoke", :smoke do
  scenarios = {
    "minimal" => {
      expected_arch_skills: %w[rails-way],
      forbidden_arch_skills: %w[service-objects query-objects form-objects],
      stack_includes: ["Rails "],
      stack_excludes: %w[devise sidekiq pundit]
    },
    "services" => {
      expected_arch_skills: %w[rails-way service-objects],
      forbidden_arch_skills: %w[query-objects form-objects],
      stack_includes: ["Rails "],
      stack_excludes: %w[devise sidekiq pundit]
    },
    "full_stack" => {
      expected_arch_skills: %w[rails-way],
      forbidden_arch_skills: %w[service-objects query-objects form-objects],
      stack_includes: %w[devise sidekiq pundit],
      stack_excludes: []
    }
  }

  scenarios.each do |fixture, expected|
    context "with the #{fixture} fixture" do
      let(:app_dir) { Smoke.copy_fixture(fixture) }

      before do
        Smoke.add_path_gem!(app_dir)
        Smoke.bundle_install!(app_dir)
      end

      it "writes the expected files exactly once and mounts the engine" do
        out, status = Smoke.run_hyperdrive_init!(app_dir, "--yes")

        expect(status.success?).to be(true), "hyperdrive:init failed:\n#{out}"

        # Regression guard for the engine.rake_tasks double-load bug: the
        # "done  hyperdrive initialized" banner appears once iff the task
        # runs once. Two runs would print it twice.
        expect(out.scan("hyperdrive initialized").length).to eq(1), "hyperdrive:init ran more than once:\n#{out}"

        expect(File.exist?(File.join(app_dir, ".mcp.json"))).to be(true)
        expect(File.exist?(File.join(app_dir, "CLAUDE.md"))).to be(true)

        expected[:expected_arch_skills].each do |skill|
          path = File.join(app_dir, ".claude/skills", skill, "SKILL.md")
          expect(File.exist?(path)).to be(true), "expected #{path} to exist for #{fixture}"
        end

        expected[:forbidden_arch_skills].each do |skill|
          path = File.join(app_dir, ".claude/skills", skill, "SKILL.md")
          expect(File.exist?(path)).to be(false), "did NOT expect #{path} for #{fixture}"
        end

        mcp_json = JSON.parse(File.read(File.join(app_dir, ".mcp.json")))
        expect(mcp_json.dig("mcpServers", "rails-hyperdrive", "url")).to include("/_hyperdrive/mcp")

        claude_md = File.read(File.join(app_dir, "CLAUDE.md"))
        expected[:stack_includes].each do |tok|
          expect(claude_md).to include(tok), "CLAUDE.md missing #{tok.inspect}:\n#{claude_md}"
        end
        expected[:stack_excludes].each do |tok|
          expect(claude_md).not_to include(tok)
        end

        routes = File.read(File.join(app_dir, "config/routes.rb"))
        expect(routes).to include("Rails::Hyperdrive::Engine")
        expect(routes).to include("/_hyperdrive")

        # Idempotency: re-running should report "identical" and not duplicate
        # the mount.
        out2, status2 = Smoke.run_hyperdrive_init!(app_dir, "--yes")
        expect(status2.success?).to be(true), out2
        expect(out2).to include("identical")
        routes_after = File.read(File.join(app_dir, "config/routes.rb"))
        expect(routes_after.scan("Rails::Hyperdrive::Engine").length).to eq(1)
      end

      it "honors --dry-run" do
        out, status = Smoke.run_hyperdrive_init!(app_dir, "--yes", "--dry-run")
        expect(status.success?).to be(true), out
        expect(File.exist?(File.join(app_dir, ".mcp.json"))).to be(false)
        expect(File.exist?(File.join(app_dir, "CLAUDE.md"))).to be(false)
        routes = File.read(File.join(app_dir, "config/routes.rb"))
        expect(routes).not_to include("Rails::Hyperdrive::Engine")
      end
    end
  end
end
