## inventory.gd
## Full Equip Agent screen — port of InventoryScreen.kt + EquipmentTab
## Equipped slots, Inventory/Stash tabs with category filters, shop, transfer

extends Control

# ── State ─────────────────────────────────────────────────────────────────────

var _e
var _handle: int = -1
var _active_tab: int = 0       # 0=Inventory  1=Stash
var _inv_filter: String = "All"
var _stash_filter: String = "All"
var _search_text: String = ""

# ── Stored UI refs ────────────────────────────────────────────────────────────

var _equipped_row: HBoxContainer
var _item_list: VBoxContainer
var _tab_btns: Array = []
var _filter_hbox: HBoxContainer
var _search_input: LineEdit

# Shop dialog state (class-level so methods can reference each other)
var _shop_dialog: AcceptDialog
var _shop_content: VBoxContainer
var _shop_tab_btns: Array = []
var _shop_active_tab: int = 0
var _shop_buy_cat: String = "Weapons"

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_e = RimvaleAPI.engine
	_handle = GameState.selected_hero_handle
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RimvaleUtils.add_bg(self, RimvaleColors.BG_DARK)
	_build_ui()

# ── UI Construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# ── Header ──
	var hdr = ColorRect.new()
	hdr.color = RimvaleColors.BG_CARD
	hdr.custom_minimum_size = Vector2(0, 60)
	root.add_child(hdr)

	var hmgn = MarginContainer.new()
	hmgn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		hmgn.add_theme_constant_override("margin_" + s, 12)
	hdr.add_child(hmgn)

	var hrow = HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 12)
	hmgn.add_child(hrow)

	var char_name: String = str(_e.get_character_name(_handle)) if _handle != -1 else "No Hero"
	hrow.add_child(RimvaleUtils.label("🎒 Gear — " + char_name, 20, RimvaleColors.ACCENT))

	var gold_lbl = RimvaleUtils.label("💰 %d GP" % GameState.gold, 15, RimvaleColors.GOLD)
	hrow.add_child(gold_lbl)

	# Attunement SP summary
	var att_committed: int = _e.get_attunement_sp_committed(_handle) if _handle != -1 else 0
	if att_committed > 0:
		hrow.add_child(RimvaleUtils.label("🔮 %d SP attuned" % att_committed, 13, RimvaleColors.SP_PURPLE))

	var _hdr_spacer = Control.new()
	_hdr_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(_hdr_spacer)

	var back_btn = RimvaleUtils.button("← Back", RimvaleColors.TEXT_GRAY, 40, 13)
	back_btn.pressed.connect(func():
		get_parent().get_parent().pop_screen()
	)
	hrow.add_child(back_btn)

	# ── Equipped slots ──
	var eq_mgn = MarginContainer.new()
	for s in ["left", "right"]:
		eq_mgn.add_theme_constant_override("margin_" + s, 12)
	eq_mgn.add_theme_constant_override("margin_top", 10)
	eq_mgn.add_theme_constant_override("margin_bottom", 6)
	root.add_child(eq_mgn)

	_equipped_row = HBoxContainer.new()
	_equipped_row.add_theme_constant_override("separation", 8)
	eq_mgn.add_child(_equipped_row)
	_refresh_equipped()

	# ── Tabs ──
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 0)
	root.add_child(tab_row)
	for ti in range(2):
		var ti_cap: int = ti
		var tlabel: String = "Inventory" if ti == 0 else "Stash"
		var tbtn = RimvaleUtils.button(tlabel,
			RimvaleColors.ACCENT if ti == _active_tab else RimvaleColors.TEXT_GRAY, 42, 14)
		tbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tbtn.pressed.connect(func():
			_active_tab = ti_cap
			for i in range(_tab_btns.size()):
				_tab_btns[i].add_theme_color_override("font_color",
					RimvaleColors.ACCENT if i == _active_tab else RimvaleColors.TEXT_GRAY)
			_rebuild_filter_chips()
			_rebuild_items()
		)
		_tab_btns.append(tbtn)
		tab_row.add_child(tbtn)

	# ── Category filter row ──
	var filter_scroll = ScrollContainer.new()
	filter_scroll.custom_minimum_size = Vector2(0, 36)
	filter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(filter_scroll)

	_filter_hbox = HBoxContainer.new()
	_filter_hbox.add_theme_constant_override("separation", 8)
	var filter_mgn = MarginContainer.new()
	for s in ["left", "right"]:
		filter_mgn.add_theme_constant_override("margin_" + s, 12)
	filter_scroll.add_child(filter_mgn)
	filter_mgn.add_child(_filter_hbox)
	_rebuild_filter_chips()

	# ── Search box ──
	var search_mgn = MarginContainer.new()
	for s in ["left", "right"]:
		search_mgn.add_theme_constant_override("margin_" + s, 12)
	search_mgn.add_theme_constant_override("margin_top", 4)
	search_mgn.add_theme_constant_override("margin_bottom", 4)
	root.add_child(search_mgn)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Search items..."
	_search_input.clear_button_enabled = true
	_search_input.custom_minimum_size = Vector2(0, 36)
	_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_search_input.add_theme_font_size_override("font_size", 14)
	_search_input.add_theme_color_override("font_color", RimvaleColors.TEXT_WHITE)
	_search_input.add_theme_color_override("font_placeholder_color", RimvaleColors.TEXT_DIM)
	var search_sb = StyleBoxFlat.new()
	search_sb.bg_color = Color(0.16, 0.14, 0.24, 1.0)
	search_sb.border_color = Color(0.5, 0.5, 0.6, 0.4)
	search_sb.set_border_width_all(1)
	search_sb.set_corner_radius_all(6)
	search_sb.set_content_margin_all(8)
	_search_input.add_theme_stylebox_override("normal", search_sb)
	var search_sb_focus = search_sb.duplicate()
	search_sb_focus.border_color = RimvaleColors.ACCENT
	_search_input.add_theme_stylebox_override("focus", search_sb_focus)
	_search_input.text_changed.connect(func(new_text: String):
		_search_text = new_text.to_lower()
		_rebuild_items()
	)
	search_mgn.add_child(_search_input)

	# ── Item list ──
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var list_mgn = MarginContainer.new()
	for s in ["left", "right"]:
		list_mgn.add_theme_constant_override("margin_" + s, 12)
	list_mgn.add_theme_constant_override("margin_top", 4)
	list_mgn.add_theme_constant_override("margin_bottom", 8)
	list_mgn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_mgn)

	_item_list = VBoxContainer.new()
	_item_list.add_theme_constant_override("separation", 10)
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_mgn.add_child(_item_list)

	_rebuild_items()

	# ── Open Market button ──
	var shop_mgn = MarginContainer.new()
	for s in ["left", "right", "bottom"]:
		shop_mgn.add_theme_constant_override("margin_" + s, 12)
	root.add_child(shop_mgn)

	var shop_btn = RimvaleUtils.button("🛒 Open Market", RimvaleColors.GOLD, 48, 15)
	shop_btn.pressed.connect(func(): _show_shop_dialog())
	shop_mgn.add_child(shop_btn)

