extends Control

var current_tab: int = 0
var _content_area: Control
var selected_lineage: String = ""
var selected_feat_category: String = ""
var selected_feat_tree: String = ""
var selected_feat: String = ""
var selected_region: String = ""
var selected_item_type: String = "magic"
var selected_spell_domain: String = "All"

# Stored panel references — avoids all get_node() path lookups
var _lineage_details_panel: VBoxContainer
var _feat_trees_list: VBoxContainer
var _feats_list: VBoxContainer
var _feat_details_panel: VBoxContainer
var _items_list: VBoxContainer
var _item_detail_panel: VBoxContainer
var _region_details_panel: VBoxContainer
var _spells_list: VBoxContainer
var _spell_detail_panel: VBoxContainer
var _spell_domain_chips: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RimvaleUtils.add_bg(self, RimvaleColors.BG_DARK)

	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 0)
	add_child(main_vbox)

	var tab_container = HBoxContainer.new()
	tab_container.custom_minimum_size.y = 60
	main_vbox.add_child(tab_container)

	var tabs = ["Lineages", "Feats", "Items", "Geography", "Magic"]
	for i in range(tabs.size()):
		var tab_btn = RimvaleUtils.button(tabs[i], RimvaleColors.ACCENT, 50, 14)
		tab_btn.pressed.connect(_on_tab_selected.bindv([i]))
		tab_container.add_child(tab_btn)

	RimvaleUtils.add_bg(tab_container, RimvaleColors.BG_CARD_DARK)

	_content_area = Control.new()
	_content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_child(_content_area)

	_build_lineages_tab(_content_area)
	_build_feats_tab(_content_area)
	_build_items_tab(_content_area)
	_build_geography_tab(_content_area)
	_build_magic_tab(_content_area)

	_on_tab_selected(0)

func _on_tab_selected(idx: int) -> void:
	current_tab = idx
	for child in _content_area.get_children():
		child.visible = false
	if idx < _content_area.get_child_count():
		_content_area.get_child(idx).visible = true

# ── Lineages ─────────────────────────────────────────────────────────────────

func _build_lineages_tab(parent: Control) -> void:
	var panel = Control.new()
	panel.anchor_right = 1.0; panel.anchor_bottom = 1.0
	panel.visible = false
	parent.add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.anchor_right = 1.0; hbox.anchor_bottom = 1.0
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Left: lineage list
	var left_scroll = ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.custom_minimum_size.x = 200
	var lineages_list = VBoxContainer.new()
	lineages_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lineages: PackedStringArray = RimvaleAPI.engine.get_all_lineages()
	for lineage in lineages:
		var lname: String = str(lineage)
		var btn = RimvaleUtils.button(lname, RimvaleColors.CYAN, 50, 12)
		btn.pressed.connect(_on_lineage_selected.bindv([lname]))
		lineages_list.add_child(btn)

	left_scroll.add_child(lineages_list)
	hbox.add_child(left_scroll)

	# Right: details (stored reference)
	_lineage_details_panel = VBoxContainer.new()
	_lineage_details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lineage_details_panel.add_theme_constant_override("separation", 8)
	_lineage_details_panel.add_child(RimvaleUtils.label("Select a lineage", 14, RimvaleColors.TEXT_GRAY))
	hbox.add_child(_lineage_details_panel)

