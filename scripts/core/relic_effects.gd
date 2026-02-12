class_name RelicEffects
extends RefCounted


static func on_perfect_dodge(player: PlayerController, relic_ids: Array, relics_data: Array) -> void:
	for relic_id in relic_ids:
		var relic := _find_relic(relic_id, relics_data)
		if str(relic.get("effect", "")) == "perfect_dodge_heal":
			var heal := int(relic.get("value", 0))
			player.current_health = min(player.max_health, player.current_health + heal)


static func combo_damage_bonus(relic_ids: Array, relics_data: Array) -> float:
	var bonus := 0.0
	for relic_id in relic_ids:
		var relic := _find_relic(relic_id, relics_data)
		if str(relic.get("effect", "")) == "combo_damage":
			bonus += float(relic.get("value", 0.0))
	return bonus


static func clear_speed_bonus(relic_ids: Array, relics_data: Array) -> float:
	var bonus := 0.0
	for relic_id in relic_ids:
		var relic := _find_relic(relic_id, relics_data)
		if str(relic.get("effect", "")) == "clear_speed_bonus":
			bonus += float(relic.get("value", 0.0))
	return bonus


static func _find_relic(relic_id: String, relics_data: Array) -> Dictionary:
	for relic in relics_data:
		if str(relic.get("id", "")) == relic_id:
			return relic
	return {}
