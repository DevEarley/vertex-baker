extends Button
@export var TARGET:Control

func _ready():
	if(TARGET == null):
		TARGET = self;

func _on_pressed() -> void:
	if(TARGET.visible == false):
		TARGET.show()
	for child in TARGET.get_children():
		child.visible = !child.visible;
