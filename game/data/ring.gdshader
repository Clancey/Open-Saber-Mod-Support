shader_type spatial;
render_mode unshaded, cull_disabled;

uniform lowp vec4 ring_color : source_color = vec4(0.0);
uniform lowp vec3 chrome_color = vec3(0.018, 0.02, 0.026);
uniform lowp float idle_energy = 0.08;
uniform lowp float lit_energy = 2.2;

void fragment() {
	float fresnel = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.4);
	float light_level = max(ring_color.r, max(ring_color.g, ring_color.b));
	vec3 lit_color = chrome_color + ring_color.rgb * fresnel;
	ALBEDO = chrome_color + ring_color.rgb * 0.025;
	EMISSION = chrome_color * idle_energy + lit_color * fresnel * lit_energy * clamp(light_level, 0.0, 1.0);
}
