namespace :hyperdrive do
  desc "Install Rails Hyperdrive into this app (writes .mcp.json, CLAUDE.md, skills, mounts engine)"
  task :init do
    require "rails/generators"
    require "generators/hyperdrive/install/install_generator"
    Rails::Generators::Hyperdrive::InstallGenerator.start(ARGV.drop(1))
  end
end
