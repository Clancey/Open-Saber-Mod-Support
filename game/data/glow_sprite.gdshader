shader_type spatial;
// Additive "baked glow" sprite (Beat Saber's NoteArrowGlow / NoteCircleGlow /
// SaberFakeGlow materials): a soft alpha texture tinted by a color.
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, depth_test_disabled;

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D glow_texture : source_color, filter_linear_mipmap;
uniform float intensity = 1.0;
uniform float fade = 1.0;

void fragment() {
	vec4 sample = texture(glow_texture, UV);
	float alpha = sample.a * color.a * fade;
	ALBEDO = color.rgb * sample.rgb * alpha * intensity;
	ALPHA = alpha;
}
