# 팀 계약 — Island City (Godot 4.7, 데스크톱, GDScript)

모든 역할이 공유하는 경로·규약입니다. 역할 간 연결이 이 문서의 경로와 이름에 의존하므로, 바꿔야 하면 직접 바꾸지 말고 orchestrator에 보고합니다. 스타일 기준은 `docs/art-style-prompts.md`입니다.

## 1. 범위와 원칙
- `wind.mp4`의 **렌더링 스타일·색 언어**만 따릅니다. 영상 속 게임의 캐릭터·UI·레벨 배치는 복제하지 않는 오리지널 게임입니다.
- 2D 이미지 에셋은 **codex CLI의 image_gen(gpt-image-2)** 으로 생성합니다(`docs/art-style-prompts.md` 6장). 3D는 Blender 스크립트/Godot 프리미티브로 절차적 로우폴리 제작, 오디오는 사양 + 합성 플레이스홀더입니다.
- `project.godot`, `scenes/main.tscn`, `addons/`는 orchestrator 소유입니다. autoload·입력 액션·레이어 추가가 필요하면 보고서에 적어 요청합니다.

## 2. 폴더 소유

| 폴더 | 역할 |
|---|---|
| `scripts/`, `scenes/characters/` | gameplay |
| `shaders/`, `scenes/world/` | world |
| `assets/models/`, `assets/textures/`, `docs/style-reference/` | art |
| `ui/` | ui |
| `assets/audio/` | audio |
| `tests/` | qa |
| `project.godot`, `scenes/main.tscn`, `addons/`, `docs/*.md` | orchestrator |

## 3. 좌표·스케일
- 1 unit = 1 m, Y-up, 캐릭터 정면 = **-Z**(Godot 기본).
- 플레이어 키 약 **1.0 m**(치비 2.5등신), 원점은 발바닥 중앙.
- 해수면 Y = **0.0**. 육지는 Y > 0, 물속은 Y < 0.

## 4. 입력 액션 (project.godot에 정의됨)
`move_forward`(W) `move_back`(S) `move_left`(A) `move_right`(D) `jump`(Space, 공중에서 다시 누르면 활공) `dive`(C, 수중 하강) `sprint`(Shift) `attack`(J/좌클릭) `interact`(E) `inventory`(I) `world_map`(M) `pause`(Esc)

## 4.1 Autoload (project.godot에 등록됨, 스텁 존재)

| 이름 | 경로 | 소유 | 역할 |
|---|---|---|---|
| `GameEvents` | `res://scripts/autoload/game_events.gd` | gameplay | 전역 signal 버스. ui·audio·world는 여기 signal만 구독 |
| `Inventory` | `res://scripts/autoload/inventory.gd` | gameplay | 아이템 보관·추가·제거 |
| `QuestManager` | `res://scripts/autoload/quest_manager.gd` | gameplay | 퀘스트 진행 |
| `DialogueManager` | `res://scripts/autoload/dialogue_manager.gd` | gameplay | 대화 진행 |
| `AudioManager` | `res://assets/audio/audio_manager.tscn` | audio | BGM/SFX/Ambient 재생 API |

스텁 파일은 소유 역할이 자유롭게 덮어씁니다. 경로와 이름만 유지합니다.

## 5. 물리 레이어

| 번호 | 이름 | 용도 |
|---|---|---|
| 1 | world | 지형·건물·바위 충돌 |
| 2 | player | 플레이어 바디 |
| 3 | enemy | 적 바디 |
| 4 | water | 물 영역 `Area3D` (수영 판정) |
| 5 | interactable | NPC·채집물 `Area3D` |
| 6 | hitbox | 공격 판정 |

## 6. 노드 그룹
- `player` — 플레이어 루트 노드
- `water_volume` — 수영 판정용 물 `Area3D` (world가 배치, gameplay가 감지)
- `interactable` — 상호작용 가능 대상
- `enemy` — 적

## 7. 에셋 경로 계약 (art가 생성, 다른 역할이 참조)
3D 모델은 `.glb`, 색은 **버텍스 컬러 또는 단색 base color**로 넣고 셀 셰이딩은 world의 셰이더가 담당합니다.

| 경로 | 내용 |
|---|---|
| `assets/models/characters/player.glb` | 오리지널 치비 탐험가, 1.0 m, 원점 발, -Z 정면 |
| `assets/models/gear/glider_wings.glb` | 흰-분홍 깃털 활공 날개 (등에 부착) |
| `assets/models/nature/tree_round_a.glb`, `tree_round_b.glb` | 둥근 클럼프 캐노피 나무 |
| `assets/models/nature/bush_round.glb` | 둥근 덤불 |
| `assets/models/nature/rock_a.glb`, `rock_b.glb`, `rock_c.glb` | 각진 로우폴리 바위 |
| `assets/models/nature/cattail.glb`, `lilypad.glb`, `seagrass.glb` | 물가·수중 식생 |
| `assets/models/buildings/cottage.glb`, `pier.glb` | 빨간 지붕 흰 벽 오두막, 나무 선착장 |
| `assets/models/creatures/slime.glb` | 오리지널 적 (둥근 젤리형) |
| `assets/textures/terrain/*.png` | 잔디·흙길·모래·해저 텍스처 (codex) |
| `assets/textures/icons/*.png` | 인벤토리 아이콘 512² (codex) |
| `assets/textures/map/world_map.png` | 손그림 월드맵 (codex) |

에셋이 아직 없으면 같은 경로를 기대하는 플레이스홀더(프리미티브 메시)로 진행하고, 보고서에 "교체 대기"로 적습니다.

## 8. 셰이더 계약 (world 제공)
- `shaders/toon.gdshader` — 버텍스 컬러 × `albedo` 유니폼, 2~3단 램프, 그림자를 `#256d4b`~`#2b8277` 쪽으로 보정, 아웃라인 없음.
- 다른 역할은 이 셰이더를 `ShaderMaterial`로 참조만 하고 수정하지 않습니다.

## 9. 씬 조립 (orchestrator)
`scenes/main.tscn` = `scenes/world/island.tscn` + `scenes/characters/player.tscn` 인스턴스 + `ui/hud.tscn` + 오디오 매니저(autoload).

```
world: island.tscn ─┐
gameplay: player.tscn ─┼→ orchestrator: main.tscn → qa: 테스트·자동 플레이 → orchestrator: 녹화·비교
ui: hud.tscn ─────────┤
audio: AudioManager ──┘
```

## 10. 검증 명령
```
godot --headless --import --quit                 # 임포트 오류 확인
godot --headless --quit-after 120 res://<씬>.tscn  # 씬 로드 후 120프레임 실행
```
각 역할은 끝내기 전에 자기 씬을 위 명령으로 로드해 `ERROR`/`SCRIPT ERROR`가 없는지 확인하고 결과를 보고합니다.
