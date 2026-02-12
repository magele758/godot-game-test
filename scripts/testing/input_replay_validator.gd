class_name InputReplayValidator
extends RefCounted

const ALLOWED_ACTIONS := {
	"move_left": true,
	"move_right": true,
	"move_up": true,
	"move_down": true,
	"attack": true,
	"dodge": true,
}


static func validate_events(events: Array) -> Dictionary:
	var previous_time: float = -1.0
	for event_data: Variant in events:
		var event_dict: Dictionary = event_data as Dictionary
		var action: String = str(event_dict.get("action", ""))
		var timestamp: float = float(event_dict.get("t", -1.0))
		if not ALLOWED_ACTIONS.has(action):
			return {"ok": false, "reason": "Unsupported action: %s" % action}
		if timestamp < 0.0:
			return {"ok": false, "reason": "Timestamp must be >= 0"}
		if timestamp < previous_time:
			return {"ok": false, "reason": "Timestamps must be monotonic"}
		previous_time = timestamp
	return {"ok": true, "count": events.size()}


static func compute_signature(events: Array) -> String:
	var normalized: Array = []
	for event_data: Variant in events:
		var event_dict: Dictionary = event_data as Dictionary
		normalized.append("%0.3f:%s" % [float(event_dict.get("t", 0.0)), str(event_dict.get("action", ""))])
	return str(hash(JSON.stringify(normalized)))
