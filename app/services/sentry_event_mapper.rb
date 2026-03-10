# frozen_string_literal: true

# SentryEventMapper translates Sentry SDK event fields to Findbug models.
#
# Sentry Field                          → Findbug Field
# exception.values[0].type              → exception_class
# exception.values[0].value             → message
# exception.values[0].stacktrace.frames → backtrace
# user, breadcrumbs, tags               → context (jsonb)
# request                               → request_data (jsonb)
# environment                           → environment
# release                               → release_version
# level                                 → severity
# fingerprint                           → fingerprint
# type: "transaction" + spans           → PerformanceEvent fields
# start_timestamp / timestamp           → duration_ms (calculated)
#
class SentryEventMapper
  # Map a Sentry error event to Findbug ErrorEvent data
  def self.map_error(payload, project_id: nil)
    exception = extract_exception(payload)
    exception_class = exception&.dig("type") || payload["logger"] || "UnknownError"
    message = exception&.dig("value") || payload["message"] || payload.dig("logentry", "message") || ""
    backtrace = extract_backtrace(exception)
    fingerprint = generate_fingerprint(payload, exception_class, message)

    {
      fingerprint: fingerprint,
      exception_class: exception_class,
      message: message.truncate(10_000),
      backtrace: backtrace,
      context: build_context(payload),
      request_data: payload["request"] || {},
      environment: payload["environment"],
      release: payload["release"],
      severity: map_severity(payload["level"]),
      source: "sentry_sdk",
      handled: extract_handled(payload),
      project_id: project_id
    }
  end

  # Map a Sentry transaction to Findbug PerformanceEvent data
  def self.map_transaction(payload, project_id: nil)
    start_ts = parse_timestamp(payload["start_timestamp"])
    end_ts = parse_timestamp(payload["timestamp"])
    duration_ms = ((end_ts - start_ts) * 1000).round(2)
    duration_ms = 0 if duration_ms.negative?

    # Extract span-level timing
    spans = payload["spans"] || []
    db_time_ms = calculate_span_time(spans, "db")
    view_time_ms = calculate_span_time(spans, "template")

    request_data = payload["request"] || {}

    {
      transaction_name: payload["transaction"] || "unknown",
      transaction_type: map_transaction_type(payload),
      request_method: request_data["method"],
      request_path: request_data["url"] || request_data["path_info"],
      duration_ms: duration_ms,
      db_time_ms: db_time_ms,
      view_time_ms: view_time_ms,
      query_count: count_db_spans(spans),
      slow_queries: extract_slow_queries(spans),
      n_plus_one_queries: detect_n_plus_one(spans),
      has_n_plus_one: detect_n_plus_one(spans).any?,
      context: build_context(payload),
      environment: payload["environment"],
      release: payload["release"],
      captured_at: Time.at(end_ts).utc,
      project_id: project_id
    }
  end

  class << self
    private

    def extract_exception(payload)
      values = payload.dig("exception", "values")
      return nil unless values.is_a?(Array)
      # Last exception in the chain is typically the most relevant
      values.last
    end

    def extract_backtrace(exception)
      return [] unless exception

      frames = exception.dig("stacktrace", "frames")
      return [] unless frames.is_a?(Array)

      # Sentry sends frames in reverse order (most recent last)
      frames.reverse.map do |frame|
        file = frame["filename"] || frame["abs_path"] || "unknown"
        line = frame["lineno"]
        func = frame["function"]
        "#{file}:#{line}:in `#{func}'"
      end
    end

    def generate_fingerprint(payload, exception_class, message)
      # Use Sentry's fingerprint if provided
      if payload["fingerprint"].is_a?(Array) && payload["fingerprint"] != [ "{{ default }}" ]
        return Digest::SHA256.hexdigest(payload["fingerprint"].join("|"))
      end

      # Default grouping: exception class + first backtrace line
      exception = extract_exception(payload)
      frames = exception&.dig("stacktrace", "frames")
      location = if frames.is_a?(Array) && frames.any?
                   frame = frames.last
                   "#{frame['filename']}:#{frame['lineno']}"
      else
                   ""
      end

      Digest::SHA256.hexdigest("#{exception_class}|#{location}")
    end

    def build_context(payload)
      context = {}
      context["user"] = payload["user"] if payload["user"].present?
      context["tags"] = payload["tags"] if payload["tags"].present?
      context["extra"] = payload["extra"] if payload["extra"].present?
      context["request"] = payload["request"] if payload["request"].present?

      if payload["breadcrumbs"].present?
        crumbs = payload.dig("breadcrumbs", "values") || payload["breadcrumbs"]
        context["breadcrumbs"] = crumbs if crumbs.is_a?(Array)
      end

      context["contexts"] = payload["contexts"] if payload["contexts"].present?
      context
    end

    def map_severity(level)
      case level.to_s.downcase
      when "fatal", "critical", "error" then "error"
      when "warning" then "warning"
      when "info", "debug", "log" then "info"
      else "error"
      end
    end

    def extract_handled(payload)
      exception = extract_exception(payload)
      mechanism = exception&.dig("mechanism")
      return false unless mechanism
      mechanism["handled"] != false
    end

    def map_transaction_type(payload)
      op = payload.dig("contexts", "trace", "op")
      case op
      when "http.server" then "request"
      when "queue.task", "queue.process" then "job"
      else "request"
      end
    end

    def calculate_span_time(spans, op_prefix)
      relevant = spans.select { |s| s["op"].to_s.start_with?(op_prefix) }
      relevant.sum do |span|
        start_ts = parse_timestamp(span["start_timestamp"])
        end_ts = parse_timestamp(span["timestamp"])
        ((end_ts - start_ts) * 1000).round(2)
      end
    end

    def count_db_spans(spans)
      spans.count { |s| s["op"].to_s.start_with?("db") }
    end

    def extract_slow_queries(spans, threshold_ms: 100)
      spans.select { |s| s["op"].to_s.start_with?("db") }
           .map do |span|
             duration = ((parse_timestamp(span["timestamp"]) - parse_timestamp(span["start_timestamp"])) * 1000).round(2)
             next nil if duration < threshold_ms
             { "duration_ms" => duration, "description" => span["description"].to_s.truncate(500) }
           end.compact.first(20)
    end

    def detect_n_plus_one(spans)
      # Group DB queries by their description (SQL pattern)
      db_spans = spans.select { |s| s["op"].to_s.start_with?("db") }
      grouped = db_spans.group_by { |s| normalize_query(s["description"].to_s) }

      grouped.filter_map do |query, occurrences|
        next if occurrences.size < 3 || query.blank?
        {
          "count" => occurrences.size,
          "example" => occurrences.first["description"].to_s.truncate(500)
        }
      end
    end

    # Sentry sends timestamps as either ISO 8601 strings or Unix floats
    def parse_timestamp(value)
      case value
      when Numeric then value.to_f
      when String
        if value.match?(/\A\d+(\.\d+)?\z/)
          value.to_f
        else
          Time.parse(value).to_f
        end
      else 0.0
      end
    end

    def normalize_query(sql)
      # Remove specific values to group similar queries
      sql.gsub(/\b\d+\b/, "?")
         .gsub(/'[^']*'/, "?")
         .gsub(/"[^"]*"/, "?")
         .strip
         .truncate(200)
    end
  end
end
