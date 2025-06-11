class ModifyUsers < ActiveRecord::Migration[4.2]
  def self.up
    remove_column "users", "filter"
    add_column  "users", "last_updated_at", :datetime
  end

  def self.down
    remove_column "users", "last_updated_at"
  end
end