func _on_lineage_selected(lineage: String) -> void:
	selected_lineage = lineage
	for child in _lineage_details_panel.get_children():
		child.queue_free()

	_lineage_details_panel.add_child(RimvaleUtils.label(lineage, 16, RimvaleColors.ACCENT))
	_lineage_details_panel.add_child(RimvaleUtils.separator())

	var raw: PackedStringArray = RimvaleAPI.engine.get_lineage_details(lineage)
	# raw = [type, speed, traits_pipe_separated, languages, description, culture]
	if raw.size() < 6:
		_lineage_details_panel.add_child(RimvaleUtils.label("No data available.", 12, RimvaleColors.TEXT_GRAY))
		return

	# Type + Speed row
	var type_lbl := RimvaleUtils.label(raw[0] + "  •  Speed " + raw[1], 12, RimvaleColors.TEXT_GRAY)
	_lineage_details_panel.add_child(type_lbl)

	# Languages
	var lang_lbl := RimvaleUtils.label("Languages: " + raw[3], 12, RimvaleColors.TEXT_GRAY)
	_lineage_details_panel.add_child(lang_lbl)

	_lineage_details_panel.add_child(RimvaleUtils.separator())

	# Description (word-wrapped)
	if raw[4] != "":
		var desc_lbl := Label.new()
		desc_lbl.text = raw[4]
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", RimvaleColors.TEXT_WHITE)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_lineage_details_panel.add_child(desc_lbl)

	_lineage_details_panel.add_child(RimvaleUtils.separator())

	# Traits
	if raw[2] != "":
		_lineage_details_panel.add_child(RimvaleUtils.label("Traits:", 12, RimvaleColors.ACCENT))
		var traits: PackedStringArray = raw[2].split(" | ")
		for trait_txt in traits:
			if trait_txt.strip_edges() == "":
				continue
			var t_lbl := Label.new()
			t_lbl.text = "• " + trait_txt.strip_edges()
			t_lbl.add_theme_font_size_override("font_size", 11)
			t_lbl.add_theme_color_override("font_color", RimvaleColors.TEXT_WHITE)
			t_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_lineage_details_panel.add_child(t_lbl)

	# Culture
	if raw[5] != "":
		_lineage_details_panel.add_child(RimvaleUtils.separator())
		_lineage_details_panel.add_child(RimvaleUtils.label("Culture:", 12, RimvaleColors.ACCENT))
		var cult_lbl := Label.new()
		cult_lbl.text = raw[5]
		cult_lbl.add_theme_font_size_override("font_size", 11)
		cult_lbl.add_theme_color_override("font_color", RimvaleColors.TEXT_GRAY)
		cult_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cult_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_lineage_details_panel.add_child(cult_lbl)

# ── Feats ─────────────────────────────────────────────────────────────────────

func _build_feats_tab(parent: Control) -> void:
	var panel = Control.new()
	panel.anchor_right = 1.0; panel.anchor_bottom = 1.0
	panel.visible = false
	parent.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0; vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Category dropdown
	var cat_hbox = HBoxContainer.new()
	cat_hbox.custom_minimum_size.y = 40
	cat_hbox.add_child(RimvaleUtils.label("Category:", 12, RimvaleColors.TEXT_WHITE))
	var cat_dropdown = OptionButton.new()
	cat_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var categories: PackedStringArray = RimvaleAPI.engine.get_all_feat_categories()
	for cat in categories:
		cat_dropdown.add_item(str(cat))

	cat_dropdown.item_selected.connect(_on_feat_category_selected)
	cat_hbox.add_child(cat_dropdown)
	vbox.add_child(cat_hbox)

	# Three-column content
	var content_hbox = HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 12)

	# Left: feat trees (stored)
	var left_scroll = ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.custom_minimum_size.x = 200
	_feat_trees_list = VBoxContainer.new()
	_feat_trees_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(_feat_trees_list)
	content_hbox.add_child(left_scroll)

	# Middle: feats (stored)
	var mid_scroll = ScrollContainer.new()
	mid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_scroll.custom_minimum_size.x = 200
	_feats_list = VBoxContainer.new()
	_feats_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_scroll.add_child(_feats_list)
	content_hbox.add_child(mid_scroll)

	# Right: details (stored)
	_feat_details_panel = VBoxContainer.new()
	_feat_details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feat_details_panel.add_child(RimvaleUtils.label("Select a feat", 12, RimvaleColors.TEXT_GRAY))
	content_hbox.add_child(_feat_details_panel)

	vbox.add_child(content_hbox)

func _on_feat_category_selected(idx: int) -> void:
	var categories: PackedStringArray = RimvaleAPI.engine.get_all_feat_categories()
	if idx >= categories.size():
		return
	selected_feat_category = str(categories[idx])

	for child in _feat_trees_list.get_children():
		child.queue_free()
	for child in _feats_list.get_children():
		child.queue_free()
	for child in _feat_details_panel.get_children():
		child.queue_free()

	var trees: PackedStringArray = RimvaleAPI.engine.get_feat_trees_by_category(selected_feat_category)
	for tree in trees:
		var tname: String = str(tree)
		var btn = RimvaleUtils.button(tname, RimvaleColors.HP_GREEN, 50, 12)
		btn.pressed.connect(_on_feat_tree_selected.bindv([tname]))
		_feat_trees_list.add_child(btn)

