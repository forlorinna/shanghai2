extends CanvasLayer

const Atlas = preload("res://ui/atlas.gd")
const TouchOverlay = preload("res://ui/touch.gd")
const Jobs = preload("res://systems/missions.gd")
const Weather = preload("res://systems/climate.gd")
const Car = preload("res://assets/vehicles/vehicle.gd")
const CREAM := Color("#f2e9d9")
const MUTED := Color("#a6bdc3")
const HONEY := Color("#ffc58b")
const AQUA := Color("#a4eadf")
const DARK := Color("#11242f")
const MODEL_ZH := ["轿车", "SUV", "跑车", "出租车", "公交车", "摩托车", "警车"]
const MODEL_EN := ["Sedan", "SUV", "Sports car", "Taxi", "Bus", "Motorcycle", "Police"]
const PRICE := [0, 320, 740, 210, 650, 235, 999]
var game
var screen := ""
var layer_root: Control
var safe: MarginContainer
var content: Control
var hud: Control
var touch: Control
var font: Font
var notice_label: Label
var notice_panel: PanelContainer
var clock: Label
var balance: Label
var stars: Label
var speed: Label
var mission: Label
var health: ProgressBar
var energy: ProgressBar
var guidance: Label
var debug_panel: Label
var damage_tint: ColorRect
var flash := 0.0
var debug := false
var parent_screen := "title"
var settings_tab := 0
var map_control: Control
var force_touch := false
var refresh := 0.0

func _ready() -> void:
	layer = 7
	font = preload("res://assets/textures/city-font.otf")

func t(zh: String, en: String) -> String:
	return game.bi(zh, en)

func _style(color: Color, border := Color.TRANSPARENT, rounding := 9) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(rounding)
	s.content_margin_left = 13
	s.content_margin_right = 13
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _label(text: String, size: int, color := CREAM) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_override("font", font)
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func _button(text: String, call: Callable, highlight := false, height := 40) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = height
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.add_theme_font_override("font", font)
	result.add_theme_font_size_override("font_size", 15)
	result.add_theme_color_override("font_color", Color("#14282e") if highlight else CREAM)
	result.add_theme_color_override("font_hover_color", Color("#14282e") if highlight else AQUA)
	result.add_theme_color_override("font_pressed_color", Color("#14282e") if highlight else HONEY)
	result.add_theme_color_override("font_disabled_color", Color("#6f8490"))
	result.add_theme_stylebox_override("normal", _style(HONEY if highlight else Color("#17323f"), Color("#b9dab94d") if highlight else Color("#55758365")))
	result.add_theme_stylebox_override("hover", _style(Color("#ffd7a5") if highlight else Color("#244b54"), Color("#a3d6ca80")))
	result.add_theme_stylebox_override("pressed", _style(Color("#79bfb4") if highlight else Color("#2e5662"), AQUA))
	result.add_theme_stylebox_override("disabled", _style(Color("#15262d"), Color("#30434a")))
	result.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, HONEY))
	result.pressed.connect(func():
		game.feedback("ui", game.focus())
		call.call()
	)
	return result

func _box(vertical: bool, separation := 10) -> BoxContainer:
	var box: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box

func _panel(parent: Node, bg := Color("#0d212de8"), border := Color("#55748166")) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(bg, border, 11))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel

func _background(color: Color) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_root.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.show_behind_parent = true

func _set_rect(node: Control, anchors: Vector4, offsets: Vector4) -> void:
	node.anchor_left = anchors.x
	node.anchor_top = anchors.y
	node.anchor_right = anchors.z
	node.anchor_bottom = anchors.w
	node.offset_left = offsets.x
	node.offset_top = offsets.y
	node.offset_right = offsets.z
	node.offset_bottom = offsets.w

func _insets() -> void:
	if not is_instance_valid(safe):
		return
	var margin := Vector4(24, 18, 24, 18)
	if OS.has_feature("android"):
		var physical := DisplayServer.window_get_size()
		if physical.x > 0 and physical.y > 0:
			var inset := DisplayServer.get_display_safe_area()
			if inset.size.x > 0 and inset.size.y > 0:
				var logical := get_viewport().get_visible_rect().size / Vector2(physical)
				margin += Vector4(inset.position.x * logical.x, inset.position.y * logical.y,
					maxi(0, physical.x - inset.end.x) * logical.x, maxi(0, physical.y - inset.end.y) * logical.y)
	for row in [["margin_left", margin.x], ["margin_top", margin.y], ["margin_right", margin.z], ["margin_bottom", margin.w]]:
		safe.add_theme_constant_override(row[0], int(row[1]))

