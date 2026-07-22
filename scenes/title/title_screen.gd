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
var _continue_btn: Button         # Quick-resume of the most recent save
var _continue_sub_lbl: Label      # Small caption showing which slot Continue will load
var _load_game_btn: Button        # Opens the slot picker
var _new_game_btn: Button
var _settings_btn: Button
var _quit_btn: Button
var _version_lbl: Label

# Two-level menu: the root picks a game (RPG / Battle / TCG); submenus hold
# each game's own options. Arrays drive visibility in _show_menu_level().
var _menu_level: String = "root"
var _root_btns: Array = []        # the three game buttons
var _rpg_btns: Array = []         # Continue / Load / New / Back
var _battle_btns: Array = []      # Battle Mode / Conquest / Back
var _rpg_menu_btn: Button
var _back_btn: Button             # shared submenu → root button
var _continue_ok: bool = false    # save-dependent visibility, checked at build
var _load_ok: bool = false

# Settings overlay
var _settings_overlay: Control

# Slot picker / new-game name prompt / save browser
var _slot_picker_overlay: Control
var _name_prompt_overlay: Control
var _save_browser_overlay: Control

# Confirmation dialog (used for new-game-while-saves-exist + delete-slot)
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

	# Migrate any legacy single-file save into a slot once, before we check
	# what's available. After migration, list_save_slots() is the source of truth.
	GameState.migrate_legacy_save_if_needed()
	var has_save: bool = GameState.list_save_slots().size() > 0 \
		or FileAccess.file_exists(SAVE_PATH)

	# ── Root level: pick a game ──────────────────────────────────────────
	_rpg_menu_btn = _make_menu_btn("⚔ Rimvale — The RPG", RimvaleColors.GOLD, 18)
	_rpg_menu_btn.pressed.connect(func(): _show_menu_level("rpg"))
	_menu_vbox.add_child(_rpg_menu_btn)
	_root_btns.append(_rpg_menu_btn)

	var battle_menu_btn := _make_menu_btn("🏰 Rimvale Battle", RimvaleColors.ORANGE, 18)
	battle_menu_btn.pressed.connect(func(): _show_menu_level("battle"))
	_menu_vbox.add_child(battle_menu_btn)
	_root_btns.append(battle_menu_btn)

	var tcg_btn := _make_menu_btn("🃏 Rimvale TCG", RimvaleColors.ACCENT, 18)
	tcg_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/cards/card_setup.tscn")
	)
	_menu_vbox.add_child(tcg_btn)
	_root_btns.append(tcg_btn)

	# ── RPG submenu: Continue / Load / New ───────────────────────────────
	var resume_meta: Dictionary = _find_most_recent_slot_meta()
	_continue_ok = has_save and not resume_meta.is_empty()
	_load_ok = has_save

	_continue_btn = _make_menu_btn("Continue", RimvaleColors.GOLD, 18)
	_continue_btn.pressed.connect(_on_continue)
	_menu_vbox.add_child(_continue_btn)
	_rpg_btns.append(_continue_btn)

	# Subtitle showing which save will be resumed
	_continue_sub_lbl = Label.new()
	_continue_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_continue_sub_lbl.add_theme_font_size_override("font_size", 11)
	_continue_sub_lbl.add_theme_color_override("font_color", RimvaleColors.TEXT_GRAY)
	if not resume_meta.is_empty():
		var nm: String = str(resume_meta.get("display_name", resume_meta.get("slot_id", "")))
		var lp: String = str(resume_meta.get("last_played", ""))
		_continue_sub_lbl.text = nm + ("  •  " + lp if lp != "" else "")
	_menu_vbox.add_child(_continue_sub_lbl)

	# Load Game (slot picker) — visible whenever any save exists
	_load_game_btn = _make_menu_btn("Load Game", RimvaleColors.ACCENT, 18)
	_load_game_btn.pressed.connect(_on_load_game)
	_menu_vbox.add_child(_load_game_btn)
	_rpg_btns.append(_load_game_btn)

	# New Game
	_new_game_btn = _make_menu_btn("New Game", RimvaleColors.CYAN, 18)
	_new_game_btn.pressed.connect(_on_new_game)
	_menu_vbox.add_child(_new_game_btn)
	_rpg_btns.append(_new_game_btn)

	# ── Battle submenu: skirmish + conquest ──────────────────────────────
	var battle_btn := _make_menu_btn("⚔ Battle Mode", RimvaleColors.ORANGE, 18)
	battle_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/battle/battle_setup.tscn")
	)
	_menu_vbox.add_child(battle_btn)
	_battle_btns.append(battle_btn)

	# Region Conquest — the Battle Mode meta-campaign (own save, separate too)
	var conquest_btn := _make_menu_btn("🗺 Conquest", RimvaleColors.GOLD, 18)
	conquest_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/battle/conquest_map.tscn")
	)
	_menu_vbox.add_child(conquest_btn)
	_battle_btns.append(conquest_btn)

	# ── Shared "back to game pick" button for both submenus ──────────────
	_back_btn = _make_menu_btn("◂ Back", RimvaleColors.TEXT_GRAY, 16)
	_back_btn.pressed.connect(func(): _show_menu_level("root"))
	_menu_vbox.add_child(_back_btn)

	# Settings
	_settings_btn = _make_menu_btn("Settings", RimvaleColors.TEXT_LIGHT, 16)
	_settings_btn.pressed.connect(_on_settings)
	_menu_vbox.add_child(_settings_btn)

	# Credits & Legal (includes the SRD 5.2.1 CC-BY attribution — required)
	var credits_btn: Button = _make_menu_btn("Credits", RimvaleColors.TEXT_GRAY, 16)
	credits_btn.pressed.connect(_show_credits)
	_menu_vbox.add_child(credits_btn)

	# Quit
	_quit_btn = _make_menu_btn("Quit", RimvaleColors.TEXT_GRAY, 16)
	_quit_btn.pressed.connect(_on_quit)
	_menu_vbox.add_child(_quit_btn)

	# Settings / Credits / Quit live on the root level only.
	_root_btns.append(_settings_btn)
	_root_btns.append(credits_btn)
	_root_btns.append(_quit_btn)

	# Open on the game-pick level.
	_show_menu_level("root")

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

	# Title music — fade in shortly after the screen appears.
	if typeof(AudioManager) != TYPE_NIL:
		AudioManager.play_music("music_title", 2.0)

	# Gamepad: grab focus on the most relevant button so D-pad / stick can
	# navigate without the user needing to click first.
	call_deferred("_grab_initial_focus")


