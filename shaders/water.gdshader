// 수면 (해수면 Y=0 평면). 깊이 기반 #57d3b6 → #13b4c3 → #2597b1, 해안선 폼 띠,
// 흰 원형 물결 링, 수면 아래 바닥이 비치는 투명도.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec3 shallow_color : source_color = vec3(0.3412, 0.8275, 0.7137);  // #57d3b6
uniform vec3 mid_color : source_color = vec3(0.0745, 0.7059, 0.7647);      // #13b4c3
uniform vec3 deep_color : source_color = vec3(0.1451, 0.5922, 0.6941);     // #2597b1
uniform vec3 foam_color : source_color = vec3(1.0);
uniform vec3 underside_color : source_color = vec3(0.3412, 0.8275, 0.7137);
uniform float mid_depth = 0.9;      // 이 수심에서 mid_color
uniform float deep_depth = 2.6;     // 이 수심에서 deep_color
uniform float alpha_shallow = 0.55; // 얕은 곳: 바닥이 거의 그대로 비침
uniform float alpha_deep = 0.92;
uniform float clear_depth = 2.2;    // 이 수심까지 alpha가 shallow → deep으로 오름
uniform float foam_width = 0.55;
uniform float ring_cell = 7.0;     // 원형 물결 링 격자 크기 (m)
uniform float ring_speed = 0.12;
uniform float ring_width = 0.05;  // 링 두께 (m)
uniform float ring_strength = 0.85;
uniform float sparkle_strength = 0.9;
uniform float saturation_boost = 1.25;
uniform float water_level = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
vec2 hash22(vec2 p) {
	return vec2(hash21(p), hash21(p + 17.7));
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 wxz = v_world.xz;

	if (!FRONT_FACING) {
		// 수중에서 올려다본 수면: 밝은 청록 천장
		float n = vnoise(wxz * 0.35 + TIME * 0.08);
		ALBEDO = mix(underside_color, vec3(0.85, 1.0, 0.95), n * 0.5);
		ALPHA = 0.9;
	} else {
		// 장면 깊이 복원 → 수면 아래 바닥의 월드 Y
		float d = texture(depth_tex, SCREEN_UV).r;
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, d);
		vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		view.xyz /= view.w;
		vec3 floor_world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
		float depth = max(water_level - floor_world.y, 0.0); // 수직 수심

		// 깊이 기반 3색 혼합
		vec3 col = mix(shallow_color, mid_color, smoothstep(0.0, mid_depth, depth));
		col = mix(col, deep_color, smoothstep(mid_depth, deep_depth, depth));

		// 느린 명암 얼룩 (페인터리)
		float n = vnoise(wxz * 0.22 + vec2(TIME * 0.03, -TIME * 0.02)) * 0.6 + vnoise(wxz * 0.7 - TIME * 0.05) * 0.4;
		col = mix(col, col * 0.88 + vec3(0.0, 0.05, 0.04), smoothstep(0.35, 0.75, n) * 0.6);

		float alpha = mix(alpha_shallow, alpha_deep, smoothstep(0.0, clear_depth, depth));

		// 해안선 폼 띠
		float wob = vnoise(wxz * 0.9 + TIME * 0.25) * 0.35 + 0.65 * (0.5 + 0.5 * sin(TIME * 1.1 + wxz.x * 0.6 + wxz.y * 0.4));
		float fw = foam_width * (0.55 + 0.6 * wob);
		float foam = 1.0 - smoothstep(fw * 0.45, fw, depth);
		// 바닥 지오메트리가 없는 곳(깊이 0)은 폼 제외
		foam *= step(0.0001, d);

		// 흰 원형 물결 링: 격자 셀마다 하나씩 퍼지는 링
		float ring = 0.0;
		vec2 cell = floor(wxz / ring_cell);
		for (int i = -1; i <= 1; i++) {
			for (int j = -1; j <= 1; j++) {
				vec2 c = cell + vec2(float(i), float(j));
				vec2 r = hash22(c);
				if (r.x > 0.16) continue; // 일부 셀만 링을 가짐
				vec2 center = (c + 0.2 + 0.6 * hash22(c + 3.1)) * ring_cell;
				float life = fract(TIME * ring_speed + r.y);
				float radius = 0.15 + life * 0.85; // 최대 지름 약 2m
				float dist = length(wxz - center);
				float band = 1.0 - smoothstep(0.0, ring_width, abs(dist - radius));
				ring += band * (1.0 - life) * smoothstep(0.0, 0.1, life);
			}
		}
		ring = clamp(ring, 0.0, 1.0) * ring_strength * (1.0 - foam);

		// 작은 반짝임 하이라이트
		vec2 sc = floor(wxz * 2.2);
		float tw = hash21(sc);
		vec2 sf = fract(wxz * 2.2) - 0.5;
		float spark = smoothstep(0.17, 0.0, length(sf)) * step(0.86, tw) * (0.5 + 0.5 * sin(TIME * 2.5 + tw * 40.0));
		col += vec3(0.8, 1.0, 0.95) * spark * sparkle_strength;
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		col = clamp(mix(vec3(lum), col, saturation_boost), 0.0, 1.5);
		col = mix(col, foam_color, max(foam * 0.8, ring));
		alpha = mix(alpha, 1.0, max(foam, ring * 0.6));
		alpha *= smoothstep(0.0, 0.03, depth + foam); // 해안선에서 부드럽게 사라짐
		ALBEDO = col;
		ALPHA = clamp(alpha, 0.0, 1.0);
	}
}
