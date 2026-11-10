extends Control

const ChordEditPopupScene := preload("res://scenes/chord_edit_popup.tscn")
const PadButtonScene := preload("res://scenes/pad_button.tscn")

## Order matches the MIDI / XBOX / KEYS mode switch buttons.
const INPUT_MODES := ["midi", "gamepad", "keyboard"]

## Button centers inside PadArea (558x248), traced from the physical 8-button
## arcade stick: top row X Y RB LB (left one sits lower), bottom row A B RT LT.
## Index order matches MidiRouter.apply_xbox_defaults() / the RTYU-FGHJ keys.
const PAD_CENTERS := [
	Vector2(125, 93), Vector2(227, 58), Vector2(340, 58), Vector2(454, 58),
	Vector2(104, 191), Vector2(206, 157), Vector2(320, 157), Vector2(433, 157),
]

@onready var midi_mode_button: Button = %MidiModeButton
@onready var gamepad_mode_button: Button = %GamepadModeButton
@onready var keys_mode_button: Button = %KeysModeButton
@onready var settings_button: Button = %SettingsButton
@onready var refresh_button: Button = %RefreshButton
@onready var save_button: Button = %SaveButton
@onready var preset_dropdown: OptionButton = %PresetDropdown
@onready var output_info_label: Label = %OutputInfoLabel
@onready var panic_button: Button = %PanicButton
@onready var sampler_button: Button = %SamplerButton
@onready var stick_view: Control = %StickView
@onready var stick_caption: Label = %StickCaption
@onready var pad_area: Control = %PadArea
@onready var display_chord_label: Label = %DisplayChordLabel
@onready var display_notes_label: Label = %DisplayNotesLabel
@onready var status_label: Label = %StatusLabel
@onready var gamepad_status_label: Label = %GamepadStatusLabel

@onready var settings_window: Window = %SettingsWindow
@onready var input_caption: Label = %InputCaption
@onready var input_device_dropdown: OptionButton = %InputDeviceDropdown
@onready var output_mode_dropdown: OptionButton = %OutputModeDropdown
@onready var stick_enable_check: CheckBox = %StickEnableCheck
@onready var dpad_enable_check: CheckBox = %DpadEnableCheck
@onready var ramp_row: Control = %RampRow
@onready var attack_spin: SpinBox = %AttackSpin
@onready var release_spin: SpinBox = %ReleaseSpin
@onready var new_preset_name_field: LineEdit = %NewPresetNameField
@onready var save_as_button: Button = %SaveAsButton
@onready var reveal_presets_button: Button = %RevealPresetsButton
@onready var close_settings_button: Button = %CloseSettingsButton

var _mode_buttons: Array[Button] = []
var _pad_buttons: Array = []
var _chord_popup
var _output_ports_cache: PackedStringArray = []

func _ready() -> void:
	var window := get_window()
	window.always_on_top = true
	window.unresizable = true

	# godot_rtmidi segfaults inside its own static teardown code whenever the
	# engine unloads the extension on normal exit (independent of port state
	# -- closing ports first doesn't help). Skipping Godot's own shutdown
	# path and terminating the process directly avoids ever reaching that
	# buggy code.
	get_tree().set_auto_accept_quit(false)
	window.close_requested.connect(_on_close_requested)

	_chord_popup = ChordEditPopupScene.instantiate()
	add_child(_chord_popup)
	_chord_popup.saved.connect(_on_chord_saved)

	for i in range(ChordPreset.PAD_COUNT):
		var pad_button = PadButtonScene.instantiate()
		pad_button.pad_index = i
		pad_button.edit_requested.connect(_on_pad_edit_requested)
		pad_area.add_child(pad_button)
		pad_button.position = PAD_CENTERS[i] - pad_button.custom_minimum_size / 2.0
		_pad_buttons.append(pad_button)

	_mode_buttons = [midi_mode_button, gamepad_mode_button, keys_mode_button]
	var mode_group := ButtonGroup.new()
	for i in range(_mode_buttons.size()):
		_mode_buttons[i].button_group = mode_group
		_mode_buttons[i].pressed.connect(_on_input_mode_selected.bind(i))

	settings_button.pressed.connect(_open_settings)
	close_settings_button.pressed.connect(settings_window.hide)
	settings_window.close_requested.connect(settings_window.hide)
	refresh_button.icon = UiTheme.refresh_icon()
	refresh_button.pressed.connect(_refresh_devices)
	input_device_dropdown.item_selected.connect(_on_input_device_selected)
	output_mode_dropdown.item_selected.connect(_on_output_mode_selected)
	preset_dropdown.item_selected.connect(_on_preset_selected)
	save_button.pressed.connect(_on_save_pressed)
	save_as_button.pressed.connect(_on_save_as_pressed)
	new_preset_name_field.text_submitted.connect(func(_t): _on_save_as_pressed())
	panic_button.pressed.connect(MidiRouter.panic)
	sampler_button.pressed.connect(_on_sampler_pressed)
	reveal_presets_button.pressed.connect(PresetManager.reveal_presets_folder)
	stick_enable_check.toggled.connect(_on_stick_toggled)
	dpad_enable_check.toggled.connect(func(on): PresetManager.current_preset.dpad_enabled = on)
	attack_spin.value_changed.connect(func(v): PresetManager.current_preset.lever_attack_ms = int(v))
	release_spin.value_changed.connect(func(v): PresetManager.current_preset.lever_release_ms = int(v))

	MidiRouter.device_error.connect(_on_device_error)
	MidiRouter.gamepad_status_changed.connect(_on_gamepad_status_changed)
	MidiRouter.pad_played.connect(_on_pad_played)
	MidiRouter.dpad_cc_sent.connect(_on_dpad_cc_sent)
	PresetManager.preset_changed.connect(_refresh_all)

	_refresh_devices()
	_refresh_preset_dropdown()
	_refresh_all()
	_init_gamepad_status()

