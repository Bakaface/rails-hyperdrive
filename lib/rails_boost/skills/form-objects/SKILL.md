---
name: form-objects
description: Use ActiveModel-based form objects when a single form persists to multiple models or carries virtual attributes / validation contexts. Use when the user asks about "multi-model form", "ActiveModel::Model", "virtual attributes", or "validation context".
category: architecture
---

# Form Objects

A skill for handling forms that don't map 1:1 to a single Active Record model.

## When to apply

- A form persists data into 2+ Active Record models in one submit.
- A form has attributes that don't belong on any model (search filters, "confirm password", agreed-to-terms).
- A model needs *different* validations depending on context (sign-up vs. profile edit) and the context-arg dance has grown ugly.
- The user says any of: "multi-model form", "ActiveModel::Model", "virtual attributes", "form gets messy".

## Shape

Form objects in this codebase follow these rules:

1. **Live in `app/forms/`** and end in `Form`: `SignUpForm`, `OnboardingForm`.
2. **Include `ActiveModel::Model`** (and `ActiveModel::Attributes` for typed attrs in Rails 7+).
3. **Look like an AR model from the controller's perspective** — `form.assign_attributes(params); form.save`. Returns truthy on success, falsy + populates `form.errors` on failure.
4. **Own the transaction** when persisting to multiple models.

```ruby
# app/forms/sign_up_form.rb
class SignUpForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :email, :string
  attribute :password, :string
  attribute :company_name, :string
  attribute :agreed_to_terms, :boolean, default: false

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 12 }
  validates :company_name, presence: true
  validates :agreed_to_terms, acceptance: true

  attr_reader :user, :company

  def save
    return false unless valid?
    ActiveRecord::Base.transaction do
      @company = Company.create!(name: company_name)
      @user = @company.users.create!(email: email, password: password)
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.merge!(e.record.errors)
    false
  end
end
```

The view can call `form_with model: @form, url: sign_ups_path` and Rails picks up labels/errors via `ActiveModel::Naming`.

## Anti-patterns to call out

- Form objects that wrap a single AR model with no extra attributes. Use the model.
- Form objects that don't expose `errors` — the view can't render them.
- Putting business workflows (charging cards, sending emails) into the form. Save the records; let a service / callback handle side effects.

## Live introspection (via Rails Boost MCP)

- `list_models` → see which AR models the form needs to write to
- `list_routes` → identify which controller submits the form
- `locate_source SignUpForm#save` → see existing form patterns in this app
