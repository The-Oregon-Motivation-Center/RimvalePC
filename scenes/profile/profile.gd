extends Control

var rename_dialog_open: bool = false
var wipe_confirm_dialog_open: bool = false

var _player_name_lbl: Label  # stored ref for live updates

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RimvaleUtils.add_bg(self, RimvaleColors.BG_DARK)

	var main_scroll = ScrollContainer.new()
	main_scroll.anchor_left = 0.0
	main_scroll.anchor_top = 0.0
	main_scroll.anchor_right = 1.0
	main_scroll.anchor_bottom = 1.0
	add_child(main_scroll)

	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 16)
	main_scroll.add_child(main_vbox)

	# Profile card section
	_build_profile_card(main_vbox)

	main_vbox.add_child(RimvaleUtils.separator())

	# XP Progress section
	_build_xp_section(main_vbox)

	main_vbox.add_child(RimvaleUtils.separator())

	# Resources section
	_build_resources_section(main_vbox)

	main_vbox.add_child(RimvaleUtils.separator())

	# Actions section
	_build_actions_section(main_vbox)

	main_vbox.add_child(RimvaleUtils.separator())

	# Stats summary section
	_build_stats_section(main_vbox)

	main_vbox.add_child(RimvaleUtils.spacer(20))

func _build_profile_card(parent: VBoxContainer) -> void:
	var card = Control.new()
	card.custom_minimum_size.y = 140
	RimvaleUtils.add_bg(card, RimvaleColors.BG_CARD)
	parent.add_child(card)

	var card_vbox = VBoxContainer.new()
	card_vbox.anchor_left = 0.0
	card_vbox.anchor_top = 0.0
	card_vbox.anchor_right = 1.0
	card_vbox.anchor_bottom = 1.0
	card_vbox.add_theme_constant_override("separation", 8)
	card.add_child(card_vbox)

	# Title
	card_vbox.add_child(RimvaleUtils.label("ACF Agent Profile", 16, RimvaleColors.ACCENT))

	# Player name
	var name_hbox = HBoxContainer.new()
	name_hbox.add_child(RimvaleUtils.label("Name:", 12, RimvaleColors.TEXT_GRAY))
	var name_label = RimvaleUtils.label(GameState.player_name, 13, RimvaleColors.TEXT_WHITE)
	_player_name_lbl = name_label
	name_hbox.add_child(name_label)
	card_vbox.add_child(name_hbox)

	# Rank (placeholder)
	var rank_hbox = HBoxContainer.new()
	rank_hbox.add_child(RimvaleUtils.label("Rank:", 12, RimvaleColors.TEXT_GRAY))
	rank_hbox.add_child(RimvaleUtils.label("Agent", 13, RimvaleColors.GOLD))
	card_vbox.add_child(rank_hbox)

	# Level
	var level_hbox = HBoxContainer.new()
	level_hbox.add_child(RimvaleUtils.label("Level:", 12, RimvaleColors.TEXT_GRAY))
	var level_label = RimvaleUtils.label(str(GameState.player_level), 13, RimvaleColors.TEXT_WHITE)
	level_label.name = "player_level_label"
	level_hbox.add_child(level_label)
	card_vbox.add_child(level_hbox)

	# Rename button
	var rename_btn = RimvaleUtils.button("Rename", RimvaleColors.CYAN, 50, 12)
	rename_btn.pressed.connect(_on_rename_pressed)
	card_vbox.add_child(rename_btn)

