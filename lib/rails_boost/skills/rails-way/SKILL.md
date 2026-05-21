---
name: rails-way
description: Apply DHH Rails canonical patterns — fat models / skinny controllers, RESTful resources, concerns for cross-cutting code, Active Record callbacks, defaults over configuration. Use when the user asks about "DHH way", "Rails canonical", "fat models skinny controllers", "RESTful resources", "concerns", or "defaults over config".
category: architecture
---

# The Rails Way

A skill for writing Ruby on Rails code in the canonical DHH style. Default to convention; reach for abstractions only when convention breaks.

## When to apply

- The user asks how to organize new code in a Rails app.
- The user asks "where should this live" for new behavior.
- The user invokes any of: "the Rails way", "DHH style", "convention over configuration", "RESTful", "fat model skinny controller", "concerns".

## Core principles

1. **Convention over configuration.** Filenames, class names, table names, route names all follow conventions. Do not deviate without a strong reason.
2. **Fat models, skinny controllers.** Business logic lives in the model. Controllers translate HTTP to model calls and pick a response.
3. **RESTful resources first.** Default to the seven standard actions (`index`, `show`, `new`, `create`, `edit`, `update`, `destroy`). Resist verb-routes; add nested resources or new resources instead.
4. **Concerns for cross-cutting code.** A concern is for behavior shared across models or controllers (e.g. `Trashable`, `Searchable`). It is not a junk drawer for cleaning up a fat class.
5. **Active Record callbacks are fine.** Use them for things that *always* must happen when a record changes (audit logs, denormalized counts). Do not fear them.
6. **Use the framework.** Reach for `delegated_type`, `enum`, `has_many :through`, `accepts_nested_attributes_for`, `attr_encrypted`, `signed_global_ids`, etc. before writing your own.

## Anti-patterns to call out

- Introducing `app/services/` to "thin the model" before the model is actually hard to navigate. A 500-line model is fine.
- Wrapping every controller action in a service object. Controllers are allowed to call models.
- Replacing scopes with query objects when a scope works.
- Hexagonal / clean architecture / repository pattern in a fresh app. Rails is opinionated for a reason.

## When to escape the Rails way

The Rails way is the default, not the law. Reach for explicit service / query / form objects when:

- A single model exceeds ~700 lines and grouping concerns no longer helps.
- A piece of business logic is invoked from 3+ controllers/jobs in materially different shapes.
- A workflow spans multiple models with non-trivial transactional boundaries.

In those cases, see the `service-objects`, `query-objects`, and `form-objects` skills.

## Live introspection (via Rails Boost MCP)

When in doubt about app structure:
- `list_models` → which models exist, what columns/associations they have
- `list_routes` → what the URL structure looks like
- `locate_source` → where a constant or method is defined
- `run_ruby` → check a hypothesis against the running app

Prefer reading the running app over guessing.
