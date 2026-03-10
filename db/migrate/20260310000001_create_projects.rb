# frozen_string_literal: true

class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :findbug_projects do |t|
      t.string :name, null: false
      t.string :dsn_key, null: false
      t.string :platform, default: "ruby"

      t.timestamps
    end

    add_index :findbug_projects, :dsn_key, unique: true
    add_index :findbug_projects, :name
  end
end
