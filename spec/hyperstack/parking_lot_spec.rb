require 'rails_helper'

describe 'ParkingLot component', js: true do
  before(:each) do
    %w[A1 A2 A3 A4].each_with_index do |name, i|
      ParkingSpot.create!(name: name, position: i + 1)
    end
  end

  it 'renders all four spots vacant' do
    mount 'ParkingLot'
    expect(page).to have_content('4 of 4 spots free')
    %w[A1 A2 A3 A4].each { |name| expect(page).to have_content(name) }
    expect(page).to have_content('Vacant', count: 4)
    expect(page).not_to have_content('Occupied')
  end

  it 'occupies a spot on click and persists it server-side' do
    mount 'ParkingLot'
    expect(page).to have_content('4 of 4 spots free')

    page.find('div.cursor-pointer', text: 'A1').click

    expect(page).to have_content('3 of 4 spots free')
    expect(page).to have_content('Occupied', count: 1)
    wait_for { ParkingSpot.find_by(name: 'A1').occupied }.to be(true)
  end

  it 'reflects server-side changes in real time (broadcast)' do
    mount 'ParkingLot'
    expect(page).to have_content('4 of 4 spots free')
    # the real pages auto-connect via the react_component view helper;
    # hyper-spec's mount bypasses it, so subscribe explicitly
    evaluate_ruby 'Hyperstack.connect("Hyperstack::Application")'

    ParkingSpot.find_by(name: 'A2').update(occupied: true)

    expect(page).to have_content('3 of 4 spots free')
    expect(page).to have_content('Occupied', count: 1)
  end
end
