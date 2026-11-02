extends Node

const SFX_2D_POOL_SIZE := 12
const SFX_3D_POOL_SIZE := 12
const UI_POOL_SIZE := 4
const SILENT_DB := -80.0

const SOUNDS := {
	"footstep_grass": {
		"kind": "sfx",
		"path": "res://assets/audio/placeholder/footstep_grass.ogg",
		"bus": "SFX",
		"loop": false,
		"volume_db": -6.0,
		"max_distance": 14.0,
	},
	"footstep_sand": {
		"kind": "sfx",
		"path": "res://assets/audio/placeholder/footstep_sand.ogg",
		"bus": "SFX",
		"loop": false,
		"volume_db": -6.0,
		"max_distance": 14.0,
	},
	"footstep_dirt": {
		"kind": "sfx",
		"path": "res://assets/audio/placeholder/footstep_dirt.ogg",
		"bus": "SFX",
		"loop": false,
		"volume_db": -6.0,
		"max_distance": 14.0,
	},
	"footstep_wood": {
		"kind": "sfx",
		"path": "res://assets/audio/placeholder/footstep_wood.ogg",
		"bus": "SFX",
		"loop": false,
		"volume_db": -6.0,
		"max_distance": 16.0,
	},
	"water_enter": {
		"kind": "sfx",
		"path": "res://assets/audio/placeholder/water_enter.ogg",
		"bus": "SFX",
		"loop": false,
		"volume_db": -4.0,
		"max_distance": 26.0,
	},
	"attack_swing": {
		"kind": "sfx",
		"path": "res://assets/audio/placeholder/attack_swing.ogg",
		"bus": "SFX",
		"loop": false,
		"volume_db": -6.0,
		"max_distance": 20.0,
	},
	"player_hit": {
		"kind": "sfx",
		"path": "res://assets/audio/placeholder/player_hit.ogg",
		"bus": "SFX",
		"loop": false,
		"volume_db": -4.0,
		"max_distance": 20.0,
	},
	"slime_hit": {
		"kind": "sfx",
		"path": "res://assets/audio/placeholder/slime_hit.ogg",
		"bus": "SFX",
		"loop": false,
		"volume_db": -5.0,
		"max_distance": 22.0,
	},
	"slime_defeat": {
		"kind": "sfx",
		"path": "res://assets/audio/placeholder/slime_defeat.ogg",
		"bus": "SFX",
		"loop": false,
		"volume_db": -4.0,
		"max_distance": 24.0,
	},
	"item_pickup": {
		"kind": "sfx",
		"path": "res://assets/audio/placeholder/item_pickup.ogg",
		"bus": "SFX",
		"loop": false,
		"volume_db": -5.0,
		"max_distance": 16.0,
	},
	"wind_light": {
		"kind": "ambient",
		"path": "res://assets/audio/placeholder/wind_light.ogg",
		"bus": "Ambient",
		"loop": true,
		"volume_db": -12.0,
		"spatial": false,
	},
	"wind_strong": {
		"kind": "ambient",
		"path": "res://assets/audio/placeholder/wind_strong.ogg",
		"bus": "Ambient",
		"loop": true,
		"volume_db": -10.0,
		"spatial": false,
	},
	"waves_shore": {
		"kind": "ambient",
		"path": "res://assets/audio/placeholder/waves_shore.ogg",
		"bus": "Ambient",
		"loop": true,
		"volume_db": -10.0,
		"spatial": true,
		"max_distance": 45.0,
	},
	"glide_wind": {
		"kind": "ambient",
		"path": "res://assets/audio/placeholder/glide_wind.ogg",
		"bus": "Ambient",
		"loop": true,
		"volume_db": -10.0,
		"spatial": false,
	},
	"swim_loop": {
		"kind": "ambient",
		"path": "res://assets/audio/placeholder/swim_loop.ogg",
		"bus": "Ambient",
		"loop": true,
		"volume_db": -12.0,
		"spatial": false,
	},
	"underwater_loop": {
		"kind": "ambient",
		"path": "res://assets/audio/placeholder/underwater_loop.ogg",
		"bus": "Ambient",
		"loop": true,
		"volume_db": -10.0,
		"spatial": false,
	},
	"ui_open": {
		"kind": "ui",
		"path": "res://assets/audio/placeholder/ui_open.ogg",
		"bus": "UI",
		"loop": false,
		"volume_db": -2.0,
	},
	"ui_close": {
		"kind": "ui",
		"path": "res://assets/audio/placeholder/ui_close.ogg",
		"bus": "UI",
		"loop": false,
		"volume_db": -2.0,
	},
	"ui_select": {
		"kind": "ui",
		"path": "res://assets/audio/placeholder/ui_select.ogg",
		"bus": "UI",
		"loop": false,
		"volume_db": -2.0,
	},
	"dialogue_advance": {
		"kind": "ui",
		"path": "res://assets/audio/placeholder/dialogue_advance.ogg",
		"bus": "UI",
		"loop": false,
		"volume_db": -2.0,
	},
	"bgm_meadow": {
		"kind": "bgm",
		"path": "res://assets/audio/placeholder/bgm_meadow.ogg",
		"bus": "BGM",
		"loop": true,
		"volume_db": -6.0,
	},
	"bgm_beach": {
		"kind": "bgm",
		"path": "res://assets/audio/placeholder/bgm_beach.ogg",
		"bus": "BGM",
		"loop": true,
		"volume_db": -6.0,
	},
	"bgm_village": {
		"kind": "bgm",
		"path": "res://assets/audio/placeholder/bgm_village.ogg",
		"bus": "BGM",
		"loop": true,
		"volume_db": -6.0,
	},
	"bgm_underwater": {
		"kind": "bgm",
		"path": "res://assets/audio/placeholder/bgm_underwater.ogg",
		"bus": "BGM",
		"loop": true,
		"volume_db": -6.0,
	},
}

