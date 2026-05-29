---
name: query-objects
description: Encapsulate complex Active Record queries in dedicated query object classes. Use when the user asks about "complex AR query", "scope organization", "N+1", "includes/preload/eager_load", or "query encapsulation".
category: architecture
---

# Query Objects

A skill for organizing non-trivial Active Record queries in a Rails app.

## When to apply

- A query joins 3+ tables, or chains 4+ scopes, or has a window function.
- A scope is so long that callers no longer compose it.
- The same query (or near-variant) appears in 3+ places.
- The user says any of: "complex query", "extract a query object", "N+1 problem", "preload vs includes vs eager_load", "Arel".

## Shape

Query objects in this codebase follow these rules:

1. **Live in `app/queries/`** and end in `Query`: `ActiveCustomersQuery`, `OverduePaymentsQuery`.
2. **Initialized with a relation**, default `Model.all`. Composable with other query objects and scopes.
3. **Expose `#call`** returning an `ActiveRecord::Relation` (not an array — let callers chain).
4. **Do not paginate or load**. That's the caller's responsibility.
5. **Document the SQL shape** in a comment at the top.

```ruby
# app/queries/active_customers_query.rb
class ActiveCustomersQuery
  # Customers with at least one paid invoice in the last 90 days.
  # SQL: customers JOIN invoices ON ... WHERE invoices.paid_at > ?
  def initialize(relation = Customer.all)
    @relation = relation
  end

  def call
    @relation
      .joins(:invoices)
      .where(invoices: { paid_at: 90.days.ago.. })
      .distinct
  end
end

# Composes naturally with scopes:
ActiveCustomersQuery.new(Customer.in_region("eu")).call.order(:name).limit(50)
```

## N+1 guidance

When `list_models` shows associations being walked:
- `includes` for one-to-one access pattern (Rails picks preload or eager_load)
- `preload` for many associated rows (separate query)
- `eager_load` if you need to `WHERE` on the joined table
- `strict_loading: true` in dev to surface accidental N+1s

## Anti-patterns to call out

- Query objects that take `params` directly. Take a relation; let the controller / scope filter.
- Query objects that return arrays / counts. Return a relation.
- Replacing every `scope` with a query object. Scopes are fine; query objects are for what scopes can't express cleanly.
- Query objects that mutate (`.update_all`). That's a service object.

## Live introspection (via Rails Hyperdrive MCP)

- `run_sql "EXPLAIN SELECT ..."` → check the query plan before claiming an index is needed
- `list_models` → see what associations / indexes exist
- `run_ruby "User.where(active: true).explain"` → introspect actual generated SQL
