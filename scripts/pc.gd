extends Node2D

@onready var sprite: Sprite2D = $Sprite2D

var color = "red"
var facing = "down"
var linked = false

var pc_off_sprites = {
	"red_up": Rect2(56, 8, 8, 8),
	"red_down": Rect2(48, 8, 8, 8),
	"red_left": Rect2(40, 8, 8, 8),
	"red_right": Rect2(64, 8, 8, 8),
	"blue_up": Rect2(136, 8, 8, 8),
	"blue_down": Rect2(128, 8, 8, 8),
	"blue_left": Rect2(120, 8, 8, 8),
	"blue_right": Rect2(144, 8, 8, 8),
	"green_up": Rect2(56, 48, 8, 8),
	"green_down": Rect2(48, 48, 8, 8),
	"green_left": Rect2(40, 48, 8, 8),
	"green_right": Rect2(64, 48, 8, 8),
	"purple_up": Rect2(136, 48, 8, 8),
	"purple_down": Rect2(128, 48, 8, 8),
	"purple_left": Rect2(120, 48, 8, 8),
	"purple_right": Rect2(144, 48, 8, 8)
}


var pc_on_sprites = {
	"red_up": Rect2(56, 0, 8, 8),
	"red_down": Rect2(48, 0, 8, 8),
	"red_left": Rect2(40, 0, 8, 8),
	"red_right": Rect2(64, 0, 8, 8),
	"blue_up": Rect2(136, 0, 8, 8),
	"blue_down": Rect2(128, 0, 8, 8),
	"blue_left": Rect2(120, 0, 8, 8),
	"blue_right": Rect2(144, 0, 8, 8),
	"green_up": Rect2(56, 40, 8, 8),
	"green_down": Rect2(48, 40, 8, 8),
	"green_left": Rect2(40, 40, 8, 8),
	"green_right": Rect2(64, 40, 8, 8),
	"purple_up": Rect2(136, 40, 8, 8),
	"purple_down": Rect2(128, 40, 8, 8),
	"purple_left": Rect2(120, 40, 8, 8),
	"purple_right": Rect2(144, 40, 8, 8)
}


func set_state(new_color: String, new_facing: String, connected: bool) -> void:
	color = new_color
	facing = new_facing
	linked = connected
	_apply_visual()

func set_connected(connected: bool) -> void:
	linked = connected
	_apply_visual()

func _apply_visual() -> void:
	sprite.region_enabled = true
	
	var key = color + "_" + facing
	var sprite_map = pc_on_sprites if linked else pc_off_sprites

	if sprite_map.has(key):
		sprite.region_rect = sprite_map[key]
