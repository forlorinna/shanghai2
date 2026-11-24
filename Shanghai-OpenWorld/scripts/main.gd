extends Node3D

const World = preload("res://systems/world.gd")
const Climate = preload("res://systems/climate.gd")
const Sound = preload("res://systems/sound.gd")
const Streets = preload("res://systems/streets.gd")
const Storage = preload("res://systems/save.gd")
const Jobs = preload("res://systems/missions.gd")
const Person = preload("res://scripts/player.gd")
const Car = preload("res://assets/vehicles/vehicle.gd")
const Interface = preload("res://ui/interface.gd")
const A = preload("res://scripts/art.gd")

const DEFAULTS := {
	"language":"zh", "quality":1, "fps":60, "auto":true, "power":false,
	"vibration":true, "intensity":0.8, "camera":1.0, "steering":1.0,
	"volume":0.74, "effects_volume":0.85, "ambience_volume":0.72, "music_volume":0.50,
	"lefty":false, "controls_scale":1.0, "controls_alpha":0.72, "controls_offset":0.0,
	"gyro":false, "traffic":true, "crowds":1.0, "wanted":true,
}
const VIBE := {
	"ui":[17, 0.35], "land":[27, 0.54], "hurt":[75, 0.72], "crash":[36, 0.52],
	"crash_heavy":[140, 1.0], "brake":[44, 0.53], "drift":[75, 0.43], "bump":[25, 0.45],
	"thunder":[125, 0.70], "complete":[108, 0.52], "wanted":[81, 0.75],
}
var settings: Dictionary = DEFAULTS.duplicate(true)
var world
var climate
var player
var audio
var streets
var missions
var ui
var camera := Camera3D.new()
var driving
var cars: Array[CharacterBody3D] = []
var save_cache := {}
var started := false
var quality := 1
var yaw := -2.34
var pitch := -0.06
var camera_distance := 5.5
var camera_mode := 0
var money := 250
var owned := [0]
var unlocks := []
var outfit := 0
var wanted := 0
var heat_timer := 0.0
var arrest_timer := 0.0
var wanted_meter := 0.0
var free_explore := false
var sandbox := false
var infinite_health := false
var infinite_stamina := false
var infinite_money := false
var photo_mode := false
var free_camera := false
var free_position := Vector3.ZERO
var speed_scale := 1.0
var in_tunnel := false
var gate_delay := 0.0
var on_ferry := false
var departed_station := -1
var inside := false
var interior_return := Vector3.ZERO
var interior_root: Node3D
var apartment_root: Node3D
var touch_vector := Vector2.ZERO
var touch_flags: Dictionary = {}
var pressed: Dictionary = {}
var destination := Vector3.INF
var itinerary := PackedVector2Array()
var route_clock := 0.0
var save_clock := 0.0
var performance_clock := 0.0
var feedback_clock: Dictionary = {}
var fps_samples := 0.0
var notice_until := 0
var notice_text := ""

func _ready() -> void:
	_bind()
	save_cache = Storage.read()
	var config := ConfigFile.new()
	config.load("user://preferences.cfg")
	for key in settings:
		var candidate: Variant = config.get_value("settings", key, save_cache.get("settings", {}).get(key, settings[key]))
		if typeof(candidate) == typeof(settings[key]) or (settings[key] is int and candidate is float):
			settings[key] = candidate
	audio = Sound.new()
	add_child(audio)
	audio.start()
	world = World.new()
	add_child(world)
	world.start()
	climate = Climate.new()
	add_child(climate)
	climate.start()
	streets = Streets.new()
	add_child(streets)
	streets.build(self, world.data.roads, world.data.walkways)
	_add_entrance_signs()
	missions = Jobs.new()
	missions.game = self
	player = Person.new()
	player.create(self)
	add_child(player)
	var spawn := start_position()
	world.warm(spawn)
	player.position = spawn
	player.hero.visible = false
	add_child(camera)
	camera.current = true
	camera.fov = 72
	camera.near = 0.13
	camera.far = 3500
	_title_view()
	ui = Interface.new()
	ui.game = self
	add_child(ui)
	ui.open("title")
	apply_settings()
	climate.tick(self, 0.12, spawn)

