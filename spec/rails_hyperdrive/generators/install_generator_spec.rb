require "spec_helper"
require "rails/generators"
require "rails/generators/testing/behavior"
require "generators/rails_hyperdrive/install/install_generator"
require "fileutils"
require "tmpdir"

RSpec.describe Rails::Generators::RailsHyperdrive::InstallGenerator do
  include Rails::Generators::Testing::Behavior
  include FileUtils

  destination File.expand_path("../../tmp/install_generator", __dir__)
  tests described_class

  def stub_rails_root(path)
    allow(::Rails).to receive(:root).and_return(Pathname.new(path))
  end

  before do
    prepare_destination
    @app_dir = destination_root
    FileUtils.mkdir_p(File.join(@app_dir, "config"))
    File.write(File.join(@app_dir, "config", "routes.rb"), "Rails.application.routes.draw do\nend\n")
    File.write(File.join(@app_dir, "Gemfile.lock"), File.read(File.expand_path("../../fixtures/gemfile_lock/standard.lock", __dir__)))
    stub_rails_root(@app_dir)
  end

  it "writes .mcp.json with the mount path" do
    run_generator(["--yes"])
    body = File.read(File.join(@app_dir, ".mcp.json"))
    expect(body).to include("/_hyperdrive/mcp")
  end

  it "writes CLAUDE.md interpolated with the StackProfile" do
    run_generator(["--yes"])
    body = File.read(File.join(@app_dir, "CLAUDE.md"))
    expect(body).to include("Rails 8.0.1")
  end

  it "installs the heuristic architecture skills" do
    run_generator(["--yes"])
    expect(File).to exist(File.join(@app_dir, ".claude/skills/rails-way/SKILL.md"))
  end

  it "mounts the engine in config/routes.rb" do
    run_generator(["--yes"])
    routes = File.read(File.join(@app_dir, "config/routes.rb"))
    expect(routes).to include("Rails::Hyperdrive::Engine")
    expect(routes).to include("/_hyperdrive")
  end

  it "is idempotent — re-running does not duplicate the mount" do
    run_generator(["--yes"])
    run_generator(["--yes"])
    routes = File.read(File.join(@app_dir, "config/routes.rb"))
    expect(routes.scan("Rails::Hyperdrive::Engine").length).to eq(1)
  end

  it "honors --dry-run by writing no files" do
    run_generator(["--yes", "--dry-run"])
    expect(File).not_to exist(File.join(@app_dir, ".mcp.json"))
    expect(File).not_to exist(File.join(@app_dir, "CLAUDE.md"))
    expect(File.read(File.join(@app_dir, "config/routes.rb"))).not_to include("Rails::Hyperdrive::Engine")
  end

  it "honors --skip-skills (no CLAUDE.md, no SKILL.md, still writes .mcp.json)" do
    run_generator(["--yes", "--skip-skills"])
    expect(File).to exist(File.join(@app_dir, ".mcp.json"))
    expect(File).not_to exist(File.join(@app_dir, ".claude/skills/rails-way/SKILL.md"))
    expect(File).not_to exist(File.join(@app_dir, "CLAUDE.md"))
  end

  it "honors --mount-at and writes the initializer when non-default" do
    run_generator(["--yes", "--mount-at", "/admin/hyperdrive"])
    body = File.read(File.join(@app_dir, ".mcp.json"))
    expect(body).to include("/admin/hyperdrive/mcp")
    routes = File.read(File.join(@app_dir, "config/routes.rb"))
    expect(routes).to include("/admin/hyperdrive")
    initializer = File.join(@app_dir, "config/initializers/rails_hyperdrive.rb")
    expect(File).to exist(initializer)
    expect(File.read(initializer)).to include('c.mount_at = "/admin/hyperdrive"')
  end

  it "does NOT write the initializer when --mount-at is the default" do
    run_generator(["--yes"])
    expect(File).not_to exist(File.join(@app_dir, "config/initializers/rails_hyperdrive.rb"))
  end

  it "refuses to run outside Rails.env.development? (no .mcp.json written)" do
    allow(::Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
    output = capture(:stderr) { run_generator(["--yes"]) }
    expect(output).to include("development").or include("refuse")
    expect(File).not_to exist(File.join(@app_dir, ".mcp.json"))
  end

  it "normalizes --mount-at without a leading slash" do
    run_generator(["--yes", "--mount-at", "hyperdrive"])
    body = File.read(File.join(@app_dir, ".mcp.json"))
    expect(body).to include("/hyperdrive/mcp")
  end

  it "strips a trailing slash from --mount-at" do
    run_generator(["--yes", "--mount-at", "/_hyperdrive/"])
    body = File.read(File.join(@app_dir, ".mcp.json"))
    expect(body).to include("/_hyperdrive/mcp")
    expect(body).not_to include("/_hyperdrive//mcp")
  end
end
