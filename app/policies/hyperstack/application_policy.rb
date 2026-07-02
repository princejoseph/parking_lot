class Hyperstack::ApplicationPolicy
  # Allow any session to connect
  always_allow_connection
  # Send all attributes from all public models
  regulate_all_broadcasts { |policy| policy.send_all }
  # Allow create/update/destroy from the client
  allow_change(to: :all, on: [:create, :update, :destroy]) { true }
  # Allow remote access to all scopes
  ApplicationRecord.regulate_scope :all
end