func _bind() -> void:
	var bindings := {
		"move_left":[KEY_A, KEY_LEFT], "move_right":[KEY_D, KEY_RIGHT],
		"move_up":[KEY_W, KEY_UP], "move_down":[KEY_S, KEY_DOWN], "jump":[KEY_SPACE],
		"sprint":[KEY_SHIFT], "crouch":[KEY_CTRL], "walk":[KEY_ALT], "handbrake":[KEY_SPACE],
		"interact":[KEY_E], "vehicle":[KEY_F], "horn":[KEY_H], "camera":[KEY_V],
		"map":[KEY_M], "phone":[KEY_TAB], "pause":[KEY_ESCAPE], "capture":[KEY_F9],
		"debug":[KEY_F3], "turn_left":[KEY_Z], "turn_right":[KEY_X],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var input := InputEventKey.new()
			input.physical_keycode = key
			InputMap.action_add_event(action, input)
	for row in [["move_left", JOY_AXIS_LEFT_X, -1], ["move_right", JOY_AXIS_LEFT_X, 1], ["move_up", JOY_AXIS_LEFT_Y, -1], ["move_down", JOY_AXIS_LEFT_Y, 1]]:
		var stick := InputEventJoypadMotion.new()
		stick.axis = row[1]
		stick.axis_value = row[2]
		InputMap.action_add_event(row[0], stick)
	for row in [["jump", JOY_BUTTON_A], ["handbrake", JOY_BUTTON_A], ["vehicle", JOY_BUTTON_Y], ["interact", JOY_BUTTON_X], ["sprint", JOY_BUTTON_LEFT_SHOULDER], ["camera", JOY_BUTTON_RIGHT_SHOULDER], ["pause", JOY_BUTTON_START], ["horn", JOY_BUTTON_B]]:
		var button := InputEventJoypadButton.new()
		button.button_index = row[1]
		InputMap.action_add_event(row[0], button)

func is_playing() -> bool:
	return started and is_instance_valid(ui) and ui.screen == "game"

func bi(zh: String, en: String) -> String:
	return en if settings.get("language") == "en" else zh

func _title_view() -> void:
	camera.position = Vector3(-1142, 72, -615)
	camera.look_at(Vector3(-263, 161, -686))
	if world != null:
		world.warm(Vector3(-930, 0, -527))

func start_position() -> Vector3:
	var p: Array = world.data.spawn
	return Vector3(p[0], 0.14, p[1])

func begin(mode: String) -> void:
	if started:
		leave_vehicle(true)
		for vehicle in cars:
			vehicle.queue_free()
		cars.clear()
	inside = false
	in_tunnel = false
	on_ferry = false
	photo_mode = false
	free_camera = false
	apply_settings()
	money = 250
	wanted = 0
	owned = [0]
	unlocks = []
	outfit = 0
	clear_destination()
	missions.current.clear()
	missions.completed.clear()
	climate.hour = 16.25
	climate.weather = 0
	free_explore = mode == "free"
	sandbox = false
	var saved := save_cache if mode == "continue" else {}
	var pos := start_position()
	if not saved.is_empty():
		var p: Array = saved.position
		var restored := Vector3(p[0], clampf(p[1], 0.05, 2.0), p[2])
		if world.in_bounds(restored) and not world.is_water(restored):
			pos = restored
		money = maxi(0, int(saved.get("money", 250)))
		climate.hour = fposmod(float(saved.get("hour", 16.25)), 24.0)
		climate.weather = clampi(int(saved.get("weather", 0)), 0, 6)
		if saved.get("owned") is Array:
			owned = saved.owned.duplicate()
		if saved.get("unlocks") is Array:
			unlocks = saved.unlocks.duplicate()
		outfit = clampi(int(saved.get("outfit", 0)), 0, 2)
		if saved.get("completed") is Array:
			missions.completed = saved.completed.duplicate()
		var job: Dictionary = saved.get("mission", {})
		if job.has("id") and int(job.id) >= 0 and int(job.id) < Jobs.JOBS.size():
			missions.start(int(job.id))
			missions.current.merge(job, true)
			if int(job.get("leg", 0)) == 1:
				set_destination(place(Jobs.JOBS[int(job.id)][4], true))
	world.warm(pos)
	player.hero.visible = true
	player.reset_at(pos)
	player.set_driven(false)
	player.style_avatar(outfit)
	camera_mode = 0
	yaw = -2.34
	pitch = -0.06
	if saved.has("vehicle") and saved.vehicle.has("model"):
		var road: Dictionary = streets.spawn_space(pos)
		var color := Color.from_string(str(saved.vehicle.get("paint", "")), Color("#458b9d"))
		var vehicle := spawn_car(int(saved.vehicle.model), road.pos, road.yaw, color)
		vehicle.integrity = clampf(float(saved.vehicle.get("integrity", 100)), 0, 100)
		enter_vehicle(vehicle)
	else:
		var road: Dictionary = streets.spawn_space(pos)
		spawn_car(0, road.pos, road.yaw, Color("#4ba9ad"))
		var shoulder := Basis(Vector3.UP, float(road.yaw)).x * 3.0
		var parking: Vector3 = road.pos + shoulder + Vector3.UP * 0.12
		if world.in_bounds(parking) and not world.is_water(parking):
			player.reset_at(parking)
		var taxi_spot: Dictionary = streets.spawn_space(road.pos + Vector3(19, 0, 14))
		spawn_car(3, taxi_spot.pos, taxi_spot.yaw, Color("#deb650"))
	started = true
	ui.open("game")
	_camera(1.0, true)
	notice(bi("浦东 · 陆家嘴", "Pudong · Lujiazui"))

func apply_settings() -> void:
	quality = clampi(int(settings.quality), 0, 3)
	Engine.max_fps = 30 if settings.power else int(settings.fps)
	get_viewport().scaling_3d_scale = [0.72, 0.86, 1.0, 1.0][quality]
	world.map_radius = [1, 2, 3, 3][quality]
	audio.levels(settings)

func spawn_car(model: int, at: Vector3, direction: float, color := Color("#458b9d")) -> CharacterBody3D:
	var car := Car.new()
	car.create(self, model, color)
	add_child(car)
	car.position = at
	car.rotation.y = direction
	cars.append(car)
	if cars.size() > 12:
		for old in cars.duplicate():
			if old != driving and old != car:
				cars.erase(old)
				old.queue_free()
				break
	return car

func summon(model: int) -> void:
	if in_tunnel or on_ferry or inside:
		notice(bi("请在地面道路旁召唤车辆", "Summon vehicles from a surface street"))
		return
	if not owned.has(model) and not sandbox and model != 3:
		return
	var near: Dictionary = streets.spawn_space(focus() + Vector3(6, 0, 7))
	var car := spawn_car(model, near.pos, near.yaw, Color("#65a9af") if model != 3 else Color("#deb650"))
	notice(bi("车辆已停在附近道路", "Vehicle parked on a nearby street"))
	set_destination(car.position)

func enter_vehicle(car) -> void:
	driving = car
	car.use_driver(true)
	player.set_driven(true)
	yaw = car.rotation.y
	camera_mode = 0
	feedback("ui", car.position)

func leave_vehicle(force := false) -> void:
	if not is_instance_valid(driving):
		return
	if not force and absf(driving.speed) > 4.0:
		notice(bi("减速后下车", "Slow down before exiting"))
		return
	var car: CharacterBody3D = driving
	var side := car.global_basis.x * (float(driving.size.x) * 0.54 + 0.55)
	var exit: Vector3 = car.position - side + Vector3.UP * 0.16
	var params := PhysicsRayQueryParameters3D.create(car.position + Vector3.UP * 0.8, exit + Vector3.UP * 0.8, 1)
	if not get_world_3d().direct_space_state.intersect_ray(params).is_empty():
		exit = car.position + side + Vector3.UP * 0.16
	car.use_driver(false)
	driving = null
	player.set_driven(false)
	player.position = exit
	camera_mode = 0

func toggle_car() -> void:
	if on_ferry or inside:
		return
	if driving != null:
		leave_vehicle()
		return
	var nearest = null
	var distance := 5.8
	for car in cars:
		var dist := car.position.distance_to(player.position)
		if dist < distance:
			nearest = car
			distance = dist
	if nearest != null:
		enter_vehicle(nearest)
	else:
		notice(bi("靠近停放的车辆后上车", "Approach a parked vehicle to enter"))

func motion() -> Vector2:
	var value := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if touch_vector.length_squared() > 0.01:
		value = touch_vector
	if driving != null:
		value.x += float(flag("steer_right")) - float(flag("steer_left"))
		value.y += float(flag("reverse")) - float(flag("accelerate"))
		var forward := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
		var reverse := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
		value.y += reverse - forward
		if settings.gyro and OS.has_feature("android"):
			var gyro := Input.get_accelerometer()
			if gyro.length_squared() > 1.0:
				value.x += clampf(gyro.x / 4.5, -0.88, 0.88)
	return value.limit_length(1.0) if driving == null else value.clamp(-Vector2.ONE, Vector2.ONE)

func flag(action: String) -> bool:
	return bool(touch_flags.get(action, false)) or (InputMap.has_action(action) and Input.is_action_pressed(action))

func consume(action: String) -> bool:
	if pressed.has(action):
		pressed.erase(action)
		return true
	return false

func press_action(action: String) -> void:
	if not is_playing() and action != "pause":
		return
	if action in ["jump", "horn"]:
		pressed[action] = true
		return
	match action:
		"vehicle": toggle_car()
		"interact": interact()
		"camera": camera_mode = (camera_mode + 1) % (3 if driving != null else 2)
		"map", "phone": ui.open(action)
		"pause":
			if ui.screen == "game":
				ui.open("pause")
			elif started:
				ui.open("game")
		"capture": capture()
		"debug": ui.debug = not ui.debug

func look(delta: Vector2) -> void:
	if is_playing():
		yaw -= delta.x * 0.0044 * float(settings.camera)
		pitch = clampf(pitch - delta.y * 0.0044 * float(settings.camera), -1.16, 1.03)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)
	if event is InputEventMouseButton and event.pressed and is_playing():
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if not OS.has_feature("mobile"):
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			camera_distance = clampf(camera_distance + (1.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0), 2.5, 12)
	if event is InputEventJoypadMotion and is_playing() and event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		if absf(event.axis_value) > 0.17:
			get_viewport().set_input_as_handled()
	for action in ["jump", "vehicle", "interact", "camera", "map", "phone", "pause", "horn", "capture", "debug"]:
		if event.is_action_pressed(action, false):
			press_action(action)

