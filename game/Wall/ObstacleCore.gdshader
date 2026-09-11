shader_type spatial;
// Obstacle core (screen displacement): the scene
// behind the wall shows through tinted toward the obstacle color. Rendered
// with multiplicative blending so the tint also applies when the camera is
// inside the wall; the additive color, frame and glow are a second pass.
render_mode blend_mul, depth_draw_never, cull_back, unshaded;

uniform vec4 color : source_color = vec4(1.0, 0.188, 0.188, 1.0);
uniform float lerp_to_white = 0.75;
uniform float fresnel_power = 2.5;
uniform float fresnel_darken = 0.35;

void fragment() {
	vec3 tint = mix(color.rgb, vec3(1.0), lerp_to_white);
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, fresnel_power);
	ALBEDO = tint * (1.0 - fresnel * fresnel_darken);
	ALPHA = 1.0;
}
