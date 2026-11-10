class_name KeyboardUtils
extends RefCounted

## The Karabiner -> IAC bridge turns rtyufghj key presses into MIDI notes on
## MidiRouter.KEYBOARD_BRIDGE_PORT_NAME, one consecutive note per key in
## physical row-major order (top row RTYU, bottom row FGHJ) to match the pad
## grid's 4-column layout.
const NOTE_BASE := 60 # C4
const KEY_LABELS := ["R", "T", "Y", "U", "F", "G", "H", "J"]

static func note_for_pad(pad_index: int) -> int:
	return NOTE_BASE + pad_index

static func key_label(note: int) -> String:
	var offset := note - NOTE_BASE
	if offset >= 0 and offset < KEY_LABELS.size():
		return KEY_LABELS[offset]
	return "Note%d" % note
