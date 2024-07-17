shader_type spatial;
render_mode cull_disabled,diffuse_burley,specular_schlick_ggx;

uniform vec4 color : source_color;
uniform sampler2D texture_emission : hint_default_black;

uniform float metallic;
uniform float roughness;
uniform float sub_emission_energy;

uniform bool cutted = false;
uniform float cut_dist_from_center = 0.0;
uniform float cut_vanish = 0.0;
uniform float cut_angle = 0.0;
uniform float cut_white_margin = 0.04;

uniform bool is_dot = false;

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
void vertex() {
	if (cutted) {
		float cut_line = cut_dist_from_center+(VERTEX*rotation3dZ(cut_angle)).x;
		cut_interp = cut_line;
		cut_interp -= cut_vanish;
	}
}

void fragment() {
	ALBEDO = color.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	
	vec2 dot_uv = vec2(UV.x+0.5, UV.y);
	EMISSION = (color.rgb * sub_emission_energy) + texture(texture_emission, is_dot ? dot_uv : UV).rgb;
	if (!FRONT_FACING)	EMISSION = vec3(1.0);
	
	if (cutted){
		// Discard all pixels "in the cut"
		if (cut_interp < 0.0) discard;
		
		// soft white margin
		EMISSION += vec3( smoothstep(cut_white_margin+0.01,cut_white_margin,cut_interp) );
		// hard white margin
		//EMISSION += vec3( float(cut_white_margin < cut_interp) );
	}
}
