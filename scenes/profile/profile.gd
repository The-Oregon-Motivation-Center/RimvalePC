extends Control

var rename_dialog_open: bool = false
var wipe_confirm_dialog_open: bool = false

var _player_name_lbl: Label  # stored ref for live updates

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RimvaleUtils.add_bg(self, RimvaleColors.BG_DARK)

	# Daily login bonus — show toast if first visit today
	if GameState.check_daily_login():
		_show_daily_bonus_toast()

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

	# Dev Tools / cheat panel
	_build_devtools_section(main_vbox)

	main_vbox.add_child(RimvaleUtils.separator())

	# Save Game section — manual saves + autosave info
	_build_save_section(main_vbox)

	main_vbox.add_child(RimvaleUtils.separator())

	# Garage — owned arcane vehicles
	_build_vehicles_section(main_vbox)

	main_vbox.add_child(RimvaleUtils.separator())

	# Cemetery — fallen units, revive for gold cost
	_build_cemetery_section(main_vbox)

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

	# Rank — computed from current level
	var rank_hbox = HBoxContainer.new()
	rank_hbox.add_child(RimvaleUtils.label("Rank:", 12, RimvaleColors.TEXT_GRAY))
	rank_hbox.add_child(RimvaleUtils.label(
		GameState._rank_for_level(GameState.player_level), 13, RimvaleColors.GOLD))
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

func _build_save_section(parent: VBoxContainer) -> void:
	parent.add_child(RimvaleUtils.label("Save Game", 14, RimvaleColors.ACCENT))

	var card = RimvaleUtils.card()
	parent.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	# Active slot info
	var slot_id: String = GameState.current_save_slot
	var meta: Dictionary = GameState._read_meta(slot_id)
	var slot_name: String = str(meta.get("display_name", slot_id))
	vbox.add_child(RimvaleUtils.label(
		"Active slot: %s" % slot_name, 12, RimvaleColors.TEXT_WHITE))
	var last_played: String = str(meta.get("last_played", "—"))
	vbox.add_child(RimvaleUtils.label(
		"Last save: %s" % last_played, 11, RimvaleColors.TEXT_GRAY))

	# Manual save button
	var manual_btn = RimvaleUtils.button("💾  Manual Save…", RimvaleColors.GOLD, 56, 13)
	manual_btn.pressed.connect(func(): _show_manual_save_prompt())
	vbox.add_child(manual_btn)

	# Recent saves preview (first 3)
	vbox.add_child(RimvaleUtils.label("Recent saves in this slot:", 11, RimvaleColors.TEXT_GRAY))
	var saves: Array = GameState.list_saves_in_slot(slot_id)
	if saves.is_empty():
		var none_lbl := RimvaleUtils.label("(no save files yet)", 11, RimvaleColors.TEXT_GRAY)
		vbox.add_child(none_lbl)
	else:
		var shown: int = 0
		for sv in saves:
			if shown >= 3: break
			var kind: String = str(sv["kind"])
			var label: String = str(sv["label"])
			var badge: String = "[AUTO] " if kind == "auto" else "[MANUAL] "
			var color: Color = RimvaleColors.TEXT_LIGHT if kind == "auto" else RimvaleColors.GOLD
			vbox.add_child(RimvaleUtils.label(badge + label, 10, color))
			shown += 1


