extends Node

## Autoload singleton. Reads Note On/Off from a physical MIDI controller and
## button/trigger/stick input from a connected gamepad; for any input mapped
## to a pad, sends that pad's whole chord out through a MidiOut port (virtual
## port by default) so a DAW can receive it as normal MIDI input.

signal pad_triggered(pad_index: int)
signal pad_released(pad_index: int)
signal device_error(message: String)
## Emitted for every incoming Note On regardless of whether it's mapped to a
## pad. Used by the chord editor's "Learn" button to capture a trigger note.
signal raw_note_on(note: int)
## Emitted for every gamepad button press or analog-trigger crossing
## regardless of mapping. Same purpose as raw_note_on but for gamepad Learn.
signal raw_gamepad_button(code: int)
signal gamepad_status_changed(connected: bool, name: String)
## Fired alongside pad_triggered with the velocity actually sent, for the
## main window's display strip.
signal pad_played(pad_index: int, velocity: int)
## Lever position (-1..1 each axis, y down) for the on-screen lever. Follows
## whichever of left stick / right stick / D-pad is currently deflected, since
## an arcade stick's LS/DP/RS switch decides which one the lever reports as.
## Emitted regardless of stick_enabled (that only gates the MIDI output).
signal stick_moved(x: float, y: float)
## A D-pad direction sent its CC (for the main window's display strip).
signal dpad_cc_sent(direction: String, cc: int, value: int)

const GAMEPAD_DEFAULT_VELOCITY := 100
const STICK_DEADZONE := 0.10
const TRIGGER_THRESHOLD := 0.5
## Same order as ChordPreset.dpad_ccs.
const DPAD_BUTTONS := [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]
const DPAD_NAMES := ["Up", "Down", "Left", "Right"]
## Name of the IAC Driver virtual port the Karabiner -> keyboard bridge sends
## MIDI to. Fixed rather than user-selectable (unlike a real MIDI keyboard's
## input_port_name) since this bridge always talks to the one dedicated port.
## Must match the port name created in Audio MIDI Setup.
const KEYBOARD_BRIDGE_PORT_NAME := "ChordPad Keyboard"

var midi_in: MidiIn
var midi_out: MidiOut

var _preset: ChordPreset
var _trigger_lookup: Dictionary = {} # midi trigger_note (int) -> pad_index (int)
var _gamepad_trigger_lookup: Dictionary = {} # gamepad button code (int) -> pad_index (int)
## pad_index -> { "channel": int, "notes": Array[int] }, snapshotted at the
## moment a pad is triggered so a mapping edit made while the button is held
## can't desync the note-off from the note-on it belongs to.
var _active_notes: Dictionary = {}
var _analog_trigger_state: Dictionary = {} # LEFT_TRIGGER/RIGHT_TRIGGER -> bool pressed

var _left_stick := Vector2.ZERO
var _right_stick := Vector2.ZERO
var _dpad := Vector2.ZERO
var _last_bend: int = 0
var _last_cc: int = 64
## Smoothed lever outputs (attack/release ramps). key -> {cur, target, rest,
## span, sent}. Keys: "bend", "cc", "dpad0".."dpad3". `span` is the distance
## from rest to full deflection, which the attack/release times refer to.
var _ramps: Dictionary = {}

## godot-rtmidi's is_port_open() has been observed to not reliably reflect
## virtual-port state, so device readiness is tracked here instead of relying
## on it (both as a guard before send_message() and before re-opening).
var _input_configured: bool = false
var _output_configured: bool = false

func _ready() -> void:
	set_process(false)
	midi_in = MidiIn.new()
	midi_out = MidiOut.new()
	add_child(midi_in)
	add_child(midi_out)
	midi_in.midi_message.connect(_on_midi_message)
	midi_in.midi_error.connect(_on_midi_error)
	midi_out.midi_error.connect(_on_midi_error)

	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	var connected := Input.get_connected_joypads()
	if not connected.is_empty():
		gamepad_status_changed.emit(true, Input.get_joy_name(connected[0]))

func list_input_ports() -> PackedStringArray:
	return MidiIn.get_port_names()

func list_output_ports() -> PackedStringArray:
	return MidiOut.get_port_names()

