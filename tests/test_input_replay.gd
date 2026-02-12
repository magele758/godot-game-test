extends RefCounted


func run() -> Dictionary:
	var failures: Array = []
	var replay_events: Array = [
		{"t": 0.00, "action": "move_right"},
		{"t": 0.18, "action": "dodge"},
		{"t": 0.36, "action": "attack"},
		{"t": 0.62, "action": "attack"},
	]

	var validation: Dictionary = InputReplayValidator.validate_events(replay_events)
	if not bool(validation.get("ok", false)):
		failures.append("Replay validation should pass for valid sample.")

	var signature := InputReplayValidator.compute_signature(replay_events)
	if signature.is_empty():
		failures.append("Replay signature should not be empty.")

	var bad_replay: Array = [
		{"t": 0.10, "action": "attack"},
		{"t": 0.05, "action": "dodge"},
	]
	var bad_validation: Dictionary = InputReplayValidator.validate_events(bad_replay)
	if bool(bad_validation.get("ok", true)):
		failures.append("Replay validation should reject non-monotonic timeline.")

	return {
		"name": "test_input_replay",
		"failures": failures,
	}
