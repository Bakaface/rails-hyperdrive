require_relative "base"

module Rails
  module Hyperdrive
    module Tools
      class ListModels < Base
        tool_name "list_models"
        description "List Active Record model classes with their columns, validations, and associations. Eager-loads the app first."

        input_schema(properties: {})

        def self.call(server_context: nil)
          with_dev_guard do
            ::Rails.application.eager_load!
            models = ActiveRecord::Base.descendants.reject(&:abstract_class?).sort_by(&:name)
            described = models.map do |m|
              describe(m)
            rescue StandardError => e
              # Collect per-model failures so one broken class doesn't blank out
              # the whole listing.
              { class: m.name, errors: ["#{e.class}: #{e.message}"] }
            end
            respond_json(described)
          end
        end

        def self.describe(model)
          {
            class: model.name,
            table: safe(model, :table_name),
            columns: safe_columns(model),
            validators: safe_validators(model),
            associations: safe_associations(model)
          }
        end

        def self.safe(model, method)
          model.public_send(method)
        rescue => e
          "<error: #{e.class}: #{e.message}>"
        end

        def self.safe_columns(model)
          return [] unless model.connected? || ActiveRecord::Base.connected?
          model.columns.map { |c| { name: c.name, type: c.type.to_s, null: c.null, default: c.default } }
        rescue => e
          [{ error: "#{e.class}: #{e.message}" }]
        end

        def self.safe_validators(model)
          model.validators.flat_map do |v|
            v.attributes.map do |attr|
              { attribute: attr.to_s, kind: v.kind.to_s, options: v.options.transform_values(&:to_s) }
            end
          end
        rescue
          []
        end

        def self.safe_associations(model)
          model.reflect_on_all_associations.map do |a|
            { name: a.name.to_s, macro: a.macro.to_s, class_name: safe_class_name(a) }
          end
        rescue
          []
        end

        def self.safe_class_name(association)
          association.class_name
        rescue
          nil
        end
      end
    end
  end
end
