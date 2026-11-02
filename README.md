# Island City

`wind.mp4`의 **렌더링 스타일과 색 언어**를 따라 만든 Godot 4.7 데스크톱 게임입니다(GDScript, Forward+ 렌더러). 영상 속 게임의 캐릭터·UI·레벨 배치는 가져오지 않았고, 캐릭터와 세계는 오리지널입니다.

---

## 1. 레퍼런스 영상

`wind.mp4`는 1080×1920, 62초 세로 쇼츠입니다. 게임 화면은 가운데 1080×1080 영역입니다. 아래 미리보기는 처음 6초를 자막 없이 잘라낸 것이고, 누르면 원본 영상이 열립니다.

[![레퍼런스 영상 미리보기](docs/media/wind_preview.gif)](wind.mp4)

### 레퍼런스 프레임

`docs/style-reference/`에 자막 영역을 잘라낸 프레임 6장이 있습니다. 스타일을 비교할 때 기준으로 쓰는 이미지입니다.

| 호숫가 (1s) | 초원 (7s) | 물가 (14s) |
|---|---|---|
| ![](docs/style-reference/frame_01s.jpg) | ![](docs/style-reference/frame_07s.jpg) | ![](docs/style-reference/frame_14s.jpg) |
| **수중 (24s)** | **수면 (31s)** | **흙길 (50s)** |
| ![](docs/style-reference/frame_24s.jpg) | ![](docs/style-reference/frame_31s.jpg) | ![](docs/style-reference/frame_50s.jpg) |

### 스타일 요약

- 채도 높은 초록 초원과 청록 물이 화면의 대부분을 차지합니다.
- 렌더링은 애니메 셀 셰이딩에 페인터리 텍스처를 섞은 형태이고, 윤곽선이 없습니다.
- **그림자가 회색이나 검정이 아니라 청록·짙은 초록으로 떨어집니다.** 이 룩을 가장 잘 구분하는 특징입니다.
- 자세한 분석, 측정 팔레트, 프롬프트는 [`docs/art-style-prompts.md`](docs/art-style-prompts.md)에 있습니다.

---

## 2. 생성한 컨셉 아트 (codex · gpt-image-2)

2D 이미지는 codex CLI의 `image_gen`(gpt-image-2)으로 만들었습니다. 키아트로 룩을 정한 뒤 캐릭터 시트를 만들었습니다.

| 키아트 1 — 호숫가 활공 | 키아트 2 — 마을과 흙길 |
|---|---|
| ![](docs/style-reference/keyart_01.png) | ![](docs/style-reference/keyart_02.png) |

**플레이어 캐릭터 턴어라운드 (오리지널 디자인)**

![](docs/style-reference/player_sheet.png)

### 게임 텍스처

| 잔디 | 흙길 | 모래 | 해저 |
|---|---|---|---|
| ![](assets/textures/terrain/grass.png) | ![](assets/textures/terrain/dirt_path.png) | ![](assets/textures/terrain/sand.png) | ![](assets/textures/terrain/seabed.png) |

### 아이템 아이콘

| ![](assets/textures/icons/wildflower.png) | ![](assets/textures/icons/feather.png) | ![](assets/textures/icons/fish.png) | ![](assets/textures/icons/seashell.png) | ![](assets/textures/icons/sea_pearl.png) | ![](assets/textures/icons/slime_jelly.png) | ![](assets/textures/icons/wooden_stick.png) |
|---|---|---|---|---|---|---|
| 들꽃 | 깃털 | 물고기 | 조개 | 진주 | 슬라임 젤리 | 나뭇가지 |

### 월드맵

![](assets/textures/map/world_map.png)

---

## 3. 레퍼런스와 게임 화면 비교

모든 비교 이미지는 왼쪽이 레퍼런스, 오른쪽이 Island City입니다. 비교 대상은 캐릭터나 UI가 아니라 **색, 셰이딩, 밀도 같은 룩**입니다.

### 고정 카메라 5곳 (월드만)

| 초원 |
|---|
| ![](docs/comparison/pair_meadow.jpg) |
| **해변** |
| ![](docs/comparison/pair_beach.jpg) |
| **흙길** |
| ![](docs/comparison/pair_path.jpg) |
| **수중** |
| ![](docs/comparison/pair_underwater.jpg) |
| **마을** |
| ![](docs/comparison/pair_village.jpg) |

### 실제 플레이 화면 (캐릭터와 HUD 포함)

