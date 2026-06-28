class AddNameToHosts < ActiveRecord::Migration[8.1]
  def change
    add_column :hosts, :name, :string
  end
end
