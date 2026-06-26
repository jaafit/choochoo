class AddPlayerTokensAndLogActor < ActiveRecord::Migration[8.1]
  def up
    add_column :players, :uuid, :string
    # Each player gets a token for their own (limited) view of the host.
    Player.reset_column_information
    Player.find_each { |p| p.update_columns(uuid: SecureRandom.uuid) }
    change_column_null :players, :uuid, false
    add_index :players, :uuid, unique: true

    # Which player performed a logged action (null = the host did it).
    add_column :logs, :actor_player_id, :integer
  end

  def down
    remove_column :players, :uuid
    remove_column :logs, :actor_player_id
  end
end
