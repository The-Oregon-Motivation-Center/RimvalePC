## rimvale_utils.gd
## Shared utility functions. Autoloaded as "RimvaleUtils".

extends Node

const PORTRAIT_BASE := "res://assets/characters/"
const PORTRAIT_FALLBACK := "res://assets/characters/regal_human.png"

# ── Portrait loading ──────────────────────────────────────────────────────────

## Convert lineage display name to portrait texture.
## e.g.  "Regal Human" → assets/characters/regal_human.png
func get_portrait(lineage_name: String) -> Texture2D:
	var key := lineage_name.to_lower().replace(" ", "_").replace("-", "_").replace("'", "")
	var path := PORTRAIT_BASE + key + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return load(PORTRAIT_FALLBACK)

## True if portrait exists for this lineage
func has_portrait(lineage_name: String) -> bool:
	var key := lineage_name.to_lower().replace(" ", "_").replace("-", "_").replace("'", "")
	return ResourceLoader.exists(PORTRAIT_BASE + key + ".png")

# ── UI helpers ────────────────────────────────────────────────────────────────

## Build a full-color background rect as the first child of a Control node.
func add_bg(parent: Control, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	parent.move_child(r, 0)
	return r

## Create a styled Label.
func label(txt: String, size: int = 16, color: Color = RimvaleColors.TEXT_WHITE,
		bold: bool = false) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## Create a styled Button.
func button(txt: String, col: Color = RimvaleColors.PRIMARY,
		min_h: int = 48, font_size: int = 16) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, min_h)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", col)
	return b

## Create a horizontal resource bar (HP / AP / SP style).
func resource_bar(label_txt: String, current: int, maximum: int,
		bar_color: Color, width: float = 200.0) -> Control:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(width, 0)
	vbox.add_theme_constant_override("separation", 2)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)

	var lbl := Label.new()
	lbl.text = label_txt
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", RimvaleColors.TEXT_GRAY)
	lbl.custom_minimum_size = Vector2(24, 0)
	row.add_child(lbl)

	var val := Label.new()
	val.text = "%d/%d" % [current, maximum]
	val.add_theme_font_size_override("font_size", 11)
	val.add_theme_color_override("font_color", RimvaleColors.TEXT_LIGHT)
	row.add_child(val)

	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(width, 6)
	bar_bg.color = Color(bar_color, 0.25)
	vbox.add_child(bar_bg)

	var pct := float(current) / float(max(maximum, 1))
	var bar_fill := ColorRect.new()
	bar_fill.custom_minimum_size = Vector2(width * pct, 6)
	bar_fill.color = bar_color
	bar_fill.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	bar_bg.add_child(bar_fill)

	return vbox

## Horizontal rule
func separator() -> HSeparator:
	return HSeparator.new()

## Spacer of given height
func spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s

# ── Format helpers ────────────────────────────────────────────────────────────

func format_xp(current: int, required: int) -> String:
	return "%d / %d XP" % [current, required]

func pct(current: int, maximum: int) -> float:
	return float(current) / float(max(maximum, 1))