func _grab_initial_focus() -> void:
	if _rpg_menu_btn != null:
		_rpg_menu_btn.grab_focus()


## Toggle menu buttons between the root game-pick and one game's submenu.
## Levels: "root" (RPG / Battle / TCG), "rpg", "battle".
func _show_menu_level(level: String) -> void:
	_menu_level = level
	for b in _root_btns:
		(b as Button).visible = level == "root"
	for b in _rpg_btns:
		(b as Button).visible = level == "rpg"
	for b in _battle_btns:
		(b as Button).visible = level == "battle"
	_back_btn.visible = level != "root"
	# Save-dependent RPG entries only show when a save actually exists.
	_continue_btn.visible = level == "rpg" and _continue_ok
	_continue_sub_lbl.visible = _continue_btn.visible
	_load_game_btn.visible = level == "rpg" and _load_ok
	# Keep gamepad focus somewhere sensible after the switch.
	match level:
		"root":
			_rpg_menu_btn.grab_focus()
		"rpg":
			if _continue_btn.visible:
				_continue_btn.grab_focus()
			else:
				_new_game_btn.grab_focus()
		"battle":
			if not _battle_btns.is_empty():
				(_battle_btns[0] as Button).grab_focus()

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

	# Audio: subtle hover + click.
	btn.mouse_entered.connect(func():
		if typeof(AudioManager) != TYPE_NIL: AudioManager.hover())
	btn.pressed.connect(func():
		if typeof(AudioManager) != TYPE_NIL: AudioManager.click())

	return btn

# ── Actions ──────────────────────────────────────────────────────────────────
## Resume the most recently played save without opening the slot picker.
## continue_game("") auto-picks the slot whose newest save file is freshest.
func _on_continue() -> void:
	GameState.continue_game()
	_transition_to_game()

func _on_load_game() -> void:
	_show_slot_picker()

