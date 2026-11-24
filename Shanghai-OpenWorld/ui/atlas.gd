extends Control

const MapShader = preload("res://shaders/atlas.gdshader")
const TEXTURE = preload("res://maps/atlas.png")
var game
var miniature := false
var map := TextureRect.new()
var mat := ShaderMaterial.new()
var midpoint := Vector2.ZERO
var span := Vector2.ONE
var zoom := 1.0
var selected := Vector3.INF
var pointers: Dictionary = {}
var drag_anchor := Vector2(-1, -1)
var drag_moved := false
var font: Font

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE if miniature else Control.MOUSE_FILTER_STOP
	mat.shader = MapShader
	mat.set_shader_parameter("round_map", miniature)
	map.texture = TEXTURE
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_SCALE
	map.material = mat
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map)
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.show_behind_parent = true
	font = load("res://assets/textures/city-font.otf")
	if miniature:
		custom_minimum_size = Vector2(164, 164)
	else:
		custom_minimum_size = Vector2(240, 230)

func _process(_delta: float) -> void:
	if not is_visible_in_tree() or game == null or size.y < 2.0:
		return
	var bounds: Array = game.world.data.bounds
	if miniature:
		midpoint = _meters_to_uv(game.focus())
		span = Vector2(205.0 / (bounds[2] - bounds[0]), 205.0 / (bounds[3] - bounds[1]))
	else:
		if midpoint == Vector2.ZERO:
			midpoint = Vector2(0.50, 0.49)
		var aspect := float(bounds[2] - bounds[0]) / float(bounds[3] - bounds[1])
		var panel := size.x / size.y
		span = Vector2(maxf(1.0, panel / aspect), maxf(1.0, aspect / panel)) / zoom
	mat.set_shader_parameter("midpoint", midpoint)
	mat.set_shader_parameter("span", span)
	queue_redraw()

func _meters_to_uv(p: Vector3) -> Vector2:
	var b: Array = game.world.data.bounds
	return Vector2(inverse_lerp(b[0], b[2], p.x), inverse_lerp(b[1], b[3], p.z))

func _screen(p: Vector3) -> Vector2:
	return ((_meters_to_uv(p) - midpoint) / span + Vector2.ONE * 0.5) * size

func _screen_to_metres(at: Vector2) -> Vector3:
	var b: Array = game.world.data.bounds
	var uv := (at / size - Vector2.ONE * 0.5) * span + midpoint
	return Vector3(lerpf(b[0], b[2], clampf(uv.x, 0, 1)), 0.12, lerpf(b[1], b[3], clampf(uv.y, 0, 1)))

func _draw() -> void:
	if game == null or not is_instance_valid(map) or size.y < 2.0:
		return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.49
	if miniature:
		draw_arc(center, radius, 0, TAU, 64, Color("#cedad8"), 1.7, true)
		draw_arc(center, radius - 4, 0, TAU, 64, Color("#aec3c64a"), 1, true)
		draw_string(font, Vector2(center.x - 4.5, 19), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#f0d2a5"))
	var prev := Vector2.INF
	for point in game.itinerary:
		var this := _screen(Vector3(point.x, 0, point.y))
		if prev.is_finite():
			if not miniature or (center.distance_to(this) < radius - 3 and center.distance_to(prev) < radius - 3):
				draw_line(prev, this, Color("#f6b77b"), 2.5 if miniature else 3.2, true)
		prev = this
	if not miniature:
		for entry in game.world.data.landmarks:
			var on_map := _screen(Vector3(entry[3][0], 0, entry[3][1]))
			if get_rect().size.x < on_map.x or get_rect().size.y < on_map.y or on_map.x < 0 or on_map.y < 0:
				continue
			draw_circle(on_map, 4, Color("#eaa76f"), true, -1, true)
			if zoom > 1.52 or entry[0] in ["pearl", "shanghai", "bund", "wharf", "bridge"]:
				var tag: String = game.bi(entry[1], entry[2])
				draw_string_outline(font, on_map + Vector2(8, -5), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color("#122532"))
				draw_string(font, on_map + Vector2(8, -5), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ece6dd"))
		var target: Vector3 = selected if selected.is_finite() else game.destination
		if target.is_finite():
			var p := _screen(target)
			draw_arc(p, 11, 0, TAU, 24, Color("#ffc18b"), 2.3, true)
			draw_circle(p, 3.2, Color("#ffc18b"), true, -1, true)
	var self_point := center if miniature else _screen(game.focus())
	var rotated := PackedVector2Array()
	for p in [Vector2(0, -10), Vector2(6, 6), Vector2(0, 3), Vector2(-6, 6)]:
		rotated.append(self_point + p.rotated(-game.yaw))
	draw_circle(self_point, 11.0, Color("#084b55"), true, -1, true)
	draw_colored_polygon(rotated, Color("#d5fff3"))

func _pan(relative: Vector2) -> void:
	midpoint = (midpoint - relative / size * span).clamp(Vector2.ZERO, Vector2.ONE)

func _gui_input(event: InputEvent) -> void:
	if miniature:
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampf(zoom * (1.19 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.84), 1.0, 7.0)
			accept_event()
		if event.button_index == MOUSE_BUTTON_LEFT and pointers.is_empty():
			if event.pressed:
				drag_anchor = event.position
				drag_moved = false
			elif drag_anchor.x >= 0:
				if not drag_moved:
					selected = _screen_to_metres(event.position)
				drag_anchor = Vector2(-1, -1)
			accept_event()
	elif event is InputEventMouseMotion and drag_anchor.x >= 0 and pointers.is_empty():
		drag_moved = drag_moved or drag_anchor.distance_to(event.position) > 5.0
		if drag_moved:
			_pan(event.relative)
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			pointers[event.index] = event.position
			if pointers.size() == 1:
				drag_moved = false
			else:
				drag_moved = true
		elif pointers.has(event.index):
			if pointers.size() == 1 and not drag_moved:
				selected = _screen_to_metres(event.position)
			pointers.erase(event.index)
		accept_event()
	elif event is InputEventScreenDrag and pointers.has(event.index):
		if pointers.size() == 2:
			for index in pointers:
				if index != event.index:
					var old: Vector2 = pointers[event.index]
					var other: Vector2 = pointers[index]
					zoom = clampf(zoom * (event.position.distance_to(other) / maxf(5, old.distance_to(other))), 1.0, 7.0)
					break
		else:
			_pan(event.relative)
		drag_moved = true
		pointers[event.index] = event.position
		accept_event()
