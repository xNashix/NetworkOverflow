extends Node2D

@onready var sprite: Sprite2D = $Sprite2D

var atlas_texture: Texture2D = preload("res://sprites/Network_Overflow_Sprites.png")

func set_visual(region: Rect2, rot_steps: int, flip: bool = false) -> void:
	sprite.texture = atlas_texture
	sprite.region_enabled = true
	sprite.region_rect = region
	rotation_degrees = 90.0 * rot_steps
	sprite.flip_h = flip
