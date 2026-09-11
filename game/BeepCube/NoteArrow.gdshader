shader_type spatial;
// Note arrow, glowing white:
// a flat, self-lit white shape that blooms.
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float emission_energy = 2.0;

void fragment() {
	ALBEDO = color.rgb * emission_energy;
}
