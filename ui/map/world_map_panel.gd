extends Control

signal window_opened
signal window_closed

@export var map_texture_path: String = "res://assets/textures/map/world_map.png"
@export var world_min: Vector2 = Vector2(-150.0, -150.0)
@export var world_max: Vector2 = Vector2(150.0, 150.0)

@onready var map_texture_rect: TextureRect = %MapTextureRect
@onready var map_area: Control = %MapArea
@onready var placeholder_rect: ColorRect = %PlaceholderRect
@onready var player_marker: Control = %PlayerMarker
@onready var close_button: Button = %CloseButton
@onready var coord_label: Label = %CoordLabel

var is_open: bool = false

func _ready() -> void:
	visible = false
	if close_button:
		close_button.pressed.connect(close)

	_load_map_texture()

func _load_map_texture() -> void:
	var loaded := false
	if ResourceLoader.exists(map_texture_path):
		var tex = load(map_texture_path) as Texture2D
		if tex:
			map_texture_rect.texture = tex
			map_texture_rect.visible = true
			placeholder_rect.visible = false
			loaded = true

	if not loaded:
		map_texture_rect.visible = false
		placeholder_rect.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("world_map"):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	_update_player_marker()
	window_opened.emit()

func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	window_closed.emit()

func _process(_delta: float) -> void:
	if is_open:
		_update_player_marker()

func _update_player_marker() -> void:
	if not player_marker or not map_area:
		return

	var player_node: Node3D = null
	var tree := get_tree()
	if tree:
		player_node = tree.get_first_node_in_group("player") as Node3D

	var world_x := 0.0
	var world_z := 0.0
	var player_yaw := 0.0

	if player_node and is_instance_valid(player_node):
		var pos = player_node.global_position
		world_x = pos.x
		world_z = pos.z
		player_yaw = player_node.rotation.y
		if "facing" in player_node and player_node.facing is Vector3 and player_node.facing.length_squared() > 0.01:
			player_yaw = atan2(-player_node.facing.x, -player_node.facing.z)

	if coord_label:
		coord_label.text = "위치: X %d, Z %d" % [int(world_x), int(world_z)]

	# 0..1 정규화 매핑
	var range_x := world_max.x - world_min.x
	var range_z := world_max.y - world_min.y
	if range_x == 0.0:
		range_x = 1.0
	if range_z == 0.0:
		range_z = 1.0

	var norm_x := clampf((world_x - world_min.x) / range_x, 0.0, 1.0)
	var norm_z := clampf((world_z - world_min.y) / range_z, 0.0, 1.0)

	var area_size := map_area.size
	player_marker.position = Vector2(norm_x * area_size.x, norm_z * area_size.y)
	player_marker.rotation = -player_yaw
