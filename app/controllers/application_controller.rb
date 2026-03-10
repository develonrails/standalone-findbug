# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  allow_browser versions: :modern

  before_action :authenticate!
  before_action :set_current_project

  helper_method :current_project, :projects

  private

  def authenticate!
    return true unless Findbug.config.web_enabled?

    authenticate_or_request_with_http_basic("Findbug") do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(username.to_s, Findbug.config.web_username.to_s) &&
        ActiveSupport::SecurityUtils.secure_compare(password.to_s, Findbug.config.web_password.to_s)
    end
  end

  def set_current_project
    if params[:project_id].present?
      @current_project = Project.find_by(id: params[:project_id])
      session[:project_id] = @current_project&.id
    elsif session[:project_id].present?
      @current_project = Project.find_by(id: session[:project_id])
    end
  end

  def current_project
    @current_project
  end

  def projects
    @projects ||= Project.order(:name)
  end

  def scope_to_project(scope)
    current_project ? scope.where(project_id: current_project.id) : scope
  end

  rescue_from ActiveRecord::RecordNotFound do
    flash[:error] = "Record not found"
    redirect_to root_path
  end

  def flash_success(message)
    flash[:success] = message
  end

  def flash_error(message)
    flash[:error] = message
  end
end
