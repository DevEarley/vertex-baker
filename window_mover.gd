extends Window
class_name WindowMover

@export var MAIN: VertexBakerMainWindow;

var LAST_POSITION:Vector2 = Vector2.ZERO
var stuck = false
func _input(event):
	#if event is InputEventMouseMotion:
		#print("wm movement")
	if(MAIN.CURRENT_WINDOW != self && MAIN.CURRENT_WINDOW != null): return
	if event is InputEventMouseMotion && MAIN.MOVING_WINDOW == true:
		#LAST_POSITION =  Vector2.ZERO
		#stuck= false
		MAIN.CURRENT_WINDOW = self
		self.position += Vector2i(event.position - LAST_POSITION)
		#MAIN._input(event)
		return
		#print("moved inside window")
		#LAST_POSITION = Vector2i(event.position)
		#return
	if(event is InputEventMouseButton && event.is_pressed()):

			if(event.position.y<40 && event.position.x<450):
				LAST_POSITION = event.position
				self.unfocusable = true
				self.mouse_passthrough = true
				MAIN.MOVING_WINDOW = true
				MAIN.CURRENT_WINDOW = self;
				#print("clicked window")
			#else:
				#self.mouse_passthrough = false
				#self.unfocusable = false

	if(event is InputEventMouseButton && event.is_released() && MAIN.MOVING_WINDOW ==true):
		if(MAIN.CURRENT_WINDOW!=null):
			MAIN.CURRENT_WINDOW.unfocusable = true
			MAIN.CURRENT_WINDOW.mouse_passthrough = true
		self.mouse_passthrough = true
		self.unfocusable = true
		MAIN.CURRENT_WINDOW = self;
		MAIN.MOVING_WINDOW = true
		#print("stop moving window")
		stuck = true
		MAIN._input(event)


func _on_scroll_container_mouse_entered() -> void:
	self.unfocusable = false
	MAIN.CURRENT_WINDOW = self;
	#print("in")
	pass # Replace with function body.


func _on_scroll_container_mouse_exited() -> void:
	if(MAIN.MOVING_WINDOW == false):
		self.mouse_passthrough = false
		self.unfocusable = true
		MAIN.CURRENT_WINDOW = null;
		#MAIN.MOVING_WINDOW = true
		stuck = true

		#print(" out")
