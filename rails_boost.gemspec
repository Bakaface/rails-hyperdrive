require_relative "lib/rails_boost/version"

Gem::Specification.new do |spec|
  spec.name        = "rails_boost"
  spec.version     = Rails::Boost::VERSION
  spec.authors     = ["Bakaface"]
  spec.email       = ["afaceisnomore@gmail.com"]

  spec.summary     = "Dev-only Rails engine that bootstraps an MCP server + skills for AI coding agents."
  spec.description = <<~DESC
    Rails Boost mounts an MCP (Model Context Protocol) server at /_boost/mcp in development,
    exposing introspection tools for AI coding agents (eval Ruby, query DB, tail logs,
    list models/routes, locate source, fetch docs, snapshot stack). It also ships a
    `boost:init` generator that installs architecture skills and discovers per-gem skills
    shipped under a documented convention.
  DESC
  spec.homepage    = "https://github.com/Bakaface/rails-boost"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir[
    "lib/**/*",
    "config/**/*",
    "MIT-LICENSE",
    "LICENSE.txt",
    "Rakefile",
    "README.md",
    "SECURITY.md",
    "CHANGELOG.md"
  ].reject { |f| File.directory?(f) }

  spec.bindir        = "exe"
  spec.executables   = []
  spec.require_paths = ["lib"]

  spec.add_dependency "railties", ">= 7.2", "< 8.1"
  spec.add_dependency "activerecord", ">= 7.2", "< 8.1"
  spec.add_dependency "mcp", "~> 0.17"
  spec.add_dependency "tty-prompt", "~> 0.23"
  spec.add_dependency "bundler", ">= 2.3"
end
