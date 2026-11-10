class_name NoteUtils
extends RefCounted

## MIDI note number <-> name conversion using Ableton Live's octave convention
## (middle C / MIDI note 60 = "C3"), so labels in this tool match Ableton's
## piano roll instead of the more common Yamaha/General MIDI "C4" convention.

const SHARP_NAMES: Array[String] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

static func note_number_to_name(note: int) -> String:
	var octave := int(floor(float(note) / 12.0)) - 2
	var semitone := note % 12
	if semitone < 0:
		semitone += 12
	return "%s%d" % [SHARP_NAMES[semitone], octave]

## Builds a MIDI note number from a pitch class index (0-11, matching SHARP_NAMES)
## and an Ableton-style octave number.
static func note_from_parts(semitone: int, octave: int) -> int:
	return (octave + 2) * 12 + semitone