func _on_feat_tree_selected(tree: String) -> void:
	selected_feat_tree = tree
	for child in _feats_list.get_children():
		child.queue_free()

	var feats: PackedStringArray = RimvaleAPI.engine.get_feats_by_tree(tree)
	for feat in feats:
		var fname: String = str(feat)
		var btn = RimvaleUtils.button(fname, RimvaleColors.CYAN, 50, 12)
		btn.pressed.connect(_on_feat_selected.bindv([fname]))
		_feats_list.add_child(btn)

func _on_feat_selected(tier_label: String) -> void:
	selected_feat = tier_label
	for child in _feat_details_panel.get_children():
		child.queue_free()

	# tier_label is "Tier N" — parse tier number and use selected_feat_tree for the feat name
	var tier: int = 1
	var parts: PackedStringArray = tier_label.split(" ")
	if parts.size() >= 2 and parts[0] == "Tier":
		tier = int(parts[1])

	var feat_name: String = selected_feat_tree

	_feat_details_panel.add_child(RimvaleUtils.label(feat_name, 16, RimvaleColors.ACCENT))

	var tier_row = HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 6)
	_feat_details_panel.add_child(tier_row)
	tier_row.add_child(RimvaleUtils.label("Tier %d" % tier, 13, RimvaleColors.GOLD))
	var cat_str: String = str(RimvaleAPI.engine.get_feat_details(feat_name, tier).get(1, "")) \
		if RimvaleAPI.engine.get_feat_details(feat_name, tier).size() > 1 \
		else ""
	if cat_str != "":
		tier_row.add_child(RimvaleUtils.label("· " + cat_str, 11, RimvaleColors.TEXT_DIM))

	_feat_details_panel.add_child(RimvaleUtils.separator())

	var description: String = RimvaleAPI.engine.get_feat_description(feat_name, tier)
	var desc_lbl = RimvaleUtils.label(description if description != "" else "No description available.", 12, RimvaleColors.TEXT_WHITE)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feat_details_panel.add_child(desc_lbl)

	# ── Unlock button ─────────────────────────────────────────────────────────
	# Find selected hero: prefer GameState.selected_hero_handle, fall back to first active.
	var e = RimvaleAPI.engine
	var hero_handle: int = GameState.selected_hero_handle
	if hero_handle == -1:
		var actives := GameState.get_active_handles()
		if not actives.is_empty():
			hero_handle = actives[0]

	if hero_handle != -1:
		var feat_pts: int   = e.get_character_feat_points(hero_handle)
		var cur_tier: int   = e.get_character_feat_tier(hero_handle, feat_name)
		var next_tier: int  = cur_tier + 1
		var hero_name: String = e.get_character_name(hero_handle)
		var can_unlock: bool  = feat_pts > 0 and next_tier <= 4   # max 4 tiers

		_feat_details_panel.add_child(RimvaleUtils.separator())

		# Show current tier & points
		var hero_info := HBoxContainer.new()
		hero_info.add_theme_constant_override("separation", 8)
		hero_info.add_child(RimvaleUtils.label(hero_name, 12, RimvaleColors.ACCENT))
		hero_info.add_child(RimvaleUtils.label("·  %d feat pts" % feat_pts, 12,
			RimvaleColors.GOLD if feat_pts > 0 else RimvaleColors.TEXT_DIM))
		if cur_tier > 0:
			hero_info.add_child(RimvaleUtils.label("·  Tier %d owned" % cur_tier, 12, RimvaleColors.HP_GREEN))
		_feat_details_panel.add_child(hero_info)

		var cap_feat: String = feat_name
		var cap_tier: int    = next_tier
		var cap_hero: int    = hero_handle
		var unlock_btn := RimvaleUtils.button(
			"Unlock Tier %d" % next_tier if can_unlock else "No Feat Points",
			RimvaleColors.SUCCESS if can_unlock else RimvaleColors.TEXT_DIM, 44, 13)
		unlock_btn.disabled = not can_unlock
		unlock_btn.pressed.connect(func():
			if e.spend_feat_point(cap_hero, cap_feat, cap_tier):
				# Refresh details panel to show new tier
				_on_feat_selected(selected_feat)
		)
		_feat_details_panel.add_child(unlock_btn)

# ── Items ─────────────────────────────────────────────────────────────────────

