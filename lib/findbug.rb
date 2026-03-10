# frozen_string_literal: true

module Findbug
  VERSION = "1.0.0"

  class Error < StandardError; end

  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield(config) if block_given?
      config.validate!
      config
    end

    def reset!
      @config = nil
      @logger = nil
    end

    def logger
      @logger ||= config.logger || (defined?(Rails) && Rails.logger) || Logger.new(IO::NULL)
    end

    def logger=(new_logger)
      @logger = new_logger
    end

    def enabled?
      config.enabled && config.redis_url.present?
    end
  end
end

# Submodules are autoloaded by Zeitwerk via config.autoload_lib
