extends Control

var current_tab: int = 0
var quests: Array = []
var active_tasks: Dictionary = {}
var active_forages: Array = []
var _content_area: Control  # stored so _on_tab_selected can find children
var _quests_vbox: VBoxContainer  # stored for _on_generate_quest refresh

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RimvaleUtils.add_bg(self, RimvaleColors.BG_DARK)

	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 0)
	add_child(main_vbox)

	# Tab selector buttons
	var tab_container = HBoxContainer.new()
	tab_container.custom_minimum_size.y = 60
	main_vbox.add_child(tab_container)

	var tabs = ["Missions", "Story", "Dungeon Dive", "Crafting", "Foraging", "Rituals", "Base"]
	for i in range(tabs.size()):
		var tab_btn = RimvaleUtils.button(tabs[i], RimvaleColors.ACCENT, 50, 14)
		tab_btn.pressed.connect(_on_tab_selected.bindv([i]))
		tab_container.add_child(tab_btn)

	RimvaleUtils.add_bg(tab_container, RimvaleColors.BG_CARD_DARK)

	# Content area — stored as class var so tab switching can reference it
	_content_area = Control.new()
	_content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_child(_content_area)

	# Initialize tabs
	_build_missions_tab(_content_area)
	_build_story_tab(_content_area)
	_build_dungeon_tab(_content_area)
	_build_crafting_tab(_content_area)
	_build_foraging_tab(_content_area)
	_build_rituals_tab(_content_area)
	_build_base_tab(_content_area)

	# Show first tab
	_on_tab_selected(0)

func _on_tab_selected(idx: int) -> void:
	current_tab = idx
	for child in _content_area.get_children():
		child.visible = false
	if idx < _content_area.get_child_count():
		_content_area.get_child(idx).visible = true

func _build_missions_tab(parent: Control) -> void:
	var missions_panel = Control.new()
	missions_panel.anchor_left = 0.0
	missions_panel.anchor_top = 0.0
	missions_panel.anchor_right = 1.0
	missions_panel.anchor_bottom = 1.0
	missions_panel.visible = false
	parent.add_child(missions_panel)

	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	missions_panel.add_child(vbox)

	# Region filter buttons
	var regions = RimvaleAPI.engine.get_all_regions()
	var region_scroll = ScrollContainer.new()
	region_scroll.custom_minimum_size.y = 80
	var region_hbox = HBoxContainer.new()
	region_hbox.add_theme_constant_override("separation", 8)
	region_scroll.add_child(region_hbox)
	vbox.add_child(region_scroll)

	for region in regions:
		var region_btn = RimvaleUtils.button(region, RimvaleColors.CYAN, 70, 12)
		region_btn.pressed.connect(_on_region_filter_selected.bindv([region]))
		region_hbox.add_child(region_btn)

	vbox.add_child(RimvaleUtils.spacer(8))

	# Quests list
	var quests_scroll = ScrollContainer.new()
	quests_scroll.anchor_left = 0.0
	quests_scroll.anchor_top = 0.0
	quests_scroll.anchor_right = 1.0
	quests_scroll.anchor_bottom = 1.0
	quests_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_quests_vbox = VBoxContainer.new()
	_quests_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quests_scroll.add_child(_quests_vbox)
	vbox.add_child(quests_scroll)

	# Generate quest button
	var gen_quest_btn = RimvaleUtils.button("Generate Quest", RimvaleColors.GOLD, 60, 14)
	gen_quest_btn.pressed.connect(_on_generate_quest)
	vbox.add_child(gen_quest_btn)

	# Sample quests
	_generate_sample_quests()
	_refresh_quests_display(_quests_vbox)

