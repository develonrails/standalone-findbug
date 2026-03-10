# frozen_string_literal: true

class DashboardController < ApplicationController
  def index
    @stats = calculate_stats
    @recent_errors = scope_to_project(ErrorEvent).unresolved.recent.limit(10)
    @slowest_endpoints = scope_to_project(PerformanceEvent).slowest_transactions(since: 24.hours.ago, limit: 5)
  end

  def health
    status = {
      status: "ok",
      version: Findbug::VERSION,
      redis: Findbug::Storage::ConnectionPool.healthy? ? "ok" : "error",
      database: ErrorEvent.connection.active? ? "ok" : "error",
      buffer: Findbug::Storage::RedisBuffer.stats
    }
    render json: status
  rescue StandardError => e
    render json: { status: "error", message: e.message }, status: :internal_server_error
  end

  def stats
    render json: calculate_stats
  end

  private

  def calculate_stats
    errors = scope_to_project(ErrorEvent)
    perf = scope_to_project(PerformanceEvent)

    {
      errors: {
        total: errors.count,
        unresolved: errors.unresolved.count,
        last_24h: errors.where("created_at >= ?", 24.hours.ago).count,
        last_7d: errors.where("created_at >= ?", 7.days.ago).count
      },
      performance: {
        total: perf.count,
        last_24h: perf.where("captured_at >= ?", 24.hours.ago).count,
        avg_duration: perf.where("captured_at >= ?", 24.hours.ago).average(:duration_ms)&.round(2) || 0,
        n_plus_one_count: perf.with_n_plus_one.where("captured_at >= ?", 24.hours.ago).count
      },
      buffer: Findbug::Storage::RedisBuffer.stats,
      timestamp: Time.current.iso8601
    }
  end
end