## Returns the slot summary whose newest save file was modified most recently,
## or {} if no slots exist. Used to label and gate the Continue button.
func _find_most_recent_slot_meta() -> Dictionary:
	var summaries: Array = GameState.get_slot_summaries()
	var best: Dictionary = {}
	var best_mt: int = -1
	for s in summaries:
		var p: String = str(s.get("latest_save", ""))
		if p == "": continue
		var mt: int = FileAccess.get_modified_time(p)
		if mt > best_mt:
			best_mt = mt
			best = s
	return best

func _on_new_game() -> void:
	# Always prompt for a save name. The new save lives in its own slot
	# and never overwrites existing slots.
	_show_new_game_name_prompt()

func _start_new_game(display_name: String) -> void:
	GameState.start_new_game(display_name)
	_transition_to_game()

# ── Slot picker (Load Game) ──────────────────────────────────────────────────
func _show_slot_picker() -> void:
	if _slot_picker_overlay:
		_slot_picker_overlay.queue_free()
	_slot_picker_overlay = Control.new()
	_slot_picker_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slot_picker_overlay.z_index = 50

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slot_picker_overlay.add_child(dim)

	var panel_styled := PanelContainer.new()
	panel_styled.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel_styled.offset_left = -300; panel_styled.offset_right = 300
	panel_styled.offset_top = -240; panel_styled.offset_bottom = 240
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0.08, 0.04, 0.16, 1.0)
	border.border_color = RimvaleColors.ACCENT
	border.set_border_width_all(2)
	border.set_corner_radius_all(8)
	border.set_content_margin_all(20)
	panel_styled.add_theme_stylebox_override("panel", border)
	_slot_picker_overlay.add_child(panel_styled)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel_styled.add_child(vbox)

	var title := Label.new()
	title.text = "Load Game"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", RimvaleColors.ACCENT)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 320)
	vbox.add_child(scroll)
	var list_v := VBoxContainer.new()
	list_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_v.add_theme_constant_override("separation", 10)
	scroll.add_child(list_v)

	var summaries: Array = GameState.get_slot_summaries()
	if summaries.is_empty():
		var none := Label.new()
		none.text = "No save slots yet. Start a New Game to begin."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.add_theme_color_override("font_color", RimvaleColors.TEXT_GRAY)
		list_v.add_child(none)
	else:
		for s in summaries:
			list_v.add_child(_make_slot_card(s))

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)
	var close := _make_menu_btn("Close", RimvaleColors.TEXT_GRAY, 14)
	close.custom_minimum_size = Vector2(140, 38)
	close.pressed.connect(func():
		_slot_picker_overlay.queue_free()
		_slot_picker_overlay = null
	)
	btn_row.add_child(close)

	add_child(_slot_picker_overlay)

