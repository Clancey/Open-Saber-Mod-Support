shader_type spatial;
// Beat Saber "The First" background (BloomPrePassBackgroundColorsGradient):
// a vertical gradient with a dark band of the left environment color below the
// horizon and a faint band of the right environment color at the horizon.
render_mode unshaded, cull_front, depth_draw_never;

uniform vec4 left_color : source_color = vec4(0.85, 0.085, 0.085, 1.0);
uniform vec4 right_color : source_color = vec4(0.188, 0.675, 1.0, 1.0);
uniform vec4 base_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float bottom_intensity = 0.25;
uniform float horizon_intensity = 0.1;
uniform float brightness = 1.0;
// kept for compatibility with the old background material
uniform float contrast = 1.0;
uniform float bg_0_intensity_mult = 1.0;
uniform float bg_1_intensity_mult = 1.0;
uniform float bg_2_intensity_mult = 1.0;
uniform float bg_3_intensity_mult = 1.0;
uniform float bg_4_intensity_mult = 1.0;

varying vec3 sphere_direction;

void vertex() {
	sphere_direction = normalize(VERTEX);
}

vec3 stop_color(float t, vec3 bottom, vec3 horizon) {
	// gradient stops from the original: 0.0 bottom, 0.1 bottom, 0.35 black,
	// 0.46 black, 0.5 horizon (exp 0.5), 1.0 black
	if (t < 0.1) {
		return bottom;
	} else if (t < 0.35) {
		return mix(bottom, vec3(0.0), (t - 0.1) / 0.25);
	} else if (t < 0.46) {
		return vec3(0.0);
	} else if (t < 0.5) {
		return mix(vec3(0.0), horizon, (t - 0.46) / 0.04);
	}
	float u = (t - 0.5) / 0.5;
	return mix(horizon, vec3(0.0), pow(u, 0.5));
}

void fragment() {
	float t = clamp(sphere_direction.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 bottom = left_color.rgb * bottom_intensity;
	vec3 horizon = right_color.rgb * horizon_intensity;
	ALBEDO = (stop_color(t, bottom, horizon) + base_color.rgb * 0.15) * brightness;
}
