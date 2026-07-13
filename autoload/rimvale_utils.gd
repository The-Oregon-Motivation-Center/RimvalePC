## rimvale_utils.gd
## Shared utility functions. Autoloaded as "RimvaleUtils".

extends Node


# ── Settings helpers ──────────────────────────────────────────────────────────
# SettingsManager pushes preferences into Engine.get_meta(), so any system
# can query them without depending on the Settings autoload.

## Combat-animation duration after applying the user's "Animation Speed"
## preference. Pass the *baseline* tween duration; the function returns a
## faster value if the user wants snappier combat (or slower if they prefer
## cinematic pacing). Use everywhere a fixed-duration combat tween fires.
func combat_dur(base_seconds: float) -> float:
	var speed: float = float(Engine.get_meta("combat_speed", 1.0))
	if speed < 0.01:
		speed = 1.0
	return base_seconds / speed


## True when the user has opted into "Reduce Motion" — gate camera shakes,
## screen flashes, and ambient camera moves on this.
func reduce_motion() -> bool:
	return bool(Engine.get_meta("reduce_motion", false))


## True when verbose battle-log dice/modifier breakdowns should be shown.
func verbose_battle_log() -> bool:
	return bool(Engine.get_meta("verbose_battle_log", true))


## True when verbose tooltips should be shown across the UI.
func verbose_tooltips() -> bool:
	return bool(Engine.get_meta("verbose_tooltips", true))


## UI text scale factor (1.0 = normal). Multiply font sizes by this where
## the UI cares to honour the accessibility preference.
func text_scale() -> float:
	var s: float = float(Engine.get_meta("text_scale", 1.0))
	return clampf(s, 0.5, 2.0)


## Spawn the tabbed settings dialog over the given parent (any Node).
## Used by every screen that wires F10 / gamepad Back to "open settings."
func open_settings_dialog(parent: Node) -> void:
	if parent == null:
		return
	var script := load("res://scenes/popups/settings_dialog.gd")
	if script == null:
		return
	if typeof(AudioManager) != TYPE_NIL:
		AudioManager.open_panel()
	var dlg = script.new()
	parent.add_child(dlg)
	dlg.open()


## Show a tutorial hint if it hasn't been shown before. No-op if the user
## has already dismissed this step, or has turned tutorials off entirely.
## `parent` is any Node — the popup adds itself as a child and free()s itself
## on dismiss. Safe to call from anywhere; deferred so caller can finish its
## own _ready before the popup mounts.
func show_hint(parent: Node, step_id: String, body: String, title: String = "Tip") -> void:
	if parent == null:
		return
	if GameState.tutorial_disabled:
		return
	if GameState.tutorial_step_was_shown(step_id):
		return
	var script := load("res://scenes/popups/tutorial_hint.gd")
	if script == null:
		return
	var dlg = script.new()
	parent.add_child(dlg)
	dlg.open(step_id, body, title)


const PORTRAIT_BASE = "res://assets/characters/"
const PORTRAIT_FALLBACK = "res://assets/characters/regal_human.png"
const SPRITE_PORTRAIT_BASE = "res://assets/characters_3d/"
const SPRITE_PORTRAIT_FALLBACK = "res://assets/characters_3d/regal_human.png"

# ── Portrait loading ──────────────────────────────────────────────────────────

## Convert lineage display name to portrait texture (original art with backgrounds).
## e.g.  "Regal Human" → assets/characters/regal_human.png
## Safe against missing import metadata — returns null instead of crashing.
func get_portrait(lineage_name: String) -> Texture2D:
	var key := lineage_name.to_lower().replace(" ", "_").replace("-", "_").replace("'", "")
	var path := PORTRAIT_BASE + key + ".png"
	# Try the specific lineage portrait first
	var tex := _safe_load_texture(path)
	if tex != null:
		return tex
	# Fall back to the default portrait
	return _safe_load_texture(PORTRAIT_FALLBACK)

## Load the transparent-background sprite portrait for a lineage.
## Tries characters_3d/ first, then falls back to original characters/.
func get_sprite_portrait(lineage_name: String) -> Texture2D:
	var key := lineage_name.to_lower().replace(" ", "_").replace("-", "_").replace("'", "")
	# Try transparent sprite version first
	var sprite_path := SPRITE_PORTRAIT_BASE + key + ".png"
	var tex := _safe_load_texture(sprite_path)
	if tex != null:
		return tex
	# Fall back to original portrait (still looks good in UI)
	var orig_path := PORTRAIT_BASE + key + ".png"
	tex = _safe_load_texture(orig_path)
	if tex != null:
		return tex
	# Final fallback
	tex = _safe_load_texture(SPRITE_PORTRAIT_FALLBACK)
	if tex != null:
		return tex
	return _safe_load_texture(PORTRAIT_FALLBACK)

