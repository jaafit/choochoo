class DropRoundStateColumns < ActiveRecord::Migration[8.1]
  # Presence and the in-progress pick now live in the browser, so the server no
  # longer tracks who is in the room or who has been nominated.
  def change
    remove_column :players, :present, :boolean, default: false, null: false
    remove_column :hosts, :nominated_player_id, :integer
  end
end
