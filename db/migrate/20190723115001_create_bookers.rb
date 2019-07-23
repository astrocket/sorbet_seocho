# typed: true
class CreateBookers < ActiveRecord::Migration[6.0]
  def change
    create_table :bookers do |t|
      t.string :name
      t.string :phone

      t.timestamps
    end
  end
end
