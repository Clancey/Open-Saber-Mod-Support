extends Node3D

var is_extended = false

@onready var _mat : ShaderMaterial = $LightSaber_Mesh.material_override;

@onready var _anim = $AnimationPlayer
var saber_holder

func _ready():
	saber_holder = get_parent().get_parent()
	saber_holder.connect("saber_show", Callable(self, "_show"))
	saber_holder.connect("saber_hide", Callable(self, "_hide"))
	saber_holder.connect("saber_quickhide", Callable(self, "quickhide"))
	saber_holder.connect("saber_set_thickness", Callable(self, "set_thickness"))
	saber_holder.connect("saber_set_color", Callable(self, "set_color"))
	saber_holder.connect("saber_set_trail", Callable(self, "set_trail"))
	saber_holder.connect("saber_hit", Callable(self, "hit"))
	quickhide()
	_sub_ready()

func _sub_ready():
	pass
	
func set_color(color):
	_mat.set_shader_parameter("color", color);
	$tail.set_color(color)
func set_thickness(value):
	$LightSaber_Mesh.scale.x = value
	$LightSaber_Mesh.scale.y = value
func set_trail(enabled=true):
	$tail.visible = enabled

func _show():
	_anim.play("Show");
	is_extended = true;
	
func _hide():
	_anim.play("Hide");
	is_extended = false;
	
func quickhide():
	_anim.play("QuickHide");
	is_extended = false;

func hit(cube,time_offset):
	if time_offset>0.2 or time_offset<-0.05:
		$hitsound.play()
	else:
		if time_offset <= 0:
			$hitsound.play(-time_offset)
		else:
			await get_tree().create_timer(time_offset).timeout
			$hitsound.play()

