extends Button

## One of the 8 round arcade buttons. Custom-drawn so the "lit" state can fade
## smoothly: _glow goes 1 -> 0 on release, blending idle gray into RED.
## Click opens the chord editor for this pad.

signal edit_requested(pad_index: int)

@export var pad_index: int = 0

const BEZEL := 4.0
const RELEASE_FADE := 0.25

var _glow: float = 0.0:
	set(value):
		_glow = value
		_update_label_colors()
		queue_redraw()
var _tween: Tween

@onready var chord_label: Label = %ChordLabel
@onready var trigger_label: Label = %TriggerLabel

func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	pressed.connect(func(): edit_requested.emit(pad_index))
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	MidiRouter.pad_triggered.connect(_on_pad_triggered)
	MidiRouter.pad_released.connect(_on_pad_released)
	_update_label_colors()

func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 1.0
	var ring := UiTheme.CONTROL_BORDER_HOVER if is_hovered() else UiTheme.CONTROL_BORDER
	ring = ring.lerp(UiTheme.RED_HOVER, _glow)
	var fill := UiTheme.CONTROL.lerp(UiTheme.RED, _glow)
	draw_circle(center, radius, ring, true, -1.0, true)
	draw_circle(center, radius - BEZEL, fill, true, -1.0, true)

func refresh(pad: PadConfig) -> void:
	var trigger_name := "—"
	match PresetManager.current_preset.input_mode:
		"gamepad":
			if pad.trigger_gamepad_button >= 0:
				trigger_name = GamepadUtils.button_name(pad.trigger_gamepad_button)
		"keyboard":
			if pad.trigger_keyboard_note >= 0:
				trigger_name = KeyboardUtils.key_label(pad.trigger_keyboard_note)
		_:
			if pad.trigger_note >= 0:
				trigger_name = NoteUtils.note_number_to_name(pad.trigger_note)
	trigger_label.text = trigger_name

	var note_names := PackedStringArray()
	for n in pad.chord_notes:
		note_names.append(NoteUtils.note_number_to_name(n))
	var symbol := ChordTheory.detect_chord_symbol(pad.chord_notes)
	if symbol.is_empty():
		match note_names.size():
			0: symbol = "—"
			1: symbol = note_names[0]
			_: symbol = "%d notes" % note_names.size()
	chord_label.text = symbol
	chord_label.add_theme_font_size_override("font_size", 20 if symbol.length() <= 4 else 14)
	tooltip_text = "Pad %d · %s\n%s" % [pad_index + 1, trigger_name, " ".join(note_names) if not note_names.is_empty() else "unassigned"]

func _update_label_colors() -> void:
	if chord_label == null:
		return
	chord_label.add_theme_color_override("font_color", UiTheme.TEXT.lerp(Color.WHITE, _glow))
	trigger_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM.lerp(Color.WHITE, _glow))

func _on_pad_triggered(index: int) -> void:
	if index != pad_index:
		return
	if _tween:
		_tween.kill()
	_glow = 1.0

func _on_pad_released(index: int) -> void:
	if index != pad_index:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_glow", 0.0, RELEASE_FADE)
