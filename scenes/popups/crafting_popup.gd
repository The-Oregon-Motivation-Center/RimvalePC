extends AcceptDialog
class_name CraftingPopup

# ─────────────────────────────────────────────────────────────────────────────
# Crafting popup for region-map POIs (Blacksmith).
# Mirrors world.gd::_build_crafting_tab but is fully self-contained — no shared
# state with world.gd. Safe to instance alongside world.gd's own crafting tab.
#
# Usage (from explore.gd):
#   var popup := preload("res://scenes/popups/crafting_popup.gd").new()
#   add_child(popup)
#   popup.popup_centered(Vector2i(680, 640))
# The popup cleans itself up via close/visibility signals.
# ─────────────────────────────────────────────────────────────────────────────

var _active_handles: Array = []
var _member_dd: OptionButton
var _type_dd: OptionButton
var _recipe_lbl: Label
var _tasks_vbox: VBoxContainer
var _repair_vbox: VBoxContainer
var _craftable_items: Array = []
var _refresh_timer: Timer

func _init() -> void:
	title = "Blacksmith — Crafting"
	min_size = Vector2i(680, 640)
	# AcceptDialog: hide the cancel, keep the OK/Close
	get_ok_button().text = "Close"
	# Clean up on close — Godot 4 uses visibility_changed / close_requested,
	# not Godot 3's popup_hide.
	visibility_changed.connect(_on_visibility_changed)
	close_requested.connect(queue_free)
	confirmed.connect(queue_free)

func _on_visibility_changed() -> void:
	if not visible:
		queue_free()

func _ready() -> void:
	# Root content container
	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	vbox.add_child(RimvaleUtils.label("Assign Crafting Tasks", 16, RimvaleColors.ACCENT))

	# ── Crafter dropdown ─────────────────────────────────────────────────────
	_active_handles = GameState.get_active_handles()
	if _active_handles.size() > 0:
		var mh := HBoxContainer.new()
		mh.add_child(RimvaleUtils.label("Crafter:", 12, RimvaleColors.TEXT_WHITE))
		_member_dd = OptionButton.new()
		for h in _active_handles:
			_member_dd.add_item(str(RimvaleAPI.engine.get_character_name(h)))
		_member_dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mh.add_child(_member_dd)
		vbox.add_child(mh)
	else:
		vbox.add_child(RimvaleUtils.label("No active party members.", 12, RimvaleColors.DANGER))

	# ── Recipe / item dropdown ───────────────────────────────────────────────
	_craftable_items = RimvaleAPI.engine.get_craftable_items()
	var th := HBoxContainer.new()
	th.add_child(RimvaleUtils.label("Item:", 12, RimvaleColors.TEXT_WHITE))
	_type_dd = OptionButton.new()
	for entry in _craftable_items:
		_type_dd.add_item(str(entry[0]))
	if _craftable_items.is_empty():
		for fb in ["Weapon", "Armor", "Potion", "Tool"]:
			_type_dd.add_item(fb)
	_type_dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(_type_dd)
	vbox.add_child(th)

	# ── Recipe detail (materials + duration) ─────────────────────────────────
	_recipe_lbl = RimvaleUtils.label("", 11, RimvaleColors.TEXT_GRAY)
	_recipe_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_recipe_lbl)
	_type_dd.item_selected.connect(_on_recipe_selected)
	if not _craftable_items.is_empty():
		_on_recipe_selected(0)

	# ── Start button ─────────────────────────────────────────────────────────
	var start_btn := RimvaleUtils.button("Start Crafting", RimvaleColors.GOLD, 44, 13)
	start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(start_btn)

	vbox.add_child(RimvaleUtils.separator())

	# ── Active tasks ─────────────────────────────────────────────────────────
	vbox.add_child(RimvaleUtils.label("Active Tasks", 14, RimvaleColors.ACCENT))
	_tasks_vbox = VBoxContainer.new()
	_tasks_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tasks_vbox)
	_refresh_tasks()

	vbox.add_child(RimvaleUtils.separator())

	# ── Repair list ──────────────────────────────────────────────────────────
	vbox.add_child(RimvaleUtils.label("Repair Equipment", 14, RimvaleColors.ACCENT))
	_repair_vbox = VBoxContainer.new()
	_repair_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_repair_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(_repair_vbox)
	_refresh_repair_list()

	# ── Refresh timer (1 s tick) ─────────────────────────────────────────────
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 1.0
	_refresh_timer.autostart = true
	_refresh_timer.timeout.connect(_refresh_tasks)
	add_child(_refresh_timer)

# ─────────────────────────────────────────────────────────────────────────────
# Handlers
# ─────────────────────────────────────────────────────────────────────────────

