require "spec_helper"
require "rails_boost/skill_discovery"
require "rails_boost/audit_header"

RSpec.describe Rails::Boost::SkillDiscovery do
  let(:fixture_root) { File.expand_path("../fixtures/dummy_gem", __dir__) }
  let(:fake_spec) do
    instance_double(
      Gem::Specification,
      name: "dummy_gem",
      version: Gem::Version.new("1.4.2"),
      full_gem_path: fixture_root
    )
  end

  it "discovers skills shipped under the documented convention" do
    skills = described_class.discover(specs: [fake_spec])
    expect(skills.map(&:name)).to eq(["dummy-skill"])
  end

  it "picks the version-matching skill (1.x in, not 2.x)" do
    skill = described_class.discover(specs: [fake_spec]).first
    expect(skill.versions).to eq("~> 1.0")
    expect(skill.path).to include("dummy-v1")
  end

  it "rejects skills whose declared gem doesn't match the spec" do
    wrong_spec = instance_double(Gem::Specification,
      name: "other_gem", version: Gem::Version.new("1.0.0"), full_gem_path: fixture_root)
    expect(described_class.discover(specs: [wrong_spec])).to be_empty
  end

  it "returns an empty array when no skills are present" do
    empty_spec = instance_double(Gem::Specification,
      name: "x", version: Gem::Version.new("1.0.0"), full_gem_path: "/tmp/nope")
    expect(described_class.discover(specs: [empty_spec])).to be_empty
  end

  describe "audit header" do
    it "builds source/sha256/installed_at lines" do
      header = Rails::Boost::AuditHeader.build(
        source_gem: "sidekiq", version: "7.3.4", body: "hello"
      )
      expect(header).to include("source=sidekiq@7.3.4")
      expect(header).to match(/sha256=[a-f0-9]{64}/)
      expect(header).to match(/installed_at=\d{4}-\d{2}-\d{2}T/)
    end

    it "injects into existing frontmatter" do
      body = "---\nname: x\n---\n\nbody\n"
      header = "# rails_boost: foo=bar"
      result = Rails::Boost::AuditHeader.inject_into_frontmatter(body, header)
      expect(result).to match(/name: x\n# rails_boost: foo=bar\n---/)
    end
  end
end
