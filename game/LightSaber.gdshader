shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float emission_strength : hint_range(1.0, 8.0) = 5.0;
uniform float flicker_amount : hint_range(0.0, 0.15) = 0.045;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float core = smoothstep(0.38, 0.92, facing);
	float halo = pow(1.0 - facing, 0.7);
	float length_wave = sin(UV.y * 36.0 + TIME * 31.0);
	length_wave += sin(UV.y * 83.0 - TIME * 47.0) * 0.5;
	float flicker = 1.0 + length_wave * flicker_amount;
	float tip = smoothstep(0.82, 1.0, UV.y);
	float tip_boost = 1.0 + tip * 0.18;

	vec3 saber_color = max(color.rgb, vec3(0.001));
	vec3 colored_halo = saber_color * (0.72 + halo * 0.48);
	vec3 white_core = mix(saber_color, vec3(1.0), core) * core;

	ALBEDO = mix(saber_color * 0.35, vec3(1.0), core);
	EMISSION = (colored_halo + white_core * 0.72) * emission_strength * flicker * tip_boost;
}
