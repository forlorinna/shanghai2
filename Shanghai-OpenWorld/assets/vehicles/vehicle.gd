extends CharacterBody3D

const A = preload("res://scripts/art.gd")
const TYPES := ["sedan", "suv", "sports", "taxi", "bus", "motorcycle", "police"]
const SIZES := [
	Vector3(1.82, 1.46, 4.40), Vector3(2.02, 1.92, 4.64), Vector3(1.98, 1.25, 4.30),
	Vector3(1.84, 1.53, 4.43), Vector3(2.62, 3.18, 9.2), Vector3(0.67, 1.26, 2.18),
	Vector3(1.86, 1.54, 4.58),
]
const TOP_SPEED := [38.0, 35.0, 54.0, 36.0, 25.0, 45.0, 44.0]
var game
var variant := 0
var paint := Color("#458b9d")
var size := Vector3.ONE
var active := false
var speed := 0.0
var steering := 0.0
var integrity := 100.0
var shell := Node3D.new()
var wheels: Array[Node3D] = []
var wheel_rest: Array[Vector3] = []
var suspension_clocks := 0.0
var body_pitch := 0.0
var headlamps: Array[MeshInstance3D] = []
var rear: Array[MeshInstance3D] = []
var signals: Array[MeshInstance3D] = []
var body_panels: Array[MeshInstance3D] = []
var door: Node3D
var door_timer := 0.0
var light: SpotLight3D
var cooldown := 0.0
var surface_clock := 0.0
var engine: AudioStreamPlayer3D

func create(context, model: int, color: Color, is_traffic := false, stripped := false) -> void:
	game = context
	variant = clampi(model, 0, TYPES.size() - 1)
	paint = color
	size = SIZES[variant]
	collision_layer = 4 if not is_traffic else 8
	collision_mask = 1 | 4 | 8
	floor_snap_length = 0.58
	floor_max_angle = deg_to_rad(47)
	var hit := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x * 0.94, size.y * 0.74, size.z * 0.96)
	hit.shape = shape
	hit.position.y = shape.size.y * 0.5 + 0.014
	add_child(hit)
	add_child(shell)
	_build(stripped)
	if not is_traffic:
		engine = AudioStreamPlayer3D.new()
		engine.stream = context.audio.samples.get("motor")
		engine.unit_size = 10.0
		engine.max_distance = 55.0
		engine.bus = &"Effects"
		engine.volume_db = -16
		add_child(engine)

func _panel(at: Vector3, extent: Vector3, mat: Material, contoured := false) -> MeshInstance3D:
	var part := A.coachwork(shell, at, extent, mat) if contoured else A.box(shell, at, extent, mat)
	body_panels.append(part)
	return part

