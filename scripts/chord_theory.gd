class_name ChordTheory
extends RefCounted

## Semitone offsets from the root, kept to 3-4 notes per the tool's chord-pad
## concept. "Major 9" / "Minor 9" here are 4-note add9 voicings (root, 3rd,
## 5th, 9th) rather than full 5-note 9th chords with the 7th included.
const QUALITIES := {
	"Major": [0, 4, 7],
	"Minor": [0, 3, 7],
	"Diminished": [0, 3, 6],
	"Augmented": [0, 4, 8],
	"Sus2": [0, 2, 7],
	"Sus4": [0, 5, 7],
	"Major 7": [0, 4, 7, 11],
	"Minor 7": [0, 3, 7, 10],
	"Dominant 7": [0, 4, 7, 10],
	"Diminished 7": [0, 3, 6, 9],
	"Major 9": [0, 4, 7, 14],
	"Minor 9": [0, 3, 7, 14],
}

static func quality_names() -> Array:
	return QUALITIES.keys()

static func generate_chord(root_note: int, quality: String) -> Array[int]:
	var result: Array[int] = []
	for interval in QUALITIES.get(quality, QUALITIES["Major"]):
		result.append(root_note + interval)
	return result

## Short chord-symbol suffixes for QUALITIES, e.g. "Minor 7" -> "m7". Major
## has no suffix per standard notation (bare "C" already means C major).
const QUALITY_ABBREVIATIONS := {
	"Major": "",
	"Minor": "m",
	"Diminished": "dim",
	"Augmented": "aug",
	"Sus2": "sus2",
	"Sus4": "sus4",
	"Major 7": "maj7",
	"Minor 7": "m7",
	"Dominant 7": "7",
	"Diminished 7": "dim7",
	"Major 9": "maj9",
	"Minor 9": "m9",
}

## Reverse of generate_chord(): given a pad's chord notes, tries to find a
## QUALITIES entry whose interval pattern matches the notes' pitch-class
## content and returns a short symbol like "C" or "Am7". Tries the lowest
## note as the root first (chords built via generate_chord() are always
## root-position, ascending from the root), then the other notes, so
## manually-edited/inverted voicings can still match. Returns "" if nothing
## matches (including fewer than 3 distinct pitch classes).
static func detect_chord_symbol(notes: Array[int]) -> String:
	if notes.size() < 3:
		return ""
	var sorted_notes: Array[int] = notes.duplicate()
	sorted_notes.sort()
	var pitch_classes: Array[int] = []
	for n in sorted_notes:
		var pc := ((n % 12) + 12) % 12
		if not pitch_classes.has(pc):
			pitch_classes.append(pc)
	if pitch_classes.size() < 3:
		return ""

	var root_candidates: Array[int] = [((sorted_notes[0] % 12) + 12) % 12]
	for pc in pitch_classes:
		if not root_candidates.has(pc):
			root_candidates.append(pc)

	for root_pc in root_candidates:
		var intervals: Array[int] = []
		for pc in pitch_classes:
			intervals.append(((pc - root_pc) + 12) % 12)
		intervals.sort()
		for quality_name in QUALITIES:
			var pattern: Array[int] = []
			for interval in QUALITIES[quality_name]:
				pattern.append(interval % 12)
			pattern.sort()
			if pattern == intervals:
				return NoteUtils.SHARP_NAMES[root_pc] + QUALITY_ABBREVIATIONS.get(quality_name, "")
	return ""
