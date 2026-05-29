require "spec_helper"
require "rails/hyperdrive/stack_document"

RSpec.describe Rails::Hyperdrive::StackDocument do
  def render(profile)
    described_class.render(profile)
  end

  it "renders plain facts for Rails, Ruby, and database" do
    md = render(rails: { version: "8.0.1" }, ruby: { version: "3.3.6" }, database: { adapter: "sqlite3" })
    expect(md).to include("- **Rails:** 8.0.1")
    expect(md).to include("- **Ruby:** 3.3.6")
    expect(md).to include("- **Database:** sqlite3")
  end

  it "appends a steering clause when a bucket has exactly one known gem" do
    md = render(jobs: [{ key: :sidekiq, version: "7.3.4" }])
    expect(md).to include("- **Background jobs:** sidekiq 7.3.4 — use `Sidekiq::Job`, not `ActiveJob` wrappers")
  end

  it "omits steering when a bucket is ambiguous (>1 gem)" do
    md = render(jobs: [{ key: :sidekiq, version: "7.3" }, { key: :good_job, version: "3.0" }])
    expect(md).to include("- **Background jobs:** sidekiq 7.3, good_job 3.0")
    expect(md).not_to include("Sidekiq::Job")
  end

  it "renders a fact line with no steering tail for a single gem lacking a clause" do
    md = render(jobs: [{ key: :resque, version: "2.0" }])
    expect(md).to include("- **Background jobs:** resque 2.0")
    expect(md).not_to include(" — ")
  end

  it "omits a bucket with no gems" do
    md = render(rails: { version: "8.0.1" }, jobs: [], auth: [])
    expect(md).not_to include("Background jobs")
    expect(md).not_to include("Authn")
  end

  it "always appends the MCP tools section" do
    md = render(rails: { version: "8.0.1" })
    expect(md).to include("## MCP tools")
    expect(md).to include("Prefer `run_ruby`")
    expect(md).to include("Use `list_models` and `list_routes`")
  end

  it "produces body-only markdown (no YAML frontmatter)" do
    expect(render(rails: { version: "8.0.1" })).not_to start_with("---")
  end
end
