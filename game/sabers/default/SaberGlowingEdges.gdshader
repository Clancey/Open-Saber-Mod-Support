shader_type spatial;
// Saber glowing edges: thin colored strips
// along the blade and handle that glow in the saber color.
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec4 color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 3.0;

void fragment() {
	ALBEDO = color.rgb * emission_energy;
}
