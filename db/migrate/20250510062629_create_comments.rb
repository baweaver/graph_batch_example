class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments do |t|
      t.text :body
      t.references :post, null: false, foreign_key: true
      t.references :author, polymorphic: true, null: false

      t.timestamps
    end
  end
end
