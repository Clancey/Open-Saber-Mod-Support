shader_type spatial;
render_mode unshaded;

varying vec4 light_data;

void vertex() {
	light_data = INSTANCE_CUSTOM;
}

void fragment() {
	float edge_distance = min(
		min(UV.x, 1.0 - UV.x),
		min(UV.y, 1.0 - UV.y)
	);
	float soft_body = smoothstep(0.0, 0.22, edge_distance);
	float bright_core = smoothstep(0.18, 0.42, edge_distance);
	float visibility = clamp(light_data.a, 0.0, 1.0);
	vec3 idle_color = vec3(0.004, 0.006, 0.01);
	vec3 tube_color = idle_color + light_data.rgb * visibility;
	float emission_energy = mix(0.08, 2.7, visibility);
	ALBEDO = tube_color * (0.08 + soft_body * 0.18);
	EMISSION = tube_color * emission_energy * (0.28 + soft_body * 0.72 + bright_core * 0.75);
}
