extends Node3D
## 룩 검증용 캡처: 각 Shot 마커에서 PNG 저장 후 종료. (화면 있는 실행 필요)
## godot --path . res://scenes/world/_shots.tscn [-- shots=ShotMeadow,ShotBeach out=/tmp/world_shots]

var _nowater := false
var _nouw := false
const ALL := ["ShotMeadow", "ShotBeach", "ShotPath", "ShotUnderwater", "ShotVillage"]

func _ready() -> void:
	var out := "/tmp/world_shots"
	var names: Array = ALL.duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a == "nouw":
			_nouw = true
		elif a == "nowater":
			_nowater = true
		elif a.begins_with("shots="):
			names = a.substr(6).split(",")
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1080, 820)
	var island: Node3D = load("res://scenes/world/island.tscn").instantiate()
	add_child(island)
	if _nowater:
		island.get_node("Water").visible = false
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 600.0
	add_child(cam)
	cam.make_current()
	for n in names:
		var m: Marker3D = island.get_node(n)
		cam.global_transform = m.global_transform
		island.set_underwater(n == "ShotUnderwater" and not _nouw)
		print(n, " cam ", cam.global_position, " fwd ", -cam.global_transform.basis.z, " ground_h ", island.terrain.sample_height(cam.global_position.x, cam.global_position.z))
		for i in range(40):
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [out, n])
		print("saved ", n, " ", img.get_size())
	get_tree().quit()
