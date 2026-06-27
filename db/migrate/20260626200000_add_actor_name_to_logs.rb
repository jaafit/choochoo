class AddActorNameToLogs < ActiveRecord::Migration[8.1]
  def up
    # Denormalized actor name (null = the host/Admin did it), so the log survives
    # the actor being deleted — same reasoning as player_name.
    add_column :logs, :actor_name, :string

    # Backfill from the still-existing actor players.
    execute <<~SQL
      UPDATE logs
      SET actor_name = (SELECT name FROM players WHERE players.id = logs.actor_player_id)
      WHERE actor_player_id IS NOT NULL
    SQL
  end

  def down
    remove_column :logs, :actor_name
  end
end
