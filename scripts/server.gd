extends Node2D

# Referencia na grafiku servera
@onready var sprite = $Sprite2D

# Mapovanie farieb na konkrétne výrezy zo spritesheetu
# Kľúč = názov farby (string)
# Hodnota = Rect2 (pozícia a veľkosť v spritesheete)
var COLORS = {
	"red": Rect2(0, 0, 16, 16),
	"blue": Rect2(80, 0, 16, 16),
	"green": Rect2(0, 40, 16, 16),
	"purple": Rect2(80, 40, 16, 16)
}
# Aktuálna farba servera
# Na začiatku je prázdna (musí byť nastavená cez set_color)
var current_color = ""

# Nastaví farbu servera a zároveň jeho vizuál
func set_color(color_name):
	current_color = color_name
	# Zapne režim výrezu zo spritesheetu
	sprite.region_enabled = true
	# Nastaví konkrétny výrez podľa farby
	sprite.region_rect = COLORS[color_name]
