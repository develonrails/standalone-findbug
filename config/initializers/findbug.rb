# frozen_string_literal: true

Rails.application.config.after_initialize do
  Findbug.configure do |config|
  config.enabled = true
  config.redis_url = ENV.fetch("FINDBUG_REDIS_URL", "redis://localhost:6379/1")
  config.web_username = ENV["FINDBUG_USERNAME"]
  config.web_password = ENV["FINDBUG_PASSWORD"]
  config.retention_days = 30
  config.persist_batch_size = 100
  config.persist_interval = 30
  end
end
