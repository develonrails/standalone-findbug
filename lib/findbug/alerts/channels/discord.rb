# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module Findbug
  module Alerts
    module Channels
      class Discord < Base
        def send_alert(error_event)
          webhook_url = config[:webhook_url]
          return if webhook_url.blank?
          post_to_webhook(webhook_url, build_payload(error_event))
        end

        private

        def build_payload(error_event)
          {
            username: config[:username] || "Findbug",
            avatar_url: config[:avatar_url],
            embeds: [ {
              title: error_event.exception_class.truncate(256),
              description: error_event.message.to_s.truncate(2048),
              color: severity_color_decimal(error_event.severity),
              url: error_url(error_event),
              fields: build_fields(error_event),
              footer: { text: "Findbug | #{error_event.environment}" },
              timestamp: error_event.last_seen_at.iso8601
            }.compact ]
          }.compact
        end

        def build_fields(error_event)
          fields = [
            { name: "Severity", value: error_event.severity.upcase, inline: true },
            { name: "Occurrences", value: error_event.occurrence_count.to_s, inline: true }
          ]
          if error_event.release_version
            fields << { name: "Release", value: error_event.release_version.to_s.truncate(100), inline: true }
          end
          if error_event.backtrace_lines.any?
            backtrace = error_event.backtrace_lines.first(5).join("\n")
            fields << { name: "Backtrace", value: "```\n#{backtrace.truncate(1000)}\n```", inline: false }
          end
          fields
        end

        def severity_color_decimal(severity)
          case severity
          when "error" then 14_423_100
          when "warning" then 16_761_095
          when "info" then 1_548_984
          else 7_107_965
          end
        end

        def post_to_webhook(webhook_url, payload)
          uri = URI.parse(webhook_url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == "https")
          http.open_timeout = 5
          http.read_timeout = 5
          request = Net::HTTP::Post.new(uri.path)
          request["Content-Type"] = "application/json"
          request.body = payload.to_json
          http.request(request)
        rescue StandardError => e
          Findbug.logger.error("[Findbug] Discord alert failed: #{e.message}")
        end
      end
    end
  end
end
