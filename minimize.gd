extends Button
@export var WINDOW:WindowMover
@export var EXPAND_BUTTON:Button
@export var FOLD_BUTTON:Button

var OPEN = false
func ON_EXPAND() -> void:
	FOLD_BUTTON.show()
	EXPAND_BUTTON.hide()
	WINDOW.MAIN.CURRENT_WINDOW = null
	OPEN = true
	WINDOW.size = Vector2(500,500)

func ON_FOLD() -> void:
	FOLD_BUTTON.hide()
	EXPAND_BUTTON.show()
	WINDOW.MAIN.CURRENT_WINDOW = null
	OPEN = false
	WINDOW.size = Vector2(500,40)
