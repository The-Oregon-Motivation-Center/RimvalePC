## shop.gd
## Market — Buy items with gold, sell from inventory.

extends Control

const _WS = preload("res://autoload/world_systems.gd")

var _e
var _content_area: Control
var _gold_label: Label
var _items_list: VBoxContainer
var _current_tab: int = 0
var _shop_items: Array = []  # Array of {name, type, price, category}
var _active_filter: String = "All"
var _shop_search: String = ""
var _filter_chips: Dictionary = {}  # cat -> Button
var _tab_btns: Array = []

func _ready() -> void:
	_e = RimvaleAPI.engine
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RimvaleUtils.add_bg(self, RimvaleColors.BG_DARK)

	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# ── Header ──
	var hdr_panel: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.DIVIDER, 0, 14)
	hdr_panel.custom_minimum_size = Vector2(0, 64)
	root.add_child(hdr_panel)

	var hrow = HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 14)
	hdr_panel.add_child(hrow)

	var title_lbl = RimvaleUtils.label("🛒  Market", 22, RimvaleColors.ACCENT)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(title_lbl)

	# Show current region's government type and effect
	var current_region: String = GameState.current_region
	var gov_type: String = _WS.REGION_GOVERNMENTS.get(current_region, "unknown")
	var gov_data: Dictionary = _WS.GOVERNMENT_TYPES.get(gov_type, {})
	var gov_name: String = gov_data.get("name", gov_type)
	var gov_info: String = "%s (+%.0f%% prices)" % [gov_name, (gov_data.get("price_mod", 1.0) - 1.0) * 100]
	var gov_pill: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD_DARK, RimvaleColors.ACCENT, 12, 8)
	var gov_lbl: Label = RimvaleUtils.label(gov_info, 12, RimvaleColors.TEXT_GRAY)
	gov_pill.add_child(gov_lbl)
	hrow.add_child(gov_pill)

	var gold_pill: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD_DARK, RimvaleColors.GOLD, 16, 10)
	_gold_label = RimvaleUtils.label("💰  %d gold" % GameState.gold, 15, RimvaleColors.GOLD)
	gold_pill.add_child(_gold_label)
	hrow.add_child(gold_pill)

	# ── Tab buttons (Buy / Sell) ──
	var tab_outer = MarginContainer.new()
	for s in ["left","right"]:
		tab_outer.add_theme_constant_override("margin_" + s, 10)
	tab_outer.add_theme_constant_override("margin_top", 10)
	root.add_child(tab_outer)

	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	tab_outer.add_child(tab_row)

	_tab_btns.clear()
	for i in range(2):
		var lbl: String = ["🛍  Buy", "💼  Sell"][i]
		var btn = RimvaleUtils.chip(lbl, i == _current_tab, 14)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 42)
		var idx_cap: int = i
		btn.pressed.connect(func(): _switch_tab(idx_cap))
		tab_row.add_child(btn)
		_tab_btns.append(btn)

	# ── Category filter ──
	var fmgn = MarginContainer.new()
	for s in ["left","right"]:
		fmgn.add_theme_constant_override("margin_" + s, 10)
	fmgn.add_theme_constant_override("margin_top", 8)
	root.add_child(fmgn)

	var chip_row = HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 6)
	fmgn.add_child(chip_row)

	for cat in ["All", "Weapons", "Armor", "Consumable", "Magic", "Misc"]:
		var cat_cap: String = cat
		var chip = RimvaleUtils.chip(cat, cat == _active_filter, 11)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.pressed.connect(func(): _filter_items(cat_cap))
		chip_row.add_child(chip)
		_filter_chips[cat] = chip

	# ── Search box ──
	var search_mgn = MarginContainer.new()
	for s in ["left","right"]:
		search_mgn.add_theme_constant_override("margin_" + s, 10)
	search_mgn.add_theme_constant_override("margin_top", 8)
	root.add_child(search_mgn)

	var search_input = LineEdit.new()
	search_input.placeholder_text = "Search items..."
	search_input.text = _shop_search
	search_input.clear_button_enabled = true
	search_input.custom_minimum_size = Vector2(0, 36)
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.add_theme_font_size_override("font_size", 14)
	search_input.add_theme_color_override("font_color", RimvaleColors.TEXT_WHITE)
	search_input.add_theme_color_override("font_placeholder_color", RimvaleColors.TEXT_DIM)
	var search_sb = StyleBoxFlat.new()
	search_sb.bg_color = Color(0.16, 0.14, 0.24, 1.0)
	search_sb.border_color = Color(0.5, 0.5, 0.6, 0.4)
	search_sb.set_border_width_all(1)
	search_sb.set_corner_radius_all(6)
	search_sb.set_content_margin_all(8)
	search_input.add_theme_stylebox_override("normal", search_sb)
	var search_sb_focus = search_sb.duplicate()
	search_sb_focus.border_color = RimvaleColors.ACCENT
	search_input.add_theme_stylebox_override("focus", search_sb_focus)
	search_input.text_changed.connect(func(new_text: String):
		_shop_search = new_text.to_lower()
		_refresh_list()
	)
	search_mgn.add_child(search_input)

	# ── Item scroll ──
	var scroll_mgn = MarginContainer.new()
	scroll_mgn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for s in ["left","right","top","bottom"]:
		scroll_mgn.add_theme_constant_override("margin_" + s, 10)
	root.add_child(scroll_mgn)

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_mgn.add_child(scroll)

	_items_list = VBoxContainer.new()
	_items_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_items_list)

	_load_shop_items()
	_switch_tab(0)

