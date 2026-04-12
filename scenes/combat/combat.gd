## combat.gd
## Turn-based combat scene.
##
## Flow:
##   setup → start_combat() → poll current combatant →
##     if player:  show action buttons → perform_action() → end_player_phase() → next_turn()
##     if enemy:   process_enemy_phase() → next_turn()
##   loop until one side is defeated.

extends Control

var _e: RimvaleEngine

# Handles for enemies spawned this fight
var _enemy_handles: Array = []

# UI references
var _initiative_list: VBoxContainer
var _combatant_panel: VBoxContainer
var _action_log: RichTextLabel
var _action_bar: HBoxContainer
var _round_label: Label
var _status_label: Label

# Combatant name/id tracking for display
var _combatant_info: Array = []  # Array of { id, name, is_player }

const ENEMY_NAME: String = "Goblin Raider"
const ENEMY_CATEGORY: int = 0   # 0 = generic/humanoid category enum
const ENEMY_LEVEL: int = 1

# ActionType enum values (mirrors CombatManager.h)
const ACTION_MELEE:  int = 0
const ACTION_DODGE:  int = 1
const ACTION_REST:   int = 3
const ACTION_ITEM:   int = 9
const ACTION_SPELL:  int = 10
const ACTION_RANGED: int = 12

# ── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_e = RimvaleAPI.engine
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Root layout
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_build_header())

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 0)
	root.add_child(content)

	content.add_child(_build_left_panel())
	content.add_child(_build_center_panel())
	content.add_child(_build_right_panel())

	root.add_child(_build_footer())

	# Start the fight
	_setup_combat()

# ── Panel builders ────────────────────────────────────────────────────────────

func _build_header() -> Control:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.05, 0.08, 1.0)
	bg.custom_minimum_size = Vector2(0, 60)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	bg.add_child(margin)

	var hbox := HBoxContainer.new()
	margin.add_child(hbox)

	var title := Label.new()
	title.text = "⚔  COMBAT"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.50, 0.30, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

	_round_label = Label.new()
	_round_label.text = "Round 1"
	_round_label.add_theme_font_size_override("font_size", 20)
	_round_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.80, 1.0))
	hbox.add_child(_round_label)

	return bg

func _build_left_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "INITIATIVE ORDER"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.55, 1.0))
	vbox.add_child(lbl)

	vbox.add_child(HSeparator.new())

	_initiative_list = VBoxContainer.new()
	_initiative_list.add_theme_constant_override("separation", 6)
	vbox.add_child(_initiative_list)

	return panel

func _build_center_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Current combatant info
	var act_lbl := Label.new()
	act_lbl.text = "ACTIVE COMBATANT"
	act_lbl.add_theme_font_size_override("font_size", 14)
	act_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.55, 1.0))
	vbox.add_child(act_lbl)

	_combatant_panel = VBoxContainer.new()
	_combatant_panel.add_theme_constant_override("separation", 8)
	vbox.add_child(_combatant_panel)

	vbox.add_child(HSeparator.new())

	# Action log
	var log_lbl := Label.new()
	log_lbl.text = "BATTLE LOG"
	log_lbl.add_theme_font_size_override("font_size", 14)
	log_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.55, 1.0))
	vbox.add_child(log_lbl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_action_log = RichTextLabel.new()
	_action_log.bbcode_enabled = true
	_action_log.fit_content = true
	_action_log.scroll_active = false
	_action_log.add_theme_font_size_override("normal_font_size", 15)
	_action_log.add_theme_color_override("default_color", Color(0.85, 0.85, 0.80, 1.0))
	scroll.add_child(_action_log)

	return panel

func _build_right_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "ACTIONS"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.55, 1.0))
	vbox.add_child(lbl)

	vbox.add_child(HSeparator.new())

	_action_bar = HBoxContainer.new()
	_action_bar.add_theme_constant_override("separation", 8)
	vbox.add_child(_action_bar)

	# Status / feedback label
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.95, 0.80, 0.30, 1.0))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Retreat button
	var retreat_btn := Button.new()
	retreat_btn.text = "Retreat to Hub"
	retreat_btn.custom_minimum_size = Vector2(0, 48)
	retreat_btn.add_theme_font_size_override("font_size", 15)
	retreat_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	retreat_btn.pressed.connect(_on_retreat)
	vbox.add_child(retreat_btn)

	return panel

