extends Node

const SAMPLES := ["motor", "horn", "impact", "step", "skid", "rain", "river", "ambience", "thunder", "complete", "ferry", "night"]
var samples: Dictionary = {}
var emitters: Array[AudioStreamPlayer3D] = []
var position_index := 0
var loops: Dictionary = {}

func start() -> void:
	for bus in [&"Effects", &"City", &"Music"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, bus)
	for sample in SAMPLES:
		var stream: AudioStreamWAV = load("res://assets/audio/%s.wav" % sample)
		if sample in ["motor", "rain", "river", "ambience", "night"]:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = int(stream.get_length() * stream.mix_rate) - 1
		samples[sample] = stream
	for i in 10:
		var thing := AudioStreamPlayer3D.new()
		thing.bus = &"Effects"
		thing.max_distance = 105
		thing.unit_size = 14
		add_child(thing)
		emitters.append(thing)
	for sample in ["ambience", "rain", "river", "night"]:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music" if sample == "night" else &"City"
		player.stream = samples[sample]
		player.volume_db = -60
		add_child(player)
		if DisplayServer.get_name() != "headless":
			player.play()
		loops[sample] = player

func play_spatial(label: String, at: Vector3, gain := 0.0) -> void:
	if DisplayServer.get_name() == "headless" or not samples.has(label):
		return
	var emitter := emitters[position_index]
	position_index = (position_index + 1) % emitters.size()
	emitter.stop()
	emitter.global_position = at
	emitter.stream = samples[label]
	emitter.pitch_scale = randf_range(0.94, 1.06)
	emitter.volume_db = gain
	emitter.play()

func levels(settings: Dictionary) -> void:
	for bus in {"Master": "volume", "Effects": "effects_volume", "City": "ambience_volume", "Music": "music_volume"}:
		var index := AudioServer.get_bus_index(bus)
		var amount: float = settings.get({"Master": "volume", "Effects": "effects_volume", "City": "ambience_volume", "Music": "music_volume"}[bus], 0.75)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(amount, 0.0001)))

func mix(wetness: float, night: float, river: bool, wanted: int) -> void:
	loops.ambience.volume_db = -20.0
	loops.rain.volume_db = lerpf(-65, -8, wetness)
	loops.river.volume_db = -13 if river else -65
	loops.night.volume_db = lerpf(-47, -13, maxf(night, float(wanted) / 5.0))
	loops.night.pitch_scale = 1.0 + wanted * 0.042

func _exit_tree() -> void:
	for player in loops.values():
		player.stop()
		player.stream = null
