# frozen_string_literal: true

class ProjectsController < ApplicationController
  def index
    @projects = Project.order(:name)
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)
    if @project.save
      flash_success "Project \"#{@project.name}\" created. DSN: #{@project.dsn}"
      redirect_to projects_path
    else
      flash_error @project.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @project = Project.find(params[:id])
  end

  def destroy
    @project = Project.find(params[:id])
    name = @project.name
    @project.destroy
    flash_success "Project \"#{name}\" deleted"
    redirect_to projects_path
  end

  private

  def project_params
    params.require(:project).permit(:name, :platform)
  end
end