func _show_manual_save_prompt() -> void:
	var overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 90
	get_tree().root.add_child(overlay)

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -200; panel.offset_right = 200
	panel.offset_top = -100; panel.offset_bottom = 100
	var border = StyleBoxFlat.new()
	border.bg_color = Color(0.10, 0.08, 0.16, 1.0)
	border.border_color = RimvaleColors.GOLD
	border.set_border_width_all(2); border.set_corner_radius_all(8)
	border.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", border)
	overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var t = RimvaleUtils.label("Manual Save", 16, RimvaleColors.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(t)

	var input = LineEdit.new()
	input.text = "Save %s" % Time.get_datetime_string_from_system().substr(0, 16)
	input.placeholder_text = "Save name"
	input.custom_minimum_size = Vector2(0, 36)
	vbox.add_child(input)

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var cancel = RimvaleUtils.button("Cancel", RimvaleColors.TEXT_GRAY, 36, 12)
	cancel.custom_minimum_size = Vector2(110, 36)
	cancel.pressed.connect(func(): overlay.queue_free())
	row.add_child(cancel)

	var save_btn = RimvaleUtils.button("Save", RimvaleColors.GOLD, 36, 12)
	save_btn.custom_minimum_size = Vector2(110, 36)
	save_btn.pressed.connect(func():
		var lbl: String = input.text.strip_edges()
		if lbl.is_empty(): lbl = "Manual Save"
		var p: String = GameState.save_manual(lbl)
		overlay.queue_free()
		# Refresh the page so the new save appears in the saves list.
		# Use _refresh() (which clears children first) instead of _ready()
		# directly — _ready() appends a second copy of every section on top
		# of the existing one, producing a doubled / glitched layout.
		_refresh()
	)
	row.add_child(save_btn)

	input.grab_focus()
	input.select_all()


func _build_actions_section(parent: VBoxContainer) -> void:
	parent.add_child(RimvaleUtils.label("Actions", 14, RimvaleColors.ACCENT))

	var actions_vbox = VBoxContainer.new()
	actions_vbox.add_theme_constant_override("separation", 8)

	var rename_action_btn = RimvaleUtils.button("✏️ Edit Profile Name", RimvaleColors.CYAN, 60, 12)
	rename_action_btn.pressed.connect(_on_rename_pressed)
	actions_vbox.add_child(rename_action_btn)

	var manage_btn = RimvaleUtils.button("⚔ Manage Units", RimvaleColors.ACCENT, 60, 12)
	manage_btn.pressed.connect(func():
		get_tree().root.get_child(0).go_to_tab(0)
	)
	actions_vbox.add_child(manage_btn)

	var levelup_btn = RimvaleUtils.button("⬆ Level Up a Unit", RimvaleColors.SUCCESS, 60, 12)
	levelup_btn.pressed.connect(func():
		if GameState.collection.is_empty():
			# No units yet — show the character creation screen instead
			get_tree().root.get_child(0).push_screen(
				"res://scenes/character_creation/character_creation.tscn")
		else:
			# Select a hero to level up — prefer first active team member, else first in collection
			if GameState.selected_hero_handle == -1 or not GameState.collection.has(GameState.selected_hero_handle):
				if not GameState.active_team.is_empty():
					GameState.selected_hero_handle = GameState.active_team[0]
				else:
					GameState.selected_hero_handle = GameState.collection[0]
			get_tree().root.get_child(0).push_screen(
				"res://scenes/level_up/level_up.tscn")
	)
	actions_vbox.add_child(levelup_btn)

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

	parent.add_child(RimvaleUtils.spacer(8))

	# Exit to Main Menu — saves and returns to title screen
	var menu_btn = RimvaleUtils.button("Exit to Main Menu", RimvaleColors.TEXT_LIGHT, 60, 12)
	menu_btn.pressed.connect(func():
		var main_node = get_tree().current_scene
		if main_node and main_node.has_method("exit_to_title"):
			main_node.exit_to_title()
		else:
			GameState.save_game()
			GameState.reset_loaded_flag()
			get_tree().change_scene_to_file("res://scenes/title/title_screen.tscn")
	)
	parent.add_child(menu_btn)

# ── Garage / Vehicles ────────────────────────────────────────────────────────

## Tear down the whole profile and re-run _ready so vehicle / location changes
## propagate to every label.
func _refresh() -> void:
	for c in get_children():
		c.queue_free()
	call_deferred("_ready")

func _build_vehicles_section(parent: VBoxContainer) -> void:
	# One-shot migration: scoop any vehicles sitting in character inventories
	# or attuned magic-item lists into the proper garage + attuned_vehicles
	# state. Idempotent; safe to call every time the garage is shown.
	var migrated: int = RimvaleAPI.engine.sync_vehicles_from_characters()
	parent.add_child(RimvaleUtils.label("🚗 Garage", 18, RimvaleColors.ACCENT))
	if migrated > 0:
		parent.add_child(RimvaleUtils.label(
			"Synced %d vehicle%s from your team's gear into the garage." % [
				migrated, "s" if migrated != 1 else ""],
			11, RimvaleColors.SP_PURPLE))

	# Active-vehicle banner
	if GameState.active_vehicle != "":
		var deployed_panel := PanelContainer.new()
		var dsb := StyleBoxFlat.new()
		dsb.bg_color = Color(0.15, 0.10, 0.04, 1.0)
		dsb.border_color = RimvaleColors.GOLD
		dsb.set_border_width_all(1); dsb.set_corner_radius_all(6); dsb.set_content_margin_all(8)
		deployed_panel.add_theme_stylebox_override("panel", dsb)
		var drow := HBoxContainer.new()
		drow.add_theme_constant_override("separation", 8)
		deployed_panel.add_child(drow)
		drow.add_child(RimvaleUtils.label(
			"⚡ Deployed: %s" % GameState.active_vehicle, 13, RimvaleColors.GOLD))
		var dspc := Control.new(); dspc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		drow.add_child(dspc)
		var recall_btn := RimvaleUtils.button("Recall", RimvaleColors.TEXT_GRAY, 30, 11)
		recall_btn.pressed.connect(func():
			GameState.recall_vehicle()
			_refresh()
		)
		drow.add_child(recall_btn)
		parent.add_child(deployed_panel)

	# Refill-cost banner
	var loc_row := HBoxContainer.new()
	loc_row.add_theme_constant_override("separation", 8)
	parent.add_child(loc_row)
	var loc_lbl := RimvaleUtils.label(
		"Currently in: %s" % ("Metropolitan (cheap refills)" if GameState.party_in_metropolitan else "Outside Metropolitan (expensive refills)"),
		11, RimvaleColors.TEXT_GRAY)
	loc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loc_row.add_child(loc_lbl)
	var toggle_loc := RimvaleUtils.button(
		"Toggle Location" if GameState.debug_mode else "",
		RimvaleColors.TEXT_GRAY, 28, 11)
	toggle_loc.visible = GameState.debug_mode
	toggle_loc.pressed.connect(func():
		GameState.party_in_metropolitan = not GameState.party_in_metropolitan
		_refresh()
	)
	loc_row.add_child(toggle_loc)

	if GameState.owned_vehicles.is_empty():
		parent.add_child(RimvaleUtils.label(
			"No vehicles owned yet. Recover or purchase arcane vehicles to add them to your garage.",
			12, RimvaleColors.TEXT_GRAY))
		# Debug: grant a starter set
		if GameState.debug_mode:
			var grant_btn := RimvaleUtils.button(
				"[DEBUG] Grant Arcane Motorcycle", Color(0.85, 0.55, 0.35), 32, 11)
			grant_btn.pressed.connect(func():
				GameState.acquire_vehicle("Arcane Motorcycle")
				_refresh()
			)
			parent.add_child(grant_btn)
		return

	for vname in GameState.owned_vehicles.keys():
		parent.add_child(_build_vehicle_card(vname))

func _build_vehicle_card(name: String) -> Control:
	var stats: Dictionary = VehicleData.get_stats(name)
	var owned: Dictionary = GameState.owned_vehicles.get(name, {})
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.16, 1.0)
	sb.border_color = Color(0.45, 0.45, 0.60, 0.55)
	sb.set_border_width_all(1); sb.set_corner_radius_all(6); sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Title row
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	vbox.add_child(trow)
	trow.add_child(RimvaleUtils.label(name, 15, RimvaleColors.GOLD))
	var rarity_lbl := RimvaleUtils.label(
		"  " + str(stats.get("rarity", "Common")), 11, RimvaleColors.TEXT_GRAY)
	rarity_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(rarity_lbl)

	# Stats line
	var type_str: String = str(stats.get("type", "land")).capitalize()
	var paved_lbl: String = "%d mph" % int(stats.get("speed_paved", 0))
	var unpaved_lbl: String = "%d mph" % int(stats.get("speed_unpaved", 0))
	var stats_text: String = "%s · %d passenger%s · %s / %s · HP %d/%d" % [
		type_str,
		int(stats.get("capacity", 1)), "s" if int(stats.get("capacity", 1)) > 1 else "",
		paved_lbl, unpaved_lbl,
		int(owned.get("hp_current", stats.get("hp", 0))), int(stats.get("hp", 0)),
	]
	vbox.add_child(RimvaleUtils.label(stats_text, 11, RimvaleColors.TEXT_GRAY))

	# Spark Tank bar
	var st_max: int = int(stats.get("st_max", 1))
	var st_now: int = int(owned.get("st_current", 0))
	var st_row := HBoxContainer.new()
	st_row.add_theme_constant_override("separation", 8)
	vbox.add_child(st_row)
	st_row.add_child(RimvaleUtils.label("⚡ Spark Tanks: %d/%d" % [st_now, st_max], 12, RimvaleColors.SP_PURPLE))
	var st_spc := Control.new(); st_spc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st_row.add_child(st_spc)
	var refill_cost: int = int(stats.get(
		"sp_refill_in_metro" if GameState.party_in_metropolitan else "sp_refill_outside",
		0))
	var name_cap: String = name
	var refill_btn := RimvaleUtils.button(
		"Refill (%d SP)" % refill_cost,
		RimvaleColors.SP_PURPLE if st_now < st_max else RimvaleColors.TEXT_GRAY, 32, 11)
	refill_btn.disabled = (st_now >= st_max)
	refill_btn.pressed.connect(func():
		var err: String = GameState.refill_vehicle_st(name_cap)
		if err != "":
			_show_notice(err)
		_refresh()
	)
	st_row.add_child(refill_btn)

	# Deploy / Recall row
	var deploy_row := HBoxContainer.new()
	deploy_row.add_theme_constant_override("separation", 8)
	vbox.add_child(deploy_row)
	var hp_now: int = int(owned.get("hp_current", 0))
	var disabled: bool = hp_now <= 0
	var is_active: bool = (GameState.active_vehicle == name)
	var status_lbl: String = ""
	if disabled: status_lbl = "🔧 Disabled — repair before deploying."
	elif is_active: status_lbl = "✅ Currently deployed."
	else: status_lbl = "Available to deploy."
	var status := RimvaleUtils.label(status_lbl, 11,
		Color(0.95, 0.45, 0.45) if disabled else RimvaleColors.TEXT_GRAY)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deploy_row.add_child(status)
	if is_active:
		var rcl_btn := RimvaleUtils.button("Recall", RimvaleColors.TEXT_GRAY, 32, 11)
		rcl_btn.pressed.connect(func():
			GameState.recall_vehicle(); _refresh()
		)
		deploy_row.add_child(rcl_btn)
	else:
		var deploy_btn := RimvaleUtils.button("Deploy", RimvaleColors.GOLD, 32, 11)
		deploy_btn.disabled = disabled
		deploy_btn.pressed.connect(func():
			var err: String = GameState.deploy_vehicle(name_cap)
			if err != "": _show_notice(err)
			_refresh()
		)
		deploy_row.add_child(deploy_btn)

	# Special abilities — wrapped multiline
	var spec_lbl := RimvaleUtils.label(
		"Special: " + str(stats.get("special", "—")),
		11, RimvaleColors.TEXT_LIGHT)
	spec_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(spec_lbl)
	return card

