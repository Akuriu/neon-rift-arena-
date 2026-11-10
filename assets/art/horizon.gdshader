shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled;

uniform vec4 zenith : source_color = vec4(0.08, 0.14, 0.20, 1.0);
uniform vec4 haze : source_color = vec4(0.40, 0.51, 0.55, 1.0);
uniform vec4 sun_tint : source_color = vec4(0.58, 0.42, 0.25, 1.0);
uniform vec3 sun_direction = vec3(-0.59, 0.28, -0.78);
uniform float cloud_amount = 0.3;
uniform bool low_detail = false;
varying vec3 direction;
varying vec3 vertex_sky;

vec3 gradient(vec3 ray) {
	float height = pow(clamp(max(ray.y, 0.0) * 1.65, 0.0, 1.0), 0.57);
	float light = max(dot(ray, normalize(sun_direction)), 0.0);
	float sun = pow(light, 24.0);
	return mix(mix(haze.rgb, zenith.rgb, height), sun_tint.rgb,
		sun * 0.39 + smoothstep(0.998, 0.9997, light) * 0.46);
}

void vertex() {
	direction = VERTEX;
	vertex_sky = gradient(normalize(VERTEX));
}

void fragment() {
	vec3 sky = vertex_sky;
	if (!low_detail) {
		vec3 ray = normalize(direction);
		sky = gradient(ray);
		vec2 flow = ray.xz / max(0.13, ray.y + 0.21);
		float veil = sin(flow.x * 3.6 + sin(flow.y * 1.8)) * 0.46 + sin(flow.y * 4.8 + flow.x * 1.9) * 0.32;
		float clouds = smoothstep(0.26, 0.67, veil) * smoothstep(0.025, 0.22, ray.y);
		sky = mix(sky, mix(haze.rgb, vec3(0.96), 0.41), clouds * cloud_amount);
	}
	ALBEDO = sky;
}