func open(target: String) -> void:
	if target == "map" and screen in ["title", "pause", "game"]:
		parent_screen = screen
	elif target in ["settings", "about"] and screen in ["title", "pause"]:
		parent_screen = screen
	if target == "pause" or target == "title":
		game.save_game(false)
		if target == "title":
			game._title_view()
	screen = target
	if is_instance_valid(touch):
		touch.reset()
	if is_instance_valid(layer_root):
		layer_root.hide()
		layer_root.queue_free()
	notice_panel = null
	damage_tint = null
	layer_root = Control.new()
	layer_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer_root)
	layer_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe = MarginContainer.new()
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_root.add_child(safe)
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(content)
	_insets()
	safe.resized.connect(_insets)
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if target == "game" and not DisplayServer.is_touchscreen_available() and not force_touch else Input.MOUSE_MODE_VISIBLE
	match target:
		"title": _title()
		"game": _game_hud()
		"pause": _pause()
		"map": _map()
		"settings": _settings()
		"phone": _phone()
		"jobs": _jobs()
		"garage": _garage()
		"sandbox": _sandbox()
		"about": _about()
	show_notice()

func _title() -> void:
	_background(Color("#071b2a51"))
	var left := _panel(content, Color("#0b1e2aef"), Color("#577b867a"))
	_set_rect(left, Vector4(0, 0.05, 0, 0.95), Vector4(20, 0, 424, 0))
	var col := _box(true, 7)
	left.add_child(col)
	col.add_child(_label("SHANGHAI   /   31°14′ N", 15, HONEY))
	col.add_child(_label(t("魔都：自由都市", "Shanghai"), 41))
	col.add_child(_label(t("S H A N G H A I   O P E N   W O R L D", "O P E N   W O R L D"), 15, AQUA))
	var divider := HSeparator.new()
	col.add_child(divider)
	col.add_child(_button(t("开始游戏", "Start game"), func(): game.begin("new"), true, 47))
	var continuing := _button(t("继续游戏", "Continue"), func(): game.begin("continue"))
	continuing.disabled = game.save_cache.is_empty()
	col.add_child(continuing)
	col.add_child(_button(t("自由探索", "Free exploration"), func(): game.begin("free")))
	col.add_child(_button(t("上海地图", "Shanghai map"), func(): open("map")))
	for row in [[t("画质设置", "Graphics"), 0], [t("操作设置", "Controls"), 1], [t("音频设置", "Audio"), 2]]:
		col.add_child(_button(row[0], func():
			settings_tab = row[1]
			open("settings")
		))
	col.add_child(_button(t("关于游戏", "About"), func(): open("about")))
	if not OS.has_feature("web"):
		col.add_child(_button(t("退出游戏", "Quit"), func(): get_tree().quit(), false, 34))
	var foot := _label("V0.1.0     •     " + t("黄浦江两岸", "Both banks of the Huangpu"), 13, MUTED)
	col.add_child(foot)
	var caption := _panel(content, Color("#0c202dcc"), Color("#6b8d9870"))
	_set_rect(caption, Vector4(1, 1, 1, 1), Vector4(-346, -78, -14, -14))
	var info := _box(true, 2)
	caption.add_child(info)
	info.add_child(_label(t("浦东 · 陆家嘴", "PUDONG  ·  LUJIAZUI"), 19))
	info.add_child(_label("© OpenStreetMap contributors", 13, MUTED))

func _card(title: String, back: Callable, width := 660, top := 37.0) -> VBoxContainer:
	_background(Color("#071620ba"))
	var pane := _panel(content)
	_set_rect(pane, Vector4(0.5, 0, 0.5, 1), Vector4(-width * 0.5, top, width * 0.5, -top))
	var col := _box(true, 11)
	pane.add_child(col)
	var header := _box(false, 10)
	col.add_child(header)
	var title_label := _label(title, 29)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	header.add_child(_button(t("返回", "Back"), back, false, 35))
	col.add_child(HSeparator.new())
	return col