# ── Equipped Slots ────────────────────────────────────────────────────────────

func _refresh_equipped() -> void:
	for c in _equipped_row.get_children():
		c.queue_free()

	if _handle == -1:
		_equipped_row.add_child(RimvaleUtils.label("No hero selected", 13, RimvaleColors.TEXT_DIM))
		return

	var weapon: String = str(_e.get_equipped_weapon(_handle))
	var armor: String  = str(_e.get_equipped_armor(_handle))
	var shield: String = str(_e.get_equipped_shield(_handle))
	var light: String  = str(_e.get_equipped_light_source(_handle))
	var offhand: String = str(_e._chars.get(_handle, {}).get("offhand", "None"))
	var tf_t_local: int = int(_e._chars.get(_handle, {}).get("feats", {}).get("Twin Fang", 0))

	# 0=weapon, 1=armor, 2=shield, 3=light, 4=offhand — slot indices match
	# unequip_item(). The off-hand slot is only shown when Twin Fang is
	# unlocked; otherwise it has no meaning.
	var slots_data = [
		["⚔ Weapon", weapon, 0, "weapon"],
	]
	if tf_t_local >= 1:
		slots_data.append(["⚔ Off-Hand", offhand, 4, ""])
	slots_data.append_array([
		["🛡 Armor",  armor,  1, "armor"],
		["🔰 Shield", shield, 2, "shield"],
		["🔥 Light",  light,  3, ""],
	])

	for sd in slots_data:
		var slot_lbl: String = sd[0]
		var item_name: String = sd[1]
		var slot_idx: int = sd[2]
		var dur_slot: String = sd[3]

		var card = ColorRect.new()
		card.color = Color(0.10, 0.14, 0.20, 1.0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 96)

		var cmgn = MarginContainer.new()
		cmgn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for s in ["left", "right", "top", "bottom"]:
			cmgn.add_theme_constant_override("margin_" + s, 10)
		card.add_child(cmgn)

		var cvbox = VBoxContainer.new()
		cvbox.add_theme_constant_override("separation", 4)
		cmgn.add_child(cvbox)

		cvbox.add_child(RimvaleUtils.label(slot_lbl, 11, RimvaleColors.TEXT_DIM))

		var is_empty: bool = item_name.is_empty()
		var name_lbl := RimvaleUtils.label(
			item_name if not is_empty else "None",
			12,
			RimvaleColors.TEXT_WHITE if not is_empty else RimvaleColors.TEXT_DIM)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cvbox.add_child(name_lbl)

		# Durability text for weapon/armor/shield (matches level_up's display)
		if not is_empty and dur_slot != "" and _e._chars.has(_handle):
			var _cc: Dictionary = _e._chars[_handle]
			var dhp: int = _e._get_equip_hp(_cc, dur_slot)
			var dmhp: int = _e._get_equip_max_hp(_cc, dur_slot)
			if dmhp > 0:
				var dur_col: Color = (
					Color(0.30, 0.80, 0.30) if dhp > dmhp / 2
					else Color(0.90, 0.70, 0.20) if dhp > 0
					else Color(0.90, 0.20, 0.20))
				var dur_text: String = "%d/%d HP" % [maxi(0, dhp), dmhp]
				if dhp <= 0: dur_text += " (BROKEN)"
				cvbox.add_child(RimvaleUtils.label(dur_text, 10, dur_col))

		# Push the unequip button to the bottom of the card
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cvbox.add_child(spacer)

		if not is_empty:
			var si_cap: int = slot_idx
			var x_btn = RimvaleUtils.button("✕ Unequip", RimvaleColors.DANGER, 26, 10)
			x_btn.pressed.connect(func():
				_e.unequip_item(_handle, si_cap)
				_refresh_equipped()
				_rebuild_items()
			)
			cvbox.add_child(x_btn)

		_equipped_row.add_child(card)

