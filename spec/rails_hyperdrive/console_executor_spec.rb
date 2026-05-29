require "spec_helper"
require "rails_hyperdrive/console_executor"

RSpec.describe Rails::Hyperdrive::ConsoleExecutor do
  it "returns the eval result" do
    res = described_class.eval("1 + 2")
    expect(res.result).to eq(3)
    expect(res.exception).to be_nil
  end

  it "captures stdout separately from stderr" do
    res = described_class.eval(%q{puts "hi"; warn "bye"; nil})
    expect(res.stdout).to include("hi")
    expect(res.stderr).to include("bye")
  end

  it "captures exceptions without re-raising" do
    res = described_class.eval("raise ArgumentError, 'nope'")
    expect(res.exception).to be_a(ArgumentError)
    expect(res.exception.message).to eq("nope")
  end

  it "honors the timeout" do
    res = described_class.eval("sleep 5", timeout: 0.1)
    expect(res.exception).to be_a(Timeout::Error)
  end

  it "reports elapsed_ms as an integer" do
    res = described_class.eval("1")
    expect(res.elapsed_ms).to be_a(Integer)
    expect(res.elapsed_ms).to be >= 0
  end

  it "to_h shapes correctly for the MCP tool" do
    res = described_class.eval("42").to_h
    expect(res.keys).to include(:result, :stdout, :stderr, :elapsed_ms, :exception)
    expect(res[:result]).to eq("42") # inspected
  end
end
