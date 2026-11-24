extends Node3D

const WEATHER_ZH := ["晴天", "多云", "阴天", "小雨", "暴雨", "雾天", "雷电"]
const WEATHER_EN := ["Clear", "Partly cloudy", "Overcast", "Light rain", "Downpour", "Fog", "Thunderstorm"]
var hour := 16.25
var weather := 0
var night := 0.0
var wetness := 0.0
var flash := 0.0
var thunder_timer := 9.0
var weather_timer := 0.0
var sun: DirectionalLight3D
var environment: Environment
var sky: ProceduralSkyMaterial
var rain: GPUParticles3D
var last_night := false
var update_clock := 0.0

func start() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60
	add_child(sun)
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	sky = ProceduralSkyMaterial.new()
	sky.sun_angle_max = 9.0
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_sky_contribution = 0.18
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)
	rain = GPUParticles3D.new()
	rain.amount = 1200
	rain.lifetime = 0.82
	rain.visibility_aabb = AABB(Vector3(-18, -18, -18), Vector3(36, 36, 36))
	rain.emitting = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(13, 1.2, 13)
	process.direction = Vector3(0.1, -1, 0.055)
	process.spread = 5
	process.initial_velocity_min = 16
	process.initial_velocity_max = 20
	process.gravity = Vector3(0, -3.2, 0)
	rain.process_material = process
	var drop := BoxMesh.new()
	drop.size = Vector3(0.024, 0.41, 0.024)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#788e9c")
	drop.material = material
	rain.draw_pass_1 = drop
	add_child(rain)

func tick(game, dt: float, at: Vector3) -> void:
	if game.is_playing():
		hour = fposmod(hour + dt * 0.028, 24.0)
		weather_timer += dt
		if weather_timer > 245.0 and not game.sandbox:
			weather = (weather + randi_range(1, 3)) % WEATHER_ZH.size()
			weather_timer = 0.0
	var daylight := clampf(sin((hour - 6.0) * TAU / 24.0) * 1.27 + 0.14, 0, 1)
	wetness = lerpf(wetness, [0.0, 0.0, 0.06, 0.43, 1.0, 0.24, 0.93][weather], 1.0 - exp(-dt * 0.63))
	night = 1.0 - smoothstep(0.03, 0.51, daylight)
	flash = maxf(0, flash - dt * 3.8)
	if weather == 6 and game.is_playing():
		thunder_timer -= dt
		if thunder_timer < 0:
			thunder_timer = randf_range(12, 27)
			flash = 1.0
			game.feedback("thunder", at)
	rain.position = at + Vector3.UP * 8
	rain.emitting = wetness > 0.30 and not game.in_tunnel and not game.on_ferry
	rain.amount_ratio = (0.17 + wetness * 0.71) * (0.38 + game.quality * 0.20)
	update_clock += dt
	if update_clock < 0.09:
		return
	update_clock = 0
	var cloud: float = [0.0, 0.23, 0.57, 0.57, 0.73, 0.64, 0.76][weather]
	var dawn := (1.0 - absf(daylight - 0.27) / 0.40) * (1.0 - cloud) if daylight > 0.04 else 0.0
	dawn = clampf(dawn, 0.0, 1.0)
	sky.sky_top_color = Color("#0b1428").lerp(Color("#598eaf").lerp(Color("#62717b"), cloud), daylight)
	sky.sky_horizon_color = Color("#22324c").lerp(Color("#bfd2d6").lerp(Color("#ffc693"), dawn), daylight)
	sky.ground_horizon_color = sky.sky_horizon_color.darkened(0.26)
	sky.sun_curve = 0.045
	sky.sun_angle_max = 9.0 if daylight > 0.12 else 0.01
	sky.ground_bottom_color = Color("#18202b")
	sun.rotation = Vector3(-deg_to_rad(-22.0 + daylight * 80.0), deg_to_rad(fposmod(hour * 13.0 + 48.0, 360)), 0.0)
	sun.light_color = Color("#f1f0e8").lerp(Color("#ffad68"), dawn)
	sun.light_energy = daylight * (1.14 - cloud * 0.52) + flash * 2.75
	environment.ambient_light_color = Color("#748bb8").lerp(Color("#c4d6dd"), daylight)
	environment.ambient_light_energy = 0.49 + daylight * 0.23 + cloud * 0.09 + flash * 0.7
	environment.fog_enabled = true
	environment.fog_light_color = sky.sky_horizon_color.darkened(0.13) if not game.in_tunnel else Color("#303039")
	environment.fog_density = (0.0055 if weather == 5 else 0.00048 + cloud * 0.00070) if not game.in_tunnel else 0.0039
	sun.shadow_enabled = game.quality > 0 and daylight > 0.16 and not game.in_tunnel
	sun.directional_shadow_max_distance = 26 + game.quality * 27
	RenderingServer.global_shader_parameter_set("night", night)
	RenderingServer.global_shader_parameter_set("wetness", wetness)
	RenderingServer.global_shader_parameter_set("water_detail", 0.32 + game.quality * 0.23)
	if last_night != (night > 0.20):
		last_night = night > 0.20
		game.world.landmarks.night_light(night)
	game.audio.mix(wetness, night, game.on_ferry or game.world.is_water(at), game.wanted)