| 초원 걷기 |
|---|
| ![](docs/comparison/pair_play_meadow.jpg) |
| **활공** |
| ![](docs/comparison/pair_play_glide.jpg) |
| **수중** |
| ![](docs/comparison/pair_play_underwater.jpg) |

### 현재 일치도

비교해 보면 팔레트는 맞지만 **밀도와 카메라 거리에서 차이가 큽니다.** 판정 근거는 [`docs/comparison/README.md`](docs/comparison/README.md)에 있습니다.

| 항목 | 일치도 | 차이 |
|---|---|---|
| 팔레트 · 청록 그림자 | 높음 | 그림자에 회색·검정 없음 |
| 호수 | 중간 | 깊은 곳의 코발트색과 반짝임이 약함 |
| 건물 | 중간 | 벽이 흰색이 아니라 청회색 |
| 초원 밀도 · 대비 | 낮음 | 덤불·꽃·잔디 결이 부족해 평평한 초록 면에 가까움 |
| 수중 | 낮음 | 갓레이, 산호, 빽빽한 해초가 부족함 |
| 카메라 거리 | 낮음 | 레퍼런스는 캐릭터가 화면 높이의 약 1/4, 게임은 약 1/20 |

---

## 4. 플레이 녹화

자동 플레이 스크립트(`tests/playtest/autoplay.gd`)가 입력 액션을 실제 이벤트로 넣어 직접 플레이한 녹화입니다. 51초, 1280×720, 30fps입니다. 아래 미리보기는 활공 구간(28s~)이고, 누르면 전체 영상이 열립니다.

[![플레이 녹화 미리보기](docs/media/playtest_preview.gif)](docs/comparison/playtest.mp4)

녹화는 아래 순서로 진행됩니다. 괄호 안은 각 구간이 시작되는 시각입니다.

```
걷기·달리기(2s) → 꽃 3송이 채집(7s) → NPC 대화(15s) → 인벤토리(21s) → 슬라임 처치(24s) → 활공(28s) → 수영·잠수(33s) → 월드맵(46s) → 종료(51s)
```

---

## 5. 실행

필요한 도구는 Godot 4.7, [Task](https://taskfile.dev), ffmpeg(녹화할 때만)입니다.

| 명령 | 내용 |
|---|---|
| `task run` | 게임 실행 (`scenes/main.tscn`) |
| `task editor` | Godot 에디터로 열기 |
| `task test` | GUT 전체 테스트 (`task test:unit`, `task test:integration`으로 나눠 실행 가능) |
| `task playtest` | 자동 플레이를 화면으로 보기 |
| `task record` | 자동 플레이를 녹화해 `docs/comparison/playtest.mp4`로 저장 |

`task run`·`task test`·`task playtest`·`task record`는 실행 전에 에셋 임포트를 먼저 수행합니다.

```
task import → task test → task playtest → task record
```

### 조작

| 키 | 동작 |
|---|---|
| W A S D | 이동 |
| Shift | 달리기 |
| Space | 점프, 공중에서 한 번 더 누르면 활공 |
| C | 수중 하강 |
| J / 좌클릭 | 공격 |
| E | 상호작용 |
| I | 인벤토리 |
| M | 월드맵 |
| Esc | 일시정지 |

---

## 6. 구조

| 경로 | 내용 |
|---|---|
| `scenes/main.tscn` | 섬, 플레이어, HUD를 조립한 메인 씬 |
| `scenes/world/` | 절차적 지형, 잔디 배치, 섬 레이아웃 |
| `scenes/characters/`, `scripts/` | 플레이어, NPC, 슬라임, 채집물, 오토로드(이벤트·인벤토리·퀘스트·대화) |
| `shaders/` | 툰, 잔디, 물, 수중, 비네트 셰이더 |
| `ui/` | HUD, 대화창, 인벤토리, 월드맵 |
| `assets/` | 3D 모델, codex 텍스처·아이콘, 오디오 플레이스홀더 |
| `tests/` | GUT 단위·통합 테스트, 자동 플레이 |
| `docs/` | 스타일 가이드, 팀 계약, 레퍼런스, 비교 자료 |

### 문서

- [`docs/art-style-prompts.md`](docs/art-style-prompts.md): 스타일 분석, 팔레트, 이미지·3D 프롬프트
- [`docs/team-contract.md`](docs/team-contract.md): 경로, 좌표, 입력, 레이어, 셰이더 규약
- [`docs/comparison/README.md`](docs/comparison/README.md): 비교 판정과 녹화 구간
- [`scripts/API.md`](scripts/API.md), [`tests/README.md`](tests/README.md)
