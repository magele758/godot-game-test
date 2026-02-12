extends RefCounted


func run() -> Dictionary:
	var failures: Array = []
	var manager := load("res://scripts/core/progression_manager.gd").new()
	manager.profile = {
		"profile_level": 1,
		"lifetime_minutes": 0.0,
		"weapon_xp": {"paper_blade": 0},
		"unlocked_actions": ["light_attack"],
		"highest_mastery_rank": "D",
	}

	var snapshot := {
		"weapon_id": "paper_blade",
		"perfect_dodges": 4,
		"no_hit_rooms": 2,
		"combo_variety_count": 3,
		"damage_taken": 5,
		"executions": 1,
		"duration_minutes": 12.0,
	}
	var summary: Dictionary = manager.record_run(snapshot)

	if int(summary.get("xp_gain", 0)) < 40:
		failures.append("XP gain should reflect mastery + time bonus.")
	if not manager.is_action_unlocked("dash_counter"):
		failures.append("dash_counter should unlock after first strong run.")
	if int(manager.profile.get("profile_level", 1)) < 2:
		failures.append("Profile level should increase when actions unlock.")

	return {
		"name": "test_progression",
		"failures": failures,
	}
