class CreatePlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :players do |t|
      t.references :host, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :tickets, null: false, default: 0
      t.boolean :present, null: false, default: false

      t.timestamps
    end
  end
end
