extends Node3D
## 통합 씬: 월드 + 플레이어 + 카메라 + HUD를 묶고 GameEvents를 월드·오디오에 연결한다.
## 소유: orchestrator (docs/team-contract.md 9장)

const NPC_SCENE := preload("res://scenes/characters/npc.tscn")
const FLOWER_SCENE := preload("res://scenes/characters/pickup_flower.tscn")
const SLIME_SCENE := preload("res://scenes/characters/slime.tscn")

@onready var island: Node3D = $Island
@onready var player: CharacterBody3D = $Player

func _ready() -> void:
	# 월드 물 영역은 Area3D 중심이 수면 아래라서, 수면 높이(Y=0)를 명시한다.
	for water in get_tree().get_nodes_in_group("water_volume"):
		water.set_meta("surface_y", 0.0)
	player.global_transform = island.get_spawn_transform()
	player.spawn_point = player.global_position
	_wire_audio()
	GameEvents.player_underwater_changed.connect(island.set_underwater)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_place_entities()

func _place_entities() -> void:
	# 스폰 주변 링에서 수면(Y=0)보다 높은 땅만 골라 NPC·꽃·슬라임을 놓는다.
	var origin := player.global_position
	var spots := _land_spots(origin, 4.0, 18.0, 11)
	_spawn(NPC_SCENE, spots[0])
	for i in range(1, 8):
		_spawn(FLOWER_SCENE, spots[i])
	for i in range(8, 11):
		_spawn(SLIME_SCENE, spots[i])

func _land_spots(origin: Vector3, r_min: float, r_max: float, count: int) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	var i := 0
	while spots.size() < count and i < 400:
		var t := float(spots.size()) / count
		var r := lerpf(r_min, r_max, t)
		var a := i * 2.39996  # golden angle
		var p := _ground(origin + Vector3(cos(a), 0, sin(a)) * r)
		if p.y > 0.5:
			spots.append(p)
		i += 1
	return spots

func _spawn(scene: PackedScene, at: Vector3) -> void:
	var node: Node3D = scene.instantiate()
	add_child(node)
	node.global_position = at

func _ground(at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 50.0, at + Vector3.DOWN * 50.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if hit else Vector3(at.x, -100.0, at.z)

func _wire_audio() -> void:
	AudioManager.play_bgm("meadow")
	AudioManager.set_ambient("wind_light", true)
	AudioManager.set_ambient("waves_shore", true, Vector3(-20, 0, 70))
	GameEvents.footstep.connect(func(surface: String): AudioManager.play_sfx("footstep_" + surface))
	GameEvents.attack_performed.connect(func(): AudioManager.play_sfx("attack_swing"))
	GameEvents.player_damaged.connect(func(_amount: int): AudioManager.play_sfx("player_hit"))
	GameEvents.enemy_defeated.connect(func(_id: String): AudioManager.play_sfx("slime_defeat"))
	GameEvents.item_added.connect(func(_id: String, _n: int): AudioManager.play_sfx("item_pickup"))
	GameEvents.dialogue_line.connect(func(_s: String, _t: String): AudioManager.play_ui("dialogue_advance"))
	GameEvents.player_state_changed.connect(func(state: String):
		AudioManager.set_ambient("glide_wind", state == "glide")
		AudioManager.set_ambient("swim_loop", state == "swim"))
	GameEvents.player_underwater_changed.connect(func(under: bool):
		AudioManager.set_ambient("underwater_loop", under)
		AudioManager.play_bgm("underwater" if under else "meadow", 0.6 if under else 1.2))