func _build(stripped: bool) -> void:
	var body := A.material(paint, 0.35, 0.32)
	var tires := A.material(Color("#1d2228"))
	var trim := A.material(Color("#25313a"), 0.30)
	var windows := A.material(Color("#243f4e"), 0.42, 0.26)
	var metal := A.material(Color("#a2aeb0"), 0.6, 0.32)
	var red := A.material(Color("#b73d37"))
	var white := A.material(Color("#e9f3f1"), 0.1, 0.28)
	var w := size.x
	var h := size.y
	var l := size.z
	if variant == 5:
		_panel(Vector3(0, h * 0.62, -l * 0.14), Vector3(w * 0.91, h * 0.52, l * 0.50), body)
		A.box(shell, Vector3(0, h * 0.72, l * 0.13), Vector3(w * 0.66, 0.15, l * 0.46), trim)
		A.beam(shell, Vector3(0, 0.43, -l * 0.30), Vector3(0, 1.14, -l * 0.17), 0.04, metal)
		A.box(shell, Vector3(0, 1.16, -l * 0.17), Vector3(w, 0.075, 0.08), trim)
	else:
		_panel(Vector3(0, h * 0.32, 0), Vector3(w, h * 0.46, l), body, not stripped)
		_panel(Vector3(0, h * 0.53, -l * 0.26), Vector3(w * 0.94, h * 0.12, l * 0.43), body, not stripped)
		_panel(Vector3(0, h * 0.54, l * 0.31), Vector3(w * 0.95, h * 0.16, l * 0.33), body, not stripped)
		var cabin_ratio := 0.89 if variant == 4 else (0.70 if variant == 1 else 0.57)
		if not stripped and variant != 4:
			A.coachwork(shell, Vector3(0, h * 0.69, 0.08 * l), Vector3(w * 0.91, h * 0.51, l * cabin_ratio), windows, true)
			_panel(Vector3(0, h * 0.95, 0.11 * l), Vector3(w * 0.70, h * 0.051, l * cabin_ratio * 0.68), body, true)
		else:
			A.box(shell, Vector3(0, h * 0.69, 0.07 * l), Vector3(w * 0.87, h * 0.47, l * cabin_ratio), windows)
			_panel(Vector3(0, h * 0.94, 0.07 * l), Vector3(w * 0.90, h * 0.08, l * cabin_ratio * 0.95), body)
		A.box(shell, Vector3(0, h * 0.29, -l * 0.501), Vector3(w * 0.82, h * 0.18, 0.07), trim)
		if variant == 3 or variant == 6:
			A.box(shell, Vector3(0, h * 1.01, 0), Vector3(w * 0.48, 0.13, 0.28), A.material(Color("#ffce63") if variant == 3 else Color("#519dff"), 0, 0.5, true))
		if not stripped:
			door = Node3D.new()
			door.position = Vector3(-w * 0.508, h * 0.52, -l * 0.12)
			shell.add_child(door)
			var door_panel := A.box(door, Vector3(0, 0, l * 0.13), Vector3(0.06, h * 0.23, l * 0.25), body)
			body_panels.append(door_panel)
			A.box(door, Vector3(-0.042, h * 0.039, l * 0.20), Vector3(0.04, 0.036, 0.15), metal)
	for side in ([-1, 1] if variant != 5 else [0]):
		for axle in [-1, 1]:
			var radius := clampf(h * 0.235, 0.27, 0.49)
			var tire := Node3D.new()
			tire.position = Vector3(side * w * 0.46, radius, axle * l * 0.32)
			tire.rotation.z = PI * 0.5
			shell.add_child(tire)
			A.cylinder(tire, Vector3.ZERO, 0.205, radius, radius, tires, 12 if not stripped else 8)
			if not stripped:
				A.cylinder(tire, Vector3.ZERO, 0.22, radius * 0.63, radius * 0.63, metal, 11)
			wheels.append(tire)
			wheel_rest.append(tire.position)
	for side in ([-1, 1] if variant != 5 else [0]):
		headlamps.append(A.box(shell, Vector3(w * side * 0.31, h * 0.46, -l * 0.503), Vector3(w * 0.24, h * 0.075, 0.075), white))
		rear.append(A.box(shell, Vector3(w * side * 0.32, h * 0.47, l * 0.503), Vector3(w * 0.22, h * 0.075, 0.073), red))
		if not stripped:
			signals.append(A.box(shell, Vector3(w * side * 0.467, h * 0.47, l * 0.499), Vector3(0.087, 0.11, 0.071), A.material(Color("#a65d29"))))

func repaint(color: Color) -> void:
	paint = color
	var surface := A.material(paint, 0.35, 0.32)
	for panel in body_panels:
		panel.material_override = surface

func use_driver(value: bool) -> void:
	active = value
	door_timer = 0.7
	if value and light == null:
		light = SpotLight3D.new()
		light.position = Vector3(0, size.y * 0.47, -size.z * 0.53)
		light.spot_range = 46
		light.spot_angle = 33
		light.rotation.x = -0.075
		light.light_color = Color("#e3f6ff")
		light.light_energy = 2.0
		add_child(light)
	if engine:
		if value and engine.stream and DisplayServer.get_name() != "headless":
			engine.play()
		else:
			engine.stop()
	if light:
		light.visible = value and game.climate.night > 0.25

