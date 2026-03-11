# frozen_string_literal: true

class Project < ApplicationRecord
  self.table_name = "findbug_projects"

  has_many :error_events, dependent: :destroy
  has_many :performance_events, dependent: :destroy

  RETENTION_OPTIONS = [30, 60, 90, 180, 365].freeze

  validates :name, presence: true, uniqueness: true
  validates :dsn_key, presence: true, uniqueness: true
  validates :retention_days, inclusion: { in: RETENTION_OPTIONS }

  before_validation :generate_dsn_key, on: :create

  def dsn(host: ENV.fetch("FINDBUG_HOST", "localhost:3000"))
    "http://#{dsn_key}@#{host}/#{id}"
  end

  private

  def generate_dsn_key
    self.dsn_key ||= SecureRandom.hex(16)
  end
end
