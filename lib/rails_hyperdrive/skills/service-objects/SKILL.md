---
name: service-objects
description: Extract multi-step business workflows into single-purpose service objects with a clear Result return shape. Use when the user asks about "extracting a service", "controller too fat", "command pattern", "interactor", "Result/Either return", or "service vs model".
category: architecture
---

# Service Objects

A skill for organizing complex workflows in a Rails app using single-purpose service objects.

## When to apply

- A workflow spans 3+ models or has 3+ explicit steps with branching.
- The same workflow is invoked from multiple controllers, jobs, and rake tasks.
- A controller action exceeds ~30 lines or has multiple ActiveRecord transactions.
- The user says any of: "extract a service", "controller too fat", "command pattern", "interactor", "PORO".

## Shape

A service object in this codebase follows these rules:

1. **One public method**, conventionally `.call` (class method) or `#call` (instance after `.new`).
2. **Named by verb-noun**: `CreateInvoice`, `ChargeSubscription`, `ImportCsv`.
3. **Lives in `app/services/`** (or `app/services/<domain>/` for grouping).
4. **Returns a `Result`** value object with `success?`, `failure?`, `value`, `error`. Do not raise for expected failures; return `Result.failure(:reason, ...)`.
5. **Wraps its own transaction** if it touches multiple records. Outer callers should not need to wrap.
6. **Receives plain Ruby args**, not `params`. The controller's job is to translate.

```ruby
# app/services/charge_subscription.rb
class ChargeSubscription
  Result = Struct.new(:success?, :value, :error, keyword_init: true)

  def self.call(subscription:, amount_cents:)
    new(subscription: subscription, amount_cents: amount_cents).call
  end

  def initialize(subscription:, amount_cents:)
    @subscription = subscription
    @amount_cents = amount_cents
  end

  def call
    ActiveRecord::Base.transaction do
      charge = Stripe::Charge.create(...)
      payment = @subscription.payments.create!(charge_id: charge.id, amount_cents: @amount_cents)
      Result.new(success?: true, value: payment)
    end
  rescue Stripe::CardError => e
    Result.new(success?: false, error: e.message)
  end
end
```

## Anti-patterns to call out

- One service per controller action (`CreateUserService`, `UpdateUserService`, `DestroyUserService`) — that's just controller methods with extra steps. Default to the Rails way until the workflow earns its own object.
- Services that return raw booleans or `nil` on failure (caller can't tell what went wrong).
- Services that mutate `current_user` or other request-scoped state implicitly.
- "God services" with 10 public methods. Split them.
- Services that re-implement what `ActiveRecord::Base.transaction` + a model method does in 5 lines.

## Live introspection (via Rails Hyperdrive MCP)

- `locate_source ChargeSubscription.call` → see how an existing service is shaped
- `list_routes` → see which controllers exist before deciding what to extract
