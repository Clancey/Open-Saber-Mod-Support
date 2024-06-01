# This is a stand-alone version of the demo game Beep Saber. It started (and is still included)
# in the godot oculus quest toolkit (https://github.com/NeoSpark314/godot_oculus_quest_toolkit)
# But this stand-alone version as additional features and will be developed independently

extends Node

func _ready() -> void:
	vr.initialize(1.0)
	vr.scene_switch_root = self
	vr.switch_scene("res://game/GodotSplash.tscn")
	await get_tree().create_timer(2.0).timeout
	vr.switch_scene("res://game/BeepSaber_Game.tscn")
