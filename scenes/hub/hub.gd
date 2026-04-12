## hub.gd
## Party Hub — manage your party, view character sheets, start combat.

extends Control

var _e: RimvaleEngine

# UI references
var _party_container: VBoxContainer
var _detail_panel: VBoxContainer
var _selected_handle: int = -1

# ── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_e = RimvaleAPI.engine
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.10, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Root layout: header + main content
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	# ── Header bar ──────────────────────────────────────────────
	var header := _make_header()
	root_vbox.add_child(header)

	# ── Main content: two columns ────────────────────────────────
	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 0)
	root_vbox.add_child(hbox)

	# Left: party list
	hbox.add_child(_make_party_panel())

	# Right: character detail
	hbox.add_child(_make_detail_panel())

	# Populate
	_refresh_party_list()

# ── Header ───────────────────────────────────────────────────────────────────

func _make_header() -> Control:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.11, 0.16, 1.0)
	bg.custom_minimum_size = Vector2(0, 70)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 20)
	bg.add_child(hbox)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	bg.add_child(margin)

	var inner := HBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_child(inner)

	var title := Label.new()
	title.text = "RIMVALE  —  Party Hub"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.80, 0.30, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(title)

	var menu_btn := Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(130, 0)
	menu_btn.add_theme_font_size_override("font_size", 16)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn"))
	inner.add_child(menu_btn)

	return bg

# ── Party panel (left column) ────────────────────────────────────────────────

func _make_party_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Title + add button
	var row := HBoxContainer.new()
	vbox.add_child(row)

	var lbl := Label.new()
	lbl.text = "PARTY"
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.30, 1.0))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var add_btn := Button.new()
	add_btn.text = "+ Add"
	add_btn.custom_minimum_size = Vector2(80, 36)
	add_btn.add_theme_font_size_override("font_size", 14)
	add_btn.pressed.connect(_on_add_character)
	row.add_child(add_btn)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Character list (rebuilt on refresh)
	_party_container = VBoxContainer.new()
	_party_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_party_container)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Combat button
	var combat_btn := Button.new()
	combat_btn.text = "⚔  BEGIN COMBAT"
	combat_btn.custom_minimum_size = Vector2(0, 64)
	combat_btn.add_theme_font_size_override("font_size", 20)
	combat_btn.add_theme_color_override("font_color", Color(0.95, 0.50, 0.30, 1.0))
	combat_btn.pressed.connect(_on_begin_combat)
	vbox.add_child(combat_btn)

	return panel

# ── Detail panel (right column) ──────────────────────────────────────────────

func _make_detail_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	_detail_panel = VBoxContainer.new()
	_detail_panel.add_theme_constant_override("separation", 14)
	margin.add_child(_detail_panel)

	_show_detail_placeholder()
	return panel

func _show_detail_placeholder() -> void:
	_clear_detail()
	var lbl := Label.new()
	lbl.text = "← Select a character to view their sheet"
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.42, 1.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(lbl)

func _clear_detail() -> void:
	for child in _detail_panel.get_children():
		child.queue_free()

# ── Party list population ─────────────────────────────────────────────────────

func _refresh_party_list() -> void:
	for child in _party_container.get_children():
		child.queue_free()

	if GameState.party.is_empty():
		var lbl := Label.new()
		lbl.text = "No characters yet.\nClick '+ Add' to create one."
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
		_party_container.add_child(lbl)
		return

	for handle in GameState.party:
		_party_container.add_child(_make_character_card(handle))

# ── Character card ────────────────────────────────────────────────────────────

func _make_character_card(handle: int) -> Button:
	var name_ := _e.get_character_name(handle)
	var lineage_ := _e.get_character_lineage_name(handle)
	var level_ := _e.get_character_level(handle)
	var hp_ := _e.get_character_hp(handle)
	var max_hp_ := _e.get_character_max_hp(handle)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 72)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	# Build the label text
	var txt := "[b]%s[/b]  Lv.%d\n%s   HP: %d / %d" % [name_, level_, lineage_, hp_, max_hp_]

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.text = txt
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.add_theme_font_size_override("normal_font_size", 16)
	rtl.add_theme_font_size_override("bold_font_size", 18)
	rtl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(rtl)

	btn.pressed.connect(func(): _on_select_character(handle))
	return btn

# ── Character detail sheet ────────────────────────────────────────────────────

