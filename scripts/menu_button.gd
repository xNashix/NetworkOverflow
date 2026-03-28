extends TextureButton

enum ButtonType {
	NEW_GAME,
	CONTINUE,
	LEADERBOARD,
	MANUAL,
	EXIT
}

@export var button_type: ButtonType = ButtonType.NEW_GAME

@onready var normal_tex: AtlasTexture = texture_normal as AtlasTexture
@onready var pressed_tex: AtlasTexture = texture_pressed as AtlasTexture

func _ready() -> void:
	if normal_tex == null or pressed_tex == null:
		push_error("TextureButton needs AtlasTexture assigned in Texture Normal and Texture Pressed.")
		return

	match button_type:
		ButtonType.NEW_GAME:
			normal_tex.region = Rect2(32, 36, 112, 32)
			pressed_tex.region = Rect2(160, 36, 112, 32)

		ButtonType.CONTINUE:
			normal_tex.region = Rect2(32, 0, 112, 32)
			pressed_tex.region = Rect2(160, 0, 112, 32)

		ButtonType.LEADERBOARD:
			normal_tex.region = Rect2(32, 72, 112, 32)
			pressed_tex.region = Rect2(160, 72, 112, 32)

		ButtonType.MANUAL:
			normal_tex.region = Rect2(32, 108, 112, 32)
			pressed_tex.region = Rect2(160, 108, 112, 32)

		ButtonType.EXIT:
			normal_tex.region = Rect2(32, 144, 112, 32)
			pressed_tex.region = Rect2(160, 144, 112, 32)
