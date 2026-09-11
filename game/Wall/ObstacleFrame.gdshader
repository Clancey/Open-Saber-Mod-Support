shader_type spatial;
// Obstacle frame + fake glow, plus the core's additive color: bright edges on
// every face of the box, a soft additive halo around them and a faint fill.
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec4 color : source_color = vec4(1.0, 0.188, 0.188, 1.0);
uniform vec3 size = vec3(1.0);
uniform float edge_size = 0.05;
uniform float glow_size = 0.3;
uniform float edge_energy = 2.4;
uniform float glow_energy = 0.7;
uniform float add_color_multiplier = 0.2;

varying vec3 local_position_m;

void vertex() {
	// BoxMesh.size changes its vertices directly, so VERTEX is already in metres.
	local_position_m = VERTEX;
}

void fragment() {
	vec3 half_size = max(size * 0.5, vec3(0.0001));
	vec3 face_distance = max(half_size - abs(local_position_m), vec3(0.0));
	// the smallest distance is along the face normal; the middle one is the
	// distance to the nearest edge inside the face
	float d_min = min(face_distance.x, min(face_distance.y, face_distance.z));
	float d_max = max(face_distance.x, max(face_distance.y, face_distance.z));
	float edge_distance = face_distance.x + face_distance.y + face_distance.z - d_min - d_max;

	float edge = 1.0 - smoothstep(edge_size * 0.6, edge_size, edge_distance);
	float glow = pow(1.0 - clamp(edge_distance / glow_size, 0.0, 1.0), 2.0);
	vec3 edge_color = mix(color.rgb, vec3(1.0), 0.2);
	float fill = FRONT_FACING ? add_color_multiplier : add_color_multiplier * 0.5;
	ALBEDO = edge_color * edge * edge_energy + color.rgb * glow * glow_energy + color.rgb * fill;
	ALPHA = 1.0;
}
