extends RefCounted
class_name LeaderboardStore

const SAVE_PATH := "user://leaderboard.json"
const MAX_ENTRIES := 10

static func add_result(date_text: String, score: int, time_text: String) -> void:
	var entries: Array = load_entries()
	entries.append({
		"date": date_text,
		"score": score,
		"time": time_text
	})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := int(a.get("score", 0))
		var score_b := int(b.get("score", 0))
		if score_a != score_b:
			return score_a > score_b
		var time_a := _time_to_seconds(str(a.get("time", "00:00:00")))
		var time_b := _time_to_seconds(str(b.get("time", "00:00:00")))
		if time_a != time_b:
			return time_a > time_b
		return str(a.get("date", "")) > str(b.get("date", "") )
	)
	if entries.size() > MAX_ENTRIES:
		entries = entries.slice(0, MAX_ENTRIES)
	_save_entries(entries)

static func load_entries() -> Array:
	if not FileAccess.file_exists(SAVE_PATH):
		return []
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return []
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Array:
		return parsed
	return []

static func _save_entries(entries: Array) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(entries))
	file.close()

static func _time_to_seconds(time_text: String) -> int:
	var parts := time_text.split(":")
	if parts.size() != 3:
		return 0
	var hh := int(parts[0])
	var mm := int(parts[1])
	var ss := int(parts[2])
	return hh * 3600 + mm * 60 + ss
