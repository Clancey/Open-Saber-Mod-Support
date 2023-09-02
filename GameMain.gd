# This is a stand-alone version of the demo game Beep Saber. It started (and is still included)
# in the godot oculus quest toolkit (https://github.com/NeoSpark314/godot_oculus_quest_toolkit)
# But this stand-alone version as additional features and will be developed independently

extends Node

func _ready():
	
	vr.scene_switch_root = self;
	
	if (vr.inVR): vr.switch_scene("res://game/GodotSplash.tscn", 0.0, 0.0);
	vr.switch_scene("res://game/BeepSaber_Game.tscn", 0.1, 2.0);
