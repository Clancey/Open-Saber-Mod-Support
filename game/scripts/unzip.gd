extends Node

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