func connect_input(port_index: int) -> void:
	if _input_configured:
		midi_in.close_port()
	midi_in.open_port(port_index)
	midi_in.ignore_types(true, true, true)
	_input_configured = true

func connect_input_by_name(port_name: String) -> bool:
	var index := list_input_ports().find(port_name)
	if index == -1:
		return false
	connect_input(index)
	return true

## Matches by suffix rather than exact string: RtMidi's CoreMIDI backend
## prefixes IAC input port names with the IAC device's own (locale-dependent)
## name, e.g. "IAC Driver ChordPad Keyboard" in English or "IAC驅動程式
## ChordPad Keyboard" under a Chinese system locale -- only the port name
## typed into Audio MIDI Setup is guaranteed stable.
func connect_input_by_suffix(suffix: String) -> bool:
	var ports := list_input_ports()
	for i in range(ports.size()):
		if ports[i].ends_with(suffix):
			connect_input(i)
			return true
	return false

func open_output_virtual(virtual_name: String) -> void:
	if _output_configured:
		midi_out.close_port()
	midi_out.open_virtual_port(virtual_name)
	_output_configured = true

func open_output_port(port_index: int) -> void:
	if _output_configured:
		midi_out.close_port()
	midi_out.open_port(port_index)
	_output_configured = true

## Reconnects only the input device from a preset. Safe to call whenever the
## user changes the input dropdown without disturbing the output port.
func apply_input(preset: ChordPreset) -> void:
	if preset.input_mode == "keyboard":
		if not connect_input_by_suffix(KEYBOARD_BRIDGE_PORT_NAME):
			device_error.emit("Virtual port \"%s\" not found -- enable IAC Driver in Audio MIDI Setup and add a port with this exact name." % KEYBOARD_BRIDGE_PORT_NAME)
	elif not preset.input_port_name.is_empty():
		connect_input_by_name(preset.input_port_name)

## Reconnects only the output device/virtual port from a preset. Safe to call
## whenever the user changes the output dropdown without disturbing input.
func apply_output(preset: ChordPreset) -> void:
	if preset.output_mode == "virtual":
		open_output_virtual(preset.output_virtual_name)
	else:
		var index := list_output_ports().find(preset.output_mode)
		if index != -1:
			open_output_port(index)

## Applies a preset's device selection and chord mappings wholesale (used when
## switching to a different preset file, or on initial load). Any notes still
## sounding from the previous preset are force-stopped first.
func set_active_preset(preset: ChordPreset) -> void:
	panic()
	_preset = preset
	rebuild_trigger_lookup()
	apply_input(preset)
	apply_output(preset)

## Re-derives the trigger -> pad_index lookup for whichever input source the
## preset's global input_mode currently selects (the other lookup is left
## empty, so input from the inactive source is simply ignored). Call after
## editing a pad's trigger or chord in place (the popup mutates PadConfig
## objects that already live inside the active preset, so no device
## reconnection is needed for that case) or after switching input_mode.
func rebuild_trigger_lookup() -> void:
	_trigger_lookup.clear()
	_gamepad_trigger_lookup.clear()
	if _preset == null:
		return
	for i in range(_preset.pads.size()):
		var pad: PadConfig = _preset.pads[i]
		if _preset.input_mode == "gamepad":
			if pad.trigger_gamepad_button >= 0:
				_gamepad_trigger_lookup[pad.trigger_gamepad_button] = i
		elif _preset.input_mode == "keyboard":
			if pad.trigger_keyboard_note >= 0:
				_trigger_lookup[pad.trigger_keyboard_note] = i
		else:
			if pad.trigger_note >= 0:
				_trigger_lookup[pad.trigger_note] = i

## Fills any pad that has no gamepad trigger yet with the user's physical
## 8BitDo Arcade Stick layout (top row X Y RB LB, bottom row A B RT LT), so
## Xbox Controller mode is immediately usable without manually Learning all 8
## pads and the on-screen grid matches the real button positions. Existing
## gamepad mappings are left untouched.
func apply_xbox_defaults(preset: ChordPreset) -> void:
	var defaults := [
		JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_SHOULDER,
		JOY_BUTTON_A, JOY_BUTTON_B, GamepadUtils.RIGHT_TRIGGER, GamepadUtils.LEFT_TRIGGER,
	]
	for i in range(min(preset.pads.size(), defaults.size())):
		var pad: PadConfig = preset.pads[i]
		if pad.trigger_gamepad_button < 0:
			pad.trigger_gamepad_button = defaults[i]

