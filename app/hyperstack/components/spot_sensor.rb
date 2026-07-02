# Browser-based "distance sensor" as a Hyperstack component. The phone lies
# face-up in the spot; a toy car covering it blacks out the front camera.
# Occupancy is written through HyperModel (spot.save), so it broadcasts to
# every browser — no JSON fetch needed. Only the camera pixel sampling is
# native JS (getUserMedia has no Opal wrapper).
class SpotSensor < HyperComponent
  # Occupancy is judged relative to a baseline calibrated at start (spot
  # empty), so a car hovering over the phone trips it without sealing the
  # lens, and it works in bright or dim rooms. Ratio gap = hysteresis.
  # The baseline is fixed after calibration: adapting it while "vacant"
  # let an approaching car drag it down and blunt the trigger.
  CALIBRATION_SAMPLES = 5     # ~2s at 400ms/sample
  OCCUPIED_RATIO = 0.65       # dims below 65% of baseline -> occupied
  VACANT_RATIO   = 0.85       # recovers above 85% -> vacant

  before_mount do
    @spot_id = nil
    @level = nil
    @occupied = nil
    @sensing = false
    @camera_error = nil
    @baseline = nil
    @baseline_samples = nil
  end

  def selected_spot
    id = @spot_id || ParkingSpot.ordered.first&.id
    id && ParkingSpot.find(id.to_i)
  end

  def start_sensing
    mutate do
      @sensing = true
      @baseline = nil
      @baseline_samples = []
    end
    %x{
      var video  = document.getElementById('sensor-cam');
      var canvas = document.getElementById('sensor-frame');
      var ctx    = canvas.getContext('2d', { willReadFrequently: true });
      navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'user', width: 64, height: 48 }
      }).then(function(stream) {
        video.srcObject = stream;
        return video.play();
      }).then(function() {
        setInterval(function() {
          ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
          var px = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
          var sum = 0;
          for (var i = 0; i < px.length; i += 4) {
            sum += 0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2];
          }
          #{sample(`sum / (px.length / 4)`)};
        }, 400);
      }).catch(function(e) {
        #{camera_failed(`'' + e`)};
      });
    }
  end

  def camera_failed(message)
    mutate do
      @sensing = false
      @camera_error = message
    end
  end

  def sample(avg)
    mutate @level = avg.round

    if @baseline.nil?
      @baseline_samples << avg
      if @baseline_samples.size >= CALIBRATION_SAMPLES
        mutate @baseline = @baseline_samples.inject(:+) / @baseline_samples.size
      end
      return
    end

    if @occupied != true && avg < @baseline * OCCUPIED_RATIO
      report(true)
    elsif @occupied != false && avg > @baseline * VACANT_RATIO
      report(false)
    end
  end

  def report(value)
    mutate @occupied = value
    spot = selected_spot
    return unless spot
    spot.occupied = value
    spot.save
  end

  def state_text
    return "calibrating…" if @sensing && @baseline.nil?
    return "idle" if @occupied.nil?
    @occupied ? "🚗 OCCUPIED" : "VACANT"
  end

  def state_color
    return "bg-gray-700" if @occupied.nil?
    @occupied ? "bg-red-600" : "bg-green-600"
  end

  render do
    DIV(class: "min-h-screen bg-gray-900 text-gray-100 flex flex-col items-center py-10 px-4") do
      H1(class: "text-3xl font-bold mb-1") { "📷 Spot Sensor" }
      P(class: "text-gray-400 mb-6 text-center") do
        "Place this phone face-up in the empty spot, then start. " \
        "Anything dimming the camera = occupied."
      end

      SELECT(class: "text-gray-900 rounded px-4 py-3 text-lg mb-4", value: (@spot_id || selected_spot&.id).to_s) do
        ParkingSpot.ordered.each do |spot|
          OPTION(key: spot.id, value: spot.id.to_s) { "Spot #{spot.name}" }
        end
      end.on(:change) { |e| mutate @spot_id = e.target.value }

      unless @sensing
        BUTTON(class: "bg-blue-600 hover:bg-blue-500 rounded px-6 py-3 text-lg font-bold mb-6") do
          "Start sensing"
        end.on(:click) { start_sensing }
      end

      if @camera_error
        P(class: "text-red-400 mb-4 text-center") { "Camera error: #{@camera_error}" }
      end

      DIV(class: "#{state_color} rounded-xl w-full max-w-sm h-40 flex flex-col " \
                 "items-center justify-center transition-colors duration-500 text-2xl font-bold") do
        state_text
      end
      P(class: "text-gray-400 mt-4") do
        "brightness: #{@level || '–'}#{" (baseline #{@baseline.round})" if @baseline}"
      end

      VIDEO(id: "sensor-cam", playsInline: true, muted: true, class: "hidden")
      CANVAS(id: "sensor-frame", width: 64, height: 48, class: "hidden")
    end
  end
end
