class_name RegionContentFilter
extends RefCounted


static func resolve_region() -> String:
	var env_region := OS.get_environment("GAME_REGION").strip_edges().to_lower()
	if env_region == "cn":
		return "cn"
	return "global"


static func gore_profile() -> Dictionary:
	var region := resolve_region()
	return ContentDatabase.get_region_settings(region)