func _open_settings() -> void:
	settings_window.reset_size()
	settings_window.popup_centered()

func _init_gamepad_status() -> void:
	var connected := Input.get_connected_joypads()
	if not connected.is_empty():
		_on_gamepad_status_changed(true, Input.get_joy_name(connected[0]))

func _on_gamepad_status_changed(connected: bool, gamepad_name: String) -> void:
	gamepad_status_label.text = "Controller: %s" % gamepad_name if connected else "Controller: none"

func _on_stick_toggled(pressed: bool) -> void:
	PresetManager.current_preset.stick_enabled = pressed
	if not pressed:
		MidiRouter.reset_stick()
	_update_stick_caption()

func _update_stick_caption() -> void:
	var on := PresetManager.current_preset.stick_enabled
	stick_caption.text = "STICK → BEND / CC" if on else "STICK OFF"
	stick_view.refresh()

func _on_input_mode_selected(index: int) -> void:
	var preset := PresetManager.current_preset
	preset.input_mode = INPUT_MODES[index]
	match preset.input_mode:
		"gamepad":
			MidiRouter.apply_xbox_defaults(preset)
		"keyboard":
			MidiRouter.apply_keyboard_defaults(preset)
			MidiRouter.apply_input(preset)
		_:
			MidiRouter.apply_input(preset)
	MidiRouter.rebuild_trigger_lookup()
	_refresh_all()

func _update_mode_visibility() -> void:
	var mode := PresetManager.current_preset.input_mode
	var mode_index := INPUT_MODES.find(mode)
	if mode_index != -1:
		_mode_buttons[mode_index].set_pressed_no_signal(true)
	input_caption.visible = mode == "midi"
	input_device_dropdown.visible = mode == "midi"
	stick_enable_check.visible = mode == "gamepad"
	dpad_enable_check.visible = mode == "gamepad"
	ramp_row.visible = mode == "gamepad"

func _refresh_devices() -> void:
	input_device_dropdown.clear()
	var input_ports := MidiRouter.list_input_ports()
	for i in range(input_ports.size()):
		var raw_name := input_ports[i]
		input_device_dropdown.add_item(StringUtils.fix_mojibake(raw_name))
		input_device_dropdown.set_item_metadata(i, raw_name)
	var current_input := PresetManager.current_preset.input_port_name
	var input_index := input_ports.find(current_input)
	if input_index != -1:
		input_device_dropdown.select(input_index)

	output_mode_dropdown.clear()
	output_mode_dropdown.add_item("Virtual Port")
	_output_ports_cache = MidiRouter.list_output_ports()
	for port_name in _output_ports_cache:
		output_mode_dropdown.add_item(StringUtils.fix_mojibake(port_name))
	var preset := PresetManager.current_preset
	if preset.output_mode == "virtual":
		output_mode_dropdown.select(0)
	else:
		var out_index := _output_ports_cache.find(preset.output_mode)
		if out_index != -1:
			output_mode_dropdown.select(out_index + 1)
	_update_output_info()

	_init_gamepad_status()
	if PresetManager.current_preset.input_mode == "keyboard":
		MidiRouter.apply_input(PresetManager.current_preset)

func _update_output_info() -> void:
	var preset := PresetManager.current_preset
	if preset.output_mode == "virtual":
		output_info_label.text = "Out: %s (virtual)" % preset.output_virtual_name
	else:
		output_info_label.text = "Out: %s" % StringUtils.fix_mojibake(preset.output_mode)

func _on_input_device_selected(index: int) -> void:
	var preset := PresetManager.current_preset
	preset.input_port_name = input_device_dropdown.get_item_metadata(index)
	MidiRouter.apply_input(preset)

