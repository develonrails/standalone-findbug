# frozen_string_literal: true

require "ostruct"

class AlertsController < ApplicationController
  before_action :set_alert_channel, only: [ :edit, :update, :destroy, :toggle, :test ]

  def index
    @channels = AlertChannel.order(created_at: :asc)
    @enabled_count = @channels.count(&:enabled?)
  end

  def new
    @channel = AlertChannel.new
  end

  def create
    @channel = AlertChannel.new(channel_params)
    @channel.config = build_config_from_params

    if @channel.save
      flash_success "#{@channel.display_type} alert channel created"
      redirect_to alerts_path
    else
      flash_error @channel.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    @channel.assign_attributes(channel_params)
    @channel.config = build_config_from_params

    if @channel.save
      flash_success "#{@channel.display_type} alert channel updated"
      redirect_to alerts_path
    else
      flash_error @channel.errors.full_messages.join(", ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    name = @channel.name
    @channel.destroy
    flash_success "Alert channel \"#{name}\" deleted"
    redirect_to alerts_path
  end

  def toggle
    @channel.enabled = !@channel.enabled?
    if @channel.save
      flash_success "#{@channel.name} #{@channel.enabled? ? 'enabled' : 'disabled'}"
    else
      flash_error @channel.errors.full_messages.join(", ")
    end
    redirect_to alerts_path
  end

  def test
    unless @channel.enabled?
      flash_error "Cannot test a disabled channel. Enable it first."
      redirect_to alerts_path and return
    end

    error_event = build_test_error_event
    channel_instance = @channel.channel_class.new(@channel.config.symbolize_keys)

    begin
      channel_instance.send_alert(error_event)
      flash_success "Test alert sent to #{@channel.name} successfully!"
    rescue StandardError => e
      flash_error "Failed to send test alert: #{e.message}"
    end
    redirect_to alerts_path
  end

  private

  def set_alert_channel
    @channel = AlertChannel.find(params[:id])
  end

  def channel_params
    params.require(:alert_channel).permit(:name, :channel_type, :enabled)
  end

  def build_config_from_params
    config_params = params[:config] || {}
    channel_type = params.dig(:alert_channel, :channel_type) || @channel&.channel_type

    case channel_type
    when "email"
      recipients = (config_params[:recipients] || "").split(/[\n,]/).map(&:strip).compact_blank
      { "recipients" => recipients, "from" => config_params[:from].presence }.compact
    when "slack"
      { "webhook_url" => config_params[:webhook_url], "channel" => config_params[:channel].presence,
        "username" => config_params[:username].presence, "icon_emoji" => config_params[:icon_emoji].presence }.compact
    when "discord"
      { "webhook_url" => config_params[:webhook_url], "username" => config_params[:username].presence,
        "avatar_url" => config_params[:avatar_url].presence }.compact
    when "webhook"
      headers = parse_headers(config_params[:headers])
      { "url" => config_params[:url], "method" => config_params[:method].presence || "POST",
        "headers" => headers.presence }.compact
    else
      {}
    end
  end

  def parse_headers(raw)
    return {} if raw.blank?
    raw.split("\n").each_with_object({}) do |line, hash|
      key, value = line.split(":", 2).map(&:strip)
      hash[key] = value if key.present? && value.present?
    end
  end

  def build_test_error_event
    now = Time.current
    OpenStruct.new(
      id: 0,
      fingerprint: "findbug-test-alert-#{now.to_i}",
      exception_class: "Findbug::TestAlert",
      message: "This is a test alert from the Findbug dashboard. If you see this, your alert channel is working correctly!",
      severity: "error",
      status: "unresolved",
      handled: false,
      occurrence_count: 1,
      first_seen_at: now,
      last_seen_at: now,
      environment: Findbug.config.environment || "production",
      release_version: Findbug::VERSION,
      backtrace_lines: [
        "app/controllers/alerts_controller.rb:42:in `test'",
        "lib/findbug/alerts/dispatcher.rb:57:in `send_alerts'"
      ],
      context: {},
      user: nil,
      request: { "method" => "POST", "path" => "/alerts/test" },
      tags: { "source" => "test_alert" }
    )
  end
end
