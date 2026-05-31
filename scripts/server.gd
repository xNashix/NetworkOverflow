extends Node2D


@onready var sprite = $Sprite2D


var COLORS = {
	"red": Rect2(0, 0, 16, 16),
	"blue": Rect2(80, 0, 16, 16),
	"green": Rect2(0, 40, 16, 16),
	"purple": Rect2(80, 40, 16, 16)
}

var current_color = ""


func set_color(color_name):
	current_color = color_name
	sprite.region_enabled = true
	sprite.region_rect = COLORS[color_name]