func _build_cemetery_section(parent: VBoxContainer) -> void:
	parent.add_child(RimvaleUtils.label("⚰  Cemetery", 14, RimvaleColors.ACCENT))
	if GameState.cemetery.is_empty():
		parent.add_child(RimvaleUtils.label(
			"No fallen units. (Lost characters appear here and can be revived for gold.)",
			11, RimvaleColors.TEXT_GRAY))
		return
	parent.add_child(RimvaleUtils.label(
		"%d unit%s buried. Revive cost: 10,000 base + 1,000 per level." % [
			GameState.cemetery.size(),
			"s" if GameState.cemetery.size() != 1 else ""],
		11, RimvaleColors.TEXT_GRAY))
	for i in range(GameState.cemetery.size()):
		parent.add_child(_build_grave_card(i))

func _build_grave_card(grave_idx: int) -> Control:
	var grave: Dictionary = GameState.cemetery[grave_idx]
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.13, 1.0)
	sb.border_color = Color(0.45, 0.35, 0.45, 0.55)
	sb.set_border_width_all(1); sb.set_corner_radius_all(6); sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var name_str: String = str(grave.get("name", "Unknown"))
	var lineage: String = str(grave.get("lineage", "Human"))
	var lvl: int = int(grave.get("level", 1))
	var age: int = int(grave.get("age_at_death", 0))
	var cause: String = str(grave.get("cause", "unknown"))
	var day: int = int(grave.get("day_of_death", 0))
	var needs_ext: bool = GameState.grave_needs_extension(grave_idx)

	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	vbox.add_child(trow)
	trow.add_child(RimvaleUtils.label("%s   (Lv %d)" % [name_str, lvl], 14, RimvaleColors.GOLD))
	var spc := Control.new(); spc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(spc)

	vbox.add_child(RimvaleUtils.label(
		"%s · died age %d · cause: %s · day %d" % [lineage, age, cause, day],
		11, RimvaleColors.TEXT_GRAY))

	# Old-age deaths require extension. Show a slider 1..N, where N is the
	# number of years that wouldn't drop max_hp to ≤ 0. Killed-in-action
	# graves use a simple revive button at the base cost.
	var captured_idx: int = grave_idx
	var captured_name: String = name_str

	if needs_ext:
		# Show extension picker.
		# Recover stored max_hp from the serialized character (best effort).
		# If we can't parse it, default to 50 — player will see the cap dynamically.
		var grave_max_hp: int = 50
		var serialized: String = str(grave.get("serialized", ""))
		var json := JSON.new()
		if serialized != "" and json.parse(serialized) == OK:
			var data = json.data
			if data is Dictionary:
				grave_max_hp = int(data.get("max_hp", grave_max_hp))
		var max_extend: int = maxi(1, grave_max_hp - 1)   # at least 1, at most max_hp-1

		vbox.add_child(RimvaleUtils.label(
			"⏳ Old-age death — lifespan must be extended.", 11,
			Color(0.85, 0.55, 0.35)))
		vbox.add_child(RimvaleUtils.label(
			"Each year extended costs 10,000g and removes 1 max HP " +
			"(current max %d → drops to 0 = permadead)." % grave_max_hp,
			10, RimvaleColors.TEXT_DIM))

		var ext_row := HBoxContainer.new()
		ext_row.add_theme_constant_override("separation", 8)
		vbox.add_child(ext_row)
		ext_row.add_child(RimvaleUtils.label(
			"Extend years:", 11, RimvaleColors.TEXT_GRAY))
		var slider := HSlider.new()
		slider.min_value = 1
		slider.max_value = max_extend
		slider.step = 1
		slider.value = 1
		slider.custom_minimum_size = Vector2(160, 0)
		ext_row.add_child(slider)
		var ext_lbl := RimvaleUtils.label("1", 11, RimvaleColors.GOLD)
		ext_lbl.custom_minimum_size = Vector2(28, 0)
		ext_row.add_child(ext_lbl)

		var brow := HBoxContainer.new()
		brow.add_theme_constant_override("separation", 8)
		vbox.add_child(brow)
		var status_lbl := RimvaleUtils.label("", 11, RimvaleColors.GOLD)
		status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		brow.add_child(status_lbl)

		var revive_btn := RimvaleUtils.button("⚱ Revive", RimvaleColors.GOLD, 32, 11)
		brow.add_child(revive_btn)

		var refresh_status := func():
			var ext_y: int = int(slider.value)
			var total_cost: int = GameState.revive_total_cost(captured_idx, ext_y)
			var resulting_hp: int = grave_max_hp - ext_y
			ext_lbl.text = str(ext_y)
			var can_afford: bool = GameState.gold >= total_cost
			var s: String = "Cost: %dg · Max HP after: %d" % [total_cost, resulting_hp]
			if not can_afford:
				s += "  (need %d more)" % (total_cost - GameState.gold)
			status_lbl.text = s
			status_lbl.add_theme_color_override("font_color",
				RimvaleColors.GOLD if can_afford else Color(0.95, 0.45, 0.45))
			revive_btn.disabled = not can_afford
		slider.value_changed.connect(func(_v): refresh_status.call())
		refresh_status.call()

		revive_btn.pressed.connect(func():
			var err: String = GameState.revive_from_cemetery(
				captured_idx, int(slider.value))
			if err != "":
				_show_notice(err)
			else:
				_show_notice("%s has been revived!" % captured_name)
			_refresh()
		)
	else:
		# Killed-in-action: simple revive at base cost.
		var cost: int = GameState.cemetery_revive_cost(lvl)
		var can_afford: bool = GameState.gold >= cost
		var brow := HBoxContainer.new()
		brow.add_theme_constant_override("separation", 8)
		vbox.add_child(brow)
		var status_text: String = "Cost: %d gold" % cost
		if not can_afford:
			status_text += "  (need %d more)" % (cost - GameState.gold)
		var status_lbl := RimvaleUtils.label(status_text, 11,
			RimvaleColors.GOLD if can_afford else Color(0.95, 0.45, 0.45))
		status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		brow.add_child(status_lbl)
		var btn_color: Color = RimvaleColors.GOLD if can_afford else RimvaleColors.TEXT_GRAY
		var revive_btn := RimvaleUtils.button("⚱ Revive", btn_color, 32, 11)
		revive_btn.disabled = not can_afford
		revive_btn.pressed.connect(func():
			var err: String = GameState.revive_from_cemetery(captured_idx, 0)
			if err != "":
				_show_notice(err)
			else:
				_show_notice("%s has been revived!" % captured_name)
			_refresh()
		)
		brow.add_child(revive_btn)

	return card

