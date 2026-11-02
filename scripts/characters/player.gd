extends CharacterBody3D
signal underwater_changed(underwater: bool)
@export var walk_speed: float = 3.5
@export var sprint_speed: float = 5.8
@export var jump_speed: float = 6.5
@export var glide_speed: float = 5.0
@export var swim_speed: float = 2.6
@export var max_health: int = 100
@export var attack_damage: int = 25
@export var interaction_radius: float = 2.0
var health: int
var state: String = "idle"
var underwater: bool = false
var gliding: bool = false
var water_areas: Array[Area3D] = []
var invulnerability: float = 0.0
var attack_timer: float = 0.0
var attack_cooldown: float = 0.0
var hit_targets: Array[Node] = []
var facing := Vector3.FORWARD
var spawn_point := Vector3.ZERO
var step_timer: float = 0.0
var anim_time: float = 0.0
var prompt_target: Node3D
var animated_parts: Dictionary = {}
var rest_rotations: Dictionary = {}
@onready var model: Node3D = $Model
@onready var wings: Node3D = $Model/GliderWings
@onready var hitbox: Area3D = $AttackHitbox
func _ready() -> void:
	health = max_health
	spawn_point = global_position
	if not CharacterVisuals.asset(model, "res://assets/models/characters/player.glb"):
		CharacterVisuals.explorer(model, Color("b9804f"))
	if not CharacterVisuals.asset(wings, "res://assets/models/gear/glider_wings.glb"):
		var wing := BoxMesh.new()
		wing.size = Vector3(1.8, 0.08, 0.55)
		CharacterVisuals.mesh(wings, wing, Vector3.ZERO, Color("ffe4ec"))
	for part_name in ["Head", "Body", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]:
		var part := model.find_child(part_name, true, false) as Node3D
		if part != null:
			animated_parts[part_name] = part
			rest_rotations[part_name] = part.rotation
	$WaterSensor.area_entered.connect(_water_entered)
	$WaterSensor.area_exited.connect(_water_exited)
	GameEvents.player_health_changed.emit(health, max_health)
	GameEvents.player_state_changed.emit(state)
func _physics_process(delta: float) -> void:
	invulnerability = maxf(0, invulnerability - delta)
	attack_cooldown = maxf(0, attack_cooldown - delta)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if DialogueManager.is_active(): input = Vector2.ZERO
	var camera := get_viewport().get_camera_3d()
	var direction := Vector3(input.x, 0, input.y)
	if camera != null:
		var right := camera.global_basis.x
		var back := camera.global_basis.z
		right.y = 0
		back.y = 0
		direction = right.normalized() * input.x + back.normalized() * input.y
	direction = direction.limit_length()
	if direction.length() > 0.1: facing = direction.normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	water_areas = water_areas.filter(func(area): return is_instance_valid(area))
	if not water_areas.is_empty():
		gliding = false
		speed = swim_speed
		var surface: float = float(water_areas[0].get_meta("surface_y", water_areas[0].global_position.y))
		if Input.is_action_pressed("dive"): velocity.y = -2.0
		elif Input.is_action_pressed("jump"): velocity.y = 3.0
		else: velocity.y = clampf((surface - 0.35 - global_position.y) * 4.0, -2.0, 2.0)
		_set_underwater(global_position.y < surface - 0.8)
		_set_state("dive" if underwater else "swim")
	else:
		_set_underwater(false)
		if is_on_floor():
			gliding = false
			if Input.is_action_just_pressed("jump") and not DialogueManager.is_active(): velocity.y = jump_speed
		elif Input.is_action_just_pressed("jump"):
			gliding = not gliding
		if gliding:
			speed = glide_speed
			if direction.length() < 0.1: direction = facing
			velocity.y = move_toward(velocity.y, -1.1, 18.0 * delta)
		else: velocity.y -= 18.0 * delta
		_set_state("glide" if gliding else ("jump" if not is_on_floor() or velocity.y > 0.1 else ("walk" if direction.length() > 0.1 else "idle")))
	velocity.x = move_toward(velocity.x, direction.x * speed, 22.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 22.0 * delta)
	move_and_slide()
	model.rotation.y = lerp_angle(model.rotation.y, atan2(-facing.x, -facing.z), delta * 12.0)
	wings.visible = gliding
	anim_time += delta
	var walking := state == "walk"
	model.position.y = absf(sin(anim_time * 12)) * 0.045 if walking else 0.0
	model.scale = Vector3(1.0, 1.0 + sin(anim_time * 24) * 0.025, 1.0) if walking else Vector3.ONE
	_animate_parts(delta, walking, speed / walk_speed)
	if walking:
		step_timer -= delta
		if step_timer <= 0:
			GameEvents.footstep.emit("grass")
			step_timer = 0.32 if speed == walk_speed else 0.22
	if Input.is_action_just_pressed("attack") and not DialogueManager.is_active(): attack()
	if attack_timer > 0:
		attack_timer -= delta
		for body in hitbox.get_overlapping_bodies():
			if body.is_in_group("enemy") and body.has_method("take_damage") and not hit_targets.has(body):
				hit_targets.append(body)
				body.take_damage(attack_damage, facing * 5.0)
	_update_interaction()
	if Input.is_action_just_pressed("interact") and DialogueManager.can_start_interaction():
		if is_instance_valid(prompt_target): prompt_target.interact(self)
	if global_position.y < -25: respawn()
