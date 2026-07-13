## settings_dialog.gd
## Standalone tabbed settings popup. Spawned by any screen via:
##     var dlg := preload("res://scenes/popups/settings_dialog.gd").new()
##     add_child(dlg)
##     dlg.open()
##
## Tabs: Audio | Display | Gameplay | Accessibility
## Reads / writes through the `Settings` autoload. Live preview — every
## change is applied immediately; "Defaults" resets the active tab; the
## Close button dismisses with everything already saved to disk.

extends CanvasLayer

const COL_BG       := Color(0.08, 0.04, 0.16, 1.0)
const COL_PANEL    := Color(0.10, 0.05, 0.20, 1.0)
const COL_BORDER   := Color(0.55, 0.45, 0.85, 1.0)
const COL_TEXT     := Color(0.92, 0.92, 0.94, 1.0)
const COL_TEXT_DIM := Color(0.65, 0.65, 0.72, 1.0)
const COL_ACCENT   := Color(0.95, 0.78, 0.32, 1.0)
const COL_CYAN     := Color(0.45, 0.85, 0.95, 1.0)

const PANEL_W := 580
const PANEL_H := 520

var _root: Control
var _tab_btns: Array[Button] = []
var _pages: Array[Control] = []
var _current_tab: int = 0
var _on_close: Callable = Callable()


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────
func open(on_close: Callable = Callable()) -> void:
	_on_close = on_close
	_build()


func _safe_audio(method: String) -> void:
	# AudioManager is registered as an autoload; the identifier is always
	# defined at parse time. Guard against null in test contexts.
	if typeof(AudioManager) == TYPE_NIL:
		return
	if AudioManager.has_method(method):
		AudioManager.call(method)


# ─────────────────────────────────────────────────────────────────────────────
# Build root
# ─────────────────────────────────────────────────────────────────────────────
func _build() -> void:
	layer = 100
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Dim backdrop
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	# Centered panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_W * 0.5
	panel.offset_right = PANEL_W * 0.5
	panel.offset_top = -PANEL_H * 0.5
	panel.offset_bottom = PANEL_H * 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BG
	sb.border_color = COL_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(panel)

	# Main column
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	panel.add_child(col)

	col.add_child(_build_header())
	col.add_child(_build_tab_bar())
	col.add_child(_build_pages())          # expands
	col.add_child(_build_footer())

	# Initialize visibility
	_show_tab(0)


func _build_header() -> Control:
	var h := MarginContainer.new()
	h.add_theme_constant_override("margin_left", 22)
	h.add_theme_constant_override("margin_right", 22)
	h.add_theme_constant_override("margin_top", 16)
	h.add_theme_constant_override("margin_bottom", 6)

	var lbl := Label.new()
	lbl.text = "Settings"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", COL_ACCENT)
	h.add_child(lbl)
	return h


func _build_tab_bar() -> Control:
	var bar_pad := MarginContainer.new()
	bar_pad.add_theme_constant_override("margin_left", 16)
	bar_pad.add_theme_constant_override("margin_right", 16)
	bar_pad.add_theme_constant_override("margin_top", 4)
	bar_pad.add_theme_constant_override("margin_bottom", 8)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	bar_pad.add_child(bar)

	var titles := ["Audio", "Display", "Gameplay", "Accessibility"]
	for i in range(titles.size()):
		var b := Button.new()
		b.text = titles[i]
		b.flat = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 34)
		b.add_theme_font_size_override("font_size", 14)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func():
			_safe_audio("tab")
			_show_tab(i))
		_style_tab_button(b, false)
		_tab_btns.append(b)
		bar.add_child(b)

	return bar_pad


