extends Button
@export var TOGGLE_TARGET:Control
@export var EXPAND_ICON:Texture2D
@export var FOLD_ICON:Texture2D

var OPEN = true

#func ON_EXPAND() -> void:
	#FOLD_BUTTON.show()
	#EXPAND_BUTTON.hide()
	#WINDOW.MAIN.CURRENT_WINDOW = null
	#OPEN = true
	#WINDOW.size = Vector2(500,500)
#
#func ON_FOLD() -> void:
	#FOLD_BUTTON.hide()
	#EXPAND_BUTTON.show()
	#WINDOW.MAIN.CURRENT_WINDOW = null
	#OPEN = false
	#WINDOW.size = Vector2(500,40)

func _ready():
	OPEN = TOGGLE_TARGET.visible
func _on_pressed() -> void:
	OPEN = !OPEN;
	TOGGLE_TARGET.visible = OPEN
	if(FOLD_ICON!=null && EXPAND_ICON!=null):
		if(OPEN):
			self.icon = FOLD_ICON
		else:
			self.icon = EXPAND_ICON
