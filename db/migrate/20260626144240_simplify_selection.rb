class SimplifySelection < ActiveRecord::Migration[8.1]
  def change
    # Player selection is now ephemeral (session), not persisted.
    remove_column :players, :playing_order, :integer

    # Snapshot of the last send-off so it can be undone.
    add_column :hosts, :undo_send_off, :json
  end
end
