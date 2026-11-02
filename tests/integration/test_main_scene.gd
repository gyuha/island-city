extends GutTest
## main.tscn 통합 테스트. 각 테스트마다 새로 로드한다.

const MAIN := preload("res://scenes/main.tscn")

var main: Node3D
var player: CharacterBody3D

func before_each() -> void:
	Inventory.items.clear()
	QuestManager.active.clear()
	QuestManager.completed.clear()
	DialogueManager.end_dialogue()
	main = MAIN.instantiate()
	add_child(main)
	player = main.get_node("Player")
	await wait_physics_frames(30)  # main._place_entities가 끝날 때까지

func after_each() -> void:
	for a in ["move_forward", "jump", "dive", "attack", "interact", "sprint"]:
		Input.action_release(a)
	main.queue_free()
	await wait_process_frames(3)

func _group(g: String) -> Array:
	return get_tree().get_nodes_in_group(g).filter(func(n): return main.is_ancestor_of(n))

func _tap(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await wait_physics_frames(2)
	e = InputEventAction.new()
	e.action = action
	e.pressed = false
	Input.parse_input_event(e)
	await wait_physics_frames(1)

func _teleport(pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.water_areas.clear()

# ── 로드·기본 상태 ────────────────────────────────────────

func test_runs_frames_without_error() -> void:
	await wait_process_frames(120)
	assert_true(is_instance_valid(main))
	pass_test("120프레임 실행 완료")

func test_player_above_ground() -> void:
	await wait_physics_frames(60)
	assert_gt(player.global_position.y, 0.0, "플레이어 Y>0")
	var q := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP, player.global_position + Vector3.DOWN * 5.0, 1)
	var hit := main.get_world_3d().direct_space_state.intersect_ray(q)
	assert_false(hit.is_empty(), "발 아래 지면 존재")
	if not hit.is_empty():
		assert_lt(absf(player.global_position.y - hit.position.y), 0.3, "지면 위에 서 있음")
	assert_true(player.is_on_floor())

func test_entity_counts_and_heights() -> void:
	var npcs := _group("interactable").filter(func(n): return n.get_script() == load("res://scripts/characters/npc.gd"))
	var flowers := _group("interactable").filter(func(n): return n.get_script() == load("res://scripts/characters/pickup.gd"))
	var slimes := _group("enemy")
	assert_eq(npcs.size(), 1, "NPC 1")
	assert_eq(flowers.size(), 7, "꽃 7")
	assert_eq(slimes.size(), 3, "슬라임 3")
	for n in npcs + flowers + slimes:
		assert_gt(n.global_position.y, 0.5, "%s Y>0.5" % n.name)

func test_water_volumes_surface_zero() -> void:
	var waters := get_tree().get_nodes_in_group("water_volume")
	assert_gt(waters.size(), 0, "water_volume 존재")
	for w in waters:
		assert_eq(float(w.get_meta("surface_y", -999.0)), 0.0, "surface_y of " + w.name)

# ── 수영·잠수 ───────────────────────────────────────────

func test_swim_in_sea() -> void:
	_teleport(Vector3(-26, 0.5, 78))
	await wait_physics_frames(60)
	assert_false(player.water_areas.is_empty(), "물 영역 감지")
	assert_eq(player.state, "swim")
	assert_false(player.underwater)

func test_dive_sets_underwater() -> void:
	_teleport(Vector3(-26, 0.5, 78))
	await wait_physics_frames(40)
	watch_signals(GameEvents)
	Input.action_press("dive")
	await wait_physics_frames(90)
	Input.action_release("dive")
	assert_true(player.underwater, "player.underwater")
	assert_eq(player.state, "dive")
	assert_signal_emitted_with_parameters(GameEvents, "player_underwater_changed", [true])
	var island: Node3D = main.island
	assert_true(island._underwater_layer.visible, "island 수중 오버레이 표시")
	assert_true(island._env.fog_enabled)
	assert_eq(island._env.fog_light_color, island.FOG_WATER_COLOR)

func test_surfacing_restores_island() -> void:
	_teleport(Vector3(-26, 0.5, 78))
	await wait_physics_frames(30)
	Input.action_press("dive")
	await wait_physics_frames(60)
	Input.action_release("dive")
	assert_true(player.underwater)
	Input.action_press("jump")
	await wait_physics_frames(120)
	Input.action_release("jump")
	assert_false(player.underwater, "다시 수면으로")
	assert_false(main.island._underwater_layer.visible)

# ── 전투·채집·퀘스트 ────────────────────────────────────

func test_slime_attack_death_drop_defeated() -> void:
	await _slime_kill_flow(false)

## 플레이어 회전을 제거한 우회 조건: 히트박스 방향 결함과 무관하게 사망→드롭→이벤트 체인을 검증한다.
func test_slime_kill_chain_with_unrotated_player() -> void:
	await _slime_kill_flow(true)

func _slime_kill_flow(unrotate: bool) -> void:
	if unrotate:
		player.global_basis = Basis.IDENTITY
	var slime: CharacterBody3D = _group("enemy")[0]
	# 간섭 방지: 다른 슬라임은 멀리 치움
	for s in _group("enemy"):
		if s != slime:
			s.global_position += Vector3(0, 0, 500)
	QuestManager.start_quest("slimes")
	watch_signals(GameEvents)
	var pos := slime.global_position
	var pcount_before := get_tree().get_nodes_in_group("interactable").size()
	# 슬라임 바로 앞(-Z 정면 기준 facing)에 서서 공격
	player.global_position = pos + Vector3(0, 0.2, 0.9)
	player.velocity = Vector3.ZERO
	player.facing = Vector3(0, 0, -1)
	var id := slime.get_instance_id()
	for i in 4:
		if not is_instance_valid(instance_from_id(id)) or instance_from_id(id).dead:
			break
		slime.global_position = pos
		slime.velocity = Vector3.ZERO
		player.global_position = pos + Vector3(0, 0.2, 0.9)
		player.facing = Vector3(0, 0, -1)
		player.invulnerability = 5.0
		Input.action_press("attack")
		await wait_physics_frames(3)
		Input.action_release("attack")
		await wait_physics_frames(30)
	assert_signal_emitted_with_parameters(GameEvents, "enemy_defeated", ["slime"])
	assert_eq(QuestManager.get_progress("slimes"), 1, "defeat 퀘스트 진행")
	var drops := _group("interactable").filter(func(n): return n.get("item_id") == "slime_jelly")
	assert_eq(drops.size(), 1, "젤리 드롭 생성")
	assert_eq(_group("enemy").size(), 2)
	if drops.size() == 1:
		player.global_position = drops[0].global_position
		await wait_physics_frames(3)
		await _tap("interact")
		assert_eq(Inventory.get_count("slime_jelly"), 1, "드롭 획득")

func test_attack_hitbox_is_in_facing_direction() -> void:
	# main.gd가 spawn transform(회전 포함)을 플레이어에 적용하므로 로컬/월드 좌표 불일치가 드러난다.
	await wait_physics_frames(5)
	player.facing = Vector3(0, 0, -1)
	player.attack()
	var offset: Vector3 = player.hitbox.global_position - player.global_position
	offset.y = 0
	assert_gt(offset.normalized().dot(player.facing), 0.9, "히트박스가 facing 방향 앞에 있어야 함 (offset=%s, player basis.z=%s)" % [offset, player.global_basis.z])

func test_flower_interact_adds_item_and_quest_progress() -> void:
	QuestManager.start_quest("flowers")
	watch_signals(GameEvents)
	var flower: Node3D = _group("interactable").filter(func(n): return n.get_script() == load("res://scripts/characters/pickup.gd"))[0]
	player.global_position = flower.global_position + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	await wait_physics_frames(5)
	await _tap("interact")
	assert_signal_emitted_with_parameters(GameEvents, "item_added", ["wildflower", 1])
	assert_eq(Inventory.get_count("wildflower"), 1)
	assert_eq(QuestManager.get_progress("flowers"), 1)
	await wait_process_frames(2)
	assert_false(is_instance_valid(flower), "채집 후 제거")

func test_npc_dialogue_via_interact() -> void:
	var npc: Node3D = _group("interactable").filter(func(n): return n.get_script() == load("res://scripts/characters/npc.gd"))[0]
	player.global_position = npc.global_position + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	await wait_physics_frames(5)
	await _tap("interact")
	assert_true(DialogueManager.is_active(), "대화 시작")
	assert_true(QuestManager.active.has("flowers"))
	# 대화창이 같은 E 입력에서 같이 진행하는지(이중 진행) 확인용으로 상태를 기록
	var hud := main.get_node("HUD")
	assert_true(hud.dialogue_box.visible, "HUD 대화창 표시")

func test_dialogue_e_press_advances_exactly_one_line() -> void:
	# HUD 대화창(_unhandled_input)과 player(_physics_process)가 둘 다 interact로 advance하는지 확인
	var npc: Node3D = _group("interactable").filter(func(n): return n.get_script() == load("res://scripts/characters/npc.gd"))[0]
	player.global_position = npc.global_position + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	await wait_physics_frames(5)
	await _tap("interact")
	assert_true(DialogueManager.is_active())
	assert_eq(DialogueManager.line_index, 0)
	await wait_seconds(1.2)  # 타자기 효과 종료 대기 (첫 줄 약 0.6초)
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait_physics_frames(4)
	ev = InputEventAction.new()
	ev.action = "interact"
	ev.pressed = false
	Input.parse_input_event(ev)
	await wait_physics_frames(2)
	assert_eq(DialogueManager.line_index, 1, "E 한 번에 정확히 한 줄만 진행")

func test_closing_dialogue_with_e_does_not_restart_it() -> void:
	var npc: Node3D = _group("interactable").filter(func(n): return n.get_script() == load("res://scripts/characters/npc.gd"))[0]
	player.global_position = npc.global_position + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	await wait_physics_frames(5)
	await _tap("interact")
	for i in 2:
		await wait_seconds(1.2)
		await _tap("interact")
	await wait_physics_frames(3)
	assert_false(DialogueManager.is_active(), "마지막 줄에서 E로 닫으면 대화가 재시작되면 안 됨")

# ── HUD ───────────────────────────────────────────────

func test_hud_reacts_to_health() -> void:
	var hud := main.get_node("HUD")
	var label: Label = hud.status_bars.hp_label
	assert_eq(label.text, "100 / 100")
	player.take_damage(30)
	await wait_process_frames(2)
	assert_eq(label.text, "70 / 100")

func test_hud_inventory_toggle_and_pause() -> void:
	var hud := main.get_node("HUD")
	var inv = hud.inventory_panel
	# parse_input_event로 _unhandled_input 경유
	var ev := InputEventAction.new()
	ev.action = "inventory"
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait_process_frames(3)
	assert_true(inv.is_open, "I로 열림")
	assert_true(get_tree().paused, "열리면 일시정지")
	ev = InputEventAction.new()
	ev.action = "inventory"
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait_process_frames(3)
	assert_false(inv.is_open, "I로 닫힘")
	assert_false(get_tree().paused, "닫히면 일시정지 해제")

func test_hud_toast_or_quest_tracker_on_events() -> void:
	var hud := main.get_node("HUD")
	GameEvents.quest_started.emit("flowers")
	GameEvents.item_added.emit("wildflower", 1)
	await wait_process_frames(3)
	assert_true(is_instance_valid(hud))
	pass_test("퀘스트·아이템 이벤트 처리 중 오류 없음")

# ── 오디오 ─────────────────────────────────────────────

func test_audio_manager_calls_no_error() -> void:
	AudioManager.play_bgm("meadow")
	AudioManager.play_bgm("underwater", 0.0)
	AudioManager.play_bgm("meadow", 0.0)
	for id in ["footstep_grass", "attack_swing", "player_hit", "slime_defeat", "item_pickup", "slime_hit", "water_enter"]:
		AudioManager.play_sfx(id)
		AudioManager.play_sfx(id, Vector3(1, 1, 1))
	AudioManager.play_ui("ui_open")
	AudioManager.play_ui("dialogue_advance")
	for id in ["wind_light", "glide_wind", "swim_loop", "underwater_loop"]:
		AudioManager.set_ambient(id, true)
		AudioManager.set_ambient(id, false)
	AudioManager.set_ambient("waves_shore", true, Vector3(-20, 0, 70))
	AudioManager.set_ambient("waves_shore", false)
	AudioManager.set_bus_volume("Master", 1.0)
	await wait_process_frames(5)
	pass_test("AudioManager API 호출 오류 없음")
