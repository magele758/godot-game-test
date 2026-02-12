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
	var previous_time := -1.0
	for event_data in events:
		var action := str(event_data.get("action", ""))
		var timestamp := float(event_data.get("t", -1.0))
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
	for event_data in events:
		normalized.append("%0.3f:%s" % [float(event_data.get("t", 0.0)), str(event_data.get("action", ""))])
	return str(hash(JSON.stringify(normalized)))