func focus() -> Vector3:
	if on_ferry:
		return world.boat.position
	if driving != null:
		return driving.position
	return player.position

func _camera(delta: float, snap := false) -> void:
	if free_camera:
		var v := motion()
		free_position += Basis.from_euler(Vector3(pitch, yaw, 0)) * Vector3(v.x, 0, v.y) * delta * 24.0 * speed_scale
		camera.position = free_position
		camera.rotation = Vector3(pitch, yaw, 0)
		return
	var base := focus()
	var car_view: bool = driving != null
	if car_view and absf(driving.speed) > 5.0 and not flag("steer_left") and not flag("steer_right") and camera_mode == 0:
		yaw = lerp_angle(yaw, driving.rotation.y, 1.0 - exp(-delta * 0.52))
	var target := base + Vector3.UP * (2.0 if car_view else 1.57)
	if on_ferry:
		target.y += 2.5
	var direction := Basis.from_euler(Vector3(pitch, yaw, 0))
	var desired := target + direction.z * (camera_distance + (2.3 if car_view else 0.0))
	if camera_mode > 0:
		desired = target - direction.z * 0.12
		camera.rotation = Vector3(pitch, yaw, 0)
		if car_view:
			desired = driving.to_global(Vector3(0, driving.size.y * (0.87 if camera_mode == 1 else 0.65), -driving.size.z * (0.20 if camera_mode == 1 else 0.57)))
	else:
		var params := PhysicsRayQueryParameters3D.create(target, desired, 1)
		var ray := get_world_3d().direct_space_state.intersect_ray(params)
		if not ray.is_empty():
			desired = ray.position + ray.normal * 0.23
	var smoothing := 1.0 if snap or camera_mode > 0 else 1.0 - exp(-delta * 15.0)
	camera.position = camera.position.lerp(desired, smoothing)
	if camera_mode == 0 and camera.position.distance_squared_to(target) > 0.001:
		camera.look_at(target)
	player.hero.visible = not car_view and camera_mode == 0 and not on_ferry

