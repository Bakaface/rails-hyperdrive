Rails.application.configure do
  config.cache_classes = false
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.active_record.migration_error = false if config.active_record.respond_to?(:migration_error=)
  config.hosts.clear if config.respond_to?(:hosts)
  config.logger = Logger.new($stderr)
  config.log_level = :warn
end
