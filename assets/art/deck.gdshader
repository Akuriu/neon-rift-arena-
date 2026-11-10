shader_type spatial;
render_mode vertex_lighting, specular_disabled;

varying vec3 world;
uniform vec4 base_color : source_color = vec4(0.50, 0.48, 0.43, 1.0);
uniform vec4 groove_color : source_color = vec4(0.34, 0.32, 0.29, 1.0);
uniform sampler2D aggregate : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool low_detail = false;
uniform bool ground_path = false;
uniform float joint_scale = 0.0;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float surface = texture(aggregate, world.xz * 0.73).r;
	float weathering = texture(aggregate, world.xz * 0.103 + vec2(0.31, 0.62)).r;
	vec3 finish = base_color.rgb * (0.53 + 0.43 * surface + 0.34 * weathering);
	if (ground_path) {
		float trail = 1.0 - smoothstep(2.8, 5.5, abs(world.x + 1.25 * sin(world.z * 0.22)));
		finish = mix(finish * vec3(0.68, 0.76, 0.61), finish * vec3(0.98, 0.91, 0.81), trail);
	}
	if (joint_scale > 0.0) {
		vec2 panel = world.xz * joint_scale;
		vec2 edge = abs(fract(panel + 0.5) - 0.5);
		float aa = clamp(max(fwidth(panel.x), fwidth(panel.y)), 0.002, 0.10);
		float face = smoothstep(0.004, 0.004 + aa, min(edge.x, edge.y));
		finish = mix(groove_color.rgb, finish, face);
	}
	ALBEDO = finish * 0.71;
	ROUGHNESS = 0.93;
}
