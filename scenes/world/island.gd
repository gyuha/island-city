extends Node3D
## 섬 레벨 루트. 지형·소품·잔디는 _ready에서 절차적으로 생성한다.
## 공개 API: set_underwater(enabled), get_spawn_transform()

const SEABED_ROCK_COUNT := 48
const TREE_COUNT := 38
const BUSH_COUNT := 80

# 에셋 계약 경로 (art가 생성). 없으면 플레이스홀더.
const M_TREE_A := "res://assets/models/nature/tree_round_a.glb"
const M_TREE_B := "res://assets/models/nature/tree_round_b.glb"
const M_BUSH := "res://assets/models/nature/bush_round.glb"
const M_ROCKS := [
	"res://assets/models/nature/rock_a.glb",
	"res://assets/models/nature/rock_b.glb",
	"res://assets/models/nature/rock_c.glb",
]
const M_CATTAIL := "res://assets/models/nature/cattail.glb"
const M_LILYPAD := "res://assets/models/nature/lilypad.glb"
const M_SEAGRASS := "res://assets/models/nature/seagrass.glb"
const M_COTTAGE := "res://assets/models/buildings/cottage.glb"
const M_PIER := "res://assets/models/buildings/pier.glb"

const FOG_DAY_COLOR := Color("dff8d1")
const FOG_WATER_COLOR := Color("57d3b6")

var _patch := FastNoiseLite.new()
var terrain: IslandTerrain
var _rng := RandomNumberGenerator.new()
var _toon_shader: Shader = load("res://shaders/toon.gdshader")
var _toon_vc: ShaderMaterial      # 흰색 albedo — 버텍스 컬러가 색을 결정 (art 모델용)
var _toon_cache := {}
var _generated: Node3D
var _tree_spots: Array[Vector2] = []

@onready var _env: Environment = $WorldEnvironment.environment
@onready var _underwater_layer: CanvasLayer = $ScreenFX/UnderwaterLayer
var _day_fog := {}


func _ready() -> void:
	_rng.seed = 2025
	_patch.seed = 9
	_patch.frequency = 0.07
	_toon_vc = _toon(Color.WHITE)
	_generated = Node3D.new()
	_generated.name = "Generated"
	add_child(_generated)

	terrain = IslandTerrain.new()
	terrain.build()
	_build_terrain()
	_build_village()
	_build_pier()
	_build_trees_and_bushes()
	_build_rocks()
	_build_waterside()
	_build_seabed()

	var grass := GrassScatter.new()
	grass.name = "Grass"
	_generated.add_child(grass)
	grass.setup(terrain)

	_snap_spawn()
	_day_fog = {
		"enabled": _env.fog_enabled,
		"color": _env.fog_light_color,
		"density": _env.fog_density,
		"sky_affect": _env.fog_sky_affect,
	}
	set_underwater(false)


# ── 공개 API ────────────────────────────────────────────────

func set_underwater(enabled: bool) -> void:
	_underwater_layer.visible = enabled
	if enabled:
		_env.fog_enabled = true
		_env.fog_light_color = FOG_WATER_COLOR
		_env.fog_density = 0.012
		_env.fog_sky_affect = 1.0
	else:
		_env.fog_enabled = _day_fog.get("enabled", true)
		_env.fog_light_color = _day_fog.get("color", FOG_DAY_COLOR)
		_env.fog_density = _day_fog.get("density", 0.002)
		_env.fog_sky_affect = _day_fog.get("sky_affect", 0.0)


func get_spawn_transform() -> Transform3D:
	return $PlayerSpawn.global_transform


# ── 헬퍼 ────────────────────────────────────────────────────

func _toon(color: Color, faceted := false, rim := 0.0) -> ShaderMaterial:
	var key := "%s_%s_%s" % [color.to_html(), faceted, rim]
	if _toon_cache.has(key):
		return _toon_cache[key]
	var m := ShaderMaterial.new()
	m.shader = _toon_shader
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("faceted", faceted)
	m.set_shader_parameter("rim_strength", rim)
	_toon_cache[key] = m
	return m


