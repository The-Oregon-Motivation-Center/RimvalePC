## title_screen.gd
## Classic RPG title / main menu screen.
## Shows:  New Game  |  Continue (if save exists)  |  Settings  |  Quit
## Launched as the project's main scene; transitions to main.tscn on play.

extends Control

# ── Nodes ────────────────────────────────────────────────────────────────────
var _bg: ColorRect
var _title_lbl: Label
var _subtitle_lbl: Label
var _menu_vbox: VBoxContainer
var _continue_btn: Button
var _new_game_btn: Button
var _settings_btn: Button
var _quit_btn: Button
var _version_lbl: Label

# Settings overlay
var _settings_overlay: Control

# Confirmation dialog for New Game when save exists
var _confirm_overlay: Control

# ── Constants ────────────────────────────────────────────────────────────────
const MAIN_SCENE := "res://scenes/main/main.tscn"
const SAVE_PATH  := "user://rimvale_save.json"

# Fade-in
var _fade_alpha: float = 1.0
var _fade_rect: ColorRect
var _fading_in: bool = true

# ── Setup ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Deep background
	_bg = ColorRect.new()
	_bg.color = Color(0.06, 0.02, 0.12, 1.0)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# Subtle radial vignette overlay
	var vignette := ColorRect.new()
	vignette.color = Color(0.0, 0.0, 0.0, 0.25)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vignette)

	# Centred content column
	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.custom_minimum_size = Vector2(400, 0)
	center.offset_left = -200
	center.offset_top = -220
	center.add_theme_constant_override("separation", 0)
	add_child(center)

	# Spacer top
	center.add_child(_spacer(30))

	# Title
	_title_lbl = Label.new()
	_title_lbl.text = "RIMVALE"
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 52)
	_title_lbl.add_theme_color_override("font_color", RimvaleColors.GOLD)
	center.add_child(_title_lbl)

	# Subtitle
	_subtitle_lbl = Label.new()
	_subtitle_lbl.text = "Remnants of the Accord"
	_subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_lbl.add_theme_font_size_override("font_size", 16)
	_subtitle_lbl.add_theme_color_override("font_color", RimvaleColors.TEXT_GRAY)
	center.add_child(_subtitle_lbl)

	center.add_child(_spacer(50))

	# Menu buttons
	_menu_vbox = VBoxContainer.new()
	_menu_vbox.add_theme_constant_override("separation", 14)
	_menu_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(_menu_vbox)

	var has_save: bool = FileAccess.file_exists(SAVE_PATH)

	# Continue button — only if a save exists
	_continue_btn = _make_menu_btn("Continue", RimvaleColors.ACCENT, 18)
	_continue_btn.visible = has_save
	_continue_btn.pressed.connect(_on_continue)
	_menu_vbox.add_child(_continue_btn)

	# New Game
	_new_game_btn = _make_menu_btn("New Game", RimvaleColors.CYAN, 18)
	_new_game_btn.pressed.connect(_on_new_game)
	_menu_vbox.add_child(_new_game_btn)

	# Settings
	_settings_btn = _make_menu_btn("Settings", RimvaleColors.TEXT_LIGHT, 16)
	_settings_btn.pressed.connect(_on_settings)
	_menu_vbox.add_child(_settings_btn)

	# Quit
	_quit_btn = _make_menu_btn("Quit", RimvaleColors.TEXT_GRAY, 16)
	_quit_btn.pressed.connect(_on_quit)
	_menu_vbox.add_child(_quit_btn)

	# Version label bottom-right
	_version_lbl = Label.new()
	_version_lbl.text = "v0.1.0"
	_version_lbl.add_theme_font_size_override("font_size", 11)
	_version_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.2))
	_version_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_version_lbl.offset_left = -80
	_version_lbl.offset_top = -24
	_version_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_version_lbl)

	# Fade-in overlay
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 1)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)

