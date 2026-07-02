# Token external sensor devices use to write occupancy via the JSON API.
# In production set the SENSOR_API_TOKEN env var (fly secrets set ...);
# without it every write is rejected. Dev/test use a well-known token.
Rails.application.config.x.sensor_api_token =
  ENV.fetch("SENSOR_API_TOKEN") { Rails.env.production? ? "" : "dev-token" }
