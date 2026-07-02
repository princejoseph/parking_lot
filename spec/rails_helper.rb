require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
# hyper-spec must load before the Rails environment (same order as the
# hyperstack gems' own specs)
require 'hyper-spec'
require_relative '../config/environment'
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require 'rspec/wait'

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join('spec/fixtures')]

  # Hyperstack auto-creates its connection/queued-message tables only when
  # Hyperstack.on_server? (= defined?(Rails::Server)) is true. Under RSpec the
  # in-process Capybara Puma *is* the server, so make that true and build them;
  # otherwise connect-to-transport 503s and broadcast specs see nothing.
  config.before(:suite) do
    def Hyperstack.on_server?
      true
    end
    Hyperstack::Connection.build_tables
  end

  # Broadcasts fire on after_commit; transactional examples never commit, so
  # HyperModel real-time specs would silently see nothing. Clean manually.
  config.use_transactional_fixtures = false
  config.before(:each) { ParkingSpot.delete_all }

  config.filter_rails_from_backtrace!
end