func _build_xp_section(parent: VBoxContainer) -> void:
	parent.add_child(RimvaleUtils.label("Experience Progress", 14, RimvaleColors.ACCENT))

	# XP bar
	var xp_container = Control.new()
	xp_container.custom_minimum_size.y = 40
	RimvaleUtils.add_bg(xp_container, RimvaleColors.BG_CARD)

	var xp_vbox = VBoxContainer.new()
	xp_vbox.anchor_left = 0.0
	xp_vbox.anchor_top = 0.0
	xp_vbox.anchor_right = 1.0
	xp_vbox.anchor_bottom = 1.0
	xp_container.add_child(xp_vbox)

	var xp_label_hbox = HBoxContainer.new()
	xp_label_hbox.add_child(RimvaleUtils.label("XP:", 11, RimvaleColors.TEXT_GRAY))

	var xp_text = str(GameState.player_xp) + " / " + str(GameState.player_xp_required)
	var xp_value_label = RimvaleUtils.label(xp_text, 11, RimvaleColors.AP_BLUE)
	xp_value_label.name = "xp_value_label"
	xp_label_hbox.add_child(xp_value_label)
	xp_vbox.add_child(xp_label_hbox)

	# Progress bar
	var progress_bar = ProgressBar.new()
	progress_bar.max_value = float(GameState.player_xp_required)
	progress_bar.value = float(GameState.player_xp)
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.custom_minimum_size.y = 20
	progress_bar.modulate = RimvaleColors.AP_BLUE
	xp_vbox.add_child(progress_bar)

	parent.add_child(xp_container)

func _build_resources_section(parent: VBoxContainer) -> void:
	parent.add_child(RimvaleUtils.label("Resources", 14, RimvaleColors.ACCENT))

	var resources_hbox = HBoxContainer.new()
	resources_hbox.add_theme_constant_override("separation", 12)

	# Gold
	var gold_box = Control.new()
	gold_box.custom_minimum_size = Vector2(120, 60)
	RimvaleUtils.add_bg(gold_box, RimvaleColors.BG_CARD)
	var gold_vbox = VBoxContainer.new()
	gold_vbox.anchor_left = 0.0
	gold_vbox.anchor_top = 0.0
	gold_vbox.anchor_right = 1.0
	gold_vbox.anchor_bottom = 1.0
	gold_box.add_child(gold_vbox)
	gold_vbox.add_child(RimvaleUtils.label("Gold", 11, RimvaleColors.TEXT_GRAY))
	var gold_label = RimvaleUtils.label(str(GameState.gold), 14, RimvaleColors.GOLD)
	gold_label.name = "gold_display"
	gold_vbox.add_child(gold_label)
	resources_hbox.add_child(gold_box)

	# Tokens
	var tokens_box = Control.new()
	tokens_box.custom_minimum_size = Vector2(120, 60)
	RimvaleUtils.add_bg(tokens_box, RimvaleColors.BG_CARD)
	var tokens_vbox = VBoxContainer.new()
	tokens_vbox.anchor_left = 0.0
	tokens_vbox.anchor_top = 0.0
	tokens_vbox.anchor_right = 1.0
	tokens_vbox.anchor_bottom = 1.0
	tokens_box.add_child(tokens_vbox)
	tokens_vbox.add_child(RimvaleUtils.label("Tokens", 11, RimvaleColors.TEXT_GRAY))
	var tokens_label = RimvaleUtils.label(str(GameState.tokens), 14, RimvaleColors.CYAN)
	tokens_label.name = "tokens_display"
	tokens_vbox.add_child(tokens_label)
	resources_hbox.add_child(tokens_box)

	# Remnant Fragments
	var rf_box = Control.new()
	rf_box.custom_minimum_size = Vector2(120, 60)
	RimvaleUtils.add_bg(rf_box, RimvaleColors.BG_CARD)
	var rf_vbox = VBoxContainer.new()
	rf_vbox.anchor_left = 0.0
	rf_vbox.anchor_top = 0.0
	rf_vbox.anchor_right = 1.0
	rf_vbox.anchor_bottom = 1.0
	rf_box.add_child(rf_vbox)
	rf_vbox.add_child(RimvaleUtils.label("RF", 11, RimvaleColors.TEXT_GRAY))
	var rf_label = RimvaleUtils.label(str(GameState.remnant_fragments), 14, RimvaleColors.ORANGE)
	rf_label.name = "rf_display"
	rf_vbox.add_child(rf_label)
	resources_hbox.add_child(rf_box)

	parent.add_child(resources_hbox)

