shader_type spatial;
render_mode unshaded;

varying vec4 light_data;

void vertex() {
	light_data = INSTANCE_CUSTOM;
}

void fragment() {
	ALBEDO = light_data.rgb;
}
