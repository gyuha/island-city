# tests/ — QA (GUT 9 + 자동 플레이)

소유: qa. 다른 역할 폴더는 읽기만 한다. 실패는 결함 담당 역할에 보고하고 테스트를 약화시키지 않는다.

## GUT 테스트

```
# 전체
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
# 단위만(약 1초) / 통합만(약 45초)
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit
```

`-gdir`는 기본이 비재귀이므로 상위 폴더를 줄 때는 `-ginclude_subdirs`가 필요하다. `tests/playtest/`에는 `test_*.gd`가 없어 무시된다.

| 파일 | 내용 |
|---|---|
| `unit/test_inventory.gd` | add/remove/get_count/부족 시 false/사본/시그널 |
| `unit/test_quest_manager.gd` | start, collect/defeat 진행, 보상, 중복·완료 후 재시작 방지 |
| `unit/test_dialogue_manager.gd` | start/advance/end, 퀘스트 연계 |
| `unit/test_data_resources.gd` | ItemData/QuestData/DialogueData `.tres` 로드, 아이콘 경로 |
| `integration/test_scene_loads.gd` | island/player/slime/npc/pickup_flower/camera_rig/hud/audio_manager 개별 로드 |
| `integration/test_main_scene.gd` | main.tscn 통합(지면·엔티티 수·수영·잠수·전투·채집·대화·HUD·오디오) |

## 자동 플레이 (녹화용)

`tests/playtest/playtest.tscn` + `autoplay.gd`: main.tscn을 인스턴스하고 입력 액션으로 약 50초 플레이한다.
구간 로그는 `PLAYTEST_SEG <이름> t=<초>`, 종료는 `PLAYTEST_DONE` 후 자동 quit.

```
# 빠른 검증(렌더링 없음)
godot --headless res://tests/playtest/playtest.tscn
# 녹화 — AVI 권장 (30 fps, 약 30초 만에 끝남)
godot --write-movie /tmp/playtest/playtest.avi --fixed-fps 30 res://tests/playtest/playtest.tscn
# 프레임 추출
ffmpeg -i /tmp/playtest/playtest.avi -vf scale=640:360 /tmp/playtest/fr/f%05d.png
```

주의: `--write-movie out.png`(PNG 시퀀스)는 이 환경에서 프레임당 인코딩이 1~5초로 느리고
렌더가 밀리면 같은 프레임이 반복 기록된다(1367개 파일 중 고유 프레임 약 316개). `.avi`를 쓸 것.

