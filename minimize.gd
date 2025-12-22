extends Button
@export var WINDOW:WindowMover
@export var EXPAND_BUTTON:Button
@export var FOLD_BUTTON:Button
@export var SIZE_EXPANDED:Vector2 = Vector2(500,500)
@export var SIZE_COLLAPSED:Vector2 = Vector2(500,40)
@export var OPEN_FROM_BOTTOM = false
var OPEN = false
func ON_EXPAND() -> void:
	FOLD_BUTTON.show()
	EXPAND_BUTTON.hide()
	WINDOW.MAIN.CURRENT_WINDOW = null
	OPEN = true
	WINDOW.size = Vector2(500,500)
	if(OPEN_FROM_BOTTOM):
		WINDOW.position.y -= 460

func ON_FOLD() -> void:
	FOLD_BUTTON.hide()
	EXPAND_BUTTON.show()
	WINDOW.MAIN.CURRENT_WINDOW = null
	OPEN = false
	WINDOW.size = Vector2(500,40)
	if(OPEN_FROM_BOTTOM):
		WINDOW.position.y += 460
