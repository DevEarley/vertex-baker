extends Button

@export var TARGET:Node


func _on_pressed() -> void:

	self.hide()
	TARGET.show();
