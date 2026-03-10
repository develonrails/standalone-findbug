# frozen_string_literal: true

module Api
  # IngestController receives error and performance data from Sentry SDKs.
  #
  # Endpoints:
  #   POST /api/:project_id/store/    — legacy event format
  #   POST /api/:project_id/envelope/ — modern envelope format (used by sentry-rails)
  #
  class IngestController < ActionController::API
    before_action :authenticate_dsn!
    before_action :decompress_body

    # POST /api/:project_id/envelope/
    def envelope
      items = SentryEnvelopeParser.parse(@raw_body)

      items.each do |item|
        case item[:type]
        when "event", "error"
          event_data = SentryEventMapper.map_error(item[:payload], project_id: @project.id)
          Findbug::Storage::RedisBuffer.push_error(event_data)
        when "transaction"
          event_data = SentryEventMapper.map_transaction(item[:payload], project_id: @project.id)
          Findbug::Storage::RedisBuffer.push_performance(event_data)
        end
      end

      render json: { id: SecureRandom.uuid }, status: :ok
    end

    # POST /api/:project_id/store/
    def store
      payload = JSON.parse(@raw_body)

      if payload["type"] == "transaction"
        event_data = SentryEventMapper.map_transaction(payload, project_id: @project.id)
        Findbug::Storage::RedisBuffer.push_performance(event_data)
      else
        event_data = SentryEventMapper.map_error(payload, project_id: @project.id)
        Findbug::Storage::RedisBuffer.push_error(event_data)
      end

      render json: { id: payload["event_id"] || SecureRandom.uuid }, status: :ok
    rescue JSON::ParserError => e
      render json: { error: "Invalid JSON: #{e.message}" }, status: :bad_request
    end

    private

    # Authenticate via DSN key in URL or X-Sentry-Auth header
    def authenticate_dsn!
      dsn_key = extract_dsn_key
      project_id = params[:project_id]

      @project = Project.find_by(id: project_id)

      unless @project && ActiveSupport::SecurityUtils.secure_compare(@project.dsn_key, dsn_key.to_s)
        render json: { error: "Invalid DSN" }, status: :unauthorized
      end
    end

    def extract_dsn_key
      # Try X-Sentry-Auth header first
      auth_header = request.headers["X-Sentry-Auth"] || request.headers["Authorization"]
      if auth_header
        # Format: Sentry sentry_key=<key>, sentry_version=7, ...
        match = auth_header.match(/sentry_key=([^,\s]+)/)
        return match[1] if match
      end

      # Try URL-based auth (http://<key>@host/<project_id>)
      # In this case the key comes as HTTP basic auth username
      if request.authorization
        ActionController::HttpAuthentication::Basic.user_name_and_password(request).first
      end
    end

    def decompress_body
      raw = request.body.read

      @raw_body = if request.headers["Content-Encoding"] == "gzip"
                    ActiveSupport::Gzip.decompress(raw)
                  else
                    raw
                  end
    rescue Zlib::GzipFile::Error
      # Not actually gzipped, use as-is
      @raw_body = raw
    end
  end
end