# ── Item List ─────────────────────────────────────────────────────────────────

func _rebuild_filter_chips() -> void:
	for c in _filter_hbox.get_children():
		c.queue_free()
	var active_filter: String = _inv_filter if _active_tab == 0 else _stash_filter
	for cat in ["All", "Weapons", "Armor", "Consumable", "Magic", "Misc"]:
		var cat_cap: String = cat
		var cc: Color = RimvaleColors.ACCENT if cat == active_filter else RimvaleColors.TEXT_GRAY
		var chip = RimvaleUtils.button(cat, cc, 30, 12)
		chip.pressed.connect(func():
			if _active_tab == 0: _inv_filter = cat_cap
			else: _stash_filter = cat_cap
			_rebuild_filter_chips()
			_rebuild_items()
		)
		_filter_hbox.add_child(chip)

func _rebuild_items() -> void:
	for c in _item_list.get_children():
		c.queue_free()

	if _handle == -1:
		_item_list.add_child(RimvaleUtils.label("No hero selected.", 13, RimvaleColors.TEXT_DIM))
		return

	if _active_tab == 0:
		_build_inventory_items()
	else:
		_build_stash_items()

func _build_inventory_items() -> void:
	var items_raw = _e.get_inventory_items(_handle)

	# Separate magical / mundane for "All" or "Magic" filter display
	var magical_items: Array = []
	var mundane_items: Array = []

	for item_raw in items_raw:
		var item_name: String = str(item_raw)
		var details_raw = _e.get_item_details(_handle, item_name)
		var rarity: String = str(details_raw[0]) if details_raw.size() > 0 else "Mundane"
		var cur_hp: int = int(str(details_raw[1])) if details_raw.size() > 1 else 0
		var max_hp: int = int(str(details_raw[2])) if details_raw.size() > 2 else 0
		var cost: int = int(str(details_raw[3])) if details_raw.size() > 3 else 0
		var item_type: String = str(details_raw[4]) if details_raw.size() > 4 else "General"
		var desc: String = ""
		if details_raw.size() > 5:
			desc = str(details_raw[details_raw.size() - 1])
		var is_magical: bool = rarity != "Mundane"

		var item_data = {
			"name": item_name,
			"rarity": rarity,
			"cur_hp": cur_hp,
			"max_hp": max_hp,
			"cost": cost,
			"type": item_type,
			"desc": desc,
			"magical": is_magical
		}

		# Category filter
		var show: bool = _inv_filter == "All"
		match _inv_filter:
			"Weapons": show = item_type == "Weapon" and not is_magical
			"Armor":   show = (item_type == "Armor" or item_type == "Shield") and not is_magical
			"Magic":   show = is_magical
			"Consumable": show = item_type == "Consumable" and not is_magical
			"Misc":    show = item_type != "Weapon" and item_type != "Armor" and item_type != "Shield" and item_type != "Consumable" and not is_magical

		if not show:
			continue

		# Search filter
		if _search_text != "" and _search_text not in item_name.to_lower():
			continue

		if is_magical:
			magical_items.append(item_data)
		else:
			mundane_items.append(item_data)

	if magical_items.is_empty() and mundane_items.is_empty():
		_item_list.add_child(RimvaleUtils.label("No items in this category.", 13, RimvaleColors.TEXT_DIM))
		return

	# Show magical items with header if in All/Magic filter
	if not magical_items.is_empty() and (_inv_filter == "All" or _inv_filter == "Magic"):
		_item_list.add_child(_build_section_header("✦ Magical", RimvaleColors.ACCENT, false))
		for d in magical_items:
			_item_list.add_child(_build_item_row(d))

	if not mundane_items.is_empty() and not magical_items.is_empty() and (_inv_filter == "All" or _inv_filter == "Magic"):
		_item_list.add_child(_build_section_header("Mundane", RimvaleColors.TEXT_DIM, true))

	for d in mundane_items:
		_item_list.add_child(_build_item_row(d))