# ── Restored from HEAD: helpers needed by profile-page logic ─────────────

func _show_daily_bonus_toast() -> void:
	var toast := PanelContainer.new()
	toast.anchor_left   = 0.5
	toast.anchor_right  = 0.5
	toast.anchor_top    = 0.0
	toast.anchor_bottom = 0.0
	toast.offset_left   = -160
	toast.offset_right  = 160
	toast.offset_top    = 12
	toast.offset_bottom = 72
	toast.z_index       = 100

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.30, 0.08, 0.95)
	sb.border_color = RimvaleColors.SUCCESS
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left   = 16
	sb.content_margin_right  = 16
	sb.content_margin_top    = 8
	sb.content_margin_bottom = 8
	toast.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	toast.add_child(vb)
	vb.add_child(RimvaleUtils.label("✦ Daily Login Bonus!", 13, RimvaleColors.SUCCESS))
	vb.add_child(RimvaleUtils.label("+10 Tokens awarded", 11, RimvaleColors.TEXT_WHITE))

	add_child(toast)

	# Auto-dismiss after 3 seconds
	var t := get_tree().create_timer(3.0)
	t.timeout.connect(func():
		if is_instance_valid(toast):
			toast.queue_free()
		# Refresh token display after bonus
		_refresh_resource_labels()
	)

