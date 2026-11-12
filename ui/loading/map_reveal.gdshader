shader_type canvas_item;

uniform float opening = -0.04;

void fragment() {
	float edge = abs(UV.x * 2.0 - 1.0);
	COLOR.a *= smoothstep(opening - 0.03, opening + 0.03, edge);
}
