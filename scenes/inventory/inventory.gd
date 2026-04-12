## inventory.gd
## Full Equip Agent screen — port of InventoryScreen.kt + EquipmentTab
## Equipped slots, Inventory/Stash tabs with category filters, shop, transfer

extends Control

# ── State ─────────────────────────────────────────────────────────────────────

var _e: RimvaleEngine
var _handle: int = -1
var _active_tab: int = 0       # 0=Inventory  1=Stash
var _inv_filter: String = "All"
var _stash_filter: String = "All"

# ── Stored UI refs ────────────────────────────────────────────────────────────

var _equipped_row: HBoxContainer
var _item_list: VBoxContainer
var _tab_btns: Array = []
var _filter_hbox: HBoxContainer

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
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# ── Header ──
	var hdr := ColorRect.new()
	hdr.color = RimvaleColors.BG_CARD
	hdr.custom_minimum_size = Vector2(0, 60)
	root.add_child(hdr)

	var hmgn := MarginContainer.new()
	hmgn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		hmgn.add_theme_constant_override("margin_" + s, 12)
	hdr.add_child(hmgn)

	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 12)
	hmgn.add_child(hrow)

	var char_name: String = str(_e.get_character_name(_handle)) if _handle != -1 else "No Hero"
	hrow.add_child(RimvaleUtils.label("🎒 Gear — " + char_name, 20, RimvaleColors.ACCENT))

	var gold_lbl := RimvaleUtils.label("💰 %d GP" % GameState.gold, 15, RimvaleColors.GOLD)
	gold_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(gold_lbl)

	var back_btn := RimvaleUtils.button("← Back", RimvaleColors.TEXT_GRAY, 40, 13)
	back_btn.pressed.connect(func():
		get_parent().get_parent().pop_screen()
	)
	hrow.add_child(back_btn)

	# ── Equipped slots ──
	var eq_mgn := MarginContainer.new()
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
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 0)
	root.add_child(tab_row)
	for ti in range(2):
		var ti_cap: int = ti
		var tlabel: String = "Inventory" if ti == 0 else "Stash"
		var tbtn := RimvaleUtils.button(tlabel,
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
	var filter_scroll := ScrollContainer.new()
	filter_scroll.custom_minimum_size = Vector2(0, 36)
	filter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(filter_scroll)

	_filter_hbox = HBoxContainer.new()
	_filter_hbox.add_theme_constant_override("separation", 8)
	var filter_mgn := MarginContainer.new()
	for s in ["left", "right"]:
		filter_mgn.add_theme_constant_override("margin_" + s, 12)
	filter_scroll.add_child(filter_mgn)
	filter_mgn.add_child(_filter_hbox)
	_rebuild_filter_chips()

	# ── Item list ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var list_mgn := MarginContainer.new()
	for s in ["left", "right"]:
		list_mgn.add_theme_constant_override("margin_" + s, 12)
	list_mgn.add_theme_constant_override("margin_top", 4)
	list_mgn.add_theme_constant_override("margin_bottom", 8)
	list_mgn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_mgn)

	_item_list = VBoxContainer.new()
	_item_list.add_theme_constant_override("separation", 4)
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_mgn.add_child(_item_list)

	_rebuild_items()

	# ── Open Market button ──
	var shop_mgn := MarginContainer.new()
	for s in ["left", "right", "bottom"]:
		shop_mgn.add_theme_constant_override("margin_" + s, 12)
	root.add_child(shop_mgn)

	var shop_btn := RimvaleUtils.button("🛒 Open Market", RimvaleColors.GOLD, 48, 15)
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

	var slots_data := [
		["⚔ Weapon", weapon, 0],
		["🛡 Armor",  armor,  1],
		["🔰 Shield", shield, 2]
	]

	for sd in slots_data:
		var slot_lbl: String = sd[0]
		var item_name: String = sd[1]
		var slot_idx: int = sd[2]

		var card := ColorRect.new()
		card.color = Color(0.10, 0.14, 0.20, 1.0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 66)

		var cmgn := MarginContainer.new()
		cmgn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for s in ["left", "right", "top", "bottom"]:
			cmgn.add_theme_constant_override("margin_" + s, 8)
		card.add_child(cmgn)

		var cvbox := VBoxContainer.new()
		cvbox.add_theme_constant_override("separation", 3)
		cmgn.add_child(cvbox)

		cvbox.add_child(RimvaleUtils.label(slot_lbl, 11, RimvaleColors.TEXT_DIM))

		var is_empty: bool = item_name.is_empty()
		cvbox.add_child(RimvaleUtils.label(
			item_name if not is_empty else "None",
			12,
			RimvaleColors.TEXT_WHITE if not is_empty else RimvaleColors.TEXT_DIM))

		if not is_empty:
			var si_cap: int = slot_idx
			var x_btn := RimvaleUtils.button("✕", RimvaleColors.DANGER, 22, 10)
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
	for cat in ["All", "Weapons", "Armor", "Magic", "Misc"]:
		var cat_cap: String = cat
		var cc: Color = RimvaleColors.ACCENT if cat == active_filter else RimvaleColors.TEXT_GRAY
		var chip := RimvaleUtils.button(cat, cc, 30, 12)
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
	var items_raw := _e.get_inventory_items(_handle)

	# Separate magical / mundane for "All" or "Magic" filter display
	var magical_items: Array = []
	var mundane_items: Array = []

	for item_raw in items_raw:
		var item_name: String = str(item_raw)
		var details_raw := _e.get_item_details(_handle, item_name)
		var rarity: String = str(details_raw[0]) if details_raw.size() > 0 else "Mundane"
		var cur_hp: int = int(str(details_raw[1])) if details_raw.size() > 1 else 0
		var max_hp: int = int(str(details_raw[2])) if details_raw.size() > 2 else 0
		var cost: int = int(str(details_raw[3])) if details_raw.size() > 3 else 0
		var item_type: String = str(details_raw[4]) if details_raw.size() > 4 else "General"
		var desc: String = ""
		if details_raw.size() > 5:
			desc = str(details_raw[details_raw.size() - 1])
		var is_magical: bool = rarity != "Mundane"

		var item_data := {
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
			"Misc":    show = item_type != "Weapon" and item_type != "Armor" and item_type != "Shield" and not is_magical

		if not show:
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
		_item_list.add_child(RimvaleUtils.label("✦ Magical", 12, RimvaleColors.ACCENT))
		for d in magical_items:
			_item_list.add_child(_build_item_row(d))

	if not mundane_items.is_empty() and not magical_items.is_empty() and (_inv_filter == "All" or _inv_filter == "Magic"):
		_item_list.add_child(RimvaleUtils.label("Mundane", 12, RimvaleColors.TEXT_DIM))

	for d in mundane_items:
		_item_list.add_child(_build_item_row(d))

func _build_item_row(d: Dictionary) -> Control:
	var item_name: String = d["name"]
	var rarity: String = d["rarity"]
	var cur_hp: int = d["cur_hp"]
	var max_hp: int = d["max_hp"]
	var item_type: String = d["type"]
	var desc: String = d["desc"]
	var is_magical: bool = d["magical"]
	var rarity_col: Color = _rarity_color(rarity)

	var card := ColorRect.new()
	card.color = Color(rarity_col, 0.05) if is_magical else Color(0.10, 0.10, 0.14, 1.0)
	card.custom_minimum_size = Vector2(0, 0)

	var mgn := MarginContainer.new()
	mgn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		mgn.add_theme_constant_override("margin_" + s, 10)
	card.add_child(mgn)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	mgn.add_child(vbox)

	# Title row
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)

	var name_prefix: String = "✦ " if is_magical else ""
	var name_lbl := RimvaleUtils.label(name_prefix + item_name, 14,
		rarity_col if is_magical else RimvaleColors.TEXT_WHITE)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_lbl)

	# Action buttons
	var in_cap: String = item_name
	if item_type == "Consumable":
		var use_btn := RimvaleUtils.button("Use", RimvaleColors.SUCCESS, 32, 12)
		use_btn.pressed.connect(func():
			_e.use_consumable(_handle, in_cap)
			_refresh_equipped()
			_rebuild_items()
		)
		title_row.add_child(use_btn)
	elif item_type != "General" and item_type != "Consumable":
		var eq_btn := RimvaleUtils.button("Equip", RimvaleColors.ACCENT, 32, 12)
		eq_btn.pressed.connect(func():
			_e.equip_item(_handle, in_cap)
			_refresh_equipped()
			_rebuild_items()
		)
		title_row.add_child(eq_btn)

	var transfer_btn := RimvaleUtils.button("→", RimvaleColors.TEXT_GRAY, 32, 12)
	transfer_btn.custom_minimum_size = Vector2(30, 0)
	transfer_btn.pressed.connect(func(): _show_transfer_dialog(in_cap))
	title_row.add_child(transfer_btn)

	var stash_btn := RimvaleUtils.button("Stash", RimvaleColors.TEXT_GRAY, 32, 12)
	stash_btn.pressed.connect(func():
		_e.remove_item_from_inventory(_handle, in_cap)
		GameState.add_to_stash(in_cap)
		_rebuild_items()
	)
	title_row.add_child(stash_btn)

	# Info row
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 12)
	vbox.add_child(info_row)

	info_row.add_child(RimvaleUtils.label(item_type, 10, RimvaleColors.TEXT_DIM))
	info_row.add_child(RimvaleUtils.label("Dur: %d/%d" % [cur_hp, max_hp], 10, RimvaleColors.TEXT_DIM))
	if is_magical:
		info_row.add_child(RimvaleUtils.label(rarity, 10, rarity_col))
		var attune_cost: int = _attunement_cost(rarity)
		if attune_cost > 0:
			info_row.add_child(RimvaleUtils.label("Attune: %d SP" % attune_cost, 10, RimvaleColors.SP_PURPLE))

	# Description (collapsible-like: show if short)
	if not desc.is_empty() and desc.length() < 200:
		var desc_lbl := RimvaleUtils.label(desc, 11, RimvaleColors.TEXT_GRAY)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_lbl)

	return card