func _scroll(parent: Node) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var col := _box(true)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	return col

func _pause() -> void:
	var column := _card(t("游戏暂停", "Game paused"), func(): open("game"), 510, 87)
	column.add_child(_button(t("返回游戏", "Resume"), func(): open("game"), true))
	column.add_child(_button(t("地图与导航", "Map and GPS"), func(): open("map")))
	column.add_child(_button(t("城市手机", "City phone"), func(): open("phone")))
	column.add_child(_button(t("手动存档", "Save game"), func(): game.save_game()))
	column.add_child(_button(t("游戏设置", "Settings"), func(): open("settings")))
	column.add_child(_button(t("沙盒与调试", "Sandbox & diagnostics"), func(): open("sandbox")))
	column.add_child(_button(t("返回主菜单", "Main menu"), func(): open("title")))

func _bar(slot: BoxContainer, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(110, 7)
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _style(Color("#27414a"), Color.TRANSPARENT, 4))
	bar.add_theme_stylebox_override("fill", _style(color, Color.TRANSPARENT, 4))
	slot.add_child(bar)
	return bar

func _game_hud() -> void:
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mini := Atlas.new()
	mini.game = game
	mini.miniature = true
	hud.add_child(mini)
	_set_rect(mini, Vector4.ZERO, Vector4(13, 18, 177, 182))
	var meta := _panel(hud)
	_set_rect(meta, Vector4.ZERO, Vector4(196, 18, 404, 132))
	var details := _box(true, 4)
	meta.add_child(details)
	clock = _label("", 16, CREAM)
	details.add_child(clock)
	balance = _label("", 15, AQUA)
	details.add_child(balance)
	health = _bar(details, Color("#ed8d78"))
	energy = _bar(details, Color("#9cd6bf"))
	stars = _label("", 16, HONEY)
	details.add_child(stars)
	var top := _box(false, 8)
	hud.add_child(top)
	top.alignment = BoxContainer.ALIGNMENT_END
	_set_rect(top, Vector4(1, 0, 1, 0), Vector4(-384, 17, -12, 57))
	for row in [[t("地图", "Map"), "map"], [t("手机", "Phone"), "phone"], [t("暂停", "Pause"), "pause"]]:
		top.add_child(_button(row[0], func(): open(row[1]), false, 36))
	var action_box := _box(true, 5)
	hud.add_child(action_box)
	_set_rect(action_box, Vector4(1, 0, 1, 0), Vector4(-371, 70, -14, 167))
	mission = _label("", 17, HONEY)
	mission.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	action_box.add_child(mission)
	guidance = _label("", 14, CREAM)
	guidance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	action_box.add_child(guidance)
	speed = _label("", 33, CREAM)
	speed.add_theme_color_override("font_outline_color", Color("#112430"))
	speed.add_theme_constant_override("outline_size", 7)
	speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(speed)
	_set_rect(speed, Vector4(1, 0.52, 1, 0.52), Vector4(-241, -31, -28, 45))
	debug_panel = _label("", 14, AQUA)
	debug_panel.add_theme_color_override("font_outline_color", Color("#081621"))
	debug_panel.add_theme_constant_override("outline_size", 6)
	hud.add_child(debug_panel)
	_set_rect(debug_panel, Vector4(0, 0, 0, 0), Vector4(17, 205, 490, 300))
	damage_tint = ColorRect.new()
	damage_tint.color = Color(0.67, 0.07, 0.08, 0)
	damage_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(damage_tint)
	damage_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch = TouchOverlay.new()
	touch.game = game
	touch.forced = force_touch
	content.add_child(touch)
	touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _map_back() -> void:
	open("game" if game.started and parent_screen != "pause" else parent_screen)

