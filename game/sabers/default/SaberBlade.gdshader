shader_type spatial;
// Saber blade: a white-hot core that tints
// toward the saber color at the edges and blooms strongly.
// Unshaded: the HDR color goes straight into ALBEDO so the glow pass picks it up.
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec4 color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform sampler2D noise_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float core_energy = 5.0;
uniform float edge_energy = 2.2;
uniform float noise_strength = 0.12;
uniform float noise_speed = 2.5;

void fragment() {
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float core = pow(facing, 1.6);
	float noise = texture(noise_texture, vec2(UV.x * 2.0, UV.y * 6.0 - TIME * noise_speed)).r;
	float flicker = 1.0 + (noise - 0.5) * noise_strength;
	vec3 tint = mix(color.rgb, vec3(1.0), 0.15);
	ALBEDO = mix(tint * edge_energy, vec3(core_energy), core) * flicker;
}
