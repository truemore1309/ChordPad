class_name UiTheme
extends RefCounted

## White "arcade stick" palette + Theme builder. The built Theme is saved to
## res://ui/theme.tres (see tools/build_theme.gd) and set as the project-wide
## custom theme, so both the editor preview and every Window use it. The color
## constants are also read directly by the custom-drawn controls (pads, stick).
##
## Rule of thumb: pure white base, grays only where depth is needed, and
## anything the user is pressing / that is "on" turns pure RED (#FF0000).

const BG := Color("ffffff")
const BODY := Color("ffffff")
const BODY_BORDER := Color("8c8c8c")
const SECTION := Color("f5f5f5")
const SECTION_BORDER := Color("c4c4c4")
const CONTROL := Color("e6e6e6")
const CONTROL_HOVER := Color("d9d9d9")
const CONTROL_BORDER := Color("a6a6a6")
const CONTROL_BORDER_HOVER := Color("6e6e6e")
const DISPLAY := Color("ececec")
const TEXT := Color("1a1a1a")
const TEXT_DIM := Color("6b6b6b")
const TEXT_FAINT := Color("9a9a9a")
const RED := Color("ff0000")
const RED_HOVER := Color("ff3030")
const RED_DARK := Color("cc0000")
const RED_LIGHT := Color("ffb3b3")
const WINDOW_BAR := Color("6e6e6e")
const BLACK := Color("000000")