func _build_devtools_section(parent: VBoxContainer) -> void:
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	var hdr := RimvaleUtils.label("🛠  Dev Tools", 14, RimvaleColors.WARNING)
	header_row.add_child(hdr)
	var sub := RimvaleUtils.label("add resources for testing", 11, RimvaleColors.TEXT_DIM)
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_row.add_child(sub)
	parent.add_child(header_row)

	# Card background
	var card := PanelContainer.new()
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.10, 0.09, 0.04, 0.95)
	sbox.border_color = Color(RimvaleColors.WARNING, 0.35)
	sbox.set_border_width_all(1)
	sbox.set_corner_radius_all(6)
	sbox.content_margin_left   = 12
	sbox.content_margin_right  = 12
	sbox.content_margin_top    = 10
	sbox.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sbox)
	parent.add_child(card)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	card.add_child(rows)

	# Debug mode toggle
	var debug_row := HBoxContainer.new()
	debug_row.add_theme_constant_override("separation", 8)
	var debug_lbl := RimvaleUtils.label("🐛 Debug Mode", 12, RimvaleColors.DANGER)
	debug_lbl.custom_minimum_size = Vector2(100, 0)
	debug_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	debug_row.add_child(debug_lbl)
	var debug_check := CheckButton.new()
	debug_check.button_pressed = GameState.debug_mode
	debug_check.add_theme_font_size_override("font_size", 13)
	debug_check.add_theme_color_override("font_color", RimvaleColors.TEXT_WHITE)
	debug_check.text = "ON" if GameState.debug_mode else "OFF"
	debug_check.toggled.connect(func(on: bool):
		GameState.debug_mode = on
		debug_check.text = "ON" if on else "OFF"
		GameState.save_game()
		# Re-render the whole page so the cheat rows show/hide.
		_refresh()
	)
	debug_row.add_child(debug_check)
	var debug_hint := RimvaleUtils.label(
		"Enables auto-complete on story missions", 10, RimvaleColors.TEXT_DIM)
	debug_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	debug_row.add_child(debug_hint)
	rows.add_child(debug_row)

	# Cheat rows below only render in debug mode — toggle above flips them.
	if not GameState.debug_mode:
		return

	rows.add_child(RimvaleUtils.separator())

	# Gold row
	rows.add_child(_devtools_row(
		"⚜ Gold",  RimvaleColors.GOLD,
		[["+ 500", 500], ["+ 2 000", 2000], ["+ 10 000", 10000]],
		func(amt: int) -> void:
			GameState.earn_gold(amt)
			_refresh_resource_labels()
			GameState.save_game()
	))

	# Tokens row
	rows.add_child(_devtools_row(
		"◈ Tokens", RimvaleColors.CYAN,
		[["+ 1", 1], ["+ 5", 5], ["+ 20", 20]],
		func(amt: int) -> void:
			GameState.tokens += amt
			_refresh_resource_labels()
			GameState.save_game()
	))

	# Remnant Fragments row
	rows.add_child(_devtools_row(
		"⬡ RF",    RimvaleColors.ORANGE,
		[["+ 100", 100], ["+ 500", 500], ["+ 1 000", 1000]],
		func(amt: int) -> void:
			GameState.remnant_fragments += amt
			_refresh_resource_labels()
			GameState.save_game()
	))

	# ── Time fast-forward ─────────────────────────────────────────────────
	# advance_days() is the single time-of-day primitive — it ticks
	# game_day, ages every character in the collection, and routes any
	# natural deaths into the cemetery. So +1 day, +7, +30, +365 here all
	# fire the same aging + reputation propagation passes the mission /
	# travel paths trigger normally; this is just a debug shortcut.
	rows.add_child(RimvaleUtils.separator())
	var time_lbl := RimvaleUtils.label(
		"🕐 Game Day: %d  (Year %d, Day %d)" % [
			GameState.game_day,
			(GameState.game_day - 1) / 365 + 1,
			((GameState.game_day - 1) % 365) + 1],
		12, RimvaleColors.CYAN)
	rows.add_child(time_lbl)
	rows.add_child(_devtools_row(
		"⏱ Time", RimvaleColors.CYAN,
		[["+ 1 Day", 1], ["+ 1 Week", 7], ["+ 1 Month", 30], ["+ 1 Year", 365]],
		func(days: int) -> void:
			var deaths: Array = GameState.advance_days(days)
			GameState.save_game()
			if deaths.size() > 0:
				_show_notice("Time skipped %d day(s). %d unit(s) died of old age: %s" % [
					days, deaths.size(), ", ".join(deaths)])
			else:
				_show_notice("Time skipped %d day(s)." % days)
			_refresh()   # full page refresh so cemetery / age fields update
	))