func _build_items_tab(parent: Control) -> void:
	var panel = Control.new()
	panel.anchor_right = 1.0; panel.anchor_bottom = 1.0
	panel.visible = false
	parent.add_child(panel)

	# Outer HBox: left list pane + right detail pane
	var hbox = HBoxContainer.new()
	hbox.anchor_right = 1.0; hbox.anchor_bottom = 1.0
	hbox.add_theme_constant_override("separation", 0)
	panel.add_child(hbox)

	# ── Left pane: filter buttons + scrollable list ────────────────────────────
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size.x = 220
	left_vbox.add_theme_constant_override("separation", 0)
	RimvaleUtils.add_bg(left_vbox, RimvaleColors.BG_CARD_DARK)
	hbox.add_child(left_vbox)

	var type_hbox = HBoxContainer.new()
	type_hbox.custom_minimum_size.y = 44
	type_hbox.add_theme_constant_override("separation", 0)
	left_vbox.add_child(type_hbox)

	var magic_btn = RimvaleUtils.button("✨ Magic", RimvaleColors.ACCENT, 44, 12)
	magic_btn.flat = true
	magic_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	magic_btn.pressed.connect(_on_item_type_selected.bindv(["magic"]))
	type_hbox.add_child(magic_btn)

	var mundane_btn = RimvaleUtils.button("⚔ Mundane", RimvaleColors.TEXT_GRAY, 44, 12)
	mundane_btn.flat = true
	mundane_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mundane_btn.pressed.connect(_on_item_type_selected.bindv(["mundane"]))
	type_hbox.add_child(mundane_btn)

	var items_scroll = ScrollContainer.new()
	items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	items_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(items_scroll)

	_items_list = VBoxContainer.new()
	_items_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_list.add_theme_constant_override("separation", 2)
	items_scroll.add_child(_items_list)

	# ── Right pane: item detail panel ─────────────────────────────────────────
	var right_scroll = ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hbox.add_child(right_scroll)

	var detail_mgn = MarginContainer.new()
	detail_mgn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left","right","top","bottom"]:
		detail_mgn.add_theme_constant_override("margin_" + s, 16)
	right_scroll.add_child(detail_mgn)

	_item_detail_panel = VBoxContainer.new()
	_item_detail_panel.add_theme_constant_override("separation", 8)
	_item_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_mgn.add_child(_item_detail_panel)

	# Placeholder prompt
	_item_detail_panel.add_child(
		RimvaleUtils.label("← Select an item to view details.", 13, RimvaleColors.TEXT_DIM))

	# Load initial items after _items_list is stored
	_refresh_items_list()

func _on_item_type_selected(item_type: String) -> void:
	selected_item_type = item_type
	_refresh_items_list()
	# Clear detail panel when switching category
	for c in _item_detail_panel.get_children():
		c.queue_free()
	_item_detail_panel.add_child(
		RimvaleUtils.label("← Select an item to view details.", 13, RimvaleColors.TEXT_DIM))

func _refresh_items_list() -> void:
	for child in _items_list.get_children():
		child.queue_free()

	var items: PackedStringArray
	if selected_item_type == "magic":
		items = RimvaleAPI.engine.get_all_registry_magic_items()
	else:
		items = RimvaleAPI.engine.get_all_registry_mundane_items()

	for item in items:
		var iname: String = str(item)
		var btn = RimvaleUtils.button(iname, RimvaleColors.GOLD, 42, 11)
		btn.flat = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_item_selected.bindv([iname]))
		_items_list.add_child(btn)

func _on_item_selected(item: String) -> void:
	for c in _item_detail_panel.get_children():
		c.queue_free()

	var details: PackedStringArray = RimvaleAPI.engine.get_registry_item_details(item)
	# details format: [rarity, cur_hp, max_hp, cost, item_type, type-specific..., description]
	var d_name: String   = item
	var d_rarity: String = str(details[0]) if details.size() > 0 else "Mundane"
	var d_cost: String   = str(details[3]) if details.size() > 3 else "0"
	var d_type: String   = str(details[4]) if details.size() > 4 else "Item"
	var d_desc: String   = ""
	if details.size() > 5:
		d_desc = str(details[details.size() - 1])
	else:
		d_desc = "No description."

	_item_detail_panel.add_child(
		RimvaleUtils.label(d_name, 18, RimvaleColors.GOLD))

	var meta_row = HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 12)
	_item_detail_panel.add_child(meta_row)
	meta_row.add_child(RimvaleUtils.label(d_type, 13, RimvaleColors.ACCENT))
	if d_rarity != "Mundane":
		meta_row.add_child(RimvaleUtils.label(d_rarity, 13, RimvaleColors.SUCCESS))
	meta_row.add_child(RimvaleUtils.label("💰 %sg" % d_cost, 13, RimvaleColors.GOLD))

	_item_detail_panel.add_child(RimvaleUtils.separator())

	var desc_lbl = RimvaleUtils.label(d_desc, 13, RimvaleColors.TEXT_WHITE)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_detail_panel.add_child(desc_lbl)

