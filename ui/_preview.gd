extends Control

@onready var hud: CanvasLayer = $HUD

var _frame: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 가짜 플레이어 노드를 그룹 player에 추가 (월드맵 마커 테스트용)
	var fake_player := Node3D.new()
	fake_player.name = "FakePlayer"
	fake_player.add_to_group("player")
	fake_player.position = Vector3(25.0, 0.0, -15.0)
	fake_player.rotation.y = deg_to_rad(45.0)
	add_child(fake_player)

func _process(_delta: float) -> void:
	_frame += 1

	match _frame:
		1:
			# 1) 기본 HUD: HP/스태미나, 퀘스트 수주, 상호작용 프롬프트
			GameEvents.player_health_changed.emit(100, 100)
			GameEvents.stamina_changed.emit(100.0, 100.0)
			GameEvents.quest_started.emit("flowers")
			GameEvents.interact_prompt_changed.emit("야생화 채집", true)
		4:
			# 2) 피격 플래시 & 체력 감소
			GameEvents.player_health_changed.emit(75, 100)
			GameEvents.player_damaged.emit(25)
		7:
			# 3) 아이템 획득 토스트 & 퀘스트 진행
			GameEvents.item_added.emit("wildflower", 1)
			GameEvents.quest_progress.emit("flowers", 1, 5)
		11:
			# 4) 대화창 시작 및 라인 출력
			GameEvents.interact_prompt_changed.emit("", false)
			GameEvents.dialogue_started.emit("gardener")
			GameEvents.dialogue_line.emit("정원사 모루", "안녕! 섬에 온 걸 환영해. 바람이 참 상쾌하지?")
		19:
			# 5) 대화 종료 후 인벤토리 오픈
			GameEvents.dialogue_ended.emit()
			Inventory.add_item("wildflower", 3)
			Inventory.add_item("slime_jelly", 2)
			Inventory.add_item("feather", 1)
			if hud and hud.inventory_panel:
				hud.inventory_panel.open()
		29:
			# 6) 인벤토리 닫고 월드맵 오픈
			if hud and hud.inventory_panel:
				hud.inventory_panel.close()
			if hud and hud.world_map_panel:
				hud.world_map_panel.open()
