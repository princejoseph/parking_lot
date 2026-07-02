require 'rails_helper'

describe 'Sensor API', type: :request do
  let!(:spot) { ParkingSpot.create!(name: 'A1', position: 1) }
  let(:auth) { { 'Authorization' => 'Bearer dev-token' } }

  describe 'GET /api/spots' do
    it 'is public and lists spots' do
      get '/api/spots'
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        [{ 'id' => spot.id, 'name' => 'A1', 'occupied' => false }]
      )
    end
  end

  describe 'POST /api/spots/:id' do
    it 'rejects requests without a token' do
      post '/api/spots/A1', params: { occupied: true }
      expect(response).to have_http_status(:unauthorized)
      expect(spot.reload.occupied).to be(false)
    end

    it 'rejects requests with a wrong token' do
      post '/api/spots/A1', params: { occupied: true },
                            headers: { 'Authorization' => 'Bearer wrong' }
      expect(response).to have_http_status(:unauthorized)
      expect(spot.reload.occupied).to be(false)
    end

    it 'updates by name with a valid token' do
      post '/api/spots/A1', params: { occupied: true }, headers: auth
      expect(response).to have_http_status(:ok)
      expect(spot.reload.occupied).to be(true)
    end

    it 'updates by id and casts string booleans' do
      post "/api/spots/#{spot.id}", params: { occupied: 'true' }, headers: auth
      expect(response).to have_http_status(:ok)
      expect(spot.reload.occupied).to be(true)
    end

    it 'returns 404 for unknown spots' do
      post '/api/spots/ZZ', params: { occupied: true }, headers: auth
      expect(response).to have_http_status(:not_found)
    end
  end
end
