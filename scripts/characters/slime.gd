extends CharacterBody3D
@export var max_health: int = 50
@export var detection_radius: float = 7.0
@export var hop_speed: float = 2.5
@export var damage: int = 12
@export var drop_item: String = "slime_jelly"
var health: int
var hop_timer: float = 0.8
var contact_cooldown: float = 0.0
var dead: bool = false
func _ready() -> void:
	health = max_health
	if not CharacterVisuals.asset($Model, "res://assets/models/creatures/slime.glb"):
		var jelly := SphereMesh.new()
		jelly.radius = 0.45
		jelly.height = 0.65
		CharacterVisuals.mesh($Model, jelly, Vector3(0, 0.34, 0), Color("57d3b6"))
func _physics_process(delta: float) -> void:
	if dead: return
	hop_timer -= delta
	contact_cooldown -= delta
	velocity.y -= 18.0 * delta
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0, delta * 7)
		velocity.z = move_toward(velocity.z, 0, delta * 7)
		if player != null and global_position.distance_to(player.global_position) < detection_radius and hop_timer <= 0:
			var direction := global_position.direction_to(player.global_position)
			velocity = Vector3(direction.x * hop_speed, 4.0, direction.z * hop_speed)
			hop_timer = 1.15
	move_and_slide()
	$Model.scale.y = lerpf($Model.scale.y, 0.85 if is_on_floor() else 1.12, delta * 10)
	if player != null and global_position.distance_to(player.global_position) < 0.95 and contact_cooldown <= 0:
		player.take_damage(damage, global_position.direction_to(player.global_position) * 4.0)
		contact_cooldown = 1.2
func take_damage(amount: int, knockback: Vector3 = Vector3.ZERO) -> void:
	if dead: return
	health -= amount
	velocity += knockback + Vector3.UP * 2
	if health <= 0:
		dead = true
		GameEvents.enemy_defeated.emit("slime")
		var drop: Area3D = load("res://scenes/characters/pickup_flower.tscn").instantiate()
		drop.item_id = drop_item
		drop.prompt = "젤리 줍기"
		get_parent().add_child(drop)
		drop.global_position = global_position
		queue_free()
