# frozen_string_literal: true

module Findbug
  module Processing
    class DataScrubber
      FILTERED = "[FILTERED]"
      CREDIT_CARD_PATTERN = /\b(?:\d{4}[-\s]?){3}\d{4}\b/
      SSN_PATTERN = /\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b/
      BEARER_TOKEN_PATTERN = /Bearer\s+[A-Za-z0-9\-_.~+\/]+=*/i

      class << self
        def scrub(event)
          deep_scrub(event)
        end

        def scrub_string(value)
          return value unless value.is_a?(String)
          value = value.dup
          value.gsub!(CREDIT_CARD_PATTERN, FILTERED)
          value.gsub!(SSN_PATTERN, FILTERED)
          value.gsub!(BEARER_TOKEN_PATTERN, "Bearer #{FILTERED}")
          value
        end

        private

        def deep_scrub(obj, path = [])
          case obj
          when Hash
            obj.each_with_object({}) do |(key, value), result|
              result[key] = sensitive_key?(key) ? FILTERED : deep_scrub(value, path + [ key ])
            end
          when Array
            obj.map.with_index { |item, i| deep_scrub(item, path + [ i ]) }
          when String
            scrub_string(obj)
          else
            obj
          end
        end

        def sensitive_key?(key)
          key_s = key.to_s.downcase
          scrub_fields.any? { |field| key_s.include?(field.downcase) }
        end

        def scrub_fields
          @scrub_fields ||= begin
            default_fields = %w[
              password passwd secret token api_key apikey access_key accesskey
              private_key privatekey credit_card creditcard card_number cardnumber
              cvv cvc ssn social_security authorization auth bearer cookie session csrf
            ]
            (default_fields + Findbug.config.scrub_fields.map(&:to_s)).uniq
          end
        end

        def reset!
          @scrub_fields = nil
        end
      end
    end
  end
end