# ── Geography ─────────────────────────────────────────────────────────────────

func _build_geography_tab(parent: Control) -> void:
	var panel = Control.new()
	panel.anchor_right = 1.0; panel.anchor_bottom = 1.0
	panel.visible = false
	parent.add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.anchor_right = 1.0; hbox.anchor_bottom = 1.0
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var left_scroll = ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.custom_minimum_size.x = 200
	var regions_list = VBoxContainer.new()
	regions_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var regions: PackedStringArray = RimvaleAPI.engine.get_all_regions()
	for region in regions:
		var rname: String = str(region)
		var btn = RimvaleUtils.button(rname, RimvaleColors.CYAN, 50, 12)
		btn.pressed.connect(_on_region_selected.bindv([rname]))
		regions_list.add_child(btn)

	left_scroll.add_child(regions_list)
	hbox.add_child(left_scroll)

	# Right: details (stored reference)
	_region_details_panel = VBoxContainer.new()
	_region_details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_region_details_panel.add_theme_constant_override("separation", 8)
	_region_details_panel.add_child(RimvaleUtils.label("Select a region", 14, RimvaleColors.TEXT_GRAY))
	hbox.add_child(_region_details_panel)

func _on_region_selected(region: String) -> void:
	selected_region = region
	for child in _region_details_panel.get_children():
		child.queue_free()

	_region_details_panel.add_child(RimvaleUtils.label(region, 16, RimvaleColors.ACCENT))
	_region_details_panel.add_child(RimvaleUtils.separator())

	var details: PackedStringArray = RimvaleAPI.engine.get_region_details(region)
	for detail in details:
		_region_details_panel.add_child(RimvaleUtils.label(str(detail), 12, RimvaleColors.TEXT_WHITE))

	_region_details_panel.add_child(RimvaleUtils.separator())
	_region_details_panel.add_child(RimvaleUtils.label("Terrains:", 14, RimvaleColors.ACCENT))

	var terrains: PackedStringArray = RimvaleAPI.engine.get_region_terrains(region)
	for terrain in terrains:
		_region_details_panel.add_child(RimvaleUtils.label("• " + str(terrain), 12, RimvaleColors.TEXT_WHITE))

# ── Magic ─────────────────────────────────────────────────────────────────────

func _build_magic_tab(parent: Control) -> void:
	var panel = Control.new()
	panel.anchor_right = 1.0; panel.anchor_bottom = 1.0
	panel.visible = false
	parent.add_child(panel)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.anchor_right = 1.0; outer_vbox.anchor_bottom = 1.0
	outer_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(outer_vbox)

	outer_vbox.add_child(RimvaleUtils.label("Spells & Magic", 16, RimvaleColors.ACCENT))

	# Domain filter chips
	var domain_chips_hbox = HBoxContainer.new()
	domain_chips_hbox.add_theme_constant_override("separation", 6)
	outer_vbox.add_child(domain_chips_hbox)

	var domains: Array = ["All", "Biological", "Chemical", "Physical", "Spiritual"]
	for dom in domains:
		var chip := RimvaleUtils.button(dom, RimvaleColors.TEXT_GRAY, 30, 11)
		chip.flat = true
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if dom == "All":
			chip.add_theme_color_override("font_color", RimvaleColors.ACCENT)
		chip.pressed.connect(_on_spell_domain_selected.bind(dom))
		_spell_domain_chips[dom] = chip
		domain_chips_hbox.add_child(chip)

	# Two-pane layout: spell list | detail panel
	var hbox = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 8)
	outer_vbox.add_child(hbox)

	# Left: spell list with scroll
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size.x = 220
	left_vbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(left_vbox)

	var spell_scroll = ScrollContainer.new()
	spell_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spell_scroll.custom_minimum_size = Vector2(220, 0)
	left_vbox.add_child(spell_scroll)

	_spells_list = VBoxContainer.new()
	_spells_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spells_list.add_theme_constant_override("separation", 3)
	spell_scroll.add_child(_spells_list)

	# Right: detail panel
	var right_scroll = ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(right_scroll)

	_spell_detail_panel = VBoxContainer.new()
	_spell_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spell_detail_panel.add_theme_constant_override("separation", 8)
	_spell_detail_panel.add_child(RimvaleUtils.label("Select a spell", 14, RimvaleColors.TEXT_GRAY))
	right_scroll.add_child(_spell_detail_panel)

	_refresh_spell_list()