## Section header label with optional top breathing room.
func _build_section_header(text: String, color: Color, with_top_pad: bool) -> Control:
	var box := VBoxContainer.new()
	if with_top_pad:
		var top_pad := Control.new()
		top_pad.custom_minimum_size = Vector2(0, 8)
		box.add_child(top_pad)
	var lbl := RimvaleUtils.label(text, 13, color)
	box.add_child(lbl)
	var bot_pad := Control.new()
	bot_pad.custom_minimum_size = Vector2(0, 4)
	box.add_child(bot_pad)
	return box

func _build_item_row(d: Dictionary) -> Control:
	var item_name: String = d["name"]
	var rarity: String = d["rarity"]
	var cur_hp: int = d["cur_hp"]
	var max_hp: int = d["max_hp"]
	var item_type: String = d["type"]
	var desc: String = d["desc"]
	var is_magical: bool = d["magical"]
	var rarity_col: Color = _rarity_color(rarity)

	# Use a PanelContainer with a styled border so magical items pop.
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	if is_magical:
		sb.bg_color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.07)
		sb.border_color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.55)
	else:
		sb.bg_color = Color(0.10, 0.10, 0.14, 1.0)
		sb.border_color = Color(0.30, 0.30, 0.36, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# ── Row 1: name (left) + rarity badge (right, magical only) ──
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)

	var name_prefix: String = "✦ " if is_magical else ""
	var name_lbl := RimvaleUtils.label(name_prefix + item_name, 15,
		rarity_col if is_magical else RimvaleColors.TEXT_WHITE)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_row.add_child(name_lbl)

	if is_magical:
		var rarity_chip := PanelContainer.new()
		var chip_sb := StyleBoxFlat.new()
		chip_sb.bg_color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.18)
		chip_sb.border_color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.55)
		chip_sb.set_border_width_all(1)
		chip_sb.set_corner_radius_all(10)
		chip_sb.content_margin_left = 8; chip_sb.content_margin_right = 8
		chip_sb.content_margin_top = 2;  chip_sb.content_margin_bottom = 2
		rarity_chip.add_theme_stylebox_override("panel", chip_sb)
		rarity_chip.add_child(RimvaleUtils.label(rarity, 10, rarity_col))
		title_row.add_child(rarity_chip)

	# ── Row 2: meta line (type · durability · attunement status) ──
	var meta_parts: PackedStringArray = []
	meta_parts.append(item_type)
	if max_hp > 0:
		meta_parts.append("Dur %d/%d" % [cur_hp, max_hp])
	var attune_cost: int = _attunement_cost(rarity) if is_magical else 0
	var is_attuned: bool = is_magical and _e.is_attuned(_handle, item_name)
	if is_attuned:
		meta_parts.append("Attuned (-%d SP)" % attune_cost)
	var meta_text: String = " · ".join(meta_parts)
	var meta_col: Color = RimvaleColors.SP_PURPLE if is_attuned else RimvaleColors.TEXT_DIM
	vbox.add_child(RimvaleUtils.label(meta_text, 11, meta_col))

	# ── Row 3: description (if present and reasonably short) ──
	if not desc.is_empty() and desc.length() < 240:
		var desc_lbl := RimvaleUtils.label(desc, 11, RimvaleColors.TEXT_GRAY)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_lbl)

	# ── Curse warning (if any) ──
	var item_full_eff: Dictionary = MagicItemData.ALL_MAGIC_ITEMS.get(item_name, {}).get("effects", {})
	if bool(item_full_eff.get("requires_curse", false)):
		var curse_str: String = str(item_full_eff.get("curse_text", "This item carries a curse — see GMG description."))
		var curse_lbl := RimvaleUtils.label("⚠ Curse: " + curse_str, 11, Color(0.95, 0.45, 0.45))
		curse_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(curse_lbl)

	# ── Row 4: action bar — bigger buttons, all on their own line ──
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	vbox.add_child(action_row)

	var in_cap: String = item_name
	if item_type == "Consumable":
		var use_btn := RimvaleUtils.button("Use", RimvaleColors.SUCCESS, 38, 12)
		use_btn.custom_minimum_size = Vector2(78, 0)
		use_btn.pressed.connect(func():
			_e.use_consumable(_handle, in_cap)
			_refresh_equipped()
			_rebuild_items()
		)
		action_row.add_child(use_btn)
	elif item_type != "General":
		var eq_btn := RimvaleUtils.button("Equip", RimvaleColors.ACCENT, 38, 12)
		eq_btn.custom_minimum_size = Vector2(78, 0)
		eq_btn.pressed.connect(func():
			_e.equip_item(_handle, in_cap)
			_refresh_equipped()
			_rebuild_items()
		)
		action_row.add_child(eq_btn)
		# Off-Hand button: only surfaces for weapon-type items when the
		# wielder has Twin Fang T1+. Calls the dual-wield engine API.
		if item_type == "Weapon" and _handle != -1:
			var c_dict: Dictionary = _e._chars.get(_handle, {})
			var tf_t: int = int(c_dict.get("feats", {}).get("Twin Fang", 0))
			if tf_t >= 1:
				var oh_btn := RimvaleUtils.button(
					"Off-Hand", RimvaleColors.CYAN, 38, 12)
				oh_btn.custom_minimum_size = Vector2(86, 0)
				oh_btn.pressed.connect(func():
					var err: String = _e.equip_offhand_weapon(_handle, in_cap)
					if err != "":
						_show_notice(err)
					_refresh_equipped()
					_rebuild_items()
				)
				action_row.add_child(oh_btn)

	# Magical → Attune / Unattune button (its own real button now, not a tiny chip)
	if is_magical and attune_cost > 0:
		var in_cap2: String = item_name
		# Apex items get a tier picker instead of a single attune button.
		if _e.is_apex_item(in_cap2):
			var apex_tier: int = _e.apex_get_tier(_handle, in_cap2)
			var apex_lbl_text: String = "Tier %d/5" % apex_tier if apex_tier > 0 else "Not Attuned"
			action_row.add_child(RimvaleUtils.label(apex_lbl_text, 11, RimvaleColors.SP_PURPLE))
			var pick_btn := RimvaleUtils.button(
				"Attune Tier…", RimvaleColors.SP_PURPLE, 38, 12)
			pick_btn.custom_minimum_size = Vector2(120, 0)
			pick_btn.pressed.connect(func(): _show_apex_tier_picker(in_cap2))
			action_row.add_child(pick_btn)
		elif is_attuned:
			var unattune_btn := RimvaleUtils.button(
				"Unattune", Color(0.70, 0.30, 0.30), 38, 12)
			unattune_btn.custom_minimum_size = Vector2(108, 0)
			unattune_btn.pressed.connect(func():
				_e.unattune_item(_handle, in_cap2)
				_refresh_equipped()
				_rebuild_items()
			)
			action_row.add_child(unattune_btn)
		else:
			var attune_btn := RimvaleUtils.button(
				"Attune (%d SP)" % attune_cost, RimvaleColors.SP_PURPLE, 38, 12)
			attune_btn.custom_minimum_size = Vector2(120, 0)
			attune_btn.pressed.connect(func():
				var result: String = _e.attune_item(_handle, in_cap2)
				if result != "":
					_show_notice(result)
				else:
					_show_notice("Attuned to %s (-%d max SP)" % [in_cap2, attune_cost])
				_refresh_equipped()
				_rebuild_items()
			)
			action_row.add_child(attune_btn)

	# Push transfer / stash buttons to the right edge
	var action_spacer := Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(action_spacer)

	var transfer_btn := RimvaleUtils.button("→ Give", RimvaleColors.TEXT_GRAY, 38, 12)
	transfer_btn.custom_minimum_size = Vector2(80, 0)
	transfer_btn.pressed.connect(func(): _show_transfer_dialog(in_cap))
	action_row.add_child(transfer_btn)

	var stash_btn := RimvaleUtils.button("Stash", RimvaleColors.TEXT_GRAY, 38, 12)
	stash_btn.custom_minimum_size = Vector2(74, 0)
	stash_btn.pressed.connect(func():
		_e.remove_item_from_inventory(_handle, in_cap)
		GameState.add_to_stash(in_cap)
		_rebuild_items()
	)
	action_row.add_child(stash_btn)

	return card

