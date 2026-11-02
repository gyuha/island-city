class_name GrassScatter
extends Node3D
## 청크 단위 MultiMesh 잔디 + 꽃 스캐터.
## 성능: 카메라 거리 기반 visibility_range로 촘촘한 근거리 층(~28m)과
## 성긴 원거리 층(18~80m, 블레이드 굵게)을 나눠 플레이어/카메라 주변만 촘촘하게 그린다.

const CHUNK := 12
const NEAR_DENSITY := 70.0   # 블레이드/m²
const FAR_DENSITY := 12.0
const FLOWER_DENSITY := [0.6, 0.9, 0.4]  # 흰/노랑/분홍 /m²
const NEAR_END := 28.0
const FAR_BEGIN := 20.0
const FAR_END := 85.0
const FLOWER_END := 42.0

const FLOWER_COLORS := [Color("fffdf0"), Color("ffd23a"), Color("ff9fc0")]

var _grass_shader: Shader = load("res://shaders/grass.gdshader")


static func make_blade_mesh(height: float, width: float, segments: int = 3) -> ArrayMesh:
	## 끝이 뾰족한 휘어진 블레이드. UV.y = 높이 비율(0..1), UV.x = 0(잎).
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in range(segments):
		var t := float(i) / segments
		var w := width * 0.5 * (1.0 - pow(t, 1.6) * 0.85)
		var y := t * height
		var zc := 0.22 * height * t * t
		verts.append(Vector3(-w, y, zc))
		verts.append(Vector3(w, y, zc))
		uvs.append(Vector2(0, t))
		uvs.append(Vector2(0, t))
	verts.append(Vector3(0, height, 0.22 * height))
	uvs.append(Vector2(0, 1))
	for i in range(segments - 1):
		var a := i * 2
		idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var top := (segments - 1) * 2
	idx.append_array([top, top + 1, segments * 2])
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	return _to_mesh(verts, normals, uvs, idx)


static func make_flower_mesh(stem_h: float, head_r: float) -> ArrayMesh:
	## 가는 줄기(UV.x=0) + 위를 향한 육각 머리(UV.x=1).
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var sw := 0.012
	verts.append_array([Vector3(-sw, 0, 0), Vector3(sw, 0, 0), Vector3(-sw * 0.6, stem_h, 0), Vector3(sw * 0.6, stem_h, 0)])
	uvs.append_array([Vector2(0, 0), Vector2(0, 0), Vector2(0, 1), Vector2(0, 1)])
	idx.append_array([0, 1, 2, 1, 3, 2])
	var c := verts.size()
	verts.append(Vector3(0, stem_h, 0))
	uvs.append(Vector2(1, 1))
	for k in range(6):
		var a := TAU * k / 6.0
		verts.append(Vector3(cos(a) * head_r, stem_h, sin(a) * head_r))
		uvs.append(Vector2(1, 1))
	for k in range(6):
		idx.append_array([c, c + 1 + k, c + 1 + (k + 1) % 6])
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	return _to_mesh(verts, normals, uvs, idx)


static func _to_mesh(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, idx: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _flower_material(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _grass_shader
	m.set_shader_parameter("flower_color", color)
	m.set_shader_parameter("wind_strength", 0.1)
	return m


func setup(terrain: IslandTerrain) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var grass_mat := ShaderMaterial.new()
	grass_mat.shader = _grass_shader
	var near_mesh := make_blade_mesh(0.42, 0.055, 3)
	var far_mesh := make_blade_mesh(0.46, 0.12, 2)
	var flower_mesh := make_flower_mesh(0.3, 0.05)
	var flower_mats: Array[ShaderMaterial] = []
	for c in FLOWER_COLORS:
		flower_mats.append(_flower_material(c))

	var lo := -IslandTerrain.HALF
	var hi := IslandTerrain.HALF
	for cz in range(lo, hi, CHUNK):
		for cx in range(lo, hi, CHUNK):
			if _chunk_peak_mask(terrain, cx, cz) < 0.05:
				continue
			var origin := Vector3(cx, 0, cz)
			_add_layer(terrain, rng, cx, cz, NEAR_DENSITY, near_mesh, grass_mat, 0.0, NEAR_END, Vector2(0.85, 1.35), 1.0)
			_add_layer(terrain, rng, cx, cz, FAR_DENSITY, far_mesh, grass_mat, FAR_BEGIN, FAR_END, Vector2(0.9, 1.4), 1.0)
			for i in range(flower_mats.size()):
				_add_layer(terrain, rng, cx, cz, FLOWER_DENSITY[i], flower_mesh, flower_mats[i], 0.0, FLOWER_END, Vector2(0.8, 1.4), 0.9)


func _chunk_peak_mask(terrain: IslandTerrain, cx: int, cz: int) -> float:
	var peak := 0.0
	for dz in range(0, CHUNK + 1, 3):
		for dx in range(0, CHUNK + 1, 3):
			peak = maxf(peak, terrain.sample_grass(cx + dx, cz + dz))
	return peak


func _add_layer(terrain: IslandTerrain, rng: RandomNumberGenerator, cx: int, cz: int, density: float,
		mesh: Mesh, mat: ShaderMaterial, vis_begin: float, vis_end: float, scale_range: Vector2, mask_pow: float) -> void:
	var attempts := int(density * CHUNK * CHUNK)
	var buf := PackedFloat32Array()
	buf.resize(attempts * 12)
	var n := 0
	for k in range(attempts):
		var x := cx + rng.randf() * CHUNK
		var z := cz + rng.randf() * CHUNK
		var m := terrain.sample_grass(x, z)
		if m < 0.5 or rng.randf() > m * mask_pow:
			continue
		var y := terrain.sample_height(x, z) - 0.03
		var th := rng.randf() * TAU
		var s := rng.randf_range(scale_range.x, scale_range.y)
		var c := cos(th)
		var sn := sin(th)
		var o := n * 12
		buf[o + 0] = c
		buf[o + 1] = 0.0
		buf[o + 2] = sn
		buf[o + 3] = x
		buf[o + 4] = 0.0
		buf[o + 5] = s
		buf[o + 6] = 0.0
		buf[o + 7] = y
		buf[o + 8] = -sn
		buf[o + 9] = 0.0
		buf[o + 10] = c
		buf[o + 11] = z
		n += 1
	if n == 0:
		return
	buf.resize(n * 12)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = n
	mm.buffer = buf
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_begin = vis_begin
	mmi.visibility_range_begin_margin = 4.0 if vis_begin > 0.0 else 0.0
	mmi.visibility_range_end = vis_end
	mmi.visibility_range_end_margin = 4.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)