func _map() -> void:
	var col := _card(t("上海 · 城市地图", "Shanghai · City map"), _map_back, 1050, 28)
	var block := _box(false)
	block.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(block)
	map_control = Atlas.new()
	map_control.game = game
	map_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	block.add_child(map_control)
	var side := _box(true, 7)
	side.custom_minimum_size.x = 208
	block.add_child(side)
	side.add_child(_label(t("上海地标", "Landmarks"), 17, AQUA))
	var links := _scroll(side)
	for entry in game.world.data.landmarks:
		links.add_child(_button(t(entry[1], entry[2]), func():
			map_control.selected = game.place(entry[0], true)
			map_control.midpoint = map_control._meters_to_uv(map_control.selected)
			map_control.zoom = 2.3
		, false, 31))
	var commands := _box(false, 8)
	col.add_child(commands)
	commands.add_child(_label(t("拖动平移 · 滚轮或双指缩放", "Drag to pan · wheel or pinch to zoom"), 13, MUTED))
	if game.started:
		commands.add_child(_button(t("设为目的地", "Set destination"), func():
			if map_control.selected.is_finite():
				game.set_destination(map_control.selected)
				parent_screen = "game"
				open("game")
		, true, 35))
		commands.add_child(_button(t("快速传送", "Fast travel"), func():
			if map_control.selected.is_finite():
				var node: Dictionary = game.streets.spawn_space(map_control.selected)
				game.in_tunnel = false
				game.on_ferry = false
				game.inside = false
				game.player.set_driven(game.driving != null)
				game.teleport(node.pos)
				if game.driving != null:
					game.driving.rotation.y = node.yaw
				parent_screen = "game"
				open("game")
		, false, 35))
		commands.add_child(_button(t("清除导航", "Clear route"), func():
			game.clear_destination()
			map_control.selected = Vector3.INF
		, false, 35))
	col.add_child(_label("© OpenStreetMap contributors  ·  ODbL 1.0", 12, MUTED))

func _toggle(target: VBoxContainer, text: String, initial: bool, cb: Callable) -> void:
	var control := _button(text + "    " + t("开", "ON") if initial else text + "    " + t("关", "OFF"), func(): cb.call(), initial, 35)
	target.add_child(control)

func _setting_switch(target: VBoxContainer, text: String, key: String) -> void:
	_toggle(target, text, bool(game.settings[key]), func():
		game.settings[key] = not game.settings[key]
		if key == "wanted" and not game.settings[key]:
			game.set_wanted(0)
		game.apply_settings()
		game.save_settings()
		open(screen)
	)

func _slider(target: VBoxContainer, text: String, key: String, low: float, high: float) -> void:
	var row := _box(false)
	var label := _label(text, 15, CREAM)
	label.custom_minimum_size.x = 190
	row.add_child(label)
	var slide := HSlider.new()
	slide.min_value = low
	slide.max_value = high
	slide.step = 0.025
	slide.value = float(game.settings[key])
	slide.custom_minimum_size.y = 30
	slide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slide.add_theme_stylebox_override("slider", _style(Color("#446571"), Color.TRANSPARENT, 3))
	slide.add_theme_stylebox_override("grabber_area", _style(Color("#a7d4c6"), Color.TRANSPARENT, 3))
	slide.value_changed.connect(func(value: float):
		game.settings[key] = value
		game.apply_settings()
		game.save_settings()
	)
	row.add_child(slide)
	target.add_child(row)

func _options(parent: VBoxContainer, names: Array, selected: int, callback: Callable) -> void:
	var row := _box(false, 7)
	for i in names.size():
		var item := _button(names[i], func(): callback.call(i), i == selected, 34)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(item)
	parent.add_child(row)

