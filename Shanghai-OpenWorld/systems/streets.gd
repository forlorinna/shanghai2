extends Node3D

const A = preload("res://scripts/art.gd")
const Car = preload("res://assets/vehicles/vehicle.gd")
const Citizen = preload("res://assets/characters/citizen.gd")
const PAINT := [Color("#d4d7d0"), Color("#4d7491"), Color("#866d69"), Color("#637472"), Color("#383e47"), Color("#d3a741")]
var graph := AStar2D.new()
var point_ids: Dictionary = {}
var point_cells: Dictionary = {}
var index_grid: Dictionary = {}
var tracks: Array[Dictionary] = []
var sidewalks: Array[Dictionary] = []
var traffic: Array[Dictionary] = []
var people: Array[Dictionary] = []
var detectives: Array[Dictionary] = []
var game
var build_clock := 0.0
var light_clock := 0.0
var signals: Array = []
var active_signals: Dictionary = {}
var signals_clock := 0.0
var signal_glow := [
	A.material(Color("#fa594a"), 0.0, 0.55, true),
	A.material(Color("#ffc572"), 0.0, 0.55, true),
	A.material(Color("#78e4af"), 0.0, 0.55, true),
]
var signal_housing := A.material(Color("#334349"))
var signal_dark := A.material(Color("#202b2a"))

func build(context, rows: Array, walking: Array) -> void:
	game = context
	signals = game.world.data.get("signals", [])
	for row in rows:
		var points := _coords(row[3])
		if points.size() < 2:
			continue
		for i in range(1, points.size()):
			var a := _graph_point(points[i - 1])
			var b := _graph_point(points[i])
			if a != b:
				graph.connect_points(a, b, not bool(row[2]))
		if not str(row[4]).ends_with("_link") and row[4] not in ["service", "motorway"]:
			_add_track(tracks, points, minf(2.5, float(row[1]) * 0.24), bool(row[2]))
	for row in walking:
		_add_track(sidewalks, _coords(row[3]), 0.0, false)

func _graph_point(p: Vector2) -> int:
	if point_ids.has(p):
		return point_ids[p]
	var ix := graph.get_available_point_id()
	point_ids[p] = ix
	graph.add_point(ix, p)
	var cell := Vector2i(floori(p.x / 64.0), floori(p.y / 64.0))
	if not point_cells.has(cell):
		point_cells[cell] = []
	point_cells[cell].append(ix)
	return ix

func _coords(rows: Array) -> PackedVector2Array:
	var coords := PackedVector2Array()
	for row in rows:
		coords.append(Vector2(row[0], row[1]))
	return coords

func _add_track(target: Array[Dictionary], points: PackedVector2Array, offset: float, oneway: bool) -> void:
	var line := Curve2D.new()
	line.bake_interval = 4.0
	for p in points:
		line.add_point(p)
	if line.get_baked_length() < (20.0 if offset > 0 else 12.0):
		return
	var feature := {"line":line, "length":line.get_baked_length(), "offset":offset, "oneway":oneway, "lights":[]}
	if offset > 0:
		var gate_a := line.get_point_position(0)
		var gate_b := line.get_point_position(line.point_count - 1)
		for row in signals:
			var at := Vector2(row[0], row[1])
			if minf(gate_a.distance_to(at), gate_b.distance_to(at)) < 11.0:
				var along := line.get_closest_offset(at)
				if line.sample_baked(along).distance_to(at) < 6.4:
					feature.lights.append([along, row[2]])
	target.append(feature)
	if offset > 0:
		var mid := line.sample_baked(feature.length * 0.5)
		var tile := Vector2i(floori(mid.x / 256), floori(mid.y / 256))
		if not index_grid.has(tile):
			index_grid[tile] = []
		index_grid[tile].append(feature)

func _route_candidates(at: Vector2) -> Array:
	var center := Vector2i(floori(at.x / 64.0), floori(at.y / 64.0))
	var choices: Array = []
	for x in range(-1, 2):
		for z in range(-1, 2):
			for point in point_cells.get(center + Vector2i(x, z), []):
				choices.append([at.distance_squared_to(graph.get_point_position(point)), point])
	choices.sort_custom(func(a, b): return a[0] < b[0])
	return choices.slice(0, 9) if not choices.is_empty() else [[0.0, graph.get_closest_point(at)]]

