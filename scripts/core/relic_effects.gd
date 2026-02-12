class_name RelicEffects
extends RefCounted


static func on_perfect_dodge(player: PlayerController, relic_ids: Array, relics_data: Array) -> void:
	for relic_id: Variant in relic_ids:
		var relic: Dictionary = _find_relic(str(relic_id), relics_data)
		if str(relic.get("effect", "")) == "perfect_dodge_heal":
			var heal: int = int(relic.get("value", 0) as int)
			player.current_health = mini(player.max_health, player.current_health + heal)


static func combo_damage_bonus(relic_ids: Array, relics_data: Array) -> float:
	var bonus: float = 0.0
	for relic_id: Variant in relic_ids:
		var relic: Dictionary = _find_relic(str(relic_id), relics_data)
		if str(relic.get("effect", "")) == "combo_damage":
			bonus += float(relic.get("value", 0.0))
	return bonus


static func clear_speed_bonus(relic_ids: Array, relics_data: Array) -> float:
	var bonus: float = 0.0
	for relic_id: Variant in relic_ids:
		var relic: Dictionary = _find_relic(str(relic_id), relics_data)
		if str(relic.get("effect", "")) == "clear_speed_bonus":
			bonus += float(relic.get("value", 0.0))
	return bonus


static func _find_relic(relic_id: String, relics_data: Array) -> Dictionary:
	for relic: Variant in relics_data:
		var relic_dict: Dictionary = relic as Dictionary
		if str(relic_dict.get("id", "")) == relic_id:
			return relic_dict
	return {}
