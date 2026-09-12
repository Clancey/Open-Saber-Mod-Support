extends "res://tests/test_case.gd"

# BeepSaber_Game hides the back-column enclosure during menus because those walls sit
# 0.86 m either side of the centre line and slice the UI canvases. It finds them by node
# name prefix, so an environment that names them anything else would silently keep its
# walls and bring the occlusion back with no error to notice.
#
# Ground truth here is the mesh FILENAME, which is independent of the node name the game
# matches on, so this fails when the two drift apart.

const ENVIRONMENT_DIRECTORY: String = "res://game/environments"
const DEFAULT_ENVIRONMENT: String = "res://game/event_driver.tscn"
const ENCLOSURE_PARENT: String = "Level"


func test_every_enclosure_mesh_is_reachable_by_the_prefix_the_game_matches_on() -> void:
	var checked: int = 0
	for scene_path: String in _environment_scenes():
		for node: Dictionary in _enclosure_nodes(scene_path):
			checked += 1
			var where: String = "%s -> %s" % [scene_path.get_file(), node["name"]]
			assert_true(
				String(node["name"]).begins_with(BeepSaber_Game.ENCLOSURE_NODE_PREFIX),
				"%s does not start with %s, so the game cannot hide it" %
					[where, BeepSaber_Game.ENCLOSURE_NODE_PREFIX])
			assert_eq(String(node["parent"]), ENCLOSURE_PARENT,
				"%s is not a direct child of %s, so the game cannot find it" %
					[where, ENCLOSURE_PARENT])

	# Without this the test would pass by finding nothing at all, which is exactly the
	# failure it exists to catch.
	assert_true(checked >= 6,
		"only found %d enclosure meshes; the detector itself is broken" % checked)


func test_the_detector_rejects_meshes_that_are_not_enclosures() -> void:
	# Negative control: the same detector must NOT claim ordinary scenery.
	var names: Array[String] = []
	for node: Dictionary in _enclosure_nodes(DEFAULT_ENVIRONMENT):
		names.append(String(node["name"]))
	assert_false(names.has("TrackConstruction"),
		"detector matched TrackConstruction, so it matches too much to prove anything")
	assert_true(names.size() > 0, "detector found no enclosure in the default environment")


func _environment_scenes() -> Array[String]:
	var scenes: Array[String] = [DEFAULT_ENVIRONMENT]
	var dir: DirAccess = DirAccess.open(ENVIRONMENT_DIRECTORY)
	if dir == null:
		return scenes
	for file_name: String in dir.get_files():
		if file_name.ends_with(".tscn"):
			scenes.append("%s/%s" % [ENVIRONMENT_DIRECTORY, file_name])
	scenes.sort()
	return scenes


# Reads the scene text rather than instantiating, so this stays cheap and inspects the
# artifact that actually ships.
func _enclosure_nodes(scene_path: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var text: String = FileAccess.get_file_as_string(scene_path)
	if text.is_empty():
		return found

	var enclosure_ids: Dictionary = {}
	var resource_pattern: RegEx = RegEx.new()
	@warning_ignore("return_value_discarded")
	resource_pattern.compile('\\[ext_resource type="ArrayMesh" path="([^"]+)" id="([^"]+)"\\]')
	for match: RegExMatch in resource_pattern.search_all(text):
		var mesh_file: String = match.get_string(1).get_file().to_lower().replace("_", "")
		if mesh_file.contains("backcolumns"):
			enclosure_ids[match.get_string(2)] = true

	var node_pattern: RegEx = RegEx.new()
	@warning_ignore("return_value_discarded")
	node_pattern.compile(
		'\\[node name="([^"]+)" type="MeshInstance3D" parent="([^"]*)"\\]\\n((?:[a-z_]+ = [^\\n]*\\n)*)')
	for match: RegExMatch in node_pattern.search_all(text):
		var body: String = match.get_string(3)
		var mesh_reference: RegExMatch = RegEx.create_from_string(
			'mesh = ExtResource\\("([^"]+)"\\)').search(body)
		if mesh_reference != null and enclosure_ids.has(mesh_reference.get_string(1)):
			found.append({"name": match.get_string(1), "parent": match.get_string(2)})
	return found
