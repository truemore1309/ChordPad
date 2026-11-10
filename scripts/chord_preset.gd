class_name ChordPreset
extends RefCounted

const PAD_COUNT := 8
const SCHEMA_VERSION := 3

var preset_name: String = "default"
var pads: Array[PadConfig] = []
## What triggers the pads: "midi" (external MIDI keyboard), "gamepad" (Xbox
## controller), or "keyboard" (computer keyboard via the Karabiner/IAC
## bridge). Global, not per-pad — only one input source is active at once.
var input_mode: String = "midi"
var input_port_name: String = ""
var output_mode: String = "virtual" # "virtual" | a concrete MIDI output port name
var output_virtual_name: String = "ChordPad"
## Left stick -> pitch bend (up/down) + CC (left/right) passthrough. On by
## default.
var stick_enabled: bool = true
var stick_channel: int = 0 # 0-15
var stick_cc: int = 28
## D-pad -> one CC per direction (127 on press, 0 on release) on stick_channel,
## so each direction can be MIDI-mapped separately in a DAW. A direction that
## is also Learned as a pad trigger plays the pad instead of sending its CC.
var dpad_enabled: bool = true
var dpad_ccs: Array[int] = [20, 21, 22, 23] # up, down, left, right
## Lever smoothing for the D-pad CCs and the stick's bend/CC: how long a value
## takes to travel from rest to full (attack) and from full back to rest
## (release). 0 = instant, i.e. the raw on/off jump.
var lever_attack_ms: int = 0
var lever_release_ms: int = 0

static func create_default(name: String = "default") -> ChordPreset:
	var preset := ChordPreset.new()
	preset.preset_name = name
	for i in range(PAD_COUNT):
		preset.pads.append(PadConfig.new())
	return preset

func to_dict() -> Dictionary:
	var pad_dicts: Array[Dictionary] = []
	for pad in pads:
		pad_dicts.append(pad.to_dict())
	return {
		"schema_version": SCHEMA_VERSION,
		"preset_name": preset_name,
		"pads": pad_dicts,
		"input_mode": input_mode,
		"input_port_name": input_port_name,
		"output_mode": output_mode,
		"output_virtual_name": output_virtual_name,
		"stick_enabled": stick_enabled,
		"stick_channel": stick_channel,
		"stick_cc": stick_cc,
		"dpad_enabled": dpad_enabled,
		"dpad_ccs": dpad_ccs.duplicate(),
		"lever_attack_ms": lever_attack_ms,
		"lever_release_ms": lever_release_ms,
	}

static func from_dict(d: Dictionary) -> ChordPreset:
	var preset := ChordPreset.new()
	preset.preset_name = String(d.get("preset_name", "default"))
	preset.input_mode = String(d.get("input_mode", "midi"))
	preset.input_port_name = String(d.get("input_port_name", ""))
	preset.output_mode = String(d.get("output_mode", "virtual"))
	preset.output_virtual_name = String(d.get("output_virtual_name", "ChordPad"))
	preset.stick_enabled = bool(d.get("stick_enabled", true))
	preset.stick_channel = int(d.get("stick_channel", 0))
	preset.stick_cc = int(d.get("stick_cc", 28))
	preset.dpad_enabled = bool(d.get("dpad_enabled", true))
	var ccs: Array[int] = []
	for cc in d.get("dpad_ccs", [20, 21, 22, 23]):
		ccs.append(int(cc))
	while ccs.size() < 4:
		ccs.append(20 + ccs.size())
	preset.dpad_ccs = ccs
	preset.lever_attack_ms = int(d.get("lever_attack_ms", 0))
	preset.lever_release_ms = int(d.get("lever_release_ms", 0))
	var loaded_pads: Array[PadConfig] = []
	for pad_dict in d.get("pads", []):
		loaded_pads.append(PadConfig.from_dict(pad_dict))
	while loaded_pads.size() < PAD_COUNT:
		loaded_pads.append(PadConfig.new())
	preset.pads = loaded_pads
	return preset

func to_json_string() -> String:
	return JSON.stringify(to_dict(), "\t")

static func from_json_string(text: String) -> ChordPreset:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return ChordPreset.from_dict(parsed)
