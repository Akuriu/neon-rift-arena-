shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled;

uniform vec4 zenith : source_color = vec4(0.08, 0.14, 0.20, 1.0);
uniform vec4 haze : source_color = vec4(0.40, 0.51, 0.55, 1.0);
uniform vec4 sun_tint : source_color = vec4(0.58, 0.42, 0.25, 1.0);
uniform vec3 sun_direction = vec3(-0.59, 0.28, -0.78);
varying vec3 direction;

void vertex() {
	direction = VERTEX;
}

void fragment() {
	vec3 ray = normalize(direction);
	float height = pow(clamp(abs(ray.y) * 1.55, 0.0, 1.0), 0.42);
	float sun = pow(max(dot(ray, normalize(sun_direction)), 0.0), 14.0);
	vec3 sky = mix(haze.rgb, zenith.rgb, height);
	ALBEDO = mix(sky, sun_tint.rgb, sun * 0.34);
}
