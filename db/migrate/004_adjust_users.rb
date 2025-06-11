class AdjustUsers < ActiveRecord::Migration[4.2]
  def self.up
      remove_column 'users', 'last_updated_at'
      add_column 'users', 'last_seen_at', :datetime
  end

  def self.down
      remove_column 'users', 'last_seen_at'
  end
end