var _stream_cache: Dictionary = {}
var _warned: Dictionary = {}
var _sfx_2d: Array[AudioStreamPlayer] = []
var _sfx_3d: Array[AudioStreamPlayer3D] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _pool_cursor := 0
var _bgm_a: AudioStreamPlayer
var _bgm_b: AudioStreamPlayer
var _bgm_current: AudioStreamPlayer
var _bgm_region := ""
var _bgm_tweens: Array[Tween] = []
var _ambient_players: Dictionary = {}


func _ready() -> void:
	_bgm_a = _make_2d_player("BGM")
	_bgm_b = _make_2d_player("BGM")
	for i in SFX_2D_POOL_SIZE:
		_sfx_2d.append(_make_2d_player("SFX"))
	for i in SFX_3D_POOL_SIZE:
		_sfx_3d.append(_make_3d_player())
	for i in UI_POOL_SIZE:
		_ui_players.append(_make_2d_player("UI"))


func play_sfx(id: String, position: Variant = null) -> void:
	var entry := _entry_for(id, "sfx")
	if entry.is_empty():
		return
	var stream := _get_stream(entry)
	if stream == null:
		return
	var volume: float = entry.get("volume_db", 0.0)
	if position is Vector3:
		var player := _claim(_sfx_3d) as AudioStreamPlayer3D
		player.stop()
		player.stream = stream
		player.volume_db = volume
		player.max_distance = entry.get("max_distance", 20.0)
		player.global_position = position
		player.play()
	else:
		var player := _claim(_sfx_2d) as AudioStreamPlayer
		player.stop()
		player.stream = stream
		player.volume_db = volume
		player.play()


func play_ui(id: String) -> void:
	var entry := _entry_for(id, "ui")
	if entry.is_empty():
		return
	var stream := _get_stream(entry)
	if stream == null:
		return
	var player := _claim(_ui_players) as AudioStreamPlayer
	player.stop()
	player.stream = stream
	player.volume_db = entry.get("volume_db", 0.0)
	player.play()


