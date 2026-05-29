require "yaml"

module Rails
  module Hyperdrive
    # Reads and writes `.hyperdrive/lock.yml` — the git-tracked manifest that
    # records, per installed file, the source gem + version, the canonical
    # `source_sha` (SHA256 of the install-ready body, pre audit-header
    # injection), and an install timestamp. Also tracks the CLAUDE.md
    # injected-line opt-out state.
    #
    # `installed_at` is volatile metadata, never an input to any comparison.
    class LockFile
      SCHEMA_VERSION = 1
      STATE_PRESENT  = "present".freeze
      STATE_REMOVED  = "removed-by-user".freeze

      attr_reader :path
      attr_accessor :claude_md_state

      # Load existing lock state from disk (absent file → empty lock).
      def self.load(path)
        new(path).tap(&:read)
      end

      def initialize(path)
        @path = path.to_s
        @claude_md_state = nil # nil = no lock has been written yet
        @files = {}            # path(String) => entry Hash(symbol keys)
      end

      def read
        return self unless File.exist?(@path)

        data = YAML.safe_load(File.read(@path)) || {}
        @claude_md_state = data.dig("claude_md", "state")
        Array(data["files"]).each do |raw|
          entry = symbolize(raw)
          @files[entry[:path]] = entry if entry[:path]
        end
        self
      rescue Psych::SyntaxError
        self
      end

      def exists?
        File.exist?(@path)
      end

      def entry(file_path)
        @files[file_path.to_s]
      end

      def known?(file_path)
        @files.key?(file_path.to_s)
      end

      def guideline_paths
        @files.values.select { |e| e[:artifact] == "guideline" }.map { |e| e[:path] }
      end

      def each_entry(&block)
        @files.values.each(&block)
      end

      def upsert(path:, artifact:, source:, source_sha:, installed_at:)
        @files[path.to_s] = {
          path: path.to_s,
          artifact: artifact.to_s,
          source: source.to_s,
          source_sha: source_sha.to_s,
          installed_at: installed_at.to_s
        }
      end

      # Carry an existing entry forward unchanged (preserves installed_at).
      def carry(entry)
        return unless entry && entry[:path]
        @files[entry[:path]] = entry
      end

      def to_yaml
        {
          "version"   => SCHEMA_VERSION,
          "claude_md" => { "state" => (@claude_md_state || STATE_PRESENT) },
          "files"     => @files.values.sort_by { |e| e[:path] }.map { |e| stringify(e) }
        }.to_yaml
      end

      private

      def symbolize(raw)
        raw.each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
      end

      def stringify(entry)
        {
          "path"         => entry[:path],
          "artifact"     => entry[:artifact],
          "source"       => entry[:source],
          "source_sha"   => entry[:source_sha],
          "installed_at" => entry[:installed_at]
        }
      end
    end
  end
end
