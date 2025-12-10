extends Node

var seconds_for_reading_info_banner = 1.5;
var seconds_for_UI_ANIMATION = 0.15;
var seconds_for_drawing_cards = 0.2;
var seconds_for_auto_battler = 0.2;
var seconds_for_CPU_v_CPU = 0.5;
var SPEED = 1.0
var current_timers=[];
var SKIP_BUTTON
func _input(event:InputEvent):
	if(event.is_action_released("ui_select")):
		for timer:Timer in current_timers:
			timer.emit_signal("timeout")

#func _ready():
	#Performance.add_custom_monitor("game/current_timers", get_current_timers)


func get_current_timers()->int:
	return current_timers.size()

func for_seconds(seconds: float,skippable=false) -> void: #unskippable
	var current_timer = Timer.new()
	add_child(current_timer)

	if(skippable):
		current_timers.push_back(current_timer);
		#SKIP_BUTTON.show()

	current_timer.start(seconds / SPEED)
	await current_timer.timeout

	if(skippable):
		#SKIP_BUTTON.hide()
		current_timers.erase(current_timer);

	current_timer.queue_free()



func for_UI_animation() -> void: #skippable
	var current_timer = Timer.new()
	add_child(current_timer)
	current_timers.push_back(current_timer);

	var seconds = seconds_for_UI_ANIMATION / SPEED;
	current_timer.start(seconds)
	await current_timer.timeout

	current_timers.erase(current_timer);
	current_timer.queue_free()

func for_drawing_cards() -> void: #skippable
	var current_timer = Timer.new()
	add_child(current_timer)
	current_timers.push_back(current_timer);

	var seconds = seconds_for_drawing_cards / SPEED;
	current_timer.start(seconds)
	await current_timer.timeout

	current_timers.erase(current_timer);
	current_timer.queue_free()

func for_animation(Animation_Player:AnimationPlayer) -> void:
	var current_timer = Timer.new()
	add_child(current_timer)
	current_timers.push_back(current_timer);

	current_timer.start(Animation_Player.current_animation_length / SPEED)
	await current_timer.timeout

	current_timers.erase(current_timer);
	current_timer.queue_free()
