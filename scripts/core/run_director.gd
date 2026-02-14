class_name RunDirector
extends Node

## 参考 GodotRoguelikeTutorial 的 DungeonBoard + Schedule 模式
## 改进：难度递增、精英房、宝藏休息房、物品奖励

var rng := RandomNumberGenerator.new()
var run_rooms: Array = []
var room_cursor: int = -1
var difficulty_level: int = 0


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

	# 构建房间序列：战斗 → 宝藏/精英 交替 → Boss
	run_rooms = []
	difficulty_level = 0
	var combat_count: int = mini(target_combat_rooms, combat_rooms.size())

	for i in range(combat_count):
		var room: Dictionary = combat_rooms[i].duplicate()
		# 难度递增：每层多 1 个敌人，血量 +20%
		room["enemy_count"] = int(room.get("enemy_count", 2)) + i
		room["difficulty_bonus"] = float(i) * 0.2
		room["room_index"] = i
		run_rooms.append(room)

		# 每 2 个战斗房后插入一个特殊房间
		if (i + 1) % 2 == 0 and i < combat_count - 1:
			if rng.randf() < 0.4:
				run_rooms.append(_make_elite_room(i))
			else:
				run_rooms.append(_make_treasure_room(i))

	# 最终 Boss 房
	if boss_rooms.is_empty():
		run_rooms.append({
			"id": "final_boss",
			"type": "boss",
			"enemy_count": 1,
			"time_budget_sec": 120,
			"difficulty_bonus": float(combat_count) * 0.3,
		})
	else:
		var boss: Dictionary = boss_rooms[rng.randi_range(0, boss_rooms.size() - 1)].duplicate()
		boss["difficulty_bonus"] = float(combat_count) * 0.3
		run_rooms.append(boss)

	room_cursor = -1
	return run_rooms


func _make_elite_room(after_index: int) -> Dictionary:
	return {
		"id": "elite_%d" % after_index,
		"type": "elite",
		"enemy_count": 2,
		"time_budget_sec": 90,
		"difficulty_bonus": float(after_index) * 0.3 + 0.5,
		"reward_multiplier": 2.0,
	}


func _make_treasure_room(after_index: int) -> Dictionary:
	return {
		"id": "treasure_%d" % after_index,
		"type": "treasure",
		"enemy_count": 0,
		"time_budget_sec": 30,
		"heal_amount": 25,
		"guaranteed_relic": true,
	}


func has_next_room() -> bool:
	return room_cursor + 1 < run_rooms.size()


func next_room() -> Dictionary:
	if not has_next_room():
		return {}
	room_cursor += 1
	difficulty_level = room_cursor
	return run_rooms[room_cursor] as Dictionary


func get_room_count() -> int:
	return run_rooms.size()


func get_progress_ratio() -> float:
	if run_rooms.is_empty():
		return 0.0
	return float(room_cursor + 1) / float(run_rooms.size())


func validate_generated_run() -> bool:
	if run_rooms.is_empty():
		return false
	for room_data: Variant in run_rooms:
		if not validate_room(room_data as Dictionary):
			return false
	var final_room: Dictionary = run_rooms[run_rooms.size() - 1] as Dictionary
	var final_type: String = str(final_room.get("type", ""))
	return final_type == "boss"


static func validate_room(room_data: Dictionary) -> bool:
	if str(room_data.get("id", "")).is_empty():
		return false
	var room_type: String = str(room_data.get("type", ""))
	# 宝藏房不需要敌人
	if room_type == "treasure":
		return true
	if int(room_data.get("enemy_count", 0) as int) <= 0:
		return false
	if int(room_data.get("time_budget_sec", 0) as int) <= 0:
		return false
	return true
