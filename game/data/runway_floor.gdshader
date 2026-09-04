shader_type spatial;
render_mode unshaded;

uniform lowp vec4 base_color : source_color = vec4(0.015, 0.015, 0.025, 1.0);
uniform lowp vec4 left_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform lowp vec4 right_color : source_color = vec4(0.0, 0.0, 1.0, 1.0);
uniform lowp vec4 event_color : source_color = vec4(0.0);
uniform lowp float lane_spacing = 0.6;
uniform lowp float runway_half_width = 3.0;
uniform lowp float edge_width = 0.045;

varying highp vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 grid_coord = abs(fract(world_position.xz / lane_spacing + 0.5) - 0.5);
	float grid_distance = min(grid_coord.x, grid_coord.y) * lane_spacing;
	float grid_line = 1.0 - smoothstep(0.012, 0.026, grid_distance);
	float horizon = smoothstep(0.0, 48.0, -world_position.z);
	float edge_distance = abs(abs(world_position.x) - runway_half_width);
	float edge = 1.0 - smoothstep(edge_width, edge_width * 2.5, edge_distance);
	vec3 edge_color = mix(left_color.rgb, right_color.rgb, step(0.0, world_position.x));
	vec3 surface = base_color.rgb * mix(0.42, 0.9, horizon);
	surface += base_color.rgb * grid_line * 0.32;
	surface += event_color.rgb * 0.018;
	ALBEDO = surface;
	EMISSION = surface * 0.35 + edge_color * edge * 2.2;
}
