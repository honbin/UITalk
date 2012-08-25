class ChangeDataTypeForCommentBody < ActiveRecord::Migration
  def up
    change_table :comments do |t|
      t.change :body, :text, :limit => nil
    end
  end

  def down
    change_table :comments do |t|
      t.change :body, :string
    end
  end
end
