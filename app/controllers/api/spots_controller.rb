# Sensor-facing API. The device (phone over a toy car) reports
# occupied/vacant here; saving the model broadcasts the change to every
# browser via HyperModel/ActionCable.
#
#   GET  /api/spots               -> [{ id, name, occupied }, ...]
#   POST /api/spots/A1  { "occupied": true }   (PUT/PATCH also accepted,
#                                                :id can be spot name or id)
module Api
  class SpotsController < ActionController::API
    rescue_from ActiveRecord::RecordNotFound do
      render json: { error: "spot not found" }, status: :not_found
    end

    def index
      render json: ParkingSpot.ordered.as_json(only: %i[id name occupied])
    end

    def update
      spot = ParkingSpot.find_by(name: params[:id]) ||
             ParkingSpot.find_by!(id: params[:id])
      occupied = ActiveModel::Type::Boolean.new.cast(params.require(:occupied))
      spot.update!(occupied: occupied)
      render json: spot.as_json(only: %i[id name occupied])
    end
  end
end
