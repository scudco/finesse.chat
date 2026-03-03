class AddInvokedByToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :invoked_by, :string
  end
end