func _style_tab_button(b: Button, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL if active else Color(1, 1, 1, 0.03)
	sb.border_color = COL_ACCENT if active else Color(COL_BORDER.r, COL_BORDER.g, COL_BORDER.b, 0.4)
	sb.set_border_width_all(0)
	sb.border_width_bottom = 3 if active else 1
	sb.set_corner_radius_all(0)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.set_content_margin_all(8)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_color_override("font_color", COL_ACCENT if active else COL_TEXT_DIM)
	b.add_theme_color_override("font_hover_color", COL_ACCENT)


func _show_tab(idx: int) -> void:
	_current_tab = idx
	for i in range(_tab_btns.size()):
		_style_tab_button(_tab_btns[i], i == idx)
	for i in range(_pages.size()):
		_pages[i].visible = (i == idx)


# ─────────────────────────────────────────────────────────────────────────────
# Pages
# ─────────────────────────────────────────────────────────────────────────────
func _build_pages() -> Control:
	var page_root := MarginContainer.new()
	page_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_root.add_theme_constant_override("margin_left", 24)
	page_root.add_theme_constant_override("margin_right", 24)
	page_root.add_theme_constant_override("margin_top", 4)
	page_root.add_theme_constant_override("margin_bottom", 6)

	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_root.add_child(stack)

	_pages.append(_build_audio_page())
	_pages.append(_build_display_page())
	_pages.append(_build_gameplay_page())
	_pages.append(_build_accessibility_page())
	for p in _pages:
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(p)

	return page_root


# ── Audio page ────────────────────────────────────────────────────────────────
func _build_audio_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.add_child(_section_label("Volume"))
	box.add_child(_slider_row("Master",
		Settings.audio_master(),
		func(v): Settings.set_value("audio_master", v),
		0.0, 1.0, 0.01, "%d%%", 100.0))
	box.add_child(_slider_row("Music",
		Settings.audio_music(),
		func(v): Settings.set_value("audio_music", v),
		0.0, 1.0, 0.01, "%d%%", 100.0))
	box.add_child(_slider_row("Sound Effects",
		Settings.audio_sfx(),
		func(v):
			Settings.set_value("audio_sfx", v)
			# Preview on release
			,
		0.0, 1.0, 0.01, "%d%%", 100.0,
		func(v):
			_safe_audio("click")))
	box.add_child(_slider_row("UI Sounds",
		Settings.audio_ui(),
		func(v): Settings.set_value("audio_ui", v),
		0.0, 1.0, 0.01, "%d%%", 100.0,
		func(v):
			_safe_audio("click")))

	box.add_child(_spacer(6))
	box.add_child(_hint("Changes apply instantly. Test by clicking around."))
	return box


# ── Display page ──────────────────────────────────────────────────────────────
func _build_display_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)

	box.add_child(_section_label("Window"))
	box.add_child(_toggle_row("Fullscreen",
		bool(Settings.get_value("display_fullscreen")),
		func(on): Settings.set_value("display_fullscreen", on)))
	box.add_child(_toggle_row("V-Sync",
		bool(Settings.get_value("display_vsync")),
		func(on): Settings.set_value("display_vsync", on)))

	box.add_child(_section_label("Resolution"))
	box.add_child(_dropdown_row("Window Size",
		Settings.COMMON_RESOLUTIONS,
		str(Settings.get_value("display_resolution")),
		func(val): Settings.set_value("display_resolution", val)))

	box.add_child(_spacer(6))
	box.add_child(_hint("Resolution is ignored while Fullscreen is on."))
	return box


# ── Gameplay page ─────────────────────────────────────────────────────────────
func _build_gameplay_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)

	box.add_child(_section_label("Combat"))
	box.add_child(_slider_row("Animation Speed",
		Settings.combat_speed(),
		func(v): Settings.set_value("combat_speed", v),
		0.5, 2.0, 0.05, "%.2f×", 1.0))
	box.add_child(_toggle_row("Verbose Battle Log (show dice & modifiers)",
		Settings.verbose_battle_log(),
		func(on): Settings.set_value("verbose_battle_log", on)))

	box.add_child(_section_label("Save"))
	box.add_child(_slider_row("Auto-Save Frequency (days, 0 = off)",
		float(Settings.autosave_freq()),
		func(v): Settings.set_value("autosave_freq", int(v)),
		0.0, 14.0, 1.0, "%d", 1.0))

	box.add_child(_section_label("Help"))
	box.add_child(_toggle_row("Verbose Tooltips",
		Settings.verbose_tooltips(),
		func(on): Settings.set_value("verbose_tooltips", on)))

	return box


# ── Accessibility page ────────────────────────────────────────────────────────
func _build_accessibility_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)

	box.add_child(_section_label("Display"))
	box.add_child(_slider_row("UI Text Scale",
		Settings.text_scale(),
		func(v): Settings.set_value("text_scale", v),
		0.85, 1.5, 0.05, "%d%%", 100.0))

	box.add_child(_section_label("Vision"))
	box.add_child(_dropdown_row("Colorblind Filter",
		["off", "protan", "deutan", "tritan"],
		Settings.colorblind(),
		func(val): Settings.set_value("colorblind", val),
		{"off": "Off",
		 "protan": "Protanopia (red-blind)",
		 "deutan": "Deuteranopia (green-blind)",
		 "tritan": "Tritanopia (blue-blind)"}))

	box.add_child(_section_label("Motion"))
	box.add_child(_toggle_row("Reduce Motion (suppress camera shake & flashes)",
		Settings.reduce_motion(),
		func(on): Settings.set_value("reduce_motion", on)))

	return box