func _physics_process(delta: float) -> void:
	if world == null:
		return
	var at := focus()
	world.stream(Vector3(-645, 0, -521) if is_instance_valid(ui) and ui.screen == "title" else (interior_return if inside else at), delta)
	climate.tick(self, delta, at)
	if not is_playing():
		return
	world.move_ferry(delta)
	if not inside:
		streets.tick(delta, at)
	_camera(delta)
	if not world.in_bounds(at) and not inside:
		respawn()
		return
	gate_delay = maxf(0, gate_delay - delta)
	if on_ferry:
		player.position = world.boat.position + Vector3.UP * 1.50
		if world.ferry_pause > 0 and world.ferry_station != departed_station:
			var landing: Vector3 = world.ferry_path[0] if world.ferry_station == 0 else world.ferry_path[-1]
			on_ferry = false
			player.set_driven(false)
			teleport(landing + Vector3.UP * 0.83)
			missions.event("ferry", landing)
	elif in_tunnel and gate_delay == 0:
		for index in 2:
			if at.distance_to(world.last_end(index)) < 5.7:
				cross_gate(index)
				break
	if in_tunnel and at.y < -37:
		respawn()
	missions.tick(at, delta)
	_update_wanted(delta, at)
	save_clock += delta
	if save_clock >= 35.0:
		save_clock = 0.0
		save_game(false)
	route_clock += delta
	if destination.is_finite() and route_clock >= 2.8:
		route_clock = 0.0
		_update_route(at)

