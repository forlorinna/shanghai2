extends Node3D

const Landmarks = preload("res://assets/landmarks/landmarks.gd")
const A = preload("res://scripts/art.gd")
const CHUNK_PATH := "res://maps/chunks/%s.scn"
const TILE := 256.0
const TUNNEL_Y := -22.0
var data: Dictionary
var loaded: Dictionary = {}
var pending: Dictionary = {}
var keys: Dictionary = {}
var water: Array[Array] = []
var landmarks: Node3D
var tunnel: PackedVector3Array
var boat: Node3D
var ferry_path: PackedVector3Array
var ferry_segment := 0
var ferry_fraction := 0.0
var ferry_direction := 1
var ferry_pause := 10.0
var ferry_station := 0
var metro_markers: Array[Node3D] = []
var stream_clock := 0.0
var map_radius := 2
var active_tile := Vector2i(999, 999)
var threaded := true

func start() -> void:
	threaded = DisplayServer.get_name() != "headless" and not OS.has_feature("web")
	data = JSON.parse_string(FileAccess.get_file_as_string("res://maps/city.json"))
	for key in data.tiles:
		keys[key] = true
	for polygon in data.water:
		var rings := []
		for ring in polygon:
			var pts := PackedVector2Array()
			for p in ring:
				pts.append(Vector2(p[0], p[1]))
			rings.append(pts)
		water.append(rings)
	var skyline: PackedScene = load(CHUNK_PATH % "skyline")
	add_child(skyline.instantiate())
	landmarks = Landmarks.new()
	landmarks.name = "Landmarks"
	add_child(landmarks)
	landmarks.build(data.landmarks, data.bridge)
	landmarks.night_light(0.0)
	tunnel = _points(data.tunnel, TUNNEL_Y)
	ferry_path = _points(data.ferry, -0.58)
	_build_tunnel()
	_build_ferry()

func _points(rows: Array, height: float) -> PackedVector3Array:
	var result := PackedVector3Array()
	for row in rows:
		result.append(Vector3(row[0], height, row[1]))
	return result

func coordinate(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.z / TILE))

func id(tile: Vector2i) -> String:
	return "%s_%s" % [tile.x, tile.y]

func warm(at: Vector3) -> void:
	var center := coordinate(at)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var name_key := id(center + Vector2i(dx, dz))
			if keys.has(name_key) and not loaded.has(name_key):
				if pending.has(name_key):
					var waiting: PackedScene = ResourceLoader.load_threaded_get(CHUNK_PATH % name_key)
					pending.erase(name_key)
					if waiting != null:
						_attach_chunk(name_key, waiting)
				else:
					var packed: PackedScene = load(CHUNK_PATH % name_key)
					_attach_chunk(name_key, packed)

func _attach_chunk(key: String, scene: PackedScene) -> void:
	var piece := scene.instantiate()
	add_child(piece)
	loaded[key] = piece

func stream(pos: Vector3, delta: float) -> void:
	active_tile = coordinate(pos)
	# A small budget prevents completed background reads from all attaching in the same frame.
	var mounted := 0
	for key in pending.keys():
		var path := CHUNK_PATH % key
		var state := ResourceLoader.load_threaded_get_status(path)
		if state == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		pending.erase(key)
		if state == ResourceLoader.THREAD_LOAD_LOADED:
			var scene: PackedScene = ResourceLoader.load_threaded_get(path)
			var cell: Array = key.split("_")
			if not loaded.has(key) and maxi(absi(int(cell[0]) - active_tile.x), absi(int(cell[1]) - active_tile.y)) <= map_radius + 1:
				_attach_chunk(key, scene)
				mounted += 1
				if mounted == 2:
					break
	stream_clock += delta
	if stream_clock < 0.16:
		return
	stream_clock = 0.0
	var budget := maxi(0, 6 - pending.size()) if threaded else 3
	for layer in range(0, map_radius + 1):
		for x in range(-layer, layer + 1):
			for z in range(-layer, layer + 1):
				if budget == 0 or maxi(absi(x), absi(z)) != layer:
					continue
				var key := id(active_tile + Vector2i(x, z))
				if keys.has(key) and not loaded.has(key) and not pending.has(key):
					if threaded:
						var error := ResourceLoader.load_threaded_request(CHUNK_PATH % key, "PackedScene")
						if error == OK:
							pending[key] = true
							budget -= 1
					else:
						var scene: PackedScene = load(CHUNK_PATH % key)
						_attach_chunk(key, scene)
						budget -= 1
	for key in loaded.keys():
		var row: Array = key.split("_")
		var distance := maxi(absi(int(row[0]) - active_tile.x), absi(int(row[1]) - active_tile.y))
		if distance > map_radius + 1:
			loaded[key].queue_free()
			loaded.erase(key)
		else:
			var body: StaticBody3D = loaded[key].get_node_or_null("Geometry")
			if body != null:
				body.collision_layer = 1 if distance <= 1 else 0