func _build_footer() -> Control:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12, 1.0)
	bg.custom_minimum_size = Vector2(0, 36)
	return bg

# ── Combat logic ─────────────────────────────────────────────────────────────

func _setup_combat() -> void:
	_log("[color=yellow]⚔ Combat begins![/color]")

	# Add party members
	var party: Array = GameState.get_active_handles()
	for handle in party:
		_e.add_player_to_combat(handle)

	# Spawn one enemy per party member (up to 2)
	var enemy_count := mini(party.size(), 2)
	for i in range(enemy_count):
		var suffix := "" if i == 0 else " #%d" % (i + 1)
		var eh := _e.spawn_creature(ENEMY_NAME + suffix, ENEMY_CATEGORY, ENEMY_LEVEL)
		_enemy_handles.append(eh)
		_e.add_creature_to_combat(eh)
		_log("Spawned [color=red]%s[/color] (handle %d)" % [ENEMY_NAME + suffix, eh])

	_e.start_combat()
	_log("Initiative rolled.")

	_refresh_initiative()
	_do_current_turn()

func _do_current_turn() -> void:
	_refresh_round()
	_refresh_combatant_panel()

	var is_player: bool = _e.get_current_combatant_is_player()
	if is_player:
		_show_player_actions()
	else:
		_show_action_buttons(false)
		# Defer enemy processing slightly so log renders
		await get_tree().create_timer(0.4).timeout
		_run_enemy_turn()

func _run_enemy_turn() -> void:
	_e.process_enemy_phase()
	var log_line: String = _e.get_last_action_log()
	if log_line.length() > 0:
		_log("[color=salmon]%s[/color]" % log_line)
	_check_combat_over()
	_e.next_turn()
	_do_current_turn()

func _show_player_actions() -> void:
	_clear_action_bar()
	_status_label.text = "Your turn!"

	# Attack button — targets first living enemy
	var atk_btn := _action_button("⚔ Attack", Color(0.95, 0.50, 0.30, 1.0))
	atk_btn.pressed.connect(_on_attack)
	_action_bar.add_child(atk_btn)

	# Spell button — opens picker if the current player has learned spells
	var cur_handle: int = _get_current_player_handle()
	if cur_handle != -1:
		var spells_raw := _e.get_learned_spells(cur_handle)
		if spells_raw.size() > 0:
			var spell_btn := _action_button("🔮 Spell", Color(0.74, 0.40, 1.0))
			spell_btn.pressed.connect(func(): _show_spell_picker(cur_handle))
			_action_bar.add_child(spell_btn)

	# End turn button
	var end_btn := _action_button("End Turn", Color(0.65, 0.65, 0.65, 1.0))
	end_btn.pressed.connect(_on_end_turn)
	_action_bar.add_child(end_btn)

func _show_action_buttons(enabled: bool) -> void:
	for child in _action_bar.get_children():
		if child is Button:
			child.disabled = !enabled

