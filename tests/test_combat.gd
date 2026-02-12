extends RefCounted


func run() -> Dictionary:
	var failures: Array = []

	var normal_hit: Dictionary = CombatResolver.compute_hit(10.0, 1.0, 1, false)
	if int(normal_hit.get("damage", 0) as int) != 10:
		failures.append("Expected base damage 10 for single hit combo.")

	var combo_hit: Dictionary = CombatResolver.compute_hit(10.0, 1.0, 3, false)
	if int(combo_hit.get("damage", 0) as int) <= int(normal_hit.get("damage", 0) as int):
		failures.append("Combo hit should be stronger than first hit.")

	var execution_hit: Dictionary = CombatResolver.compute_hit(10.0, 1.0, 2, true)
	if int(execution_hit.get("damage", 0) as int) <= int(combo_hit.get("damage", 0) as int):
		failures.append("Execution hit should be stronger than normal combo hit.")

	return {
		"name": "test_combat",
		"failures": failures,
	}