func route(a: Vector3, b: Vector3) -> PackedVector2Array:
	var start := Vector2(a.x, a.z)
	var finish := Vector2(b.x, b.z)
	if graph.get_point_count() == 0:
		return PackedVector2Array()
	var starts := _route_candidates(start)
	var ends := _route_candidates(finish)
	# Endpoints at junctions may only admit traffic in one direction.
	var options: Array = []
	for s in starts:
		for e in ends:
			options.append([s[0] + e[0], s[1], e[1]])
	options.sort_custom(func(left, right): return left[0] < right[0])
	for index in mini(48, options.size()):
		var option: Array = options[index]
		var route_points := graph.get_point_path(option[1], option[2])
		if route_points.is_empty():
			continue
		route_points.insert(0, start)
		route_points.append(finish)
		return route_points
	return PackedVector2Array()

func spawn_space(at: Vector3) -> Dictionary:
	var center := Vector2(at.x, at.z)
	var nearest := graph.get_point_position(graph.get_closest_point(center))
	var best := {"pos": Vector3(nearest.x, 0.10, nearest.y), "yaw":0.0}
	var dist := INF
	for tile in range(-1, 2):
		for j in range(-1, 2):
			var cell := Vector2i(floori(at.x / 256), floori(at.z / 256)) + Vector2i(tile, j)
			for road in index_grid.get(cell, []):
				var line: Curve2D = road.line
				var path_off := clampf(line.get_closest_offset(center), 4.0, float(road.length) - 4.0)
				var p := line.sample_baked(path_off)
				var look := p.direction_to(line.sample_baked(path_off + 2.0))
				var side := Vector2(-look.y, look.x) * float(road.offset)
				p += side
				var proximity := p.distance_squared_to(center)
				if proximity < dist:
					dist = proximity
					best = {"pos":Vector3(p.x, 0.08, p.y), "yaw":atan2(-look.x, -look.y)}
	return best

func _near_track(at: Vector3, walk: bool, minimum: float) -> Dictionary:
	var center := Vector2(at.x, at.z)
	var target := sidewalks if walk else tracks
	for attempt in 24:
		var feature := target.pick_random() as Dictionary
		var progress := clampf(feature.line.get_closest_offset(center) + randf_range(-115, 115), 0, feature.length)
		var end := feature.line.sample_baked(progress) as Vector2
		var distance := end.distance_to(center)
		if distance > minimum and distance < 205.0:
			return {"feature": feature, "distance": progress, "heading": 1 if feature.oneway or randf() > 0.5 else -1}
	return {}

func tick(delta: float, at: Vector3) -> void:
	light_clock = fposmod(light_clock + delta, 22.0)
	signals_clock += delta
	if signals_clock > 0.35:
		signals_clock = 0.0
		_update_signals(at)
	build_clock += delta
	var cars: int = [5, 10, 15, 19][game.quality] if game.settings.get("traffic", true) else 0
	var citizens: int = [5, 9, 13, 18][game.quality]
	citizens = roundi(citizens * float(game.settings.get("crowds", 1.0)))
	if game.in_tunnel or game.on_ferry:
		cars = 0
		citizens = 0
	if build_clock > 0.14:
		build_clock = 0.0
		_spawn(at, cars, false)
		_spawn(at, citizens, true)
		for i in range(detectives.size() - 1, -1, -1):
			if detectives[i].node.position.distance_to(at) > 235 or i >= game.wanted or game.in_tunnel or game.on_ferry:
				detectives[i].node.queue_free()
				detectives.remove_at(i)
		if detectives.size() < game.wanted and not game.in_tunnel and not game.on_ferry:
			var entry := _near_track(at, false, 75)
			if not entry.is_empty():
				var police := Car.new()
				police.create(game, 6, Color("#b0c5d9"), true, true)
				add_child(police)
				var pos: Vector2 = entry.feature.line.sample_baked(entry.distance)
				police.position = Vector3(pos.x, 0.11, pos.y)
				detectives.append({"node":police, "speed":0.0, "route":route(police.position, at), "wp":1, "timer":1.5})
	for entry in traffic:
		_move(entry, delta, at, false)
	for entry in people:
		_move(entry, delta, at, true)
	for entry in detectives:
		_pursue(entry, delta, at)

