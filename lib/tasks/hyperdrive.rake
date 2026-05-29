namespace :hyperdrive do
  desc "Install Rails Hyperdrive into this app (writes .mcp.json, CLAUDE.md, skills, guidelines, mounts engine)"
  task :init do
    require "rails/generators"
    require "generators/hyperdrive/install/install_generator"
    Rails::Generators::Hyperdrive::InstallGenerator.start(ARGV.drop(1))
  end

  desc "Re-sync Rails Hyperdrive content, force-overwriting locally-modified files"
  task :update do
    require "rails/generators"
    require "generators/hyperdrive/install/install_generator"
    Rails::Generators::Hyperdrive::InstallGenerator.start(ARGV.drop(1) + ["--update"])
  end

  desc "Suggest uninstalled rails-hyperdrive companion gems for this app's stack (networked, cached; pass --refresh to re-query)"
  task :discover do
    require "rails/generators"
    require "generators/hyperdrive/discover/discover_generator"
    Rails::Generators::Hyperdrive::DiscoverGenerator.start(ARGV.drop(1))
  end
end
