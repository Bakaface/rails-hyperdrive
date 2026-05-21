# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`rails_boost` is a **dev-only Rails engine gem** that mounts an MCP (Model Context Protocol) server at `/_boost/mcp` exposing 8 introspection tools for AI coding agents, plus a `boost:init` generator that installs architecture skills and auto-discovers per-gem skills.

This is the gem itself, **not** an app that uses it. There is no host Rails app — specs boot a tiny in-memory app via Combustion at `spec/internal/`.

`README.md` describes the user-facing golden path.

## Commands

```bash
bin/setup                                          # bundle install
bundle exec rspec                                  # full suite (default rake task)
bundle exec rspec spec/rails_boost/tools_spec.rb   # single file
bundle exec rspec -e "name fragment"               # filter by example name
bundle exec rspec --tag smoke                      # opt-in end-to-end smoke (slow; ~60s first run)
bin/console                                        # IRB with rails_boost loaded

# CI matrix is Ruby {3.2, 3.3, 3.4} × Rails {7.2, 8.0}.
# Reproduce a specific slot locally:
RAILS_VERSION=7.2 bundle install && RAILS_VERSION=7.2 bundle exec rspec
```

Coverage is written to `coverage/` by SimpleCov (configured in `spec/spec_helper.rb`).

## Architecture

### Composition root

`lib/rails_boost/mcp_server.rb` is where everything wires together. It builds a single `MCP::Server` with the 8 tools and 2 resource families, then wraps the `StreamableHTTPTransport` in `Safety::RackMiddleware` and exposes it as a Rack app. The engine's `config/routes.rb` mounts that rack app at `/mcp`. `McpServer.reset!` exists for test isolation — singletons are intentional.

### Safety model (defense in depth)

Three layers, all keyed off `Rails::Boost.dev_mode?` (the single source of truth in `lib/rails_boost.rb`):

1. **Engine load-time warning** (`engine.rb`) — loads in any env so production boots don't blow up, just logs a warning.
2. **Rack middleware** (`safety/rack_middleware.rb`) — 403s every request outside `Rails.env.development?` or with an Origin outside the allowlist (`localhost`, `127.0.0.1`, `[::1]`).
3. **Per-tool `with_dev_guard`** (`tools/base.rb`) — catches direct invocations (tests, rake tasks) that bypass the transport.

When adding new tools, always inherit from `Tools::Base` and wrap the body in `with_dev_guard { ... }`. The block also rescues and shapes exceptions into `respond_error`.

SQL safety (`sql_safety.rb`) is a regex pair: an allowed-leader pattern (`SELECT`/`WITH...SELECT`/`EXPLAIN`/`SHOW`/`PRAGMA`) plus a forbidden-token denylist (to catch a `DELETE` smuggled inside a CTE). It is a **guardrail against accidental AI damage, not a sandbox** — the user has root on their dev DB.

### Shared state between generator and runtime

`StackProfile` (`lib/rails_boost/stack_profile.rb`) parses `Gemfile.lock` into a categorized stack snapshot. **Both** the `boost:init` generator (to render `CLAUDE.md`/`.mcp.json`) **and** the `describe_app` MCP tool / `boost://stack-profile` resource consume it. This is deliberate — installer and running server must not drift on what "this app's stack" means. Gem→category mapping lives in `lib/rails_boost/data/gem_categories.yml`.

### 3rd-party skill discovery contract

`SkillDiscovery` (`lib/rails_boost/skill_discovery.rb`) walks `Bundler.load.specs` looking for `<gem-source>/lib/<gem_name>/rails_boost/skills/**/SKILL.md` with required YAML frontmatter (`name`, `description`, `gem`, `versions`). It version-matches `versions` (a `Gem::Requirement` string) against the resolved spec and, when multiple variants exist (e.g. `dummy-v1/`, `dummy-v2/`), the **highest spec_version wins per `name:` key**.

`AuditHeader` (`lib/rails_boost/audit_header.rb`) then injects `source=<gem>@<version>`, `sha256=...`, and `installed_at=...` as YAML comments **inside** the skill's frontmatter (so the skill parser still sees a valid schema).

### Generator

`lib/generators/rails_boost/install/install_generator.rb` is invoked via `bin/rails boost:init` (wired by `lib/tasks/boost.rake`). Public flags: `--yes`, `--mount-at`, `--skip-skills`, `--dry-run` (translated to Thor's `pretend`), `--force-install`. Heuristic defaults look at `app/services`, `app/queries`, `app/forms`. Interactive prompts use `tty-prompt`; non-TTY or `--yes` falls through to the heuristic.

Bundled architecture skills live at `lib/rails_boost/skills/{rails-way,service-objects,query-objects,form-objects}/SKILL.md` and are copied to `.claude/skills/<name>/` in the host app.

## Test infrastructure

- **Combustion** (`spec/spec_helper.rb`) boots a real Rails app from `spec/internal/`. Schema is `spec/internal/db/schema.rb` (Users + Posts on SQLite).
- `ENV["RAILS_ENV"]` is forced to `"development"` in the spec helper because the engine middleware refuses anything else.
- `before(:each)` resets `StackProfile` and `McpServer` singletons — preserve this when adding new singletons.
- Generator specs write into `spec/tmp/install_generator/` (gitignored). 3rd-party skill discovery is exercised against `spec/fixtures/dummy_gem/`.
- **Smoke specs** (`spec/smoke/`, tagged `:smoke`, excluded by default in `.rspec`) shell out to a real `bin/rails boost:init` subprocess against fixture apps under `spec/fixtures/smoke_apps/{minimal,services,full_stack}/` and POST JSON-RPC to a booted server. Shared bundle cache lives at `spec/tmp/smoke-bundle/`. Run with `bundle exec rspec --tag smoke`. CI smoke job triggers on every push to `main`, on `workflow_dispatch`, or on PRs with the `run-smoke` label.

## Gemfile & dependency notes

- `Gemfile.lock` is **gitignored** — Bundler resolves fresh each install. CI keys its cache off `RAILS_VERSION` to avoid cross-slot bleed.
- Runtime deps: `railties`, `activerecord` (both `>= 7.2, < 8.1`), `mcp ~> 0.17`, `tty-prompt ~> 0.23`, `bundler >= 2.3`.
- License must stay MIT throughout, including transitive runtime deps — no Apache-licensed runtime additions.