func _on_recipe_selected(idx: int) -> void:
	if idx < _craftable_items.size():
		var entry: PackedStringArray = _craftable_items[idx] as PackedStringArray
		var dur_sec: int = int(str(entry[2])) if entry.size() > 2 else 60
		var mins: int = dur_sec / 60
		var secs: int = dur_sec % 60
		var dur_str: String = ("%dm %ds" % [mins, secs]) if mins > 0 else ("%ds" % secs)
		_recipe_lbl.text = "Materials: %s  |  Time: %s" % [str(entry[1]), dur_str]
	else:
		_recipe_lbl.text = ""

func _on_start_pressed() -> void:
	if _active_handles.is_empty():
		push_warning("[Crafting Popup] No active party members")
		return
	var sel_idx: int = _member_dd.selected if _member_dd != null else 0
	sel_idx = clamp(sel_idx, 0, _active_handles.size() - 1)
	var handle: int = _active_handles[sel_idx]
	if GameState.is_busy(handle):
		push_warning("[Crafting Popup] Character is already busy")
		return
	var sel_item_idx: int = _type_dd.selected
	var item_type: String = _type_dd.get_item_text(sel_item_idx)
	var duration: float = 60.0
	if sel_item_idx < _craftable_items.size():
		var entry: PackedStringArray = _craftable_items[sel_item_idx] as PackedStringArray
		duration = float(int(str(entry[2]))) if entry.size() > 2 else 60.0
	var task: Dictionary = {
		"character_handle": handle,
		"character_name":   str(RimvaleAPI.engine.get_character_name(handle)),
		"item_type":        item_type,
		"end_time":         Time.get_unix_time_from_system() + duration,
	}
	GameState.crafting_tasks.append(task)
	GameState.set_busy(handle, true)
	_refresh_tasks()
	print("[Crafting Popup] %s started %s (%.0fs)" % [task["character_name"], item_type, duration])

func _refresh_tasks() -> void:
	if _tasks_vbox == null or not is_instance_valid(_tasks_vbox):
		return
	for c in _tasks_vbox.get_children():
		c.queue_free()
	if GameState.crafting_tasks.is_empty():
		_tasks_vbox.add_child(RimvaleUtils.label("No active crafting tasks.", 12, RimvaleColors.TEXT_GRAY))
		return
	var now: float = Time.get_unix_time_from_system()
	for task in GameState.crafting_tasks:
		var remaining: float = maxf(0.0, float(task["end_time"]) - now)
		var row := HBoxContainer.new()
		var info: String = "%s → %s  (%.0fs)" % [task["character_name"], task["item_type"], remaining]
		row.add_child(RimvaleUtils.label(info, 12, RimvaleColors.TEXT_WHITE))
		_tasks_vbox.add_child(row)

