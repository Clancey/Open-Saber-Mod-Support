# This is a stand-alone version of the demo game Beep Saber. It started (and is still included)
# in the godot oculus quest toolkit (https://github.com/NeoSpark314/godot_oculus_quest_toolkit)
# But this stand-alone version as additional features and will be developed independently

extends Node

func _ready():
	var valid_refresh_rates = $Configuration.get_available_refresh_rates() as Array
	var refresh_rate = valid_refresh_rates[valid_refresh_rates.size()-1] if (valid_refresh_rates and valid_refresh_rates.size() > 0) else 0
	if refresh_rate == 0:
		refresh_rate = 90
	
	if OS.get_name() == "Android":
		$Configuration.set_render_target_size_multiplier(0.9)
		$Configuration.set_foveation_level(10,false)
		$Configuration.set_refresh_rate(refresh_rate)
	
		
	vr.initialize(true, refresh_rate);
	vr.log_info("valid_refresh_rates: "+str(valid_refresh_rates))
	vr.log_info("refresh_rate: "+str(refresh_rate))
	
	Engine.iterations_per_second = refresh_rate
	Engine.target_fps = refresh_rate
	OS.vsync_enabled = false
	
	#vr.set_display_refresh_rate(60);
	#Engine.target_fps = 60;
	
	vr.scene_switch_root = self;
	
	if (vr.inVR): vr.switch_scene("res://game/GodotSplash.tscn", 0.0, 0.0);
	vr.switch_scene("res://game/BeepSaber_Game.tscn", 0.1, 2.0);
