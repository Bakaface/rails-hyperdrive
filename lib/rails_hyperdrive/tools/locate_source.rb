require_relative "base"

module Rails
  module Hyperdrive
    module Tools
      class LocateSource < Base
        tool_name "locate_source"
        description "Resolve a reference to file:line. Accepts 'Const#instance_method', 'Const.class_method', 'Const' (constant location), or 'dep:<gem>' (gem path)."

        input_schema(
          properties: {
            reference: { type: "string", description: "Reference to locate." }
          },
          required: ["reference"]
        )

        def self.call(reference:, server_context: nil)
          with_dev_guard do
            resolve(reference.to_s.strip)
          end
        end

        def self.resolve(reference)
          if reference.start_with?("dep:")
            return resolve_gem(reference.sub(/\Adep:/, ""), reference)
          end

          if reference.include?("#")
            klass_name, method = reference.split("#", 2)
            klass = constantize(klass_name)
            unless instance_method_defined?(klass, method)
              return respond_error("could not resolve: #{reference}")
            end
            file, line = klass.instance_method(method.to_sym).source_location
            file ? respond_text("#{file}:#{line}") : respond_error("could not resolve: #{reference}")
          elsif reference.include?(".")
            klass_name, method = reference.split(".", 2)
            klass = constantize(klass_name)
            unless klass.respond_to?(method, true)
              return respond_error("could not resolve: #{reference}")
            end
            file, line = klass.method(method.to_sym).source_location
            file ? respond_text("#{file}:#{line}") : respond_error("could not resolve: #{reference}")
          else
            owner_name, const_name = split_const(reference)
            owner = constantize(owner_name)
            return respond_error("could not resolve: #{reference}") unless owner.respond_to?(:const_source_location)
            location = owner.const_source_location(const_name)
            location && location.first ? respond_text("#{location[0]}:#{location[1]}") : respond_error("could not resolve: #{reference}")
          end
        rescue NameError
          respond_error("could not resolve: #{reference}")
        end

        def self.split_const(reference)
          if reference.include?("::")
            parts = reference.split("::")
            [parts[0..-2].join("::"), parts.last]
          else
            ["Object", reference]
          end
        end

        def self.instance_method_defined?(klass, method)
          sym = method.to_sym
          klass.instance_methods(true).include?(sym) ||
            klass.private_instance_methods(true).include?(sym)
        end

        def self.resolve_gem(name, reference)
          spec = Gem::Specification.find_all_by_name(name).first
          return respond_error("could not resolve: #{reference}") unless spec
          respond_text(spec.full_gem_path)
        end

        def self.constantize(name)
          if defined?(::ActiveSupport) && String.method_defined?(:constantize)
            name.constantize
          else
            name.split("::").inject(Object) { |m, c| m.const_get(c) }
          end
        end
      end
    end
  end
end
