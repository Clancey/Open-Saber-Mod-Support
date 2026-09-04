shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 body_color : source_color = vec4(0.008, 0.006, 0.008, 1.0);
uniform vec4 rim_color : source_color = vec4(0.75, 0.035, 0.008, 1.0);
uniform float rim_emission_energy = 0.7;
uniform float pulse_speed = 1.35;
uniform float shell_grow = 0.018;

void vertex() {
	VERTEX += NORMAL * shell_grow;
}

void fragment() {
	float facing = max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);
	float fresnel = 1.0 - facing;
	float fresnel_squared = fresnel * fresnel;
	float rim = fresnel_squared * fresnel;
	float pulse = 0.78 + sin(TIME * pulse_speed) * 0.22;

	ALBEDO = body_color.rgb;
	EMISSION = body_color.rgb * 0.08 + rim_color.rgb * rim * pulse * rim_emission_energy;
}