## Fills any pad that has no keyboard trigger yet with the RTYU/FGHJ layout
## matching the on-screen 4-column grid (top row RTYU, bottom row FGHJ) --
## the same physical row order the Karabiner rule sends as MIDI notes.
## Existing keyboard mappings are left untouched.
func apply_keyboard_defaults(preset: ChordPreset) -> void:
	for i in range(preset.pads.size()):
		var pad: PadConfig = preset.pads[i]
		if pad.trigger_keyboard_note < 0:
			pad.trigger_keyboard_note = KeyboardUtils.note_for_pad(i)

func _on_midi_error(_error_type: int, error_message: String) -> void:
	device_error.emit(error_message)

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	gamepad_status_changed.emit(connected, Input.get_joy_name(device) if connected else "")

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_on_joy_button(event.button_index, event.pressed)
	elif event is InputEventJoypadMotion:
		_on_joy_motion(event.axis, event.axis_value)

func _on_joy_button(button_index: int, pressed: bool) -> void:
	_update_dpad(button_index, pressed)
	if pressed:
		raw_gamepad_button.emit(button_index)
	if not _gamepad_trigger_lookup.has(button_index):
		_handle_dpad_cc(button_index, pressed)
		return
	var pad_index: int = _gamepad_trigger_lookup[button_index]
	if pressed:
		_trigger_pad_by_index(pad_index, GAMEPAD_DEFAULT_VELOCITY)
	else:
		_release_pad_by_index(pad_index)

func _on_joy_motion(axis: int, value: float) -> void:
	if axis == JOY_AXIS_TRIGGER_LEFT:
		_handle_analog_trigger(GamepadUtils.LEFT_TRIGGER, value)
	elif axis == JOY_AXIS_TRIGGER_RIGHT:
		_handle_analog_trigger(GamepadUtils.RIGHT_TRIGGER, value)
	elif axis == JOY_AXIS_LEFT_Y:
		_left_stick.y = value
		_emit_lever()
		_handle_stick_pitchbend(value)
	elif axis == JOY_AXIS_LEFT_X:
		_left_stick.x = value
		_emit_lever()
		_handle_stick_cc(value)
	elif axis == JOY_AXIS_RIGHT_X:
		_right_stick.x = value
		_emit_lever()
	elif axis == JOY_AXIS_RIGHT_Y:
		_right_stick.y = value
		_emit_lever()

func _update_dpad(button_index: int, pressed: bool) -> void:
	match button_index:
		JOY_BUTTON_DPAD_UP: _dpad.y = _dpad_axis(_dpad.y, -1.0, pressed)
		JOY_BUTTON_DPAD_DOWN: _dpad.y = _dpad_axis(_dpad.y, 1.0, pressed)
		JOY_BUTTON_DPAD_LEFT: _dpad.x = _dpad_axis(_dpad.x, -1.0, pressed)
		JOY_BUTTON_DPAD_RIGHT: _dpad.x = _dpad_axis(_dpad.x, 1.0, pressed)
		_: return
	_emit_lever()

## D-pad direction -> its own CC: 127 while held, 0 on release. Only reached
## for directions that aren't Learned as a pad trigger.
func _handle_dpad_cc(button_index: int, pressed: bool) -> void:
	var i := DPAD_BUTTONS.find(button_index)
	if i == -1 or _preset == null or not _preset.dpad_enabled:
		return
	var cc: int = _preset.dpad_ccs[i]
	var value := 127 if pressed else 0
	_set_ramp("dpad%d" % i, value, 0.0, 127.0)
	dpad_cc_sent.emit(DPAD_NAMES[i], cc, value)

## Press sets the axis to `direction`; release only clears it if that same
## direction is still the one held (so rolling up->down doesn't snap to 0).
static func _dpad_axis(current: float, direction: float, pressed: bool) -> float:
	if pressed:
		return direction
	return 0.0 if current == direction else current

