shader_type spatial;
// Note body: a saturated, lightly glossy note
// body with a darkened rim (ENABLE_RIM_DIM), a subtle baked reflection and an
// optional plane cut with a white-hot edge for note debris (ENABLE_PLANE_CUT).
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float albedo_multiplier = 0.9;
uniform float emission_energy = 0.16;
uniform float rim_dim = 0.55;
uniform float rim_dim_power = 2.2;
uniform float roughness_value = 0.3;
uniform float metallic_value = 0.0;
uniform sampler2D reflection_texture : hint_default_black, filter_linear_mipmap;
uniform float reflection_intensity = 0.1;
uniform float cut_face_emission_energy = 2.5;

// plane cut (debris halves)
uniform bool cutted = false;
uniform float cut_dist_from_center = 0.0;
uniform float cut_vanish = 0.0;
uniform float cut_angle = 0.0;
uniform float cut_white_margin = 0.04;
uniform bool is_chain_head = false;

mat3 rotation3dZ(float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
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
		float cut_line = cut_dist_from_center + (VERTEX * rotation3dZ(cut_angle)).x;
		cut_interp = cut_line - cut_vanish;
	}
}

void fragment() {
	if (cutted && cut_interp < 0.0) {
		discard;
	}
	if (is_chain_head && chain_interp < 0.0) {
		discard;
	}

	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float facing = clamp(dot(n, v), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_dim_power);

	// Cheap "environment" reflection: a view-space matcap from the original game's
	// NotesReflection cubemap face.
	vec2 matcap_uv = n.xy * 0.5 + 0.5;
	vec3 reflection = texture(reflection_texture, matcap_uv).rgb;

	float cut_heat = 0.0;
	float chain_heat = 0.0;
	if (cutted) {
		cut_heat = 1.0 - smoothstep(0.0, cut_white_margin, abs(cut_interp));
	}
	if (is_chain_head) {
		chain_heat = 1.0 - smoothstep(0.0, cut_white_margin, abs(chain_interp));
	}
	float white_hot = max(cut_heat, chain_heat);

	vec3 body = color.rgb * albedo_multiplier * (1.0 - rim * rim_dim);
	if (FRONT_FACING) {
		ALBEDO = body;
		METALLIC = metallic_value;
		ROUGHNESS = roughness_value;
		SPECULAR = 0.35;
		EMISSION = color.rgb * emission_energy
			+ reflection * color.rgb * reflection_intensity
			+ mix(color.rgb, vec3(1.0), white_hot) * white_hot * cut_face_emission_energy;
	} else {
		// inside of a cut note: flat, slightly glowing cut face
		vec3 cut_face = mix(color.rgb * 0.7, vec3(1.0), white_hot);
		ALBEDO = cut_face;
		METALLIC = 0.0;
		ROUGHNESS = 1.0;
		EMISSION = cut_face * (0.35 + white_hot * cut_face_emission_energy);
	}
}
