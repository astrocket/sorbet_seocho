# typed: true
class CreateReservations < ActiveRecord::Migration[6.0]
  def change
    create_table :reservations do |t|
      t.references :booker, null: false, foreign_key: true
      t.datetime :checkin

      t.timestamps
    end
  end
end
