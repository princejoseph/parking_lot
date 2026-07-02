class CreateParkingSpots < ActiveRecord::Migration[7.2]
  def change
    create_table :parking_spots do |t|
      t.string :name, null: false
      t.integer :position, null: false
      t.boolean :occupied, null: false, default: false

      t.timestamps
    end
  end
end