func _build_story_tab(parent: Control) -> void:
	var story_panel = Control.new()
	story_panel.anchor_left = 0.0
	story_panel.anchor_top = 0.0
	story_panel.anchor_right = 1.0
	story_panel.anchor_bottom = 1.0
	story_panel.visible = false
	parent.add_child(story_panel)

	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 12)
	story_panel.add_child(vbox)

	# Training missions
	vbox.add_child(RimvaleUtils.label("Training Missions", 16, RimvaleColors.ACCENT))
	var training_hbox = HBoxContainer.new()
	for i in range(1, 6):
		var train_btn = RimvaleUtils.button("Mission %d" % i, RimvaleColors.HP_GREEN, 50, 12)
		train_btn.pressed.connect(print.bindv(["Starting training mission %d" % i]))
		training_hbox.add_child(train_btn)
	vbox.add_child(training_hbox)

	vbox.add_child(RimvaleUtils.separator())

	# Story campaign
	vbox.add_child(RimvaleUtils.label("Story Campaign", 16, RimvaleColors.ACCENT))
	vbox.add_child(RimvaleUtils.label("Campaign coming soon...", 12, RimvaleColors.TEXT_GRAY))

func _build_dungeon_tab(parent: Control) -> void:
	var dungeon_panel = Control.new()
	dungeon_panel.anchor_left = 0.0
	dungeon_panel.anchor_top = 0.0
	dungeon_panel.anchor_right = 1.0
	dungeon_panel.anchor_bottom = 1.0
	dungeon_panel.visible = false
	parent.add_child(dungeon_panel)

	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 12)
	dungeon_panel.add_child(vbox)

	# Kaiju encounters
	vbox.add_child(RimvaleUtils.label("Kaiju Encounters", 16, RimvaleColors.ACCENT))
	var kaijus = ["Pyroclast", "Grondar", "Thal'Zuur", "Ny'Zorrak", "Mirecoast Sleeper", "Aegis Ultima"]
	for kaiju in kaijus:
		var kaiju_btn = RimvaleUtils.button(kaiju, RimvaleColors.ORANGE, 60, 12)
		kaiju_btn.pressed.connect(print.bindv(["Starting Kaiju: " + kaiju]))
		vbox.add_child(kaiju_btn)

	vbox.add_child(RimvaleUtils.separator())

	# Apex bosses
	vbox.add_child(RimvaleUtils.label("Apex Bosses", 16, RimvaleColors.ACCENT))
	var bosses = ["Varnok", "Lady Nyssara", "Malgrin", "Sithra", "Korrak", "Veltraxis", "Xal'Thuun"]
	for boss in bosses:
		var boss_btn = RimvaleUtils.button(boss, RimvaleColors.DANGER, 60, 12)
		boss_btn.pressed.connect(print.bindv(["Starting Boss: " + boss]))
		vbox.add_child(boss_btn)

	vbox.add_child(RimvaleUtils.separator())

	# Militia
	vbox.add_child(RimvaleUtils.label("Militia Raid", 16, RimvaleColors.ACCENT))
	var militia_hbox = HBoxContainer.new()
	militia_hbox.custom_minimum_size.y = 40
	var count_label = RimvaleUtils.label("Count: 5", 12, RimvaleColors.TEXT_WHITE)
	militia_hbox.add_child(count_label)
	var count_slider = HSlider.new()
	count_slider.min_value = 1
	count_slider.max_value = 10
	count_slider.value = 5
	count_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_slider.value_changed.connect(func(v): count_label.text = "Count: %d" % int(v))
	militia_hbox.add_child(count_slider)
	vbox.add_child(militia_hbox)