func _settings() -> void:
	var col := _card(t("游戏设置", "Settings"), func(): open(parent_screen))
	_options(col, [t("画质", "Graphics"), t("操作", "Controls"), t("音频", "Audio")], settings_tab, func(index: int):
		settings_tab = index
		open("settings")
	)
	var fields := _scroll(col)
	match settings_tab:
		0:
			fields.add_child(_label(t("画质等级", "Visual preset"), 16, AQUA))
			_options(fields, [t("低", "Low"), t("中", "Medium"), t("高", "High"), t("极高", "Ultra")], int(game.settings.quality), func(index: int):
				game.settings.quality = index
				_apply()
			)
			fields.add_child(_label(t("帧率上限", "Frame cap"), 16, AQUA))
			var caps := [30, 45, 60, 90]
			_options(fields, ["30 FPS", "45 FPS", "60 FPS", "90 FPS"], caps.find(int(game.settings.fps)), func(index: int):
				game.settings.fps = caps[index]
				_apply()
			)
			_setting_switch(fields, t("自动降低画质", "Automatic quality reduction"), "auto")
			_setting_switch(fields, t("省电模式", "Battery saving"), "power")
			_setting_switch(fields, t("通缉系统", "Wanted system"), "wanted")
			_setting_switch(fields, t("交通车辆", "City traffic"), "traffic")
			_slider(fields, t("行人密度", "Pedestrian density"), "crowds", 0, 2)
		1:
			_options(fields, ["简体中文", "English"], 1 if game.settings.language == "en" else 0, func(index: int):
				game.settings.language = "en" if index == 1 else "zh"
				_apply()
			)
			_setting_switch(fields, t("左手触控模式", "Left-handed touch layout"), "lefty")
			_setting_switch(fields, t("倾斜驾驶", "Tilt steering"), "gyro")
			_setting_switch(fields, t("Android 震动", "Android vibration"), "vibration")
			_slider(fields, t("震动强度", "Vibration strength"), "intensity", 0, 1)
			_slider(fields, t("镜头灵敏度", "Camera sensitivity"), "camera", 0.35, 2.2)
			_slider(fields, t("驾驶灵敏度", "Steering sensitivity"), "steering", 0.40, 1.6)
			_slider(fields, t("按钮大小", "Button size"), "controls_scale", 0.72, 1.32)
			_slider(fields, t("按钮透明度", "Button opacity"), "controls_alpha", 0.20, 1)
			_slider(fields, t("按钮位置", "Button position"), "controls_offset", -1, 0.45)
			_toggle(fields, t("显示触屏布局", "Show touch layout"), force_touch, func():
				force_touch = not force_touch
				open("settings")
			)
			fields.add_child(_label("WASD  ·  SPACE  ·  F  ·  E  ·  V  ·  M  ·  TAB  ·  ESC", 13, MUTED))
		2:
			_slider(fields, t("主音量", "Master volume"), "volume", 0, 1)
			_slider(fields, t("效果音量", "Effects volume"), "effects_volume", 0, 1)
			_slider(fields, t("环境音量", "City volume"), "ambience_volume", 0, 1)
			_slider(fields, t("音乐音量", "Music volume"), "music_volume", 0, 1)

func _apply() -> void:
	game.apply_settings()
	game.save_settings()
	open("settings")

func _phone() -> void:
	var col := _card(t("城市手机", "City phone"), func(): open("game"), 550, 63)
	col.add_child(_label("%s    ·    %s" % [_time(), _weather()], 19, AQUA))
	col.add_child(_button(t("上海地图与 GPS", "Shanghai map & GPS"), func():
		parent_screen = "game"
		open("map")
	, true))
	col.add_child(_button(t("相机 · 保存截图", "Camera · Save screenshot"), func():
		open("game")
		game.capture()
	))
	col.add_child(_button(t("任务列表与城市联系人", "Jobs & city contacts"), func(): open("jobs")))
	col.add_child(_button(t("车库与收藏", "Garage & collection"), func(): open("garage")))
	col.add_child(_button(t("出租车服务", "Request a taxi"), func():
		game.summon(3)
		open("game")
	))
	col.add_child(_button(t("游戏设置", "Settings"), func():
		parent_screen = "phone"
		open("settings")
	))
	col.add_child(_button(t("手动存档", "Save game"), func(): game.save_game()))

func _jobs() -> void:
	var col := _card(t("任务与联系人", "Jobs & contacts"), func(): open("phone"))
	var list := _scroll(col)
	if not game.missions.current.is_empty():
		list.add_child(_label(game.missions.job_name(), 18, HONEY))
		list.add_child(_button(t("取消任务", "Cancel current job"), func():
			game.missions.current.clear()
			game.clear_destination()
			open("jobs")
		))
	for i in Jobs.JOBS.size():
		var job: Array = Jobs.JOBS[i]
		var title := t(job[1], job[2]) + "    ¥%s" % job[5]
		if game.missions.completed.has(job[0]):
			title += "   ✓"
		list.add_child(_button(title, func():
			game.missions.start(i)
			open("game")
		, false, 37))