func _make_slot_card(s: Dictionary) -> Control:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.02, 0.10, 1.0)
	sb.border_color = Color(RimvaleColors.ACCENT.r, RimvaleColors.ACCENT.g,
							RimvaleColors.ACCENT.b, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var name_lbl := Label.new()
	name_lbl.text = str(s.get("display_name", s.get("slot_id", "")))
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", RimvaleColors.GOLD)
	col.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Last played: %s" % str(s.get("last_played", "—"))
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", RimvaleColors.TEXT_GRAY)
	col.add_child(sub_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	col.add_child(btn_row)

	var slot_id: String = str(s.get("slot_id", ""))
	var continue_btn := _make_menu_btn("Continue", RimvaleColors.ACCENT, 12)
	continue_btn.custom_minimum_size = Vector2(120, 32)
	continue_btn.pressed.connect(func():
		_slot_picker_overlay.queue_free()
		_slot_picker_overlay = null
		GameState.continue_game(slot_id)
		_transition_to_game()
	)
	btn_row.add_child(continue_btn)

	var browse_btn := _make_menu_btn("Browse Saves", RimvaleColors.CYAN, 12)
	browse_btn.custom_minimum_size = Vector2(140, 32)
	browse_btn.pressed.connect(func(): _show_save_browser(slot_id))
	btn_row.add_child(browse_btn)

	var del_btn := _make_menu_btn("Delete", RimvaleColors.DANGER, 12)
	del_btn.custom_minimum_size = Vector2(90, 32)
	del_btn.pressed.connect(func():
		_show_confirm("Delete \"%s\"?" % name_lbl.text,
			"All saves in this slot will be permanently lost.",
			"Delete", RimvaleColors.DANGER,
			func():
				GameState.delete_save_slot(slot_id)
				# Refresh the picker so the deleted slot disappears
				_slot_picker_overlay.queue_free()
				_slot_picker_overlay = null
				_show_slot_picker())
	)
	btn_row.add_child(del_btn)

	return card

# ── Per-slot save browser (auto + manual saves) ──────────────────────────────
func _show_save_browser(slot_id: String) -> void:
	if _save_browser_overlay:
		_save_browser_overlay.queue_free()
	_save_browser_overlay = Control.new()
	_save_browser_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_save_browser_overlay.z_index = 60

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_save_browser_overlay.add_child(dim)

	var panel_styled := PanelContainer.new()
	panel_styled.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel_styled.offset_left = -280; panel_styled.offset_right = 280
	panel_styled.offset_top = -220; panel_styled.offset_bottom = 220
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0.06, 0.03, 0.14, 1.0)
	border.border_color = RimvaleColors.CYAN
	border.set_border_width_all(2); border.set_corner_radius_all(8)
	border.set_content_margin_all(18)
	panel_styled.add_theme_stylebox_override("panel", border)
	_save_browser_overlay.add_child(panel_styled)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel_styled.add_child(vbox)

	var title := Label.new()
	title.text = "Saves — %s" % slot_id
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", RimvaleColors.CYAN)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 280)
	vbox.add_child(scroll)
	var list_v := VBoxContainer.new()
	list_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_v.add_theme_constant_override("separation", 6)
	scroll.add_child(list_v)

	var saves: Array = GameState.list_saves_in_slot(slot_id)
	if saves.is_empty():
		var none := Label.new()
		none.text = "(no save files in this slot)"
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.add_theme_color_override("font_color", RimvaleColors.TEXT_GRAY)
		list_v.add_child(none)
	else:
		for sv in saves:
			var path: String = str(sv["path"])
			var kind: String = str(sv["kind"])
			var label: String = str(sv["label"])
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var name_lbl := Label.new()
			var badge: String = "[AUTO] " if kind == "auto" else "[MANUAL] "
			name_lbl.text = badge + label
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.add_theme_font_size_override("font_size", 12)
			name_lbl.add_theme_color_override("font_color",
				RimvaleColors.TEXT_LIGHT if kind == "auto" else RimvaleColors.GOLD)
			row.add_child(name_lbl)
			var load_btn := _make_menu_btn("Load", RimvaleColors.ACCENT, 11)
			load_btn.custom_minimum_size = Vector2(80, 28)
			load_btn.pressed.connect(func():
				GameState.set_active_slot(slot_id)
				if GameState.load_specific_save(path):
					_save_browser_overlay.queue_free()
					_save_browser_overlay = null
					_slot_picker_overlay.queue_free()
					_slot_picker_overlay = null
					_transition_to_game()
			)
			row.add_child(load_btn)
			list_v.add_child(row)

	var close := _make_menu_btn("Back", RimvaleColors.TEXT_GRAY, 12)
	close.custom_minimum_size = Vector2(120, 34)
	close.pressed.connect(func():
		_save_browser_overlay.queue_free()
		_save_browser_overlay = null
	)
	vbox.add_child(close)

	add_child(_save_browser_overlay)

# ── New Game name prompt ─────────────────────────────────────────────────────
func _show_new_game_name_prompt() -> void:
	if _name_prompt_overlay:
		_name_prompt_overlay.queue_free()
	_name_prompt_overlay = Control.new()
	_name_prompt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_name_prompt_overlay.z_index = 50

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_name_prompt_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -200; panel.offset_right = 200
	panel.offset_top = -110; panel.offset_bottom = 110
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0.08, 0.04, 0.16, 1.0)
	border.border_color = RimvaleColors.CYAN
	border.set_border_width_all(2); border.set_corner_radius_all(8)
	border.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", border)
	_name_prompt_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Name your save"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", RimvaleColors.CYAN)
	vbox.add_child(title)

	var name_input := LineEdit.new()
	var auto_name: String = "Save %d" % (GameState.list_save_slots().size() + 1)
	name_input.text = auto_name
	name_input.placeholder_text = "Save name"
	name_input.custom_minimum_size = Vector2(0, 36)
	vbox.add_child(name_input)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var cancel := _make_menu_btn("Cancel", RimvaleColors.TEXT_GRAY, 13)
	cancel.custom_minimum_size = Vector2(120, 36)
	cancel.pressed.connect(func():
		_name_prompt_overlay.queue_free()
		_name_prompt_overlay = null
	)
	btn_row.add_child(cancel)

	var go := _make_menu_btn("Begin", RimvaleColors.ACCENT, 13)
	go.custom_minimum_size = Vector2(120, 36)
	go.pressed.connect(func():
		var nm: String = name_input.text.strip_edges()
		if nm.is_empty(): nm = auto_name
		_name_prompt_overlay.queue_free()
		_name_prompt_overlay = null
		_start_new_game(nm)
	)
	btn_row.add_child(go)

	add_child(_name_prompt_overlay)
	name_input.grab_focus()
	name_input.select_all()