func _build_crafting_tab(parent: Control) -> void:
	var craft_panel = Control.new()
	craft_panel.anchor_left = 0.0
	craft_panel.anchor_top = 0.0
	craft_panel.anchor_right = 1.0
	craft_panel.anchor_bottom = 1.0
	craft_panel.visible = false
	parent.add_child(craft_panel)

	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 12)
	craft_panel.add_child(vbox)

	vbox.add_child(RimvaleUtils.label("Assign Crafting Tasks", 16, RimvaleColors.ACCENT))

	# Party member selector
	var active_handles := GameState.get_active_handles()
	if active_handles.size() > 0:
		var member_hbox = HBoxContainer.new()
		member_hbox.add_child(RimvaleUtils.label("Crafter:", 12, RimvaleColors.TEXT_WHITE))
		var member_dropdown = OptionButton.new()
		for h in active_handles:
			var cname: String = str(RimvaleAPI.engine.get_character_name(h))
			member_dropdown.add_item(cname)
		member_hbox.add_child(member_dropdown)
		vbox.add_child(member_hbox)

	# Item type selector
	var type_hbox = HBoxContainer.new()
	type_hbox.add_child(RimvaleUtils.label("Item Type:", 12, RimvaleColors.TEXT_WHITE))
	var type_dropdown = OptionButton.new()
	for item_type in ["Weapon", "Armor", "Potion", "Tool"]:
		type_dropdown.add_item(item_type)
	type_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_hbox.add_child(type_dropdown)
	vbox.add_child(type_hbox)

	var assign_btn = RimvaleUtils.button("Start Crafting", RimvaleColors.GOLD, 60, 14)
	assign_btn.pressed.connect(_on_assign_crafting)
	vbox.add_child(assign_btn)

	vbox.add_child(RimvaleUtils.separator())

	# Active tasks
	vbox.add_child(RimvaleUtils.label("Active Tasks", 16, RimvaleColors.ACCENT))
	var tasks_scroll = ScrollContainer.new()
	tasks_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tasks_vbox = VBoxContainer.new()
	tasks_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tasks_scroll.add_child(tasks_vbox)
	vbox.add_child(tasks_scroll)

	if active_tasks.is_empty():
		tasks_vbox.add_child(RimvaleUtils.label("No active crafting tasks", 12, RimvaleColors.TEXT_GRAY))

func _build_foraging_tab(parent: Control) -> void:
	var forage_panel = Control.new()
	forage_panel.anchor_left = 0.0
	forage_panel.anchor_top = 0.0
	forage_panel.anchor_right = 1.0
	forage_panel.anchor_bottom = 1.0
	forage_panel.visible = false
	parent.add_child(forage_panel)

	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 12)
	forage_panel.add_child(vbox)

	vbox.add_child(RimvaleUtils.label("Assign Foraging Tasks", 16, RimvaleColors.ACCENT))

	# Forage type buttons
	var forage_types = [["🏹 Hunting", "hunting"], ["🎣 Fishing", "fishing"], ["⛏ Mining", "mining"], ["🌿 Gathering", "gathering"]]
	var forage_hbox = HBoxContainer.new()
	forage_hbox.add_theme_constant_override("separation", 8)
	for forage_data in forage_types:
		var forage_btn = RimvaleUtils.button(forage_data[0], RimvaleColors.CYAN, 50, 12)
		forage_btn.pressed.connect(_on_foraging_selected.bindv([forage_data[1]]))
		forage_hbox.add_child(forage_btn)
	vbox.add_child(forage_hbox)

	# Character selector
	var forage_handles := GameState.get_active_handles()
	if forage_handles.size() > 0:
		var char_hbox = HBoxContainer.new()
		char_hbox.add_child(RimvaleUtils.label("Character:", 12, RimvaleColors.TEXT_WHITE))
		var char_dropdown = OptionButton.new()
		for h in forage_handles:
			var cname: String = str(RimvaleAPI.engine.get_character_name(h))
			char_dropdown.add_item(cname)
		char_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		char_hbox.add_child(char_dropdown)
		vbox.add_child(char_hbox)

	var assign_forage_btn = RimvaleUtils.button("Start Foraging", RimvaleColors.GOLD, 60, 14)
	assign_forage_btn.pressed.connect(_on_assign_foraging)
	vbox.add_child(assign_forage_btn)

	vbox.add_child(RimvaleUtils.separator())

	# Active forages
	vbox.add_child(RimvaleUtils.label("Active Tasks", 16, RimvaleColors.ACCENT))
	var forage_scroll = ScrollContainer.new()
	forage_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var forage_vbox = VBoxContainer.new()
	forage_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forage_scroll.add_child(forage_vbox)
	vbox.add_child(forage_scroll)

