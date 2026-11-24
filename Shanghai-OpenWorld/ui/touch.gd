extends Control

var game
var font: Font
var fingers: Dictionary = {}
var joystick := -1
var orbit := -1
var base := Vector2.ZERO
var tip := Vector2.ZERO
var buttons: Dictionary = {}
var forced := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = load("res://assets/textures/city-font.otf")

func enabled() -> bool:
	return game != null and game.is_playing() and (forced or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available())

func reset() -> void:
	joystick = -1
	orbit = -1
	fingers.clear()
	if game != null:
		game.touch_flags.clear()
		game.touch_vector = Vector2.ZERO

func _process(_delta: float) -> void:
	if not enabled():
		if not fingers.is_empty():
			reset()
		queue_redraw()
		return
	var scale_factor: float = game.settings.controls_scale
	var margin := 61.0 * scale_factor + absf(float(game.settings.controls_offset)) * 25.0
	var y_offset := float(game.settings.controls_offset) * 75.0
	var right_x := size.x - margin
	var swap: bool = game.settings.lefty
	base = Vector2(margin + 45.0, size.y - margin - 37.0 + y_offset)
	buttons.clear()
	if game.driving == null:
		_button("jump", "↑", right_x - 20, size.y - 111.0 + y_offset, 35)
		_button("sprint", game.bi("跑", "RUN"), right_x - 104, size.y - 78.0 + y_offset, 29)
		_button("crouch", game.bi("蹲", "DUCK"), right_x - 117, size.y - 154 + y_offset, 27)
		_button("vehicle", game.bi("上车", "ENTER"), right_x - 15, size.y - 197 + y_offset, 32)
		_button("interact", game.bi("互动", "USE"), right_x - 80, size.y - 230 + y_offset, 28)
	else:
		_button("accelerate", game.bi("油门", "GAS"), right_x - 5, size.y - 88 + y_offset, 39)
		_button("reverse", game.bi("刹车", "BRAKE"), right_x - 104, size.y - 75 + y_offset, 33)
		_button("handbrake", game.bi("手刹", "DRIFT"), right_x - 112, size.y - 161 + y_offset, 30)
		_button("horn", game.bi("喇叭", "HORN"), right_x - 6, size.y - 170 + y_offset, 28)
		_button("vehicle", game.bi("下车", "EXIT"), right_x - 10, size.y - 241 + y_offset, 30)
		_button("interact", game.bi("互动", "USE"), right_x - 100, size.y - 231 + y_offset, 26)
		base.y = size.y - 108 + y_offset
		for info in [["steer_left", "‹", base.x - 43], ["steer_right", "›", base.x + 43]]:
			_button(info[0], info[1], info[2], base.y, 32)
	_button("camera", game.bi("视角", "VIEW"), right_x - 19, size.y - 309 + y_offset, 22)
	if swap:
		base.x = size.x - base.x
		for key in buttons:
			var spec: Array = buttons[key]
			spec[0].x = size.x - spec[0].x
	queue_redraw()

func _button(action: String, label: String, x: float, y: float, radius: float) -> void:
	buttons[action] = [Vector2(x, y), label, radius * float(game.settings.controls_scale)]

func _draw() -> void:
	if not enabled() or game.photo_mode:
		return
	var alpha: float = game.settings.controls_alpha
	if game.driving == null:
		var radius := 63.0 * float(game.settings.controls_scale)
		draw_circle(base, radius, Color(0.06, 0.11, 0.15, alpha * 0.45), true, -1, true)
		draw_arc(base, radius, 0, TAU, 45, Color(0.75, 0.91, 0.92, alpha * 0.60), 1.4, true)
		draw_circle(base + (tip if joystick >= 0 else Vector2.ZERO), radius * 0.38, Color(0.64, 0.89, 0.87, alpha * 0.57), true, -1, true)
	for action in buttons:
		var spec: Array = buttons[action]
		var selected: bool = game.touch_flags.has(action)
		var fill := Color(0.21, 0.55, 0.54, alpha) if selected else Color(0.06, 0.11, 0.15, alpha * 0.77)
		draw_circle(spec[0], spec[2], fill, true, -1, true)
		draw_arc(spec[0], spec[2], 0, TAU, 28, Color(0.73, 0.89, 0.89, alpha * 0.80), 1.4, true)
		var label: String = spec[1]
		var font_size := 22 if label.length() == 1 else 11
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, spec[0] + Vector2(-width * 0.5, font_size * 0.32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.94, 0.98, 0.97, minf(1, alpha + 0.30)))

func _input(event: InputEvent) -> void:
	if not enabled():
		return
	if event is InputEventScreenTouch:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed:
			for action in buttons:
				var item: Array = buttons[action]
				if point.distance_to(item[0]) <= float(item[2]) + 5.0:
					fingers[event.index] = action
					game.touch_flags[action] = true
					game.press_action(action)
					get_viewport().set_input_as_handled()
					return
			if game.driving == null and joystick < 0 and point.distance_to(base) < 109.0 * float(game.settings.controls_scale):
				joystick = event.index
				_stick(point)
				get_viewport().set_input_as_handled()
				return
			if orbit < 0 and point.y > 92.0 and ((point.x > size.x * 0.43) != bool(game.settings.lefty)):
				orbit = event.index
				get_viewport().set_input_as_handled()
		elif fingers.has(event.index) or joystick == event.index or orbit == event.index:
			if fingers.has(event.index):
				game.touch_flags.erase(fingers[event.index])
				fingers.erase(event.index)
			if joystick == event.index:
				joystick = -1
				game.touch_vector = Vector2.ZERO
			if orbit == event.index:
				orbit = -1
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == joystick:
			_stick(get_global_transform_with_canvas().affine_inverse() * event.position)
			get_viewport().set_input_as_handled()
		elif event.index == orbit:
			game.look(event.relative)
			get_viewport().set_input_as_handled()

func _stick(point: Vector2) -> void:
	var radius := 63.0 * float(game.settings.controls_scale)
	tip = (point - base).limit_length(radius)
	game.touch_vector = tip / radius
