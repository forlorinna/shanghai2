extends RefCounted

static var cache: Dictionary = {}

static func material(color: Color, metallic := 0.0, roughness := 0.72, luminous := false) -> StandardMaterial3D:
	var key := [color, metallic, roughness, luminous]
	if cache.has(key):
		return cache[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	if luminous:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = 1.5
	cache[key] = result
	return result

static func mesh(root: Node3D, primitive: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = primitive
	item.position = pos
	item.material_override = mat
	root.add_child(item)
	return item

static func box(root: Node3D, pos: Vector3, extent: Vector3, mat: Material) -> MeshInstance3D:
	var primitive := BoxMesh.new()
	primitive.size = extent
	return mesh(root, primitive, pos, mat)

static func sphere(root: Node3D, pos: Vector3, extent: Vector3, mat: Material, segments := 14) -> MeshInstance3D:
	var primitive := SphereMesh.new()
	primitive.radial_segments = segments
	primitive.rings = maxi(4, segments / 2)
	primitive.radius = 0.5
	primitive.height = 1
	var item := mesh(root, primitive, pos, mat)
	item.scale = extent
	return item

static func cylinder(root: Node3D, pos: Vector3, height: float, bottom: float, top: float, mat: Material, sides := 16) -> MeshInstance3D:
	var primitive := CylinderMesh.new()
	primitive.radial_segments = sides
	primitive.rings = 0
	primitive.height = height
	primitive.bottom_radius = bottom
	primitive.top_radius = top
	return mesh(root, primitive, pos, mat)

static func beam(root: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material, sides := 8) -> MeshInstance3D:
	var pointer := cylinder(root, (a + b) * 0.5, a.distance_to(b), radius, radius, mat, sides)
	var direction := a.direction_to(b)
	var axis := Vector3.UP.cross(direction)
	if axis.length_squared() > 0.000001:
		pointer.rotate(axis.normalized(), Vector3.UP.angle_to(direction))
	return pointer

static func collider(root: Node3D, at: Vector3, extent: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var hit := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = extent
	hit.shape = shape
	body.position = at
	root.add_child(body)
	body.add_child(hit)
	return body

static func coachwork(root: Node3D, pos: Vector3, extent: Vector3, mat: Material, cabin := false) -> MeshInstance3D:
	var half := extent * 0.5
	var bevel := minf(0.19, half.x * 0.26)
	var footprint := [
		Vector2(-half.x + bevel, -half.z), Vector2(half.x - bevel, -half.z),
		Vector2(half.x, -half.z + bevel), Vector2(half.x, half.z - bevel),
		Vector2(half.x - bevel, half.z), Vector2(-half.x + bevel, half.z),
		Vector2(-half.x, half.z - bevel), Vector2(-half.x, -half.z + bevel),
	]
	var rings: Array[PackedVector3Array] = []
	var phases := [[-1.0, 0.92, 0.97], [-0.60, 1.0, 1.0], [0.56, 1.0, 0.997], [1.0, 0.89, 0.93]]
	if cabin:
		phases = [[-1.0, 0.99, 0.99], [-0.75, 1.0, 1.0], [0.91, 0.83, 0.71], [1.0, 0.76, 0.66]]
	for phase in phases:
		var ring := PackedVector3Array()
		for p in footprint:
			ring.append(Vector3(p.x * phase[1], half.y * phase[0],
				p.y * phase[2] + (half.z * 0.13 if cabin and phase[0] > 0 else 0.0)))
		rings.append(ring)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for step in range(1, rings.size()):
		for j in footprint.size():
			var next := (j + 1) % footprint.size()
			var lower := rings[step - 1]
			var upper := rings[step]
			for vertex in [lower[j], lower[next], upper[next], lower[j], upper[next], upper[j]]:
				surface.add_vertex(vertex)
	for j in footprint.size():
		var next := (j + 1) % footprint.size()
		for vertex in [Vector3(0, half.y, 0), rings[-1][j], rings[-1][next],
				Vector3(0, -half.y, 0), rings[0][next], rings[0][j]]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	return mesh(root, surface.commit(), pos, mat)
