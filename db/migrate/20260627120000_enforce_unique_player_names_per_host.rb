class EnforceUniquePlayerNamesPerHost < ActiveRecord::Migration[8.1]
  def change
    # Case-insensitive uniqueness within a host: "Bob" and "bob" collide.
    # Mirrors the model's `uniqueness: { case_sensitive: false }`.
    add_index :players, "host_id, LOWER(name)", unique: true,
      name: "index_players_on_host_id_and_lower_name"
  end
end