func _process(delta: float) -> void:
	if not is_playing():
		return
	var joy := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if joy.length_squared() > 0.035:
		look(joy * delta * 840.0)
	if settings.auto:
		performance_clock += delta
		fps_samples += Engine.get_frames_per_second() * delta
		if performance_clock >= 8.0:
			if quality > 0 and (fps_samples / performance_clock < 28.0 or Performance.get_monitor(Performance.MEMORY_STATIC) > 490_000_000):
				quality -= 1
				world.map_radius = [1, 2, 3, 3][quality]
				get_viewport().scaling_3d_scale = [0.72, 0.86, 1.0, 1.0][quality]
			performance_clock = 0.0
			fps_samples = 0.0

func place(key: String, roadside := true) -> Vector3:
	for entry in world.data.landmarks:
		if entry[0] == key:
			var p := Vector3(entry[3][0], 0.08, entry[3][1])
			return streets.spawn_space(p).pos if roadside else p
	return start_position()

func set_destination(at: Vector3) -> void:
	destination = at
	_update_route(focus())
	route_clock = 0.0

func clear_destination() -> void:
	destination = Vector3.INF
	itinerary.clear()

func _update_route(at: Vector3) -> void:
	itinerary = streets.route(at, destination)
	if itinerary.is_empty() and at.distance_to(destination) > 15.0:
		var a := 0 if at.distance_to(world.gate(0)) < at.distance_to(world.gate(1)) else 1
		itinerary = streets.route(at, world.gate(a))
		var tunnel: PackedVector3Array = world.tunnel.duplicate()
		if a == 1:
			tunnel.reverse()
		for p in tunnel:
			itinerary.append(Vector2(p.x, p.z))
		itinerary.append_array(streets.route(world.gate(1 - a), destination))

func teleport(at: Vector3) -> void:
	if not world.in_bounds(at):
		return
	world.warm(at)
	var actor: CharacterBody3D = driving if driving != null else player
	actor.position = at
	actor.velocity = Vector3.ZERO
	if driving != null:
		driving.speed = 0.0
	if camera.is_inside_tree():
		camera.position = actor.position + Vector3(0, 2.8, 4.5)

func interact() -> void:
	var at := focus()
	if inside:
		inside = false
		teleport(interior_return)
		return
	if on_ferry:
		return
	if gate_delay <= 0:
		for index in 2:
			var point: Vector3 = world.last_end(index) if in_tunnel else world.gate(index)
			if at.distance_to(point) < 15.0:
				cross_gate(index)
				return
	if in_tunnel:
		return
	if driving == null:
		for index in 2:
			var dock: Vector3 = world.ferry_path[0] if index == 0 else world.ferry_path[-1]
			if at.distance_to(dock) < 30:
				if world.ferry_pause > 0 and world.ferry_station == index:
					on_ferry = true
					player.set_driven(true)
					departed_station = index
					world.ferry_pause = minf(2.4, world.ferry_pause)
					audio.play_spatial("ferry", world.boat.position, -4)
					return
				notice(bi("轮渡正在江上航行 · 请稍候", "The ferry is crossing · wait at the dock"))
				return
		if at.distance_to(cafe_entrance()) < 7.0:
			_open_cafe()
			return
		if at.distance_to(apartment_entrance()) < 7.0:
			if unlocks.has("apartment"):
				_open_apartment()
			else:
				notice(bi("在手机车库与收藏中解锁住所", "Unlock the apartment in Garage & collection"))
			return
		for entry in streets.people:
			if entry.node.position.distance_to(at) < 3.7:
				notice([bi("沿江走一走，晚上灯光很好看。", "Walk along the river after dark. The lights are worth it."), bi("过江可以搭轮渡，也可以走延安东路隧道。", "Take the ferry or the Yan’an Tunnel to cross."), bi("去陆家嘴中心绿地看看吧。", "Have you seen Lujiazui Central Green?")].pick_random())
				return
	notice(bi("这里没有可交互的对象", "Nothing to interact with here"))

