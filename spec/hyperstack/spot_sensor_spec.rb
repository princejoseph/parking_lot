require 'rails_helper'

describe 'SpotSensor component', js: true do
  before(:each) do
    %w[A1 A2 A3 A4].each_with_index do |name, i|
      ParkingSpot.create!(name: name, position: i + 1)
    end
  end

  it 'renders the spot dropdown, idle state and start button' do
    mount 'SpotSensor'
    expect(page).to have_content('Spot Sensor')
    %w[A1 A2 A3 A4].each { |name| expect(page).to have_content("Spot #{name}") }
    expect(page).to have_content('idle')
    expect(page).to have_content('Start sensing')
  end

  it 'writes occupancy through HyperModel (the path report() uses)' do
    mount 'SpotSensor'
    expect(page).to have_content('Spot Sensor')

    # same client-side write report(true) performs after a dark sample
    evaluate_ruby do
      spot = ParkingSpot.find_by_name('A1')
      spot.occupied = true
      spot.save
    end

    wait_for { ParkingSpot.find_by(name: 'A1').occupied }.to be(true)
  end
end
