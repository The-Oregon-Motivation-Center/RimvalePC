extends AcceptDialog
class_name BasePopup

# ─────────────────────────────────────────────────────────────────────────────
# Base Building popup for region-map Town Hall POIs.
#
# Shows base tier, facilities, supplies, morale at a glance. "Open Full Base
# Management…" jumps to the World tab where the full facility/ally UI lives.
#
# NOTE: The original handoff plan mentioned the player "buying" a base in a
# specific town — that requires multi-region base support (GameState currently
# models a single base). That's a bigger design change; flagged in HANDOFF.md.
# ─────────────────────────────────────────────────────────────────────────────

var _stats_vbox: VBoxContainer
var _fac_vbox: VBoxContainer
var _refresh_timer: Timer

func _init() -> void:
	title = "Town Hall — Base Management"
	min_size = Vector2i(600, 640)
	get_ok_button().text = "Close"
	visibility_changed.connect(_on_visibility_changed)
	close_requested.connect(queue_free)
	confirmed.connect(queue_free)

func _on_visibility_changed() -> void:
	if not visible:
		queue_free()

func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	vbox.add_child(RimvaleUtils.label("ACF Headquarters", 18, RimvaleColors.ACCENT))
	var sub := RimvaleUtils.label(
		"Quick overview of your agency's facilities and supplies.",
		11, RimvaleColors.TEXT_GRAY)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(sub)

	var open_btn := RimvaleUtils.button("🏛 Open Full Base Management…", RimvaleColors.GOLD, 44, 13)
	open_btn.pressed.connect(_on_open_world_tab)
	vbox.add_child(open_btn)

	vbox.add_child(RimvaleUtils.separator())

	# Stats section
	_stats_vbox = VBoxContainer.new()
	_stats_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(_stats_vbox)

	vbox.add_child(RimvaleUtils.separator())
	vbox.add_child(RimvaleUtils.label("FACILITIES", 13, RimvaleColors.TEXT_DIM))
	_fac_vbox = VBoxContainer.new()
	_fac_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fac_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(_fac_vbox)

	_refresh_all()

	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 2.0
	_refresh_timer.autostart = true
	_refresh_timer.timeout.connect(_refresh_all)
	add_child(_refresh_timer)

func _on_open_world_tab() -> void:
	var main_node = get_tree().root.get_child(0)
	if main_node and main_node.has_method("go_to_tab"):
		main_node.go_to_tab(1)  # World tab
	hide()

func _refresh_all() -> void:
	_refresh_stats()
	_refresh_facilities()

func _refresh_stats() -> void:
	if _stats_vbox == null or not is_instance_valid(_stats_vbox):
		return
	for c in _stats_vbox.get_children():
		c.queue_free()

	var fac_count: int = GameState.base_facilities.size()
	var fac_max: int = GameState.get_base_max_facilities()

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 16)
	row1.add_child(RimvaleUtils.label("Base Tier: %d / 5" % GameState.base_tier, 14, RimvaleColors.GOLD))
	row1.add_child(RimvaleUtils.label("Facilities: %d / %d" % [fac_count, fac_max], 12, RimvaleColors.TEXT_WHITE))
	_stats_vbox.add_child(row1)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 16)
	row2.add_child(RimvaleUtils.label("Supplies: %d" % GameState.base_supplies, 12, RimvaleColors.HP_GREEN))
	row2.add_child(RimvaleUtils.label("Defense: %d (%+d)" % [GameState.base_defense, GameState.get_base_defense_mod()], 12, RimvaleColors.CYAN))
	row2.add_child(RimvaleUtils.label("Morale: %d" % GameState.base_morale, 12, Color(0.90, 0.75, 0.20)))
	_stats_vbox.add_child(row2)

	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 16)
	row3.add_child(RimvaleUtils.label("Gold: %d" % GameState.gold, 12, RimvaleColors.GOLD))
	row3.add_child(RimvaleUtils.label("Remnant Fragments: %d" % GameState.remnant_fragments, 12, RimvaleColors.SP_PURPLE))
	row3.add_child(RimvaleUtils.label("Allies: %d" % GameState.recruited_allies.size(), 12, Color(0.20, 0.78, 0.40)))
	_stats_vbox.add_child(row3)

	# Upgrade hint
	if GameState.base_tier < 5:
		var tier_cost_g: int = 500 * GameState.base_tier
		var tier_cost_rf: int = 3 * GameState.base_tier
		var can_up: bool = GameState.gold >= tier_cost_g and GameState.remnant_fragments >= tier_cost_rf
		var hint_col: Color = RimvaleColors.HP_GREEN if can_up else RimvaleColors.TEXT_DIM
		_stats_vbox.add_child(RimvaleUtils.label(
			"Next tier: %dg + %d RF %s" % [
				tier_cost_g, tier_cost_rf,
				"(ready)" if can_up else "(need more)"],
			11, hint_col))

func _refresh_facilities() -> void:
	if _fac_vbox == null or not is_instance_valid(_fac_vbox):
		return
	for c in _fac_vbox.get_children():
		c.queue_free()

	if GameState.base_facilities.is_empty():
		_fac_vbox.add_child(RimvaleUtils.label(
			"No facilities built yet. Open Full Base Management to build one.",
			12, RimvaleColors.TEXT_GRAY))
		return

	for fi in GameState.base_facilities:
		if fi < 0 or fi >= GameState.FACILITY_DEFS.size():
			continue
		var fac: Dictionary = GameState.FACILITY_DEFS[fi]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(RimvaleUtils.label(
			"%s %s" % [str(fac.get("icon", "■")), str(fac.get("name", "Facility"))],
			12, RimvaleColors.TEXT_WHITE))
		var tier_txt: String = "Tier %d" % int(fac.get("tier", 1))
		row.add_child(RimvaleUtils.label(tier_txt, 10, RimvaleColors.TEXT_DIM))
		_fac_vbox.add_child(row)
