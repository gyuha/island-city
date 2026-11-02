extends Node
## 녹화용 자동 플레이. main.tscn을 인스턴스하고 입력 액션으로 약 55초간 플레이한다.
## 소유: qa. 실행: godot --write-movie /tmp/playtest/frame.png --fixed-fps 30 res://tests/playtest/playtest.tscn

@onready var main: Node3D = $Main
@onready var player: CharacterBody3D = $Main/Player

var t0 := 0.0
var _held := {}
var dialogue_lines: Array = []

func _ready() -> void:
	GameEvents.dialogue_line.connect(func(s, text): dialogue_lines.append(text); print("PLAYTEST_LOG dialogue_line ", text))
	GameEvents.enemy_defeated.connect(func(id): print("PLAYTEST_LOG enemy_defeated ", id))
	GameEvents.item_added.connect(func(id, n): print("PLAYTEST_LOG item_added ", id, " x", n))
	GameEvents.player_underwater_changed.connect(func(u): print("PLAYTEST_LOG underwater ", u))
	_run()

func _now() -> float:
	return float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second - t0

func _seg(name: String) -> void:
	_release_all()
	print("PLAYTEST_SEG %s t=%.1f" % [name, _now()])

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, true).timeout

# ── 입력 ────────────────────────────────────────────────

func _hold(action: String, strength := 1.0) -> void:
	Input.action_press(action, strength)
	_held[action] = true

func _release(action: String) -> void:
	Input.action_release(action)
	_held.erase(action)

func _release_all() -> void:
	for a in _held.keys():
		Input.action_release(a)
	_held.clear()

func _tap(action: String, hold_sec := 0.12) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(hold_sec)
	e = InputEventAction.new()
	e.action = action
	e.pressed = false
	Input.parse_input_event(e)
	await _wait(0.08)

func _axis(pos: String, neg: String, v: float) -> void:
	if v >= 0.0:
		_hold(pos, v)
		_release(neg)
	else:
		_hold(neg, -v)
		_release(pos)

## 목표 방향(월드)을 카메라 기준 WASD 입력으로 변환. 거리를 반환.
func _steer(target: Vector3) -> float:
	var to := target - player.global_position
	to.y = 0.0
	var dist := to.length()
	var cam := get_viewport().get_camera_3d()
	if cam == null or dist < 0.05:
		_axis("move_right", "move_left", 0.0)
		_axis("move_back", "move_forward", 0.0)
		return dist
	var right := cam.global_basis.x
	var back := cam.global_basis.z
	right.y = 0.0
	back.y = 0.0
	right = right.normalized()
	back = back.normalized()
	var d := to / dist
	_axis("move_right", "move_left", d.dot(right))
	_axis("move_back", "move_forward", d.dot(back))
	return dist

func _stop_move() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "sprint"]:
		_release(a)

## target은 Vector3 또는 노드를 돌려주는 Callable. 도착하면 true.
func _walk_to(target: Callable, stop_dist: float, timeout: float, sprint := false) -> bool:
	if sprint: _hold("sprint")
	var elapsed := 0.0
	var last_pos := player.global_position
	var stuck := 0.0
	while elapsed < timeout:
		var tp: Variant = target.call()
		if tp == null:
			break
		var dist := _steer(tp)
		if dist <= stop_dist:
			_stop_move()
			return true
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		elapsed += dt
		stuck += dt
		if stuck > 1.5:
			if player.global_position.distance_to(last_pos) < 0.4:
				await _tap("jump")
			last_pos = player.global_position
			stuck = 0.0
	_stop_move()
	return false

func _nearest(nodes: Array) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for n in nodes:
		if not is_instance_valid(n): continue
		var d := player.global_position.distance_to(n.global_position)
		if d < bd:
			bd = d
			best = n
	return best

func _flowers() -> Array:
	return get_tree().get_nodes_in_group("interactable").filter(func(n): return n.get("item_id") == "wildflower" and not n.collected)

# ── 시나리오 ─────────────────────────────────────────────