# ─────────────────────────────────────────────────────────────────────────────
# Footer (Defaults, Close)
# ─────────────────────────────────────────────────────────────────────────────
func _build_footer() -> Control:
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 22)
	pad.add_theme_constant_override("margin_right", 22)
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_bottom", 16)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	pad.add_child(row)

	var defaults := _action_button("Defaults", COL_TEXT_DIM, false)
	defaults.pressed.connect(func():
		_safe_audio("back")
		Settings.reset_to_defaults()
		# Rebuild current page so widget values refresh
		_rebuild_pages())
	row.add_child(defaults)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var close := _action_button("Close", COL_ACCENT, true)
	close.pressed.connect(func():
		_safe_audio("close_panel")
		_close())
	row.add_child(close)

	return pad


func _action_button(text: String, color: Color, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(140, 38)
	b.add_theme_font_size_override("font_size", 14)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.flat = true

	var sb := StyleBoxFlat.new()
	if primary:
		sb.bg_color = Color(color.r, color.g, color.b, 0.18)
	else:
		sb.bg_color = Color(1, 1, 1, 0.04)
	sb.border_color = Color(color.r, color.g, color.b, 0.5 if primary else 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	b.add_theme_stylebox_override("normal", sb)

	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(color.r, color.g, color.b, 0.30)
	sb_h.border_color = Color(color.r, color.g, color.b, 0.8)
	b.add_theme_stylebox_override("hover", sb_h)

	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	b.mouse_entered.connect(func(): _safe_audio("hover"))
	return b


func _close() -> void:
	# Settings already persisted on every change; nothing else to flush.
	if _on_close.is_valid():
		_on_close.call()
	queue_free()


func _rebuild_pages() -> void:
	# Clear and recreate pages so widget values reflect the new state.
	# The page_root is the parent of the page stack.
	if _pages.is_empty():
		return
	var stack: Node = _pages[0].get_parent()
	for p in _pages:
		stack.remove_child(p)
		p.queue_free()
	_pages.clear()
	_pages.append(_build_audio_page())
	_pages.append(_build_display_page())
	_pages.append(_build_gameplay_page())
	_pages.append(_build_accessibility_page())
	for p in _pages:
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(p)
	_show_tab(_current_tab)


# ─────────────────────────────────────────────────────────────────────────────
# Reusable row builders
# ─────────────────────────────────────────────────────────────────────────────
func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", COL_CYAN)
	return l


func _hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", COL_TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _slider_row(label_text: String, initial: float, on_change: Callable,
		min_v: float, max_v: float, step: float, fmt: String, mult: float,
		on_release: Callable = Callable()) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(180, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", COL_TEXT)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 24)
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(60, 0)
	val_lbl.text = fmt % (initial * mult)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.add_theme_color_override("font_color", COL_ACCENT)
	row.add_child(val_lbl)

	slider.value_changed.connect(func(v):
		val_lbl.text = fmt % (v * mult)
		on_change.call(v))
	if on_release.is_valid():
		slider.drag_ended.connect(func(_drag_changed):
			on_release.call(slider.value))

	return row


func _toggle_row(label_text: String, initial: bool, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", COL_TEXT)
	row.add_child(lbl)

	var cb := CheckButton.new()
	cb.button_pressed = initial
	cb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cb.toggled.connect(func(on):
		_safe_audio("switch")
		on_change.call(on))
	row.add_child(cb)

	return row


func _dropdown_row(label_text: String, options: Array, current: String,
		on_change: Callable, display_map: Dictionary = {}) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", COL_TEXT)
	row.add_child(lbl)

	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(220, 32)
	ob.add_theme_font_size_override("font_size", 13)
	ob.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sel_idx := 0
	for i in range(options.size()):
		var key := str(options[i])
		var display := str(display_map.get(key, key))
		ob.add_item(display, i)
		if key == current:
			sel_idx = i
	ob.select(sel_idx)
	ob.item_selected.connect(func(idx):
		_safe_audio("click")
		on_change.call(str(options[idx])))
	row.add_child(ob)

	return row
