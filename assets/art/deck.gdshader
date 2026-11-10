shader_type spatial;
render_mode specular_schlick_ggx;

varying vec3 world;
uniform vec4 base_color : source_color = vec4(0.235, 0.275, 0.295, 1.0);
uniform vec4 groove_color : source_color = vec4(0.125, 0.159, 0.175, 1.0);
uniform bool low_detail = false;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 panel = world.xz / vec2(3.0, 2.75);
	vec2 repeat_uv = fract(panel);
	vec2 edge = min(repeat_uv, 1.0 - repeat_uv);
	float seams = smoothstep(0.005, 0.014, min(edge.x, edge.y));
	float lane = step(16.0, abs(world.x));
	vec3 metal = base_color.rgb;
	float bolt = 0.0;
	if (!low_detail) {
		float hash = fract(sin(dot(floor(panel), vec2(127.1, 311.7))) * 43758.54);
		float grain = sin(world.x * 41.0 + sin(world.z * 31.0)) * sin(world.z * 42.0);
		bolt = 1.0 - smoothstep(0.010, 0.018, length(edge - vec2(0.055)));
		metal *= 0.91 + hash * 0.15 + grain * 0.023;
	}
	metal = mix(metal, metal * vec3(0.83, 0.98, 1.07), lane * 0.65);
	ALBEDO = mix(groove_color.rgb, metal, seams) * (1.0 - bolt * 0.36);
	ROUGHNESS = 0.86;
	METALLIC = 0.08;
}
