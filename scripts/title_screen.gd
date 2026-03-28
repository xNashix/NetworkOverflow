extends Control

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_leaderboard_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/leaderboard.tscn")


func _on_manual_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/manual.tscn")
