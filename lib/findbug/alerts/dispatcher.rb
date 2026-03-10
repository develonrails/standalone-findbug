# frozen_string_literal: true

module Findbug
  module Alerts
    class Dispatcher
      class << self
        def notify(error_event, async: true)
          return unless Findbug.enabled?
          return unless any_enabled?
          return unless should_alert?(error_event)
          return if throttled?(error_event)

          if async
            AlertJob.perform_later(error_event.id)
          else
            send_alerts(error_event)
          end
          record_alert(error_event)
        end

        def send_alerts(error_event)
          AlertChannel.enabled.find_each do |channel_record|
            channel_instance = channel_record.channel_class.new(channel_record.config.symbolize_keys)
            channel_instance.send_alert(error_event)
          rescue StandardError => e
            Findbug.logger.error("[Findbug] Failed to send alert to #{channel_record.name}: #{e.message}")
          end
        end

        def any_enabled?
          AlertChannel.enabled.exists?
        rescue StandardError
          false
        end

        private

        def should_alert?(error_event)
          return false if error_event.status == ErrorEvent::STATUS_IGNORED
          %w[error warning].include?(error_event.severity)
        end

        def throttled?(error_event)
          Throttler.throttled?(error_event.fingerprint)
        end

        def record_alert(error_event)
          Throttler.record(error_event.fingerprint)
        end
      end
    end
  end
end