func _mesh_node(mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.rotation_degrees = rot
	return mi


func _sphere(radial := 12, rings := 6) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = radial
	s.rings = rings
	return s


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _static_body(shape: Shape3D, pos := Vector3.ZERO, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	cs.rotation_degrees = rot
	body.add_child(cs)
	return body


func _apply_toon_override(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for c in node.get_children():
		_apply_toon_override(c, mat)


## 계약 경로 glb가 있으면 인스턴스(+toon override), 없으면 fallback 플레이스홀더.
func _spawn_model(path: String, fallback: Callable, mat: Material = null) -> Node3D:
	if ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene:
			var inst := scene.instantiate() as Node3D
			_apply_toon_override(inst, mat if mat else _toon_vc)
			return inst
	return fallback.call()


func _first_mesh(path: String, name_hint := "") -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var inst := scene.instantiate()
	var found: Mesh = null
	var stack: Array = [inst]
	while not stack.is_empty() and found == null:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and n.mesh and (name_hint == "" or n.name == name_hint):
			found = n.mesh
		stack.append_array(n.get_children())
	inst.free()
	return found


func _place(node: Node3D, x: float, z: float, y_offset := 0.0, yaw := 0.0) -> void:
	node.position = Vector3(x, terrain.sample_height(x, z) + y_offset, z)
	node.rotation.y = yaw
	_generated.add_child(node)


func _multimesh(mesh: Mesh, mat: Material, xforms: Array[Transform3D], vis_end := 0.0) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis_end > 0.0:
		mmi.visibility_range_end = vis_end
	_generated.add_child(mmi)
	return mmi


func _snap_spawn() -> void:
	var sp: Marker3D = $PlayerSpawn
	var p := sp.global_position
	sp.global_position = Vector3(p.x, terrain.sample_height(p.x, p.z) + 0.3, p.z)


func _near_path(x: float, z: float, margin: float) -> bool:
	return terrain.path_weight(x, z) > 0.0 or terrain.path_weight(x + margin, z) > 0.0 \
		or terrain.path_weight(x - margin, z) > 0.0 or terrain.path_weight(x, z + margin) > 0.0 \
		or terrain.path_weight(x, z - margin) > 0.0


# ── 지형 ────────────────────────────────────────────────────

func _build_terrain() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = terrain.build_mesh()
	var tm := ShaderMaterial.new()
	tm.shader = _toon_shader
	tm.set_shader_parameter("path_blend", true)
	tm.set_shader_parameter("path_color", IslandTerrain.C_PATH)
	mi.material_override = tm
	_generated.add_child(mi)
	var body := _static_body(terrain.build_collision_shape())
	body.name = "TerrainBody"
	_generated.add_child(body)


# ── 마을 / 선착장 ───────────────────────────────────────────

func _cottage_placeholder() -> Node3D:
	var root := Node3D.new()
	root.add_child(_mesh_node(_box(Vector3(3.4, 2.3, 3.0)), _toon(Color("f6f1e4")), Vector3(0, 1.15, 0)))
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = 3.0
	roof.height = 1.7
	roof.radial_segments = 4
	roof.rings = 1
	root.add_child(_mesh_node(roof, _toon(Color("d9503f")), Vector3(0, 3.1, 0), Vector3(1.0, 1.0, 0.88), Vector3(0, 45, 0)))
	root.add_child(_mesh_node(_box(Vector3(0.8, 1.4, 0.12)), _toon(Color("7a4f30")), Vector3(0, 0.7, 1.52)))
	root.add_child(_mesh_node(_box(Vector3(0.55, 1.1, 0.55)), _toon(Color("e2c98f")), Vector3(1.0, 3.5, -0.5)))
	root.add_child(_static_body(_make_box_shape(Vector3(3.4, 3.4, 3.0)), Vector3(0, 1.7, 0)))
	return root


func _make_box_shape(size: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = size
	return s


func _build_village() -> void:
	var vc := IslandTerrain.VILLAGE_C
	var spots := [Vector2(-7, -3), Vector2(2, -8), Vector2(8, 1), Vector2(-3, 6), Vector2(11, -9)]
	var i := 0
	for s in spots:
		var p: Vector2 = vc + s
		var cottage := _spawn_model(M_COTTAGE, _cottage_placeholder)
		cottage.name = "Cottage%d" % i
		var yaw := atan2(-(vc.x - 4.0 - p.x), -(vc.y + 6.0 - p.y)) # 길 쪽을 바라보게
		_place(cottage, p.x, p.y, 0.0, yaw)
		_tree_spots.append(p)
		i += 1


func _build_pier() -> void:
	var z0 := terrain.pier_shore_z - 3.0
	var root := Node3D.new()
	root.name = "Pier"
	var built := _spawn_model(M_PIER, _pier_placeholder)
	root.add_child(built)
	root.position = Vector3(IslandTerrain.PIER_X, 0.0, z0)
	_generated.add_child(root)


func _pier_placeholder() -> Node3D:
	var root := Node3D.new()
	var length := 13.0
	var width := 2.4
	var plank_a := _toon(Color("b9804f"))
	var plank_b := _toon(Color("a46f43"))
	var n := int(length / 0.5)
	for k in range(n):
		root.add_child(_mesh_node(_box(Vector3(width, 0.14, 0.46)), plank_a if k % 2 == 0 else plank_b, Vector3(0, 0.62, 0.25 + k * 0.5)))
	var post_mat := _toon(Color("7a4f30"))
	for k in range(0, int(length / 3.0) + 1):
		for sx in [-1.0, 1.0]:
			root.add_child(_mesh_node(_box(Vector3(0.22, 3.2, 0.22)), post_mat, Vector3(sx * (width * 0.5 - 0.05), -0.5, 0.4 + k * 3.0)))
	root.add_child(_mesh_node(_box(Vector3(0.14, 0.14, length)), post_mat, Vector3(-width * 0.5, 0.62 - 0.14, length * 0.5)))
	root.add_child(_mesh_node(_box(Vector3(0.14, 0.14, length)), post_mat, Vector3(width * 0.5, 0.62 - 0.14, length * 0.5)))
	root.add_child(_static_body(_make_box_shape(Vector3(width, 0.2, length)), Vector3(0, 0.62, length * 0.5)))
	return root


# ── 나무·덤불 ───────────────────────────────────────────────

func _tree_placeholder(variant: int) -> Node3D:
	var root := Node3D.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.1
	trunk.bottom_radius = 0.16
	trunk.height = 2.6
	root.add_child(_mesh_node(trunk, _toon(Color("5d3d28")), Vector3(0, 1.3, 0)))
	var greens := [Color("3aa13b"), Color("4fae48"), Color("81d465")]
	var count := 5 + variant
	for k in range(count):
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(0.2, 0.95)
		var y := 2.9 + _rng.randf_range(-0.2, 1.1) + (0.5 if k == 0 else 0.0)
		var s := _rng.randf_range(0.8, 1.25)
		var c: Color = greens[clampi(int((y - 2.6) * 1.5), 0, 2)]
		root.add_child(_mesh_node(_sphere(14, 7), _toon(c), Vector3(cos(a) * r, y, sin(a) * r), Vector3.ONE * s))
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.28
	cyl.height = 2.6
	root.add_child(_static_body(cyl, Vector3(0, 1.3, 0)))
	return root


func _bush_placeholder() -> Node3D:
	var root := Node3D.new()
	var cols := [Color("4fae48"), Color("5bb94f"), Color("81d465")]
	for k in range(3):
		var a := TAU * k / 3.0 + _rng.randf()
		root.add_child(_mesh_node(_sphere(12, 6), _toon(cols[k]), Vector3(cos(a) * 0.4, 0.5 + 0.1 * k, sin(a) * 0.4), Vector3.ONE * _rng.randf_range(0.5, 0.7)))
	return root


func _scatter_points(count: int, min_dist: float, accept: Callable, existing: Array[Vector2]) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var tries := 0
	while pts.size() < count and tries < count * 60:
		tries += 1
		var p := Vector2(_rng.randf_range(-85, 85), _rng.randf_range(-70, 70))
		if not accept.call(p):
			continue
		var ok := true
		for q in existing:
			if p.distance_squared_to(q) < min_dist * min_dist:
				ok = false
				break
		if ok:
			for q in pts:
				if p.distance_squared_to(q) < min_dist * min_dist:
					ok = false
					break
		if ok:
			pts.append(p)
	return pts


func _build_trees_and_bushes() -> void:
	var tree_ok := func(p: Vector2) -> bool:
		return terrain.sample_grass(p.x, p.y) > 0.95 and terrain.sample_height(p.x, p.y) > 2.0 \
			and p.distance_to(IslandTerrain.VILLAGE_C) > 11.0 and not _near_path(p.x, p.y, 2.5) \
			and p.distance_to(IslandTerrain.LAKE_C) > IslandTerrain.LAKE_R + 3.0
	var trees := _scatter_points(TREE_COUNT, 7.0, tree_ok, _tree_spots)
	var i := 0
	for p in trees:
		var variant := i % 2
		var t := _spawn_model(M_TREE_A if variant == 0 else M_TREE_B, func(): return _tree_placeholder(variant))
		t.name = "Tree%d" % i
		var s := _rng.randf_range(0.8, 0.95)
		t.scale = Vector3.ONE * s
		_place(t, p.x, p.y, -0.1, _rng.randf() * TAU)
		i += 1
	var bush_ok := func(p: Vector2) -> bool:
		return terrain.sample_grass(p.x, p.y) > 0.95 and not _near_path(p.x, p.y, 1.5) \
			and p.distance_to(IslandTerrain.VILLAGE_C) > 9.0
	var bushes := _scatter_points(BUSH_COUNT, 2.8, bush_ok, trees)
	# 무리 짓기: 일부 덤불 곁에 2~3개를 더 붙인다
	var grouped: Array[Vector2] = []
	for k in range(mini(bushes.size(), 45)):
		for m in range(_rng.randi_range(2, 3)):
			var q: Vector2 = bushes[k] + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(1.3, 2.3)
			if terrain.sample_grass(q.x, q.y) > 0.9:
				grouped.append(q)
	# 길가 덤불
	var pp := terrain.path_points
	for si in range(pp.size() - 1):
		var a: Vector2 = pp[si]
		var b2: Vector2 = pp[si + 1]
		var dir := (b2 - a).normalized()
		var n := dir.orthogonal()
		var d := 2.0
		while d < a.distance_to(b2) - 2.0:
			var side := 1.0 if _rng.randf() < 0.5 else -1.0
			var q := a + dir * d + n * side * _rng.randf_range(3.0, 4.2)
			if terrain.sample_grass(q.x, q.y) > 0.9 and not _near_path(q.x, q.y, 1.2):
				grouped.append(q)
				grouped.append(q + Vector2.from_angle(_rng.randf() * TAU) * 1.6)
			d += _rng.randf_range(5.0, 9.0)
	bushes.append_array(grouped)
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 1.0
	shadow_mesh.bottom_radius = 1.0
	shadow_mesh.height = 0.02
	shadow_mesh.radial_segments = 16
	shadow_mesh.rings = 1
	var shadow_mat := _toon(Color("256d4b"))
	i = 0
	for p in bushes:
		var b := _spawn_model(M_BUSH, _bush_placeholder)
		b.name = "Bush%d" % i
		var sc := _rng.randf_range(0.65, 0.85)
		b.scale = Vector3.ONE * sc
		_place(b, p.x, p.y, -0.05, _rng.randf() * TAU)
		# 접지 그림자 (짙은 청록)
		var sh := _mesh_node(shadow_mesh, shadow_mat, Vector3(p.x + 0.15, terrain.sample_height(p.x, p.y) + 0.12, p.y + 0.1), Vector3(1.0, 1.0, 0.85) * sc * 0.95)
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_generated.add_child(sh)
		i += 1


# ── 바위 ────────────────────────────────────────────────────

func _rock_placeholder(color: Color, size: float) -> Node3D:
	var root := Node3D.new()
	root.add_child(_mesh_node(_sphere(6, 3), _toon(color, true), Vector3(0, size * 0.35, 0), Vector3(size * 1.2, size * 0.85, size)))
	var sh := SphereShape3D.new()
	sh.radius = size * 0.9
	root.add_child(_static_body(sh, Vector3(0, size * 0.3, 0)))
	return root


func _make_rock(idx: int, color: Color, size: float) -> Node3D:
	return _spawn_model(M_ROCKS[idx % 3], func(): return _rock_placeholder(color, size), _toon(color, true))


func _build_rocks() -> void:
	var land_ok := func(p: Vector2) -> bool:
		return terrain.sample_grass(p.x, p.y) > 0.9 and not _near_path(p.x, p.y, 1.5) \
			and p.distance_to(IslandTerrain.VILLAGE_C) > 10.0 \
			and p.distance_to(IslandTerrain.LAKE_C) > IslandTerrain.LAKE_R + 2.0
	var land := _scatter_points(12, 9.0, land_ok, _tree_spots)
	var i := 0
	for p in land:
		var r := _make_rock(i, Color("8fb0b8").lerp(Color("a7c4bc"), _rng.randf()), _rng.randf_range(0.7, 1.5))
		r.name = "Rock%d" % i
		_place(r, p.x, p.y, -0.15, _rng.randf() * TAU)
		i += 1
	# 해저·호수 바닥 바위 (이끼 낀 청록 계열)
	var sea_ok := func(p: Vector2) -> bool:
		var h := terrain.sample_height(p.x, p.y)
		return h < -1.5 and h > -9.0
	var sea := _scatter_points(SEABED_ROCK_COUNT, 4.5, sea_ok, [])
	for p in sea:
		var col := Color("4f8f9a").lerp(Color("4aa089"), _rng.randf())
		var r := _make_rock(i, col, _rng.randf_range(1.0, 2.4))
		r.name = "SeabedRock%d" % i
		_place(r, p.x, p.y, -0.3, _rng.randf() * TAU)
		i += 1
	# ShotUnderwater 화면 앞쪽에 보이는 바위
	for spec in [[Vector2(-27.0, 72.5), 1.1, Color("4f8f9a")], [Vector2(-30.5, 69.5), 0.8, Color("4aa089")]]:
		var r2 := _make_rock(i, spec[2], spec[1])
		r2.name = "SeabedRock%d" % i
		_place(r2, spec[0].x, spec[0].y, -0.2, _rng.randf() * TAU)
		i += 1


# ── 물가: 부들·수련 ─────────────────────────────────────────

func _build_waterside() -> void:
	var lake := IslandTerrain.LAKE_C
	# 부들 (줄기 + 갈색 머리). seagrass/cattail.glb가 있으면 그 메시 사용.
	var cat_mesh := _first_mesh(M_CATTAIL)
	var stalks: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	var tries := 0
	while stalks.size() < 260 and tries < 6000:
		tries += 1
		var p := Vector2(_rng.randf_range(-85, 85), _rng.randf_range(-70, 70))
		var h := terrain.sample_height(p.x, p.y)
		if h < 0.05 or h > 0.8 or p.distance_to(Vector2(IslandTerrain.PIER_X, terrain.pier_shore_z)) < 4.0:
			continue
		# 군락: 노이즈 대신 호수 근처와 해안 일부에 집중
		if p.distance_to(lake) > IslandTerrain.LAKE_R * 1.4 and _rng.randf() > 0.12:
			continue
		var s := _rng.randf_range(0.8, 1.3)
		var tilt := Vector3(_rng.randf_range(-0.12, 0.12), _rng.randf() * TAU, _rng.randf_range(-0.12, 0.12))
		var basis := Basis.from_euler(tilt).scaled(Vector3.ONE * s)
		stalks.append(Transform3D(basis, Vector3(p.x, h, p.y)))
		heads.append(Transform3D(basis, Vector3(p.x, h, p.y) + basis * Vector3(0, 0.95, 0)))
	if cat_mesh:
		_multimesh(cat_mesh, _toon_vc, stalks)
	else:
		var stalk := CylinderMesh.new()
		stalk.top_radius = 0.012
		stalk.bottom_radius = 0.018
		stalk.height = 1.0
		stalk.radial_segments = 4
		stalk.rings = 1
		var head := CapsuleMesh.new()
		head.radius = 0.045
		head.height = 0.28
		head.radial_segments = 6
		head.rings = 2
		var stalk_xf: Array[Transform3D] = []
		for xf in stalks:
			stalk_xf.append(Transform3D(xf.basis, xf.origin + xf.basis * Vector3(0, 0.5, 0)))
		_multimesh(stalk, _toon(Color("4fae48")), stalk_xf)
		_multimesh(head, _toon(Color("7a4f30")), heads)

	# 수련
	var pad_mesh := _first_mesh(M_LILYPAD, "LilyPadLeaf")
	var blossom_mesh := _first_mesh(M_LILYPAD, "LotusBlossom")
	var pads: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	tries = 0
	while pads.size() < 46 and tries < 3000:
		tries += 1
		var a := _rng.randf() * TAU
		var r := IslandTerrain.LAKE_R * sqrt(_rng.randf()) * 0.85
		var x := lake.x + cos(a) * r
		var z := lake.y + sin(a) * r
		if terrain.sample_height(x, z) > -0.6:
			continue
		var s := _rng.randf_range(1.0, 1.7)
		var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, 1, s))
		pads.append(Transform3D(b, Vector3(x, 0.03, z)))
		if _rng.randf() < 0.3:
			flowers.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3(x + 0.1, 0.03, z)))
	if pad_mesh:
		_multimesh(pad_mesh, _toon_vc, pads)
		if blossom_mesh:
			_multimesh(blossom_mesh, _toon_vc, flowers)
	else:
		var pad := CylinderMesh.new()
		pad.top_radius = 0.55
		pad.bottom_radius = 0.55
		pad.height = 0.04
		pad.radial_segments = 14
		pad.rings = 1
		_multimesh(pad, _toon(Color("5bb94f")), pads)
		var fl := _sphere(8, 4)
		fl.radius = 0.12
		fl.height = 0.24
		_multimesh(fl, _toon(Color("ff9fc0")), flowers)