func interaction_hint() -> String:
	var at := focus()
	if inside:
		return bi("E  ·  返回街道", "E  ·  Return to the street")
	if on_ferry:
		return bi("黄浦江轮渡 · 正在航行", "Huangpu ferry · Crossing")
	for index in 2:
		var point: Vector3 = world.last_end(index) if in_tunnel else world.gate(index)
		if at.distance_to(point) < 15:
			return bi("E  ·  延安东路隧道", "E  ·  Yan’an road tunnel")
	if driving == null:
		if at.distance_to(cafe_entrance()) < 7:
			return bi("E  ·  进入滨江咖啡馆", "E  ·  Enter Riverside Café")
		if at.distance_to(apartment_entrance()) < 7:
			return bi("E  ·  城市公寓", "E  ·  City apartment")
		if at.distance_to(world.ferry_path[0]) < 30 or at.distance_to(world.ferry_path[-1]) < 30:
			return bi("E  ·  轮渡码头", "E  ·  Ferry dock")
		for car in cars:
			if at.distance_to(car.position) < 5.8:
				return bi("F  ·  上车", "F  ·  Enter vehicle")
	return ""

func cafe_entrance() -> Vector3:
	return start_position() + Vector3(4.5, 0, 6.6)

func apartment_entrance() -> Vector3:
	return place("green", true) + Vector3(3.4, 0, 8.2)

func _add_entrance_signs() -> void:
	for record in [[cafe_entrance(), "滨江咖啡馆  /  RIVERSIDE CAFÉ"], [apartment_entrance(), "城市公寓  /  CITY APARTMENT"]]:
		var post := Node3D.new()
		post.position = record[0]
		add_child(post)
		var sign := Label3D.new()
		sign.font = preload("res://assets/textures/city-font.otf")
		sign.text = record[1]
		sign.font_size = 48
		sign.outline_size = 12
		sign.pixel_size = 0.008
		sign.position.y = 2.50
		sign.modulate = Color("#ffe3bf")
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.visibility_range_end = 55.0
		post.add_child(sign)
		A.cylinder(post, Vector3(0, 0.71, 0), 1.42, 0.065, 0.050, A.material(Color("#698783")), 8)
		A.box(post, Vector3(0, 1.53, 0), Vector3(0.45, 0.49, 0.10), A.material(Color("#a7744b")))

func _open_apartment() -> void:
	if apartment_root == null:
		apartment_root = Node3D.new()
		apartment_root.name = "CityApartment"
		apartment_root.position = Vector3(22, 680, 0)
		add_child(apartment_root)
		var oak := A.material(Color("#a98360"))
		var plaster := A.material(Color("#e8d7bc"))
		var fabric := A.material(Color("#41686a"))
		A.box(apartment_root, Vector3(0, -0.18, 0), Vector3(9, 0.34, 10), oak)
		A.collider(apartment_root, Vector3(0, -0.18, 0), Vector3(9, 0.34, 10))
		A.box(apartment_root, Vector3(0, 3.6, 0), Vector3(9, 0.24, 10), plaster)
		for side in [-1, 1]:
			A.box(apartment_root, Vector3(side * 4.45, 1.7, 0), Vector3(0.24, 3.4, 10), plaster)
			A.collider(apartment_root, Vector3(side * 4.45, 1.7, 0), Vector3(0.24, 3.4, 10))
			A.box(apartment_root, Vector3(0, 1.7, side * 4.95), Vector3(9, 3.4, 0.23), plaster)
			A.collider(apartment_root, Vector3(0, 1.7, side * 4.95), Vector3(9, 3.4, 0.23))
		A.box(apartment_root, Vector3(-2.1, 0.30, -3.3), Vector3(2.3, 0.60, 2.9), fabric)
		A.box(apartment_root, Vector3(-2.1, 0.64, -4.24), Vector3(2.1, 0.15, 0.6), plaster)
		A.box(apartment_root, Vector3(3.4, 0.42, -0.85), Vector3(1.1, 0.84, 3.2), oak)
		A.box(apartment_root, Vector3(0, 0.035, 1), Vector3(3.3, 0.03, 5), fabric)
		var light := OmniLight3D.new()
		light.position = Vector3(0, 3.1, 0)
		light.light_color = Color("#ffcb9d")
		light.omni_range = 12
		light.light_energy = 2.7
		apartment_root.add_child(light)
	interior_return = apartment_entrance()
	inside = true
	player.position = apartment_root.position + Vector3(0, 0.15, 3.2)
	player.velocity = Vector3.ZERO
	_camera(1.0, true)
	notice(bi("城市公寓", "City apartment"))

