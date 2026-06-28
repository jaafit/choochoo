class AddAdminAndOwner < ActiveRecord::Migration[8.1]
  def change
    # A player can be flagged as an admin. Multiple admins per host are allowed.
    add_column :players, :admin, :boolean, default: false, null: false

    # The host's owner is its first admin: one per host, can never be demoted.
    add_column :hosts, :owner_id, :integer
    add_index  :hosts, :owner_id
  end
end