## Load a texture without crashing if the file is missing or not yet imported.
func _safe_load_texture(path: String) -> Texture2D:
	# Path 1: Godot resource system (works when editor has imported the file)
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res as Texture2D

	# Path 2: Raw file load — bypasses import system entirely.
	# ResourceLoader.exists() returns false when .import metadata is missing,
	# even if the PNG is sitting right there on disk. FileAccess checks the
	# actual filesystem instead.
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null:
			return ImageTexture.create_from_image(img)

	return null

## True if portrait exists for this lineage
func has_portrait(lineage_name: String) -> bool:
	var key := lineage_name.to_lower().replace(" ", "_").replace("-", "_").replace("'", "")
	return ResourceLoader.exists(PORTRAIT_BASE + key + ".png")

# ── UI helpers ────────────────────────────────────────────────────────────────

## Build a full-color background rect as the first child of a Control node.
func add_bg(parent: Control, color: Color) -> ColorRect:
	var r = ColorRect.new()
	r.color = color
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	parent.move_child(r, 0)
	return r

## Create a styled Label.
func label(txt: String, size: int = 16, color: Color = RimvaleColors.TEXT_WHITE,
		bold: bool = false) -> Label:
	var l = Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## Create a styled Button.
func button(txt: String, col: Color = RimvaleColors.PRIMARY,
		min_h: int = 48, font_size: int = 16) -> Button:
	var b = Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, min_h)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", col)
	return b

## Create a horizontal resource bar (HP / AP / SP style).
func resource_bar(label_txt: String, current: int, maximum: int,
		bar_color: Color, width: float = 200.0) -> Control:
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(width, 0)
	vbox.add_theme_constant_override("separation", 2)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)

	var lbl = Label.new()
	lbl.text = label_txt
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", RimvaleColors.TEXT_GRAY)
	lbl.custom_minimum_size = Vector2(24, 0)
	row.add_child(lbl)

	var val = Label.new()
	val.text = "%d/%d" % [current, maximum]
	val.add_theme_font_size_override("font_size", 11)
	val.add_theme_color_override("font_color", RimvaleColors.TEXT_LIGHT)
	row.add_child(val)

	var bar_bg = ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(width, 6)
	bar_bg.color = Color(bar_color, 0.25)
	vbox.add_child(bar_bg)

	var pct = float(current) / float(max(maximum, 1))
	var bar_fill = ColorRect.new()
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
	var s = Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s

# ── Card / panel helpers ──────────────────────────────────────────────────────

## Build a modern rounded-panel card.
## Returns a PanelContainer with a StyleBoxFlat background and soft border.
## Use `card.add_child(...)` directly — it already has internal padding.
func card(bg_color: Color = RimvaleColors.BG_CARD, border_color: Color = RimvaleColors.DIVIDER,
		corner: int = 8, pad: int = 10) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.corner_radius_top_left = corner
	sb.corner_radius_top_right = corner
	sb.corner_radius_bottom_left = corner
	sb.corner_radius_bottom_right = corner
	sb.border_color = border_color
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	panel.add_theme_stylebox_override("panel", sb)
	return panel

## Build a flat, accent-bordered pill button for filter chips.
func chip(txt: String, active: bool, font_size: int = 12) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 30)
	b.add_theme_font_size_override("font_size", font_size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = RimvaleColors.ACCENT if active else RimvaleColors.BG_CARD_DARK
	sb.corner_radius_top_left = 15
	sb.corner_radius_top_right = 15
	sb.corner_radius_bottom_left = 15
	sb.corner_radius_bottom_right = 15
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.border_color = RimvaleColors.ACCENT
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	b.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = RimvaleColors.ACCENT if active else RimvaleColors.BG_CARD
	b.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = sb.duplicate()
	pressed.bg_color = RimvaleColors.ACCENT
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color",
		RimvaleColors.BG_DARK if active else RimvaleColors.TEXT_LIGHT)
	b.add_theme_color_override("font_hover_color",
		RimvaleColors.BG_DARK if active else RimvaleColors.TEXT_WHITE)
	return b

## Build a compact icon (emoji/text) for category markers.
func category_icon(cat: String) -> Label:
	var emoji: String = "📦"
	match cat:
		"Weapons":    emoji = "⚔️"
		"Armor":      emoji = "🛡️"
		"Consumable": emoji = "🧪"
		"Magic":      emoji = "✨"
		"Misc":       emoji = "📦"
	var l := Label.new()
	l.text = emoji
	l.custom_minimum_size = Vector2(28, 28)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 18)
	return l

# ── Format helpers ────────────────────────────────────────────────────────────

func format_xp(current: int, required: int) -> String:
	return "%d / %d XP" % [current, required]

func pct(current: int, maximum: int) -> float:
	return float(current) / float(max(maximum, 1))
