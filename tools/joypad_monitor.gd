extends SceneTree

## Prints every gamepad event Godot receives, to diagnose what a controller
## (e.g. an arcade stick's LS / DP / RS lever modes) actually reports.
## Close the window (or Ctrl+C) to stop.
##   /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/joypad_monitor.gd

const AXIS_NAMES := ["LeftX", "LeftY", "RightX", "RightY", "LT", "RT"]
var _last_axis := {}

func _initialize() -> void:
	root.title = "Joypad monitor - press buttons / move the lever"
	root.size = Vector2i(480, 120)
	Input.joy_connection_changed.connect(func(d, c): print("[connect] device=%d connected=%s name=%s" % [d, c, Input.get_joy_name(d)]))
	for d in Input.get_connected_joypads():
		print("[device] %d  name=\"%s\"  known_mapping=%s  guid=%s" % [d, Input.get_joy_name(d), Input.is_joy_known(d), Input.get_joy_guid(d)])
	if Input.get_connected_joypads().is_empty():
		print("[device] none connected")
	root.window_input.connect(_on_input)

func _on_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		print("[button] %-12s index=%d pressed=%s" % [GamepadUtils.button_name(event.button_index), event.button_index, event.pressed])
	elif event is InputEventJoypadMotion:
		# Only print meaningful changes so analog noise doesn't flood the log.
		var v := snappedf(event.axis_value, 0.1)
		if _last_axis.get(event.axis, 99.0) == v:
			return
		_last_axis[event.axis] = v
		var axis_name: String = AXIS_NAMES[event.axis] if event.axis < AXIS_NAMES.size() else "Axis%d" % event.axis
		print("[axis]   %-12s index=%d value=%.1f" % [axis_name, event.axis, v])