func _switch_tab(idx: int) -> void:
	_current_tab = idx
	# Rebuild tab chips with active state baked into their stylebox
	for i in range(_tab_btns.size()):
		var active: bool = (i == idx)
		var lbl: String = ["🛍  Buy", "💼  Sell"][i]
		var new_chip: Button = RimvaleUtils.chip(lbl, active, 14)
		new_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		new_chip.custom_minimum_size = Vector2(0, 42)
		var idx_cap: int = i
		new_chip.pressed.connect(func(): _switch_tab(idx_cap))
		var old: Button = _tab_btns[i]
		old.replace_by(new_chip)
		_tab_btns[i] = new_chip
	_refresh_list()

## Returns the item's price from the registry.  Falls back to a hash-based
## estimate only when the item is not in the registry (e.g. quest rewards).
## Applies regional price modifiers and government tax modifiers.
func _get_item_price(item_name: String, category: String) -> int:
	var details: PackedStringArray = _e.get_registry_item_details(item_name)
	var registry_price: int = 0
	if details.size() >= 4:
		registry_price = int(details[3])
		if registry_price <= 0:
			# Fallback for unknown items — should rarely trigger
			var h: int = 0
			for c in item_name:
				h = (h * 31 + c.unicode_at(0)) & 0x7FFFFFFF
			registry_price = 10 + (h % 141)
	else:
		# Fallback for unknown items — should rarely trigger
		var h: int = 0
		for c in item_name:
			h = (h * 31 + c.unicode_at(0)) & 0x7FFFFFFF
		registry_price = 10 + (h % 141)

	# Apply regional price modifier based on category
	var current_region: String = GameState.current_region
	var regional_mods: Dictionary = _WS.REGIONAL_PRICE_MODIFIERS.get(current_region, {})
	var category_key: String = _map_category_to_modifier_key(category)
	var regional_mod: float = regional_mods.get(category_key, 1.0)

	# Apply government tax/price modifier
	var gov_type: String = _WS.REGION_GOVERNMENTS.get(current_region, "monarchy")
	var gov_data: Dictionary = _WS.GOVERNMENT_TYPES.get(gov_type, {})
	var gov_mod: float = gov_data.get("price_mod", 1.0)

	# Calculate final price with both modifiers
	var final_price: float = float(registry_price) * regional_mod * gov_mod
	return maxi(1, int(final_price))

## Map shop categories to regional price modifier keys
func _map_category_to_modifier_key(category: String) -> String:
	match category:
		"Weapons":    return "weapons"
		"Armor":      return "armor"
		"Consumable": return "potions"
		"Magic":      return "luxury"
		"Misc":       return "food"
		_:            return "food"

