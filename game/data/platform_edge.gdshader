shader_type spatial;
render_mode unshaded;

uniform lowp vec4 left_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform lowp vec4 right_color : source_color = vec4(0.0, 0.0, 1.0, 1.0);
uniform lowp float edge_energy = 3.0;

varying highp float world_x;

void vertex() {
	world_x = (MODEL_MATRIX * vec4(VERTEX, 1.0)).x;
}

void fragment() {
	vec3 edge_color = mix(left_color.rgb, right_color.rgb, smoothstep(-0.04, 0.04, world_x));
	ALBEDO = edge_color * 0.3;
	EMISSION = edge_color * edge_energy;
}
