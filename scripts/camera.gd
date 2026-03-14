extends Camera2D

# Rýchlosť pohybu kamery 
var speed = 300

func _process(_delta):
	# Smer pohybu (začína ako nulový vektor)
	var dir = Vector2.ZERO

# Kontrola vstupov – skladáme smer podľa stlačených kláves
	if Input.is_action_pressed("ui_right"):
		dir.x += 1
	if Input.is_action_pressed("ui_left"):
		dir.x -= 1
	if Input.is_action_pressed("ui_down"):
		dir.y += 1
	if Input.is_action_pressed("ui_up"):
		dir.y -= 1
		
# Normalizácia zabezpečí rovnakú rýchlosť aj diagonálne
	position += dir.normalized() * speed * _delta

func _input(event):
	# Zachytávanie vstupu z myši (scroll koliesko)
	if event is InputEventMouseButton:
		# Zoom in (priblíženie)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom *= 0.9
		# Zoom out (oddialenie)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom *= 1.1
