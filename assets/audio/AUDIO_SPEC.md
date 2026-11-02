# 오디오 사양 — Island City

이 문서는 `assets/audio/`의 사운드 목록·트리거·믹싱 규칙을 정의합니다. 음원은 이 프로젝트에서 **AI 생성하지 않습니다**. 현재 파일은 ffmpeg로 합성한 합성 플레이스홀더이며, 최종 음원은 아래 "최종 음원 방향" 설명에 맞춰 같은 파일명으로 교체합니다.

- 버스 레이아웃: `assets/audio/default_bus_layout.tres` (`project.godot`의 `audio/buses/default_bus_layout`에 등록됨)
- 매니저: `assets/audio/audio_manager.tscn` + `audio_manager.gd` (autoload `AudioManager`)
- 플레이스홀더: `assets/audio/placeholder/*.ogg`
- id→음원 매핑의 단일 소스: `audio_manager.gd`의 `const SOUNDS`

## 1. 버스 구조

```
Master (0 dB)
├── BGM (-2 dB)
├── Ambient (-4 dB)
└── SFX (0 dB)
    └── UI (-3 dB)
```

| 버스 | 부모 | 기본 볼륨 | 용도 |
|---|---|---|---|
| Master | — | 0 dB | 최종 출력 |
| BGM | Master | -2 dB | 지역별 배경음 |
| SFX | Master | 0 dB | 월드 효과음(발소리·전투·아이템) |
| UI | SFX | -3 dB | UI·대화 효과음 |
| Ambient | Master | -4 dB | 바람·파도·수영·활공 루프 |

`AudioManager.set_bus_volume(bus, linear)`는 0.0~1.0 선형 값을 dB로 변환해 적용합니다. 0.0은 -80 dB(무음)로 처리합니다.

## 2. 사운드 목록

`루프`가 켜진 음원은 `.ogg.import`의 `loop=true`로 임포트되어 있습니다. 매니저도 로드 시 `AudioStreamOggVorbis.loop`를 한 번 더 보정합니다.

