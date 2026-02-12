class_name DropTable
extends RefCounted


static func validate_entries(entries: Array) -> bool:
	if entries.is_empty():
		return false
	var total_weight := 0.0
	for item in entries:
		var weight := float(item.get("weight", 0.0))
		if weight < 0.0:
			return false
		total_weight += weight
	return total_weight > 0.0


static func pick(entries: Array, rng: RandomNumberGenerator) -> Dictionary:
	if not validate_entries(entries):
		return {}

	var total_weight := 0.0
	for item in entries:
		total_weight += float(item.get("weight", 0.0))

	var roll := rng.randf_range(0.0, total_weight)
	var cursor := 0.0
	for item in entries:
		cursor += float(item.get("weight", 0.0))
		if roll <= cursor:
			return item

	return entries[entries.size() - 1]
