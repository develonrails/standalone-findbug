# frozen_string_literal: true

class AlertChannel < ApplicationRecord
  self.table_name = "findbug_alert_channels"

  CHANNEL_TYPES = %w[email slack discord webhook].freeze

  def self.encryption_available?
    return false unless defined?(ActiveRecord::Encryption)
    ActiveRecord::Encryption.config.primary_key.present?
  rescue StandardError
    false
  end

  serialize :config_data, coder: JSON
  encrypts :config_data if encryption_available?

  validates :name, presence: true
  validates :channel_type, presence: true, inclusion: { in: CHANNEL_TYPES }
  validate :validate_required_config

  scope :enabled, -> { where(enabled: true) }
  scope :by_type, ->(type) { where(channel_type: type) }

  def config
    config_data || {}
  end

  def config=(value)
    self.config_data = value
  end

  def channel_class
    case channel_type
    when "email"   then Findbug::Alerts::Channels::Email
    when "slack"   then Findbug::Alerts::Channels::Slack
    when "discord" then Findbug::Alerts::Channels::Discord
    when "webhook" then Findbug::Alerts::Channels::Webhook
    end
  end

  def display_type
    channel_type&.titleize
  end

  def masked_config
    masked = {}
    case channel_type
    when "email"
      masked["Recipients"] = Array(config["recipients"]).join(", ").presence || "None"
      masked["From"] = config["from"] || "findbug@localhost"
    when "slack"
      masked["Webhook URL"] = mask_url(config["webhook_url"])
      masked["Channel"] = config["channel"] || "Default"
      masked["Username"] = config["username"] || "Findbug"
    when "discord"
      masked["Webhook URL"] = mask_url(config["webhook_url"])
      masked["Username"] = config["username"] || "Findbug"
    when "webhook"
      masked["URL"] = mask_url(config["url"])
      masked["Method"] = (config["method"] || "POST").upcase
      headers_count = (config["headers"] || {}).size
      masked["Custom Headers"] = "#{headers_count} configured" if headers_count > 0
    end
    masked
  end

  private

  def mask_url(url)
    return "Not configured" if url.blank?
    uri = URI.parse(url)
    path = uri.path.to_s
    masked_path = path.length > 8 ? "#{path[0..7]}********" : "********"
    "#{uri.scheme}://#{uri.host}#{masked_path}"
  rescue URI::InvalidURIError
    "#{url[0..15]}********"
  end

  def validate_required_config
    return if config.blank? && !enabled?
    case channel_type
    when "email"
      errors.add(:base, "Email channel requires at least one recipient") if enabled? && Array(config["recipients"]).compact_blank.empty?
    when "slack"
      errors.add(:base, "Slack channel requires a webhook URL") if enabled? && config["webhook_url"].blank?
    when "discord"
      errors.add(:base, "Discord channel requires a webhook URL") if enabled? && config["webhook_url"].blank?
    when "webhook"
      errors.add(:base, "Webhook channel requires a URL") if enabled? && config["url"].blank?
    end
  end
end
