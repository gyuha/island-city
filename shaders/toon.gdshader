// 계약 셰이더: 버텍스 컬러 × albedo (× 선택적 albedo_texture), 3단 램프,
// 청록 그림자 보정, 선택적 민트 림, 아웃라인 없음.
// 다른 역할은 ShaderMaterial로 참조만 한다. (전용 방향광 1개 기준으로 튜닝)
shader_type spatial;
render_mode specular_disabled;

#include "res://shaders/toon_ramp.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec2 uv_scale = vec2(1.0);
uniform bool faceted = false; // 로우폴리 바위 등: 면 단위 평면 셰이딩
uniform vec3 rim_color : source_color = vec3(0.80, 1.0, 0.93);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0; // 캐릭터에만 0.2~0.3

uniform bool path_blend = false;   // 지형 전용: COLOR.a = 길 가중치, 노이즈로 경계를 불규칙하게
uniform vec3 path_color : source_color = vec3(0.89, 0.82, 0.71);
varying vec3 wpos;

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
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV * uv_scale);
	vec3 base = albedo.rgb * COLOR.rgb * tex.rgb;
	if (path_blend) {
		float n = vnoise(wpos.xz * 1.3) * 0.5 + vnoise(wpos.xz * 4.1) * 0.25 - 0.375;
		float b = smoothstep(0.44, 0.56, COLOR.a + n * 0.55);
		base = mix(base, path_color * albedo.rgb, b);
	}
	ALBEDO = base;
	if (faceted) {
		NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	}
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color * rim * rim_strength;
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	DIFFUSE_LIGHT += toon_ramp(ndl, ATTENUATION) * LIGHT_COLOR / PI;
}