func _build_stash_items() -> void:
	if GameState.stash.size() == 0:
		_item_list.add_child(RimvaleUtils.label("The stash is empty.", 13, RimvaleColors.TEXT_DIM))
		return

	var any_shown: bool = false
	for item_name in GameState.stash:
		var details_raw = _e.get_registry_item_details(item_name)
		var item_type: String = str(details_raw[4]) if details_raw.size() > 4 else "General"
		var rarity: String = str(details_raw[0]) if details_raw.size() > 0 else "Mundane"
		var is_magical: bool = rarity != "Mundane"

		var show: bool = _stash_filter == "All"
		match _stash_filter:
			"Weapons": show = item_type == "Weapon" and not is_magical
			"Armor":   show = (item_type == "Armor" or item_type == "Shield") and not is_magical
			"Magic":   show = is_magical
			"Consumable": show = item_type == "Consumable" and not is_magical
			"Misc":    show = item_type != "Weapon" and item_type != "Armor" and item_type != "Shield" and item_type != "Consumable" and not is_magical

		if not show:
			continue

		# Search filter
		if _search_text != "" and _search_text not in item_name.to_lower():
			continue

		any_shown = true
		var in_cap: String = item_name

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 46)
		_item_list.add_child(row)

		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)
		var stash_name_col: Color = _rarity_color(rarity) if is_magical else RimvaleColors.TEXT_WHITE
		var stash_prefix: String = "✦ " if is_magical else ""
		info.add_child(RimvaleUtils.label(stash_prefix + item_name, 14, stash_name_col))
		# Show description from registry
		var stash_desc: String = str(details_raw[details_raw.size() - 1]) if details_raw.size() > 0 else ""
		if stash_desc.length() > 0 and stash_desc.length() < 200:
			var sdlbl: Label = RimvaleUtils.label(stash_desc, 10, RimvaleColors.TEXT_GRAY)
			sdlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info.add_child(sdlbl)
		info.add_child(RimvaleUtils.label(item_type, 10, RimvaleColors.TEXT_DIM))

		var take_btn = RimvaleUtils.button("Take", RimvaleColors.SUCCESS, 36, 12)
		take_btn.pressed.connect(func():
			GameState.remove_from_stash(in_cap)
			_e.add_item_to_inventory(_handle, in_cap)
			_rebuild_items()
		)
		row.add_child(take_btn)

	if not any_shown:
		_item_list.add_child(RimvaleUtils.label("Nothing in this category.", 13, RimvaleColors.TEXT_DIM))