| id | 버스 | 루프 | 기본 볼륨 | 트리거 (GameEvents signal 또는 상황) | 배치 | 최종 음원 방향 |
|---|---|---|---|---|---|---|
| `wind_light` | Ambient | 예 | -12 dB | 야외 기본 상태, `weather_wind_changed(1)` | 2D | 30초 심리스 루프. 낮은 핑크 노이즈 바람, 200~2 kHz 대역, 잎·풀 흔들림의 미세한 변조. 휘파람 같은 톤 없이 부드럽게. |
| `wind_strong` | Ambient | 예 | -10 dB | 고지대·폭풍, `weather_wind_changed(2)` | 2D | 30초 루프. 핑크+브라운 노이즈를 겹친 넓은 대역, 0.2 Hz의 완만한 돌풍 스웰. 낮은 웅웅거림 포함. |
| `waves_shore` | Ambient | 예 | -10 dB | 해변 근처, `shore_proximity_changed(true, position)` | 3D, 최대 45 m | 30초 루프. 0.1 Hz로 밀려오는 파도, 거품 쉬익, 원거리 저역 럼블. 청취자가 해안선에 가까울수록 커지게. |
| `glide_wind` | Ambient | 예 | -10 dB | 활공 시작/종료, `player_glide_started` / `player_glide_ended` | 2D | 8초 루프. 300~3 kHz 협대역 바람, 0.5 Hz의 빠른 날개 펄럭임 변조. 공중 활공의 속도감. |
| `swim_loop` | Ambient | 예 | -12 dB | 수영 중(수면), `player_entered_water` / `player_exited_water` | 2D | 8초 루프. 물을 젓는 저역 출렁임과 잔거품. 물 밖으로 나오면 즉시 정지. |
| `underwater_loop` | Ambient | 예 | -10 dB | 잠수·수중, `player_submerged_changed(true)` | 2D | 12초 루프. 500 Hz 이하로 먹먹한 저역, 55 Hz 험, 0.25 Hz 느린 맥동. 수면 위 소리는 들리지 않게. |
| `footstep_grass` | SFX | 아니오 | -6 dB | 발걸음, `player_footstep(surface="grass", position)` | 3D, 14 m | 0.18초. 500 Hz~5 kHz 대역의 짧은 풀 rustle. 단단한 임팩트 없이 바스락. |
| `footstep_sand` | SFX | 아니오 | -6 dB | 발걸음, `player_footstep(surface="sand", position)` | 3D, 14 m | 0.22초. 250 Hz~2.6 kHz의 부드러운 모래 crunch. 풀보다 낮고 둔탁. |
| `footstep_dirt` | SFX | 아니오 | -6 dB | 발걸음, `player_footstep(surface="dirt", position)` | 3D, 14 m | 0.16초. 90 Hz 썸프 + 1.8 kHz 이하 흙 부스러짐. 짧고 건조. |
| `footstep_wood` | SFX | 아니오 | -6 dB | 발걸음, `player_footstep(surface="wood", position)` | 3D, 16 m | 0.14초. 180 Hz 공명 + 700 Hz~3.8 kHz 판자 울림. 선착장·마루 전용. |
| `water_enter` | SFX | 아니오 | -4 dB | 물 진입, `player_entered_water(position)` | 3D, 26 m | 0.6초. 250 Hz~6.5 kHz 스플래시 + 70 Hz 저역 임팩트. 얕은 물과 깊은 물 모두 어울리게. |
| `attack_swing` | SFX | 아니오 | -6 dB | 공격 시작, `attack_started(position)` | 3D, 20 m | 0.3초. 600 Hz~5 kHz 휘두름 whoosh. 날카롭지만 금속성은 아님. |
| `player_hit` | SFX | 아니오 | -4 dB | 플레이어 피격, `player_damaged(amount, position)` | 3D, 20 m | 0.3초. 110 Hz 둔탁한 타격 + 2.2 kHz 이하 노이즈. 아프지만 잔인하지 않게. |
| `slime_hit` | SFX | 아니오 | -5 dB | 슬라임 피격, `enemy_hit(enemy_id, position)` | 3D, 22 m | 0.2초. 400 Hz~2.2 kHz 젤리 같은 squish + 18 Hz 비브라토. |
| `slime_defeat` | SFX | 아니오 | -4 dB | 슬라임 처치, `enemy_defeated(enemy_id, position)` | 3D, 24 m | 0.6초. 520→240 Hz로 내려가는 squelch + 노이즈. 귀엽게 사라지는 느낌. |
| `item_pickup` | SFX | 아니오 | -5 dB | 아이템 획득, `item_collected(item_id, position)` | 3D, 16 m | 0.36초. 880→1318.5 Hz 두 음 블립. 밝고 짧게, UI음보다 살짝 두껍게. |
| `ui_open` | UI | 아니오 | -2 dB | UI 열기, `ui_opened(ui_name)` | 2D | 0.16초. 660→990 Hz 상승 블립. 패널이 열리는 가벼운 느낌. |
| `ui_close` | UI | 아니오 | -2 dB | UI 닫기, `ui_closed(ui_name)` | 2D | 0.16초. 990→660 Hz 하강 블립. |
| `ui_select` | UI | 아니오 | -2 dB | 선택·확정, `ui_selection_changed` 또는 `ui_confirm` | 2D | 0.07초. 1046.5 Hz 단음 틱. 반복 재생에 피로하지 않게. |
| `dialogue_advance` | UI | 아니오 | -2 dB | 대사 넘김, `dialogue_advanced` | 2D | 0.05초. 587.33 Hz 아주 짧은 틱. `ui_select`보다 작고 부드럽게. |
| `bgm_meadow` | BGM | 예 | -6 dB | 초원 지역, `region_changed("meadow")` | 2D | 30~60초 루프. C major add9 패드, 0.5 Hz 느린 맥동. 밝고 평화로운 오프닝. 최종은 목관·현악 중심의 따뜻한 편곡. |
| `bgm_beach` | BGM | 예 | -6 dB | 해변 지역, `region_changed("beach")` | 2D | 30~60초 루프. Fmaj7 패드, 0.25 Hz 맥동. 넓고 한가로운 바다 공기. 최종은 가벼운 기타·마림바. |
| `bgm_village` | BGM | 예 | -6 dB | 마을 지역, `region_changed("village")` | 2D | 30~60초 루프. G major 패드, 0.5 Hz 맥동. 생활감 있는 따뜻함. 최종은 아코디언·플루트. |
| `bgm_underwater` | BGM | 예 | -6 dB | 수중, `player_submerged_changed(true)` | 2D | 30~60초 루프. A minor 패드, 750 Hz 로우패스, 0.125 Hz 맥동. 먹먹하고 몽환적. 최종은 낮은 첼로·신스 패드. |

## 3. GameEvents → AudioManager 연결표

gameplay의 `GameEvents` signal은 아직 스텁입니다. 아래 signal 이름은 **제안**이며, gameplay가 확정하면 orchestrator가 이 표대로 연결합니다. AudioManager는 signal을 직접 구독하지 않습니다.

