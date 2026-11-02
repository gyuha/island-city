extends GutTest

const SCENES := [
	"res://scenes/world/island.tscn",
	"res://scenes/characters/player.tscn",
	"res://scenes/characters/slime.tscn",
	"res://scenes/characters/npc.tscn",
	"res://scenes/characters/pickup_flower.tscn",
	"res://scenes/characters/camera_rig.tscn",
	"res://ui/hud.tscn",
	"res://assets/audio/audio_manager.tscn",
]

func test_scene_loads_and_runs() -> void:
	for path in SCENES:
		var ps := load(path) as PackedScene
		assert_not_null(ps, "load: " + path)
		if ps == null:
			continue
		var node := ps.instantiate()
		assert_not_null(node, "instantiate: " + path)
		add_child(node)
		await wait_process_frames(5)
		assert_true(is_instance_valid(node), "alive after 5 frames: " + path)
		node.queue_free()
		await wait_process_frames(2)
