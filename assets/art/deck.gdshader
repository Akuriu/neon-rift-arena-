shader_type spatial;
render_mode vertex_lighting, specular_disabled;

varying vec3 world;
uniform vec4 base_color : source_color = vec4(0.235, 0.275, 0.295, 1.0);
uniform vec4 groove_color : source_color = vec4(0.125, 0.159, 0.175, 1.0);
uniform bool low_detail = false;
uniform bool ground_path = false;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 panel = world.xz / vec2(3.0, 2.75);
	vec2 repeat_uv = fract(panel);
	vec2 edge = min(repeat_uv, 1.0 - repeat_uv);
	float footprint = max(fwidth(panel.x), fwidth(panel.y));
	float seams = mix(smoothstep(0.006, 0.014 + footprint, min(edge.x, edge.y)), 0.93, smoothstep(0.09, 0.38, footprint));
	float lane = step(16.0, abs(world.x));
	vec3 metal = base_color.rgb;
	float bolt = 0.0;
	if (!low_detail) {
		float hash = fract(sin(dot(floor(panel), vec2(127.1, 311.7))) * 43758.54);
		float grain = sin(world.x * 25.0 + sin(world.z * 21.0)) * sin(world.z * 23.0) * (1.0 - smoothstep(0.006, 0.09, footprint));
		bolt = 1.0 - smoothstep(0.010, 0.018, length(edge - vec2(0.055)));
		metal *= 0.91 + hash * 0.15 + grain * 0.023;
	}
	metal = mix(metal, metal * vec3(0.83, 0.98, 1.07), lane * 0.65);
	if (ground_path) {
		float trail = 1.0 - smoothstep(3.4, 5.8, abs(world.x + 1.4 * sin(world.z * 0.24)));
		metal = mix(metal * vec3(0.71, 0.95, 0.61), metal * vec3(1.24, 1.07, 0.86), trail);
		seams = mix(1.0, seams, trail * 0.18);
		bolt = 0.0;
	}
	ALBEDO = mix(groove_color.rgb, metal, seams) * (1.0 - bolt * 0.36);
	ROUGHNESS = 0.79 + (1.0 - seams) * 0.18;
	METALLIC = 0.08;
}