static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 14

	# --- Buttons (also the base for OptionButton / mode toggles) ---------
	for type_name in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type_name, _box(CONTROL, CONTROL_BORDER, 6))
		t.set_stylebox("hover", type_name, _box(CONTROL_HOVER, CONTROL_BORDER_HOVER, 6))
		t.set_stylebox("pressed", type_name, _box(RED, RED, 6))
		t.set_stylebox("hover_pressed", type_name, _box(RED_HOVER, RED_HOVER, 6))
		t.set_stylebox("disabled", type_name, _box(SECTION, SECTION_BORDER, 6))
		t.set_stylebox("focus", type_name, StyleBoxEmpty.new())
		t.set_color("font_color", type_name, TEXT)
		t.set_color("font_hover_color", type_name, TEXT)
		t.set_color("font_focus_color", type_name, TEXT)
		t.set_color("font_pressed_color", type_name, Color.WHITE)
		t.set_color("font_hover_pressed_color", type_name, Color.WHITE)
		t.set_color("font_disabled_color", type_name, TEXT_FAINT)
	# An OptionButton "pressed" is just its popup being open -- don't flash red.
	t.set_stylebox("pressed", "OptionButton", _box(CONTROL_HOVER, CONTROL_BORDER_HOVER, 6))
	t.set_color("font_pressed_color", "OptionButton", TEXT)
	t.set_color("font_hover_pressed_color", "OptionButton", TEXT)

	# Big round arcade-style buttons (Panic / Sampler / function keys).
	t.set_type_variation("RoundButton", "Button")
	t.set_stylebox("normal", "RoundButton", _box(CONTROL, CONTROL_BORDER, 64, 3))
	t.set_stylebox("hover", "RoundButton", _box(CONTROL_HOVER, CONTROL_BORDER_HOVER, 64, 3))
	t.set_stylebox("pressed", "RoundButton", _box(RED, RED, 64, 3))
	t.set_stylebox("hover_pressed", "RoundButton", _box(RED_HOVER, RED_HOVER, 64, 3))
	t.set_font_size("font_size", "RoundButton", 11)
	# Icons on round buttons are drawn white and tinted by state.
	t.set_color("icon_normal_color", "RoundButton", TEXT)
	t.set_color("icon_hover_color", "RoundButton", TEXT)
	t.set_color("icon_focus_color", "RoundButton", TEXT)
	t.set_color("icon_pressed_color", "RoundButton", Color.WHITE)
	t.set_color("icon_hover_pressed_color", "RoundButton", Color.WHITE)

	# Segments of the MIDI / Xbox / Keys switch: pill shaped.
	t.set_type_variation("PillButton", "Button")
	t.set_stylebox("normal", "PillButton", _box(CONTROL, CONTROL_BORDER, 14))
	t.set_stylebox("hover", "PillButton", _box(CONTROL_HOVER, CONTROL_BORDER_HOVER, 14))
	t.set_stylebox("pressed", "PillButton", _box(RED, RED, 14))
	t.set_stylebox("hover_pressed", "PillButton", _box(RED_HOVER, RED_HOVER, 14))
	t.set_font_size("font_size", "PillButton", 12)

	# CheckBox inherits Button styles -- keep it a plain checkbox, not a red slab.
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		t.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", TEXT)
	t.set_color("font_hover_pressed_color", "CheckBox", TEXT)

	# --- Panels ----------------------------------------------------------
	t.set_type_variation("BodyPanel", "Panel")
	t.set_stylebox("panel", "BodyPanel", _box(BODY, BODY_BORDER, 44, 6))
	t.set_type_variation("SectionPanel", "Panel")
	t.set_stylebox("panel", "SectionPanel", _box(SECTION, SECTION_BORDER, 10, 2))
	# The button deck and lever washer are black, like the real stick's art panel.
	t.set_type_variation("BlackPanel", "Panel")
	t.set_stylebox("panel", "BlackPanel", _box(BLACK, BLACK, 10, 2))
	t.set_type_variation("DisplayPanel", "Panel")
	t.set_stylebox("panel", "DisplayPanel", _box(DISPLAY, SECTION_BORDER, 10, 2))

	# --- Labels ------------------------------------------------------------
	t.set_color("font_color", "Label", TEXT)
	t.set_type_variation("DimLabel", "Label")
	t.set_color("font_color", "DimLabel", TEXT_DIM)
	t.set_font_size("font_size", "DimLabel", 12)
	t.set_type_variation("CaptionLabel", "Label")
	t.set_color("font_color", "CaptionLabel", TEXT_FAINT)
	t.set_font_size("font_size", "CaptionLabel", 10)
	t.set_type_variation("BigChordLabel", "Label")
	t.set_color("font_color", "BigChordLabel", RED)
	t.set_font_size("font_size", "BigChordLabel", 34)

	# --- Inputs ------------------------------------------------------------
	t.set_stylebox("normal", "LineEdit", _box(DISPLAY, CONTROL_BORDER, 6))
	t.set_stylebox("focus", "LineEdit", _box(DISPLAY, RED, 6))
	t.set_stylebox("read_only", "LineEdit", _box(SECTION, SECTION_BORDER, 6))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_FAINT)
	t.set_color("caret_color", "LineEdit", RED)
	t.set_color("selection_color", "LineEdit", RED_LIGHT)

	t.set_stylebox("panel", "ItemList", _box(DISPLAY, CONTROL_BORDER, 6))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", _box(RED_LIGHT, RED_LIGHT, 4, 0))
	t.set_stylebox("selected_focus", "ItemList", _box(RED, RED, 4, 0))
	t.set_stylebox("hovered", "ItemList", _box(CONTROL, CONTROL, 4, 0))
	t.set_color("font_hovered_color", "ItemList", TEXT)
	t.set_stylebox("cursor", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", TEXT)

	t.set_stylebox("panel", "PopupMenu", _box(SECTION, CONTROL_BORDER, 6, 1, 4))
	t.set_stylebox("hover", "PopupMenu", _box(RED, RED, 4, 0))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)

	t.set_stylebox("panel", "TooltipPanel", _box(SECTION, CONTROL_BORDER, 4, 1, 6))
	t.set_color("font_color", "TooltipLabel", TEXT)

	var sep := StyleBoxLine.new()
	sep.color = SECTION_BORDER
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)

	# --- Windows (chord editor, settings) ---------------------------------
	var win := _box(BODY, WINDOW_BAR, 8, 2)
	win.border_width_top = 34
	win.expand_margin_left = 2
	win.expand_margin_right = 2
	win.expand_margin_bottom = 2
	win.expand_margin_top = 34
	t.set_stylebox("embedded_border", "Window", win)
	t.set_stylebox("embedded_unfocused_border", "Window", win)
	t.set_constant("title_height", "Window", 34)
	t.set_color("title_color", "Window", Color.WHITE)

	# --- Icons: Godot's defaults are drawn for dark themes (near-white), so
	# redraw the ones that sit on light backgrounds in gray / red.
	var arrow_down := _triangle(12, 7, TEXT_DIM, false)
	t.set_icon("arrow", "OptionButton", arrow_down)
	for state in ["", "_hover", "_pressed"]:
		t.set_icon("up" + state, "SpinBox", _triangle(10, 6, TEXT_DIM if state == "" else TEXT, true))
		t.set_icon("down" + state, "SpinBox", _triangle(10, 6, TEXT_DIM if state == "" else TEXT, false))
	t.set_icon("up_disabled", "SpinBox", _triangle(10, 6, TEXT_FAINT, true))
	t.set_icon("down_disabled", "SpinBox", _triangle(10, 6, TEXT_FAINT, false))
	t.set_icon("updown", "SpinBox", _updown(10, 16, TEXT_DIM))
	t.set_icon("unchecked", "CheckBox", _square(16, BODY, CONTROL_BORDER_HOVER))
	t.set_icon("checked", "CheckBox", _square(16, RED, RED))
	t.set_icon("radio_checked", "PopupMenu", _dot(12, RED))
	t.set_icon("radio_unchecked", "PopupMenu", _dot(12, Color(0, 0, 0, 0)))
	t.set_icon("checked", "PopupMenu", _square(14, RED, RED))
	t.set_icon("unchecked", "PopupMenu", _square(14, BODY, CONTROL_BORDER))
	return t