# ── 해저: 조약돌·해초 ───────────────────────────────────────

func _build_seabed() -> void:
	# 조약돌 3색
	var pebble := _sphere(8, 4)
	var pebble_cols := [Color("3f93b8"), Color("8bc4c8"), Color("6fa58f")]
	for ci in range(pebble_cols.size()):
		var xf: Array[Transform3D] = []
		var tries := 0
		while xf.size() < 1800 and tries < 40000:
			tries += 1
			var p := Vector2(_rng.randf_range(-92, 92), _rng.randf_range(-76, 76))
			var h := terrain.sample_height(p.x, p.y)
			if h > -0.35 or h < -8.0:
				continue
			var sc := _rng.randf_range(0.1, 0.4)
			var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc * 1.2, sc * 0.45, sc))
			xf.append(Transform3D(b, Vector3(p.x, h + 0.02, p.y)))
		_multimesh(pebble, _toon(pebble_cols[ci]), xf)

	# 해초
	var sg_mesh := _first_mesh(M_SEAGRASS)
	if sg_mesh == null:
		sg_mesh = GrassScatter.make_blade_mesh(1.0, 0.11, 4)
	var from_glb := ResourceLoader.exists(M_SEAGRASS) and _first_mesh(M_SEAGRASS) != null
	var sg_mat: ShaderMaterial = _toon_vc
	if not from_glb:
		sg_mat = ShaderMaterial.new()
		sg_mat.shader = load("res://shaders/grass.gdshader")
		sg_mat.set_shader_parameter("root_color", Color("2b8277"))
		sg_mat.set_shader_parameter("mid_color", Color("3fae8c"))
		sg_mat.set_shader_parameter("tip_color", Color("7fe3a6"))
		sg_mat.set_shader_parameter("wind_strength", 0.35)
		sg_mat.set_shader_parameter("wind_speed", 0.7)
	var xf: Array[Transform3D] = []
	var tries := 0
	while xf.size() < 2600 and tries < 80000:
		tries += 1
		var c := Vector2(_rng.randf_range(-90, 90), _rng.randf_range(-74, 74))
		if _patch.get_noise_2d(c.x, c.y) < 0.3:
			continue
		var h0 := terrain.sample_height(c.x, c.y)
		if h0 > -0.7 or h0 < -6.5 or c.distance_to(IslandTerrain.LAKE_C) < IslandTerrain.LAKE_R * 1.5:
			continue
		# 클러스터: 한 점에서 5~8 블레이드
		var n := _rng.randi_range(3, 8)
		var clump_scale := _rng.randf_range(0.35, 1.6)
		var max_sy := clampf(-h0 * 0.85, 0.35, 2.2)
		for k in range(n):
			var p := c + Vector2(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.4, 0.4))
			var h := terrain.sample_height(p.x, p.y)
			var sy := minf(clump_scale * _rng.randf_range(0.6, 1.4), max_sy)
			var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(1.0, sy, 1.0))
			xf.append(Transform3D(b, Vector3(p.x, h - 0.03, p.y)))
	_multimesh(sg_mesh, sg_mat, xf)
