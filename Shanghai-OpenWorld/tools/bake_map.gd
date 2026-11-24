extends SceneTree

const CITY_SHADER = preload("res://shaders/city.gdshader")
const WATER_SHADER = preload("res://shaders/huangpu.gdshader")
const BUILDING_COLORS := [
	Color("#8098a3"), Color("#879695"), Color("#8e8c82"), Color("#a1a29a"), Color("#566f82"),
	Color("#c6ab89"), Color("#aaa092"), Color("#bdad94"), Color("#8e8376"), Color("#b6a898"),
]
const ROAD_COLORS := [Color("#858686"), Color("#39404a"), Color("#313946"), Color("#2b3440"), Color("#6b7174")]
var surfaces: Dictionary
var origin := Vector3.ZERO
var solid := PackedVector3Array()
var materials: Array[Material] = []

func _initialize() -> void:
	for i in range(4):
		var mat := ShaderMaterial.new()
		mat.shader = CITY_SHADER
		mat.set_shader_parameter("surface_type", i)
		materials.append(mat)
	var water := ShaderMaterial.new()
	water.shader = WATER_SHADER
	materials.append(water)
	var city: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/city.json"))
	var skyline := Node3D.new()
	skyline.name = "Skyline"
	for tile in city.tiles:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/source/chunks/%s.json" % tile))
		if data.get("skyline", []).is_empty():
			continue
		surfaces = {}
		origin = _center(tile)
		var group := Node3D.new()
		group.name = "Distant_" + tile.replace("-", "N")
		group.position = origin
		skyline.add_child(group)
		group.owner = skyline
		_attach_distant(group, data.skyline)
		group.get_child(0).owner = skyline
	_save(skyline, "res://maps/chunks/skyline.scn")
	for tile in city.tiles:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/source/chunks/%s.json" % tile))
		_bake(tile, data)
	print("Map bake complete, ", city.tiles.size(), " chunk scenes plus skyline")
	quit()

func _center(key: String) -> Vector3:
	var pair := key.split("_")
	return Vector3((float(pair[0]) + 0.5) * 256.0, 0, (float(pair[1]) + 0.5) * 256.0)

func _attach_distant(root: Node3D, buildings: Array) -> void:
	for building in buildings:
		_building(building, "HLOD", false)
	_attach(root, "HLOD", 2, 405.0)

func _surface(key: String) -> SurfaceTool:
	if not surfaces.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[key] = st
	return surfaces[key]

func _point(a: Array, index: int, height: float) -> Vector3:
	return Vector3(float(a[index]), height, float(a[index + 1]))

func _tri(key: String, a: Vector3, b: Vector3, c: Vector3, color: Color, normal: Vector3, collision := false) -> void:
	if (b - a).cross(c - a).length_squared() < 0.000001:
		return
	var st := _surface(key)
	for point in [a, b, c]:
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(point - origin)
		if collision:
			solid.append(point - origin)

func _flat(data: Array, height: float, key: String, color: Color, collision := false) -> void:
	for index in range(0, data.size(), 6):
		var a := _point(data, index, height)
		var b := _point(data, index + 2, height)
		var c := _point(data, index + 4, height)
		if (b - a).cross(c - a).y > 0:
			_tri(key, a, c, b, color, Vector3.UP, collision)
		else:
			_tri(key, a, b, c, color, Vector3.UP, collision)

func _quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, normal: Vector3, collision := false) -> void:
	_tri(key, a, b, c, color, normal, collision)
	_tri(key, a, c, d, color, normal, collision)

func _building(record: Array, key: String, collision: bool) -> void:
	var height: float = record[1]
	var color: Color = BUILDING_COLORS[int(record[2])]
	_flat(record[4], height, key, color.darkened(0.28), collision)
	for ring in record[3]:
		for j in ring.size():
			var a := _point(ring[j], 0, 0)
			var b := _point(ring[(j + 1) % ring.size()], 0, 0)
			var normal := (b - a).cross(Vector3.UP).normalized()
			_quad(key, a, a + Vector3.UP * height, b + Vector3.UP * height, b,
				color, normal, collision)
			if int(record[2]) >= 5 and collision and height > 12.0:
				for h in [3.05, height - 0.75, height - 2.0]:
					var offset := normal * 0.12
					var c: Vector3 = a + Vector3.UP * h + offset
					var d: Vector3 = b + Vector3.UP * h + offset
					_quad("details", c - offset * 2.0, c + Vector3.UP * 0.26 - offset * 2.0,
						d + Vector3.UP * 0.26 - offset * 2.0, d - offset * 2.0, color.lightened(0.22), normal)
					_quad("details", c, c + Vector3.UP * 0.26, d + Vector3.UP * 0.26, d,
						color.lightened(0.22), normal)