func _emit_lever() -> void:
	var pos := _dpad
	if _left_stick.length() > STICK_DEADZONE:
		pos = _left_stick
	elif _right_stick.length() > STICK_DEADZONE:
		pos = _right_stick
	stick_moved.emit(pos.x, pos.y)

func _handle_analog_trigger(code: int, value: float) -> void:
	var pressed := value > TRIGGER_THRESHOLD
	var was_pressed: bool = _analog_trigger_state.get(code, false)
	if pressed == was_pressed:
		return
	_analog_trigger_state[code] = pressed
	if pressed:
		raw_gamepad_button.emit(code)
	if not _gamepad_trigger_lookup.has(code):
		return
	var pad_index: int = _gamepad_trigger_lookup[code]
	if pressed:
		_trigger_pad_by_index(pad_index, int(clampf(value, 0.0, 1.0) * 127))
	else:
		_release_pad_by_index(pad_index)

## Left stick up/down -> pitch bend. Mirrors Xbox2MIDI: up is negative on the
## axis, inverted here so pushing up bends pitch up.
func _handle_stick_pitchbend(value: float) -> void:
	if _preset == null or not _preset.stick_enabled:
		return
	var centered := absf(value) < STICK_DEADZONE
	var bend := 0 if centered else int(clampf(roundf(-value * 8191.0), -8192.0, 8191.0))
	if bend == _last_bend:
		return
	_last_bend = bend
	_set_ramp("bend", bend, 0.0, 8192.0)

## Left stick left/right -> a configurable CC (default CC28), matching
## Xbox2MIDI's behavior.
func _handle_stick_cc(value: float) -> void:
	if _preset == null or not _preset.stick_enabled:
		return
	var centered := absf(value) < STICK_DEADZONE
	var cc_val := 64 if centered else int(clampf(roundf((value + 1.0) / 2.0 * 127.0), 0.0, 127.0))
	if cc_val == _last_cc:
		return
	_last_cc = cc_val
	_set_ramp("cc", cc_val, 64.0, 64.0)

## Sends a centered pitch bend / CC once so the stick doesn't leave a DAW
## track bent or a CC stuck off-center. Safe to call even if never bent.
func reset_stick() -> void:
	if _output_configured and _preset != null:
		midi_out.send_message(PackedByteArray([0xE0 | _preset.stick_channel, 0, 64]))
		midi_out.send_message(PackedByteArray([0xB0 | _preset.stick_channel, _preset.stick_cc, 64]))
	_last_bend = 0
	_last_cc = 64
	for key in ["bend", "cc"]:
		_snap_ramp_to_rest(key)

func _on_midi_message(_delta: float, message: PackedByteArray) -> void:
	if message.size() < 2:
		return
	var status := message[0] & 0xF0
	var note := message[1]
	var velocity := message[2] if message.size() > 2 else 0

	# Some hardware sends Note On with velocity 0 instead of a real Note Off.
	var is_note_on := status == 0x90 and velocity > 0
	var is_note_off := status == 0x80 or (status == 0x90 and velocity == 0)

	if is_note_on:
		raw_note_on.emit(note)
		if _trigger_lookup.has(note):
			_trigger_pad_by_index(_trigger_lookup[note], velocity)
	elif is_note_off:
		if _trigger_lookup.has(note):
			_release_pad_by_index(_trigger_lookup[note])

func _trigger_pad_by_index(pad_index: int, velocity: int) -> void:
	var pad: PadConfig = _preset.pads[pad_index]
	var out_velocity := pad.fixed_velocity if pad.velocity_mode == "fixed" else velocity

	var sounding_notes: Array[int] = []
	if _output_configured:
		for chord_note in pad.chord_notes:
			midi_out.send_message(PackedByteArray([0x90 | pad.output_channel, chord_note, out_velocity]))
			sounding_notes.append(chord_note)

	_active_notes[pad_index] = {"channel": pad.output_channel, "notes": sounding_notes}
	pad_triggered.emit(pad_index)
	pad_played.emit(pad_index, out_velocity)

func _release_pad_by_index(pad_index: int) -> void:
	if not _active_notes.has(pad_index):
		return
	var entry: Dictionary = _active_notes[pad_index]
	if _output_configured:
		for chord_note in entry["notes"]:
			midi_out.send_message(PackedByteArray([0x80 | entry["channel"], chord_note, 0]))
	_active_notes.erase(pad_index)
	pad_released.emit(pad_index)

