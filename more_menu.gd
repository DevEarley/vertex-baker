extends Button


func _on_pressed() -> void:
	for child in self.get_children():
		child.visible = !child.visible;
