extends RefCounted


func run() -> Dictionary:
	var failures: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var entries: Array = [
		{"id": "common", "weight": 70.0},
		{"id": "rare", "weight": 25.0},
		{"id": "legendary", "weight": 5.0},
	]
	if not DropTable.validate_entries(entries):
		failures.append("Drop table with positive weights should be valid.")

	var invalid_entries: Array = [
		{"id": "broken_a", "weight": 0.0},
		{"id": "broken_b", "weight": 0.0},
	]
	if DropTable.validate_entries(invalid_entries):
		failures.append("Drop table with zero total weight should be invalid.")

	var sampled_ids: Dictionary = {}
	for _idx in range(30):
		var picked: Dictionary = DropTable.pick(entries, rng)
		var item_id := str(picked.get("id", ""))
		sampled_ids[item_id] = true

	if sampled_ids.is_empty():
		failures.append("Drop table sampling should return at least one item.")
	if not sampled_ids.has("common"):
		failures.append("Sample should include common item in 30 draws.")

	return {
		"name": "test_drop_table",
		"failures": failures,
	}
