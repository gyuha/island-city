extends Node3D
@export var target_path: NodePath
@export var follow_speed: float = 6.0
@export var distance: float = 9.5
@export var pitch_degrees: float = -55.0
var target: Node3D
func _ready() -> void:
	if not target_path.is_empty(): target = get_node_or_null(target_path)
	if target == null: target = get_tree().get_first_node_in_group("player")
	if target != null: global_position = target.global_position
func _process(delta: float) -> void:
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player")
		return
	global_position = global_position.lerp(target.global_position + Vector3.UP * 0.5, 1.0 - exp(-follow_speed * delta))
	var diving: bool = target.get("underwater") == true
	var gliding: bool = target.get("gliding") == true
	var offset := Vector3(0, sin(deg_to_rad(-pitch_degrees)), cos(deg_to_rad(-pitch_degrees))) * distance
	if gliding: offset *= 1.25
	if diving: offset = target.get("facing") * -4.5 + Vector3.UP * 1.8
	$Camera3D.position = $Camera3D.position.lerp(offset, 1.0 - exp(-4.0 * delta))
	$Camera3D.look_at(global_position)
