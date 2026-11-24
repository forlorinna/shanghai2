extends SceneTree

const Scene = preload("res://game/main.tscn")
const Save = preload("res://systems/save.gd")
var game
var failures := 0
var render := false
var photo_dir := ""

func _initialize() -> void:
	render = DisplayServer.get_name() != "headless"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="):
			photo_dir = arg.trim_prefix("--screenshots=")
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	print(("PASS  " if condition else "FAIL  ") + description)
	if not condition:
		failures += 1

func _ticks(count: int) -> void:
	for index in count:
		await physics_frame

func _photo(label: String) -> void:
	if not render or photo_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var view := root.get_texture().get_image()
	var path := photo_dir.path_join(label + ".png")
	_check(view != null and view.save_png(path) == OK, "Rendered screenshot " + label)

func _run() -> void:
	seed(314159)
	game = Scene.instantiate()
	root.add_child(game)
	await _ticks(45)
	_check(game.ui.screen == "title" and game.world.data.stats.buildings > 1500, "Title and authentic map initialized")
	await _photo("01-title")
	game.ui.open("map")
	_check(game.ui.map_control != null and game.ui.map_control.game == game, "Title map panel opens")
	await _photo("02-atlas")
	game.ui.open("title")
	game.begin("new")
	game.settings.auto = false
	game.apply_settings()
	await _ticks(50)
	_check(game.player.is_on_floor() and absf(game.player.position.y) < 0.12, "Player lands on streamed Shanghai terrain")
	_check(game.player.hero.skeleton.get_bone_count() >= 10 and game.player.hero.visible, "Animated skeleton is active in third person")
	var before: Vector3 = game.player.position
	Input.action_press("move_up")
	await _ticks(36)
	Input.action_release("move_up")
	await _ticks(12)
	_check(game.player.position.distance_to(before) > 0.9, "Player walks through normal input")
	game.press_action("jump")
	await _ticks(13)
	_check(game.player.position.y > 0.25, "Player jumps through action handler")
	await _ticks(38)
	game.press_action("camera")
	await _ticks(3)
	_check(game.camera_mode == 1 and not game.player.hero.visible, "First person camera toggles")
	game.press_action("camera")
	var overlay = game.ui.touch
	overlay.forced = true
	await process_frame
	overlay._process(0.0)
	var coordinates: Transform2D = overlay.get_global_transform_with_canvas()
	var finger := InputEventScreenTouch.new()
	finger.index = 1
	finger.pressed = true
	finger.position = coordinates * overlay.base
	overlay._input(finger)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = coordinates * (overlay.base - Vector2(0, 50))
	overlay._input(drag)
	var second := InputEventScreenTouch.new()
	second.index = 2
	second.pressed = true
	second.position = coordinates * overlay.buttons["sprint"][0]
	overlay._input(second)
	_check(game.touch_vector.y < -0.5 and game.touch_flags.get("sprint", false), "Touch handler holds joystick and sprint simultaneously")
	overlay.reset()
	overlay.forced = false
	await _photo("03-pudong")
	var car: CharacterBody3D = game.cars[0]
	game.teleport(car.position + Vector3.LEFT * 2.2 + Vector3.UP * 0.1)
	await _ticks(3)
	game.press_action("vehicle")
	_check(game.driving == car, "Parked car can be entered")
	var initial := car.position
	Input.action_press("move_up")
	await _ticks(48)
	Input.action_release("move_up")
	_check(car.position.distance_to(initial) > 1.4 and car.speed > 2.0, "Vehicle accelerates and drives on real road geometry")
	Input.action_press("handbrake")
	await _ticks(36)
	Input.action_release("handbrake")
	_check(absf(car.speed) < 1.0, "Handbrake slows the vehicle")
	_check(car.is_on_floor() and car.position.y > -0.5, "Vehicle collides with ground")
	# Exercise both surface portals, then follow the actual underground ribbon under player throttle.
	game.teleport(game.world.gate(0) + Vector3.UP * 0.09)
	game.press_action("interact")
	await _ticks(8)
	_check(game.in_tunnel and car.position.y < -20.0 and car.is_on_floor(), "West portal puts car on physical tunnel floor")
	var path: PackedVector3Array = game.world.tunnel
	var index := 1
	var iterations := 0
	while game.in_tunnel and index < path.size() and iterations < 1500:
		var at := car.position
		var target := path[index]
		var distance := Vector2(target.x - at.x, target.z - at.z).length()
		if distance < 2.2 and index < path.size() - 1:
			index += 1
			target = path[index]
		# Automatic test pilot rotates the wheel heading while acceleration still uses real input and physics.
		car.rotation.y = atan2(at.x - target.x, at.z - target.z)
		Input.action_press("move_up", 0.70 if distance > 24 else 0.33)
		if car.speed > 23:
			Input.action_release("move_up")
		iterations += 1
		await _ticks(4)
	Input.action_release("move_up")
	_check(not game.in_tunnel and car.position.distance_to(game.world.gate(1)) < 24.0,
		"Drove from west to east through tunnel (%s steps, waypoint %s, position %s)" % [iterations, index, car.position])
	var en_route: PackedVector2Array = game.streets.route(game.place("century"), game.place("green"))
	_check(en_route.size() > 2, "GPS follows the directed OSM road graph")
	car.speed = 0.0
	game.press_action("vehicle")
	_check(game.driving == null, "Parked vehicle can be exited")
	game.teleport(game.place("bund"))
	await _ticks(150)
	_check(game.player.is_on_floor() and game.world.loaded.has(game.world.id(game.world.coordinate(game.player.position))),
		"West-bank land and streamed tile are active")
	_check(game.streets.people.size() > 0 and game.streets.traffic.size() > 0, "Nearby pedestrian and AI traffic spawning")
	game.climate.hour = 22.4
	game.climate.weather = 4
	await _ticks(70)
	_check(game.climate.night > 0.8 and game.climate.wetness > 0.38 and game.climate.rain.emitting, "Night and rain systems update runtime state")
	game.yaw = -1.75
	game.pitch = -0.04
	await _ticks(25)
	await _photo("04-bund-night")
	game.settings.vibration = false
	game.feedback("complete", game.focus())
	_check(not game.settings.vibration, "Vibration preference can be disabled")
	game.set_wanted(3)
	_check(game.wanted == 3, "Wanted system raises the configured level")
	game.settings.wanted = false
	await _ticks(3)
	_check(game.wanted == 0, "Wanted system respects the disable setting")
	game.missions.start(5)
	game.teleport(game.place("promenade", true))
	await _ticks(5)
	_check(int(game.missions.current.get("leg", 0)) == 1, "Landmark mission advances at its first checkpoint")
	game.teleport(game.place("convention", true))
	await _ticks(5)
	_check(game.missions.current.is_empty() and game.money == 370, "Mission completes with reward and saves")
	# Real data ferry boarding and travel at gameplay time, with accelerated physics configuration outside the test.
	game.world.ferry_segment = 0
	game.world.ferry_fraction = 0.0
	game.world.ferry_direction = 1
	game.world.ferry_station = 0
	game.world.ferry_pause = 10.0
	game.world.boat.position = game.world.ferry_path[0]
	game.teleport(game.world.ferry_path[0] + Vector3.UP * 0.9)
	game.press_action("interact")
	_check(game.on_ferry, "Ferry docks allow boarding")
	if not render:
		await _ticks(5500)
		_check(not game.on_ferry and game.player.position.distance_to(game.world.ferry_path[-1]) < 18.0, "Ferry reaches the opposite bank and disembarks")
	game.on_ferry = false
	game.player.set_driven(false)
	game.teleport(game.cafe_entrance())
	game.press_action("interact")
	_check(game.inside, "Riverside café interior is enterable")
	game.press_action("interact")
	_check(not game.inside and game.player.position.distance_to(game.cafe_entrance()) < 3, "Café exit returns to Shanghai")
	game.money = 1500
	_check(game.buy_unlock("apartment", 1200) and game.money == 300, "Apartment unlocked using game currency")
	game.teleport(game.apartment_entrance())
	game.press_action("interact")
	_check(game.inside and game.apartment_root != null, "Unlocked apartment can be entered")
	game.press_action("interact")
	game.money = 777
	game.save_game(false)
	game.money = 779
	game.save_game(false)
	_check(int(Save.read().get("money", 0)) == 779, "Versioned local save can be read")
	var file := FileAccess.open(Save.FILE, FileAccess.WRITE)
	file.store_string("torn write")
	file.close()
	_check(int(Save.read().get("money", 0)) == 777, "Corrupted primary restores previous backup")
	game.save_cache = Save.read()
	game.begin("continue")
	_check(game.money == 777, "Continue restores player economy from backup")
	game.ui.open("phone")
	_check(game.ui.screen == "phone", "In-game phone opens")
	game.ui.open("pause")
	game.ui.open("settings")
	_check(game.ui.screen == "settings", "Settings reachable from pause")
	game.ui.open("game")
	var travel_target: Vector3 = game.place("century")
	var old_key: String = game.world.id(game.world.coordinate(game.focus()))
	game.teleport(travel_target)
	await _ticks(160)
	_check(game.world.loaded.has(game.world.id(game.world.coordinate(travel_target))), "Chunk attached after travelling across map")
	if old_key != game.world.id(game.world.coordinate(travel_target)):
		var far: Vector3 = game.place("nanjing")
		game.teleport(far)
		await _ticks(160)
		_check(not game.world.loaded.has(game.world.id(game.world.coordinate(travel_target))), "Far chunks unload across district travel")
	game.queue_free()
	await process_frame
	print("RESULT  %s failure(s)" % failures)
	quit(0 if failures == 0 else 1)