func _refresh_repair_list() -> void:
	if _repair_vbox == null or not is_instance_valid(_repair_vbox):
		return
	for c in _repair_vbox.get_children():
		c.queue_free()

	var e = RimvaleAPI.engine
	var found_any: bool = false
	var handles: Array = GameState.get_active_handles()
	for h in handles:
		var cname: String = str(e.get_character_name(h))
		for slot in ["weapon", "armor", "shield"]:
			var cur_hp: int = e._get_equip_hp(e._chars[h], slot)
			var max_hp: int = e._get_equip_max_hp(e._chars[h], slot)
			var item_name: String = str(e._chars[h].get(slot, "None"))
			if item_name == "None" or item_name == "":
				continue
			if cur_hp >= max_hp:
				continue
			found_any = true
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var info_lbl := Label.new()
			var status: String = "DESTROYED" if cur_hp <= -max_hp else ("BROKEN" if cur_hp <= 0 else "Damaged")
			var repair_cost: int = maxi(1, (max_hp - cur_hp) * 2)
			var sell_price: int = _compute_sell_price(item_name, cur_hp, max_hp)
			info_lbl.text = "%s  %s [%s] %d/%d HP — Repair %d GP · Sell %d GP" % [
				cname, item_name, status, maxi(0, cur_hp), max_hp, repair_cost, sell_price]
			info_lbl.add_theme_font_size_override("font_size", 11)
			info_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3) if cur_hp <= 0 else Color(0.9, 0.85, 0.7))
			info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(info_lbl)

			# Sell button (left of Repair)
			var sell_btn := Button.new()
			sell_btn.text = "Sell %dg" % sell_price
			sell_btn.add_theme_font_size_override("font_size", 12)
			sell_btn.custom_minimum_size = Vector2(90, 0)
			sell_btn.add_theme_color_override("font_color", RimvaleColors.GOLD)
			var cap_h_sell: int = h
			var cap_slot_sell: String = slot
			var cap_price: int = sell_price
			sell_btn.pressed.connect(func():
				_sell_equipped(cap_h_sell, cap_slot_sell, cap_price))
			row.add_child(sell_btn)

			var repair_btn := Button.new()
			repair_btn.text = "Repair"
			repair_btn.add_theme_font_size_override("font_size", 12)
			repair_btn.custom_minimum_size = Vector2(70, 0)
			repair_btn.disabled = GameState.gold < repair_cost
			var cap_h: int = h
			var cap_slot: String = slot
			repair_btn.pressed.connect(func():
				e.repair_equipment(cap_h, cap_slot)
				_refresh_repair_list())
			row.add_child(repair_btn)
			_repair_vbox.add_child(row)

	# Damaged stash items
	for iname in GameState.stash_hp.keys():
		var hp_arr: Array = GameState.stash_hp[iname]
		var max_hp: int = e._weapon_max_hp(iname)
		if max_hp <= 0:
			max_hp = e._armor_max_hp(iname)
		if max_hp <= 0:
			continue
		for copy_i in range(hp_arr.size()):
			var shp: int = int(hp_arr[copy_i])
			if shp < 0 or shp >= max_hp:
				continue
			found_any = true
			var row2 := HBoxContainer.new()
			row2.add_theme_constant_override("separation", 8)
			var info2 := Label.new()
			var st2: String = "BROKEN" if shp <= 0 else "Damaged"
			var rc2: int = maxi(1, (max_hp - shp) * 2)
			var sp2: int = _compute_sell_price(iname, shp, max_hp)
			info2.text = "Stash  %s [%s] %d/%d HP — Repair %d GP · Sell %d GP" % [
				iname, st2, maxi(0, shp), max_hp, rc2, sp2]
			info2.add_theme_font_size_override("font_size", 11)
			info2.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3) if shp <= 0 else Color(0.9, 0.85, 0.7))
			info2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row2.add_child(info2)

			# Sell button (left of Repair) — for the stash item
			var sb2 := Button.new()
			sb2.text = "Sell %dg" % sp2
			sb2.add_theme_font_size_override("font_size", 12)
			sb2.custom_minimum_size = Vector2(90, 0)
			sb2.add_theme_color_override("font_color", RimvaleColors.GOLD)
			var cap_iname_sell: String = iname
			var cap_sp: int = sp2
			sb2.pressed.connect(func():
				_sell_stash(cap_iname_sell, cap_sp))
			row2.add_child(sb2)

			var rb2 := Button.new()
			rb2.text = "Repair"
			rb2.add_theme_font_size_override("font_size", 12)
			rb2.custom_minimum_size = Vector2(70, 0)
			rb2.disabled = GameState.gold < rc2
			var cap_iname: String = iname
			rb2.pressed.connect(func():
				e.repair_stash_item(cap_iname)
				_refresh_repair_list())
			row2.add_child(rb2)
			_repair_vbox.add_child(row2)

	if not found_any:
		var lbl := Label.new()
		lbl.text = "All equipment is in good condition."
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		_repair_vbox.add_child(lbl)

# ─────────────────────────────────────────────────────────────────────────────
# Sell helpers (mirror shop.gd's pricing and flow)
# ─────────────────────────────────────────────────────────────────────────────

func _compute_sell_price(item_name: String, current_hp: int, max_hp: int) -> int:
	# Matches shop.gd::_get_sell_price: 50% of base, scaled 10%-100% by durability.
	var details: PackedStringArray = RimvaleAPI.engine.get_registry_item_details(item_name)
	var base_price: int = 0
	if details.size() >= 4:
		base_price = int(str(details[3]))
	if base_price <= 0:
		# Fallback hash (same algorithm as shop.gd)
		var h: int = 0
		for c in item_name:
			h = (h * 31 + c.unicode_at(0)) & 0x7FFFFFFF
		base_price = 10 + (h % 141)
	var base_sell: int = maxi(5, int(float(base_price) * 0.5))
	if max_hp <= 0:
		return base_sell
	var hp_ratio: float = clampf(float(maxi(0, current_hp)) / float(max_hp), 0.0, 1.0)
	var dur_mult: float = 0.10 + hp_ratio * 0.90
	return maxi(1, int(float(base_sell) * dur_mult))

func _sell_equipped(handle: int, slot: String, price: int) -> void:
	var slot_idx: int = {"weapon": 0, "armor": 1, "shield": 2}.get(slot, -1)
	if slot_idx < 0:
		return
	RimvaleAPI.engine.unequip_item(handle, slot_idx)
	GameState.earn_gold(price)
	GameState.save_game()
	_refresh_repair_list()

func _sell_stash(item_name: String, price: int) -> void:
	GameState.remove_from_stash(item_name)
	GameState.earn_gold(price)
	GameState.save_game()
	_refresh_repair_list()
