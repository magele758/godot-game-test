class_name RunDirector
extends Node

var rng := RandomNumberGenerator.new()
var run_rooms: Array = []
var room_cursor: int = -1


func build_run(p_seed: int, room_catalog: Array, target_combat_rooms: int = 4) -> Array:
	rng.seed = p_seed
	var combat_rooms: Array = []
	var boss_rooms: Array = []

	for room_data: Variant in room_catalog:
		var room_dict: Dictionary = room_data as Dictionary
		var room_type: String = str(room_dict.get("type", "combat"))
		if room_type == "boss":
			boss_rooms.append(room_dict)
		else:
			combat_rooms.append(room_dict)

	combat_rooms.shuffle()
	var picked_rooms: Array = combat_rooms.slice(0, mini(target_combat_rooms, combat_rooms.size()))
	if boss_rooms.is_empty():
		picked_rooms.append({
			"id": "fallback_boss",
			"type": "boss",
			"enemy_count": 1,
			"time_budget_sec": 120,
		})
	else:
		picked_rooms.append(boss_rooms[rng.randi_range(0, boss_rooms.size() - 1)])

	run_rooms = picked_rooms
	room_cursor = -1
	return run_rooms


func has_next_room() -> bool:
	return room_cursor + 1 < run_rooms.size()


func next_room() -> Dictionary:
	if not has_next_room():
		return {}
	room_cursor += 1
	return run_rooms[room_cursor] as Dictionary


func validate_generated_run() -> bool:
	if run_rooms.is_empty():
		return false
	for room_data: Variant in run_rooms:
		if not validate_room(room_data as Dictionary):
			return false
	var final_room: Dictionary = run_rooms[run_rooms.size() - 1] as Dictionary
	return str(final_room.get("type", "")) == "boss"


static func validate_room(room_data: Dictionary) -> bool:
	if str(room_data.get("id", "")).is_empty():
		return false
	if int(room_data.get("enemy_count", 0) as int) <= 0:
		return false
	if int(room_data.get("time_budget_sec", 0) as int) <= 0:
		return false
	return true