# ── Apex Tier Picker ──────────────────────────────────────────────────────────

func _show_apex_tier_picker(item_name: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Apex Attunement — " + item_name
	dialog.get_ok_button().text = "Close"
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	dialog.add_child(vbox)

	var entry: Dictionary = MagicItemData.ALL_MAGIC_ITEMS.get(item_name, {})
	var tier_data: Dictionary = entry.get("effects", {}).get("tiers", {})
	var current_tier: int = _e.apex_get_tier(_handle, item_name)
	var avail_sp: int = _e.get_available_max_sp(_handle)

	vbox.add_child(RimvaleUtils.label(
		"Attune at a chosen tier. Each tier costs 1 max SP (cumulative). " +
		"Available max SP: %d. Current tier: %d." % [avail_sp, current_tier],
		12, RimvaleColors.TEXT_GRAY))

	# Tier 0 row = "Unattune"
	var unattune_row := HBoxContainer.new()
	unattune_row.add_theme_constant_override("separation", 8)
	vbox.add_child(unattune_row)
	unattune_row.add_child(RimvaleUtils.label("Tier 0 — Unattuned", 13, RimvaleColors.TEXT_GRAY))
	var unattune_spc := Control.new(); unattune_spc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unattune_row.add_child(unattune_spc)
	if current_tier > 0:
		var u_btn := RimvaleUtils.button("Set", Color(0.70, 0.30, 0.30), 32, 11)
		u_btn.pressed.connect(func():
			var err: String = _e.apex_set_tier(_handle, item_name, 0)
			if err != "":
				_show_notice(err)
			dialog.queue_free()
			_refresh_equipped()
			_rebuild_items()
		)
		unattune_row.add_child(u_btn)

	# Tier 1..5 rows
	for t in range(1, 6):
		var t_eff: Dictionary = tier_data.get(t, {})
		var summary: String = _summarize_tier_effects(t_eff)
		var tier_box := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		var is_current: bool = (t == current_tier)
		var is_unlocked: bool = (t <= current_tier)
		sb.bg_color = Color(0.13, 0.10, 0.20, 1.0) if is_current else Color(0.10, 0.09, 0.14, 1.0)
		sb.border_color = RimvaleColors.SP_PURPLE if is_unlocked else Color(0.4, 0.4, 0.45, 0.5)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(8)
		tier_box.add_theme_stylebox_override("panel", sb)
		var trow := HBoxContainer.new()
		trow.add_theme_constant_override("separation", 8)
		tier_box.add_child(trow)
		var tlabel := RimvaleUtils.label("Tier %d  (%d SP)" % [t, t], 13,
			RimvaleColors.SP_PURPLE if is_unlocked else RimvaleColors.TEXT_GRAY)
		tlabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		trow.add_child(tlabel)
		var summary_lbl := RimvaleUtils.label(summary, 11, RimvaleColors.TEXT_GRAY)
		summary_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		trow.add_child(summary_lbl)
		var t_cap: int = t
		var sel_btn := RimvaleUtils.button(
			"Set" if not is_current else "Active",
			RimvaleColors.SP_PURPLE if not is_current else RimvaleColors.SUCCESS, 32, 11)
		sel_btn.disabled = is_current
		sel_btn.pressed.connect(func():
			var err: String = _e.apex_set_tier(_handle, item_name, t_cap)
			if err != "":
				_show_notice(err)
				return
			dialog.queue_free()
			_refresh_equipped()
			_rebuild_items()
		)
		trow.add_child(sel_btn)
		vbox.add_child(tier_box)

	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2(540, 480))