func _garage() -> void:
	var col := _card(t("车库与收藏", "Garage & collection"), func(): open("phone"))
	col.add_child(_label(t("余额  ", "Balance  ") + "¥%s" % game.money, 16, AQUA))
	var list := _scroll(col)
	for i in range(6):
		var name := t(MODEL_ZH[i], MODEL_EN[i])
		var owned: bool = game.owned.has(i) or game.sandbox
		var text := name + t("   召唤", "   Summon") if owned else name + "   ¥%s" % PRICE[i]
		list.add_child(_button(text, func():
			if owned:
				game.summon(i)
				open("game")
			elif game.money >= PRICE[i] or game.infinite_money:
				if not game.infinite_money:
					game.money -= PRICE[i]
				game.owned.append(i)
				game.save_game(false)
				open("garage")
			else:
				game.notice(t("余额不足", "Insufficient funds"))
		, owned, 36))
	var recolor := _button(t("为当前车辆换色", "Repaint current vehicle"), func():
		game.driving.repaint([Color("#437c87"), Color("#b5414e"), Color("#eeeecc"), Color("#566240"), Color("#283949")].pick_random())
		game.save_game(false)
	)
	recolor.disabled = game.driving == null
	list.add_child(recolor)

	list.add_child(HSeparator.new())
	for style in 3:
		var key := "outfit_%s" % style
		var unlocked: bool = style == 0 or game.unlocks.has(key)
		var color: String = [t("青灰夹克", "Teal jacket"), t("酒红夹克", "Burgundy jacket"), t("深灰夹克", "Graphite jacket")][style]
		var cost := 110 + style * 40
		list.add_child(_button(color + (t("   穿着", "   Wear") if unlocked else "   ¥%d" % cost), func():
			if unlocked or game.buy_unlock(key, cost):
				game.outfit = style
				game.player.style_avatar(style)
				game.save_game(false)
				open("garage")
		, game.outfit == style, 36))
	var has_home: bool = game.unlocks.has("apartment")
	list.add_child(_button(t("导航至城市公寓", "Route to apartment") if has_home else t("解锁城市公寓   ¥1200", "Unlock city apartment   ¥1200"), func():
		if has_home:
			game.set_destination(game.apartment_entrance())
			open("game")
		elif game.buy_unlock("apartment", 1200):
			open("garage")
	, false, 36))

func _sandbox() -> void:
	var col := _card(t("沙盒与调试", "Sandbox & diagnostics"), func(): open("pause"))
	var list := _scroll(col)
	_toggle(list, t("开发者遥测", "Performance overlay"), debug, func():
		debug = not debug
		open("sandbox")
	)
	_toggle(list, t("沙盒", "Sandbox"), game.sandbox, func():
		game.sandbox = not game.sandbox
		if not game.sandbox:
			game.infinite_health = false
			game.infinite_stamina = false
			game.infinite_money = false
			game.free_camera = false
			game.photo_mode = false
			game.speed_scale = 1.0
		open("sandbox")
	)
	if not game.sandbox:
		return
	for row in [["infinite_health", t("无限生命", "Infinite health")], ["infinite_stamina", t("无限体力", "Infinite stamina")], ["infinite_money", t("无限资金", "Infinite funds")], ["photo_mode", t("无 HUD 摄影模式", "Hide HUD")], ["free_camera", t("自由航拍相机", "Free aerial camera")]]:
		_toggle(list, row[1], bool(game.get(row[0])), func():
			game.set(row[0], not bool(game.get(row[0])))
			game.free_position = game.camera.position + Vector3.UP * 24.0
			open("sandbox")
		)
	_setting_switch(list, t("交通车辆", "City traffic"), "traffic")
	_setting_switch(list, t("通缉系统", "Wanted system"), "wanted")
	_slider(list, t("行人密度", "Pedestrian density"), "crowds", 0, 2)
	list.add_child(_button(t("移动速度   ×", "Movement speed   ×") + str(game.speed_scale), func():
		game.speed_scale = 0.75 if game.speed_scale >= 2.5 else game.speed_scale + 0.25
		open("sandbox")
	))
	list.add_child(_button(t("时间   ", "Time   ") + _time(), func():
		game.climate.hour = fposmod(game.climate.hour + 3.0, 24.0)
		open("sandbox")
	))
	list.add_child(_button(t("天气   ", "Weather   ") + _weather(), func():
		game.climate.weather = (game.climate.weather + 1) % 7
		open("sandbox")
	))
	list.add_child(_button(t("生成车辆", "Spawn vehicle"), func(): open("garage")))
	list.add_child(_button(t("删除附近停放的车辆", "Remove nearby parked cars"), func():
		for car in game.cars.duplicate():
			if car != game.driving and car.position.distance_to(game.focus()) < 35:
				game.cars.erase(car)
				car.queue_free()
	))
	list.add_child(_button(t("通缉星级   ", "Wanted level   ") + str(game.wanted), func():
		game.set_wanted((game.wanted + 1) % 6)
		open("sandbox")
	))

