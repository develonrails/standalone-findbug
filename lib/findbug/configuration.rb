# frozen_string_literal: true

module Findbug
  class Configuration
    attr_accessor :enabled, :redis_url, :redis_pool_size, :redis_pool_timeout,
                  :sample_rate, :ignored_exceptions, :ignored_paths,
                  :performance_enabled, :performance_sample_rate,
                  :slow_request_threshold_ms, :slow_query_threshold_ms,
                  :scrub_fields, :scrub_headers, :scrub_header_names,
                  :retention_days, :max_buffer_size, :buffer_ttl,
                  :queue_name, :persist_batch_size, :persist_interval, :auto_persist,
                  :web_username, :web_password, :web_path,
                  :release, :environment, :logger

    attr_reader :alerts

    def initialize
      @enabled = true
      @redis_url = ENV.fetch("FINDBUG_REDIS_URL", "redis://localhost:6379/1")
      @redis_pool_size = ENV.fetch("FINDBUG_REDIS_POOL_SIZE", 5).to_i
      @redis_pool_timeout = 1
      @sample_rate = 1.0
      @ignored_exceptions = []
      @ignored_paths = []
      @performance_enabled = true
      @performance_sample_rate = 1.0
      @slow_request_threshold_ms = 0
      @slow_query_threshold_ms = 100
      @scrub_fields = %w[
        password password_confirmation secret secret_key secret_token
        api_key api_secret access_token refresh_token
        credit_card card_number cvv ssn social_security private_key
      ]
      @scrub_headers = true
      @scrub_header_names = []
      @retention_days = 30
      @max_buffer_size = 10_000
      @buffer_ttl = 86_400
      @queue_name = "findbug"
      @persist_batch_size = 100
      @persist_interval = 30
      @auto_persist = true
      @web_username = ENV["FINDBUG_USERNAME"]
      @web_password = ENV["FINDBUG_PASSWORD"]
      @web_path = "/"
      @alerts = AlertConfiguration.new
      @release = ENV["FINDBUG_RELEASE"]
      @environment = nil
      @logger = nil
    end

    def alerts
      if block_given?
        yield @alerts
      else
        @alerts
      end
    end

    def validate!
      raise ConfigurationError, "sample_rate must be between 0.0 and 1.0" unless sample_rate.between?(0.0, 1.0)
      raise ConfigurationError, "performance_sample_rate must be between 0.0 and 1.0" unless performance_sample_rate.between?(0.0, 1.0)
    end

    def web_enabled?
      web_username.present? && web_password.present?
    end
  end

  class AlertConfiguration
    attr_accessor :throttle_period

    def initialize
      @throttle_period = 300
    end
  end

  class ConfigurationError < StandardError; end
end
