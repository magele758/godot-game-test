extends Node

const DATA_FILES := {
	"weapons": "res://data/weapons.json",
	"enemies": "res://data/enemies.json",
	"rooms": "res://data/rooms.json",
	"relics": "res://data/relics.json",
	"tasks": "res://data/tasks.json",
	"regions": "res://data/regions.json",
}

var cache: Dictionary = {}


func _ready() -> void:
	reload_all()


func reload_all() -> void:
	cache.clear()
	for key in DATA_FILES.keys():
		cache[key] = _load_json(str(DATA_FILES[key]))


func get_collection(name: String) -> Variant:
	return cache.get(name, [])


func get_region_settings(region: String) -> Dictionary:
	var regions_data: Variant = cache.get("regions", {})
	if typeof(regions_data) != TYPE_DICTIONARY:
		return {}
	var regions: Dictionary = regions_data
	return regions.get(region, regions.get("global", {}))


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("Missing data file: %s" % path)
		return [] if path.ends_with(".json") else {}

	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_warning("Empty data file: %s" % path)
		return []

	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_warning("Invalid JSON in %s" % path)
		return []
	return parsed
