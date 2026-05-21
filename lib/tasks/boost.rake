namespace :boost do
  desc "Install Rails Boost into this app (writes .mcp.json, CLAUDE.md, skills, mounts engine)"
  task :init do
    require "rails/generators"
    require "generators/rails_boost/install/install_generator"
    Rails::Generators::RailsBoost::InstallGenerator.start(ARGV.drop(1))
  end
end
