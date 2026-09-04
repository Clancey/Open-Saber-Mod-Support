extends Node

func get_str(dict: Dictionary, key: String, default: String, platform_defaults: Dictionary = {}) -> String:
	if dict.has(key) and dict[key] is String:
		@warning_ignore("unsafe_cast")
		return dict[key] as String
	if OS.get_name() in platform_defaults.keys():
		return platform_defaults[OS.get_name()]
	return default

func get_bool(dict: Dictionary, key: String, default: bool, platform_defaults: Dictionary = {}) -> bool:
	if dict.has(key) and dict[key] is bool:
		@warning_ignore("unsafe_cast")
		return dict[key] as bool
	if OS.get_name() in platform_defaults.keys():
		return platform_defaults[OS.get_name()]
	return default

func get_float(dict: Dictionary, key: String, default: float, platform_defaults: Dictionary = {}) -> float:
	if dict.has(key) and dict[key] is float:
		@warning_ignore("unsafe_cast")
		return dict[key] as float
	if OS.get_name() in platform_defaults.keys():
		return platform_defaults[OS.get_name()]
	return default

func get_array(dict: Dictionary, key: String, default: Array, platform_defaults: Dictionary = {}) -> Array:
	if dict.has(key) and dict[key] is Array:
		@warning_ignore("unsafe_cast")
		return dict[key] as Array
	if OS.get_name() in platform_defaults.keys():
		return platform_defaults[OS.get_name()]
	return default

func get_dict(dict: Dictionary, key: String, default: Dictionary, platform_defaults: Dictionary = {}) -> Dictionary:
	if dict.has(key) and dict[key] is Dictionary:
		@warning_ignore("unsafe_cast")
		return dict[key] as Dictionary
	if OS.get_name() in platform_defaults.keys():
		return platform_defaults[OS.get_name()]
	return default

static func get_color(dict: Dictionary, default: Color) -> Color:
	var keys: Array[String] = ["color", "_color"]
	for key in keys:
		if not dict.has(key) or not dict[key] is Array:
			continue
		var components := dict[key] as Array
		if components.size() < 3:
			continue
		var valid := true
		for index in range(mini(components.size(), 4)):
			if not components[index] is int and not components[index] is float:
				valid = false
				break
		if valid:
			var alpha := float(components[3]) if components.size() >= 4 else 1.0
			return Color(float(components[0]), float(components[1]), float(components[2]), alpha)
	return default

func unzip(zip_file: String, destination: String) -> void:
	var zreader := ZIPReader.new()
	if zreader.open(zip_file) != OK:
		vr.log_warning("unable to open zip file %s" % zip_file)
		return
	for file in zreader.get_files():
		var buffer := zreader.read_file(file)
		if buffer:
			var filea := FileAccess.open(destination+"/"+file, FileAccess.WRITE)
			filea.store_buffer(buffer)
			filea.close()
	@warning_ignore("return_value_discarded")
	zreader.close()


var fake_thread_finished: Dictionary[Thread, Variant] = {}

func custom_thread_wait_to_finish(thread: Thread) -> Variant:
	if OS.has_feature("web"):
		if not fake_thread_finished.has(thread):
			return null
		var r: Variant = fake_thread_finished[thread]
		fake_thread_finished.erase(thread)
		return r
	if thread.is_started():
		if thread.is_alive():
			return thread.wait_to_finish()
		return thread.wait_to_finish()
	return null

func custom_thread_call(thread: Thread, function: Callable, params: Array = []) -> Error:
	if OS.has_feature("web"):
		fake_thread_finished[thread] = function.callv(params)
		return OK
	if thread.is_started():
		if thread.is_alive():
			return ERR_BUSY
		thread.wait_to_finish()
	return thread.start(function.bindv(params))
