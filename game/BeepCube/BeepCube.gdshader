shader_type spatial;
render_mode cull_disabled, blend_mix, depth_prepass_alpha, diffuse_burley, specular_schlick_ggx;

uniform vec4 color : source_color;
uniform sampler2D texture_emission : hint_default_black;

uniform float metallic;
uniform float roughness;
uniform float sub_emission_energy;
uniform float symbol_emission_energy = 3.6;
uniform float rim_emission_energy = 0.55;
uniform float cut_face_emission_energy = 4.0;
uniform float edge_darkening = 0.28;
uniform float bottom_darkening = 0.18;

uniform bool cutted = false;
uniform float cut_dist_from_center = 0.0;
uniform float cut_vanish = 0.0;
uniform float cut_angle = 0.0;
uniform float cut_white_margin = 0.04;

uniform bool is_dot = false;
uniform bool is_chain_head = false;

// [firepal]TODO: Build matrix on CPU (I tried but couldn't')
mat3 rotation3dZ(float angle) {
	float s = sin(angle);
	float c = cos(angle);

	return mat3(
		vec3(c, s, 0.0),
		vec3(-s, c, 0.0),
		vec3(0.0, 0.0, 1.0)
	);
}

varying float cut_interp;
varying float chain_interp;
void vertex() {
	cut_interp = 1.0;
	chain_interp = 1.0;

	if (is_chain_head) {
		chain_interp = 0.1 + VERTEX.y;
	}
	if (cutted) {
		float cut_line = cut_dist_from_center+(VERTEX*rotation3dZ(cut_angle)).x;
		cut_interp = cut_line - cut_vanish;
	}
}

void fragment() {
	float visibility = 1.0;
	if (cutted) {
		visibility *= step(0.0, cut_interp);
	}
	if (is_chain_head) {
		visibility *= step(0.0, chain_interp);
	}
	ALPHA = visibility;

	float edge = smoothstep(0.55, 1.0, max(abs(UV.x - 0.5), abs(UV.y - 0.5)) * 2.0);
	float bottom = 1.0 - smoothstep(0.0, 0.55, UV.y);
	float body_shade = 1.0 - edge * edge_darkening - bottom * bottom_darkening;
	vec3 body_color = color.rgb * body_shade;

	float facing = max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);
	float fresnel = 1.0 - facing;
	float fresnel_squared = fresnel * fresnel;
	float rim = fresnel_squared * fresnel_squared;
	vec3 rim_color = mix(color.rgb, vec3(1.0), 0.32);

	vec2 symbol_uv = UV;
	if (is_dot) {
		symbol_uv.x += 0.5;
	}
	vec3 symbol_sample = texture(texture_emission, symbol_uv).rgb;
	float symbol_mask = max(symbol_sample.r, max(symbol_sample.g, symbol_sample.b));

	float cut_heat = 0.0;
	float chain_heat = 0.0;
	if (cutted) {
		cut_heat = 1.0 - smoothstep(0.0, cut_white_margin + 0.025, abs(cut_interp));
	}
	if (is_chain_head) {
		chain_heat = 1.0 - smoothstep(0.0, cut_white_margin + 0.02, abs(chain_interp));
	}
	float white_hot = max(cut_heat, chain_heat);

	ALBEDO = mix(body_color, rim_color, rim * 0.16);
	METALLIC = metallic;
	ROUGHNESS = roughness;
	if (FRONT_FACING) {
		vec3 inner_glow = color.rgb * sub_emission_energy;
		vec3 symbol_glow = vec3(symbol_mask * symbol_emission_energy);
		vec3 rim_glow = rim_color * rim * rim_emission_energy;
		vec3 cut_glow = mix(color.rgb, vec3(1.0), white_hot) * white_hot * cut_face_emission_energy;
		EMISSION = inner_glow + symbol_glow + rim_glow + cut_glow;
	} else {
		vec3 hot_surface = mix(color.rgb * 0.65, vec3(1.0), white_hot);
		ALBEDO = hot_surface;
		EMISSION = hot_surface * cut_face_emission_energy;
	}
}
