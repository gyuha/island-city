class_name IslandTerrain
extends RefCounted
## 섬 지형 데이터: 높이 격자, 잔디 마스크, 버텍스 컬러 메시, HeightMap 충돌.
## 1 unit = 1 m, 해수면 Y=0. 격자 간격 1 m, 범위 ±HALF.

const HALF := 100
const N := HALF * 2 + 1
const ISLAND_RADII := Vector2(82.0, 68.0)
const LAKE_C := Vector2(-24.0, 12.0)
const LAKE_R := 13.0
const VILLAGE_C := Vector2(26.0, -10.0)
const PIER_X := 8.0

# 팔레트 (docs/art-style-prompts.md 1.3) — sRGB hex
const C_GRASS_A := Color("2a8a4a")
const C_GRASS_B := Color("33a04a")
const C_GRASS_HI := Color("5bb94f")
const C_PATH := Color("e4d2b4")
const C_SAND := Color("e4d2b4")
const C_SAND_DEEP := Color("d6bd94")
const C_SEABED_TEAL := Color("cfd9a2")

var heights := PackedFloat32Array()
var grass_mask := PackedFloat32Array()
var path_points: Array[Vector2] = []
var pier_shore_z := 0.0

var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _coast := FastNoiseLite.new()
var _edge := FastNoiseLite.new()


func _init() -> void:
	_hills.seed = 11
	_hills.frequency = 0.018
	_hills.fractal_octaves = 2
	_detail.seed = 23
	_detail.frequency = 0.09
	_coast.seed = 5
	_coast.frequency = 0.012
	_edge.seed = 41
	_edge.frequency = 0.22
	# 마을/호수 위치가 정해진 뒤 선착장 해안선을 찾고, 그에 맞춰 길을 정한다
	pier_shore_z = _find_shore_z(PIER_X)
	path_points = [
		Vector2(VILLAGE_C.x - 2.0, VILLAGE_C.y + 6.0),
		Vector2(18.0, 6.0),
		Vector2(12.0, 16.0),
		Vector2(PIER_X - 3.0, 26.0),
		Vector2(PIER_X + 1.0, pier_shore_z - 6.0),
		Vector2(PIER_X, pier_shore_z - 1.0),
	]


static func _smin(a: float, b: float, k: float) -> float:
	var h := clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, h) - k * h * (1.0 - h)


func height_at(x: float, z: float) -> float:
	var warp := _coast.get_noise_2d(x, z) * 0.10
	var d := Vector2(x / ISLAND_RADII.x, z / ISLAND_RADII.y).length() + warp
	var xs := d - 0.80
	var hills := 2.3 + (_hills.get_noise_2d(x, z) * 0.5 + 0.5) * 3.2 + _detail.get_noise_2d(x, z) * 0.25
	var h: float
	if xs > 0.0:
		h = -12.0 * (1.0 - exp(-xs * 1.6)) + _detail.get_noise_2d(x * 1.7, z * 1.7) * 0.12
	else:
		h = _smin(-xs * 14.0, hills, 1.2)
	# 석호: 내륙 호수 분지
	var rd := Vector2(x, z).distance_to(LAKE_C) / LAKE_R
	rd += _coast.get_noise_2d(x * 3.0, z * 3.0) * 0.18
	var lake_floor := -4.6 + 9.2 * smoothstep(0.45, 1.6, rd)
	h = _smin(h, lake_floor, 0.9)
	# 마을 구역 평탄화
	var dv := Vector2(x, z).distance_to(VILLAGE_C)
	h = lerpf(h, 3.4, 1.0 - smoothstep(9.0, 17.0, dv))
	# 메시 가장자리는 평평한 먼 바다 바닥(-12.2)으로
	var edge := maxf(absf(x), absf(z))
	h = lerpf(h, -12.2, smoothstep(86.0, 100.0, edge))
	return h


func _find_shore_z(x: float) -> float:
	var z := 20.0
	while z < 95.0 and height_at(x, z) > 0.0:
		z += 0.5
	return z