static func _box(bg: Color, border: Color, radius: int, border_width: int = 1, padding: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = padding + 4
	s.content_margin_right = padding + 4
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	s.anti_aliasing = true
	return s

## --- Tiny procedural icons (4x4 supersampled for smooth edges) -----------

static func _paint(w: int, h: int, inside: Callable) -> ImageTexture:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var hits := 0
			var col := Color(0, 0, 0, 0)
			for sy in range(4):
				for sx in range(4):
					var c: Color = inside.call(x + (sx + 0.5) / 4.0, y + (sy + 0.5) / 4.0)
					if c.a > 0.0:
						hits += 1
						col = c
			if hits > 0:
				col.a *= hits / 16.0
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

static func _triangle(w: int, h: int, color: Color, up: bool) -> ImageTexture:
	return _paint(w, h, func(px: float, py: float) -> Color:
		var t := (py / h) if up else (1.0 - py / h)
		var half := t * w / 2.0
		return color if absf(px - w / 2.0) <= half else Color(0, 0, 0, 0))

static func _updown(w: int, h: int, color: Color) -> ImageTexture:
	var gap := 2.0
	var th := (h - gap) / 2.0
	return _paint(w, h, func(px: float, py: float) -> Color:
		var t := -1.0
		if py < th:
			t = py / th
		elif py > th + gap:
			t = 1.0 - (py - th - gap) / th
		return color if t >= 0.0 and absf(px - w / 2.0) <= t * w / 2.0 else Color(0, 0, 0, 0))

static func _square(size: int, fill: Color, border: Color) -> ImageTexture:
	return _paint(size, size, func(px: float, py: float) -> Color:
		if px < 1.5 or py < 1.5 or px > size - 1.5 or py > size - 1.5:
			return border
		return fill)

static func _dot(size: int, color: Color) -> ImageTexture:
	var r := size / 2.0 - 2.0
	return _paint(size, size, func(px: float, py: float) -> Color:
		return color if Vector2(px, py).distance_to(Vector2(size / 2.0, size / 2.0)) <= r else Color(0, 0, 0, 0))

## Clockwise "refresh" arrow, drawn white so the button's icon_*_color tints it.
## Drawn rather than using the U+27F3 glyph, whose fallback-font metrics left
## it visibly off-center inside the round button.
static func refresh_icon(size: int = 20) -> ImageTexture:
	var c := Vector2(size, size) / 2.0
	var r := size * 0.33
	var thick := size * 0.11
	var gap_end := deg_to_rad(-55.0) # arc runs clockwise from 0 deg to here
	var tip_angle := gap_end
	var p := c + Vector2(cos(tip_angle), sin(tip_angle)) * r
	var tangent := Vector2(-sin(tip_angle), cos(tip_angle))
	var normal := Vector2(cos(tip_angle), sin(tip_angle))
	var head := size * 0.2
	var a := p + tangent * head
	var b := p - tangent * head * 0.25 + normal * head
	var d := p - tangent * head * 0.25 - normal * head
	return _paint(size, size, func(px: float, py: float) -> Color:
		var q := Vector2(px, py)
		if Geometry2D.point_is_inside_triangle(q, a, b, d):
			return Color.WHITE
		var dist := q.distance_to(c)
		if absf(dist - r) > thick / 2.0:
			return Color(0, 0, 0, 0)
		var ang := atan2(q.y - c.y, q.x - c.x)
		return Color(0, 0, 0, 0) if ang > gap_end and ang < 0.0 else Color.WHITE)