func _run() -> void:
	t0 = float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second
	await _wait(2.0)

	# (1) 초원 걷기·달리기
	_seg("walk_run")
	var npc := _nearest(get_tree().get_nodes_in_group("interactable").filter(func(n): return n.has_method("interact") and n.get("dialogue") != null))
	var far: Node3D = null
	for f in _flowers():
		if far == null or player.global_position.distance_to(f.global_position) > player.global_position.distance_to(far.global_position):
			far = f
	# 먼 꽃 쪽으로 걷다가(4.5s) 달린다(4s)
	await _walk_to(func(): return far.global_position, 1.0, 4.5, false)
	await _walk_to(func(): return far.global_position if is_instance_valid(far) else null, 1.0, 4.0, true)
	await _walk_to(func(): return npc.global_position, 6.0, 4.0, true)

	# (2) 꽃 채집 3회
	_seg("flowers")
	for i in 3:
		var f := _nearest(_flowers())
		if f == null: break
		await _walk_to(func(): return f.global_position if is_instance_valid(f) else null, 1.0, 6.0, true)
		await _wait(0.5)
		await _tap("interact")
		await _wait(0.5)

	# (3) NPC 대화
	_seg("npc_dialogue")
	await _walk_to(func(): return npc.global_position, 1.2, 8.0, true)
	await _wait(0.4)
	await _tap("interact")
	var guard := 0
	while DialogueManager.is_active() and guard < 6:
		await _wait(1.6)
		if DialogueManager.is_active():
			await _tap("interact")
		guard += 1
	await _wait(0.6)

	# (4) 인벤토리
	_seg("inventory")
	await _tap("inventory")
	await _wait(2.5)
	await _tap("inventory")
	await _wait(0.5)

	# (5) 슬라임 처치
	_seg("slime")
	var slime := _nearest(get_tree().get_nodes_in_group("enemy"))
	var sid := slime.get_instance_id()
	await _walk_to(func(): return slime.global_position if is_instance_valid(slime) else null, 1.4, 10.0, true)
	var tries := 0
	while is_instance_valid(instance_from_id(sid)) and tries < 14:
		_steer(slime.global_position) if is_instance_valid(slime) else null
		await _tap("attack", 0.1)
		await _wait(0.45)
		tries += 1
	_stop_move()
	await _wait(0.4)
	var drop := _nearest(get_tree().get_nodes_in_group("interactable").filter(func(n): return n.get("item_id") == "slime_jelly"))
	if drop != null:
		await _walk_to(func(): return drop.global_position if is_instance_valid(drop) else null, 0.9, 5.0, false)
		await _tap("interact")
	await _wait(0.3)

	# (6) 점프 + 공중 점프 활공
	_seg("glide")
	var sea := Vector3(-26, 0.5, 78)
	await _tap("jump", 0.15)
	await _wait(0.15)
	await _tap("jump", 0.1)
	var glide_t := 0.0
	var glide_frames := 0
	while glide_t < 3.5 and player.state != "swim":
		_steer(sea)
		await get_tree().physics_frame
		if player.state == "glide": glide_frames += 1
		glide_t += get_physics_process_delta_time()
	_stop_move()
	print("PLAYTEST_LOG glide_physics_frames=", glide_frames, " wings_visible=", player.wings.visible)
	if player.gliding:
		await _tap("jump", 0.1)
	await _wait(0.6)

	# (7) 바다 수영 + 잠수
	_seg("swim_dive")
	await _walk_to(func(): return sea if player.state != "swim" and player.state != "dive" else null, 1.0, 22.0, true)
	var swim_t := 0.0
	while swim_t < 4.0:
		_steer(sea + Vector3(-6, 0, 6))
		await get_tree().physics_frame
		swim_t += get_physics_process_delta_time()
	_stop_move()
	_hold("dive")
	var dive_t := 0.0
	while dive_t < 6.0:
		_steer(sea + Vector3(-10, 0, 10))
		await get_tree().physics_frame
		dive_t += get_physics_process_delta_time()
	_stop_move()
	_release("dive")
	_hold("jump")
	await _wait(2.5)
	_release("jump")
	print("PLAYTEST_LOG after_surface state=", player.state, " pos=", player.global_position, " water_areas=", player.water_areas.size(), " vy=", player.velocity.y)

	# (8) 월드맵
	_seg("world_map")
	await _tap("world_map")
	await _wait(3.5)
	await _tap("world_map")
	await _wait(0.8)

	_release_all()
	print("PLAYTEST_LOG kills/inventory=", Inventory.get_items(), " state=", player.state, " pos=", player.global_position, " t=%.1f" % _now())
	print("PLAYTEST_DONE")
	get_tree().quit()