func _build_actions_section(parent: VBoxContainer) -> void:
	parent.add_child(RimvaleUtils.label("Actions", 14, RimvaleColors.ACCENT))

	var actions_vbox = VBoxContainer.new()
	actions_vbox.add_theme_constant_override("separation", 8)

	var rename_action_btn = RimvaleUtils.button("Edit Profile Name", RimvaleColors.CYAN, 60, 12)
	rename_action_btn.pressed.connect(_on_rename_pressed)
	actions_vbox.add_child(rename_action_btn)

	parent.add_child(actions_vbox)

func _build_stats_section(parent: VBoxContainer) -> void:
	parent.add_child(RimvaleUtils.label("Collection Stats", 14, RimvaleColors.ACCENT))

	var stats_hbox = HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", 12)

	# Total units
	var total_box = Control.new()
	total_box.custom_minimum_size = Vector2(120, 60)
	RimvaleUtils.add_bg(total_box, RimvaleColors.BG_CARD)
	var total_vbox = VBoxContainer.new()
	total_vbox.anchor_left = 0.0
	total_vbox.anchor_top = 0.0
	total_vbox.anchor_right = 1.0
	total_vbox.anchor_bottom = 1.0
	total_box.add_child(total_vbox)
	total_vbox.add_child(RimvaleUtils.label("Collection", 11, RimvaleColors.TEXT_GRAY))
	var total_label = RimvaleUtils.label(str(GameState.collection.size()), 14, RimvaleColors.ACCENT)
	total_label.name = "collection_count"
	total_vbox.add_child(total_label)
	stats_hbox.add_child(total_box)

	# Active team
	var team_box = Control.new()
	team_box.custom_minimum_size = Vector2(120, 60)
	RimvaleUtils.add_bg(team_box, RimvaleColors.BG_CARD)
	var team_vbox = VBoxContainer.new()
	team_vbox.anchor_left = 0.0
	team_vbox.anchor_top = 0.0
	team_vbox.anchor_right = 1.0
	team_vbox.anchor_bottom = 1.0
	team_box.add_child(team_vbox)
	team_vbox.add_child(RimvaleUtils.label("Active Team", 11, RimvaleColors.TEXT_GRAY))
	var team_label = RimvaleUtils.label(str(GameState.active_team.size()), 14, RimvaleColors.HP_GREEN)
	team_label.name = "active_team_count"
	team_vbox.add_child(team_label)
	stats_hbox.add_child(team_box)

	parent.add_child(stats_hbox)

	# Danger zone
	parent.add_child(RimvaleUtils.separator())
	parent.add_child(RimvaleUtils.label("Danger Zone", 14, RimvaleColors.DANGER))

	var wipe_btn = RimvaleUtils.button("Wipe All Data", RimvaleColors.DANGER, 60, 12)
	wipe_btn.pressed.connect(_on_wipe_pressed)
	parent.add_child(wipe_btn)