func _spawn(at: Vector3, limit: int, walk: bool) -> void:
	var actors := people if walk else traffic
	for i in range(actors.size() - 1, -1, -1):
		if actors[i].node.position.distance_to(at) > 235 or i >= limit:
			actors[i].node.queue_free()
			actors.remove_at(i)
	if actors.size() >= limit:
		return
	var entry := _near_track(at, walk, 19 if walk else 31)
	if entry.is_empty():
		return
	var p: Vector2 = entry.feature.line.sample_baked(entry.distance)
	for actor in actors:
		if Vector2(actor.node.position.x, actor.node.position.z).distance_to(p) < (3 if walk else 10):
			return
	var node: Node3D
	if walk:
		node = Citizen.new()
		node.build(randi() % 12)
		node.scale = Vector3.ONE * randf_range(0.91, 1.05)
	else:
		node = Car.new()
		node.create(game, [0, 0, 1, 2, 3, 3, 4, 5].pick_random(), PAINT.pick_random(), true, true)
	add_child(node)
	node.position = Vector3(p.x, 0.04, p.y)
	entry.node = node
	entry.speed = 0.0
	entry.pace = randf_range(0.88, 1.18)
	entry.pause = 0.0
	actors.append(entry)

func _move(entry: Dictionary, delta: float, player: Vector3, walking: bool) -> void:
	var node: Node3D = entry.node
	var feature: Dictionary = entry.feature
	var line: Curve2D = feature.line
	var p := line.sample_baked(entry.distance)
	var ahead := line.sample_baked(clampf(entry.distance + 2.0 * float(entry.heading), 0.0, feature.length))
	var look := p.direction_to(ahead)
	if look == Vector2.ZERO:
		look = line.sample_baked(clampf(entry.distance - 2.0 * float(entry.heading), 0.0, feature.length)).direction_to(p)
	p += Vector2(-look.y, look.x) * float(feature.offset)
	var direction := Vector3(look.x, 0, look.y)
	var target := (1.8 if walking else (12.0 if int(node.variant) != 4 else 8.0)) * float(entry.pace)
	var to_player := player - node.position
	if to_player.length() < (1.5 if walking else 13.0) and direction.dot(to_player.normalized()) > 0.65:
		target = 0.0
	if not walking:
		for other in traffic:
			if other.node == node:
				continue
			var gap: Vector3 = other.node.position - node.position
			if gap.length() < 12.0 and gap.dot(direction) > 0.35 and absf(gap.cross(direction).y) < 2.0:
				target = minf(target, maxf(0, (gap.length() - 5.0) * 0.9))
		for crossing in feature.lights:
			var until: float = (float(crossing[0]) - float(entry.distance)) * float(entry.heading)
			if until > 2.0 and until < 13.0 and _signal_phase(crossing[1]) != 2:
				target = minf(target, maxf(0.0, (until - 3.0) * 1.1))
	if walking and entry.pause > 0:
		entry.pause -= delta
		target = 0.0
	elif walking and randf() < delta * 0.012:
		entry.pause = randf_range(1.0, 3.0)
	entry.speed = move_toward(entry.speed, target, delta * (3.1 if walking else 6.5))
	node.position = Vector3(p.x, 0.018, p.y)
	node.rotation.y = lerp_angle(node.rotation.y, atan2(-look.x, -look.y), 1.0 - exp(-delta * 8.0))
	if walking:
		node.animate(delta, entry.speed, "ground")
	else:
		node.animate_wheels(delta, entry.speed)
		node._lights(target <= 0.1, false, false)
	entry.distance += float(entry.speed) * float(entry.heading) * delta
	if entry.distance > feature.length or entry.distance < 0.0:
		if not walking and _advance(entry, p, look):
			return
		if feature.oneway:
			entry.distance = feature.length
			node.position.y = -90.0
		else:
			entry.distance = clampf(entry.distance, 0.0, feature.length)
			entry.heading *= -1

