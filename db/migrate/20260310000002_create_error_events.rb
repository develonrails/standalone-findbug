# frozen_string_literal: true

class CreateErrorEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :findbug_error_events do |t|
      t.string :fingerprint, null: false
      t.string :exception_class, null: false
      t.text :message
      t.text :backtrace
      t.jsonb :context, default: {}
      t.jsonb :request_data, default: {}
      t.string :environment
      t.string :release_version
      t.string :severity, default: "error"
      t.string :source
      t.boolean :handled, default: false
      t.integer :occurrence_count, default: 1
      t.datetime :first_seen_at
      t.datetime :last_seen_at
      t.string :status, default: "unresolved"
      t.references :project, foreign_key: { to_table: :findbug_projects }

      t.timestamps
    end

    add_index :findbug_error_events, :fingerprint
    add_index :findbug_error_events, :exception_class
    add_index :findbug_error_events, :status
    add_index :findbug_error_events, :severity
    add_index :findbug_error_events, :last_seen_at
    add_index :findbug_error_events, :created_at
    add_index :findbug_error_events, [ :status, :last_seen_at ]
    add_index :findbug_error_events, [ :exception_class, :created_at ]
    add_index :findbug_error_events, [ :project_id, :fingerprint ], name: "idx_error_events_project_fingerprint"
  end
end
