extends Node
class_name MapDownloader

# Downloads a BeatSaver map zip and unpacks it into the Songs folder. This is
# the download/unzip half of BeatSaverPanel._on_HTTPRequest_download_completed
# as a reusable node: the zip is written to APPDATA/temp, extracted into
# <songs_dir>/<song_dir_name>/ and removed. One download at a time.

signal progress(downloaded_bytes: int, total_bytes: int)
signal finished(ok: bool, out_dir: String, error: String)

var songs_dir: String = Constants.APPDATA_PATH + "Songs/"
var temp_dir: String = Constants.APPDATA_PATH + "temp/"

var _http: HTTPRequest
var _dir_name := ""
var _busy := false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "HTTPDownload"
	if OS.get_name() != "Web":
		_http.use_threads = true
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)


func is_busy() -> bool:
	return _busy


## Strips path separators and characters Windows rejects in folder names.
static func sanitize_dir_name(song_name: String) -> String:
	var clean := song_name
	for bad: String in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		clean = clean.replace(bad, "")
	clean = clean.strip_edges()
	return clean if not clean.is_empty() else "map"


func download(url: String, song_dir_name: String) -> Error:
	if _busy:
		return ERR_BUSY
	_dir_name = sanitize_dir_name(song_dir_name)
	var error := _http.request(url)
	if error != OK:
		return error
	_busy = true
	set_process(true)
	return OK


func cancel() -> void:
	if _busy:
		_http.cancel_request()
		_busy = false


func _process(_delta: float) -> void:
	if _busy:
		progress.emit(_http.get_downloaded_bytes(), _http.get_body_size())


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		finished.emit(false, "", "download failed (result %d, http %d)" % [result, response_code])
		return
	if body.slice(0, 10) == "<!DOCTYPE html>".to_utf8_buffer().slice(0, 10):
		finished.emit(false, "", "server returned a web page instead of a zip")
		return

	var error := DirAccess.make_dir_recursive_absolute(temp_dir)
	if error != OK:
		finished.emit(false, "", "cannot create temp dir %s" % temp_dir)
		return
	var zip_path := temp_dir + "%s.zip" % _dir_name
	var file := FileAccess.open(zip_path, FileAccess.WRITE)
	if file == null:
		finished.emit(false, "", "cannot write %s" % zip_path)
		return
	file.store_buffer(body)
	file.close()

	var out_dir := songs_dir + _dir_name + "/"
	error = DirAccess.make_dir_recursive_absolute(out_dir)
	if error != OK:
		@warning_ignore("return_value_discarded")
		DirAccess.remove_absolute(zip_path)
		finished.emit(false, "", "cannot create %s" % out_dir)
		return
	Utils.unzip(zip_path, out_dir)
	@warning_ignore("return_value_discarded")
	DirAccess.remove_absolute(zip_path)
	if Map.find_file_case_insensitive(out_dir, "info.dat").is_empty():
		finished.emit(false, out_dir, "zip did not contain an Info.dat")
		return
	finished.emit(true, out_dir, "")
