# Rails Boost

> Dev-only Rails engine that bootstraps an MCP server + architecture skills for AI coding agents (Claude Code first).

Rails Boost mounts an [MCP (Model Context Protocol)](https://modelcontextprotocol.io) server at `http://localhost:3000/_boost/mcp` in development, exposing **8 introspection tools** so AI agents stop guessing — they can eval Ruby, query the DB (read-only), tail logs, list models and routes, locate source, fetch docs, and snapshot the stack.

It also ships a `boost:init` generator that installs **architecture skills** (Rails Way, Service Objects, Query Objects, Form Objects) and auto-discovers **per-gem skills** that 3rd-party gems ship under a documented convention.

Built on the official [`mcp` gem](https://github.com/modelcontextprotocol/ruby-sdk). MIT-licensed.

---

## Golden path

```bash
# 1. Add the dev gem
$ bundle add rails_boost --group=development

# 2. Run the generator
$ bin/rails boost:init

  detected: Rails 8.0.1, Ruby 3.3.6, Postgres, RSpec, Sidekiq, Hotwire
  detected gem-shipped skills: sidekiq (1), devise (1), pundit (1)

  Which architecture style does this app use?
    [x] rails-way            (DHH conventions)
    [ ] service-objects      (suggested: app/services/ found)
    [ ] query-objects
    [ ] form-objects
    > [Enter to accept, space to toggle, q to quit]

  wrote .mcp.json
  wrote CLAUDE.md
  wrote .claude/skills/rails-way/SKILL.md
  wrote .claude/skills/sidekiq-jobs/SKILL.md           (from sidekiq 7.3.4)
  wrote .claude/skills/devise-auth/SKILL.md            (from devise 4.9.4)
  wrote .claude/skills/pundit-authz/SKILL.md           (from pundit 2.4.0)
  mounted Rails::Boost::Engine at /_boost in config/routes.rb

  done.

# 3. Start the dev server
$ bin/dev

# 4. Open Claude Code in the project directory
# → Claude Code reads .mcp.json, connects to http://localhost:3000/_boost/mcp
# → agent has 8 tools + the installed skills + the stack-aware CLAUDE.md
```

---

## What ships

### MCP tools (8)

| # | Tool | Purpose |
|---|------|---------|
| 1 | `run_ruby` | Eval Ruby in the booted Rails process, with timeout + output capture |
| 2 | `run_sql` | Read-only SQL via the AR connection (refuses non-SELECT) |
| 3 | `tail_logs` | Tail recent lines from `log/development.log` |
| 4 | `list_models` | List Active Record model classes with columns/validations/associations |
| 5 | `locate_source` | Resolve `Const#method` / `Const.method` / `dep:<gem>` to a file:line |
| 6 | `lookup_doc` | Look up RDoc for a symbol (via `ri`) |
| 7 | `describe_app` | Snapshot: Rails/Ruby/DB versions + full `StackProfile` |
| 8 | `list_routes` | All routes: HTTP verb, path, controller#action, named route |

### Resources

- `boost://stack-profile` — JSON of the resolved `StackProfile`
- `boost://skills/{name}` — markdown body of each installed skill

### Architecture skills

`rails-way`, `service-objects`, `query-objects`, `form-objects` — written as `SKILL.md` files, installed into `.claude/skills/<name>/`.

### 3rd-party gem skill contract

A gem ships skills at:

```
<gem-source>/lib/<gem_name>/rails_boost/skills/<skill_name>[-v<major>]/SKILL.md
```

with required YAML frontmatter:

```yaml
---
name: sidekiq-jobs
description: Background job patterns for Sidekiq — idempotency, retries, perform_async/in/at.
gem: sidekiq
versions: "~> 7.0"
category: jobs
---
```

`boost:init` discovers all such files, version-matches each against the gem in the lockfile, installs the winner with an audit header naming `source`, `version`, `sha256`, and `installed_at`.

---

## Safety

Rails Boost is **dev-only**. The engine refuses to handle requests outside `Rails.env.development?` and enforces an origin allowlist (`localhost`, `127.0.0.1`). See [SECURITY.md](SECURITY.md).

---

## License

MIT — see [LICENSE.txt](LICENSE.txt).
