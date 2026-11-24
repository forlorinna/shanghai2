extends Node3D

const A = preload("res://scripts/art.gd")
var stone := A.material(Color("#bcbcb2"))
var dark := A.material(Color("#243942"), 0.28)
var silver := A.material(Color("#94a7ab"), 0.48, 0.4)
var glass := A.material(Color("#467889"), 0.4, 0.28)
var rose := A.material(Color("#a73362"), 0.2)
var amber := A.material(Color("#e7ad65"), 0.13)
var historic := A.material(Color("#ac9174"), 0.07)
var jade := A.material(Color("#305a56"), 0.35)
var lamps: Array[MeshInstance3D] = []
var neon_pink := A.material(Color("#ff346d"), 0.05, 0.64, true)
var neon_blue := A.material(Color("#44bdf0"), 0.12, 0.60, true)
var neon_mint := A.material(Color("#b0f0ee"), 0.08, 0.68, true)
var warm_outline := A.material(Color("#ffba67"), 0.04, 0.68, true)

func build(specs: Array, bridge_ends: Array) -> void:
	for entry in specs:
		var root := Node3D.new()
		root.name = entry[0]
		root.position = Vector3(entry[3][0], 0, entry[3][1])
		match entry[0]:
			"pearl": _pearl(root)
			"shanghai": _shanghai(root)
			"jinmao": _jinmao(root)
			"swfc": _swfc(root)
			"convention": _convention(root)
			"peace": _peace(root)
			"customs": _customs(root)
			"bridge": _bridge(root, bridge_ends)
			"wharf": _wharf(root)
			_: 
				root.free()
				continue
		add_child(root)

