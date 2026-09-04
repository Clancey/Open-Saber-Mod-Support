shader_type spatial;
render_mode unshaded;

uniform sampler2D burn_texture : source_color;
uniform lowp vec4 base_color : source_color = vec4(0.015, 0.015, 0.025, 1.0);
uniform lowp float burn_energy = 12.0;

void fragment() {
	vec3 burn = texture(burn_texture, UV).rgb;
	vec2 grid_coord = abs(fract(UV * 3.333333 + 0.5) - 0.5);
	float grid_line = 1.0 - smoothstep(0.018, 0.045, min(grid_coord.x, grid_coord.y));
	vec3 surface = base_color.rgb * (0.68 + grid_line * 0.22);
	ALBEDO = surface;
	EMISSION = surface * 0.45 + burn * burn_energy;
}
