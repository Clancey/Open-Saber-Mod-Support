shader_type spatial;
// Beat Saber saber handle ("Handle" material, Custom/SimpleLit): a dark
// glossy grip lit by a colored rim light.
render_mode cull_back, depth_draw_opaque, diffuse_lambert, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float base_brightness = 0.12;
uniform float rim_power = 2.5;
uniform float rim_energy = 1.4;
uniform float roughness_value = 0.25;

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	vec3 base = mix(vec3(0.06), color.rgb * 0.5, 0.35) * base_brightness / 0.12;
	ALBEDO = base;
	METALLIC = 0.6;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.5;
	EMISSION = color.rgb * rim * rim_energy + base * 0.15;
}
