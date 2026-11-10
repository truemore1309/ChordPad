class_name StringUtils
extends RefCounted

## godot-rtmidi's macOS CoreMIDI port names come through Godot with non-ASCII
## characters double-encoded: the original UTF-8 bytes got decoded as Latin-1
## somewhere in the native layer. Since Latin-1 codepoints map 1:1 to byte
## values 0-255, the fix is to read each character's codepoint back out as a
## raw byte and re-decode that byte sequence as UTF-8. Display-only — the
## original (corrupted) string is still what the addon expects for matching,
## so callers must keep using the raw string for connect/port lookups.
static func fix_mojibake(s: String) -> String:
	var bytes := PackedByteArray()
	for i in range(s.length()):
		var code := s.unicode_at(i)
		if code > 255:
			return s # not a simple Latin-1 corruption; leave untouched
		bytes.append(code)
	var fixed := bytes.get_string_from_utf8()
	return fixed if not fixed.is_empty() else s
