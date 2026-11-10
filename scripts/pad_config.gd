class_name PadConfig
extends RefCounted

## Which of these three is active depends on the preset's global input_mode,
## not on the pad itself — this way switching modes doesn't erase mappings
## you learned in the other modes.
## -1 means "unassigned". Used when input_mode == "midi".
var trigger_note: int = -1
## Godot JoyButton index, or GamepadUtils.LEFT_TRIGGER/RIGHT_TRIGGER for the
## analog triggers. -1 means "unassigned". Used when input_mode == "gamepad".
var trigger_gamepad_button: int = -1
## MIDI note received from the keyboard-bridge virtual port (Karabiner-Elements
## remapping rtyufghj -> MIDI, routed through the IAC Driver). Kept separate
## from trigger_note so this doesn't collide with a real MIDI keyboard mapping.
## -1 means "unassigned". Used when input_mode == "keyboard".
var trigger_keyboard_note: int = -1
var chord_notes: Array[int] = []
var output_channel: int = 0 # 0-15 internally, shown as 1-16 in the UI
var velocity_mode: String = "passthrough" # "passthrough" | "fixed"
var fixed_velocity: int = 100

func to_dict() -> Dictionary:
	return {
		"trigger_note": trigger_note,
		"trigger_gamepad_button": trigger_gamepad_button,
		"trigger_keyboard_note": trigger_keyboard_note,
		"chord_notes": chord_notes.duplicate(),
		"output_channel": output_channel,
		"velocity_mode": velocity_mode,
		"fixed_velocity": fixed_velocity,
	}

static func from_dict(d: Dictionary) -> PadConfig:
	var pad := PadConfig.new()
	pad.trigger_note = int(d.get("trigger_note", -1))
	pad.trigger_gamepad_button = int(d.get("trigger_gamepad_button", -1))
	pad.trigger_keyboard_note = int(d.get("trigger_keyboard_note", -1))
	var notes: Array[int] = []
	for n in d.get("chord_notes", []):
		notes.append(int(n))
	pad.chord_notes = notes
	pad.output_channel = int(d.get("output_channel", 0))
	pad.velocity_mode = String(d.get("velocity_mode", "passthrough"))
	pad.fixed_velocity = int(d.get("fixed_velocity", 100))
	return pad
