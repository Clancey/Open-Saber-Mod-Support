extends Node

var storage_path
var zip_file
@onready var zreader = ZIPReader.new()

func unzip(sourceFile,destination):
	zip_file = sourceFile
	storage_path = destination
	var err = zreader.open(zip_file)
	if err != OK:
		print("unable to open zip file")
		return false
	for f in zreader.get_files():
		_unzip_file(f)
	zreader.close()


func _unzip_file(file):
	var buffer = zreader.read_file(file)
	if buffer:
		var filea = FileAccess.open(storage_path+"/"+file, FileAccess.WRITE)
		filea.store_buffer(buffer)
		filea.close()