func _on_select_character(handle: int) -> void:
	_selected_handle = handle
	_clear_detail()

	var name_ := _e.get_character_name(handle)
	var lineage_ := _e.get_character_lineage_name(handle)
	var level_ := _e.get_character_level(handle)
	var xp_ := _e.get_character_xp(handle)
	var xp_req_ := _e.get_character_xp_required(handle)
	var hp_ := _e.get_character_hp(handle)
	var max_hp_ := _e.get_character_max_hp(handle)
	var ap_ := _e.get_character_ap(handle)
	var max_ap_ := _e.get_character_max_ap(handle)
	var sp_ := _e.get_character_sp(handle)
	var max_sp_ := _e.get_character_max_sp(handle)
	var ac_ := _e.get_character_ac(handle)
	var spd_ := _e.get_character_movement_speed(handle)
	var gold_ := _e.get_inventory_gold(handle)

	# Name header
	var name_lbl := Label.new()
	name_lbl.text = name_
	name_lbl.add_theme_font_size_override("font_size", 32)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.30, 1.0))
	_detail_panel.add_child(name_lbl)

	var sub := Label.new()
	sub.text = "%s  •  Level %d  •  %d / %d XP" % [lineage_, level_, xp_, xp_req_]
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.65, 0.65, 0.60, 1.0))
	_detail_panel.add_child(sub)

	_detail_panel.add_child(HSeparator.new())

	# Stats grid
	var stats_grid := GridContainer.new()
	stats_grid.columns = 3
	stats_grid.add_theme_constant_override("h_separation", 24)
	stats_grid.add_theme_constant_override("v_separation", 10)
	_detail_panel.add_child(stats_grid)

	_stat_cell(stats_grid, "HP",  "%d / %d" % [hp_, max_hp_],  Color(0.85, 0.30, 0.30, 1.0))
	_stat_cell(stats_grid, "AP",  "%d / %d" % [ap_, max_ap_],  Color(0.30, 0.55, 0.90, 1.0))
	_stat_cell(stats_grid, "SP",  "%d / %d" % [sp_, max_sp_],  Color(0.50, 0.85, 0.50, 1.0))
	_stat_cell(stats_grid, "AC",  str(ac_),                    Color(0.85, 0.75, 0.40, 1.0))
	_stat_cell(stats_grid, "SPD", str(spd_),                   Color(0.70, 0.70, 0.70, 1.0))
	_stat_cell(stats_grid, "Gold", str(gold_),                 Color(0.95, 0.80, 0.30, 1.0))

	_detail_panel.add_child(HSeparator.new())

	# Feats & Spells header
	var feats_lbl := Label.new()
	feats_lbl.text = "FEATS"
	feats_lbl.add_theme_font_size_override("font_size", 15)
	feats_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.55, 1.0))
	_detail_panel.add_child(feats_lbl)

	var feats_tree := _e.get_feat_trees_by_character(handle)
	var feat_text := ", ".join(Array(feats_tree)) if feats_tree.size() > 0 else "(none)"
	var feats_val := Label.new()
	feats_val.text = feat_text
	feats_val.add_theme_font_size_override("font_size", 15)
	feats_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_panel.add_child(feats_val)

	var spells_lbl := Label.new()
	spells_lbl.text = "LEARNED SPELLS"
	spells_lbl.add_theme_font_size_override("font_size", 15)
	spells_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.55, 1.0))
	_detail_panel.add_child(spells_lbl)

	var learned := _e.get_learned_spells(handle)
	var spell_text := ", ".join(Array(learned)) if learned.size() > 0 else "(none)"
	var spells_val := Label.new()
	spells_val.text = spell_text
	spells_val.add_theme_font_size_override("font_size", 15)
	spells_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_panel.add_child(spells_val)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(spacer)

	# Remove from party button
	var remove_btn := Button.new()
	remove_btn.text = "Remove from Party"
	remove_btn.custom_minimum_size = Vector2(0, 48)
	remove_btn.add_theme_font_size_override("font_size", 15)
	remove_btn.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35, 1.0))
	remove_btn.pressed.connect(func(): _on_remove_character(handle))
	_detail_panel.add_child(remove_btn)

func _stat_cell(grid: GridContainer, label_txt: String, value_txt: String, col: Color) -> void:
	var box := VBoxContainer.new()
	grid.add_child(box)

	var lbl := Label.new()
	lbl.text = label_txt
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1.0))
	box.add_child(lbl)

	var val := Label.new()
	val.text = value_txt
	val.add_theme_font_size_override("font_size", 20)
	val.add_theme_color_override("font_color", col)
	box.add_child(val)

# ── Actions ───────────────────────────────────────────────────────────────────

func _on_add_character() -> void:
	if GameState.party_is_full():
		# Flash a warning in the detail panel
		_clear_detail()
		var lbl := Label.new()
		lbl.text = "Party is full! (max %d)" % GameState.MAX_PARTY_SIZE
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4, 1.0))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_detail_panel.add_child(lbl)
		return
	get_tree().change_scene_to_file("res://scenes/character_creation/character_creation.tscn")

func _on_remove_character(handle: int) -> void:
	_e.destroy_character(handle)
	GameState.party.erase(handle)
	_selected_handle = -1
	_show_detail_placeholder()
	_refresh_party_list()

func _on_begin_combat() -> void:
	if GameState.party.is_empty():
		_clear_detail()
		var lbl := Label.new()
		lbl.text = "Add at least one character first!"
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4, 1.0))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_detail_panel.add_child(lbl)
		return
	get_tree().change_scene_to_file("res://scenes/combat/combat.tscn")
