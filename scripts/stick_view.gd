extends Control

## The lever on the left of the arcade body. Mirrors the gamepad's left stick
## live (MidiRouter.stick_moved: left stick, right stick or D-pad); the ball
## turns red while the lever is pushed off center.

const GATE_RADIUS := 64.0
const BALL_RADIUS := 30.0
const TRAVEL := 30.0

var _pos := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	MidiRouter.stick_moved.connect(_on_stick_moved)

func _on_stick_moved(x: float, y: float) -> void:
	_pos = Vector2(x, y).limit_length(1.0)
	queue_redraw()

func refresh() -> void:
	queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	draw_circle(center, GATE_RADIUS + 3.0, UiTheme.BLACK, true, -1.0, true)
	var ball_center := center + _pos * TRAVEL
	# Shaft "shadow" from gate center to the ball, so the tilt reads clearly.
	draw_line(center, ball_center, UiTheme.CONTROL_BORDER, 10.0, true)
	var active := _pos.length() > MidiRouter.STICK_DEADZONE
	var ball := UiTheme.RED if active else UiTheme.CONTROL
	var ring := UiTheme.RED_HOVER if active else UiTheme.CONTROL_BORDER_HOVER
	draw_circle(ball_center, BALL_RADIUS, ring, true, -1.0, true)
	draw_circle(ball_center, BALL_RADIUS - 3.0, ball, true, -1.0, true)
