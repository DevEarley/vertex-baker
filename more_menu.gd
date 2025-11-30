extends Button
@export var TARGET:Control
@export var HIDE_WHEN_TARGET_IS_ON:Control

func _ready():
	if(TARGET == null):
		TARGET = self;

func _on_pressed() -> void:
	if(TARGET.visible == false):
		TARGET.show()
	var children =  TARGET.get_children()
	if(children!=null && children.size()>0):
		for child in TARGET.get_children():
			child.visible = !child.visible;
		var open = children[0].visible
		if(HIDE_WHEN_TARGET_IS_ON !=null):
			HIDE_WHEN_TARGET_IS_ON.visible = !open;
