shader_type spatial;
// Beat Saber's Parametric3SliceSprite with ENABLE_Y_AXIS_BILLBOARD: a soft
// glow strip that always faces the camera while staying aligned with the
// object's local Y axis (saber blades, neon tubes, lasers).
// Mesh: a unit QuadMesh (x in [-0.5, 0.5], y in [-0.5, 0.5]).
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 color : source_color = vec4(1.0, 0.0, 0.0, 0.6);
uniform sampler2D glow_texture : source_color, filter_linear_mipmap;
uniform float width = 0.1;
uniform float length = 1.0;
uniform float center = 0.0; // 0 = the strip starts at the origin, 0.5 = centered
uniform float intensity = 1.0;
uniform float fade = 1.0;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 axis = normalize((MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec3 to_camera = normalize(CAMERA_POSITION_WORLD - origin);
	vec3 side = cross(axis, to_camera);
	float side_length = length(side);
	if (side_length < 0.001) {
		side = vec3(1.0, 0.0, 0.0);
	} else {
		side /= side_length;
	}
	float along = (VERTEX.y + 0.5 - center) * length;
	vec3 world_position = origin + axis * along + side * (VERTEX.x * width);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world_position, 1.0)).xyz;
	NORMAL = (inverse(MODEL_MATRIX) * vec4(to_camera, 0.0)).xyz;
}

void fragment() {
	vec4 sample = texture(glow_texture, vec2(UV.x, UV.y));
	float alpha = sample.a * color.a * fade;
	ALBEDO = color.rgb * sample.rgb * alpha * intensity;
	ALPHA = alpha;
}
