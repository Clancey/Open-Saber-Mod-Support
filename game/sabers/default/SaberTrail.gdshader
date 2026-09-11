shader_type spatial;
// Saber trail: additive vertex-colored
// strip that fades with age (FullTrail texture), with a short white section
// right behind the blade.
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform sampler2D trail_texture : source_color, filter_linear_mipmap;
uniform float intensity = 1.0;

void fragment() {
	// UV.x: position across the blade, UV.y: age along the trail (0 = newest).
	// The texture is bright at its bottom row (newest) and black at the top.
	float age_fade = texture(trail_texture, vec2(UV.x, 1.0 - UV.y)).r;
	vec3 trail_color = mix(vec3(1.0), color.rgb, COLOR.r);
	float alpha = age_fade * COLOR.a;
	ALBEDO = trail_color * alpha * intensity;
	ALPHA = alpha;
}
