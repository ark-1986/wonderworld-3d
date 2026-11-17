extends Control
## Mobile joystick. Desktop users can also use WASD/arrow keys.

var axis: Vector2 = Vector2.ZERO
var active_touch: int = -1
var dragging_mouse: bool = false
var knob: Vector2 = Vector2.ZERO
const RADIUS: float = 60.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(175, 175)

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, 77.0, Color(0.04, 0.16, 0.30, 0.25))
	draw_arc(center, 73.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.65), 4.0, true)
	draw_circle(center + knob, 35.0, Color(0.98, 0.99, 1.0, 0.82))
	draw_arc(center + knob, 33.0, 0.0, TAU, 32, Color("4dbad9"), 3.0, true)

func _set_pointer(p: Vector2) -> void:
	knob = (p - size * 0.5).limit_length(RADIUS)
	axis = knob / RADIUS
	queue_redraw()

func _reset() -> void:
	axis = Vector2.ZERO
	knob = Vector2.ZERO
	active_touch = -1
	dragging_mouse = false
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1:
			active_touch = event.index
			_set_pointer(event.position)
			accept_event()
		elif not event.pressed and event.index == active_touch:
			_reset()
			accept_event()
	elif event is InputEventScreenDrag:
		if event.index == active_touch:
			_set_pointer(event.position)
			accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging_mouse = event.pressed
			if dragging_mouse:
				_set_pointer(event.position)
			else:
				_reset()
			accept_event()
	elif event is InputEventMouseMotion and dragging_mouse:
		_set_pointer(event.position)
		accept_event()
