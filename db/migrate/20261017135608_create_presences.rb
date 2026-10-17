class CreatePresences < ActiveRecord::Migration[8.1]
  def change
    create_table :presences do |t|
      t.string :username, null: false, index: { unique: true }
      t.datetime :last_seen_at, null: false
    end
  end
end
