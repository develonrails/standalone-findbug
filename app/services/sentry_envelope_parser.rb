# frozen_string_literal: true

# SentryEnvelopeParser parses Sentry envelope format.
#
# The envelope format is newline-delimited:
#   Line 1: envelope header (JSON) — contains event_id, dsn, sdk info
#   Line 2: item header (JSON) — contains type, content_type
#   Line 3: item payload (JSON) — the actual event data
#   Line 4: next item header (if multiple items)
#   Line 5: next item payload
#   ...
#
class SentryEnvelopeParser
  def self.parse(raw_body)
    return [] if raw_body.blank?

    lines = raw_body.split("\n")
    return [] if lines.size < 3

    # First line is the envelope header
    _envelope_header = safe_parse(lines[0])

    items = []
    i = 1

    while i < lines.size
      # Item header
      item_header = safe_parse(lines[i])
      break unless item_header

      i += 1

      # Item payload — might be empty or span multiple lines
      # Check if item has a length field
      length = item_header["length"]

      if length && length > 0
        # Read exactly `length` bytes worth of payload
        payload_str = lines[i..].join("\n")[0, length]
        payload = safe_parse(payload_str)
        # Skip lines that make up this payload
        consumed = 0
        while i < lines.size && consumed < length
          consumed += lines[i].length + 1 # +1 for newline
          i += 1
        end
      else
        # No length specified — next line is the payload
        payload = safe_parse(lines[i]) if i < lines.size
        i += 1
      end

      next unless payload

      item_type = item_header["type"] || infer_type(payload)

      items << {
        type: item_type,
        payload: payload
      }
    end

    items
  end

  def self.safe_parse(json_str)
    return nil if json_str.blank?
    JSON.parse(json_str)
  rescue JSON::ParserError
    nil
  end

  def self.infer_type(payload)
    if payload["type"] == "transaction" || payload["transaction"].present?
      "transaction"
    elsif payload["exception"].present?
      "event"
    else
      "event"
    end
  end

  private_class_method :safe_parse, :infer_type
end