func path_weight(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 1e9
	for i in range(path_points.size() - 1):
		var a := path_points[i]
		var b := path_points[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	var width := 1.9 + _edge.get_noise_2d(x, z) * 0.7 + _hills.get_noise_2d(x * 4.0, z * 4.0) * 0.5
	return 1.0 - smoothstep(width - 1.2, width + 1.2, best)


func build() -> void:
	heights.resize(N * N)
	grass_mask.resize(N * N)
	for iz in range(N):
		for ix in range(N):
			heights[iz * N + ix] = height_at(ix - HALF, iz - HALF)
	for iz in range(N):
		for ix in range(N):
			var x := float(ix - HALF)
			var z := float(iz - HALF)
			var h: float = heights[iz * N + ix]
			var pw := path_weight(x, z) * smoothstep(0.9, 1.6, h)
			var g := smoothstep(1.3, 2.0, h) * (1.0 - smoothstep(0.38, 0.62, pw))
			grass_mask[iz * N + ix] = g


func sample_height(x: float, z: float) -> float:
	return _bilinear(heights, x, z)


func sample_grass(x: float, z: float) -> float:
	return _bilinear(grass_mask, x, z)


func _bilinear(arr: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf(x + HALF, 0.0, N - 1.001)
	var fz := clampf(z + HALF, 0.0, N - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var a := lerpf(arr[iz * N + ix], arr[iz * N + ix + 1], tx)
	var b := lerpf(arr[(iz + 1) * N + ix], arr[(iz + 1) * N + ix + 1], tx)
	return lerpf(a, b, tz)


func _vertex_color(x: float, z: float, h: float) -> Color:
	var n := _detail.get_noise_2d(x * 1.3, z * 1.3) * 0.5 + 0.5
	var grass := C_GRASS_A.lerp(C_GRASS_B, n)
	grass = grass.lerp(C_GRASS_HI, smoothstep(0.62, 0.9, _hills.get_noise_2d(x * 2.2, z * 2.2) * 0.5 + 0.5) * 0.5)
	var sand := C_SAND.lerp(C_SAND_DEEP, smoothstep(0.0, -6.0, h) * 0.35)
	sand = sand.lerp(C_SEABED_TEAL, smoothstep(-5.0, -9.0, h) * 0.2)
	sand = sand.lerp(sand.darkened(0.06), n * 0.5)
	# 모래 → 잔디 전이 (경계에 잔디가 불규칙하게 먹어 들어감)
	var edge_noise := _edge.get_noise_2d(x, z) * 0.35
	var sw := 1.0 - smoothstep(1.2, 1.7, h + edge_noise)
	var c := grass.lerp(sand, sw)
	# 흙길
	var pw := path_weight(x, z) * smoothstep(0.9, 1.6, h)
	var out := c.srgb_to_linear()
	out.a = pw # 길 가중치 — toon.gdshader(path_blend)가 노이즈 경계로 블렌드
	return out


func build_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	verts.resize(N * N)
	normals.resize(N * N)
	colors.resize(N * N)
	for iz in range(N):
		for ix in range(N):
			var i := iz * N + ix
			var x := float(ix - HALF)
			var z := float(iz - HALF)
			var h: float = heights[i]
			verts[i] = Vector3(x, h, z)
			var hl: float = heights[iz * N + maxi(ix - 1, 0)]
			var hr: float = heights[iz * N + mini(ix + 1, N - 1)]
			var hd: float = heights[maxi(iz - 1, 0) * N + ix]
			var hu: float = heights[mini(iz + 1, N - 1) * N + ix]
			normals[i] = Vector3(hl - hr, 2.0, hd - hu).normalized()
			colors[i] = _vertex_color(x, z, h)
	for iz in range(N - 1):
		for ix in range(N - 1):
			var a := iz * N + ix
			var b := a + 1
			var c := a + N
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func build_collision_shape() -> HeightMapShape3D:
	var shape := HeightMapShape3D.new()
	shape.map_width = N
	shape.map_depth = N
	shape.map_data = heights
	return shape
