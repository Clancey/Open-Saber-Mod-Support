shader_type spatial;
// Bomb: a dark, glossy spiked sphere with a faint
// red rim and a baked reflection.
render_mode cull_back, depth_draw_opaque, diffuse_lambert, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(0.283, 0.283, 0.283, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.031, 0.031, 1.0);
uniform float rim_power = 3.0;
uniform float rim_energy = 1.2;
uniform float albedo_multiplier = 0.1;
uniform float roughness_value = 0.12;
uniform sampler2D reflection_texture : hint_default_black, filter_linear_mipmap;
uniform float reflection_intensity = 0.12;
uniform bool custom_color = false;

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float facing = clamp(dot(n, v), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	vec2 matcap_uv = n.xy * 0.5 + 0.5;
	vec3 reflection = texture(reflection_texture, matcap_uv).rgb;

	vec3 base = color.rgb * albedo_multiplier;
	ALBEDO = base;
	METALLIC = 0.4;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.6;
	vec3 rim_glow = (custom_color ? color.rgb : rim_color.rgb) * rim * rim_energy;
	EMISSION = rim_glow + reflection * reflection_intensity + (custom_color ? color.rgb * 0.15 : vec3(0.0));
}
