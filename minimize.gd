extends Button
@export var WINDOW:WindowMover

var OPEN = false
func _on_pressed() -> void:
	WINDOW.MAIN.CURRENT_WINDOW = null
	if(OPEN == true):
		OPEN = false
		self.text = "➕"
		WINDOW.size = Vector2(500,40)

	elif(OPEN == false):
		OPEN = true
		self.text = "➖"
		WINDOW.size = Vector2(500,500)