func _on_rename_pressed() -> void:
	if rename_dialog_open:
		return

	rename_dialog_open = true

	# Create dialog overlay
	var dialog = Control.new()
	dialog.anchor_left = 0.0
	dialog.anchor_top = 0.0
	dialog.anchor_right = 1.0
	dialog.anchor_bottom = 1.0
	dialog.name = "rename_dialog"
	add_child(dialog)

	# Dark overlay
	var overlay = ColorRect.new()
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0, 0, 0, 0.5)
	dialog.add_child(overlay)

	# Dialog panel
	var panel = PanelContainer.new()
	panel.anchor_left = 0.25
	panel.anchor_top = 0.35
	panel.anchor_right = 0.75
	panel.anchor_bottom = 0.65
	panel.modulate = RimvaleColors.BG_CARD
	dialog.add_child(panel)

	var panel_vbox = VBoxContainer.new()
	panel_vbox.anchor_left = 0.0
	panel_vbox.anchor_top = 0.0
	panel_vbox.anchor_right = 1.0
	panel_vbox.anchor_bottom = 1.0
	panel_vbox.add_theme_constant_override("separation", 12)
	panel.add_child(panel_vbox)

	panel_vbox.add_child(RimvaleUtils.label("Enter New Name", 14, RimvaleColors.ACCENT))

	var name_input = LineEdit.new()
	name_input.text = GameState.player_name
	name_input.custom_minimum_size.y = 40
	panel_vbox.add_child(name_input)

	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.add_theme_constant_override("separation", 8)

	var confirm_btn = RimvaleUtils.button("Confirm", RimvaleColors.SUCCESS, 50, 12)
	confirm_btn.pressed.connect(func():
		if name_input.text.length() > 0:
			GameState.player_name = name_input.text
			_update_name_display()
		_close_rename_dialog(dialog)
	)
	buttons_hbox.add_child(confirm_btn)

	var cancel_btn = RimvaleUtils.button("Cancel", RimvaleColors.TEXT_GRAY, 50, 12)
	cancel_btn.pressed.connect(func(): _close_rename_dialog(dialog))
	buttons_hbox.add_child(cancel_btn)

	panel_vbox.add_child(buttons_hbox)

func _close_rename_dialog(dialog: Control) -> void:
	dialog.queue_free()
	rename_dialog_open = false

func _update_name_display() -> void:
	if _player_name_lbl:
		_player_name_lbl.text = GameState.player_name

func _on_wipe_pressed() -> void:
	if wipe_confirm_dialog_open:
		return

	wipe_confirm_dialog_open = true

	# Create confirmation dialog
	var dialog = Control.new()
	dialog.anchor_left = 0.0
	dialog.anchor_top = 0.0
	dialog.anchor_right = 1.0
	dialog.anchor_bottom = 1.0
	dialog.name = "wipe_dialog"
	add_child(dialog)

	# Dark overlay
	var overlay = ColorRect.new()
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0, 0, 0, 0.5)
	dialog.add_child(overlay)

	# Dialog panel
	var panel = PanelContainer.new()
	panel.anchor_left = 0.2
	panel.anchor_top = 0.3
	panel.anchor_right = 0.8
	panel.anchor_bottom = 0.7
	panel.modulate = RimvaleColors.BG_CARD
	dialog.add_child(panel)

	var panel_vbox = VBoxContainer.new()
	panel_vbox.anchor_left = 0.0
	panel_vbox.anchor_top = 0.0
	panel_vbox.anchor_right = 1.0
	panel_vbox.anchor_bottom = 1.0
	panel_vbox.add_theme_constant_override("separation", 16)
	panel.add_child(panel_vbox)

	panel_vbox.add_child(RimvaleUtils.label("Confirm Wipe All Data", 15, RimvaleColors.DANGER))
	panel_vbox.add_child(RimvaleUtils.label("This action cannot be undone.", 12, RimvaleColors.TEXT_WHITE))

	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.add_theme_constant_override("separation", 12)

	var confirm_wipe_btn = RimvaleUtils.button("Wipe Everything", RimvaleColors.DANGER, 60, 12)
	confirm_wipe_btn.pressed.connect(func():
		GameState.wipe_all()
		_close_wipe_dialog(dialog)
		print("Data wiped!")
	)
	buttons_hbox.add_child(confirm_wipe_btn)

	var cancel_wipe_btn = RimvaleUtils.button("Cancel", RimvaleColors.TEXT_GRAY, 50, 12)
	cancel_wipe_btn.pressed.connect(func(): _close_wipe_dialog(dialog))
	buttons_hbox.add_child(cancel_wipe_btn)

	panel_vbox.add_child(buttons_hbox)

func _close_wipe_dialog(dialog: Control) -> void:
	dialog.queue_free()
	wipe_confirm_dialog_open = false
