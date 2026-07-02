%w[A1 A2 A3 A4].each_with_index do |name, i|
  ParkingSpot.find_or_create_by!(name: name) { |spot| spot.position = i + 1 }
end
