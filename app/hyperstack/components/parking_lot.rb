# Reactive parking lot view. HyperModel + ActionCable pushes every
# ParkingSpot change to all connected browsers — no polling, no refresh.
class ParkingLot < HyperComponent
  def toggle(spot)
    spot.occupied = !spot.occupied
    spot.save
  end

  render do
    spots = ParkingSpot.ordered
    free = spots.to_a.count { |s| !s.occupied }

    DIV(class: "min-h-screen bg-gray-900 text-gray-100 flex flex-col items-center py-10 px-4") do
      H1(class: "text-4xl font-bold mb-1") { "🅿️ Parking Lot" }
      P(class: "text-gray-400 mb-6") { "Live spot availability — updates in real time" }

      DIV(class: "text-2xl mb-8") do
        SPAN(class: "font-bold #{free.zero? ? 'text-red-400' : 'text-green-400'}") { free.to_s }
        SPAN(class: "text-gray-400") { " of #{spots.to_a.size} spots free" }
      end

      DIV(class: "grid grid-cols-2 gap-6 w-full max-w-xl") do
        spots.each do |spot|
          spot_tile(spot)
        end
      end

      P(class: "text-gray-500 text-sm mt-10") { "Tap a spot to simulate a sensor reading" }
    end
  end

  def spot_tile(spot)
    color = spot.occupied ? "bg-red-600 border-red-400" : "bg-green-600 border-green-400"
    DIV(key: spot.id,
        class: "#{color} border-4 border-dashed rounded-xl h-44 flex flex-col " \
               "items-center justify-center cursor-pointer select-none " \
               "transition-colors duration-500 shadow-lg") do
      SPAN(class: "text-5xl") { spot.occupied ? "🚗" : "" }
      SPAN(class: "text-2xl font-bold mt-2") { spot.name.to_s }
      SPAN(class: "text-sm uppercase tracking-widest") do
        spot.occupied ? "Occupied" : "Vacant"
      end
    end.on(:click) { toggle(spot) }
  end
end
