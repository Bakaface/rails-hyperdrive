require "yaml"
require "bundler"

module Rails
  module Hyperdrive
    # Discovers skills shipped by 3rd-party gems under the convention:
    #
    #   <gem-source>/lib/<gem_name>/rails_hyperdrive/skills/<skill_name>/SKILL.md
    #
    # Each SKILL.md must carry YAML frontmatter:
    #   name:        unique skill name
    #   description: free text used for Claude Code matching
    #   gem:         the source gem (must match spec.name)
    #   versions:    Gem::Requirement string (e.g. "~> 7.0")
    #   category:    optional, advisory
    #
    # Discovery iterates `Bundler.load.specs`, version-matches each candidate
    # against the resolved spec, and returns the highest-version winner per
    # `name:` key.
    module SkillDiscovery
      Skill = Struct.new(:name, :description, :gem, :versions, :category, :path, :body, :spec_version, keyword_init: true) do
        def to_h
          { name: name, description: description, gem: gem, versions: versions,
            category: category, path: path, spec_version: spec_version }
        end
      end

      module_function

      def discover(specs: nil)
        specs ||= safe_bundler_specs
        candidates = []

        specs.each do |spec|
          glob = File.join(spec.full_gem_path, "lib", spec.name, "rails_hyperdrive", "skills", "**", "SKILL.md")
          Dir.glob(glob).each do |path|
            skill = parse(path, spec: spec)
            candidates << skill if skill
          end
        end

        # Highest gem version wins per skill name; ties broken by path so the
        # outcome is deterministic when two variants share a version.
        candidates.group_by(&:name).map do |_name, group|
          group.max_by { |s| [Gem::Version.new(s.spec_version), s.path] }
        end
      end

      def parse(path, spec:)
        body = File.read(path)
        frontmatter, _rest = split_frontmatter(body)
        return nil unless frontmatter

        meta = YAML.safe_load(frontmatter, permitted_classes: [Symbol]) || {}
        name        = meta["name"]
        description = meta["description"]
        gem_name    = meta["gem"]
        versions    = meta["versions"]
        category    = meta["category"]

        return nil unless name && description && versions && gem_name
        return nil unless gem_name.to_s == spec.name.to_s
        return nil unless version_matches?(versions, spec.version)

        Skill.new(
          name: name,
          description: description.to_s,
          gem: gem_name.to_s,
          versions: versions.to_s,
          category: category&.to_s,
          path: path,
          body: body,
          spec_version: spec.version.to_s
        )
      rescue Psych::SyntaxError
        nil
      end

      def split_frontmatter(body)
        lines = body.lines
        return [nil, body] unless lines.first&.strip == "---"

        closing_index = lines[1..].index { |l| l.strip == "---" }
        return [nil, body] unless closing_index

        absolute_closing = closing_index + 1
        [lines[1...absolute_closing].join, lines[(absolute_closing + 1)..].join]
      end

      def version_matches?(requirement_str, version)
        Gem::Requirement.new(*Array(requirement_str)).satisfied_by?(Gem::Version.new(version.to_s))
      rescue ArgumentError
        false
      end

      def safe_bundler_specs
        ::Bundler.load.specs.to_a
      rescue ::Bundler::GemfileNotFound, ::Bundler::BundlerError
        []
      end
    end
  end
end
