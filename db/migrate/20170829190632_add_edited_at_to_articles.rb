class AddEditedAtToArticles < ActiveRecord::Migration[4.2][5.0]
  def change
    add_column :articles, :edited_at, :datetime
  end
end
