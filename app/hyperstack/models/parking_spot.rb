class ParkingSpot < ApplicationRecord
  scope :ordered, -> { order(:position) }
end
