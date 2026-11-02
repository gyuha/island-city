// 약한 비네트 (포스트). 검정 대신 짙은 청록으로 가장자리를 눌러 그림자 규칙 유지.
shader_type canvas_item;

uniform vec3 edge_color : source_color = vec3(0.0627, 0.2431, 0.2196);
uniform float strength : hint_range(0.0, 1.0) = 0.22;
uniform float radius : hint_range(0.3, 1.2) = 0.85;

void fragment() {
	vec2 p = UV - 0.5;
	p.x *= 1.0;
	float v = smoothstep(radius * 0.5, radius * 0.95, length(p) * 1.414);
	COLOR = vec4(edge_color, v * strength);
}