## Build a one-line summary of a tier's static effects for the picker UI.
func _summarize_tier_effects(t_eff: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in t_eff.keys():
		var v = t_eff[key]
		if key == "active":
			parts.append("✦ " + str(v.get("name", "Active")))
		elif typeof(v) == TYPE_BOOL and v:
			parts.append(str(key).replace("_", " "))
		elif typeof(v) == TYPE_INT:
			parts.append("%s +%d" % [str(key).replace("_", " "), int(v)])
		elif typeof(v) == TYPE_ARRAY and not v.is_empty():
			parts.append(str(key).replace("_", " "))
	if parts.is_empty(): return "—"
	return ", ".join(parts)

# ── Transfer Dialog ───────────────────────────────────────────────────────────

func _show_transfer_dialog(item_name: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Transfer " + item_name
	dialog.get_ok_button().text = "Cancel"

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	dialog.add_child(vbox)
	vbox.add_child(RimvaleUtils.label("Select an agent to receive this item:", 13, RimvaleColors.TEXT_GRAY))

	for h in GameState.collection:
		if h == _handle:
			continue
		var target_name: String = str(_e.get_character_name(h))
		var lin: String = str(_e.get_character_lineage_name(h))
		var lv: int = _e.get_character_level(h)

		var h_cap: int = h
		var in_cap: String = item_name
		var row_btn = RimvaleUtils.button("%s  (%s Lv %d)" % [target_name, lin, lv],
			RimvaleColors.TEXT_WHITE, 44, 13)
		row_btn.pressed.connect(func():
			_e.remove_item_from_inventory(_handle, in_cap)
			_e.add_item_to_inventory(h_cap, in_cap)
			_rebuild_items()
			dialog.hide()
			dialog.queue_free()
		)
		vbox.add_child(row_btn)

	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2(340, 320))

# ── Shop Dialog ───────────────────────────────────────────────────────────────

func _show_shop_dialog() -> void:
	_shop_active_tab = 0
	_shop_buy_cat = "Weapons"
	_shop_tab_btns.clear()

	_shop_dialog = AcceptDialog.new()
	_shop_dialog.title = "Marketplace"
	_shop_dialog.get_ok_button().text = "Done"
	_shop_dialog.min_size = Vector2i(420, 540)

	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	_shop_dialog.add_child(outer)

	# Buy / Sell tab bar
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 0)
	outer.add_child(tab_row)

	for ti in range(2):
		var ti_cap: int = ti
		var tl: String = "Buy" if ti == 0 else "Sell"
		var tbtn = RimvaleUtils.button(tl,
			RimvaleColors.ACCENT if ti == 0 else RimvaleColors.TEXT_GRAY, 40, 13)
		tbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tbtn.pressed.connect(func(): _shop_switch_tab(ti_cap))
		_shop_tab_btns.append(tbtn)
		tab_row.add_child(tbtn)

	_shop_content = VBoxContainer.new()
	_shop_content.add_theme_constant_override("separation", 4)
	outer.add_child(_shop_content)

	_shop_rebuild()

	_shop_dialog.confirmed.connect(func(): _shop_dialog.queue_free())
	add_child(_shop_dialog)
	_shop_dialog.popup_centered(Vector2(420, 540))

func _shop_switch_tab(idx: int) -> void:
	_shop_active_tab = idx
	for i in range(_shop_tab_btns.size()):
		_shop_tab_btns[i].add_theme_color_override("font_color",
			RimvaleColors.ACCENT if i == idx else RimvaleColors.TEXT_GRAY)
	_shop_rebuild()

func _shop_rebuild() -> void:
	for c in _shop_content.get_children():
		c.queue_free()
	if _shop_active_tab == 0:
		_shop_rebuild_buy()
	else:
		_shop_rebuild_sell()

