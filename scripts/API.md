# Gameplay API

Godot 4.7.2. 모든 경로는 `res://` 기준. UI·오디오는 `GameEvents`만 구독한다. 상태 초기 표시 시 아래 autoload/player 조회 API를 사용한다. 이벤트는 동기적으로 전달되며 초기 플레이어 이벤트는 `_ready()`에서 발생한다.

## GameEvents signals

```gdscript
player_health_changed(current: int, maximum: int)
stamina_changed(current: float, maximum: float)
player_state_changed(state: String)
player_underwater_changed(underwater: bool)
player_damaged(amount: int)
player_died()
attack_performed()
enemy_defeated(enemy_id: String)
item_added(item_id: String, amount: int)
inventory_changed(items: Dictionary)
quest_started(quest_id: String)
quest_progress(quest_id: String, current: int, target: int)
quest_completed(quest_id: String)
dialogue_started(dialogue_id: String)
dialogue_line(speaker: String, text: String)
dialogue_ended()
interact_prompt_changed(text: String, visible: bool)
footstep(surface: String)
```

`stamina_changed`는 향후 호환용 선언이며 현재 스태미나 제한·발행은 없다. `inventory_changed`는 `{item_id: count}` 사본. 퀘스트 이벤트에는 리소스 ID를 전달하며 이름은 `QuestManager.get_quest_data(id).title`로 조회한다. `dialogue_line`에는 표시할 한 줄 전체를 전달한다. 프롬프트 문자열에는 E 키 안내가 포함된다. `footstep`의 현재 surface는 `grass`. 적 ID는 `slime`. 사망 이벤트 후 플레이어는 시작 지점에 즉시 부활한다.

## Autoload methods / query properties

- `Inventory.add_item(item_id: String, amount: int = 1) -> void`: 알려진 아이템만 추가; 0 이하 무시.
- `Inventory.remove_item(item_id: String, amount: int = 1) -> bool`: 수량 부족 시 변경 없이 false.
- `Inventory.get_count(item_id: String) -> int`
- `Inventory.get_items() -> Dictionary`: 사본 반환.
- `Inventory.get_item_data(item_id: String) -> ItemData`: 없는 ID는 null.
- `QuestManager.start_quest(id: String) -> bool`: 활성/완료 퀘스트는 재시작하지 않음. 기존 보유 채집품도 반영.
- `QuestManager.get_quest_data(id: String) -> QuestData`: 없는 ID는 null.
- `QuestManager.get_progress(id: String) -> int`
- `QuestManager.is_completed(id: String) -> bool`
- `QuestManager.active: Dictionary`, `completed: Dictionary`: `{quest_id: progress}` 읽기용.
- `DialogueManager.start_dialogue(data: DialogueData) -> void`: 첫 줄 발행 및 연계 퀘스트 시작.
- `DialogueManager.advance() -> void`: 다음 줄, 마지막 다음에는 종료.
- `DialogueManager.end_dialogue() -> void`
- `DialogueManager.is_active() -> bool`
- `DialogueManager.can_start_interaction() -> bool`: 활성 대화 및 종료 tick과 바로 다음 physics tick에는 false. 종료한 E 입력의 재소비를 막는다.
- `DialogueManager.ended_physics_frame: int`: 마지막 대화 종료 physics frame(읽기용).
- `DialogueManager.current: DialogueData`, `line_index: int`: 읽기용.

대화 시작은 player의 E 상호작용이 담당한다. 활성 대화의 E 입력과 `DialogueManager.advance()` 호출은 UI만 담당한다(타자기 효과 완료 또는 다음 줄 진행). player는 활성 대화 중 advance를 호출하지 않는다. UI가 없는 sandbox에서는 활성 대화를 API로 진행/종료해야 한다. 이동·공격은 대화 중 정지한다. 채집은 E 상호작용, 자동 획득하지 않는다. 완료 보상은 자동으로 인벤토리에 들어간다. 저장/불러오기는 이번 범위에 없다.

## Scenes and exports

`scenes/characters/player.tscn`: CharacterBody3D, group `player`, layer bit 2/mask 1, 원점 발. `Model` 아래 선택적 GLB와 `GliderWings`. 카메라는 별도 `camera_rig.tscn` 인스턴스를 배치한다.

| Export | Type | Default |
|---|---|---|
| walk_speed | float | 3.5 |
| sprint_speed | float | 5.8 |
| jump_speed | float | 6.5 |
| glide_speed | float | 5.0 |
| swim_speed | float | 2.6 |
| max_health | int | 100 |
| attack_damage | int | 25 |
| interaction_radius | float | 2.0 |

읽기용: `health: int`, `state: String`, `underwater: bool`, `gliding: bool`, `facing: Vector3`. 메서드: `attack()`, `take_damage(amount: int, knockback: Vector3 = Vector3.ZERO)`, `respawn()`. 로컬 signal `underwater_changed(underwater: bool)`도 제공한다. 피격 무적 1초, 공격 주기 0.45초/유효시간 0.18초, 공격당 적 1회만 피해. 공격 시작 위치는 플레이어 회전과 무관하게 월드 facing 방향 0.7m 앞/높이 0.5m이다. AttackHitbox는 layer 6(bit 32), mask enemy(bit 4).

