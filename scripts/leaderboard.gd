extends Control

const LeaderboardStore = preload("res://scripts/leaderboard_store.gd")
@onready var rows: VBoxContainer = $Rows

func _ready() -> void:
	var entries: Array = LeaderboardStore.load_entries()
	for i in range(10):
		var row: Label = rows.get_node("Row%d" % [i + 1])
		if i >= entries.size():
			row.add_theme_font_size_override("font_size", 6)
			row.text = "         --.--.---- --:--                                            --                                               --:--:--"
			continue
		var entry: Dictionary = entries[i]
		var date_text := str(entry.get("date", "--.--.---- --:--"))
		var score := int(entry.get("score", 0))
		var time_text := str(entry.get("time", "00:00:00"))
		row.add_theme_font_size_override("font_size", 6)
		row.text = "         %s                                 %d                                               %s" % [date_text, score, time_text]

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
