# Sensor-facing API. The device (phone over a toy car) reports
# occupied/vacant here; saving the model broadcasts the change to every
# browser via HyperModel/ActionCable.
#
#   GET  /api/spots               -> [{ id, name, occupied }, ...]  (public)
#   POST /api/spots/A1  { "occupied": true }   (PUT/PATCH also accepted,
#                                                :id can be spot name or id;
#                                                needs Authorization: Bearer <token>)
module Api
  class SpotsController < ActionController::API
    before_action :authenticate!, except: :index

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

    private

    def authenticate!
      expected = Rails.application.config.x.sensor_api_token
      token = request.authorization.to_s.delete_prefix("Bearer ")
      return if expected.present? &&
                ActiveSupport::SecurityUtils.secure_compare(token, expected)

      render json: { error: "unauthorized" }, status: :unauthorized
    end
  end
end
