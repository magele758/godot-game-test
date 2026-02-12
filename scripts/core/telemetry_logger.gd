extends Node

const EVENTS_PATH := "user://analytics/events.jsonl"


func _ready() -> void:
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.make_dir_recursive("analytics")


func log_event(event_name: String, payload: Dictionary) -> void:
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(EVENTS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to open telemetry file.")
		return

	file.seek_end()
	var record := {
		"ts": Time.get_datetime_string_from_system(),
		"event": event_name,
		"payload": payload,
	}
	file.store_line(JSON.stringify(record))