func _on_output_mode_selected(index: int) -> void:
	var preset := PresetManager.current_preset
	if index == 0:
		preset.output_mode = "virtual"
	else:
		preset.output_mode = _output_ports_cache[index - 1]
	MidiRouter.apply_output(preset)
	_update_output_info()

func _refresh_preset_dropdown() -> void:
	preset_dropdown.clear()
	var names := PresetManager.list_preset_files()
	for i in range(names.size()):
		preset_dropdown.add_item(names[i])
		if names[i] == PresetManager.current_preset.preset_name:
			preset_dropdown.select(i)

func _on_preset_selected(index: int) -> void:
	var preset_name := preset_dropdown.get_item_text(index)
	PresetManager.load_preset(preset_name)
	_refresh_devices()

func _on_save_pressed() -> void:
	PresetManager.save_preset(PresetManager.current_preset)
	_refresh_preset_dropdown()
	_set_status("Saved \"%s\"" % PresetManager.current_preset.preset_name)

func _on_save_as_pressed() -> void:
	var new_name := new_preset_name_field.text.strip_edges()
	if new_name.is_empty():
		return
	PresetManager.save_preset_as(PresetManager.current_preset, new_name)
	new_preset_name_field.text = ""
	_refresh_preset_dropdown()
	_set_status("Saved as \"%s\"" % new_name)

func _on_pad_edit_requested(pad_index: int) -> void:
	var pad := PresetManager.current_preset.pads[pad_index]
	_chord_popup.open_for_pad(pad_index, pad)

func _on_chord_saved(_pad_index: int) -> void:
	MidiRouter.rebuild_trigger_lookup()
	_refresh_all()

## Shows what was just played in the bottom "display" strip.
func _on_pad_played(pad_index: int, velocity: int) -> void:
	var pad := PresetManager.current_preset.pads[pad_index]
	var note_names := PackedStringArray()
	for n in pad.chord_notes:
		note_names.append(NoteUtils.note_number_to_name(n))
	var symbol := ChordTheory.detect_chord_symbol(pad.chord_notes)
	if symbol.is_empty():
		symbol = note_names[0] if note_names.size() == 1 else "Pad %d" % (pad_index + 1)
	display_chord_label.text = symbol
	display_notes_label.text = "%s   ·   Ch %d   ·   Vel %d" % [
		" ".join(note_names) if not note_names.is_empty() else "unassigned",
		pad.output_channel + 1, velocity,
	]

## Shows D-pad CC presses in the display strip (releases are silent so the
## strip keeps showing which CC was last used -- handy while MIDI-mapping).
func _on_dpad_cc_sent(direction: String, cc: int, value: int) -> void:
	if value == 0:
		return
	display_chord_label.text = "CC%d" % cc
	display_notes_label.text = "D-pad %s   ·   CC %d = %d   ·   Ch %d" % [
		direction, cc, value, PresetManager.current_preset.stick_channel + 1,
	]

## Reassigns every pad to a single consecutive note (C1..G1, matching
## Ableton's own Drum Rack pad-to-note convention) instead of a chord, for
## quickly repurposing the same 8 trigger buttons/keys to play one-shot
## samples. Trigger assignments are left untouched. Not saved to disk until
## the user presses Save, so it's easy to undo by reloading the preset.
func _on_sampler_pressed() -> void:
	var preset := PresetManager.current_preset
	for i in range(preset.pads.size()):
		preset.pads[i].chord_notes = [36 + i]
	_refresh_all()
	_set_status("Sampler layout applied (not saved yet)")

func _refresh_all() -> void:
	var preset := PresetManager.current_preset
	for i in range(_pad_buttons.size()):
		_pad_buttons[i].refresh(preset.pads[i])
	stick_enable_check.set_pressed_no_signal(preset.stick_enabled)
	dpad_enable_check.set_pressed_no_signal(preset.dpad_enabled)
	attack_spin.set_value_no_signal(preset.lever_attack_ms)
	release_spin.set_value_no_signal(preset.lever_release_ms)
	dpad_enable_check.text = "D-pad → CC %d / %d / %d / %d (up / down / left / right)" % preset.dpad_ccs
	_update_stick_caption()
	_update_mode_visibility()
	_update_output_info()

func _set_status(message: String, is_error: bool = false) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", UiTheme.RED if is_error else UiTheme.TEXT_DIM)

func _on_close_requested() -> void:
	MidiRouter.shutdown()
	# Force-terminate immediately rather than get_tree().quit(), which would
	# still run Godot's normal shutdown sequence (and hit the extension's
	# crashing teardown code). Our own state is already safe at this point --
	# presets are only ever written on an explicit Save, not on exit.
	OS.kill(OS.get_process_id())

func _on_device_error(message: String) -> void:
	_set_status(message, true)