# ── Generic confirm dialog (used by delete-slot) ─────────────────────────────
func _show_confirm(title_text: String, body_text: String,
		confirm_label: String, accent: Color, on_confirm: Callable) -> void:
	if _confirm_overlay:
		_confirm_overlay.queue_free()
	_confirm_overlay = Control.new()
	_confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.z_index = 70
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -200; panel.offset_right = 200
	panel.offset_top = -100; panel.offset_bottom = 100
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0.08, 0.04, 0.16, 1.0)
	border.border_color = accent
	border.set_border_width_all(2); border.set_corner_radius_all(8)
	border.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", border)
	_confirm_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var t := Label.new()
	t.text = title_text
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", accent)
	vbox.add_child(t)

	var b := Label.new()
	b.text = body_text
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", RimvaleColors.TEXT_LIGHT)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(b)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)
	var cancel := _make_menu_btn("Cancel", RimvaleColors.TEXT_GRAY, 12)
	cancel.custom_minimum_size = Vector2(110, 34)
	cancel.pressed.connect(func():
		_confirm_overlay.queue_free()
		_confirm_overlay = null
	)
	btn_row.add_child(cancel)
	var ok := _make_menu_btn(confirm_label, accent, 12)
	ok.custom_minimum_size = Vector2(110, 34)
	ok.pressed.connect(func():
		_confirm_overlay.queue_free()
		_confirm_overlay = null
		on_confirm.call()
	)
	btn_row.add_child(ok)
	add_child(_confirm_overlay)

func _on_settings() -> void:
	if typeof(AudioManager) != TYPE_NIL:
		AudioManager.open_panel()
	# Prefer the tabbed dialog when present; fall back to the legacy overlay.
	var dlg_script := load("res://scenes/popups/settings_dialog.gd")
	if dlg_script != null:
		var dlg = dlg_script.new()
		add_child(dlg)
		dlg.open()
	else:
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

# ── Credits & Legal ──────────────────────────────────────────────────────────
## Shows game credits including the REQUIRED SRD 5.2.1 CC-BY 4.0 attribution
## (see LEGAL_ATTRIBUTION.md — do not remove the SRD paragraph).
func _show_credits() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(720, 560)
	panel.position = Vector2(-360, -280)
	dim.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Rimvale — Credits & Legal"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(680, 430)
	vbox.add_child(scroll)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.text = """[b]Rimvale[/b]
A game by Spark Point Studios
Based on the Rimvale tabletop roleplaying game.

[b]Design, Writing & Development[/b]
Spark Point Studios

[b]Art & Audio[/b]
3D model kits by Kenney (kenney.nl) — CC0.
Additional audio credits: see the license files in the game's audio folder.

[b]Engine[/b]
Made with Godot Engine — godotengine.org/license

[b]System Reference Document Attribution[/b]
Rimvale includes material (weapon tables and weapon mastery properties) adapted from the System Reference Document 5.2.1 ("SRD 5.2.1") by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode.

This work is unofficial and is not endorsed by or affiliated with Wizards of the Coast LLC.

[b]Thank you for playing.[/b]"""
	scroll.add_child(body)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(160, 40)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func(): dim.queue_free())
	vbox.add_child(close_btn)
	close_btn.grab_focus()

# ── Helpers ──────────────────────────────────────────────────────────────────
func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s
