# frozen_string_literal: true

module Findbug
  module Alerts
    module Channels
      class Email < Base
        def send_alert(error_event)
          recipients = config[:recipients]
          return if recipients.blank?

          if defined?(ActionMailer::Base)
            FindbugMailer.error_alert(error_event, recipients).deliver_later
          else
            Findbug.logger.warn("[Findbug] ActionMailer not available for email alerts")
          end
        end
      end
    end
  end
end