## Sell price is 50% of buy price, reduced by durability loss.
## Broken items sell for 10% of base. Damaged items scale linearly between 10%-100%.
func _get_sell_price(item_name: String, hp_override: int = -1) -> int:
	var cat: String = _item_category(item_name)
	var base_sell: int = maxi(5, int(_get_item_price(item_name, cat) * 0.50))
	# Check durability — hp_override of -1 means full HP
	if hp_override == -1:
		return base_sell
	var max_hp: int = 0
	if cat == "Weapons":
		max_hp = _e._weapon_max_hp(item_name)
	elif cat == "Armor":
		max_hp = _e._armor_max_hp(item_name)
	if max_hp <= 0:
		return base_sell
	# Scale: full HP = 100%, 0 HP (broken) = 10%, linearly between
	var hp_ratio: float = clampf(float(maxi(0, hp_override)) / float(max_hp), 0.0, 1.0)
	var dur_mult: float = 0.10 + hp_ratio * 0.90  # 10% at 0 HP, 100% at full
	return maxi(1, int(base_sell * dur_mult))

## Determine category — first consults the item registry, then falls back to keywords.
func _item_category(item_name: String) -> String:
	var details: PackedStringArray = _e.get_registry_item_details(item_name)
	if details.size() >= 5:
		var reg_type: String = str(details[4])
		var reg_rarity: String = str(details[0]) if details.size() > 0 else "Mundane"
		if reg_rarity != "Mundane":
			return "Magic"
		match reg_type:
			"Weapon":     return "Weapons"
			"Armor":      return "Armor"
			"Shield":     return "Armor"
			"Consumable": return "Consumable"
			"Magic":      return "Magic"
			"Misc":       return "Misc"
			_:            return "Misc"
	var n: String = item_name.to_lower()
	if "sword" in n or "axe" in n or "bow" in n or "dagger" in n or \
	   "spear" in n or "staff" in n or "mace" in n or "blade" in n or \
	   "hammer" in n or "pistol" in n or "rifle" in n or "lance" in n or \
	   "rapier" in n or "scimitar" in n or "katana" in n or "glaive" in n or \
	   "halberd" in n or "maul" in n or "flail" in n or "pike" in n or \
	   "trident" in n or "whip" in n or "sickle" in n or "chakram" in n or \
	   "club" in n or "javelin" in n or "dart" in n or "sling" in n or \
	   "crossbow" in n or "musket" in n or "blowgun" in n or "morningstar" in n or \
	   "war pick" in n or "war_pick" in n:
		return "Weapons"
	if "shield" in n or "plate" in n or "mail" in n or "armor" in n or \
	   "leather" in n or "padded" in n or "hide" in n or "splint" in n or \
	   "breastplate" in n or "studded" in n or "chainmail" in n or "helm" in n or \
	   "robes" in n or "cloak" in n or "gauntlet" in n:
		return "Armor"
	if "potion" in n or "flask" in n or "elixir" in n or "draught" in n or \
	   "shot" in n or "tonic" in n or "vial" in n:
		return "Consumable"
	if "wand" in n or "orb" in n or "amulet" in n or "ring" in n or \
	   "scroll" in n or "tome" in n or "crystal" in n or "rune" in n or \
	   "essence" in n or "shard" in n:
		return "Magic"
	return "Misc"

func _load_shop_items() -> void:
	_shop_items.clear()
	var all_items: Array = []
	for iname_raw in _e.get_all_registry_magic_items():
		all_items.append(str(iname_raw))
	for iname_raw in _e.get_all_registry_mundane_items():
		all_items.append(str(iname_raw))

	for iname in all_items:
		var details: PackedStringArray = _e.get_registry_item_details(iname)
		var reg_type: String = str(details[4]) if details.size() >= 5 else ""
		var reg_rarity: String = str(details[0]) if details.size() > 0 else "Mundane"
		var cat: String
		if reg_rarity != "Mundane":
			cat = "Magic"
		elif reg_type != "":
			# Trust the registry type — don't fall through to keyword guessing
			match reg_type:
				"Weapon":     cat = "Weapons"
				"Armor":      cat = "Armor"
				"Shield":     cat = "Armor"
				"Consumable": cat = "Consumable"
				"Magic":      cat = "Magic"
				_:            cat = "Misc"  # Misc, Tool, Light, etc. all go to Misc
		else:
			# No registry data at all — keyword fallback as last resort
			cat = _item_category(iname)
		_shop_items.append({
			"name":     iname,
			"type":     cat,
			"price":    _get_item_price(iname, cat),
			"category": cat
		})