func _build_stash_items() -> void:
	if GameState.stash.size() == 0:
		_item_list.add_child(RimvaleUtils.label("The stash is empty.", 13, RimvaleColors.TEXT_DIM))
		return

	var any_shown: bool = false
	for item_name in GameState.stash:
		var details_raw := _e.get_registry_item_details(item_name)
		var item_type: String = str(details_raw[4]) if details_raw.size() > 4 else "General"
		var rarity: String = str(details_raw[0]) if details_raw.size() > 0 else "Mundane"
		var is_magical: bool = rarity != "Mundane"

		var show: bool = _stash_filter == "All"
		match _stash_filter:
			"Weapons": show = item_type == "Weapon" and not is_magical
			"Armor":   show = (item_type == "Armor" or item_type == "Shield") and not is_magical
			"Magic":   show = is_magical
			"Misc":    show = item_type != "Weapon" and item_type != "Armor" and item_type != "Shield" and not is_magical

		if not show:
			continue

		any_shown = true
		var in_cap: String = item_name

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 46)
		_item_list.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)
		info.add_child(RimvaleUtils.label(item_name, 14, RimvaleColors.TEXT_WHITE))
		info.add_child(RimvaleUtils.label(item_type, 10, RimvaleColors.TEXT_DIM))

		var take_btn := RimvaleUtils.button("Take", RimvaleColors.SUCCESS, 36, 12)
		take_btn.pressed.connect(func():
			GameState.remove_from_stash(in_cap)
			_e.add_item_to_inventory(_handle, in_cap)
			_rebuild_items()
		)
		row.add_child(take_btn)

	if not any_shown:
		_item_list.add_child(RimvaleUtils.label("Nothing in this category.", 13, RimvaleColors.TEXT_DIM))

