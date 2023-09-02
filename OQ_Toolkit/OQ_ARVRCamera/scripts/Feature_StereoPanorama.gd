@tool
extends Node3D

@export var far := 64.0: set = set_far
@export var stereo_texture: Texture2D: set = set_stereo_texture

func set_stereo_texture(tex):
	stereo_texture = tex
	$ScreenQuad.get_surface_override_material(0).set_shader_parameter("stereo_image", tex);

func set_far(f):
	far = f;
	$ScreenQuad.position.z = -far;
	$ScreenQuad.scale.x = far*far;
	$ScreenQuad.scale.y = far*far;

func _ready():
	if (not get_parent() is XRCamera3D):
		vr.log_error("Feature_StereoPanorama: parent is not XRCamera3D");

	set_far(far);
	set_stereo_texture(stereo_texture);
	
