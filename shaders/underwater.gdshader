// 수중 화면 효과 (CanvasLayer + ColorRect용). 밝고 어둡지 않게:
// #57d3b6 안개 틴트 + 굵은 god ray. 색수차 없음.
// 거리 안개는 island.gd가 Environment fog(#57d3b6)로 함께 켠다.
shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform vec3 fog_color : source_color = vec3(0.3412, 0.8275, 0.7137); // #57d3b6
uniform vec3 ray_color : source_color = vec3(0.86, 1.0, 0.92);
uniform float haze = 0.1;
uniform float ray_strength = 0.3;
uniform float ray_count = 5.0;     // 화면 폭당 굵은 광선 수 (굵게 = 적게)
uniform float ray_slant = 0.28;    // 광선 기울기
uniform float ray_speed = 0.06;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}
float vnoise1(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash11(i), hash11(i + 1.0), f);
}

void fragment() {
	vec3 scene = texture(screen_tex, SCREEN_UV).rgb;
	vec2 uv = UV;
	// 약한 안개 틴트 (밝기를 올리는 방향)
	vec3 col = mix(scene, fog_color, haze);
	col += fog_color * 0.06;

	// 굵은 god ray: 위에서 아래로 사선 + 아래로 갈수록 소멸
	float x = (uv.x + uv.y * ray_slant) * ray_count;
	float r = vnoise1(x + TIME * ray_speed * ray_count) * 0.65 + vnoise1(x * 0.5 - TIME * ray_speed * 2.0) * 0.35;
	float shaft = smoothstep(0.45, 0.85, r);
	float falloff = pow(1.0 - uv.y, 1.4);
	col += ray_color * shaft * falloff * ray_strength;

	COLOR = vec4(col, 1.0);
}