func _build_rituals_tab(parent: Control) -> void:
	var rituals_panel = Control.new()
	rituals_panel.anchor_left = 0.0
	rituals_panel.anchor_top = 0.0
	rituals_panel.anchor_right = 1.0
	rituals_panel.anchor_bottom = 1.0
	rituals_panel.visible = false
	parent.add_child(rituals_panel)

	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 12)
	rituals_panel.add_child(vbox)

	vbox.add_child(RimvaleUtils.label("Rituals", 16, RimvaleColors.ACCENT))

	var spells = RimvaleAPI.engine.get_all_spells()
	if spells.is_empty():
		vbox.add_child(RimvaleUtils.label("No rituals learned yet", 12, RimvaleColors.TEXT_GRAY))
	else:
		var spells_scroll = ScrollContainer.new()
		spells_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var spells_vbox = VBoxContainer.new()
		spells_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spells_vbox.add_theme_constant_override("separation", 8)

		for spell in spells:
			# Each spell element is a PackedStringArray: [name, domain, sp_cost, description, ...]
			var spell_name: String = str(spell[0])
			var spell_cost: String = str(spell[2])
			var spell_btn = RimvaleUtils.button(spell_name + " (SP: " + spell_cost + ")", RimvaleColors.SP_PURPLE, 50, 12)
			spell_btn.pressed.connect(print.bindv(["Casting ritual: " + spell_name]))
			spells_vbox.add_child(spell_btn)

		spells_scroll.add_child(spells_vbox)
		vbox.add_child(spells_scroll)

func _build_base_tab(parent: Control) -> void:
	var base_panel = Control.new()
	base_panel.anchor_left = 0.0
	base_panel.anchor_top = 0.0
	base_panel.anchor_right = 1.0
	base_panel.anchor_bottom = 1.0
	base_panel.visible = false
	parent.add_child(base_panel)

	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	base_panel.add_child(vbox)

	RimvaleUtils.add_bg(vbox, RimvaleColors.BG_CARD)
	vbox.add_child(RimvaleUtils.label("Base Building Coming Soon", 16, RimvaleColors.ACCENT))
	vbox.add_child(RimvaleUtils.label("Fortify your base and manage defenses", 12, RimvaleColors.TEXT_GRAY))

func _generate_sample_quests() -> void:
	quests = [
		{"title": "Investigate Ruins", "region": "Shadowmere", "difficulty": 2},
		{"title": "Escort Merchant", "region": "Goldfield Plains", "difficulty": 1},
		{"title": "Defeat Wyverns", "region": "Crimson Peaks", "difficulty": 3},
		{"title": "Collect Herbs", "region": "Verdant Woods", "difficulty": 1},
		{"title": "Clear Bandits", "region": "Ashen Wastes", "difficulty": 2},
	]

func _refresh_quests_display(vbox: VBoxContainer) -> void:
	for child in vbox.get_children():
		child.queue_free()

	for quest in quests:
		var quest_hbox = HBoxContainer.new()
		quest_hbox.custom_minimum_size.y = 60
		quest_hbox.add_theme_constant_override("separation", 8)
		RimvaleUtils.add_bg(quest_hbox, RimvaleColors.BG_CARD)

		var details_vbox = VBoxContainer.new()
		details_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details_vbox.add_child(RimvaleUtils.label(quest["title"], 14, RimvaleColors.TEXT_WHITE))
		details_vbox.add_child(RimvaleUtils.label(quest["region"] + " | Difficulty: " + str(quest["difficulty"]), 11, RimvaleColors.TEXT_GRAY))
		quest_hbox.add_child(details_vbox)

		var start_btn = RimvaleUtils.button("Start", RimvaleColors.GOLD, 50, 12)
		start_btn.pressed.connect(print.bindv(["Starting mission: " + quest["title"]]))
		quest_hbox.add_child(start_btn)

		vbox.add_child(quest_hbox)

func _on_generate_quest() -> void:
	var regions = RimvaleAPI.engine.get_all_regions()
	var region = regions[randi() % regions.size()]
	var new_quest = {
		"title": "Generated Quest",
		"region": region,
		"difficulty": randi() % 3 + 1
	}
	quests.append(new_quest)
	_refresh_quests_display(_quests_vbox)

func _on_region_filter_selected(region: String) -> void:
	print("Filtering quests by region: " + region)

func _on_assign_crafting() -> void:
	print("Crafting task assigned")

func _on_foraging_selected(forage_type: String) -> void:
	print("Selected foraging: " + forage_type)

func _on_assign_foraging() -> void:
	print("Foraging task assigned")
