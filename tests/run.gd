extends SceneTree

const TEST_DIRECTORY := "res://tests"
const TEST_CASE_PATH := "res://tests/test_case.gd"


func _initialize() -> void:
	var passed: int = 0
	var failed: int = 0
	var test_files: Array[String] = _discover_test_files()

	for test_file: String in test_files:
		if test_file == TEST_CASE_PATH:
			continue
		var test_script: GDScript = load(test_file) as GDScript
		var test_case: Variant = test_script.new()
		var method_names: Array[String] = []
		for method: Dictionary in test_script.get_script_method_list():
			var method_name: String = String(method["name"])
			if method_name.begins_with("test_"):
				method_names.append(method_name)
		method_names.sort()

		for method_name: String in method_names:
			var failures_before: int = test_case.failures.size()
			test_case.call(method_name)
			var new_failures: Array[String] = []
			for index: int in range(failures_before, test_case.failures.size()):
				new_failures.append(test_case.failures[index])

			var test_name: String = "%s.%s" % [test_file.get_file().get_basename(), method_name]
			if new_failures.is_empty():
				passed += 1
				print("PASS %s" % test_name)
			else:
				failed += 1
				print("FAIL %s" % test_name)
				for failure: String in new_failures:
					print("  %s" % failure)

	print("")
	print("Summary: %d passed, %d failed, %d total" % [passed, failed, passed + failed])
	quit(0 if failed == 0 else 1)


func _discover_test_files() -> Array[String]:
	var files: Array[String] = []
	for file_name: String in DirAccess.get_files_at(TEST_DIRECTORY):
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			files.append("%s/%s" % [TEST_DIRECTORY, file_name])
	files.sort()
	return files
