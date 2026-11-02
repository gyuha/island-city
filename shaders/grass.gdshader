// 블레이드 단위 GPU 잔디 (MultiMesh). 뿌리 #256d4b → 끝 #c1e6a8,
// 노이즈 기반 한 방향 바람. 같은 셰이더가 꽃(UV.x=1 머리 부분)도 그린다.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

#include "res://shaders/toon_ramp.gdshaderinc"

uniform vec3 root_color : source_color = vec3(0.1451, 0.4275, 0.2941);  // #256d4b
uniform vec3 mid_color : source_color = vec3(0.2078, 0.6275, 0.3294);   // 청록 쪽 중간 초록
uniform vec3 tip_color : source_color = vec3(0.7569, 0.9020, 0.6588);   // #c1e6a8
uniform vec3 flower_color : source_color = vec3(1.0);                    // 꽃 머리 색 (재질마다 흰/노랑/분홍)
uniform vec2 wind_dir = vec2(1.0, 0.35);       // 한 방향
uniform float wind_strength = 0.2;            // 끝이 쏠리는 양 (블레이드 높이에 비례)
uniform float wind_speed = 0.9;
uniform float wind_scale = 0.045;              // 바람 패턴 공간 주파수
uniform float tint_variation = 0.5;           // 블레이드별 명도 변화
uniform float mid_pos = 0.42;

varying float v_t;
varying float v_head;
varying float v_var;
varying float v_gust;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	v_t = clamp(UV.y, 0.0, 1.0);
	v_head = UV.x;
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_var = hash21(origin.xz * 7.13);

	vec2 d = normalize(wind_dir);
	// 바람 패턴이 한 방향으로 흘러가는 노이즈
	float n = vnoise(origin.xz * wind_scale * 6.0 - d * TIME * wind_speed * 0.6);
	n += 0.5 * vnoise(origin.xz * wind_scale * 14.0 - d * TIME * wind_speed * 1.3);
	float gust = n / 1.5;
	v_gust = gust;
	float bend = (0.7 + gust) * wind_strength * v_t * v_t;
	// 월드 방향 → 모델 공간
	vec3 wdir = vec3(d.x, 0.0, d.y);
	vec3 local_dir = normalize(transpose(mat3(MODEL_MATRIX)) * wdir);
	float scl = length(MODEL_MATRIX[1].xyz);
	VERTEX += local_dir * bend / max(scl, 0.001);
	VERTEX.y -= abs(bend) * 0.25 * v_t / max(scl, 0.001);
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec3 col = mix(root_color, mid_color, smoothstep(0.0, mid_pos, v_t));
	col = mix(col, tip_color, smoothstep(mid_pos, 1.0, v_t) * 0.7);
	col *= 1.0 + (v_var - 0.5) * tint_variation;
	col = mix(col, tip_color, clamp(v_gust - 0.5, 0.0, 1.0) * 0.4 * v_t); // 돌풍 때 밝게
	col = mix(col, flower_color, step(0.5, v_head));
	ALBEDO = col;
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT += toon_ramp(dot(NORMAL, LIGHT), ATTENUATION) * LIGHT_COLOR / PI;
}