| GameEvents signal (제안) | 호출 | 비고 |
|---|---|---|
| `player_footstep(surface: String, position: Vector3)` | `AudioManager.play_sfx("footstep_" + surface, position)` | `surface` ∈ `grass`, `sand`, `dirt`, `wood`. 발소리 간격·속도는 gameplay가 제어. |
| `player_glide_started` | `AudioManager.set_ambient("glide_wind", true)` | |
| `player_glide_ended` | `AudioManager.set_ambient("glide_wind", false)` | |
| `player_entered_water(position: Vector3)` | `AudioManager.play_sfx("water_enter", position)`<br>`AudioManager.set_ambient("swim_loop", true)` | |
| `player_exited_water` | `AudioManager.set_ambient("swim_loop", false)`<br>`AudioManager.set_ambient("underwater_loop", false)` | |
| `player_submerged_changed(submerged: bool)` | `AudioManager.set_ambient("underwater_loop", submerged)` | 잠수 시 BGM 전환은 4장 참조. |
| `attack_started(position: Vector3)` | `AudioManager.play_sfx("attack_swing", position)` | |
| `player_damaged(amount: int, position: Vector3)` | `AudioManager.play_sfx("player_hit", position)` | |
| `enemy_hit(enemy_id: String, position: Vector3)` | `AudioManager.play_sfx("slime_hit", position)` | 현재 적은 슬라임 1종. 적 추가 시 id 매핑 확장. |
| `enemy_defeated(enemy_id: String, position: Vector3)` | `AudioManager.play_sfx("slime_defeat", position)` | |
| `item_collected(item_id: String, position: Vector3)` | `AudioManager.play_sfx("item_pickup", position)` | |
| `ui_opened(ui_name: String)` | `AudioManager.play_ui("ui_open")` | |
| `ui_closed(ui_name: String)` | `AudioManager.play_ui("ui_close")` | |
| `ui_selection_changed` / `ui_confirm` | `AudioManager.play_ui("ui_select")` | 포커스 이동과 확정 모두 같은 틱 사용. |
| `dialogue_advanced` | `AudioManager.play_ui("dialogue_advance")` | |
| `region_changed(region: String)` | `AudioManager.play_bgm(region)` | `region` ∈ `meadow`, `beach`, `village`, `underwater`. |
| `player_submerged_changed(true)` | `AudioManager.play_bgm("underwater", 0.6)` | 수중 진입은 빠르게. |
| `player_submerged_changed(false)` | `AudioManager.play_bgm(현재_지역, 1.2)` | 수면 복귀는 조금 느리게. 현재 지역은 gameplay 또는 world가 보관. |
| `weather_wind_changed(level: int)` | `AudioManager.set_ambient("wind_light", level == 1)`<br>`AudioManager.set_ambient("wind_strong", level == 2)` | 두 루프를 동시에 켜지 않는다. |
| `shore_proximity_changed(near: bool, position: Vector3)` | `AudioManager.set_ambient("waves_shore", near, position)` | world가 해안 근접 여부를 판정해 전달. |

## 4. BGM 크로스페이드 규칙

- 기본 페이드: **1.5초**. `play_bgm(region, fade_sec)`의 두 번째 인자로 조정한다.
- 같은 지역이 이미 재생 중이면 **재시작하지 않는다**(no-op).
- 페이드 방식: 새 트랙은 -80 dB에서 시작해 `fade_sec` 동안 목표 볼륨으로 올라가고, 이전 트랙은 같은 시간 동안 -80 dB로 내려간 뒤 정지한다.
- 페이드 도중 다른 지역 요청이 오면 진행 중인 트윈을 모두 죽이고, 현재 재생 중인 플레이어를 outgoing으로 삼아 새 크로스페이드를 시작한다.
- 권장 페이드 길이:
  - 지역 간 이동: 1.5초
  - 수중 진입: 0.6초
  - 수면 복귀: 1.2초
- Ambient 토글(`set_ambient`)은 상태 기반이므로 즉시 켜고 끈다(페이드 없음). 음량 조절이 필요하면 `set_bus_volume("Ambient", linear)`를 사용한다.

## 5. 공개 API

```gdscript
AudioManager.play_sfx(id: String, position = null)
AudioManager.play_ui(id: String)
AudioManager.play_bgm(region: String, fade_sec := 1.5)
AudioManager.set_ambient(id: String, enabled: bool, position = null)
AudioManager.set_bus_volume(bus: String, linear: float)
```

