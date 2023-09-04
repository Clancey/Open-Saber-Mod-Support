shader_type spatial;
render_mode cull_disabled, unshaded;

uniform vec4 color;
uniform int size;

void fragment(){
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	if (int((SCREEN_UV.x*1000.0)+(SCREEN_UV.y*1000.0))%size==0){
		ALPHA = 0.0;
	}else{
		ALBEDO = color.rgb;
	}
}