## Build one labelled row of add-amount buttons.

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

func _on_wipe_pressed() -> void:
	if wipe_confirm_dialog_open:
		return

	wipe_confirm_dialog_open = true

	# Full-screen dialog layer
	var dialog = Control.new()
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.name = "wipe_dialog"
	dialog.z_index = 100
	add_child(dialog)

	# Dark overlay blocks clicks behind
	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	dialog.add_child(overlay)

	# Solid dialog box centred on screen
	var box = ColorRect.new()
	box.color = Color(0.08, 0.08, 0.18, 1.0)
	box.anchor_left = 0.15
	box.anchor_top = 0.25
	box.anchor_right = 0.85
	box.anchor_bottom = 0.65
	box.offset_left = 0
	box.offset_top = 0
	box.offset_right = 0
	box.offset_bottom = 0
	dialog.add_child(box)

	# Border around the box
	var border = ColorRect.new()
	border.color = RimvaleColors.DANGER
	border.anchor_left = 0.15
	border.anchor_top = 0.25
	border.anchor_right = 0.85
	border.anchor_bottom = 0.65
	border.offset_left = -2
	border.offset_top = -2
	border.offset_right = 2
	border.offset_bottom = 2
	border.z_index = -1
	dialog.add_child(border)

	# Content container inside the box
	var content = VBoxContainer.new()
	content.anchor_left = 0.15
	content.anchor_top = 0.25
	content.anchor_right = 0.85
	content.anchor_bottom = 0.65
	content.offset_left = 24
	content.offset_top = 24
	content.offset_right = -24
	content.offset_bottom = -24
	content.add_theme_constant_override("separation", 20)
	dialog.add_child(content)

	# Warning icon + title
	var title_lbl = RimvaleUtils.label("⚠  Wipe All Data?", 18, RimvaleColors.DANGER)
	content.add_child(title_lbl)

	# Description
	var desc_lbl = RimvaleUtils.label(
		"This will permanently delete ALL progress:\n" +
		"• Gold, Tokens, and Remnant Fragments\n" +
		"• All units except two fresh starters\n" +
		"• Mission progress and earned badges\n" +
		"• Base upgrades and facilities\n" +
		"• Visited regions and quest state\n\n" +
		"This cannot be undone.", 12, RimvaleColors.TEXT_WHITE)
	content.add_child(desc_lbl)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	content.add_child(spacer)

	# Buttons row
	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.add_theme_constant_override("separation", 16)
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var confirm_wipe_btn = RimvaleUtils.button("Wipe Everything", RimvaleColors.DANGER, 60, 14)
	confirm_wipe_btn.pressed.connect(func():
		GameState.wipe_all()
		_close_wipe_dialog(dialog)
		# Navigate back to the Units tab so the game feels like a fresh start
		var main_node = get_tree().current_scene
		if main_node and main_node.has_method("go_to_tab"):
			main_node.go_to_tab(0)
	)
	buttons_hbox.add_child(confirm_wipe_btn)

	var cancel_wipe_btn = RimvaleUtils.button("Cancel", RimvaleColors.TEXT_GRAY, 60, 14)
	cancel_wipe_btn.pressed.connect(func(): _close_wipe_dialog(dialog))
	buttons_hbox.add_child(cancel_wipe_btn)

	content.add_child(buttons_hbox)


