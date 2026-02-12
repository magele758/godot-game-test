extends RefCounted


func run() -> Dictionary:
	var failures: Array = []
	var director := RunDirector.new()
	var room_catalog: Array = [
		{"id": "r1", "type": "combat", "enemy_count": 2, "time_budget_sec": 90},
		{"id": "r2", "type": "combat", "enemy_count": 3, "time_budget_sec": 95},
		{"id": "r3", "type": "combat", "enemy_count": 4, "time_budget_sec": 105},
		{"id": "boss_x", "type": "boss", "enemy_count": 1, "time_budget_sec": 180},
	]
	var run_rooms := director.build_run(123456, room_catalog, 3)

	if run_rooms.size() != 4:
		failures.append("Run room count should be combat target + boss.")
	if not director.validate_generated_run():
		failures.append("Generated run must pass validation.")

	for room_data in run_rooms:
		if not RunDirector.validate_room(room_data):
			failures.append("Found invalid room: %s" % str(room_data))

	return {
		"name": "test_run_generation",
		"failures": failures,
	}