func _advance(entry: Dictionary, p: Vector2, previous: Vector2) -> bool:
	var tile := Vector2i(floori(p.x / 256), floori(p.y / 256))
	for candidate in index_grid.get(tile, []):
		if candidate == entry.feature:
			continue
		var line: Curve2D = candidate.line
		for heading in ([1] if candidate.oneway else [1, -1]):
			var begin: Vector2 = line.sample_baked(0 if heading == 1 else candidate.length)
			if begin.distance_to(p) > float(candidate.offset) + float(entry.feature.offset) + 2.4:
				continue
			var ahead := begin.direction_to(line.sample_baked(4.0 if heading == 1 else float(candidate.length) - 4.0))
			if previous.dot(ahead) < -0.65:
				continue
			entry.feature = candidate
			entry.heading = heading
			entry.distance = 0.0 if heading == 1 else candidate.length
			return true
	return false

func _pursue(entry: Dictionary, delta: float, player: Vector3) -> void:
	var node: Node3D = entry.node
	var route_points: PackedVector2Array = entry.route
	var here := Vector2(node.position.x, node.position.z)
	var to_player := player.distance_to(node.position)
	entry.timer -= delta
	if (entry.timer <= 0 or entry.wp >= route_points.size()) and to_player > 10:
		entry.timer = 2.7
		entry.route = route(node.position, player)
		entry.wp = mini(1, entry.route.size())
		route_points = entry.route
	if entry.wp >= route_points.size():
		return
	var wp := route_points[entry.wp]
	var heading := here.direction_to(wp)
	var dist := here.distance_to(wp)
	if dist < 3.4:
		entry.wp += 1
	var speed := 0.0 if to_player < 10 else minf(19, dist * 2.3 + 4)
	entry.speed = move_toward(entry.speed, speed, delta * 7)
	node.rotation.y = lerp_angle(node.rotation.y, atan2(-heading.x, -heading.y), 1.0 - exp(-delta * 4.5))
	var move := Vector3(heading.x, 0, heading.y) * minf(dist, entry.speed * delta)
	if not game.world.is_water(node.position + move):
		node.position += move
	node.animate_wheels(delta, entry.speed)
	node._lights(to_player < 10, true, true)

func nearby_police(at: Vector3) -> float:
	var result := INF
	for entry in detectives:
		result = minf(result, at.distance_to(entry.node.position))
	return result

func _signal_phase(yaw: float) -> int:
	var phase := fposmod(light_clock + (11.0 if absf(sin(yaw)) > 0.707 else 0.0), 22.0)
	return 2 if phase < 8.5 else (1 if phase < 10.0 else 0)

func _update_signals(at: Vector3) -> void:
	var player := Vector2(at.x, at.z)
	for index in active_signals.keys():
		var row: Array = signals[index]
		if player.distance_squared_to(Vector2(row[0], row[1])) > 370 * 370:
			active_signals[index][0].queue_free()
			active_signals.erase(index)
	for i in signals.size():
		var row: Array = signals[i]
		if not active_signals.has(i) and active_signals.size() < 32 and player.distance_squared_to(Vector2(row[0], row[1])) < 304 * 304:
			var pole := Node3D.new()
			var offset := Basis(Vector3.UP, row[2]).x * (float(row[3]) * 0.5 + 0.65)
			pole.position = Vector3(row[0], 0, row[1]) + offset
			pole.rotation.y = row[2]
			add_child(pole)
			A.cylinder(pole, Vector3(0, 2.25, 0), 4.5, 0.085, 0.063, signal_housing, 8)
			A.box(pole, Vector3(0.17, 4.15, 0), Vector3(0.48, 0.85, 0.29), signal_housing)
			var lamps: Array = []
			for j in 3:
				lamps.append(A.sphere(pole, Vector3(0.17, 4.42 - float(j) * 0.25, 0.16), Vector3(0.19, 0.19, 0.075), signal_dark, 8))
			active_signals[i] = [pole, lamps]
		if active_signals.has(i):
			var phase := _signal_phase(row[2])
			for j in 3:
				active_signals[i][1][j].material_override = signal_glow[j] if j == phase else signal_dark
