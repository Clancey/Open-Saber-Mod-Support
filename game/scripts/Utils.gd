extends Node

func get_str(dict: Dictionary, key: String, default: String) -> String:
		if dict.has(key) and dict[key] is String:
			@warning_ignore("unsafe_cast")
			return dict[key] as String
		return default

func get_bool(dict: Dictionary, key: String, default: bool) -> bool:
	if dict.has(key) and dict[key] is bool:
		@warning_ignore("unsafe_cast")
		return dict[key] as bool
	return default

func get_float(dict: Dictionary, key: String, default: float) -> float:
	if dict.has(key) and dict[key] is float:
		@warning_ignore("unsafe_cast")
		return dict[key] as float
	return default

func get_array(dict: Dictionary, key: String, default: Array) -> Array:
	if dict.has(key) and dict[key] is Array:
		@warning_ignore("unsafe_cast")
		return dict[key] as Array
	return default

func get_dict(dict: Dictionary, key: String, default: Dictionary) -> Dictionary:
	if dict.has(key) and dict[key] is Dictionary:
		@warning_ignore("unsafe_cast")
		return dict[key] as Dictionary
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
