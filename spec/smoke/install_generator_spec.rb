require "json"
require_relative "smoke_helper"

# End-to-end smoke for `bin/rails hyperdrive:init` against three real Rails apps.
# Covers gaps the unit generator spec can't catch:
#   - bin/rails -> rake -> Thor argv plumbing
#   - engine rake-task loading (regression guard for double-load bug)
#   - StackProfile reading a real bundle-resolved Gemfile.lock
#   - the in-bundle artifact walk against a real Bundler.load.specs
#
# These apps ship no companion gems, so init is a zero-content install: it
# generates stack.md + index.md + the lockfile + the CLAUDE.md import line, and
# mounts the engine. Stack facts/steering live in stack.md, not CLAUDE.md.
RSpec.describe "hyperdrive:init smoke", :smoke do
  scenarios = {
    "minimal" => {
      stack_includes: ["**Rails:**"],
      stack_excludes: %w[devise sidekiq pundit]
    },
    "services" => {
      stack_includes: ["**Rails:**"],
      stack_excludes: %w[devise sidekiq pundit]
    },
    "full_stack" => {
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
        out, status = Smoke.run_hyperdrive_init!(app_dir)

        expect(status.success?).to be(true), "hyperdrive:init failed:\n#{out}"

        # Regression guard for the engine.rake_tasks double-load bug: the
        # "done  hyperdrive initialized" banner appears once iff the task
        # runs once. Two runs would print it twice.
        expect(out.scan("hyperdrive initialized").length).to eq(1), "hyperdrive:init ran more than once:\n#{out}"

        expect(File.exist?(File.join(app_dir, ".mcp.json"))).to be(true)
        expect(File.exist?(File.join(app_dir, "CLAUDE.md"))).to be(true)
        expect(File.exist?(File.join(app_dir, ".claude/hyperdrive/stack.md"))).to be(true)
        expect(File.exist?(File.join(app_dir, ".claude/hyperdrive/index.md"))).to be(true)
        expect(File.exist?(File.join(app_dir, ".hyperdrive/lock.yml"))).to be(true)

        # rails-hyperdrive ships no bundled skills; a clean app installs none.
        expect(Dir.exist?(File.join(app_dir, ".claude/skills"))).to be(false)

        mcp_json = JSON.parse(File.read(File.join(app_dir, ".mcp.json")))
        expect(mcp_json.dig("mcpServers", "rails-hyperdrive", "url")).to include("/_hyperdrive/mcp")

        # CLAUDE.md is user-owned and carries only the single import line.
        claude_md = File.read(File.join(app_dir, "CLAUDE.md"))
        expect(claude_md).to include("@.claude/hyperdrive/index.md")

        # index.md aggregates the generated stack guideline.
        expect(File.read(File.join(app_dir, ".claude/hyperdrive/index.md"))).to include("@stack.md")

        # Stack facts + steering live in the generated stack.md.
        stack_md = File.read(File.join(app_dir, ".claude/hyperdrive/stack.md"))
        expected[:stack_includes].each do |tok|
          expect(stack_md).to include(tok), "stack.md missing #{tok.inspect}:\n#{stack_md}"
        end
        expected[:stack_excludes].each do |tok|
          expect(stack_md).not_to include(tok)
        end

        routes = File.read(File.join(app_dir, "config/routes.rb"))
        expect(routes).to include("Rails::Hyperdrive::Engine")
        expect(routes).to include("/_hyperdrive")

        # Idempotency: re-running leaves files untouched and never duplicates
        # the mount.
        out2, status2 = Smoke.run_hyperdrive_init!(app_dir)
        expect(status2.success?).to be(true), out2
        expect(out2).to match(/identical|unchanged/)
        routes_after = File.read(File.join(app_dir, "config/routes.rb"))
        expect(routes_after.scan("Rails::Hyperdrive::Engine").length).to eq(1)
      end

      it "honors --dry-run" do
        out, status = Smoke.run_hyperdrive_init!(app_dir, "--dry-run")
        expect(status.success?).to be(true), out
        expect(File.exist?(File.join(app_dir, ".mcp.json"))).to be(false)
        expect(File.exist?(File.join(app_dir, "CLAUDE.md"))).to be(false)
        expect(File.exist?(File.join(app_dir, ".claude/hyperdrive/stack.md"))).to be(false)
        routes = File.read(File.join(app_dir, "config/routes.rb"))
        expect(routes).not_to include("Rails::Hyperdrive::Engine")
      end
    end
  end
end
