extends Node

## Autoload singleton. Owns loading/saving ChordPreset JSON files under
## user://presets/ and pushes the active one into MidiRouter.

signal preset_changed

const PRESETS_DIR := "user://presets"
const DEFAULT_PRESET_RES := "res://presets/default.json"

var current_preset: ChordPreset

func _ready() -> void:
	_ensure_presets_dir()
	_bootstrap_default_if_empty()
	var names := list_preset_files()
	if names.is_empty():
		current_preset = ChordPreset.create_default()
		MidiRouter.set_active_preset(current_preset)
	else:
		load_preset(names[0])

func _ensure_presets_dir() -> void:
	if not DirAccess.dir_exists_absolute(PRESETS_DIR):
		DirAccess.make_dir_recursive_absolute(PRESETS_DIR)

func _bootstrap_default_if_empty() -> void:
	if not list_preset_files().is_empty():
		return
	if not FileAccess.file_exists(DEFAULT_PRESET_RES):
		return
	var src := FileAccess.open(DEFAULT_PRESET_RES, FileAccess.READ)
	if src == null:
		return
	var text := src.get_as_text()
	src.close()
	var dst := FileAccess.open(PRESETS_DIR.path_join("default.json"), FileAccess.WRITE)
	if dst == null:
		return
	dst.store_string(text)
	dst.close()

func list_preset_files() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(PRESETS_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			result.append(file_name.get_basename())
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

func load_preset(name: String) -> bool:
	var path := PRESETS_DIR.path_join(name + ".json")
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var preset := ChordPreset.from_json_string(text)
	if preset == null:
		return false
	preset.preset_name = name
	current_preset = preset
	MidiRouter.set_active_preset(current_preset)
	preset_changed.emit()
	return true

func save_preset(preset: ChordPreset) -> bool:
	return save_preset_as(preset, preset.preset_name)

func save_preset_as(preset: ChordPreset, new_name: String) -> bool:
	if new_name.is_empty():
		return false
	preset.preset_name = new_name
	var file := FileAccess.open(PRESETS_DIR.path_join(new_name + ".json"), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(preset.to_json_string())
	file.close()
	current_preset = preset
	preset_changed.emit()
	return true

func reveal_presets_folder() -> void:
	OS.shell_open(ProjectSettings.globalize_path(PRESETS_DIR))