## Force-stops every currently sounding note and centers the stick. Wired to
## the UI's "Panic" button and also called whenever the active preset changes.
func panic() -> void:
	if _output_configured:
		for pad_index in _active_notes.keys():
			var entry: Dictionary = _active_notes[pad_index]
			for chord_note in entry["notes"]:
				midi_out.send_message(PackedByteArray([0x80 | entry["channel"], chord_note, 0]))
	_active_notes.clear()
	reset_stick()
	if _output_configured and _preset != null and _preset.dpad_enabled:
		for cc in _preset.dpad_ccs:
			midi_out.send_message(PackedByteArray([0xB0 | _preset.stick_channel, cc, 0]))
	for i in range(DPAD_BUTTONS.size()):
		_snap_ramp_to_rest("dpad%d" % i)

# --- Lever attack / release smoothing ---------------------------------------

## Points a ramp at a new target. Moving away from rest uses the preset's
## attack time, moving back toward rest uses its release time (a jump across
## rest, e.g. bend up -> bend down, releases to rest first, then attacks).
## With a time of 0 the value is sent immediately, same as before smoothing.
func _set_ramp(key: String, target: float, rest: float, span: float) -> void:
	if not _ramps.has(key):
		_ramps[key] = {"cur": rest, "target": rest, "rest": rest, "span": span, "sent": int(rest)}
	_ramps[key]["target"] = target
	_step_ramp(key, 0.0)
	if _ramps[key]["cur"] != target:
		set_process(true)

func _process(delta: float) -> void:
	var moving := false
	for key in _ramps:
		_step_ramp(key, delta)
		if _ramps[key]["cur"] != _ramps[key]["target"]:
			moving = true
	if not moving:
		set_process(false)

func _step_ramp(key: String, delta: float) -> void:
	var r: Dictionary = _ramps[key]
	var cur: float = r["cur"]
	var target: float = r["target"]
	var rest: float = r["rest"]
	if cur == target:
		return
	var goal := target
	if (cur - rest) * (target - rest) < 0.0:
		goal = rest
	var attacking := absf(goal - rest) > absf(cur - rest)
	var ms := 0
	if _preset != null:
		ms = _preset.lever_attack_ms if attacking else _preset.lever_release_ms
	if ms <= 0:
		cur = goal
	else:
		cur = move_toward(cur, goal, float(r["span"]) * delta * 1000.0 / ms)
	r["cur"] = cur
	var value := int(roundf(cur))
	if value != r["sent"]:
		r["sent"] = value
		_send_ramp_value(key, value)
	# Crossing rest within one step (instant release) -> continue to the target.
	if cur == rest and goal == rest and target != rest:
		_step_ramp(key, delta)

func _snap_ramp_to_rest(key: String) -> void:
	if not _ramps.has(key):
		return
	var r: Dictionary = _ramps[key]
	r["cur"] = r["rest"]
	r["target"] = r["rest"]
	r["sent"] = int(r["rest"])

func _send_ramp_value(key: String, value: int) -> void:
	if not _output_configured or _preset == null:
		return
	var ch := _preset.stick_channel
	match key:
		"bend":
			var midi_value := clampi(value + 8192, 0, 16383)
			midi_out.send_message(PackedByteArray([0xE0 | ch, midi_value & 0x7F, (midi_value >> 7) & 0x7F]))
		"cc":
			midi_out.send_message(PackedByteArray([0xB0 | ch, _preset.stick_cc, clampi(value, 0, 127)]))
		_:
			var i := int(key.substr(4))
			midi_out.send_message(PackedByteArray([0xB0 | ch, _preset.dpad_ccs[i], clampi(value, 0, 127)]))

## Closes both MIDI ports before the app quits. godot_rtmidi has been
## observed to crash during engine shutdown if its ports are still open when
## the extension gets torn down, so this runs first while everything is
## still alive, rather than relying on the engine's own cleanup order.
func shutdown() -> void:
	panic()
	if _input_configured:
		midi_in.close_port()
		_input_configured = false
	if _output_configured:
		midi_out.close_port()
		_output_configured = false