func animate_wheels(delta: float, value: float) -> void:
	for tire in wheels:
		tire.rotate_object_local(Vector3.UP, -value * delta * 2.8)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.is_playing() or collision_layer == 8:
		return
	if not active and position.distance_squared_to(game.focus()) > 70_000:
		return
	if door_timer > 0.0:
		door_timer = maxf(door_timer - delta, 0.0)
		if door:
			door.rotation.y = -sin(door_timer * PI / 0.7) * 0.86
	var controls: Vector2 = game.motion() if active else Vector2.ZERO
	var brake: bool = active and game.flag("handbrake")
	var throttle := -controls.y
	var old_speed := speed
	cooldown = maxf(0.0, cooldown - delta)
	var drive := 12.8 if variant == 2 or variant == 5 else 9.6
	if integrity < 30.0:
		drive *= 0.62
	var reversing := throttle * speed < -0.4
	speed += throttle * (26.5 if reversing else drive) * delta
	speed = move_toward(speed, 0.0, (20.0 if brake else (1.0 + absf(speed) * 0.026)) * delta)
	speed = clampf(speed, -12.0, TOP_SPEED[variant])
	if absf(speed) < 0.35 and absf(throttle) < 0.08:
		speed = 0.0
	steering = lerpf(steering, controls.x, 1.0 - exp(-delta * 8.0))
	var grip: float = (0.85 - game.climate.wetness * 0.20) if brake else (1.0 - game.climate.wetness * 0.18)
	var steering_gain := (2.05 / (1.0 + absf(speed) * 0.079)) * minf(1.0, absf(speed) * 0.30)
	if active:
		rotation.y -= steering * steering_gain * signf(speed) * delta * float(game.settings.get("steering", 1.0))
		if brake and cooldown == 0.0 and absf(old_speed) > 12.0:
			game.feedback("drift" if absf(steering) > 0.3 else "brake", global_position)
			cooldown = 0.75
	var aim := -global_basis.z * speed
	var response := 1.0 - exp(-delta * (2.6 if brake else 11.0) * grip)
	velocity.x = lerpf(velocity.x, aim.x, response)
	velocity.z = lerpf(velocity.z, aim.z, response)
	velocity.y = -1.6 if is_on_floor() else velocity.y - 17.4 * delta
	var before_velocity := velocity
	move_and_slide()
	var impact := Vector2(velocity.x - before_velocity.x, velocity.z - before_velocity.z).length()
	if get_slide_collision_count() and impact > 2.0:
		speed *= 0.26 if impact > 8 else 0.57
		if cooldown == 0.0 and active:
			integrity = maxf(0, integrity - impact * 1.8)
			game.feedback("crash_heavy" if impact > 8.0 else "crash", global_position)
			game.collision_offence(impact, get_last_slide_collision().get_collider())
			if impact > 8.0 and not body_panels.is_empty():
				body_panels[0].scale.x = maxf(0.88, body_panels[0].scale.x - impact * 0.0016)
				body_panels[0].material_override = A.material(paint.darkened((100.0 - integrity) * 0.0022), 0.27, 0.56)
			cooldown = 0.6
	if active and global_position.y < -11 and not game.in_tunnel:
		game.leave_vehicle(true)
		game.respawn()
		return
	animate_wheels(delta, speed)
	shell.rotation.z = lerpf(shell.rotation.z, steering * speed * (0.008 if variant == 5 else 0.0012), response)
	suspension_clocks += delta
	if active and suspension_clocks >= 0.055:
		_sample_suspension(suspension_clocks)
		suspension_clocks = 0
	shell.rotation.x = lerpf(shell.rotation.x, body_pitch + clampf((speed - old_speed) * 0.13, -0.075, 0.075), response)
	if active and engine:
		engine.pitch_scale = clampf(0.68 + absf(speed) * 0.038 + absf(throttle) * 0.12, 0.6, 2.25)
		if game.consume("horn"):
			game.audio.play_spatial("horn", global_position, -1.0)
	if active and is_on_floor() and absf(speed) > 9.0:
		surface_clock += delta
		if surface_clock > 2.9:
			surface_clock = 0.0
			if absf(get_floor_normal().y) < 0.985:
				game.feedback("bump", global_position)
	_lights(reversing or brake, active and game.flag("turn_left"), active and game.flag("turn_right"))

func _sample_suspension(delta: float) -> void:
	var front_height := 0.0
	var rear_height := 0.0
	for index in wheels.size():
		var tire := wheels[index]
		var rest := wheel_rest[index]
		var at := to_global(Vector3(rest.x, 0, rest.z))
		var params := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.65, at - Vector3.UP * 0.67, 1)
		var ground := get_world_3d().direct_space_state.intersect_ray(params)
		var lift := -0.15 if ground.is_empty() else clampf(float(ground.position.y) - global_position.y, -0.16, 0.16)
		tire.position.y = lerpf(tire.position.y, rest.y + lift, 1.0 - exp(-delta * 16.0))
		if rest.z < 0:
			front_height += lift
		else:
			rear_height += lift
	var axles := float(maxi(1, wheels.size() / 2))
	body_pitch = clampf((front_height - rear_height) / (size.z * axles), -0.12, 0.12)

func _lights(braking: bool, left: bool, right: bool) -> void:
	var night: bool = game.climate.night > 0.25
	for lamp in headlamps:
		lamp.material_override = A.material(Color("#e1effe"), 0.1, 0.4, night)
	for lamp in rear:
		lamp.material_override = A.material(Color("#f35a4e") if braking else Color("#ae392e"), 0.05, 0.5, night or braking)
	var blink := (Time.get_ticks_msec() / 450) % 2 == 0
	for i in signals.size():
		signals[i].material_override = A.material(Color("#f4a445") if blink and (left if i == 0 else right) else Color("#a65d29"), 0, 0.6, blink and (left if i == 0 else right))
	if light:
		light.visible = night and active
