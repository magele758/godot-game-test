class_name DropTable
extends RefCounted


static func validate_entries(entries: Array) -> bool:
	if entries.is_empty():
		return false
	var total_weight: float = 0.0
	for item: Variant in entries:
		var item_dict: Dictionary = item as Dictionary
		var weight: float = float(item_dict.get("weight", 0.0))
		if weight < 0.0:
			return false
		total_weight += weight
	return total_weight > 0.0


static func pick(entries: Array, rng: RandomNumberGenerator) -> Dictionary:
	if not validate_entries(entries):
		return {}

	var total_weight: float = 0.0
	for item: Variant in entries:
		var item_dict: Dictionary = item as Dictionary
		total_weight += float(item_dict.get("weight", 0.0))

	var roll: float = rng.randf_range(0.0, total_weight)
	var cursor: float = 0.0
	for item: Variant in entries:
		var item_dict: Dictionary = item as Dictionary
		cursor += float(item_dict.get("weight", 0.0))
		if roll <= cursor:
			return item_dict

	return entries[entries.size() - 1] as Dictionary
