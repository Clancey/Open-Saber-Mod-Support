extends Node

var storage_path
var zip_file

func unzip(sourceFile,destination):
	zip_file = sourceFile
	storage_path = destination
	var gdunzip = load('res://addons/gdunzip/gdunzip.gd').new()
	var loaded = gdunzip.load(zip_file)
	if !loaded:
		print('- Failed loading zip file')
		return false
	ProjectSettings.load_resource_pack(zip_file)
	var i = 0
	for f in gdunzip.files:
		unzip_file(f)
		
func unzip_file(fileName):
	if FileAccess.file_exists("res://"+fileName):
		var readFile = FileAccess.open(("res://"+fileName), FileAccess.READ)
		var content = readFile.get_buffer(readFile.get_length())
		readFile.close()
		var base_dir = storage_path + fileName.get_base_dir()
		DirAccess.make_dir_absolute(base_dir)
		var writeFile = FileAccess.open(storage_path + fileName, FileAccess.WRITE)
		writeFile.store_buffer(content)
		writeFile.close()
