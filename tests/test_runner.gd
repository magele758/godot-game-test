extends SceneTree

const TEST_FILES := [
	"res://tests/test_combat.gd",
	"res://tests/test_progression.gd",
	"res://tests/test_run_generation.gd",
	"res://tests/test_input_replay.gd",
	"res://tests/test_drop_table.gd",
]


func _init() -> void:
	var total_failures: Array = []
	for test_file in TEST_FILES:
		var script: Script = load(test_file)
		if script == null:
			total_failures.append("Unable to load test file: %s" % test_file)
			continue
		var test_case = script.new()
		var result: Dictionary = test_case.run()
		var case_name := str(result.get("name", test_file))
		var failures: Array = result.get("failures", [])
		if failures.is_empty():
			print("PASS: %s" % case_name)
		else:
			for failure in failures:
				total_failures.append("%s -> %s" % [case_name, failure])

	if total_failures.is_empty():
		print("All tests passed.")
		quit(0)
		return

	print("Test failures:")
	for failure in total_failures:
		print("- %s" % failure)
	quit(1)