func is_water(pos: Vector3) -> bool:
	var p := Vector2(pos.x, pos.z)
	for polygon in water:
		if not Geometry2D.is_point_in_polygon(p, polygon[0]):
			continue
		var dry := false
		for i in range(1, polygon.size()):
			dry = dry or Geometry2D.is_point_in_polygon(p, polygon[i])
		if not dry:
			return true
	return false

func in_bounds(pos: Vector3) -> bool:
	var b: Array = data.bounds
	return pos.x > b[0] + 0.3 and pos.x < b[2] - 0.3 and pos.z > b[1] + 0.3 and pos.z < b[3] - 0.3

func last_end(index: int) -> Vector3:
	return tunnel[0] if index == 0 else tunnel[-1]

func gate(index: int) -> Vector3:
	var p := last_end(index)
	var other := tunnel[1] if index == 0 else tunnel[-2]
	p -= p.direction_to(other) * 13.0
	p.y = 0
	return p

func _build_tunnel() -> void:
	var root := Node3D.new()
	root.name = "YananTunnel"
	add_child(root)
	var lane := A.material(Color("#4a4b4f"))
	var wall := A.material(Color("#77746b"))
	var ceiling := A.material(Color("#4c4e4c"))
	var stripe := A.material(Color("#ead39e"), 0, 0.58, true)
	for i in range(1, tunnel.size()):
		var a := tunnel[i - 1]
		var b := tunnel[i]
		var length := a.distance_to(b) + 5.0
		var section := Node3D.new()
		root.add_child(section)
		section.position = (a + b) * 0.5
		section.rotation.y = atan2(a.x - b.x, a.z - b.z)
		A.box(section, Vector3(0, -0.45, 0), Vector3(15.5, 0.9, length), lane)
		A.collider(section, Vector3(0, -0.45, 0), Vector3(15.5, 0.9, length))
		A.box(section, Vector3(0, 5.7, 0), Vector3(16.8, 0.65, length), ceiling)
		A.collider(section, Vector3(0, 5.7, 0), Vector3(16.8, 0.65, length))
		for side in [-1, 1]:
			A.box(section, Vector3(side * 7.9, 2.55, 0), Vector3(0.58, 5.1, length), wall)
			# Short gaps at bends let the continuous drivable ribbon converge.
			A.collider(section, Vector3(side * 8.15, 2.55, 0), Vector3(0.52, 5.1, maxf(0.5, length - 10.0)))
			A.box(section, Vector3(side * 7.55, 1.45, 0), Vector3(0.06, 0.08, length), stripe)
		for j in range(-floori(length / 18), floori(length / 18) + 1):
			A.box(section, Vector3(0, 0.015, j * 8.8), Vector3(0.12, 0.025, 2.8), stripe)
			A.box(section, Vector3(0, 5.28, j * 8.8), Vector3(1.80, 0.14, 0.23), stripe)
	for index in 2:
		var gate_root := Node3D.new()
		root.add_child(gate_root)
		gate_root.position = gate(index)
		var interior := last_end(index)
		gate_root.rotation.y = atan2(gate_root.position.x - interior.x, gate_root.position.z - interior.z)
		for x in [-3.2, 3.2]:
			A.box(gate_root, Vector3(x, 1.5, 0), Vector3(0.23, 3, 0.23), stripe)
		A.box(gate_root, Vector3(0, 3, 0), Vector3(6.6, 0.16, 0.25), stripe)
		var sign := Label3D.new()
		sign.text = "延安东路隧道  /  YAN’AN TUNNEL"
		sign.font = load("res://assets/textures/city-font.otf")
		sign.position = Vector3(0, 3.75, 0)
		sign.font_size = 42
		sign.pixel_size = 0.009
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		gate_root.add_child(sign)
		metro_markers.append(gate_root)

