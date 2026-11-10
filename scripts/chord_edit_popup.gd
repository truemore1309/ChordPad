extends Window

## Per-pad chord editor. Edits a PadConfig in place and emits `saved` on
## confirm; PresetManager.save_preset() is responsible for persisting to disk.

signal saved(pad_index: int)

var pad_index: int = -1
var _pad: PadConfig
var _working_notes: Array[int] = []
## All three kept independently regardless of the active input_mode, so
## switching modes later doesn't discard whichever ones aren't currently active.
var _working_trigger_note: int = -1
var _working_trigger_gamepad: int = -1
var _working_trigger_keyboard: int = -1
var _learn_pending: bool = false

@onready var title_label: Label = %TitleLabel
@onready var trigger_value_label: Label = %TriggerValueLabel
@onready var learn_button: Button = %LearnButton
@onready var chord_list: ItemList = %ChordList
@onready var note_option: OptionButton = %NoteOption
@onready var octave_spin: SpinBox = %OctaveSpin
@onready var chord_type_option: OptionButton = %ChordTypeOption
@onready var velocity_mode_option: OptionButton = %VelocityModeOption
@onready var fixed_velocity_spin: SpinBox = %FixedVelocitySpin
@onready var channel_spin: SpinBox = %ChannelSpin

func _ready() -> void:
	for note_name in NoteUtils.SHARP_NAMES:
		note_option.add_item(note_name)
	for quality_name in ChordTheory.quality_names():
		chord_type_option.add_item(quality_name)
	velocity_mode_option.add_item("Passthrough")
	velocity_mode_option.add_item("Fixed")
	velocity_mode_option.item_selected.connect(_on_velocity_mode_selected)
	close_requested.connect(_on_cancel_pressed)

func open_for_pad(index: int, pad: PadConfig) -> void:
	pad_index = index
	_pad = pad
	_working_notes = pad.chord_notes.duplicate()
	_working_trigger_note = pad.trigger_note
	_working_trigger_gamepad = pad.trigger_gamepad_button
	_working_trigger_keyboard = pad.trigger_keyboard_note

	title_label.text = "Pad %d" % (index + 1)
	_refresh_trigger_label()

	channel_spin.value = pad.output_channel + 1
	velocity_mode_option.select(1 if pad.velocity_mode == "fixed" else 0)
	fixed_velocity_spin.value = pad.fixed_velocity
	fixed_velocity_spin.editable = pad.velocity_mode == "fixed"

	_refresh_chord_list()
	popup_centered()

func _refresh_chord_list() -> void:
	chord_list.clear()
	for note in _working_notes:
		chord_list.add_item(NoteUtils.note_number_to_name(note))

func _refresh_trigger_label() -> void:
	match PresetManager.current_preset.input_mode:
		"gamepad":
			trigger_value_label.text = "—" if _working_trigger_gamepad < 0 else GamepadUtils.button_name(_working_trigger_gamepad)
		"keyboard":
			trigger_value_label.text = "—" if _working_trigger_keyboard < 0 else KeyboardUtils.key_label(_working_trigger_keyboard)
		_:
			trigger_value_label.text = "—" if _working_trigger_note < 0 else NoteUtils.note_number_to_name(_working_trigger_note)

## Learn listens only to whichever input source the preset's global mode
## currently selects, so there's no ambiguity about what a press will map to.
func _on_learn_pressed() -> void:
	if _learn_pending:
		_cancel_learn()
		return
	_learn_pending = true
	learn_button.text = "Listening…"
	match PresetManager.current_preset.input_mode:
		"gamepad":
			MidiRouter.raw_gamepad_button.connect(_on_gamepad_learned, CONNECT_ONE_SHOT)
		"keyboard":
			MidiRouter.raw_note_on.connect(_on_keyboard_learned, CONNECT_ONE_SHOT)
		_:
			MidiRouter.raw_note_on.connect(_on_note_learned, CONNECT_ONE_SHOT)

func _on_note_learned(note: int) -> void:
	_cancel_learn()
	_working_trigger_note = note
	_refresh_trigger_label()

func _on_gamepad_learned(code: int) -> void:
	_cancel_learn()
	_working_trigger_gamepad = code
	_refresh_trigger_label()

func _on_keyboard_learned(note: int) -> void:
	_cancel_learn()
	_working_trigger_keyboard = note
	_refresh_trigger_label()

func _cancel_learn() -> void:
	if MidiRouter.raw_note_on.is_connected(_on_note_learned):
		MidiRouter.raw_note_on.disconnect(_on_note_learned)
	if MidiRouter.raw_note_on.is_connected(_on_keyboard_learned):
		MidiRouter.raw_note_on.disconnect(_on_keyboard_learned)
	if MidiRouter.raw_gamepad_button.is_connected(_on_gamepad_learned):
		MidiRouter.raw_gamepad_button.disconnect(_on_gamepad_learned)
	_learn_pending = false
	learn_button.text = "Learn"

func _on_add_note_pressed() -> void:
	var semitone := note_option.selected
	var octave := int(octave_spin.value)
	var note := NoteUtils.note_from_parts(semitone, octave)
	if note in _working_notes:
		return
	_working_notes.append(note)
	_working_notes.sort()
	_refresh_chord_list()

## Replaces the whole chord with root note + octave (reusing the Add Note
## picker above) expanded through the selected chord quality's intervals.
func _on_generate_chord_pressed() -> void:
	var semitone := note_option.selected
	var octave := int(octave_spin.value)
	var root := NoteUtils.note_from_parts(semitone, octave)
	var quality := chord_type_option.get_item_text(chord_type_option.selected)
	_working_notes = ChordTheory.generate_chord(root, quality)
	_working_notes.sort()
	_refresh_chord_list()

func _on_remove_selected_pressed() -> void:
	var selected := chord_list.get_selected_items()
	if selected.is_empty():
		return
	_working_notes.remove_at(selected[0])
	_refresh_chord_list()

func _on_velocity_mode_selected(index: int) -> void:
	fixed_velocity_spin.editable = index == 1

func _on_save_pressed() -> void:
	_cancel_learn()
	_pad.trigger_note = _working_trigger_note
	_pad.trigger_gamepad_button = _working_trigger_gamepad
	_pad.trigger_keyboard_note = _working_trigger_keyboard
	_pad.chord_notes = _working_notes.duplicate()
	_pad.output_channel = int(channel_spin.value) - 1
	_pad.velocity_mode = "fixed" if velocity_mode_option.selected == 1 else "passthrough"
	_pad.fixed_velocity = int(fixed_velocity_spin.value)
	saved.emit(pad_index)
	hide()

func _on_cancel_pressed() -> void:
	_cancel_learn()
	hide()
