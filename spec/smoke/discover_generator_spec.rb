require "json"
require_relative "smoke_helper"

# End-to-end smoke for `bin/rails hyperdrive:discover` (Stage B) against a real
# Rails app subprocess. Covers what the unit generator spec can't:
#   - bin/rails -> rake -> Thor argv plumbing (the `--` separator, --refresh)
#   - the discover_generator + companion_discovery require chain loading under
#     a real bundle
#   - a real Gemfile.lock read by CompanionDiscovery
#
# discover is the only networked command and ships dormant: no companion gems
# exist on rubygems under the `rails-hyperdrive-` prefix yet, so a live query
# returns an empty suggestion set. It is also resilient — offline / API-down /
# rate-limited paths fall back to "stale" or "unavailable" and still exit 0.
# We therefore assert only the network-invariant contract: it exits cleanly,
# gitignores its cache, and prints one of the recognized outcomes. We never
# assert on a specific live result, so the test stays deterministic regardless
# of network state.
RSpec.describe "hyperdrive:discover smoke", :smoke do
  let(:app_dir) { Smoke.copy_fixture("full_stack") }

  before do
    Smoke.add_path_gem!(app_dir)
    Smoke.bundle_install!(app_dir)
  end

  # Every terminal outcome discover can print, across online/offline/rate-limited.
  RECOGNIZED_OUTCOME = /no rails-hyperdrive companion gems found|Found gems with rails-hyperdrive|discovery unavailable|rubygems unreachable/

  it "runs end-to-end, exits cleanly, and gitignores its cache" do
    out, status = Smoke.run_hyperdrive_discover!(app_dir)

    expect(status.success?).to be(true), "hyperdrive:discover failed:\n#{out}"
    expect(out).to match(RECOGNIZED_OUTCOME), "unexpected discover output:\n#{out}"

    # The cache file is the one gitignored rails-hyperdrive artifact; ignore the
    # specific file, not the .hyperdrive/ directory (the lockfile stays tracked).
    gitignore = File.join(app_dir, ".gitignore")
    expect(File.exist?(gitignore)).to be(true)
    lines = File.read(gitignore).split("\n").map(&:strip)
    expect(lines).to include(".hyperdrive/discover_cache.json")
    expect(lines).not_to include(".hyperdrive/", ".hyperdrive")

    # discover never touches the Gemfile or installs content.
    expect(File.exist?(File.join(app_dir, ".mcp.json"))).to be(false)
    expect(File.exist?(File.join(app_dir, ".claude/hyperdrive/stack.md"))).to be(false)
    expect(File.read(File.join(app_dir, "Gemfile"))).not_to match(/rails-hyperdrive-/)
  end

  it "accepts --refresh through the rake/Thor argv plumbing" do
    out, status = Smoke.run_hyperdrive_discover!(app_dir, "--refresh")
    expect(status.success?).to be(true), "hyperdrive:discover --refresh failed:\n#{out}"
    expect(out).to match(RECOGNIZED_OUTCOME), "unexpected discover --refresh output:\n#{out}"
  end

  it "is idempotent — does not duplicate the .gitignore rule across runs" do
    Smoke.run_hyperdrive_discover!(app_dir)
    Smoke.run_hyperdrive_discover!(app_dir)
    occurrences = File.read(File.join(app_dir, ".gitignore")).scan(".hyperdrive/discover_cache.json").length
    expect(occurrences).to eq(1)
  end
end
