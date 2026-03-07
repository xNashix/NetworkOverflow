extends Node2D

# Referencia na grafiku pre PC
# @onready znamená, že sa nastaví až keď je node pripravený v scéne
@onready var sprite: Sprite2D = $Sprite2D

# Aktuálna farba PC 
var color = "red"
# Smer, ktorým je PC otočené 
var facing = "down"
# Určuje, či je PC pripojené k sieti (true = zapnuté, false = vypnuté)
var linked = false

# Mapovanie sprite-ov pre NEPRIPOJENÉ PC (OFF stav)
# Kľúč je kombinácia farby a smeru (napr. "red_up")
# Hodnota je výrez zo spritesheetu (Rect2)
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

# Mapovanie sprite-ov pre PRIPOJENÉ PC (ON stav)
# Rovnaký princíp ako vyššie, len iné pozície (rozsvietené PC)
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

# Nastaví kompletný stav PC (farba, smer, pripojenie)
func set_state(new_color: String, new_facing: String, connected: bool) -> void:
	color = new_color
	facing = new_facing
	linked = connected
	# Po zmene stavu sa okamžite aktualizuje vizuál
	_apply_visual()

# Zmení len stav pripojenia (napr. po pripojení káblom)
func set_connected(connected: bool) -> void:
	linked = connected
	_apply_visual()

# Aplikuje správny sprite podľa aktuálneho stavu
func _apply_visual() -> void:
	# Zapnutie region režimu (použitie časti spritesheetu)
	sprite.region_enabled = true
	
	# Vytvorenie kľúča (napr. "red_left")
	var key = color + "_" + facing
	# Debug výpis pre kontrolu
	print("PC key:", key, " linked:", linked)
	# Výber správnej mapy sprite-ov podľa stavu (ON/OFF)
	var sprite_map = pc_on_sprites if linked else pc_off_sprites

	# Ak existuje zodpovedajúci sprite, nastaví sa jeho výrez
	if sprite_map.has(key):
		sprite.region_rect = sprite_map[key]