func _refresh_list(filter: String = "") -> void:
	for child in _items_list.get_children():
		child.queue_free()
	if _current_tab == 0:
		_build_buy_list(filter if not filter.is_empty() else _active_filter)
	else:
		_build_sell_list()

## Builds one item row as a card with icon, name, description, price, and action.
## Left half: icon + item info.  Right half: price + buy/sell button (aligned at ~50%).
func _build_item_card(item_name: String, category: String, price: int,
		action_label: String, action_col: Color, on_action: Callable) -> PanelContainer:
	var card_p: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD_DARK, RimvaleColors.DIVIDER, 10, 10)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card_p.add_child(row)

	# ── Left half: icon + name/description ──
	var left_col = HBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 1.0
	left_col.add_theme_constant_override("separation", 10)
	row.add_child(left_col)

	# Category icon
	left_col.add_child(RimvaleUtils.category_icon(category))

	# Name + description + type
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 2)
	left_col.add_child(info)
	var name_lbl: Label = RimvaleUtils.label(item_name, 15, RimvaleColors.TEXT_WHITE)
	name_lbl.clip_text = true
	info.add_child(name_lbl)

	# Pull description from registry (last element of details array)
	var details: PackedStringArray = _e.get_registry_item_details(item_name)
	if details.size() >= 1:
		var desc_text: String = str(details[details.size() - 1])
		if desc_text.length() > 0:
			var desc_lbl: Label = RimvaleUtils.label(desc_text, 11, RimvaleColors.TEXT_GRAY)
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info.add_child(desc_lbl)

	info.add_child(RimvaleUtils.label(category, 11, RimvaleColors.TEXT_GRAY))

	# ── Right half: price + action button ──
	var right_col = HBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 1.0
	right_col.add_theme_constant_override("separation", 12)
	right_col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right_col)

	# Price pill
	var price_pill: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_DARK, RimvaleColors.GOLD, 12, 8)
	var price_lbl: Label = RimvaleUtils.label("%d g" % price, 14, RimvaleColors.GOLD)
	price_pill.add_child(price_lbl)
	right_col.add_child(price_pill)

	# Action button (Buy / Sell)
	var action_btn: Button = RimvaleUtils.chip(action_label, true, 13)
	action_btn.custom_minimum_size = Vector2(90, 38)
	var sb: StyleBoxFlat = action_btn.get_theme_stylebox("normal").duplicate()
	sb.bg_color = action_col
	sb.border_color = action_col
	action_btn.add_theme_stylebox_override("normal", sb)
	var hover_sb: StyleBoxFlat = sb.duplicate()
	hover_sb.bg_color = action_col.lightened(0.12)
	action_btn.add_theme_stylebox_override("hover", hover_sb)
	action_btn.add_theme_color_override("font_color", RimvaleColors.TEXT_WHITE)
	action_btn.add_theme_color_override("font_hover_color", RimvaleColors.TEXT_WHITE)
	action_btn.pressed.connect(on_action)
	right_col.add_child(action_btn)

	return card_p

func _build_buy_list(filter: String) -> void:
	var any_rows: bool = false
	for item in _shop_items:
		if filter != "All" and item["category"] != filter:
			continue
		if _shop_search != "" and _shop_search not in item["name"].to_lower():
			continue
		any_rows = true
		var iname: String = item["name"]
		var iprice: int = item["price"]
		var icat: String = item["category"]
		var card_p: PanelContainer = _build_item_card(
			iname, icat, iprice, "Buy", RimvaleColors.SUCCESS,
			func(): _on_buy(iname, iprice))
		_items_list.add_child(card_p)

	if not any_rows:
		var empty_card: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD_DARK, RimvaleColors.DIVIDER, 10, 20)
		var empty_lbl: Label = RimvaleUtils.label("No items in this category.", 14, RimvaleColors.TEXT_DIM)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_card.add_child(empty_lbl)
		_items_list.add_child(empty_card)

