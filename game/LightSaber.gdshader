shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float emission_strength : hint_range(1.0, 8.0) = 5.0;
uniform float flicker_amount : hint_range(0.0, 0.15) = 0.045;

void fragment() {
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 1.15);
	float core = pow(1.0 - fresnel, 24.0);
	float halo = pow(fresnel, 0.65);
	float length_wave = sin(UV.y * 36.0 + TIME * 31.0);
	length_wave += sin(UV.y * 83.0 - TIME * 47.0) * 0.5;
	float flicker = 1.0 + length_wave * flicker_amount;
	float tip = smoothstep(0.82, 1.0, UV.y);
	float tip_boost = 1.0 + tip * 0.18;

	vec3 saber_color = max(color.rgb, vec3(0.001));
	float strength_scale = emission_strength / 5.0;
	vec3 colored_halo = saber_color * mix(1.35, 3.0, halo);
	vec3 white_core = vec3(7.0) * core;

	ALBEDO = mix(saber_color * 0.42, vec3(1.0), core * 0.9);
	EMISSION = (colored_halo + white_core) * strength_scale * flicker * tip_boost;
}
