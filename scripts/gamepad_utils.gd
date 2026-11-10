class_name GamepadUtils
extends RefCounted

## Godot exposes LT/RT as analog axes, not buttons. They're represented here
## as pseudo button codes so a pad's trigger can be a single int regardless of
## whether it came from a real JoyButton or an axis threshold crossing.
const LEFT_TRIGGER := 100
const RIGHT_TRIGGER := 101

const BUTTON_NAMES := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_DPAD_UP: "D-Up",
	JOY_BUTTON_DPAD_DOWN: "D-Down",
	JOY_BUTTON_DPAD_LEFT: "D-Left",
	JOY_BUTTON_DPAD_RIGHT: "D-Right",
	JOY_BUTTON_GUIDE: "Guide",
}

static func button_name(code: int) -> String:
	if code == LEFT_TRIGGER:
		return "LT"
	if code == RIGHT_TRIGGER:
		return "RT"
	return BUTTON_NAMES.get(code, "Btn%d" % code)