func buy_unlock(item: String, cost: int) -> bool:
	if unlocks.has(item):
		return true
	if money < cost and not infinite_money:
		notice(bi("余额不足", "Insufficient funds"))
		return false
	if not infinite_money:
		money -= cost
	unlocks.append(item)
	save_game(false)
	return true

func _open_cafe() -> void:
	if interior_root == null:
		interior_root = Node3D.new()
		add_child(interior_root)
		interior_root.position = Vector3(0, 680, 0)
		var oak := A.material(Color("#a47e63"))
		var tile := A.material(Color("#595c5c"))
		var wall := A.material(Color("#e1d1b4"))
		A.box(interior_root, Vector3.DOWN * 0.16, Vector3(12, 0.30, 16), tile)
		A.collider(interior_root, Vector3.DOWN * 0.17, Vector3(12, 0.35, 16))
		A.box(interior_root, Vector3(0, 3.75, 0), Vector3(12, 0.21, 16), wall)
		for side in [-1, 1]:
			A.box(interior_root, Vector3(side * 6, 1.8, 0), Vector3(0.25, 3.6, 16), wall)
			A.collider(interior_root, Vector3(side * 6, 1.8, 0), Vector3(0.26, 3.6, 16))
			A.box(interior_root, Vector3(0, 1.8, side * 8), Vector3(12, 3.6, 0.25), wall)
			A.collider(interior_root, Vector3(0, 1.8, side * 8), Vector3(12, 3.6, 0.26))
		A.box(interior_root, Vector3(0, 0.55, -5.4), Vector3(7.2, 1.1, 1.05), oak)
		A.collider(interior_root, Vector3(0, 0.55, -5.4), Vector3(7.2, 1.1, 1.05))
		for x in [-3.3, 3.3]:
			for z in [-2.5, 1.5, 5.0]:
				A.cylinder(interior_root, Vector3(x, 0.75, z), 0.10, 0.72, 0.72, oak, 18)
				A.cylinder(interior_root, Vector3(x, 0.34, z), 0.68, 0.10, 0.09, tile)
		for z in [-5, 0, 5]:
			var light := OmniLight3D.new()
			light.position = Vector3(0, 3.38, z)
			light.light_color = Color("#ffcb8d")
			light.light_energy = 1.9
			light.omni_range = 15
			interior_root.add_child(light)
	interior_return = cafe_entrance()
	inside = true
	player.position = interior_root.position + Vector3(0, 0.2, 5.8)
	player.velocity = Vector3.ZERO
	_camera(1.0, true)
	notice(bi("滨江咖啡馆", "Riverside Café"))

func cross_gate(index: int) -> void:
	gate_delay = 3.0
	var end: Vector3 = world.last_end(index)
	var next: Vector3 = world.tunnel[1] if index == 0 else world.tunnel[-2]
	var direction := end.direction_to(next)
	var actor: CharacterBody3D = driving if driving != null else player
	if in_tunnel:
		in_tunnel = false
		teleport(world.gate(index) - direction * 3.0 + Vector3.UP * 0.12)
		direction = -direction
	else:
		in_tunnel = true
		teleport(end + direction * 8.5 + Vector3.UP * 0.11)
	actor.rotation.y = atan2(-direction.x, -direction.z)
	yaw = actor.rotation.y
	notice(bi("延安东路隧道", "Yan’an Road Tunnel") if in_tunnel else bi("已驶出延安东路隧道", "Exited the Yan’an Road Tunnel"))

func collision_offence(impact: float, collider: Object) -> void:
	if impact < 4.5 or collider == null:
		return
	if collider is CharacterBody3D and collider.collision_layer in [4, 8]:
		wanted_meter += impact
		if wanted_meter > 10.0:
			wanted_meter = 0
			set_wanted(wanted + 1)
	if impact > 13.5:
		player.damage(impact * 0.62)

