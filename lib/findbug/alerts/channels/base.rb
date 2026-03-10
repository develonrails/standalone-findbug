# frozen_string_literal: true

module Findbug
  module Alerts
    module Channels
      class Base
        attr_reader :config

        def initialize(config)
          @config = config
        end

        def send_alert(error_event)
          raise NotImplementedError, "#{self.class} must implement #send_alert"
        end

        protected

        def format_error_title(error_event)
          "[#{error_event.severity.upcase}] #{error_event.exception_class}"
        end

        def format_error_message(error_event)
          error_event.message.to_s.truncate(500)
        end

        def format_occurrence_info(error_event)
          error_event.occurrence_count > 1 ? "Occurred #{error_event.occurrence_count} times" : "First occurrence"
        end

        def error_url(error_event)
          base_url = ENV.fetch("FINDBUG_BASE_URL", nil)
          return nil unless base_url
          "#{base_url}/errors/#{error_event.id}"
        end
      end
    end
  end
end
