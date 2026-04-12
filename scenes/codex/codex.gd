extends Control

var current_tab: int = 0
var _content_area: Control
var selected_lineage: String = ""
var selected_feat_category: String = ""
var selected_feat_tree: String = ""
var selected_feat: String = ""
var selected_region: String = ""
var selected_item_type: String = "magic"

# Stored panel references — avoids all get_node() path lookups
var _lineage_details_panel: VBoxContainer
var _feat_trees_list: VBoxContainer
var _feats_list: VBoxContainer
var _feat_details_panel: VBoxContainer
var _items_list: VBoxContainer
var _region_details_panel: VBoxContainer

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

	var raw = RimvaleAPI.engine.get_lineage_details(lineage)
	for detail in raw:
		_lineage_details_panel.add_child(RimvaleUtils.label(str(detail), 12, RimvaleColors.TEXT_WHITE))

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

func _on_feat_selected(feat: String) -> void:
	selected_feat = feat
	for child in _feat_details_panel.get_children():
		child.queue_free()

	_feat_details_panel.add_child(RimvaleUtils.label(feat, 16, RimvaleColors.ACCENT))
	_feat_details_panel.add_child(RimvaleUtils.separator())

	var description: String = RimvaleAPI.engine.get_feat_description(feat, 1)
	_feat_details_panel.add_child(RimvaleUtils.label(description, 12, RimvaleColors.TEXT_WHITE))

# ── Items ─────────────────────────────────────────────────────────────────────

func _build_items_tab(parent: Control) -> void:
	var panel = Control.new()
	panel.anchor_right = 1.0; panel.anchor_bottom = 1.0
	panel.visible = false
	parent.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0; vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var type_hbox = HBoxContainer.new()
	type_hbox.custom_minimum_size.y = 40
	var magic_btn = RimvaleUtils.button("Magic Items", RimvaleColors.ACCENT, 50, 12)
	magic_btn.pressed.connect(_on_item_type_selected.bindv(["magic"]))
	type_hbox.add_child(magic_btn)
	var mundane_btn = RimvaleUtils.button("Mundane Items", RimvaleColors.CYAN, 50, 12)
	mundane_btn.pressed.connect(_on_item_type_selected.bindv(["mundane"]))
	type_hbox.add_child(mundane_btn)
	vbox.add_child(type_hbox)

	var items_scroll = ScrollContainer.new()
	items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_items_list = VBoxContainer.new()
	_items_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_scroll.add_child(_items_list)
	vbox.add_child(items_scroll)

	# Load initial items after _items_list is stored
	_refresh_items_list()

func _on_item_type_selected(item_type: String) -> void:
	selected_item_type = item_type
	_refresh_items_list()

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
		var btn = RimvaleUtils.button(iname, RimvaleColors.GOLD, 50, 12)
		btn.pressed.connect(_on_item_selected.bindv([iname]))
		_items_list.add_child(btn)

func _on_item_selected(item: String) -> void:
	var details = RimvaleAPI.engine.get_registry_item_details(item)
	print("Item details for " + item + ": " + str(details))

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

	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0; vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	vbox.add_child(RimvaleUtils.label("Spells & Magic", 16, RimvaleColors.ACCENT))

	var spells: Array = RimvaleAPI.engine.get_all_spells()
	if spells.is_empty():
		vbox.add_child(RimvaleUtils.label("No spells available", 12, RimvaleColors.TEXT_GRAY))
	else:
		var spells_scroll = ScrollContainer.new()
		spells_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var spells_vbox = VBoxContainer.new()
		spells_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spells_vbox.add_theme_constant_override("separation", 8)

		for spell in spells:
			# Each spell is a PackedStringArray: [name, domain, sp_cost, description, ...]
			var spell_name: String = str(spell[0])
			var spell_cost: String = str(spell[2])
			var spell_card = HBoxContainer.new()
			spell_card.custom_minimum_size.y = 50
			RimvaleUtils.add_bg(spell_card, RimvaleColors.BG_CARD)
			spell_card.add_child(RimvaleUtils.label(spell_name + "  (SP: " + spell_cost + ")", 13, RimvaleColors.TEXT_WHITE))
			spells_vbox.add_child(spell_card)

		spells_scroll.add_child(spells_vbox)
		vbox.add_child(spells_scroll)

	vbox.add_child(RimvaleUtils.separator())
	vbox.add_child(RimvaleUtils.label("Custom Spell Creator", 14, RimvaleColors.ACCENT))
	vbox.add_child(RimvaleUtils.label("Coming soon...", 12, RimvaleColors.TEXT_GRAY))
