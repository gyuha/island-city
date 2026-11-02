// 공용 셀 램프 (toon.gdshader, grass.gdshader가 include).
// 3단: 그림자(청록-짙은 초록) / 중간 / 밝음. 경계는 smoothstep 폭 ~0.08.
// 그림자 쪽은 회색·검정이 아니라 #256d4b~#2b8277 방향으로 곱해진다.

uniform vec3 shade_tint : source_color = vec3(0.34, 0.70, 0.60);
uniform vec3 mid_tint : source_color = vec3(0.72, 0.92, 0.84);
uniform vec3 lit_tint : source_color = vec3(1.0, 1.0, 0.96);
uniform float ramp_low = 0.34;
uniform float ramp_high = 0.68;
uniform float ramp_softness : hint_range(0.02, 0.1) = 0.04; // smoothstep 반폭 (전체 폭 = 2배)

vec3 toon_ramp(float ndotl, float atten) {
	float h = ndotl * 0.5 + 0.5; // half-lambert: 어두운 면도 완전히 죽지 않게
	h *= smoothstep(0.0, 0.25, atten); // 드롭섀도는 가장 어두운 단으로
	float s1 = smoothstep(ramp_low - ramp_softness, ramp_low + ramp_softness, h);
	float s2 = smoothstep(ramp_high - ramp_softness, ramp_high + ramp_softness, h);
	return mix(mix(shade_tint, mid_tint, s1), lit_tint, s2);
}