func set_wanted(level: int) -> void:
	var enabled: bool = settings.wanted and not free_explore
	var n := clampi(level, 0, 5) if enabled else 0
	if wanted != n:
		wanted = n
		heat_timer = 22.0 + n * 5.0
		feedback("wanted", focus())

func _update_wanted(delta: float, at: Vector3) -> void:
	if not settings.wanted or free_explore:
		wanted = 0
		return
	if wanted <= 0:
		return
	var distance: float = streets.nearby_police(at)
	if distance > 52.0 or in_tunnel:
		heat_timer -= delta
		if heat_timer <= 0.0:
			set_wanted(wanted - 1)
	if distance < 13.0 and (driving == null or absf(driving.speed) < 2.2):
		arrest_timer += delta
		if arrest_timer > 5:
			money = maxi(0, money - 100)
			respawn()
			notice(bi("追捕结束 · 扣除 ¥100", "Pursuit ended · ¥100 deducted"))
	else:
		arrest_timer = 0.0

func respawn() -> void:
	leave_vehicle(true)
	in_tunnel = false
	on_ferry = false
	inside = false
	set_wanted(0)
	arrest_timer = 0.0
	world.warm(start_position())
	player.set_driven(false)
	player.reset_at(start_position())

func feedback(event: String, at: Vector3) -> void:
	var now := Time.get_ticks_msec()
	if int(feedback_clock.get(event, 0)) > now:
		return
	feedback_clock[event] = now + 190
	var sound_map := {"land":"step", "hurt":"impact", "crash":"impact", "crash_heavy":"impact", "brake":"skid", "drift":"skid", "bump":"step", "thunder":"thunder", "complete":"complete"}
	if sound_map.has(event):
		audio.play_spatial(sound_map[event], at, -3.0 if event in ["thunder", "crash_heavy"] else -7.0)
	if event == "hurt" and ui != null:
		ui.hurt()
	if settings.vibration and OS.has_feature("android") and VIBE.has(event):
		var pattern: Array = VIBE[event]
		var intensity: float = clampf(float(settings.intensity) * float(pattern[1]), 0, 1)
		if intensity > 0.01:
			Input.vibrate_handheld(int(pattern[0]), intensity)
			if event in ["complete", "wanted", "crash_heavy"]:
				var pause := 0.17 if event == "crash_heavy" else 0.13
				get_tree().create_timer(pause).timeout.connect(func():
					if is_inside_tree() and settings.vibration and float(settings.intensity) > 0.01:
						Input.vibrate_handheld(43 if event == "complete" else 27, intensity * 0.58)
				)

func notice(message: String) -> void:
	notice_text = message
	notice_until = Time.get_ticks_msec() + 4000
	if ui != null:
		ui.show_notice()

func save_game(show := true) -> void:
	if not started:
		return
	var p := start_position() if in_tunnel or inside or on_ferry or world.is_water(focus()) else focus()
	var saved := {
		"position":[p.x,p.y,p.z], "hour":climate.hour, "weather":climate.weather,
		"settings":settings.duplicate(true), "money":money, "mission":missions.current.duplicate(true),
		"completed":missions.completed.duplicate(), "owned":owned.duplicate(), "unlocks":unlocks.duplicate(), "outfit":outfit,
	}
	if driving != null:
		saved.vehicle = {"model":driving.variant, "paint":driving.paint.to_html(), "integrity":driving.integrity}
	if Storage.write(saved) == OK:
		save_cache = saved
		if show:
			notice(bi("存档已写入本机", "Saved on this device"))
	elif show:
		notice(bi("无法保存 · 请检查可用空间", "Could not save · Check free storage"))

func capture() -> void:
	if not started or DisplayServer.get_name() == "headless":
		return
	ui.visible = false
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	ui.visible = true
	DirAccess.make_dir_recursive_absolute("user://photos")
	var path := "user://photos/Shanghai-%s.png" % int(Time.get_unix_time_from_system())
	if image.save_png(path) == OK:
		missions.event("photo", focus())
		notice(bi("照片已保存 · 应用本地目录", "Photo saved in local app storage"))

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST] and started:
		save_game(false)

func save_settings() -> void:
	var config := ConfigFile.new()
	for key in settings:
		config.set_value("settings", key, settings[key])
	config.save("user://preferences.cfg")