상태 목록: `idle`, `walk`(sprint 포함), `jump`(낙하 포함), `glide`, `swim`, `dive`. 지상 jump→공중 jump로 glide, 공중 재입력/착지/물 진입으로 해제. 수면에 자동 부유, C를 누르면 하강, jump를 누르면 상승. 수면보다 발 위치가 0.8m 아래면 dive/underwater.

`camera_rig.tscn`: `target_path: NodePath`(비우면 player 그룹 자동 탐색), `follow_speed: float = 6`, `distance: float = 9.5`, `pitch_degrees: float = -55`. glide 거리 1.25배, dive는 플레이어 진행 방향 뒤 4.5m/높이 1.8m로 보간.

`slime.tscn`: enemy 그룹, layer 3(bit 4), mask world/player. `max_health: int = 50`, `detection_radius: float = 7`, `hop_speed: float = 2.5`, `damage: int = 12`, `drop_item: String = "slime_jelly"`. `take_damage(amount: int, knockback: Vector3 = Vector3.ZERO)` 지원. 사망 시 수집 가능한 pickup 생성, `enemy_defeated("slime")` 발행.

`npc.tscn`: Area3D, interactable 그룹/layer 5(bit 16). `prompt: String = "모루와 대화"`, `dialogue: DialogueData`(gardener 기본). `interact(player: Node = null)`.

`pickup_flower.tscn`: Area3D, interactable 그룹/layer 5(bit 16). `item_id: String = "wildflower"`, `amount: int = 1`, `prompt: String = "야생화 채집"`. `interact(player: Node = null)`; 1회 획득 후 제거.

물 계약: 그룹 `water_volume`, Area3D layer 4(bit 8), monitoring/monitorable 활성, CollisionShape3D 필수. `surface_y` 메타데이터(float, **월드 Y 좌표**) 권장; 미지정 시 Area3D의 global_position.y가 수면. 플레이어 센서가 해당 영역과 겹치면 수영한다. 겹치는 물은 먼저 진입한 영역 수면 사용. 바다는 충분한 깊이와 별도 seabed 충돌을 제공해야 한다.

## Resources and samples

- `ItemData`: `id`, `display_name`, `description`, `icon_path`: String. `icon_path`는 선택적 경로로 UI에서 ResourceLoader.exists 확인 후 사용.
- `QuestData`: `id`, `title`, `objective_type`(`collect`/`defeat`), `objective_id`, `reward_item`: String; `target`, `reward_amount`: int.
- `DialogueData`: `id`, `speaker`: String; `lines`, `quest_ids`: PackedStringArray.
- Items: `scripts/data/items/{wildflower,slime_jelly,shell,feather,sea_pearl}.tres`.
- Quests: `scripts/data/quests/flowers.tres`(야생화 5), `slimes.tres`(슬라임 3), 각각 깃털 1개 보상.
- Dialogue: `scripts/data/dialogues/gardener.tres`(2줄, 두 퀘스트 부여).

```gdscript
func _ready() -> void:
    GameEvents.player_health_changed.connect(update_health)
    GameEvents.dialogue_line.connect(show_line)
    GameEvents.dialogue_ended.connect(hide_dialogue)
    GameEvents.inventory_changed.connect(refresh_inventory)
```

독립 데모: `godot --headless --quit-after 120 res://scenes/characters/sandbox.tscn`. 시각 실행은 `--headless` 생략. 임시 자체 검증: `godot --headless --script res://scripts/characters/self_check.gd`. sandbox는 잔디 평지, 오른쪽 물/바닥, 슬라임·NPC 각 1개, 꽃 6개를 제공한다.

## Character rendering and procedural pose

`CharacterVisuals.asset()` recursively overrides every imported MeshInstance3D with the shared toon shader (`albedo = Color.WHITE`, `rim_strength = 0.25`), preserving GLB vertex colors. Primitive helpers use the same shader with a colored albedo. Player parts `Head`, `Body`, `LeftArm`, `RightArm`, `LeftLeg`, `RightLeg` are discovered recursively; their imported pivot positions and rest rotations are preserved. Walking drives opposing arm/leg swings, idle blends back to rest, and glide spreads both arms. Assets without these optional part names retain whole-model bob/squash. Gardener NPC uses an original primitive silhouette with a green work dress, cream apron, leafy cap, and side basket.

플레이어 루트는 `PROCESS_MODE_PAUSABLE`을 명시한다. 자동 플레이 등 ALWAYS 상위 노드 아래에서도 지도/인벤토리 일시정지 중 이동과 중력이 진행되지 않는다.

대화 입력 회귀 확인: `godot --headless --script res://scripts/characters/dialogue_input_check.gd`. 실제 UI 입력 검증에는 `Input.parse_input_event(InputEventAction)`을 사용한다. `Input.action_press()`는 폴링 상태만 갱신하므로 `_unhandled_input`을 사용하는 대화 UI에 이벤트를 전달하지 않는다. 검증 스크립트는 폴링 입력으로 줄이 바뀌지 않는지와 실제 이벤트로 마지막 줄을 닫은 뒤 재시작하지 않는지를 함께 확인한다.