func _shop_rebuild_buy() -> void:
	# Category filter chips
	var cat_scroll = ScrollContainer.new()
	cat_scroll.custom_minimum_size = Vector2(0, 34)
	cat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop_content.add_child(cat_scroll)

	var cat_row = HBoxContainer.new()
	cat_row.add_theme_constant_override("separation", 6)
	cat_scroll.add_child(cat_row)

	for cat_n in ["Weapons", "Armor", "Consumable", "Magic", "Misc"]:
		var cn_cap: String = cat_n
		var cc: Color = RimvaleColors.ACCENT if cat_n == _shop_buy_cat else RimvaleColors.TEXT_GRAY
		var chip = RimvaleUtils.button(cat_n, cc, 30, 11)
		chip.pressed.connect(func():
			_shop_buy_cat = cn_cap
			_shop_rebuild()
		)
		cat_row.add_child(chip)

	# Item list
	var item_scroll = ScrollContainer.new()
	item_scroll.custom_minimum_size = Vector2(0, 340)
	item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop_content.add_child(item_scroll)

	var item_vbox = VBoxContainer.new()
	item_vbox.add_theme_constant_override("separation", 2)
	item_scroll.add_child(item_vbox)

	var mundane_raw = _e.get_all_registry_mundane_items()
	var magic_raw = _e.get_all_registry_magic_items()

	var combined: Array = []
	for n in mundane_raw:
		combined.append([str(n), false])
	for n in magic_raw:
		combined.append([str(n), true])
	combined.sort_custom(func(a, b): return a[0] < b[0])

	var any_shown: bool = false
	for entry in combined:
		var iname: String   = entry[0]
		var imagical: bool  = entry[1]
		var det = _e.get_registry_item_details(iname)
		var icost: int      = int(str(det[3])) if det.size() > 3 else 0
		var itype: String   = str(det[4]) if det.size() > 4 else "General"
		var idesc: String   = str(det[det.size() - 1]) if det.size() > 5 else ""

		var cat_ok: bool = false
		match _shop_buy_cat:
			"Weapons":    cat_ok = itype == "Weapon" and not imagical
			"Armor":      cat_ok = (itype == "Armor" or itype == "Shield") and not imagical
			"Consumable": cat_ok = itype == "Consumable" and not imagical
			"Magic":      cat_ok = imagical
			"Misc":       cat_ok = itype != "Weapon" and itype != "Armor" and itype != "Shield" and itype != "Consumable" and not imagical
		if not cat_ok:
			continue

		any_shown = true
		var in_cap: String  = iname
		var ic_cap: int     = icost
		var dc_cap: String  = idesc

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 44)
		item_vbox.add_child(row)

		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)
		info.add_child(RimvaleUtils.label(in_cap, 13, RimvaleColors.TEXT_WHITE))
		var sub: String = "%d GP" % ic_cap
		if not dc_cap.is_empty():
			sub += "  ·  " + dc_cap.left(48)
		info.add_child(RimvaleUtils.label(sub, 10, RimvaleColors.TEXT_DIM))

		var buy_btn = RimvaleUtils.button("Buy", RimvaleColors.GOLD, 34, 12)
		buy_btn.pressed.connect(func():
			if GameState.spend_gold(ic_cap):
				GameState.add_to_stash(in_cap)
			else:
				OS.alert("Not enough gold!", "Marketplace")
		)
		row.add_child(buy_btn)
		item_vbox.add_child(RimvaleUtils.separator())

	if not any_shown:
		item_vbox.add_child(RimvaleUtils.label("Nothing available in this category.", 13, RimvaleColors.TEXT_DIM))

func _shop_rebuild_sell() -> void:
	var sell_scroll = ScrollContainer.new()
	sell_scroll.custom_minimum_size = Vector2(0, 380)
	sell_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop_content.add_child(sell_scroll)

	var sell_vbox = VBoxContainer.new()
	sell_vbox.add_theme_constant_override("separation", 2)
	sell_scroll.add_child(sell_vbox)

	if GameState.stash.is_empty():
		sell_vbox.add_child(RimvaleUtils.label("No items in stash to sell.", 13, RimvaleColors.TEXT_DIM))
		return

	for item_n in GameState.stash:
		var det = _e.get_registry_item_details(item_n)
		var cost_val: int = int(str(det[3])) if det.size() > 3 else 0
		var sell_val: int = cost_val / 2

		var in_cap: String = item_n
		var sv_cap: int    = sell_val

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 44)
		sell_vbox.add_child(row)

		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)
		info.add_child(RimvaleUtils.label(in_cap, 13, RimvaleColors.TEXT_WHITE))
		info.add_child(RimvaleUtils.label("Sell value: %d GP" % sv_cap, 10, RimvaleColors.GOLD))

		var sell_btn = RimvaleUtils.button("Sell", RimvaleColors.DANGER, 34, 12)
		sell_btn.pressed.connect(func():
			GameState.remove_from_stash(in_cap)
			GameState.earn_gold(sv_cap)
			_shop_rebuild()
		)
		row.add_child(sell_btn)
		sell_vbox.add_child(RimvaleUtils.separator())

# ── Helpers ───────────────────────────────────────────────────────────────────

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"Common":    return Color(0.30, 0.69, 0.31)
		"Uncommon":  return Color(0.13, 0.59, 0.95)
		"Rare":      return Color(0.61, 0.15, 0.69)
		"Very Rare": return Color(1.0, 0.60, 0.0)
		"Legendary": return Color(0.96, 0.26, 0.21)
		"Apex":      return Color(1.0, 0.92, 0.23)
	return RimvaleColors.TEXT_DIM

func _attunement_cost(rarity: String) -> int:
	match rarity:
		"Common":    return 1
		"Uncommon":  return 2
		"Rare":      return 3
		"Very Rare": return 4
		"Legendary": return 5
		"Apex":      return 5
	return 0

func _show_notice(msg: String) -> void:
	var toast: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.ACCENT, 12, 14)
	var lbl: Label = RimvaleUtils.label(msg, 14, RimvaleColors.TEXT_WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_child(lbl)
	toast.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast.offset_bottom = -60
	toast.offset_top = -110
	toast.offset_left = 40
	toast.offset_right = -40
	add_child(toast)
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(toast):
			toast.queue_free()
	)
