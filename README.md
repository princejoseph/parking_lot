# Parking Lot 🅿️

A real-time parking lot monitor — the VoltRB hackathon project, rebuilt on
**Rails 7.2 + Hyperstack**.

**Live demo: https://parkinglot.fly.dev**

## Try it

1. Open https://parkinglot.fly.dev in **two browser windows** side by side.
2. Tap a spot in one window — it flips red/green in *both* instantly
   (HyperModel broadcast over ActionCable, no polling).
3. Drive it from the sensor API and watch every open browser update
   (writes need the sensor token — see below; reads are public):

   ```bash
   curl -X POST https://parkinglot.fly.dev/api/spots/A1 \
        -H "Authorization: Bearer $SENSOR_API_TOKEN" \
        -H 'Content-Type: application/json' -d '{"occupied": true}'
   ```

4. **Phone as the parking sensor:** open https://parkinglot.fly.dev/sensor on
   a phone, pick a spot, tap *Start sensing*, and lay the phone face-up in the
   "parking spot". Cover it with a toy car (or your hand) — the spot goes red
   on every screen; uncover it and it goes green. Because fly.dev serves over
   HTTPS, the camera works directly — no tunnels or flags needed.

## Deploying

Pushes to `main` auto-deploy to Fly via GitHub Actions
([.github/workflows/fly-deploy.yml](.github/workflows/fly-deploy.yml) — needs
a `FLY_API_TOKEN` repo secret from `flyctl tokens create deploy -a parkinglot`).
Manual deploy: `flyctl deploy`.

Four parking spots render green (vacant) or red (occupied). A sensor device —
a phone lying in the spot — reports to a JSON API when a toy car covers it.
The page updates **live in every open browser** via HyperModel + ActionCable:
no polling, no refresh, no hand-written websocket code. The reactivity VoltRB
gave us for free, Hyperstack gives us the same way — the `ParkingSpot` model
is shared between server and browser, and any save (from the API, the Rails
console, or another browser) broadcasts automatically.

## Stack

- Ruby 3.1 / Rails 7.2 / SQLite
- Hyperstack from the [`rails-7-compatibility` fork](https://github.com/princejoseph/hyperstack/tree/rails-7-compatibility)
  (all 8 gems pinned — see Gemfile)
- Opal (Ruby → JS via Sprockets), Tailwind via CDN
- HyperModel over ActionCable (`async` adapter — no Redis needed)

## Running

```bash
bundle install
bin/rails db:create db:migrate db:seed   # seeds spots A1–A4
bundle exec foreman start -p 3000        # web + hyperstack hot-loader
```

Visit http://localhost:3000. First page load takes ~10s (Opal compiling);
subsequent loads are instant. Open it in two browser windows and tap a spot —
both update instantly.

## The sensor API

The device in each spot reports occupancy here. Saving the model is what
triggers the broadcast, so anything that hits this endpoint updates all
browsers in real time:

```bash
# spot id or name, POST/PUT/PATCH all accepted; writes need a bearer token
curl -X POST http://localhost:3000/api/spots/A1 \
     -H 'Authorization: Bearer dev-token' \
     -H 'Content-Type: application/json' -d '{"occupied": true}'

curl http://localhost:3000/api/spots   # current state of all spots (public)
```

**Auth:** writes require `Authorization: Bearer <SENSOR_API_TOKEN>`. In
development and test the token is `dev-token`; in production it comes from
the `SENSOR_API_TOKEN` env var (`fly secrets set SENSOR_API_TOKEN=$(openssl
rand -hex 16) -a parkinglot`) and writes are rejected if it is unset. The
in-browser pages don't use the API — they write through HyperModel — so
only external devices need the token.

## Tests

RSpec + [hyper-spec](https://github.com/hyperstack-org/hyperstack/tree/edge/ruby/hyper-spec)
(from the same fork). Component specs mount `ParkingLot`/`SpotSensor` in a
real headless Chrome and cover click-to-toggle, the HyperModel write path the
sensor uses, and server→browser broadcast; request specs cover API auth.

```bash
RAILS_ENV=test bin/rails db:prepare
bundle exec rspec        # 11 examples
```

They also run in CI: the deploy workflow's `test` job gates the deploy.

Two non-obvious bits of test plumbing (see `spec/rails_helper.rb`):
transactional fixtures are off because HyperModel broadcasts fire on
`after_commit`, and the suite defines `Hyperstack.on_server?` as true so the
gem auto-creates its connection tables under the in-process Capybara server.

## The sensor device: `/sensor`

Instead of a native app with a proximity sensor, this app includes a
**browser-based sensor page** — so the whole project stays one website:

1. Lay the phone face-up in the **empty** parking spot, open
   `http://<server>:3000/sensor`, pick the spot and tap *Start sensing*.
2. The page samples the front camera's average brightness ~2×/second and
   calibrates a baseline from the first ~2 seconds (spot empty).
3. Detection is relative to that baseline, so a toy car hovering over the
   phone trips it without sealing the lens, in any room lighting: dimming
   below 65% of baseline → occupied; recovering above 85% → vacant (the gap
   is the anti-flap hysteresis). While the spot is empty the baseline slowly
   tracks lighting drift.

The sensor page is itself a Hyperstack component
([spot_sensor.rb](app/hyperstack/components/spot_sensor.rb)) — Ruby all the
way down. Only the camera pixel-sampling is native JS (an Opal x-string);
the occupancy write is a plain HyperModel `spot.save`, which broadcasts to
every browser the same way the main page does. The JSON API stays for
external devices (a future Flutter sensor app, curl, etc.).

**Caveat:** `getUserMedia` requires a secure context. `localhost` works as-is;
for a phone on your LAN you need HTTPS — easiest is a tunnel
(`ngrok http 3000`, `cloudflared`, tailscale) or Chrome's
`chrome://flags/#unsafely-treat-insecure-origin-as-secure`.

If you outgrow the camera trick (e.g. want the real proximity sensor or a
kiosk-style always-on device), **Flutter** is the right next step: the
[`proximity_sensor`](https://pub.dev/packages/proximity_sensor) package
exposes Android's near/far sensor directly, and the app is a ~50-line wrapper
that POSTs to the same API. The web Proximity Sensor API spec exists but no
browser ships it, so a web page can't read the real sensor — hence the camera
fallback here.

## How the pieces fit

```
app/hyperstack/models/parking_spot.rb   # shared model — server AND browser (Opal)
app/hyperstack/components/parking_lot.rb# reactive page: green/red grid
app/hyperstack/components/spot_sensor.rb# camera-as-distance-sensor page (also Opal!)
app/policies/hyperstack/application_policy.rb  # open access (demo!)
app/controllers/api/spots_controller.rb # JSON API for external sensor devices
```

Key Hyperstack conventions (learned the hard way — see
`~/Code/rosary/README.md` for the full new-project recipe):

- Models live in `app/hyperstack/models/` (including `ApplicationRecord`) so
  Zeitwerk loads them server-side and Opal compiles them client-side.
- Query modifiers (`order`, `limit`…) are server-only — wrap them in named
  scopes (`ParkingSpot.ordered`) and call the scope from components.
- All 8 Hyperstack gems must be pinned to the same fork/branch or Bundler
  pulls broken alphas from rubygems.org.

## Demo without any device

Tap any spot tile on the main page — it toggles occupied/vacant through the
same model, exercising the same broadcast path as the API.
