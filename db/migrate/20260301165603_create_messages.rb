class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.text :content, null: false
      t.string :author, null: false

      t.timestamps
    end
  end
end