func _refresh_spell_list() -> void:
	if not _spells_list:
		return
	for child in _spells_list.get_children():
		child.queue_free()

	var all_spells: Array = RimvaleAPI.engine.get_all_spells()
	# Sort by name
	all_spells.sort_custom(func(a, b): return str(a[0]) < str(b[0]))

	var shown: int = 0
	for spell in all_spells:
		var spell_name: String = str(spell[0])
		var domain: String = str(spell[1])
		if selected_spell_domain != "All" and domain != selected_spell_domain:
			continue
		var btn := Button.new()
		btn.text = spell_name
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", RimvaleColors.TEXT_WHITE)
		btn.flat = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size.y = 32
		btn.pressed.connect(_on_spell_selected.bind(spell))
		_spells_list.add_child(btn)
		shown += 1

	if shown == 0:
		_spells_list.add_child(RimvaleUtils.label("No spells found.", 12, RimvaleColors.TEXT_GRAY))

func _on_spell_domain_selected(domain: String) -> void:
	selected_spell_domain = domain
	for dom in _spell_domain_chips:
		var col := RimvaleColors.ACCENT if dom == domain else RimvaleColors.TEXT_GRAY
		_spell_domain_chips[dom].add_theme_color_override("font_color", col)
	_refresh_spell_list()
	# Clear detail panel
	if _spell_detail_panel:
		for child in _spell_detail_panel.get_children():
			child.queue_free()
		_spell_detail_panel.add_child(RimvaleUtils.label("Select a spell", 14, RimvaleColors.TEXT_GRAY))

func _on_spell_selected(spell: Array) -> void:
	if not _spell_detail_panel:
		return
	for child in _spell_detail_panel.get_children():
		child.queue_free()

	# spell = [name, domain, sp_cost, description, range, is_attack]
	var spell_name: String = str(spell[0])
	var domain: String = str(spell[1])
	var sp_cost: String = str(spell[2])
	var desc: String = str(spell[3])
	var range_val: String = str(spell[4])
	var is_attack: String = str(spell[5])

	_spell_detail_panel.add_child(RimvaleUtils.label(spell_name, 16, RimvaleColors.ACCENT))
	_spell_detail_panel.add_child(RimvaleUtils.separator())

	# Domain + SP Cost row
	var dom_color := RimvaleColors.TEXT_WHITE
	match domain:
		"Biological": dom_color = Color(0.4, 0.9, 0.4)
		"Chemical":   dom_color = Color(1.0, 0.6, 0.2)
		"Physical":   dom_color = Color(0.4, 0.7, 1.0)
		"Spiritual":  dom_color = Color(0.9, 0.7, 1.0)
	_spell_detail_panel.add_child(RimvaleUtils.label(domain + "  •  " + sp_cost + " SP", 12, dom_color))

	# Range + type
	var type_str := "Attack" if is_attack == "true" else "Utility"
	var range_str := ("Touch" if range_val == "1" else range_val + " tiles") if range_val != "0" else "Self"
	_spell_detail_panel.add_child(RimvaleUtils.label("Range: " + range_str + "  •  " + type_str, 12, RimvaleColors.TEXT_GRAY))

	_spell_detail_panel.add_child(RimvaleUtils.separator())

	# Description (word-wrapped)
	if desc != "":
		var desc_lbl := Label.new()
		desc_lbl.text = desc
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", RimvaleColors.TEXT_WHITE)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_spell_detail_panel.add_child(desc_lbl)