func _process(delta: float) -> void:
	if _fading_in:
		_fade_alpha -= delta * 1.2   # ~0.8s fade
		if _fade_alpha <= 0.0:
			_fade_alpha = 0.0
			_fading_in = false
			_fade_rect.visible = false
		_fade_rect.color = Color(0, 0, 0, _fade_alpha)

# ── Menu button factory ──────────────────────────────────────────────────────
func _make_menu_btn(text: String, color: Color, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = true
	btn.custom_minimum_size = Vector2(280, 52)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color(
		minf(color.r + 0.2, 1.0),
		minf(color.g + 0.2, 1.0),
		minf(color.b + 0.2, 1.0), 1.0))
	btn.add_theme_color_override("font_pressed_color", RimvaleColors.GOLD)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Styled background
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.04)
	sb.border_color = Color(color.r, color.g, color.b, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", sb)

	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = Color(color.r, color.g, color.b, 0.12)
	sb_hover.border_color = Color(color.r, color.g, color.b, 0.5)
	sb_hover.set_border_width_all(1)
	sb_hover.set_corner_radius_all(6)
	sb_hover.set_content_margin_all(10)
	btn.add_theme_stylebox_override("hover", sb_hover)

	var sb_pressed := StyleBoxFlat.new()
	sb_pressed.bg_color = Color(color.r, color.g, color.b, 0.20)
	sb_pressed.border_color = RimvaleColors.GOLD
	sb_pressed.set_border_width_all(1)
	sb_pressed.set_corner_radius_all(6)
	sb_pressed.set_content_margin_all(10)
	btn.add_theme_stylebox_override("pressed", sb_pressed)

	return btn

# ── Actions ──────────────────────────────────────────────────────────────────
func _on_continue() -> void:
	# Load existing save and go to game
	GameState.continue_game()
	_transition_to_game()

func _on_new_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		_show_new_game_confirm()
	else:
		_start_new_game()

func _start_new_game() -> void:
	GameState.start_new_game()
	_transition_to_game()

func _on_settings() -> void:
	_show_settings()

func _on_quit() -> void:
	get_tree().quit()

# ── Transition ───────────────────────────────────────────────────────────────
func _transition_to_game() -> void:
	# Fade out then switch scene
	_fade_rect.visible = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fading_in = false
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color", Color(0, 0, 0, 1), 0.5)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(MAIN_SCENE)
	)

# ── New Game Confirm Dialog ──────────────────────────────────────────────────
func _show_new_game_confirm() -> void:
	if _confirm_overlay:
		_confirm_overlay.queue_free()

	_confirm_overlay = Control.new()
	_confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.z_index = 50

	# Dim
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_confirm_overlay.queue_free()
			_confirm_overlay = null
	)
	_confirm_overlay.add_child(dim)

	# Dialog box
	var panel := ColorRect.new()
	panel.color = Color(0.08, 0.04, 0.16, 1.0)
	panel.custom_minimum_size = Vector2(360, 200)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -180
	panel.offset_top = -100
	panel.offset_right = 180
	panel.offset_bottom = 100
	_confirm_overlay.add_child(panel)

	# Border
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0.08, 0.04, 0.16, 1.0)
	border.border_color = RimvaleColors.DANGER
	border.set_border_width_all(2)
	border.set_corner_radius_all(8)
	var panel_styled := PanelContainer.new()
	panel_styled.add_theme_stylebox_override("panel", border)
	panel_styled.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(panel_styled)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20; vbox.offset_right = -20
	vbox.offset_top = 20; vbox.offset_bottom = -20
	panel_styled.add_child(vbox)

	var title := Label.new()
	title.text = "Start New Game?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", RimvaleColors.DANGER)
	vbox.add_child(title)

	var msg := Label.new()
	msg.text = "This will erase your current save.\nAll units, gold, progress, and mission\ndata will be permanently lost."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 13)
	msg.add_theme_color_override("font_color", RimvaleColors.TEXT_LIGHT)
	vbox.add_child(msg)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var cancel_btn := _make_menu_btn("Cancel", RimvaleColors.TEXT_GRAY, 14)
	cancel_btn.custom_minimum_size = Vector2(120, 40)
	cancel_btn.pressed.connect(func():
		_confirm_overlay.queue_free()
		_confirm_overlay = null
	)
	btn_row.add_child(cancel_btn)

	var confirm_btn := _make_menu_btn("New Game", RimvaleColors.DANGER, 14)
	confirm_btn.custom_minimum_size = Vector2(120, 40)
	confirm_btn.pressed.connect(func():
		_confirm_overlay.queue_free()
		_confirm_overlay = null
		_start_new_game()
	)
	btn_row.add_child(confirm_btn)

	add_child(_confirm_overlay)