func _action_button(txt: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(0, 52)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", col)
	return btn

func _clear_action_bar() -> void:
	for child in _action_bar.get_children():
		child.queue_free()

# ── Player actions ────────────────────────────────────────────────────────────

func _on_attack() -> void:
	# Find first living enemy id
	var target_id: String = ""
	for eh in _enemy_handles:
		var hp := _e.get_creature_hp(eh)
		if hp > 0:
			target_id = _e.get_creature_id(eh)
			break

	if target_id.is_empty():
		_status_label.text = "No enemies to attack!"
		return

	_e.perform_action(ACTION_MELEE, target_id)
	var log_line: String = _e.get_last_action_log()
	_log("[color=orange]%s[/color]" % (log_line if log_line.length() > 0 else "You attack!"))

	_refresh_combatant_panel()
	_status_label.text = ""

	if _check_combat_over():
		return

func _on_end_turn() -> void:
	_e.end_player_phase()
	_e.next_turn()
	_do_current_turn()

# ── Spell Casting ─────────────────────────────────────────────────────────────

## Returns the character handle whose ID matches the current combatant, or -1.
func _get_current_player_handle() -> int:
	var cur_id: String = str(_e.get_current_combatant_id())
	for ph in GameState.get_active_handles():
		if str(_e.get_character_id(ph)) == cur_id:
			return ph
	return -1

func _show_spell_picker(player_handle: int) -> void:
	var cur_sp: int  = _e.get_character_sp(player_handle)
	var max_sp: int  = _e.get_character_max_sp(player_handle)
	var spells_raw   := _e.get_learned_spells(player_handle)
	var all_spells   := _e.get_all_spells()
	var custom_sp    := _e.get_custom_spells()

	var dialog := AcceptDialog.new()
	dialog.title  = "Cast a Spell"
	dialog.get_ok_button().text = "Cancel"
	dialog.min_size = Vector2i(380, 460)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	dialog.add_child(vbox)

	vbox.add_child(_make_sp_bar_label(cur_sp, max_sp))
	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for sname_raw in spells_raw:
		var sname: String = str(sname_raw)
		var cost: int     = 0
		var desc: String  = ""
		var dom_idx: int  = 0

		# Look up cost and description in all_spells then custom_spells
		for sd in all_spells:
			if str(sd[0]) == sname:
				cost    = int(str(sd[2]))
				desc    = str(sd[3]) if sd.size() > 3 else ""
				dom_idx = int(str(sd[1]))
				break
		if cost == 0:
			for sd in custom_sp:
				if str(sd[0]) == sname:
					cost    = int(str(sd[2]))
					desc    = str(sd[3]) if sd.size() > 3 else ""
					dom_idx = int(str(sd[1]))
					break

		var can_cast: bool = cur_sp >= cost

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 50)
		list.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)

		var name_lbl := Label.new()
		name_lbl.text = "🔮 " + sname
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color",
			Color(0.74, 0.50, 1.0) if can_cast else Color(0.50, 0.50, 0.50, 1.0))
		info.add_child(name_lbl)

		if not desc.is_empty():
			var desc_lbl := Label.new()
			desc_lbl.text       = desc.left(72) + ("…" if desc.length() > 72 else "")
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
			desc_lbl.add_theme_font_size_override("font_size", 10)
			desc_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.60, 1.0))
			info.add_child(desc_lbl)

		var cost_lbl := Label.new()
		cost_lbl.text = "%d SP" % cost
		cost_lbl.add_theme_font_size_override("font_size", 14)
		cost_lbl.add_theme_color_override("font_color",
			Color(0.74, 0.40, 1.0) if can_cast else Color(0.50, 0.50, 0.50, 1.0))
		row.add_child(cost_lbl)

		var sn_cap: int  = dom_idx   # capture domain for log color
		var sc_cap: int  = cost
		var sname_cap    = sname

		var cast_btn := Button.new()
		cast_btn.text  = "Cast"
		cast_btn.custom_minimum_size = Vector2(64, 0)
		cast_btn.disabled = not can_cast
		cast_btn.add_theme_font_size_override("font_size", 13)
		cast_btn.add_theme_color_override("font_color",
			Color(0.74, 0.40, 1.0) if can_cast else Color(0.50, 0.50, 0.50, 1.0))
		cast_btn.pressed.connect(func():
			dialog.hide()
			dialog.queue_free()
			_on_cast_spell(sname_cap, sc_cap)
		)
		row.add_child(cast_btn)
		list.add_child(HSeparator.new())

	if spells_raw.size() == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "No spells learned."
		empty_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.60, 1.0))
		list.add_child(empty_lbl)

	dialog.confirmed.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2(380, 460))

func _on_cast_spell(spell_name: String, cost: int) -> void:
	var ok: bool = _e.perform_action(ACTION_SPELL, spell_name)
	var log_line: String = _e.get_last_action_log()

	if ok:
		_log("[color=#bb66ff]🔮 %s[/color]" % (log_line if log_line.length() > 0 else "You cast " + spell_name + "!"))
	else:
		_log("[color=red]Spell failed: %s[/color]" % spell_name)

	_refresh_combatant_panel()
	_status_label.text = ""
	_check_combat_over()