func _about() -> void:
	var col := _card(t("关于游戏", "About"), func(): open(parent_screen))
	for text in [
		"Shanghai Open World   ·   V0.1.0",
		t("离线单机 · 上海陆家嘴、外滩与黄浦江", "Offline single-player · Lujiazui, the Bund and the Huangpu"),
		"© OpenStreetMap contributors · ODbL 1.0",
		"https://www.openstreetmap.org/copyright",
		t("原创程序化模型与合成音效", "Original procedural models and synthesized audio"),
		"Godot Engine · MIT  /  Noto Sans CJK SC · OFL 1.1",
	]:
		col.add_child(_label(text, 17, MUTED))

func _time() -> String:
	var hour := int(game.climate.hour)
	return "%02d:%02d" % [hour, int((game.climate.hour - hour) * 60.0)]

func _weather() -> String:
	var index: int = game.climate.weather
	return t(Weather.WEATHER_ZH[index], Weather.WEATHER_EN[index])

func show_notice() -> void:
	if not is_instance_valid(content) or game.notice_text.is_empty() or Time.get_ticks_msec() > game.notice_until:
		return
	if not is_instance_valid(notice_panel):
		notice_panel = _panel(content, Color("#0c202ee8"), Color("#98c8bf86"))
		_set_rect(notice_panel, Vector4(0.5, 1, 0.5, 1), Vector4(-244, -80, 244, -32))
		notice_label = _label("", 15, CREAM)
		notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		notice_panel.add_child(notice_label)
	notice_panel.visible = true
	notice_label.text = game.notice_text

func hurt() -> void:
	flash = 0.45

func _process(delta: float) -> void:
	if is_instance_valid(notice_panel) and Time.get_ticks_msec() > game.notice_until:
		notice_panel.hide()
	if screen != "game" or not is_instance_valid(hud):
		return
	flash = maxf(0, flash - delta * 1.14)
	damage_tint.color.a = flash
	hud.visible = not game.photo_mode
	refresh += delta
	if refresh < 0.16:
		return
	refresh = 0
	clock.text = _time() + "  /  " + _weather()
	balance.text = "¥  %s" % game.money
	health.value = game.player.health
	energy.value = game.player.stamina
	stars.text = "★".repeat(game.wanted) + "☆".repeat(5 - game.wanted)
	stars.modulate.a = 1.0 if game.wanted > 0 else 0.45
	speed.visible = game.driving != null
	if speed.visible:
		speed.text = "%03d km/h" % int(absf(game.driving.speed) * 3.6)
	mission.text = game.missions.job_name()
	var hint: String = game.interaction_hint()
	guidance.text = hint if not hint.is_empty() else game.missions.detail()
	debug_panel.visible = debug
	if debug:
		debug_panel.text = "%s FPS  ·  %.1f MiB  ·  [%s]  %s/%s\nNPC %s   AI %s   VEH %s   DRAW %s" % [
			Engine.get_frames_per_second(), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			game.world.active_tile, game.world.loaded.size(), game.world.pending.size(), game.streets.people.size(),
			game.streets.traffic.size(), game.cars.size(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		]