# ── Transfer Dialog ───────────────────────────────────────────────────────────

func _show_transfer_dialog(item_name: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Transfer " + item_name
	dialog.get_ok_button().text = "Cancel"

	var vbox := VBoxContainer.new()
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
		var row_btn := RimvaleUtils.button("%s  (%s Lv %d)" % [target_name, lin, lv],
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

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	_shop_dialog.add_child(outer)

	# Buy / Sell tab bar
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 0)
	outer.add_child(tab_row)

	for ti in range(2):
		var ti_cap: int = ti
		var tl: String = "Buy" if ti == 0 else "Sell"
		var tbtn := RimvaleUtils.button(tl,
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
	var cat_scroll := ScrollContainer.new()
	cat_scroll.custom_minimum_size = Vector2(0, 34)
	cat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop_content.add_child(cat_scroll)

	var cat_row := HBoxContainer.new()
	cat_row.add_theme_constant_override("separation", 6)
	cat_scroll.add_child(cat_row)

	for cat_n in ["Weapons", "Armor", "Magic", "Misc"]:
		var cn_cap: String = cat_n
		var cc: Color = RimvaleColors.ACCENT if cat_n == _shop_buy_cat else RimvaleColors.TEXT_GRAY
		var chip := RimvaleUtils.button(cat_n, cc, 30, 11)
		chip.pressed.connect(func():
			_shop_buy_cat = cn_cap
			_shop_rebuild()
		)
		cat_row.add_child(chip)

	# Item list
	var item_scroll := ScrollContainer.new()
	item_scroll.custom_minimum_size = Vector2(0, 340)
	item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop_content.add_child(item_scroll)

	var item_vbox := VBoxContainer.new()
	item_vbox.add_theme_constant_override("separation", 2)
	item_scroll.add_child(item_vbox)

	var mundane_raw := _e.get_all_registry_mundane_items()
	var magic_raw   := _e.get_all_registry_magic_items()

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
		var det             := _e.get_registry_item_details(iname)
		var icost: int      = int(str(det[3])) if det.size() > 3 else 0
		var itype: String   = str(det[4]) if det.size() > 4 else "General"
		var idesc: String   = str(det[det.size() - 1]) if det.size() > 5 else ""

		var cat_ok: bool = false
		match _shop_buy_cat:
			"Weapons": cat_ok = itype == "Weapon" and not imagical
			"Armor":   cat_ok = (itype == "Armor" or itype == "Shield") and not imagical
			"Magic":   cat_ok = imagical
			"Misc":    cat_ok = itype != "Weapon" and itype != "Armor" and itype != "Shield" and not imagical
		if not cat_ok:
			continue

		any_shown = true
		var in_cap: String  = iname
		var ic_cap: int     = icost
		var dc_cap: String  = idesc

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 44)
		item_vbox.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)
		info.add_child(RimvaleUtils.label(in_cap, 13, RimvaleColors.TEXT_WHITE))
		var sub: String = "%d GP" % ic_cap
		if not dc_cap.is_empty():
			sub += "  ·  " + dc_cap.left(48)
		info.add_child(RimvaleUtils.label(sub, 10, RimvaleColors.TEXT_DIM))

		var buy_btn := RimvaleUtils.button("Buy", RimvaleColors.GOLD, 34, 12)
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
	var sell_scroll := ScrollContainer.new()
	sell_scroll.custom_minimum_size = Vector2(0, 380)
	sell_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop_content.add_child(sell_scroll)

	var sell_vbox := VBoxContainer.new()
	sell_vbox.add_theme_constant_override("separation", 2)
	sell_scroll.add_child(sell_vbox)

	if GameState.stash.is_empty():
		sell_vbox.add_child(RimvaleUtils.label("No items in stash to sell.", 13, RimvaleColors.TEXT_DIM))
		return

	for item_n in GameState.stash:
		var det      := _e.get_registry_item_details(item_n)
		var cost_val: int = int(str(det[3])) if det.size() > 3 else 0
		var sell_val: int = cost_val / 2

		var in_cap: String = item_n
		var sv_cap: int    = sell_val

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 44)
		sell_vbox.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)
		info.add_child(RimvaleUtils.label(in_cap, 13, RimvaleColors.TEXT_WHITE))
		info.add_child(RimvaleUtils.label("Sell value: %d GP" % sv_cap, 10, RimvaleColors.GOLD))

		var sell_btn := RimvaleUtils.button("Sell", RimvaleColors.DANGER, 34, 12)
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