func _build_ferry() -> void:
	boat = Node3D.new()
	boat.name = "HuangpuFerry"
	add_child(boat)
	var sky := A.material(Color("#cad4d2"))
	var blue := A.material(Color("#2c7186"), 0.25)
	var glass := A.material(Color("#243c49"), 0.4)
	A.box(boat, Vector3(0, 0.37, 0.6), Vector3(8, 1.7, 27), blue)
	A.box(boat, Vector3(0, 1.28, 0), Vector3(8.5, 0.2, 29), sky)
	A.box(boat, Vector3(0, 2.36, 1), Vector3(6.1, 2.1, 17.0), sky)
	A.box(boat, Vector3(0, 3.1, 1), Vector3(6.2, 0.8, 17.15), glass)
	A.box(boat, Vector3(0, 3.57, 1), Vector3(6.5, 0.18, 17.8), sky)
	A.box(boat, Vector3(0, 4.5, 4.3), Vector3(1.3, 1.8, 1.2), blue)
	for x in [-3.8, 3.8]:
		A.box(boat, Vector3(x, 1.9, 0), Vector3(0.075, 0.09, 28), sky)
		for z in [-13, -9, -5, 0, 5, 9, 13]:
			A.box(boat, Vector3(x, 1.6, z), Vector3(0.075, 0.73, 0.075), sky)
	var wake_mat := A.material(Color("#4e90a1"), 0, 0.98)
	for i in 7:
		for side in [-1, 1]:
			var pos := Vector3(side * (2.3 + i * 0.63), -0.015, 14.2 + i * 2.8)
			A.box(boat, pos, Vector3(0.16, 0.011, 2.2 + i * 0.25), wake_mat).rotation.y = side * 0.20
	for index in 2:
		var p := ferry_path[0] if index == 0 else ferry_path[-1]
		var shore := Vector3(data.ferry_docks[index][0], p.y, data.ferry_docks[index][1])
		var dock := Node3D.new()
		dock.position = p.lerp(shore, 0.5) + Vector3.UP * 0.61
		dock.rotation.y = atan2(p.x - shore.x, p.z - shore.z)
		add_child(dock)
		var deck := Vector3(7.8, 0.38, p.distance_to(shore) + 12)
		A.box(dock, Vector3.ZERO, deck, A.material(Color("#7e7164")))
		A.collider(dock, Vector3.ZERO, deck)
		var sign := Label3D.new()
		sign.font = preload("res://assets/textures/city-font.otf")
		sign.text = "金陵东路渡口  /  JINLING EAST ROAD" if index == 0 else "东昌路渡口  /  DONGCHANG ROAD"
		sign.pixel_size = 0.007
		sign.font_size = 40
		sign.position = Vector3(0, 2.3, -4)
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		dock.add_child(sign)
	boat.position = ferry_path[0]

func move_ferry(delta: float) -> void:
	if ferry_pause > 0:
		ferry_pause = maxf(0, ferry_pause - delta)
		return
	var next := ferry_segment + ferry_direction
	var a := ferry_path[ferry_segment]
	var b := ferry_path[next]
	ferry_fraction += delta * 13.5 / a.distance_to(b)
	if ferry_fraction >= 1:
		ferry_segment = next
		ferry_fraction = 0
		boat.position = b
		if next == 0 or next == ferry_path.size() - 1:
			ferry_direction *= -1
			ferry_station = 0 if next == 0 else 1
			ferry_pause = 13.0
	else:
		boat.position = a.lerp(b, ferry_fraction)
		boat.rotation.y = lerp_angle(boat.rotation.y, atan2(a.x - b.x, a.z - b.z), delta * 1.6)
		boat.position.y += sin(Time.get_ticks_msec() * 0.0017) * 0.10

func _exit_tree() -> void:
	for key in pending:
		ResourceLoader.load_threaded_get(CHUNK_PATH % key)
	pending.clear()
