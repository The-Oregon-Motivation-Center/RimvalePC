## shop.gd
## Market — Buy items with gold, sell from inventory.

extends Control

var _e: RimvaleEngine
var _content_area: Control
var _gold_label: Label
var _items_list: VBoxContainer
var _current_tab: int = 0
var _shop_items: Array = []  # Array of {name, type, price, category}

func _ready() -> void:
	_e = RimvaleAPI.engine
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RimvaleUtils.add_bg(self, RimvaleColors.BG_DARK)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# ── Header ──
	var hdr := ColorRect.new()
	hdr.color = RimvaleColors.BG_CARD
	hdr.custom_minimum_size = Vector2(0, 56)
	root.add_child(hdr)

	var hmgn := MarginContainer.new()
	hmgn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left","right","top","bottom"]:
		hmgn.add_theme_constant_override("margin_" + s, 10)
	hdr.add_child(hmgn)

	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 16)
	hmgn.add_child(hrow)

	hrow.add_child(RimvaleUtils.label("🛒 Market", 22, RimvaleColors.ACCENT))

	_gold_label = RimvaleUtils.label("💰 %d gold" % GameState.gold, 16, RimvaleColors.GOLD)
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(_gold_label)

	# ── Tab buttons ──
	var tab_row := HBoxContainer.new()
	tab_row.custom_minimum_size = Vector2(0, 46)
	tab_row.add_theme_constant_override("separation", 0)
	RimvaleUtils.add_bg(tab_row, RimvaleColors.BG_CARD_DARK)
	root.add_child(tab_row)

	for i in range(2):
		var lbl: String = ["Buy", "Sell"][i]
		var btn := RimvaleUtils.button(lbl,
			RimvaleColors.ACCENT if i == _current_tab else RimvaleColors.TEXT_GRAY, 46, 16)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.flat = true
		btn.pressed.connect(func(): _switch_tab(i))
		tab_row.add_child(btn)

	# Category filter (Buy only)
	var filter_row := HBoxContainer.new()
	filter_row.custom_minimum_size = Vector2(0, 40)
	filter_row.add_theme_constant_override("separation", 8)
	root.add_child(filter_row)

	var fmgn := MarginContainer.new()
	for s in ["left","right"]:
		fmgn.add_theme_constant_override("margin_" + s, 10)
	filter_row.add_child(fmgn)

	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 8)
	fmgn.add_child(chip_row)

	for cat in ["All", "Weapons", "Armor", "Magic", "Misc"]:
		var chip := RimvaleUtils.button(cat, RimvaleColors.TEXT_GRAY, 34, 13)
		chip.pressed.connect(func(): _filter_items(cat))
		chip_row.add_child(chip)

	# ── Item scroll ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_items_list = VBoxContainer.new()
	_items_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_items_list)

	_load_shop_items()
	_switch_tab(0)

func _switch_tab(idx: int) -> void:
	_current_tab = idx
	_refresh_list()

func _load_shop_items() -> void:
	_shop_items.clear()

	var magic_items: PackedStringArray = _e.get_all_registry_magic_items()
	for item_name in magic_items:
		_shop_items.append({
			"name": str(item_name),
			"type": "Magic",
			"price": randi_range(80, 500),
			"category": "Magic"
		})

	var mundane_items: PackedStringArray = _e.get_all_registry_mundane_items()
	var mundane_cats := ["Weapons", "Armor", "Misc"]
	for item_name in mundane_items:
		var cat: String = mundane_cats[randi() % mundane_cats.size()]
		_shop_items.append({
			"name": str(item_name),
			"type": cat,
			"price": randi_range(30, 250),
			"category": cat
		})

func _refresh_list(filter: String = "All") -> void:
	for child in _items_list.get_children():
		child.queue_free()

	if _current_tab == 0:
		_build_buy_list(filter)
	else:
		_build_sell_list()

func _build_buy_list(filter: String) -> void:
	for item in _shop_items:
		if filter != "All" and item["category"] != filter:
			continue

		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 52)
		row.add_theme_constant_override("separation", 10)

		var mgn := MarginContainer.new()
		for s in ["left","right"]:
			mgn.add_theme_constant_override("margin_" + s, 12)
		_items_list.add_child(mgn)

		var inner := HBoxContainer.new()
		inner.add_theme_constant_override("separation", 10)
		mgn.add_child(inner)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_child(info)
		info.add_child(RimvaleUtils.label(item["name"], 15, RimvaleColors.TEXT_WHITE))
		info.add_child(RimvaleUtils.label(item["type"], 12, RimvaleColors.TEXT_DIM))

		inner.add_child(RimvaleUtils.label("%dg" % item["price"], 15, RimvaleColors.GOLD))

		var price: int = item["price"]
		var name_: String = item["name"]
		var buy_btn := RimvaleUtils.button("Buy", RimvaleColors.ACCENT, 40, 13)
		buy_btn.pressed.connect(func(): _on_buy(name_, price))
		inner.add_child(buy_btn)

func _build_sell_list() -> void:
	var active := GameState.get_active_handles()
	if active.is_empty():
		_items_list.add_child(RimvaleUtils.label(
			"Add characters to your team to sell their items.", 14, RimvaleColors.TEXT_DIM))
		return

	var handle: int = active[0]
	var char_name: String = _e.get_character_name(handle)
	_items_list.add_child(RimvaleUtils.label("Selling from: " + char_name, 14, RimvaleColors.ACCENT))

	var items: PackedStringArray = _e.get_inventory_items(handle)
	if items.size() == 0:
		_items_list.add_child(RimvaleUtils.label("Inventory is empty.", 14, RimvaleColors.TEXT_DIM))
		return

	for item_name in items:
		var sell_price := randi_range(20, 100)
		var mgn := MarginContainer.new()
		for s in ["left","right"]:
			mgn.add_theme_constant_override("margin_" + s, 12)
		_items_list.add_child(mgn)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		mgn.add_child(row)

		var name_lbl := RimvaleUtils.label(str(item_name), 15, RimvaleColors.TEXT_WHITE)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		row.add_child(RimvaleUtils.label("%dg" % sell_price, 15, RimvaleColors.GOLD))

		var iname: String = str(item_name)
		var sell_btn := RimvaleUtils.button("Sell", RimvaleColors.SUCCESS, 40, 13)
		sell_btn.pressed.connect(func():
			_e.remove_item_from_inventory(handle, iname)
			GameState.earn_gold(sell_price)
			_update_gold()
			_refresh_list()
		)
		row.add_child(sell_btn)

func _filter_items(cat: String) -> void:
	_refresh_list(cat)

func _on_buy(item_name: String, price: int) -> void:
	if not GameState.spend_gold(price):
		_show_notice("Not enough gold! (need %dg, have %dg)" % [price, GameState.gold])
		return
	var active := GameState.get_active_handles()
	if active.size() > 0:
		_e.add_item_to_inventory(active[0], item_name)
	_update_gold()
	_show_notice("Bought: %s for %dg" % [item_name, price])

func _update_gold() -> void:
	_gold_label.text = "💰 %d gold" % GameState.gold

func _show_notice(msg: String) -> void:
	var lbl := RimvaleUtils.label(msg, 14, RimvaleColors.TEXT_WHITE)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.offset_bottom = -60
	lbl.offset_top = lbl.offset_bottom - 36
	add_child(lbl)
	await get_tree().create_timer(2.0).timeout
	lbl.queue_free()
