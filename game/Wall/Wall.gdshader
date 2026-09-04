shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, unshaded;

uniform vec4 albedo_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec3 size = vec3(1.0);
uniform float edge_thickness = 0.03;
uniform float edge_glow = 3.0;
uniform float face_alpha = 0.3;
uniform float fresnel_power = 3.0;
uniform float fresnel_strength = 0.6;

varying vec3 local_position_m;

void vertex() {
	// BoxMesh.size changes its vertices directly, so VERTEX is already in metres.
	local_position_m = VERTEX;
}

void fragment() {
	vec3 half_size = max(size * 0.5, vec3(0.0001));
	vec3 face_distance = max(half_size - abs(local_position_m), vec3(0.0));
	vec3 face_proximity = vec3(1.0) - smoothstep(
		vec3(0.0),
		vec3(edge_thickness),
		face_distance
	);
	float edge_mask = max(
		max(face_proximity.x * face_proximity.y, face_proximity.x * face_proximity.z),
		face_proximity.y * face_proximity.z
	);

	float normalized_height = clamp(local_position_m.y / size.y + 0.5, 0.0, 1.0);
	float inner_fog = 1.0 - abs(normalized_height * 2.0 - 1.0);
	float volume_shading = 0.72 + normalized_height * 0.16 + inner_fog * 0.12;

	float view_facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float fresnel = pow(1.0 - clamp(view_facing, 0.0, 1.0), fresnel_power);
	vec3 tint = albedo_color.rgb;

	ALBEDO = tint * volume_shading;
	EMISSION = tint * (edge_glow * edge_mask + fresnel_strength * fresnel);
	ALPHA = mix(face_alpha, 1.0, edge_mask);
}
