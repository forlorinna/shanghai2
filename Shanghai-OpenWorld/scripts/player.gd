extends CharacterBody3D

const Citizen = preload("res://assets/characters/citizen.gd")
var hero: Node3D
var capsule: CapsuleShape3D
var collider: CollisionShape3D
var game
var health := 100.0
var stamina := 100.0
var crouching := false
var driven := false
var down := 0.0
var step_clock := 0.0

func create(context) -> void:
	game = context
	floor_snap_length = 0.39
	floor_max_angle = deg_to_rad(47)
	collision_layer = 2
	collision_mask = 1 | 4
	capsule = CapsuleShape3D.new()
	capsule.height = 1.78
	capsule.radius = 0.32
	collider = CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = 0.90
	add_child(collider)
	style_avatar(0)

func style_avatar(style: int) -> void:
	var direction := 0.0
	if is_instance_valid(hero):
		direction = hero.rotation.y
		hero.hide()
		hero.queue_free()
	hero = Citizen.new()
	hero.build(style)
	hero.rotation.y = direction
	add_child(hero)
	hero.visible = not driven

func set_driven(value: bool) -> void:
	driven = value
	collider.set_deferred("disabled", value)
	hero.visible = not value
	velocity = Vector3.ZERO

func damage(amount: float) -> void:
	if game.infinite_health or down > 0.0 or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	game.feedback("hurt", global_position)
	if health == 0.0:
		down = 2.0

func reset_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	health = 100
	stamina = 100
	down = 0.0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.is_playing() or driven or game.free_camera:
		return
	if global_position.y < -48:
		game.respawn()
		return
	if down > 0:
		down -= delta
		hero.animate(delta, 0.0, "down")
		if down <= 0.0:
			game.respawn()
		return
	var move: Vector2 = game.motion()
	var direction := Basis(Vector3.UP, game.yaw) * Vector3(move.x, 0, move.y)
	var wet: bool = global_position.y < -0.47 and global_position.y > -10 and game.world.is_water(global_position)
	var wants_crouch: bool = game.flag("crouch")
	if not wants_crouch and crouching:
		wants_crouch = test_move(global_transform, Vector3.UP * 0.52)
	crouching = wants_crouch
	var target_height := 1.13 if crouching else 1.78
	capsule.height = move_toward(capsule.height, target_height, delta * 7.0)
	collider.position.y = capsule.height * 0.5 + 0.015
	var sprint: bool = game.flag("sprint") and move.length_squared() > 0.1 and not crouching and not wet and (stamina > 1.0 or game.infinite_stamina)
	stamina = clampf(stamina + delta * (-15.0 if sprint and not game.infinite_stamina else 13.0), 0, 100)
	var speed := 2.2 if crouching else (8.3 if sprint else 4.7)
	if game.flag("walk"):
		speed *= 0.48
	if wet:
		speed = 3.1
	speed *= float(game.speed_scale)
	var grounded := is_on_floor()
	var mode := "ground"
	if wet:
		velocity.y = clampf((-0.78 - global_position.y) * 4.2, -2, 4)
		mode = "swim"
	elif grounded:
		velocity.y = -0.8
		if game.consume("jump"):
			if move.length_squared() > 0.06 and test_move(global_transform, direction.normalized() * 0.48) and not test_move(global_transform.translated(Vector3.UP * 0.76), direction.normalized() * 0.48):
				velocity.y = 6.8
				mode = "climb"
			else:
				velocity.y = 5.45
				mode = "jump"
	else:
		velocity.y -= 16.0 * delta
		mode = "jump"
	var descending := velocity.y
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * (31.0 if grounded else 13.0))
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * (31.0 if grounded else 13.0))
	move_and_slide()
	if not grounded and is_on_floor() and descending < -3.8 and not wet:
		game.feedback("land", global_position)
		if descending < -12.3:
			damage((-descending - 11.0) * 5.0)
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	if direction.length_squared() > 0.05:
		hero.rotation.y = lerp_angle(hero.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-delta * 15.0))
	if grounded and not wet and flat_speed > 1.5:
		step_clock += delta * flat_speed
		if step_clock > 1.6:
			step_clock = 0
			game.audio.play_spatial("step", global_position, -8.0 if sprint else -15.0)
	hero.animate(delta, flat_speed, "crouch" if crouching and mode == "ground" else mode)
