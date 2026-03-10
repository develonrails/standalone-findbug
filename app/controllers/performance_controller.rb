# frozen_string_literal: true

class PerformanceController < ApplicationController
  def index
    @since = parse_since(params[:since] || "24h")
    base = scope_to_project(PerformanceEvent)
    @slowest = base.slowest_transactions(since: @since, limit: 20)
    @n_plus_one = base.n_plus_one_hotspots(since: @since, limit: 10)
    @throughput = base.throughput_over_time(since: @since)
    @stats = calculate_stats(@since)
  end

  def show
    @transaction_name = params[:id]
    @since = parse_since(params[:since] || "24h")

    base = scope_to_project(PerformanceEvent)
    @events = base.where(transaction_name: @transaction_name)
                  .where("captured_at >= ?", @since)
                  .recent.limit(100)
    @stats = base.aggregate_for(@transaction_name, since: @since)
    @slowest_requests = @events.order(duration_ms: :desc).limit(10)
    @n_plus_one_requests = @events.where(has_n_plus_one: true).limit(10)
  end

  private

  def calculate_stats(since)
    events = scope_to_project(PerformanceEvent).where("captured_at >= ?", since)
    total = events.count
    {
      total_requests: total,
      avg_duration: events.average(:duration_ms)&.round(2) || 0,
      max_duration: events.maximum(:duration_ms)&.round(2) || 0,
      avg_queries: events.average(:query_count)&.round(1) || 0,
      n_plus_one_percentage: total.zero? ? 0 : ((events.where(has_n_plus_one: true).count.to_f / total) * 100).round(1)
    }
  end

  def parse_since(value)
    case value
    when "1h" then 1.hour.ago
    when "24h" then 24.hours.ago
    when "7d" then 7.days.ago
    when "30d" then 30.days.ago
    else 24.hours.ago
    end
  end
end
