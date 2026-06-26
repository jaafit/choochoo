class CreateLogsAndDropUndoSnapshot < ActiveRecord::Migration[8.1]
  def change
    create_table :logs do |t|
      t.references :host, null: false, foreign_key: true
      t.string :action, null: false
      t.string :player_name
      t.integer :player_id   # plain reference; logs outlive their player
      t.json :data, default: {}

      t.timestamps
    end

    # The send-off undo snapshot now lives in the latest send_off log entry.
    remove_column :hosts, :undo_send_off, :json
  end
end
