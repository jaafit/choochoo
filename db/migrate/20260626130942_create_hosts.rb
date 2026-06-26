class CreateHosts < ActiveRecord::Migration[8.1]
  def change
    create_table :hosts do |t|
      t.string :uuid
      t.integer :nominated_player_id

      t.timestamps
    end
    add_index :hosts, :uuid, unique: true
  end
end