func attack() -> void:
	if attack_cooldown > 0: return
	attack_cooldown = 0.45
	attack_timer = 0.18
	hit_targets.clear()
	hitbox.global_position = global_position + facing * 0.7 + Vector3.UP * 0.5
	GameEvents.attack_performed.emit()
func take_damage(amount: int, knockback: Vector3 = Vector3.ZERO) -> void:
	if invulnerability > 0 or amount <= 0: return
	health = maxi(0, health - amount)
	invulnerability = 1.0
	velocity += knockback
	GameEvents.player_damaged.emit(amount)
	GameEvents.player_health_changed.emit(health, max_health)
	if health == 0:
		GameEvents.player_died.emit()
		respawn()
func respawn() -> void:
	global_position = spawn_point
	velocity = Vector3.ZERO
	gliding = false
	water_areas.clear()
	_set_underwater(false)
	health = max_health
	invulnerability = 1.0
	GameEvents.player_health_changed.emit(health, max_health)
func _set_state(value: String) -> void:
	if state == value: return
	state = value
	GameEvents.player_state_changed.emit(state)
func _set_underwater(value: bool) -> void:
	if underwater == value: return
	underwater = value
	underwater_changed.emit(value)
	GameEvents.player_underwater_changed.emit(value)
func _water_entered(area: Area3D) -> void:
	if area.is_in_group("water_volume") and not water_areas.has(area): water_areas.append(area)
func _water_exited(area: Area3D) -> void:
	water_areas.erase(area)
	if water_areas.is_empty():
		_set_underwater(false)
		if state == "swim" or state == "dive": _set_state("jump")
func _update_interaction() -> void:
	var nearest: Node3D
	var distance := interaction_radius
	if not DialogueManager.is_active():
		for candidate in get_tree().get_nodes_in_group("interactable"):
			if candidate is Node3D and candidate.has_method("interact"):
				var d := global_position.distance_to(candidate.global_position)
				if d < distance:
					distance = d
					nearest = candidate
	if prompt_target != nearest:
		prompt_target = nearest
		GameEvents.interact_prompt_changed.emit("E · " + str(nearest.get("prompt")) if nearest != null else "", nearest != null)

func _animate_parts(delta: float, walking: bool, pace: float) -> void:
	var swing := sin(anim_time * 12.0 * pace) if walking else 0.0
	for part_name in animated_parts:
		var part: Node3D = animated_parts[part_name]
		var rotation_target: Vector3 = rest_rotations[part_name]
		match part_name:
			"LeftArm":
				rotation_target.x += swing * 0.5
				if gliding: rotation_target.z -= 0.95
			"RightArm":
				rotation_target.x -= swing * 0.5
				if gliding: rotation_target.z += 0.95
			"LeftLeg": rotation_target.x -= swing * 0.65
			"RightLeg": rotation_target.x += swing * 0.65
			"Head": rotation_target.z += swing * 0.025
			"Body": rotation_target.z -= swing * 0.035
		part.rotation = part.rotation.lerp(rotation_target, 1.0 - exp(-14.0 * delta))
