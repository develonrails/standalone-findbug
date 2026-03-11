# frozen_string_literal: true

class AddRetentionDaysToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :findbug_projects, :retention_days, :integer, default: 30, null: false
  end
end
