extends Control

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