func play_bgm(region: String, fade_sec := 1.5) -> void:
	var entry := _entry_for("bgm_" + region, "bgm")
	if entry.is_empty():
		return
	if region == _bgm_region and _bgm_current != null and _bgm_current.playing:
		return
	var stream := _get_stream(entry)
	if stream == null:
		return
	var target_db: float = entry.get("volume_db", 0.0)
	var old_player: AudioStreamPlayer = _bgm_current
	var new_player: AudioStreamPlayer = _bgm_b if old_player == _bgm_a else _bgm_a

	_kill_bgm_tweens()
	new_player.stop()
	new_player.stream = stream
	new_player.volume_db = SILENT_DB if fade_sec > 0.0 else target_db
	new_player.play()

	if fade_sec > 0.0:
		var fade_in := create_tween()
		fade_in.tween_property(new_player, "volume_db", target_db, fade_sec)
		_bgm_tweens.append(fade_in)
		if old_player != null:
			var fade_out := create_tween()
			fade_out.tween_property(old_player, "volume_db", SILENT_DB, fade_sec)
			fade_out.tween_callback(old_player.stop)
			_bgm_tweens.append(fade_out)
	elif old_player != null:
		old_player.stop()

	_bgm_current = new_player
	_bgm_region = region


func set_ambient(id: String, enabled: bool, position: Variant = null) -> void:
	var entry := _entry_for(id, "ambient")
	if entry.is_empty():
		return
	if not enabled:
		if _ambient_players.has(id):
			var old_player = _ambient_players[id]
			if is_instance_valid(old_player):
				old_player.stop()
				old_player.queue_free()
			_ambient_players.erase(id)
		return
	if _ambient_players.has(id):
		var player = _ambient_players[id]
		if is_instance_valid(player):
			if position is Vector3 and player is AudioStreamPlayer3D:
				player.global_position = position
			return
		_ambient_players.erase(id)
	var stream := _get_stream(entry)
	if stream == null:
		return
	var player
	if entry.get("spatial", false):
		var player_3d := AudioStreamPlayer3D.new()
		player_3d.bus = entry.get("bus", "Ambient")
		player_3d.max_distance = entry.get("max_distance", 45.0)
		add_child(player_3d)
		if position is Vector3:
			player_3d.global_position = position
		player = player_3d
	else:
		player = _make_2d_player(entry.get("bus", "Ambient"))
	player.stream = stream
	player.volume_db = entry.get("volume_db", 0.0)
	player.play()
	_ambient_players[id] = player


func set_bus_volume(bus: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		_warn_once("unknown audio bus: " + bus)
		return
	var value := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, SILENT_DB if value <= 0.0 else linear_to_db(value))


func _make_2d_player(bus_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	add_child(player)
	return player


func _make_3d_player() -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.bus = "SFX"
	player.max_distance = 20.0
	add_child(player)
	return player


func _claim(pool: Array) -> Node:
	for player in pool:
		if not player.playing:
			return player
	_pool_cursor += 1
	return pool[_pool_cursor % pool.size()]


func _entry_for(id: String, kind: String) -> Dictionary:
	var entry: Dictionary = SOUNDS.get(id, {})
	if entry.is_empty():
		_warn_once("unknown audio id: " + id)
		return {}
	if entry.get("kind", "") != kind:
		_warn_once("audio id '%s' is not a %s" % [id, kind])
		return {}
	return entry


func _get_stream(entry: Dictionary) -> AudioStream:
	var path: String = entry.get("path", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		_warn_once("missing audio file: " + path)
		return null
	var stream: AudioStream
	if _stream_cache.has(path):
		stream = _stream_cache[path]
	else:
		stream = load(path) as AudioStream
		if stream == null:
			_warn_once("failed to load audio: " + path)
			return null
		_stream_cache[path] = stream
	if entry.get("loop", false):
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		elif stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


func _kill_bgm_tweens() -> void:
	for tween in _bgm_tweens:
		if tween.is_valid():
			tween.kill()
	_bgm_tweens.clear()


func _exit_tree() -> void:
	_kill_bgm_tweens()
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			child.stop()
			child.stream = null
	_ambient_players.clear()
	_stream_cache.clear()
	OS.delay_msec(100)


func _warn_once(message: String) -> void:
	if _warned.has(message):
		return
	_warned[message] = true
	push_warning("AudioManager: " + message)
