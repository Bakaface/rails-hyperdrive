# Security Model

`rails_boost` is a **development-only** tool. Its security model is designed for a single developer running a Rails app on their own machine — nothing more. Read this before exposing your dev server to a network you don't fully control.

## Threat model in one paragraph

Rails Boost mounts an MCP server that exposes Ruby eval, raw SQL (read-only guardrail, not a sandbox), log tailing, and source-code introspection. It is intended to be reached from `http://localhost:3000/_boost/mcp` by a local AI coding agent (Claude Code) running on the same workstation. There is no authentication. If the dev server is reachable by another process, user, or host, that party can read everything in your Rails app and run arbitrary Ruby in your dev environment.

## Three layers of defense

All three layers key off `Rails::Boost.dev_mode?` (which is `Rails.env.development?`).

1. **Engine load-time warning.** The engine loads in any environment so a production process doesn't crash if `rails_boost` slips into the wrong Bundler group, but it logs a warning at boot when not in development.

2. **Rack middleware** (`Rails::Boost::Safety::RackMiddleware`) sits in front of the MCP transport on every request:
   - Returns `403` when `Rails.env` is not `development`.
   - Returns `403` when the `Origin` header is set and its host is not in the allowlist (`localhost`, `127.0.0.1`, `[::1]`). Requests with no `Origin` (e.g. `curl`, `Rack::Test`) pass through.

3. **Per-tool `with_dev_guard`** in `Rails::Boost::Tools::Base` catches direct in-process invocations (tests, rake tasks) that would bypass the transport entirely.

## What the Origin allowlist does and doesn't do

The allowlist blocks DNS-rebinding attacks: an attacker can't trick a victim's browser into POSTing JSON-RPC to `http://localhost:3000/_boost/mcp` from an attacker-controlled origin, because the browser would attach `Origin: http://evil.example` and we'd 403 it.

It does **not** authenticate anything. Any local process that can speak HTTP to your dev server can call every tool. If you run untrusted code on the same workstation, do not run `rails_boost`.

## What `run_sql` actually is

A best-effort regex-based gate that rejects mutating SQL at the parser level. It is **not** a sandbox. A determined attacker with `run_ruby` access can trivially bypass it (`run_ruby` runs arbitrary Ruby in the Rails process). The SQL guard exists to keep a confused AI from running `DELETE FROM users` by accident, not to enforce a privilege boundary.

## Network exposure is your responsibility

Rails Boost does not bind to a network interface — that is Puma's job. The default `bin/rails server` binding behavior varies by Rails version, operating system, and your `config/puma.rb`. To be safe:

- Bind Puma to `127.0.0.1` (the default in recent Rails versions), not `0.0.0.0`.
- Do not run `bin/rails server -b 0.0.0.0` on a network you share with untrusted parties.
- Do not forward port 3000 in Docker / `kubectl port-forward` / `ngrok` / Tailscale / VPN unless you understand who can reach it.

If you must expose the dev server, put it behind your own authenticating proxy and remove `rails_boost` from the bundle first.

## Reporting a vulnerability

Open a GitHub issue describing the impact. Do not include credentials or proprietary code. For sensitive reports, email the gem author listed in `rails_boost.gemspec`.