func _make_sp_bar_label(cur: int, max_val: int) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = "SP"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.60, 1.0))
	hbox.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.text = "%d / %d" % [cur, max_val]
	val_lbl.add_theme_font_size_override("font_size", 15)
	val_lbl.add_theme_color_override("font_color", Color(0.74, 0.40, 1.0))
	hbox.add_child(val_lbl)

	return hbox

# ── UI refresh helpers ────────────────────────────────────────────────────────

func _refresh_round() -> void:
	_round_label.text = "Round %d" % _e.get_combat_round()

func _refresh_initiative() -> void:
	for child in _initiative_list.get_children():
		child.queue_free()

	var order: PackedStringArray = _e.get_initiative_order()
	var current_id: String = str(_e.get_current_combatant_id())

	for entry in order:
		var lbl := Label.new()
		lbl.text = entry
		lbl.add_theme_font_size_override("font_size", 15)
		# Highlight current
		if entry.contains(str(current_id)):
			lbl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.30, 1.0))
		else:
			lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.70, 1.0))
		_initiative_list.add_child(lbl)

func _refresh_combatant_panel() -> void:
	for child in _combatant_panel.get_children():
		child.queue_free()

	var cname: String = _e.get_current_combatant_name()
	var chp: int = _e.get_current_combatant_hp()
	var cap: int = _e.get_current_combatant_ap()
	var is_player: bool = _e.get_current_combatant_is_player()

	var name_lbl := Label.new()
	name_lbl.text = cname + ("  [PLAYER]" if is_player else "  [ENEMY]")
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color",
		Color(0.50, 0.85, 0.50, 1.0) if is_player else Color(0.90, 0.40, 0.40, 1.0))
	_combatant_panel.add_child(name_lbl)

	var stats_lbl := Label.new()
	stats_lbl.text = "HP: %d     AP: %d" % [chp, cap]
	stats_lbl.add_theme_font_size_override("font_size", 18)
	stats_lbl.add_theme_color_override("font_color", Color(0.80, 0.80, 0.75, 1.0))
	_combatant_panel.add_child(stats_lbl)

	_refresh_initiative()

# ── Win/Lose detection ────────────────────────────────────────────────────────

## Returns true if combat is over.
func _check_combat_over() -> bool:
	# Check enemies
	var all_dead := true
	for eh in _enemy_handles:
		if _e.get_creature_hp(eh) > 0:
			all_dead = false
			break

	if all_dead:
		_combat_end(true)
		return true

	# Check players
	var party_dead := true
	for ph in GameState.get_active_handles():
		if _e.get_character_hp(ph) > 0:
			party_dead = false
			break

	if party_dead:
		_combat_end(false)
		return true

	return false

func _combat_end(victory: bool) -> void:
	_clear_action_bar()
	_show_action_buttons(false)

	if victory:
		_log("\n[color=yellow]★ VICTORY! All enemies defeated. ★[/color]")
		# Collect loot for each player
		for ph in GameState.party:
			var loot: PackedStringArray = _e.collect_loot(ph)
			if loot.size() > 0:
				_log("Loot: " + ", ".join(Array(loot)))
	else:
		_log("\n[color=red]✗ DEFEAT — your party has fallen.[/color]")

	# Add "Return to Hub" button
	var ret_btn := _action_button("Return to Hub", Color(0.95, 0.80, 0.30, 1.0))
	ret_btn.pressed.connect(_on_retreat)
	_action_bar.add_child(ret_btn)

func _on_retreat() -> void:
	# Clean up enemies
	for eh in _enemy_handles:
		_e.destroy_creature(eh)
	_enemy_handles.clear()
	# Pop back to the current tab (World tab)
	get_parent().get_parent().pop_screen()

# ── Log helper ────────────────────────────────────────────────────────────────

func _log(msg: String) -> void:
	_action_log.text += msg + "\n"
