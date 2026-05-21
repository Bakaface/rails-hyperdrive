ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :email, null: false
    t.string :name
    t.timestamps
  end

  create_table :posts, force: true do |t|
    t.references :user, null: false
    t.string :title, null: false
    t.text :body
    t.timestamps
  end
end