# ── Settings Panel ───────────────────────────────────────────────────────────
func _show_settings() -> void:
	if _settings_overlay:
		_settings_overlay.queue_free()

	_settings_overlay = Control.new()
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.z_index = 50

	# Dim
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.add_child(dim)

	# Panel
	var panel := ColorRect.new()
	panel.color = Color(0.08, 0.04, 0.16, 1.0)
	panel.custom_minimum_size = Vector2(420, 360)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -210; panel.offset_right = 210
	panel.offset_top = -180; panel.offset_bottom = 180
	_settings_overlay.add_child(panel)

	# Border
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0.08, 0.04, 0.16, 1.0)
	border.border_color = RimvaleColors.ACCENT
	border.set_border_width_all(2)
	border.set_corner_radius_all(8)
	var panel_styled := PanelContainer.new()
	panel_styled.add_theme_stylebox_override("panel", border)
	panel_styled.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(panel_styled)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 24; vbox.offset_right = -24
	vbox.offset_top = 20; vbox.offset_bottom = -20
	panel_styled.add_child(vbox)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", RimvaleColors.ACCENT)
	vbox.add_child(title)

	# ── Master volume ────────────────────────────────────────────────────────
	vbox.add_child(_make_setting_row("Master Volume", func(val: float):
		AudioServer.set_bus_volume_db(0, linear_to_db(val))
	, db_to_linear(AudioServer.get_bus_volume_db(0))))

	# ── Music volume (bus 1 if exists) ───────────────────────────────────────
	if AudioServer.bus_count > 1:
		vbox.add_child(_make_setting_row("Music Volume", func(val: float):
			AudioServer.set_bus_volume_db(1, linear_to_db(val))
		, db_to_linear(AudioServer.get_bus_volume_db(1))))

	# ── SFX volume (bus 2 if exists) ─────────────────────────────────────────
	if AudioServer.bus_count > 2:
		vbox.add_child(_make_setting_row("SFX Volume", func(val: float):
			AudioServer.set_bus_volume_db(2, linear_to_db(val))
		, db_to_linear(AudioServer.get_bus_volume_db(2))))

	# ── Fullscreen toggle ────────────────────────────────────────────────────
	var fs_row := HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 12)
	var fs_label := Label.new()
	fs_label.text = "Fullscreen"
	fs_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_label.add_theme_font_size_override("font_size", 14)
	fs_label.add_theme_color_override("font_color", RimvaleColors.TEXT_LIGHT)
	fs_row.add_child(fs_label)

	var fs_check := CheckButton.new()
	fs_check.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	fs_check.toggled.connect(func(on: bool):
		if on:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	)
	fs_row.add_child(fs_check)
	vbox.add_child(fs_row)

	# ── Close button ─────────────────────────────────────────────────────────
	var close_btn := _make_menu_btn("Close", RimvaleColors.TEXT_GRAY, 14)
	close_btn.custom_minimum_size = Vector2(120, 40)
	close_btn.pressed.connect(func():
		_settings_overlay.queue_free()
		_settings_overlay = null
	)
	vbox.add_child(close_btn)

	add_child(_settings_overlay)

func _make_setting_row(label_text: String, on_change: Callable, initial: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", RimvaleColors.TEXT_LIGHT)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = clampf(initial, 0.0, 1.0)
	slider.custom_minimum_size = Vector2(160, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(on_change)
	row.add_child(slider)

	return row

# ── Helpers ──────────────────────────────────────────────────────────────────
func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s
