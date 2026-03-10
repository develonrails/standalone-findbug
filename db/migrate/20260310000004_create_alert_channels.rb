# frozen_string_literal: true

class CreateAlertChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :findbug_alert_channels do |t|
      t.string :channel_type, null: false
      t.string :name, null: false
      t.boolean :enabled, default: false
      t.text :config_data

      t.timestamps
    end

    add_index :findbug_alert_channels, :channel_type
    add_index :findbug_alert_channels, :enabled
  end
end
