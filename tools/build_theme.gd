extends SceneTree

## Regenerates res://ui/theme.tres from scripts/ui_theme.gd. Run after editing
## the palette:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/build_theme.gd

func _init() -> void:
	var builder = load("res://scripts/ui_theme.gd")
	DirAccess.make_dir_recursive_absolute("res://ui")
	var err := ResourceSaver.save(builder.build(), "res://ui/theme.tres")
	print("theme.tres saved: ", error_string(err))
	quit()