func _accent(root: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var item := A.box(root, pos, size, A.material(color, 0.0, 0.5, true))
	item.visibility_range_end = 1600
	lamps.append(item)

func night_light(amount: float) -> void:
	for lamp in lamps:
		lamp.visible = amount > 0.20

func _pearl(root: Node3D) -> void:
	A.cylinder(root, Vector3(0, 2.8, 0), 5.6, 28, 27, silver, 20)
	A.cylinder(root, Vector3(0, 81, 0), 157, 9.4, 6.6, stone, 14)
	A.cylinder(root, Vector3(0, 217, 0), 218, 6.5, 4.2, silver, 14)
	A.cylinder(root, Vector3(0, 371, 0), 95, 2.2, 1.3, dark, 9)
	A.cylinder(root, Vector3(0, 442, 0), 52, 0.7, 0.22, rose, 8)
	for angle in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		var footing := Vector3(cos(angle) * 38, 2, sin(angle) * 38)
		A.beam(root, footing, Vector3(cos(angle) * 7, 96, sin(angle) * 7), 3.6, stone, 12)
		A.collider(root, footing, Vector3(10, 7, 10))
		for level in [136, 162, 191, 219, 246]:
			A.sphere(root, Vector3(cos(angle) * 3.4, level, sin(angle) * 3.4), Vector3(8, 8, 8), glass, 10)
	for row in [[93.0, 51.0], [267.0, 44.0], [350.0, 18.0]]:
		var y: float = row[0]
		var d: float = row[1]
		A.sphere(root, Vector3(0, y, 0), Vector3(d, d * 0.9, d), rose, 26)
		A.cylinder(root, Vector3(0, y - 4, 0), 3.0, d * 0.505, d * 0.505, dark, 28)
		A.cylinder(root, Vector3(0, y + 2, 0), 2.0, d * 0.505, d * 0.505, silver, 28)
		lamps.append(A.cylinder(root, Vector3(0, y + 2.7, 0), 0.88, d * 0.508, d * 0.508, neon_pink, 28))
		lamps.append(A.cylinder(root, Vector3(0, y - 7, 0), 0.63, d * 0.494, d * 0.494, warm_outline, 28))
		for idx in 14:
			var angle := idx * TAU / 14.0
			_accent(root, Vector3(cos(angle) * d * 0.507, y - 4, sin(angle) * d * 0.507), Vector3(1.7, 0.7, 1.7), Color("#ff477c"))
	A.collider(root, Vector3(0, 2.7, 0), Vector3(36, 5.4, 34))
	A.collider(root, Vector3(0, 43, 0), Vector3(14, 83, 14))

func _shanghai(root: Node3D) -> void:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 13
	var floors := 54
	for floor_index in floors:
		for p in segments:
			var a := _twist_point(floor_index, p, floors, segments)
			var b := _twist_point(floor_index, p + 1, floors, segments)
			var c := _twist_point(floor_index + 1, p + 1, floors, segments)
			var d := _twist_point(floor_index + 1, p, floors, segments)
			for v in [a, d, c, c, b, a]:
				builder.add_vertex(v)
	builder.generate_normals()
	var mat := A.material(Color("#70aaba"), 0.61, 0.24).duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	A.mesh(root, builder.commit(), Vector3.ZERO, mat)
	for level in range(1, floors, 4):
		for p in [0, 4, 8, 11]:
			A.beam(root, _twist_point(level, p, floors, segments), _twist_point(mini(floors, level + 3), p, floors, segments), 0.75, silver, 5)
	for p in [0, 4, 8]:
		for level in range(1, floors - 2, 3):
			var a := _twist_point(level, p, floors, segments)
			var b := _twist_point(level + 3, p, floors, segments)
			lamps.append(A.beam(root, a + Vector3(a.x, 0, a.z).normalized() * 0.28,
				b + Vector3(b.x, 0, b.z).normalized() * 0.28, 0.47, neon_mint, 5))
	for p in range(0, segments, 2):
		var upper := _twist_point(floors, p, floors, segments)
		_accent(root, upper, Vector3(1.8, 2.1, 1.8), Color("#b9e6ff"))
	A.collider(root, Vector3(0, 5, 0), Vector3(58, 10, 57))

func _twist_point(floor_index: int, point: int, floors: int, segments: int) -> Vector3:
	var t := float(floor_index) / floors
	var angle := float(point) * TAU / segments + t * 2.09
	var r := (42.0 - t * 20.0) * (0.92 + 0.12 * cos(angle * 3.0 - t * 6.0))
	return Vector3(cos(angle) * r, t * 632.0 - (1.0 - cos(angle)) * t * 4.2, sin(angle) * r)

func _jinmao(root: Node3D) -> void:
	A.box(root, Vector3(0, 20, 0), Vector3(60, 40, 57), stone)
	var top := 40.0
	var width := 49.0
	for index in 12:
		var h := 47.5 - index * 3.05
		A.box(root, Vector3(0, top + h * 0.5, 0), Vector3(width, h, width), glass)
		A.box(root, Vector3(0, top + h - 2, 0), Vector3(width + 2.6, 3.8, width + 2.6), silver)
		for x in [-1, 1]:
			for z in [-1, 1]:
				A.box(root, Vector3(x * width * 0.42, top + h * 0.5, z * width * 0.42), Vector3(1.5, h, 1.5), silver)
				if index % 3 == 0:
					_accent(root, Vector3(x * width * 0.49, top + h, z * width * 0.49), Vector3(2, 1.2, 2), Color("#fadb9b"))
		if index % 2 == 0:
			for side in [-1, 1]:
				lamps.append(A.box(root, Vector3(0, top + h - 1.0, side * (width * 0.5 + 1.32)), Vector3(width, 0.37, 0.23), warm_outline))
		top += h
		width *= 0.84
	A.cylinder(root, Vector3(0, (top + 420.5) * 0.5, 0), 420.5 - top, 4, 0.7, silver, 10)
	A.collider(root, Vector3(0, 14, 0), Vector3(52, 28, 52))

func _swfc(root: Node3D) -> void:
	root.rotation.y = 0.12
	A.box(root, Vector3(0, 207, 0), Vector3(54, 414, 38), glass)
	for side in [-1, 1]:
		var low := Vector3(side * 21.8, 410, 0)
		var high := Vector3(side * 28.0, 480, 0)
		var wing := A.box(root, (low + high) * 0.5, Vector3(11, low.distance_to(high), 37), glass)
		wing.rotation.z = -side * 0.088
		A.beam(root, Vector3(side * 26.5, 24, 19), Vector3(side * 26, 413, 19), 0.55, silver)
		_accent(root, Vector3(side * 26, 481, 20), Vector3(3, 1.1, 1.0), Color("#91deff"))
	A.box(root, Vector3(0, 483.0, 0), Vector3(66, 18, 37), silver)
	for side in [-1, 1]:
		lamps.append(A.box(root, Vector3(0, 478, side * 18.57), Vector3(60, 1.3, 0.25), neon_blue))
		lamps.append(A.box(root, Vector3(0, 412, side * 19.02), Vector3(48, 1.3, 0.25), neon_blue))
		for edge in [-1, 1]:
			lamps.append(A.beam(root, Vector3(edge * 27, 34, side * 19.1), Vector3(edge * 27, 412, side * 19.1), 0.55, neon_blue, 5))
	A.box(root, Vector3(0, 477.6, 19), Vector3(59, 4, 2), dark)
	A.collider(root, Vector3(0, 18, 0), Vector3(54, 36, 38))

func _convention(root: Node3D) -> void:
	A.box(root, Vector3(0, 11, 0), Vector3(123, 22, 66), silver)
	A.box(root, Vector3(0, 13, -34), Vector3(103, 14, 4), glass)
	for x in [-48.0, 48.0]:
		A.sphere(root, Vector3(x, 19, -17), Vector3(43, 43, 43), glass, 28)
		for h in [11, 19, 27]:
			A.cylinder(root, Vector3(x, h, -17), 0.85, 21, 21, silver, 24)
		A.collider(root, Vector3(x, 12, -17), Vector3(32, 24, 32))
	A.collider(root, Vector3(0, 10, 2), Vector3(96, 20, 57))

func _facade(root: Node3D, width: float, depth: float, height: float) -> void:
	A.box(root, Vector3(0, height * 0.5, 0), Vector3(width, height, depth), historic)
	for level in range(1, floori(height / 4.5)):
		var y := level * 4.5 + 0.1
		for side in [-1, 1]:
			for col in range(-floori(width / 7.0), floori(width / 7.0) + 1):
				var x := col * 3.4
				A.box(root, Vector3(x, y, side * depth * 0.503), Vector3(1.36, 2.3, 0.17), dark)
				if level == 1 and col % 2 == 0:
					_accent(root, Vector3(x, y, side * depth * 0.513), Vector3(0.43, 1.2, 0.15), Color("#ffd596"))
			if level == 1:
				for col in range(-floori(width / 7.0), floori(width / 7.0) + 1):
					A.cylinder(root, Vector3(col * 3.4 + 1.65, 3.2, side * (depth * 0.5 + 0.31)), 6.4, 0.32, 0.27, stone, 8)
	for y in [1.0, 7.0, height - 1.5, height + 0.1]:
		A.box(root, Vector3(0, y, 0), Vector3(width + 1.1, 0.45, depth + 1.1), silver)
		if y >= 7:
			for side in [-1, 1]:
				lamps.append(A.box(root, Vector3(0, y + 0.21, side * (depth * 0.5 + 0.59)), Vector3(width, 0.11, 0.09), warm_outline))
	A.collider(root, Vector3(0, height * 0.5, 0), Vector3(width, height, depth))

func _peace(root: Node3D) -> void:
	root.rotation.y = deg_to_rad(-16)
	_facade(root, 55, 46, 31)
	A.box(root, Vector3(11, 34, 5), Vector3(20, 6, 18), historic)
	var crown := A.cylinder(root, Vector3(11, 46, 5), 22, 13, 0.9, jade, 4)
	crown.rotation.y = PI * 0.25
	A.cylinder(root, Vector3(11, 60, 5), 7, 0.35, 0.05, silver, 7)

func _customs(root: Node3D) -> void:
	root.rotation.y = deg_to_rad(-19)
	_facade(root, 36, 28, 26)
	A.box(root, Vector3(0, 42, 3), Vector3(12.3, 38, 13.0), historic)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var face := A.cylinder(root, Vector3(sin(angle) * 6.7, 53, 3 + cos(angle) * 6.9), 0.18, 2.2, 2.2, stone, 24)
		face.rotation = Vector3(PI * 0.5, angle, 0)
		var anchor := face.position + Vector3(sin(angle) * 0.15, 0, cos(angle) * 0.15)
		A.box(root, anchor + Vector3(0, 0.55, 0), Vector3(0.22, 1.4, 0.22), dark)
	A.box(root, Vector3(0, 62, 3), Vector3(10, 2.5, 10), jade)
	A.cylinder(root, Vector3(0, 66, 3), 7.5, 6.2, 1.9, jade, 4).rotation.y = PI * 0.25

func _bridge(root: Node3D, ends: Array) -> void:
	var start := Vector3(ends[0][0], 3.65, ends[0][1]) - root.position
	var end := Vector3(ends[1][0], 3.65, ends[1][1]) - root.position
	var forward := start.direction_to(end)
	var across := forward.cross(Vector3.UP)
	for side in [-1, 1]:
		var last: Vector3 = start + across * side * 6.0 + Vector3.UP * 1.3
		for i in range(1, 13):
			var t := i / 12.0
			var base: Vector3 = start.lerp(end, t) + across * side * 6.0
			var upper: Vector3 = base + Vector3.UP * (1.3 + absf(sin(t * TAU)) * 8.5)
			A.beam(root, last, upper, 0.32, silver)
			A.beam(root, base, upper, 0.14, silver)
			A.beam(root, last, base, 0.18, silver)
			last = upper
	for t in [0.10, 0.50, 0.90]:
		var point := start.lerp(end, t)
		A.box(root, point - Vector3.UP * 3.3, Vector3(12, 6, 2.35), historic)
	for t in [0.0, 1.0]:
		var point := start.lerp(end, t)
		var away := forward * (-1 if t == 0 else 1)
		var ramp_end := point + away * 19.0 - Vector3.UP * 3.55
		var ramp := A.collider(root, point.lerp(ramp_end, 0.5) - Vector3.UP * 0.19, Vector3(11, 0.4, point.distance_to(ramp_end)))
		ramp.basis = Basis.looking_at(ramp.position.direction_to(ramp_end), Vector3.UP)
		A.box(ramp, Vector3.ZERO, Vector3(11, 0.4, point.distance_to(ramp_end)), dark)

func _wharf(root: Node3D) -> void:
	root.rotation.y = deg_to_rad(-29)
	A.box(root, Vector3(0, 0.5, 0), Vector3(15, 1, 49), historic)
	A.collider(root, Vector3(0, 0.5, 0), Vector3(15, 1, 49))
	A.box(root, Vector3(0, 4.8, 0), Vector3(12, 0.65, 38), jade)
	for z in [-15, -5, 5, 15]:
		for x in [-5, 5]:
			A.cylinder(root, Vector3(x, 2.5, z), 5, 0.35, 0.3, silver, 9)
