extends Node

var run_seed: int = 0
var room_index: int = 0
var current_weapon_id: String = "paper_blade"
var cute_tasks: Dictionary = {}
var metrics: Dictionary = {}
var run_started_at_msec: int = 0


func _ready() -> void:
	reset()


func reset() -> void:
	run_seed = 0
	room_index = 0
	current_weapon_id = "paper_blade"
	cute_tasks = {}
	metrics = _fresh_metrics()
	run_started_at_msec = 0


func begin_run(seed: int, weapon_id: String, tasks: Array) -> void:
	run_seed = seed
	room_index = 0
	current_weapon_id = weapon_id
	cute_tasks = {}
	for task in tasks:
		var task_id := str(task.get("id", ""))
		if not task_id.is_empty():
			cute_tasks[task_id] = false
	metrics = _fresh_metrics()
	run_started_at_msec = Time.get_ticks_msec()


func _fresh_metrics() -> Dictionary:
	return {
		"perfect_dodges": 0,
		"no_hit_rooms": 0,
		"combo_variety": {},
		"kills": 0,
		"executions": 0,
		"damage_taken": 0,
		"room_clear_times": [],
	}


func next_room() -> void:
	room_index += 1


func register_perfect_dodge() -> void:
	metrics["perfect_dodges"] += 1


func register_combo(tag: String) -> void:
	var combo_variety: Dictionary = metrics["combo_variety"]
	combo_variety[tag] = true


func register_kill(executed: bool) -> void:
	metrics["kills"] += 1
	if executed:
		metrics["executions"] += 1


func register_damage_taken(amount: int) -> void:
	metrics["damage_taken"] += max(0, amount)


func register_room_clear(seconds_spent: float, took_damage: bool) -> void:
	metrics["room_clear_times"].append(seconds_spent)
	if not took_damage:
		metrics["no_hit_rooms"] += 1


func mark_task_complete(task_id: String) -> void:
	if cute_tasks.has(task_id):
		cute_tasks[task_id] = true


func get_combo_variety_count() -> int:
	var combo_variety: Dictionary = metrics["combo_variety"]
	return combo_variety.size()


func snapshot_for_progression() -> Dictionary:
	var duration_minutes := 0.0
	if run_started_at_msec > 0:
		duration_minutes = float(Time.get_ticks_msec() - run_started_at_msec) / 60000.0
	return {
		"weapon_id": current_weapon_id,
		"perfect_dodges": int(metrics["perfect_dodges"]),
		"no_hit_rooms": int(metrics["no_hit_rooms"]),
		"combo_variety_count": get_combo_variety_count(),
		"kills": int(metrics["kills"]),
		"executions": int(metrics["executions"]),
		"damage_taken": int(metrics["damage_taken"]),
		"duration_minutes": duration_minutes,
		"room_clear_times": metrics["room_clear_times"],
		"cute_tasks": cute_tasks.duplicate(true),
	}
