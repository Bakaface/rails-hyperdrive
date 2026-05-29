require "spec_helper"
require "rails/hyperdrive/lock_file"
require "tmpdir"

RSpec.describe Rails::Hyperdrive::LockFile do
  it "round-trips through YAML" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "lock.yml")
      lock = described_class.new(path)
      lock.claude_md_state = described_class::STATE_PRESENT
      lock.upsert(
        path: ".claude/hyperdrive/guidelines/jobs-sidekiq.md",
        artifact: "guideline",
        source: "rails-hyperdrive-sidekiq@1.2.0",
        source_sha: "ab12cd34",
        installed_at: "2026-05-29T14:22:08Z"
      )
      File.write(path, lock.to_yaml)

      reloaded = described_class.load(path)
      expect(reloaded.claude_md_state).to eq("present")
      entry = reloaded.entry(".claude/hyperdrive/guidelines/jobs-sidekiq.md")
      expect(entry[:source]).to eq("rails-hyperdrive-sidekiq@1.2.0")
      expect(entry[:source_sha]).to eq("ab12cd34")
      expect(reloaded.guideline_paths).to eq([".claude/hyperdrive/guidelines/jobs-sidekiq.md"])
      expect(reloaded.known?(".claude/hyperdrive/guidelines/jobs-sidekiq.md")).to be(true)
      expect(reloaded.known?(".claude/hyperdrive/guidelines/absent.md")).to be(false)
    end
  end

  it "recovers from a malformed lock file (returns empty state, never raises)" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "lock.yml")
      File.write(path, "files: [unterminated\n  : :\n")
      lock = nil
      expect { lock = described_class.load(path) }.not_to raise_error
      expect(lock.claude_md_state).to be_nil
      expect(lock.guideline_paths).to eq([])
    end
  end

  it "reports an absent lock as having no claude_md state" do
    lock = described_class.load("/no/such/lock.yml")
    expect(lock.claude_md_state).to be_nil
    expect(lock.exists?).to be(false)
  end

  it "defaults claude_md.state to present when serialized without one" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "lock.yml")
      yaml = described_class.new(path).to_yaml
      expect(yaml).to include("state: present")
    end
  end
end
