class AddSpamToComments < ActiveRecord::Migration[8.0]
  def change
    add_column :comments, :spam, :boolean, null: false, default: false
  end
end