| API | 동작 |
|---|---|
| `play_sfx(id, position)` | `position`이 `Vector3`이면 `AudioStreamPlayer3D`(거리 감쇠), `null`이면 `AudioStreamPlayer`(2D)로 재생. SFX 풀 12+12개를 재사용하고, 모두 사용 중이면 오래된 것부터 재할당. |
| `play_ui(id)` | UI 버스의 2D 풀(4개)에서 재생. |
| `play_bgm(region, fade_sec)` | `bgm_<region>`을 찾아 크로스페이드. BGM 플레이어 2개를 번갈아 사용. |
| `set_ambient(id, enabled, position)` | Ambient 루프를 켜고 끈다. 3번째 인자는 선택 사항이며, `waves_shore` 같은 3D 앰비언트의 위치를 지정할 때만 사용한다. |
| `set_bus_volume(bus, linear)` | 버스 볼륨을 선형 0~1로 설정. 없는 버스는 경고 1회. |

- 알 수 없는 id, 종류가 다른 id, 없는 음원 파일은 `push_warning`을 **id당 1회**만 남기고 무시한다.
- `id → 파일/버스/루프/볼륨/감쇠 거리` 매핑은 `audio_manager.gd`의 `const SOUNDS` 한 곳에만 존재한다.
- 풀 크기: 2D SFX 12, 3D SFX 12, UI 4.

## 6. 플레이스홀더 음원

모두 `assets/audio/placeholder/`에 있으며, ffmpeg의 Vorbis 인코더로 합성했다(44.1 kHz, 스테레오, 96 kbps). AI 음원 생성은 사용하지 않았다.

| 파일 | 길이 | 합성 방법 |
|---|---|---|
| `wind_light.ogg` | 30 s | 핑크 노이즈 + 1.4 kHz 로우패스 + 0.1 Hz 트레몰로 |
| `wind_strong.ogg` | 30 s | 핑크+브라운 노이즈 레이어 + 0.2 Hz 트레몰로 |
| `waves_shore.ogg` | 30 s | 브라운+핑크 노이즈 2레이어 + 0.1 Hz 스웰 |
| `glide_wind.ogg` | 8 s | 250 Hz~3 kHz 핑크 노이즈 + 0.5 Hz 트레몰로 |
| `swim_loop.ogg` | 8 s | 저역 브라운 노이즈 + 고역 물소리 레이어 |
| `underwater_loop.ogg` | 12 s | 500 Hz 로우패스 브라운 노이즈 + 55 Hz 사인 험 |
| `footstep_*.ogg` | 0.14~0.22 s | 대역 필터링 노이즈 버스트(+ 흙/나무는 저역 사인 임팩트) |
| `water_enter.ogg` | 0.6 s | 노이즈 스플래시 + 70 Hz 임팩트 |
| `attack_swing.ogg` | 0.3 s | 600 Hz~5 kHz 노이즈 whoosh |
| `player_hit.ogg` | 0.3 s | 110 Hz 사인 + 저역 노이즈 |
| `slime_hit.ogg` | 0.2 s | 320 Hz 비브라토 사인 + 노이즈 |
| `slime_defeat.ogg` | 0.6 s | 520→240 Hz 하강 chirp + 노이즈 |
| `item_pickup.ogg` | 0.36 s | 880 Hz → 1318.5 Hz 두 음 |
| `ui_*.ogg`, `dialogue_advance.ogg` | 0.05~0.16 s | 사인 블립(상승/하강/단음) |
| `bgm_*.ogg` | 32 s | 5음 사인 패드 + 저역 통과 + 느린 트레몰로 |

- BGM은 32초 길이에 대해 정수 사이클이 되도록 주파수·트레몰로 주기를 맞춰 루프 경계의 클릭을 줄였다. 지역별 조성과 맥동 주기는 2장 표 참조.
- 루프 음원 10종은 `.ogg.import`의 `loop=true`로 설정되어 있다.
- 최종 음원 교체 방법: 같은 파일명으로 덮어쓰고 `godot --headless --import --quit`를 실행한다. 파일명을 바꾸려면 `audio_manager.gd`의 `SOUNDS` 경로도 함께 수정한다.
- 최종 음원도 루프 음원이면 교체 후 `.ogg.import`의 `loop=true`를 유지한다.

## 7. 검증

```bash
godot --headless --import --quit
godot --headless --quit-after 120 res://scenes/main.tscn
```

`AudioManager`는 `project.godot` autoload로 등록되어 있으므로 main 씬 로드 시 함께 초기화된다. 프로젝트에 별도 오디오 리스너가 없어도 API 호출 자체는 오류 없이 동작한다.
