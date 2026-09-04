shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform float fill : hint_range(0.0, 1.0) = 0.5;
uniform vec4 bar_color : source_color = vec4(0.55, 2.4, 3.0, 1.0);
uniform vec4 low_color : source_color = vec4(3.5, 0.08, 0.04, 1.0);
uniform vec4 background_color : source_color = vec4(0.005, 0.01, 0.02, 0.72);

void fragment() {
	float border = 0.055;
	bool inside_border = (
		UV.x >= border
		&& UV.x <= 1.0 - border
		&& UV.y >= border
		&& UV.y <= 1.0 - border
	);
	float normalized_x = clamp((UV.x - border) / (1.0 - border * 2.0), 0.0, 1.0);
	bool filled = inside_border && normalized_x <= fill;
	float low_amount = 1.0 - smoothstep(0.20, 0.25, fill);
	float pulse = mix(0.65, 1.2, 0.5 + 0.5 * sin(TIME * 8.0));
	vec3 active_color = mix(bar_color.rgb, low_color.rgb * pulse, low_amount);
	vec4 color = filled ? vec4(active_color, 1.0) : background_color;
	ALBEDO = color.rgb;
	EMISSION = filled ? active_color * 1.4 : color.rgb * 0.05;
	ALPHA = color.a;
}
