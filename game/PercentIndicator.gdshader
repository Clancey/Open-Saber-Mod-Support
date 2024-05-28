shader_type spatial;
render_mode unshaded, cull_back;
uniform float how_full;

void fragment() {
	if (how_full < 0.005) {
		ALPHA = 0.0;
	} else  {
		float x = UV.x - 0.5;
		float y = UV.y - 0.5;
		float dist_from_center_squared = x*x + y*y;
		if (dist_from_center_squared <= 0.125 || dist_from_center_squared > 0.25) {
			ALPHA = 0.0;
		} else if (how_full >= 0.995) {
			ALPHA = 1.0;
		} else {
			float angle = atan(x,y) + PI;
			ALPHA = float(angle <= how_full * TAU);
		}
	}
}