## Show a transient toast at the top of the profile page. Auto-dismisses.
func _show_notice(message: String) -> void:
	var toast := Label.new()
	toast.text = message
	toast.add_theme_color_override("font_color", RimvaleColors.GOLD)
	toast.add_theme_font_size_override("font_size", 13)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toast.offset_top = 60
	toast.offset_bottom = 90
	toast.z_index = 100
	add_child(toast)
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		if is_instance_valid(toast):
			toast.queue_free()
	)

# ── Restored from HEAD: helpers used by other helpers ────────────────────

func _refresh_resource_labels() -> void:
	var g := find_child("gold_display",   true, false)
	if g is Label: (g as Label).text = str(GameState.gold)
	var t := find_child("tokens_display", true, false)
	if t is Label: (t as Label).text = str(GameState.tokens)
	var rf := find_child("rf_display",    true, false)
	if rf is Label: (rf as Label).text = str(GameState.remnant_fragments)

func _devtools_row(label_txt: String, col: Color,
		amounts: Array, callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var lbl := RimvaleUtils.label(label_txt, 12, col)
	lbl.custom_minimum_size = Vector2(80, 0)
	lbl.vertical_alignment  = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)

	for pair in amounts:   # pair = [label_string, int_amount]
		var btn_label: String = str(pair[0])
		var btn_amount: int   = int(pair[1])
		var btn := Button.new()
		btn.text = btn_label
		btn.custom_minimum_size = Vector2(80, 36)
		btn.add_theme_font_size_override("font_size", 13)
		# Normal style
		var ns := StyleBoxFlat.new()
		ns.bg_color = Color(col, 0.18)
		ns.border_color = Color(col, 0.55)
		ns.set_border_width_all(1)
		ns.set_corner_radius_all(5)
		ns.content_margin_left   = 6
		ns.content_margin_right  = 6
		ns.content_margin_top    = 4
		ns.content_margin_bottom = 4
		btn.add_theme_stylebox_override("normal", ns)
		# Hover
		var hs := ns.duplicate() as StyleBoxFlat
		hs.bg_color = Color(col, 0.32)
		btn.add_theme_stylebox_override("hover", hs)
		# Pressed
		var ps := ns.duplicate() as StyleBoxFlat
		ps.bg_color = Color(col, 0.45)
		btn.add_theme_stylebox_override("pressed", ps)
		btn.add_theme_color_override("font_color", col)
		btn.pressed.connect(func(): callback.call(btn_amount))
		row.add_child(btn)

	return row

## Update the resource display labels after a cheat is applied.

func _update_name_display() -> void:
	if _player_name_lbl:
		_player_name_lbl.text = GameState.player_name

func _close_rename_dialog(dialog: Control) -> void:
	dialog.queue_free()
	rename_dialog_open = false

func _close_wipe_dialog(dialog: Control) -> void:
	dialog.queue_free()
	wipe_confirm_dialog_open = false

# ── Daily Login Toast ─────────────────────────────────────────────────────────
 