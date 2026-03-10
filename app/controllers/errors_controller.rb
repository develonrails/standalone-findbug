# frozen_string_literal: true

class ErrorsController < ApplicationController
  before_action :set_error, only: [:show, :resolve, :ignore, :reopen]

  def index
    @errors = scope_to_project(ErrorEvent).all
    @errors = apply_filters(@errors)
    @page = (params[:page] || 1).to_i
    @per_page = 25
    @total_count = @errors.count
    @errors = @errors.offset((@page - 1) * @per_page).limit(@per_page)
  end

  def show
    @similar_errors = scope_to_project(ErrorEvent)
                        .where(exception_class: @error.exception_class)
                        .where.not(id: @error.id)
                        .recent.limit(5)
  end

  def resolve
    @error.resolve!
    flash_success "Error marked as resolved"
    redirect_back(fallback_location: errors_path)
  end

  def ignore
    @error.ignore!
    flash_success "Error marked as ignored"
    redirect_back(fallback_location: errors_path)
  end

  def reopen
    @error.reopen!
    flash_success "Error reopened"
    redirect_back(fallback_location: errors_path)
  end

  private

  def set_error
    @error = ErrorEvent.find(params[:id])
  end

  def apply_filters(scope)
    if params[:status].present?
      scope = scope.where(status: params[:status])
    elsif !params.key?(:status)
      scope = scope.unresolved
    end
    scope = scope.where(severity: params[:severity]) if params[:severity].present?
    if params[:search].present?
      search = "%#{params[:search]}%"
      scope = scope.where("exception_class ILIKE :search OR message ILIKE :search", search: search)
    end
    if params[:since].present?
      scope = scope.where("last_seen_at >= ?", parse_since(params[:since]))
    end
    case params[:sort]
    when "oldest" then scope.order(last_seen_at: :asc)
    when "occurrences" then scope.order(occurrence_count: :desc)
    else scope.recent
    end
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