func _build_sell_list() -> void:
	var any_items: bool = false

	# ── Stash items ─────────────────────────────────────────────────────────────
	if not GameState.stash.is_empty():
		any_items = true
		_items_list.add_child(RimvaleUtils.label("📥  STASH", 12, RimvaleColors.ACCENT))
		var stash_copy: Array = GameState.stash.duplicate()
		# Build an index counter per item name so we can look up the right HP copy
		var _hp_idx: Dictionary = {}
		for item_name in stash_copy:
			var iname: String = str(item_name)
			if _shop_search != "" and _shop_search not in iname.to_lower():
				_hp_idx[iname] = int(_hp_idx.get(iname, 0)) + 1
				continue
			var copy_idx: int = int(_hp_idx.get(iname, 0))
			_hp_idx[iname] = copy_idx + 1
			var item_hp: int = GameState.get_stash_item_hp(iname, copy_idx)
			var sell_price: int = _get_sell_price(iname, item_hp)
			var cat_: String = _item_category(iname)
			# Build display name with durability info
			var display_name: String = iname
			var max_hp: int = _e._weapon_max_hp(iname) if cat_ == "Weapons" else _e._armor_max_hp(iname)
			if max_hp > 0 and item_hp >= 0:
				display_name += "  [%d/%d HP]" % [maxi(0, item_hp), max_hp]
			var cap_sell: int = sell_price
			var card_p: PanelContainer = _build_item_card(
				display_name, cat_, sell_price, "Sell", RimvaleColors.SUCCESS,
				func():
					GameState.remove_from_stash(iname)
					GameState.earn_gold(cap_sell)
					GameState.save_game()
					_update_gold()
					_refresh_list()
			)
			_items_list.add_child(card_p)

	# ── First active hero's inventory ────────────────────────────────────────────
	var active := GameState.get_active_handles()
	if not active.is_empty():
		var handle: int    = active[0]
		var char_name: String = _e.get_character_name(handle)
		_items_list.add_child(RimvaleUtils.spacer(6))
		_items_list.add_child(RimvaleUtils.label(
			"🎒  %s'S INVENTORY" % char_name.to_upper(), 12, RimvaleColors.ACCENT))
		var items: PackedStringArray = _e.get_inventory_items(handle)
		if items.size() > 0:
			any_items = true
			for item_name in items:
				var iname: String = str(item_name)
				if _shop_search != "" and _shop_search not in iname.to_lower():
					continue
				var sell_price: int = _get_sell_price(iname)
				var cat_: String = _item_category(iname)
				var card_p: PanelContainer = _build_item_card(
					iname, cat_, sell_price, "Sell", RimvaleColors.SUCCESS,
					func():
						_e.remove_item_from_inventory(handle, iname)
						GameState.earn_gold(sell_price)
						_update_gold()
						_refresh_list()
				)
				_items_list.add_child(card_p)
		else:
			var empty_card: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD_DARK, RimvaleColors.DIVIDER, 10, 14)
			var empty_lbl: Label = RimvaleUtils.label("Inventory is empty.", 13, RimvaleColors.TEXT_DIM)
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_card.add_child(empty_lbl)
			_items_list.add_child(empty_card)

	if not any_items:
		var empty_card: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD_DARK, RimvaleColors.DIVIDER, 10, 20)
		var empty_lbl: Label = RimvaleUtils.label(
			"Nothing to sell — complete dungeons to earn loot!", 14, RimvaleColors.TEXT_DIM)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_card.add_child(empty_lbl)
		_items_list.add_child(empty_card)

func _filter_items(cat: String) -> void:
	_active_filter = cat
	for c in _filter_chips.keys():
		var old: Button = _filter_chips[c]
		var c_cap: String = c
		var new_chip: Button = RimvaleUtils.chip(c, c == cat, 11)
		new_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		new_chip.pressed.connect(func(): _filter_items(c_cap))
		old.replace_by(new_chip)
		_filter_chips[c] = new_chip
	_refresh_list(cat)

func _on_buy(item_name: String, price: int) -> void:
	if not GameState.spend_gold(price):
		_show_notice("Not enough gold! (need %dg, have %dg)" % [price, GameState.gold])
		return
	GameState.add_to_stash(item_name)
	_update_gold()
	_show_notice("Bought: %s for %dg → Stash" % [item_name, price])

func _update_gold() -> void:
	_gold_label.text = "💰  %d gold" % GameState.gold

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
	await get_tree().create_timer(2.0).timeout
	toast.queue_free()
