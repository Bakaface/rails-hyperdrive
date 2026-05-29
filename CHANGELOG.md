# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `hyperdrive:discover` — read-only, networked command that suggests uninstalled
  `rails-hyperdrive-*` companion gems for the app's stack. Queries the rubygems
  search API, matches each companion's declared `hyperdrive_targets` against
  `Gemfile.lock`, and prints the `bundle add` lines to run. Results cache to
  `.hyperdrive/discover_cache.json` (24h TTL; `--refresh` busts it); offline or
  rate-limited runs fall back to a stale cache or report "unavailable" without
  failing. Ships dormant — returns nothing until companion gems exist on rubygems.
- `hyperdrive:init` now adds a `.gitignore` rule for the discover cache.

## [0.1.0] - 2026-05-29

### Added

- Initial release of `rails-hyperdrive`: a dev-only Rails engine that mounts an MCP
  server at `/_hyperdrive/mcp` exposing introspection tools for AI coding agents.
- `hyperdrive:init` generator that installs architecture skills and auto-discovers
  per-gem skills.

[Unreleased]: https://github.com/Bakaface/rails-hyperdrive/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Bakaface/rails-hyperdrive/releases/tag/v0.1.0
