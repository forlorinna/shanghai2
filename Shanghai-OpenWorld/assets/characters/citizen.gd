extends Node3D

const A = preload("res://scripts/art.gd")
var skeleton := Skeleton3D.new()
var bones: Dictionary = {}
var clock := 0.0
var gait := 0.0
var stance := 0.0
var preset := 0

func build(style := 0) -> void:
	preset = style
	add_child(skeleton)
	var skin := A.material(Color("#b78062") if style % 3 else Color("#ce9875"))
	var shirt := A.material([Color("#e3e2d3"), Color("#dde8e2"), Color("#ba988a")][style % 3])
	var jacket := A.material([Color("#204d56"), Color("#7c4a48"), Color("#5e626e"), Color("#a99c84")][style % 4])
	var jeans := A.material([Color("#232c3a"), Color("#373842"), Color("#424544")][style % 3])
	var shoes := A.material(Color("#20232a"))
	var hair := A.material(Color("#1d1919"))
	var torso := _bone("hips", -1, Vector3(0, 0.88, 0))
	var chest := _bone("spine", bones.hips, Vector3(0, 0.22, 0))
	var head := _bone("neck", bones.spine, Vector3(0, 0.34, 0))
	A.sphere(torso, Vector3(0, 0.06, 0), Vector3(0.39, 0.34, 0.25), jeans, 10)
	A.sphere(chest, Vector3(0, 0.12, 0), Vector3(0.45, 0.49, 0.25), jacket)
	A.box(chest, Vector3(0, 0.13, -0.119), Vector3(0.115, 0.35, 0.037), shirt)
	A.sphere(head, Vector3(0, 0.13, 0), Vector3(0.225, 0.29, 0.219), skin)
	A.sphere(head, Vector3(0, 0.224, 0.019), Vector3(0.232, 0.13, 0.229), hair)
	A.sphere(head, Vector3(0, 0.135, -0.105), Vector3(0.058, 0.061, 0.072), skin, 8)
	for side in [-1, 1]:
		var tag := "l" if side == -1 else "r"
		var shoulder := _bone("arm_" + tag, bones.spine, Vector3(side * 0.212, 0.23, 0))
		A.sphere(shoulder, Vector3(0, -0.13, 0), Vector3(0.135, 0.38, 0.145), jacket)
		var elbow := _bone("forearm_" + tag, bones["arm_" + tag], Vector3(0, -0.262, 0))
		A.sphere(elbow, Vector3(0, -0.091, 0), Vector3(0.102, 0.24, 0.11), jacket)
		A.sphere(elbow, Vector3(0, -0.225, 0), Vector3(0.099, 0.155, 0.105), skin, 10)
		var hip := _bone("leg_" + tag, bones.hips, Vector3(side * 0.113, -0.033, 0))
		A.sphere(hip, Vector3(0, -0.15, 0), Vector3(0.185, 0.46, 0.196), jeans)
		var knee := _bone("calf_" + tag, bones["leg_" + tag], Vector3(0, -0.383, 0))
		A.sphere(knee, Vector3(0, -0.167, 0), Vector3(0.132, 0.416, 0.14), jeans)
		A.box(knee, Vector3(0, -0.366, -0.063), Vector3(0.153, 0.13, 0.259), shoes)

func _bone(label: String, parent: int, offset: Vector3) -> BoneAttachment3D:
	var index := skeleton.add_bone(label)
	bones[label] = index
	skeleton.set_bone_parent(index, parent)
	skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, offset))
	skeleton.set_bone_pose_position(index, offset)
	var socket := BoneAttachment3D.new()
	skeleton.add_child(socket)
	socket.bone_name = label
	return socket

func _bend(label: String, angles: Vector3) -> void:
	skeleton.set_bone_pose_rotation(bones[label], Quaternion.from_euler(angles))

func animate(delta: float, speed: float, mode: String) -> void:
	gait = move_toward(gait, clampf(speed / 4.0, 0.0, 1.2), delta * 6.0)
	stance = move_toward(stance, 1.0 if mode == "crouch" else 0.0, delta * 6.0)
	clock += (1.15 + speed * 1.85) * delta
	var swing := sin(clock) * gait
	var flying := mode in ["jump", "climb", "swim"]
	var dead := mode == "down"
	skeleton.set_bone_pose_position(bones.hips, Vector3(0, 0.88 - stance * 0.28, 0))
	_bend("hips", Vector3(PI * 0.5 if dead else stance * 0.20, 0, 0))
	_bend("spine", Vector3(-gait * 0.10 - stance * 0.27, sin(clock) * gait * 0.11, 0.0))
	for side in [-1, 1]:
		var tag := "l" if side == -1 else "r"
		_bend("leg_" + tag, Vector3(swing * side * 0.71 - stance * 0.6 + (-0.5 if flying else 0.0), 0.0, 0.04 * side))
		_bend("calf_" + tag, Vector3(maxf(0, swing * side * 0.8) + stance * 0.8, 0, 0))
		_bend("arm_" + tag, Vector3(-swing * side * 0.57 + (-1.41 if flying else 0.0), 0, 0.12 * side))
		_bend("forearm_" + tag, Vector3(-0.16 - gait * 0.34, 0, 0))
