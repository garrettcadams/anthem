class CreateSubmissions < ActiveRecord::Migration[7.0]
  def change
    create_table :submissions do |t|
      t.references :artist, null: false, foreign_key: { to_table: :users }, type: :integer
      t.references :dj, null: false, foreign_key: { to_table: :users }, type: :integer
      t.references :asset, null: false, foreign_key: true, type: :integer
      t.references :playlist, null: false, foreign_key: true, type: :integer
      t.string :status, default: 'pending', null: false
      t.text :message

      t.timestamps
    end
  end
end
