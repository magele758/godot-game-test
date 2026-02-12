extends Node

const SAVE_PATH := "user://progression_profile.json"
const ACTION_UNLOCKS := {
	"dash_counter": 60,
	"air_slash": 120,
	"execution_plus": 220,
}

var profile: Dictionary = {}


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		profile = _default_profile()
		save_profile()
		return

	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		profile = _default_profile()
		save_profile()
		return

	profile = parsed
	_ensure_profile_shape()


func save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Cannot save progression profile.")
		return
	file.store_string(JSON.stringify(profile, "\t"))


func _default_profile() -> Dictionary:
	return {
		"profile_level": 1,
		"lifetime_minutes": 0.0,
		"weapon_xp": {"paper_blade": 0},
		"unlocked_actions": ["light_attack"],
		"highest_mastery_rank": "D",
	}


func _ensure_profile_shape() -> void:
	if not profile.has("profile_level"):
		profile["profile_level"] = 1
	if not profile.has("lifetime_minutes"):
		profile["lifetime_minutes"] = 0.0
	if not profile.has("weapon_xp"):
		profile["weapon_xp"] = {"paper_blade": 0}
	if not profile.has("unlocked_actions"):
		profile["unlocked_actions"] = ["light_attack"]
	if not profile.has("highest_mastery_rank"):
		profile["highest_mastery_rank"] = "D"


func record_run(snapshot: Dictionary) -> Dictionary:
	var weapon_id: String = str(snapshot.get("weapon_id", "paper_blade"))
	var perfect_dodges: int = int(snapshot.get("perfect_dodges", 0))
	var no_hit_rooms: int = int(snapshot.get("no_hit_rooms", 0))
	var combo_variety_count: int = int(snapshot.get("combo_variety_count", 0))
	var damage_taken: int = int(snapshot.get("damage_taken", 0))
	var executions: int = int(snapshot.get("executions", 0))
	var duration_minutes: float = float(snapshot.get("duration_minutes", 0.0))

	var mastery_score: int = (
		perfect_dodges * 5
		+ no_hit_rooms * 10
		+ combo_variety_count * 3
		+ executions * 4
		+ max(0, 20 - damage_taken)
	)
	var time_bonus: int = int(duration_minutes * 2.0)
	var xp_gain: int = max(8, mastery_score + time_bonus)

	var weapon_xp: Dictionary = profile["weapon_xp"]
	weapon_xp[weapon_id] = int(weapon_xp.get(weapon_id, 0)) + xp_gain

	var unlocked_actions: Array = profile["unlocked_actions"]
	for action_id: String in ACTION_UNLOCKS.keys():
		var required_xp: int = int(ACTION_UNLOCKS[action_id])
		if int(weapon_xp[weapon_id]) >= required_xp and not unlocked_actions.has(action_id):
			unlocked_actions.append(action_id)

	profile["profile_level"] = 1 + int(unlocked_actions.size() / 2)
	profile["lifetime_minutes"] = float(profile["lifetime_minutes"]) + duration_minutes

	var rank: String = mastery_rank_from_score(mastery_score)
	if _rank_value(rank) > _rank_value(str(profile["highest_mastery_rank"])):
		profile["highest_mastery_rank"] = rank

	save_profile()
	return {
		"weapon_id": weapon_id,
		"xp_gain": xp_gain,
		"weapon_xp": int(weapon_xp[weapon_id]),
		"mastery_score": mastery_score,
		"rank": rank,
		"profile_level": int(profile["profile_level"]),
	}


func get_weapon_bonus(weapon_id: String) -> float:
	var weapon_xp: Dictionary = profile.get("weapon_xp", {})
	var xp: float = float(weapon_xp.get(weapon_id, 0))
	# 非线性成长，确保手法收益始终大于纯时长收益
	var bonus: float = min(0.15, log(1.0 + xp / 50.0) * 0.05)
	return 1.0 + bonus


func is_action_unlocked(action_id: String) -> bool:
	var unlocked_actions: Array = profile.get("unlocked_actions", [])
	return unlocked_actions.has(action_id)


func mastery_rank_from_score(score: int) -> String:
	if score >= 140:
		return "S"
	if score >= 95:
		return "A"
	if score >= 65:
		return "B"
	if score >= 35:
		return "C"
	return "D"


func _rank_value(rank: String) -> int:
	match rank:
		"S":
			return 5
		"A":
			return 4
		"B":
			return 3
		"C":
			return 2
		_:
			return 1