func _attach(root: Node3D, key: String, material: int, begin := 0.0, end := 0.0) -> void:
	if not surfaces.has(key):
		return
	var st: SurfaceTool = surfaces[key]
	st.index()
	var mi := MeshInstance3D.new()
	mi.name = key
	mi.mesh = st.commit()
	mi.material_override = materials[material]
	mi.visibility_range_begin = begin
	mi.visibility_range_end = end
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.owner = root

func _batch(root: Node3D, label: String, items: Array, mesh: Mesh, color: Color, height: float, distance_limit: float) -> void:
	if items.is_empty():
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.87
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = items.size()
	for index in items.size():
		var item: Array = items[index]
		var scale_factor: float = item[2] if label != "LampPoles" else 1.0
		multi.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_factor), _point(item, 0, height * scale_factor) - origin))
	var mi := MultiMeshInstance3D.new()
	mi.name = label
	mi.multimesh = multi
	mi.material_override = material
	mi.visibility_range_end = distance_limit
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.owner = root

func _bake(key: String, data: Dictionary) -> void:
	surfaces = {}
	solid = PackedVector3Array()
	var root := Node3D.new()
	root.name = "Chunk_" + key.replace("-", "N")
	origin = _center(key)
	root.position = origin
	_flat(data.get("ground", []), 0.0, "ground", Color("#545953"), true)
	_flat(data.get("water", []), -0.62, "water", Color.WHITE)
	_flat(data.get("water", []), -5.4, "seabed", Color("#26352e"), true)
	_flat(data.get("park", []), 0.013, "ground", Color("#395c43"))
	for row in data.get("road", []):
		_flat(row[2], row[1], "roads", ROAD_COLORS[int(row[0])])
	for row in data.get("deck", []):
		_flat(row[1], row[0], "roads", Color("#41454d"), true)
	for row in data.get("marks", []):
		var a := _point(row, 0, row[4])
		var b := _point(row, 2, row[4])
		var side := (b - a).cross(Vector3.UP).normalized() * 0.075
		_quad("details", a - side, b - side, b + side, a + side, Color("#c1b286"), Vector3.UP)
	for row in data.get("lamps", []):
		var p := _point(row, 0, 5.5)
		var forward := Vector3(sin(row[2]), 0, cos(row[2]))
		var side := forward.cross(Vector3.UP)
		_quad("lamp_glow", p - side * 0.25, p - side * 0.25 + forward * 0.54,
			p + side * 0.25 + forward * 0.54, p + side * 0.25, Color("#ffe2a3"), Vector3.UP)
	for row in data.get("supports", []):
		var p := _point(row, 0, 0.0)
		var h: float = row[2]
		var ring := [[p.x - 0.81, p.z - 0.72], [p.x - 0.81, p.z + 0.72], [p.x + 0.81, p.z + 0.72], [p.x + 0.81, p.z - 0.72]]
		for j in 4:
			var a := _point(ring[j], 0, 0.0)
			var b := _point(ring[(j + 1) % 4], 0, 0.0)
			_quad("details", a, a + Vector3.UP * h, b + Vector3.UP * h, b, Color("#686a66"), (b - a).cross(Vector3.UP).normalized(), true)
	var distant := {}
	for building in data.get("skyline", []):
		distant[building[0]] = true
	for building in data.get("buildings", []):
		_building(building, "near_buildings" if distant.has(building[0]) else "buildings", true)
	_attach(root, "ground", 2)
	_attach(root, "roads", 1)
	_attach(root, "water", 4)
	_attach(root, "seabed", 2)
	_attach(root, "buildings", 0)
	_attach(root, "near_buildings", 0, 0.0, 407.0)
	_attach(root, "details", 2, 0.0, 300.0)
	_attach(root, "lamp_glow", 3, 0.0, 395.0)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.095
	trunk.bottom_radius = 0.17
	trunk.rings = 0
	trunk.radial_segments = 6
	trunk.height = 3.0
	_batch(root, "TreeTrunks", data.get("trees", []), trunk, Color("#593f31"), 1.5, 430.0)
	var canopy := SphereMesh.new()
	canopy.radial_segments = 7
	canopy.rings = 4
	canopy.radius = 1.92
	canopy.height = 3.7
	_batch(root, "TreeCrowns", data.get("trees", []), canopy, Color("#336443"), 3.65, 550.0)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.050
	pole.bottom_radius = 0.11
	pole.radial_segments = 6
	pole.rings = 0
	pole.height = 5.5
	_batch(root, "LampPoles", data.get("lamps", []), pole, Color("#3b4349"), 2.75, 380.0)
	if not solid.is_empty():
		var body := StaticBody3D.new()
		body.name = "Geometry"
		var collider := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(solid)
		collider.shape = shape
		root.add_child(body)
		body.owner = root
		body.add_child(collider)
		collider.owner = root
	_save(root, "res://maps/chunks/%s.scn" % key)

func _save(root: Node3D, path: String) -> void:
	var packed := PackedScene.new()
	var error := packed.pack(root)
	if error == OK:
		error = ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Could not bake %s (%s)" % [path, error])
	root.free()
