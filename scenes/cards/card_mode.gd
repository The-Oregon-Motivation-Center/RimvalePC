## card_mode.gd — main play scene for Card Mode (2–4 player card battler).
##
## Board (top → bottom): one section per OPPONENT (strip + slot row; defeated
## players keep a greyed strip so the roster stays visible), center bar
## (round / turn / energy / log / End Turn), my slots, my strip, my hand.
##
## The bottom of the screen always belongs to `_viewer` — the local human seat.
## In hotseat the viewer changes only behind the opaque pass-the-device overlay;
## vs AI the human keeps their seat and the AI turns play out live up top while
## input is locked. Input is only accepted while CardSystem.turn == _viewer.
##
## Interaction state machine (_highlight_mode):
##   ""             — idle; click a hand card or one of your slots.
##   "place"        — a character card is selected; click an empty friendly slot.
##   "equip"        — an equip/feat/spell card is selected; click a friendly character.
##   "attack_target"— click any enemy slot, or an enemy strip for a direct hit.
##   "spell_target" — click a friendly slot (heal/buff) or any enemy slot
##                    (damage/debuff; area spells hit that whole side).
## ESC / right-click clears selection. Errors surface as toasts.
## While the active hand is over CardSystem.HAND_MAX, clicks on hand cards
## DISCARD them instead (the engine locks every other action until legal).

extends Control

const TITLE_SCENE := "res://scenes/title/title_screen.tscn"
const SLOT_SIZE := Vector2(150, 148)          # board card, 2-player matches
const SLOT_SIZE_COMPACT := Vector2(112, 112)  # board card, 3–4 player matches
const HAND_SIZE := Vector2(140, 150)

## Glyphs for condition badges on slot panels.
const COND_GLYPHS := {
	"bleeding": "☠", "stunned": "⏳", "slowed": "🐌",
	"frightened": "😱", "dodging": "💨", "shielded": "🛡",
	"restrained": "🕸",
}

# ── Interaction state ────────────────────────────────────────────────────────
var _viewer: int = 0                # the seat rendered at the bottom (local human)
var _selected_hand: int = -1        # index into the viewer's hand
var _selected_slot: int = -1        # acting character's slot (attack / cast)
var _pending_spell: int = -1        # index into the caster's spells array
var _highlight_mode: String = ""    # "", "place", "equip", "attack_target", "spell_target"
var _handoff_active: bool = false   # true while the pass-the-device overlay is up
var _match_over: bool = false       # true once the victory modal is shown

# ── UI references (built once in _build_layout) ──────────────────────────────
var _opp_area: VBoxContainer        # rebuilt every refresh: strips + slot rows
var _opp_strips: Dictionary = {}    # seat -> PanelContainer (living + defeated)
var _opp_slot_rows: Dictionary = {} # seat -> HBoxContainer (living seats only)
var _round_label: Label
var _turn_label: Label
var _energy_label: Label
var _log_box: RichTextLabel
var _end_turn_btn: Button
var _draw_btn: Button
var _my_slots_row: HBoxContainer
var _my_strip: PanelContainer
var _my_strip_label: Label
var _hand_row: HBoxContainer
var _toast_layer: VBoxContainer
var _popup: Control = null          # action / detail popup (one at a time)
var _overlay: Control = null        # handoff overlay

# ── Setup / teardown ─────────────────────────────────────────────────────────

var _quit_confirm: Control = null   # forfeit confirmation overlay

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RimvaleUtils.add_bg(self, RimvaleColors.BG_DARK)
	if not CardSystem.match_active or CardSystem.players.size() < 2:
		_show_no_match()
		return
	# The viewer starts as the first human seat (seat 0 is never an AI).
	_viewer = 0
	for i in range(CardSystem.num_players):
		if not CardSystem.is_ai_seat(i):
			_viewer = i
			break
	CardSystem.card_event.connect(_on_card_event)
	gui_input.connect(_on_root_gui_input)
	_build_layout()
	_refresh_board()
	_add_quit_button()
	_add_debug_button()

func _exit_tree() -> void:
	if CardSystem.card_event.is_connected(_on_card_event):
		CardSystem.card_event.disconnect(_on_card_event)

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		if _quit_confirm != null and is_instance_valid(_quit_confirm):
			_quit_confirm.queue_free()
			_quit_confirm = null
		elif _highlight_mode != "" or _selected_hand >= 0 or _selected_slot >= 0 \
				or (_popup != null and is_instance_valid(_popup)):
			_clear_selection()
			_close_popup()
		elif not _match_over:
			_open_quit_confirm()

## Right-click on empty board space clears selection (panels handle their own).
func _on_root_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		_clear_selection()

# ── Debug tools (gated on GameState.debug_mode, mirroring Battle Mode) ──────
var _debug_panel: PanelContainer = null
var _dbg_open: Dictionary = {}      # section key -> expanded?
var _dbg_edit_slot: int = 0         # slot targeted by the debug editor

## Add the 🐞 button next to the quit ✕, when debug tools were enabled on the
## match setup screen (GameState.debug_mode).
func _add_debug_button() -> void:
	if not bool(GameState.debug_mode):
		return
	var b := Button.new()
	b.text = "🐞"
	b.tooltip_text = "Debug tools (card spawner, energy, discard)"
	b.flat = true
	b.custom_minimum_size = Vector2(34, 34)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", RimvaleColors.CYAN)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(b)
	b.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	b.offset_left = -84
	b.offset_top = 8
	b.offset_right = -50
	b.offset_bottom = 42
	b.pressed.connect(_toggle_debug_panel)

func _toggle_debug_panel() -> void:
	if _debug_panel != null and is_instance_valid(_debug_panel):
		_debug_panel.queue_free()
		_debug_panel = null
		return
	_build_debug_panel()

func _build_debug_panel() -> void:
	var me: int = CardSystem.turn
	_debug_panel = RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.CYAN, 8, 8)
	_debug_panel.z_index = 70
	add_child(_debug_panel)
	_debug_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_debug_panel.offset_left = 8.0
	_debug_panel.custom_minimum_size = Vector2(228, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_debug_panel.add_child(box)

	# ── Title bar with a close ✕ ─────────────────────────────────────────
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	box.add_child(head)
	var ttl: Label = RimvaleUtils.label("🐞 DEBUG", 13, RimvaleColors.CYAN)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ttl)
	var x: Button = RimvaleUtils.button("✕", RimvaleColors.TEXT_GRAY, 20, 11)
	x.custom_minimum_size = Vector2(24, 20)
	x.pressed.connect(_toggle_debug_panel)
	head.add_child(x)

	# ── Energy (one compact row) ─────────────────────────────────────────
	var e_row := HBoxContainer.new()
	e_row.add_theme_constant_override("separation", 3)
	box.add_child(e_row)
	var refill: Button = RimvaleUtils.button("⚡ Refill", RimvaleColors.WARNING, 22, 10)
	refill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refill.pressed.connect(func() -> void:
		_do_action(CardSystem.debug_refill_energy(CardSystem.turn))
		_rebuild_debug_panel())
	e_row.add_child(refill)
	var e10: Button = RimvaleUtils.button("⚡ +10", RimvaleColors.WARNING, 22, 10)
	e10.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e10.pressed.connect(func() -> void:
		var cur: int = int(CardSystem.players[CardSystem.turn].get("energy", 0))
		_do_action(CardSystem.debug_refill_energy(CardSystem.turn, cur + 10))
		_rebuild_debug_panel())
	e_row.add_child(e10)

	# ── Discard a board slot (collapsible) ───────────────────────────────
	var dsec := _dbg_section(box, "🗑 Discard from board", "discard")
	if dsec != null:
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 2)
		dsec.add_child(srow)
		for sl in range(CardSystem.MAX_SLOTS):
			var occ = CardSystem.players[me]["slots"][sl]
			var sb: Button = RimvaleUtils.button(
				str(occ["name"]).left(4) if occ != null else "—",
				RimvaleColors.DANGER if occ != null else RimvaleColors.TEXT_DIM, 20, 9)
			sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sb.disabled = occ == null
			var si: int = sl
			sb.pressed.connect(func() -> void:
				_do_action(CardSystem.debug_discard_slot(CardSystem.turn, si))
				_rebuild_debug_panel())
			srow.add_child(sb)

	# ── Character editor (collapsible) ───────────────────────────────────
	var esec := _dbg_section(box, "🔧 Edit character", "edit")
	if esec != null:
		var pick := HBoxContainer.new()
		pick.add_theme_constant_override("separation", 2)
		esec.add_child(pick)
		for sl in range(CardSystem.MAX_SLOTS):
			var occ2 = CardSystem.players[me]["slots"][sl]
			var pb: Button = RimvaleUtils.button(
				str(occ2["name"]).left(4) if occ2 != null else "—",
				RimvaleColors.ACCENT if sl == _dbg_edit_slot else RimvaleColors.TEXT_GRAY, 20, 9)
			pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pb.disabled = occ2 == null
			var pi: int = sl
			pb.pressed.connect(func() -> void:
				_dbg_edit_slot = pi
				_rebuild_debug_panel())
			pick.add_child(pb)
		var ec = CardSystem.players[me]["slots"][_dbg_edit_slot] \
			if _dbg_edit_slot >= 0 and _dbg_edit_slot < CardSystem.MAX_SLOTS else null
		if ec == null:
			esec.add_child(RimvaleUtils.label("Pick an occupied slot.", 9, RimvaleColors.TEXT_DIM))
		else:
			esec.add_child(RimvaleUtils.label("%s — Lv%d, AC %d" % [
				str(ec["name"]), int(ec["level"]), int(ec["ac"])], 10, RimvaleColors.GOLD))
			for f_v in CardSystem.DEBUG_FIELDS:
				var fkey: String = str(f_v[0])
				var flabel: String = str(f_v[1])
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 2)
				esec.add_child(row)
				var nm: Label = RimvaleUtils.label(flabel, 9, RimvaleColors.TEXT_GRAY)
				nm.custom_minimum_size = Vector2(58, 0)
				row.add_child(nm)
				var val: Label = RimvaleUtils.label(
					str(CardSystem.debug_field_value(ec, fkey)), 9, RimvaleColors.TEXT_WHITE)
				val.custom_minimum_size = Vector2(26, 0)
				val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				row.add_child(val)
				for d_v in [[-1, "−"], [1, "+"], [10, "+10"]]:
					var dd: int = int(d_v[0])
					var db2: Button = RimvaleUtils.button(str(d_v[1]),
						RimvaleColors.DANGER if dd < 0 else RimvaleColors.SUCCESS, 18, 9)
					db2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					db2.pressed.connect(func() -> void:
						_do_action(CardSystem.debug_adjust(
							CardSystem.turn, _dbg_edit_slot, fkey, dd))
						_rebuild_debug_panel())
					row.add_child(db2)
			var maxb: Button = RimvaleUtils.button("💪 Max out", RimvaleColors.GOLD, 20, 10)
			maxb.pressed.connect(func() -> void:
				_do_action(CardSystem.debug_max_character(CardSystem.turn, _dbg_edit_slot))
				_rebuild_debug_panel())
			esec.add_child(maxb)

	# ── Card spawner: category → sub-category → cards ────────────────────
	for cat in CardSystem.debug_card_tree():
		var cat_key: String = "cat:%s" % str(cat["label"])
		var cat_box := _dbg_section(box, str(cat["label"]), cat_key)
		if cat_box == null:
			continue
		for grp in cat["groups"]:
			if (grp["cards"] as Array).is_empty():
				continue
			var grp_key: String = "%s/%s" % [cat_key, str(grp["label"])]
			var grp_box := _dbg_section(cat_box, "  %s (%d)" % [
				str(grp["label"]), (grp["cards"] as Array).size()], grp_key, 10)
			if grp_box == null:
				continue
			var scroll := ScrollContainer.new()
			scroll.custom_minimum_size = Vector2(0, mini(150,
				18 * (grp["cards"] as Array).size() + 4))
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			grp_box.add_child(scroll)
			var list := VBoxContainer.new()
			list.add_theme_constant_override("separation", 1)
			list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(list)
			for entry in grp["cards"]:
				var cb: Button = RimvaleUtils.button(str(entry["label"]),
					RimvaleColors.TEXT_LIGHT, 18, 9)
				cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var ct: String = str(entry["ctype"])
				var ck: String = str(entry["key"])
				cb.pressed.connect(func() -> void:
					_do_action(CardSystem.debug_give_card(CardSystem.turn, ct, ck)))
				list.add_child(cb)

## One collapsible section. Returns its content VBox when expanded, else null.
func _dbg_section(parent: Control, title: String, key: String, fs: int = 11) -> VBoxContainer:
	var open: bool = bool(_dbg_open.get(key, false))
	var hdr: Button = RimvaleUtils.button(("▾ " if open else "▸ ") + title,
		RimvaleColors.ACCENT if open else RimvaleColors.TEXT_GRAY, 20, fs)
	hdr.alignment = HORIZONTAL_ALIGNMENT_LEFT
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.pressed.connect(func() -> void:
		_dbg_open[key] = not bool(_dbg_open.get(key, false))
		_rebuild_debug_panel())
	parent.add_child(hdr)
	if not open:
		return null
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	parent.add_child(body)
	return body

func _rebuild_debug_panel() -> void:
	if _debug_panel != null and is_instance_valid(_debug_panel):
		_debug_panel.queue_free()
		_debug_panel = null
		_build_debug_panel()

## Small always-available escape hatch — top-right corner of the board.
## Works during the AI's turn too; hotseat handoff and victory overlays are
## added later in the tree, so they correctly cover it while shown.
func _add_quit_button() -> void:
	var b := Button.new()
	b.text = "✕"
	b.tooltip_text = "Quit this match (Esc)"
	b.flat = true
	b.custom_minimum_size = Vector2(34, 34)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", RimvaleColors.TEXT_GRAY)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(b)
	b.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	b.offset_left = -44
	b.offset_top = 8
	b.offset_right = -10
	b.offset_bottom = 42
	b.pressed.connect(_open_quit_confirm)

## Confirm dialog: abandoning the match forfeits it — no winner recorded.
func _open_quit_confirm() -> void:
	if _quit_confirm != null and is_instance_valid(_quit_confirm):
		return
	_close_popup()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_quit_confirm = dim
	var center := CenterContainer.new()
	dim.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.DANGER, 12, 20)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var title: Label = RimvaleUtils.label("Quit this match?", 20, RimvaleColors.TEXT_WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub: Label = RimvaleUtils.label("The match is abandoned — no winner is recorded.", 12, RimvaleColors.TEXT_GRAY)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var quit_b: Button = RimvaleUtils.button("🏳 Quit to Title", RimvaleColors.DANGER, 40, 14)
	quit_b.custom_minimum_size = Vector2(170, 40)
	quit_b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	quit_b.pressed.connect(_do_quit)
	row.add_child(quit_b)
	var stay_b: Button = RimvaleUtils.button("Keep Playing", RimvaleColors.TEXT_LIGHT, 40, 14)
	stay_b.custom_minimum_size = Vector2(150, 40)
	stay_b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	stay_b.pressed.connect(func():
		if _quit_confirm != null and is_instance_valid(_quit_confirm):
			_quit_confirm.queue_free()
		_quit_confirm = null)
	row.add_child(stay_b)

func _do_quit() -> void:
	CardSystem.end_match()
	get_tree().change_scene_to_file("res://scenes/title/title_screen.tscn")

func _show_no_match() -> void:
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)
	var err_l: Label = RimvaleUtils.label("No card match in progress.", 20, RimvaleColors.DANGER)
	err_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(err_l)
	var hint: Label = RimvaleUtils.label("Start a match from Card Setup first.", 13, RimvaleColors.TEXT_GRAY)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var back: Button = RimvaleUtils.button("Back to Title", RimvaleColors.PRIMARY, 48, 16)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(TITLE_SCENE)
	)
	v.add_child(back)

# ── Static layout skeleton ───────────────────────────────────────────────────

func _build_layout() -> void:
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	# 1. Opponent area — one strip (+ slot row) per enemy seat. Rebuilt from
	#    scratch inside every _refresh_board (cheap at this scale).
	_opp_area = VBoxContainer.new()
	_opp_area.add_theme_constant_override("separation", 6)
	root.add_child(_opp_area)

	# 2. Center bar.
	root.add_child(_build_center_bar())

	# 3 + 4. My row: a compact square vitals block on the LEFT, my six slots
	#        on the right. Side-by-side keeps the board short enough to fit.
	var my_line := HBoxContainer.new()
	my_line.add_theme_constant_override("separation", 8)
	root.add_child(my_line)
	_my_strip = RimvaleUtils.card(RimvaleColors.BG_CARD_DARK, RimvaleColors.DIVIDER, 8, 8)
	_my_strip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_my_strip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_my_strip.custom_minimum_size = Vector2(196, 0)
	_my_strip_label = RimvaleUtils.label("", 13, RimvaleColors.TEXT_WHITE)
	_my_strip.add_child(_my_strip_label)
	my_line.add_child(_my_strip)
	_my_slots_row = HBoxContainer.new()
	_my_slots_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_my_slots_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_my_slots_row.add_theme_constant_override("separation", 8)
	my_line.add_child(_my_slots_row)

	# 5. Hand row inside a horizontal scroller.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, HAND_SIZE.y + 30.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_row = HBoxContainer.new()
	_hand_row.add_theme_constant_override("separation", 8)
	scroll.add_child(_hand_row)
	root.add_child(scroll)

	# Toast layer sits above the board (but below overlays added later).
	_toast_layer = VBoxContainer.new()
	_toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_layer.add_theme_constant_override("separation", 6)
	add_child(_toast_layer)
	_toast_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toast_layer.offset_top = 16.0

var _cancel_btn: Button = null   # visible escape from any targeting mode
var _discard_btn: Button = null  # free discard of the selected hand card
var _bank_btn: Button = null     # gauntlet: end the run and collect the score
var _pending_banish: int = -1    # hand index awaiting a banish target
var _pending_boon: String = ""   # chosen boon awaiting its target

## Boon picker for banishing the hand card at `idx`.
func _open_banish_popup(idx: int) -> void:
	if _input_locked():
		return
	_close_popup()
	var hand: Array = CardSystem.players[CardSystem.turn].get("hand", [])
	if idx < 0 or idx >= hand.size():
		return
	var wrap := CenterContainer.new()
	add_child(wrap)
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.ACCENT, 10, 14)
	wrap.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	v.add_child(RimvaleUtils.label("✦ Banish %s" % str((hand[idx] as Dictionary).get("name", "?")),
		17, RimvaleColors.ACCENT))
	v.add_child(RimvaleUtils.label("The card leaves the match forever. Choose your boon:",
		11, RimvaleColors.TEXT_GRAY))
	for key in CardSystem.BANISH_BOONS:
		var b: Dictionary = CardSystem.BANISH_BOONS[key]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		v.add_child(row)
		var btn: Button = RimvaleUtils.button("%s %s" % [str(b["glyph"]), str(b["name"])],
			RimvaleColors.SP_PURPLE, 32, 13)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(_on_boon_chosen.bind(idx, str(key)))
		row.add_child(btn)
		var d: Label = RimvaleUtils.label(str(b["desc"]), 10, RimvaleColors.TEXT_GRAY)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(340, 0)
		row.add_child(d)
	var cls: Button = RimvaleUtils.button("Cancel", RimvaleColors.TEXT_GRAY, 30, 12)
	cls.pressed.connect(_close_popup)
	v.add_child(cls)
	_popup = wrap

## Route the chosen boon: fire immediately, or enter a targeting step.
func _on_boon_chosen(idx: int, boon: String) -> void:
	_close_popup()
	var needs: String = str((CardSystem.BANISH_BOONS[boon] as Dictionary)["needs"])
	match needs:
		"":
			_do_action(CardSystem.banish_card(CardSystem.turn, idx, boon))
		"slot":
			_pending_banish = idx
			_pending_boon = boon
			_selected_hand = idx
			_highlight_mode = "banish_target"
			_toast("Pick one of your characters.")
			_refresh_board()
		"graveyard":
			_open_reclaim_popup(idx, boon)

## Discard-pile browser for the Reclaim boon.
func _open_reclaim_popup(idx: int, boon: String) -> void:
	_close_popup()
	var gy: Array = CardSystem.players[CardSystem.turn].get("graveyard", [])
	if gy.is_empty():
		_toast("Your discard pile is empty.")
		return
	var wrap := CenterContainer.new()
	add_child(wrap)
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.ACCENT, 10, 14)
	wrap.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	v.add_child(RimvaleUtils.label("♻ Reclaim a card", 17, RimvaleColors.ACCENT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for i in range(gy.size()):
		var g: Dictionary = gy[i]
		var b: Button = RimvaleUtils.button("%s %s — %s" % [
			CardSystem.card_glyph(g), str(g.get("name", "?")), CardSystem.card_summary(g)],
			RimvaleColors.TEXT_LIGHT, 30, 11)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var gy_idx: int = i
		b.pressed.connect(func() -> void:
			_close_popup()
			_do_action(CardSystem.banish_card(CardSystem.turn, idx, boon, -1, gy_idx))
		)
		list.add_child(b)
	var cls: Button = RimvaleUtils.button("Cancel", RimvaleColors.TEXT_GRAY, 30, 12)
	cls.pressed.connect(_close_popup)
	v.add_child(cls)
	_popup = wrap

## Confirm before ending a gauntlet run voluntarily.
func _open_bank_confirm() -> void:
	if _match_over or not CardSystem.gauntlet:
		return
	_close_popup()
	var wrap := CenterContainer.new()
	add_child(wrap)
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.ACCENT, 10, 14)
	wrap.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(RimvaleUtils.label("🏁 End the gauntlet here?", 16, RimvaleColors.ACCENT))
	v.add_child(RimvaleUtils.label("Walk away undefeated with %d enemies defeated over %d round(s)." % [
		CardSystem.gauntlet_kills, CardSystem.round_num], 12, RimvaleColors.TEXT_LIGHT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var yes: Button = RimvaleUtils.button("🏁 Collect score", RimvaleColors.ACCENT, 36, 13)
	yes.pressed.connect(func() -> void:
		_close_popup()
		var err: String = CardSystem.end_gauntlet_run(_viewer)
		if err != "":
			_toast(err)
	)
	row.add_child(yes)
	var no: Button = RimvaleUtils.button("Keep fighting", RimvaleColors.TEXT_GRAY, 36, 13)
	no.pressed.connect(_close_popup)
	row.add_child(no)
	_popup = wrap

## Discard the currently selected hand card — free, any time on your turn.
func _on_discard_selected() -> void:
	if _input_locked() or _selected_hand < 0:
		return
	_do_action(CardSystem.discard_card(CardSystem.turn, _selected_hand))

func _build_center_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.custom_minimum_size = Vector2(170, 0)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_round_label = RimvaleUtils.label("", 13, RimvaleColors.TEXT_GRAY)
	info.add_child(_round_label)
	_turn_label = RimvaleUtils.label("", 17, RimvaleColors.GOLD)
	info.add_child(_turn_label)
	_energy_label = RimvaleUtils.label("", 15, RimvaleColors.WARNING)
	info.add_child(_energy_label)
	# Cancel button — appears whenever a card/attack/spell is waiting on a
	# target, so backing out never requires knowing about Esc/right-click.
	_cancel_btn = RimvaleUtils.button("✕ Cancel", RimvaleColors.DANGER, 30, 12)
	_cancel_btn.visible = false
	_cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_cancel_btn.pressed.connect(_clear_selection)
	info.add_child(_cancel_btn)
	# Free discard — always available for the selected hand card.
	_discard_btn = RimvaleUtils.button("🗑 Discard card", RimvaleColors.TEXT_GRAY, 30, 12)
	_discard_btn.visible = false
	_discard_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_discard_btn.pressed.connect(_on_discard_selected)
	info.add_child(_discard_btn)
	# Gauntlet only: walk away undefeated and bank the score.
	_bank_btn = RimvaleUtils.button("🏁 End Gauntlet", RimvaleColors.ACCENT, 30, 12)
	_bank_btn.visible = false
	_bank_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_bank_btn.pressed.connect(_open_bank_confirm)
	info.add_child(_bank_btn)
	bar.add_child(info)

	var log_panel: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD_DARK, RimvaleColors.DIVIDER, 8, 8)
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.custom_minimum_size = Vector2(0, 110)
	_log_box = RichTextLabel.new()
	_log_box.scroll_following = true
	_log_box.add_theme_font_size_override("normal_font_size", 11)
	_log_box.add_theme_color_override("default_color", RimvaleColors.TEXT_GRAY)
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.add_child(_log_box)
	bar.add_child(log_panel)

	var btn_col := VBoxContainer.new()
	btn_col.add_theme_constant_override("separation", 6)
	btn_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_draw_btn = RimvaleUtils.button("🃏 +1 Draw (1⚡)", RimvaleColors.PRIMARY, 40, 13)
	_draw_btn.custom_minimum_size = Vector2(160, 40)
	_draw_btn.pressed.connect(_on_draw_extra)
	btn_col.add_child(_draw_btn)
	_end_turn_btn = RimvaleUtils.button("End Turn ⏭", RimvaleColors.GOLD, 60, 18)
	_end_turn_btn.custom_minimum_size = Vector2(160, 60)
	_end_turn_btn.pressed.connect(_on_end_turn)
	btn_col.add_child(_end_turn_btn)
	bar.add_child(btn_col)
	return bar

# ── Board refresh (repopulate everything in place) ───────────────────────────

## The seat rendered at the bottom of the board (DISPLAY only — actions must
## keep passing CardSystem.turn). Vs AI the human always keeps their seat so
## they can spectate the enemy's moves; in hotseat it changes on handoff.
func _bottom_player() -> int:
	# Spectating: no seat belongs to the player, so follow whoever is acting.
	if CardSystem.spectator:
		return CardSystem.turn
	return _viewer

## Number of human-controlled seats this match.
func _human_seats() -> int:
	return CardSystem.num_players - CardSystem.ai_seats.size()

## True while the viewer must NOT be able to act (someone else's turn, an AI
## playing, the handoff overlay, or the match being over).
func _input_locked() -> bool:
	if CardSystem.spectator:
		return true
	return _handoff_active or _match_over or not CardSystem.match_active \
			or CardSystem.is_ai_turn() or CardSystem.turn != _viewer

func _refresh_board() -> void:
	if _handoff_active or _match_over:
		return
	if not CardSystem.match_active or CardSystem.players.size() < 2:
		return
	_hide_hover_preview()   # panels are about to be rebuilt under the cursor
	var me: int = _bottom_player()
	var pm: Dictionary = CardSystem.players[me]
	var compact: bool = CardSystem.num_players > 2

	_rebuild_opponent_area(compact)

	var my_mark: String = "▶ " if CardSystem.turn == me else ""
	if int(pm.get("hp", 0)) <= 0:
		_my_strip_label.text = "☠ %s\nDEFEATED — spectating" % str(pm.get("name", "?"))
		_my_strip_label.add_theme_color_override("font_color", RimvaleColors.TEXT_DIM)
	else:
		_my_strip_label.text = _player_stat_block(me, my_mark, true)
		_my_strip_label.add_theme_color_override("font_color", RimvaleColors.TEXT_WHITE)

	if CardSystem.conquest:
		_round_label.text = "Round %d · 🗺 %s (%d/%d)" % [
			CardSystem.round_num, CardSystem.conquest_region_name(),
			CardSystem.conquest_index + 1, CardSystem.conquest_order.size()]
	elif CardSystem.spectator:
		_round_label.text = "Round %d · 👁 spectating" % CardSystem.round_num
	elif CardSystem.gauntlet:
		_round_label.text = "Round %d · 🌊 defeated: %d" % [
			CardSystem.round_num, CardSystem.gauntlet_kills]
	else:
		_round_label.text = "Round %d" % CardSystem.round_num
	var active: Dictionary = CardSystem.players[CardSystem.turn]
	var over_limit: bool = CardSystem.hand_over_limit(CardSystem.turn)
	if CardSystem.is_ai_turn():
		_turn_label.text = "🤖 %s's turn — watch their moves…" % str(active.get("name", "?"))
		_turn_label.add_theme_color_override("font_color", RimvaleColors.DANGER)
	elif CardSystem.turn != me:
		_turn_label.text = "▶ %s's turn" % str(active.get("name", "?"))
		_turn_label.add_theme_color_override("font_color", RimvaleColors.TEXT_LIGHT)
	elif over_limit:
		_turn_label.text = "🗑 Hand over %d — click cards to discard" % CardSystem.HAND_MAX
		_turn_label.add_theme_color_override("font_color", RimvaleColors.DANGER)
	else:
		_turn_label.text = "▶ %s's turn" % str(pm.get("name", "?"))
		_turn_label.add_theme_color_override("font_color", RimvaleColors.GOLD)
	_energy_label.text = "⚡ %d/%d" % [int(pm.get("energy", 0)), mini(CardSystem.round_num, CardSystem.ENERGY_CAP)]
	_log_box.text = "\n".join(PackedStringArray(CardSystem.match_log))
	var not_my_turn: bool = CardSystem.is_ai_turn() or CardSystem.turn != me
	_end_turn_btn.disabled = not_my_turn or over_limit
	# Draw costs 1⚡ and pulls from the ACTIVE player's deck (not the bottom seat).
	_draw_btn.disabled = not_my_turn or over_limit or int(active.get("energy", 0)) < 1 \
			or (active.get("deck", []) as Array).is_empty()
	# Visible escape hatch for any pending targeting / placement mode.
	if _cancel_btn != null and is_instance_valid(_cancel_btn):
		var mode_txt: String = ""
		match _highlight_mode:
			"place":
				mode_txt = "✕ Cancel placing"
			"equip":
				mode_txt = "✕ Cancel equipping"
			"attack_target":
				mode_txt = "✕ Cancel attack"
			"spell_target":
				mode_txt = "✕ Cancel spell"
			"banish_target":
				mode_txt = "✕ Cancel banish"
		_cancel_btn.visible = mode_txt != "" and not not_my_turn
		if mode_txt != "":
			_cancel_btn.text = mode_txt
	# The free-discard button now rides the selected card itself.
	if _discard_btn != null and is_instance_valid(_discard_btn):
		_discard_btn.visible = false
	# Bank-the-run button lives for the whole gauntlet, on your own turn.
	if _bank_btn != null and is_instance_valid(_bank_btn):
		_bank_btn.visible = CardSystem.gauntlet and not not_my_turn

	_fill_slots(_my_slots_row, me, compact)
	_fill_hand()

## Free + rebuild the whole opponent area: every seat except the viewer, in
## turn order after them. Living seats get a clickable strip + slot row;
## eliminated seats keep a greyed strip so the roster stays visible.
func _rebuild_opponent_area(compact: bool) -> void:
	_clear_children(_opp_area)
	_opp_strips.clear()
	_opp_slot_rows.clear()
	for i in range(1, CardSystem.num_players):
		var seat: int = (_viewer + i) % CardSystem.num_players
		var p: Dictionary = CardSystem.players[seat]
		var alive: bool = int(p.get("hp", 0)) > 0
		# One horizontal line per opponent: square vitals block + slot row.
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		_opp_area.add_child(line)
		var strip: PanelContainer = _make_opp_strip(seat, alive)
		line.add_child(strip)
		_opp_strips[seat] = strip
		if not alive:
			continue
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 6 if compact else 8)
		line.add_child(row)
		_fill_slots(row, seat, compact)
		_opp_slot_rows[seat] = row

## One opponent's header strip: name, HP, hand/deck counts, AI/active markers.
## Living strips are clickable (direct attacks); defeated ones are inert.
## A player's vitals as a stacked multi-line block for a square panel:
##   ▶ 🤖 Name
##   HP 40/40 · AC 16
##   ✋7  📚28  🗑3
func _player_stat_block(seat: int, marks: String, mine: bool) -> String:
	var p: Dictionary = CardSystem.players[seat]
	var hand_txt: String = "✋%d/%d" % [(p.get("hand", []) as Array).size(), CardSystem.HAND_MAX] \
		if mine else "✋%d" % (p.get("hand", []) as Array).size()
	return "%s🂠 %s\nHP %d/%d · AC %d\n%s  📚%d  🗑%d" % [
		marks, str(p.get("name", "?")),
		int(p.get("hp", 0)), int(p.get("max_hp", 0)), CardSystem.player_ac(seat),
		hand_txt, (p.get("deck", []) as Array).size(),
		(p.get("graveyard", []) as Array).size()]

func _make_opp_strip(seat: int, alive: bool) -> PanelContainer:
	var p: Dictionary = CardSystem.players[seat]
	var panel: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD_DARK, RimvaleColors.DIVIDER, 8, 6)
	# Fixed-width square block instead of a full-width bar, centered beside
	# its slot row.
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(196, 0)
	var fs: int = 12 if CardSystem.num_players == 2 else 11
	if not alive:
		panel.modulate = Color(1, 1, 1, 0.55)
		var dead_txt: String = "☠ %s\nDEFEATED" % str(p.get("name", "?"))
		# Gauntlet: show when the replacement challenger marches in.
		if CardSystem.gauntlet and CardSystem.respawn_due.has(seat):
			var eta: int = maxi(0, int(CardSystem.respawn_due[seat]) - CardSystem.round_num)
			if eta <= 0:
				dead_txt += "\nchallenger arrives next round!"
			else:
				dead_txt += "\nchallenger in %d round(s)" % eta
		var dead_l: Label = RimvaleUtils.label(dead_txt, fs, RimvaleColors.TEXT_DIM)
		dead_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(dead_l)
		return panel
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var marks: String = ""
	if seat == CardSystem.turn:
		marks += "▶ "
	if CardSystem.is_ai_seat(seat):
		marks += "🤖 "
	var col: Color = RimvaleColors.GOLD if seat == CardSystem.turn else RimvaleColors.TEXT_LIGHT
	var body: String = _player_stat_block(seat, marks, false)
	if _highlight_mode == "attack_target":
		body += "\n⚔ tap to attack (1⚡)"
	var l: Label = RimvaleUtils.label(body, fs, col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(l)
	if _highlight_mode == "attack_target":
		_highlight_panel(panel, RimvaleColors.DANGER)
	_connect_click(panel, _on_enemy_strip_clicked.bind(seat))
	return panel

func _fill_slots(row: HBoxContainer, player: int, compact: bool) -> void:
	_clear_children(row)
	for slot in range(CardSystem.MAX_SLOTS):
		row.add_child(_make_slot_panel(player, slot, compact))

func _fill_hand() -> void:
	_clear_children(_hand_row)
	var hand: Array = CardSystem.players[_bottom_player()].get("hand", [])
	if hand.is_empty():
		var empty_l: Label = RimvaleUtils.label("(no cards in hand)", 12, RimvaleColors.TEXT_DIM)
		empty_l.custom_minimum_size = Vector2(0, HAND_SIZE.y)
		empty_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hand_row.add_child(empty_l)
		return
	for i in range(hand.size()):
		_hand_row.add_child(_make_hand_panel(i))

# ── Card frame building blocks (TCG look) ────────────────────────────────────

## Border color per card type: character gold, weapon orange, armor/shield
## cyan, feat green, spell purple.
func _type_color(card: Dictionary) -> Color:
	match str(card.get("ctype", "")):
		"character":
			return RimvaleColors.GOLD
		"equipment":
			if str(card.get("slot", "")) == "weapon":
				return RimvaleColors.ORANGE
			return RimvaleColors.CYAN
		"feat":
			return RimvaleColors.SUCCESS
		"spell":
			return RimvaleColors.SP_PURPLE
	return RimvaleColors.DIVIDER

## TCG-style card frame: dark bg, 2px type-colored border, rounded corners,
## soft drop shadow. _highlight_panel overrides the border color on top.
func _card_frame(border: Color, pad: int = 6) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = RimvaleColors.BG_CARD_DARK
	sb.set_corner_radius_all(10)
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	sb.shadow_size = 4
	sb.shadow_color = Color(0, 0, 0, 0.4)
	panel.add_theme_stylebox_override("panel", sb)
	return panel

## Portrait strip for a character card: lineage art cropped to cover the box,
## with an optional "LvN" badge overlapping the top-left corner. Falls back to
## a large glyph when no portrait exists for the lineage.
## Cached, sharpened portrait for a lineage. The source art is 1024²+, but
## cards show it at ~60–96px — an ~11× shrink. Plain runtime textures carry
## no mip chain, so that downscale aliases into a blur. Here each portrait is
## Lanczos-downscaled toward display size (crisp) and given mipmaps (clean at
## any further size), then cached so it is built once per lineage rather than
## reloaded on every board rebuild. Also slashes texture memory ~16×.
var _portrait_cache: Dictionary = {}   # lineage -> mipmapped Texture2D

func _card_portrait(lineage: String) -> Texture2D:
	if _portrait_cache.has(lineage):
		return _portrait_cache[lineage]
	var src: Texture2D = RimvaleUtils.get_portrait(lineage)
	if src == null:
		return null
	var img: Image = src.get_image()
	if img == null:
		_portrait_cache[lineage] = src   # can't process — use as-is
		return src
	img = img.duplicate()                # never mutate the shared image
	if img.is_compressed():
		img.decompress()
	var cap: int = 256                   # comfortably above the largest card slot
	var longest: int = maxi(img.get_width(), img.get_height())
	if longest > cap:
		var sc: float = float(cap) / float(longest)
		img.resize(maxi(1, int(img.get_width() * sc)),
			maxi(1, int(img.get_height() * sc)), Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_portrait_cache[lineage] = tex
	return tex

func _portrait_box(lineage: String, height: float, level: int = -1, glyph_pt: int = 26) -> Control:
	var box := MarginContainer.new()
	box.clip_contents = true
	box.custom_minimum_size = Vector2(0, height)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		box.add_theme_constant_override(side, 0)
	var tex: Texture2D = null
	if lineage != "":
		tex = _card_portrait(lineage)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# KEEP_ASPECT_CENTERED scales the art to fit fully INSIDE the box —
		# no crop, no bleed past the card frame. clip_contents on the rect
		# itself is the hard guarantee (COVERED mode overdraws without it).
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.clip_contents = true
		# Mip-filtered sampling — without this a 1024px source shown at
		# ~60px aliases into a blurry smear.
		tr.texture_filter = TextureRect.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tr)
	else:
		var glyph: Label = RimvaleUtils.label("🧙", glyph_pt, RimvaleColors.TEXT_DIM)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(glyph)
	if level > 0:
		var badge: Label = RimvaleUtils.label("Lv%d" % level, 9, RimvaleColors.GOLD)
		badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color(0, 0, 0, 0.7)
		bsb.set_corner_radius_all(5)
		bsb.content_margin_left = 4
		bsb.content_margin_right = 4
		bsb.content_margin_top = 1
		bsb.content_margin_bottom = 1
		badge.add_theme_stylebox_override("normal", bsb)
		box.add_child(badge)
	return box

## Tiny stat chip — colored text on a dark rounded pill.
func _chip(txt: String, color: Color, fs: int) -> Label:
	var l: Label = RimvaleUtils.label(txt, fs, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.35)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	l.add_theme_stylebox_override("normal", sb)
	return l

## Stat chip row for a character. `in_play` uses live HP/AP/free-SP values;
## hand cards show the printed maximums. Wraps when the card is narrow.
func _stat_chips(c: Dictionary, in_play: bool, compact: bool) -> Control:
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 3)
	flow.add_theme_constant_override("v_separation", 1)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs: int = 8 if compact else 9
	if in_play:
		flow.add_child(_chip("HP %d/%d" % [
			int(c.get("hp", 0)), int(c.get("max_hp", 0))], RimvaleColors.HP_GREEN, fs))
		flow.add_child(_chip("AP %d/%d" % [int(c.get("ap", 0)), int(c.get("max_ap", 0))], RimvaleColors.AP_BLUE, fs))
		flow.add_child(_chip("SP %d/%d" % [
			int(c.get("max_sp", 0)) - CardSystem.spell_sp_used(c), int(c.get("max_sp", 0))], RimvaleColors.SP_PURPLE, fs))
	else:
		flow.add_child(_chip("HP %d" % int(c.get("max_hp", 0)), RimvaleColors.HP_GREEN, fs))
		flow.add_child(_chip("AP %d" % int(c.get("max_ap", 0)), RimvaleColors.AP_BLUE, fs))
		flow.add_child(_chip("SP %d" % int(c.get("max_sp", 0)), RimvaleColors.SP_PURPLE, fs))
	flow.add_child(_chip("AC %d" % int(c.get("ac", 10)), RimvaleColors.TEXT_LIGHT, fs))
	# Unspent attribute points are worth shouting about.
	if in_play and int(c.get("stat_pts", 0)) > 0:
		flow.add_child(_chip("✋ %d pts" % int(c.get("stat_pts", 0)), RimvaleColors.GOLD, fs))
	return flow

# ── Slot panels ──────────────────────────────────────────────────────────────

func _make_slot_panel(player: int, slot: int, compact: bool) -> PanelContainer:
	var c = CardSystem.players[player]["slots"][slot]
	var occupied: bool = c != null
	var panel: PanelContainer
	if occupied:
		panel = _card_frame(_type_color(c))
		panel.mouse_entered.connect(_show_hover_preview.bind(c))
		panel.mouse_exited.connect(_hide_hover_preview)
		# Spent cards go grey: the active player's own card that can no
		# longer afford its next action this turn. Targeting highlights
		# applied later still override the border.
		if player == CardSystem.turn and player == _viewer and not CardSystem.can_act(c):
			_highlight_panel(panel, RimvaleColors.TEXT_DIM)
	else:
		# Empty slot: subtle placeholder — dim 1px border, centered "+".
		panel = PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = RimvaleColors.BG_CARD_DARK
		sb.set_corner_radius_all(10)
		sb.border_color = RimvaleColors.DIVIDER
		sb.set_border_width_all(1)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = SLOT_SIZE_COMPACT if compact else SLOT_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var hl: Color = _slot_highlight(player, slot, occupied)
	if hl.a > 0.0:
		_highlight_panel(panel, hl)
	elif not occupied:
		panel.modulate = Color(1, 1, 1, 0.7)

	if not occupied:
		var plus: Label = RimvaleUtils.label("+", 18 if compact else 22, RimvaleColors.TEXT_DIM)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(plus)
	else:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 1 if compact else 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(v)
		v.add_child(_portrait_box(str(c.get("lineage", "")), 36.0 if compact else 56.0,
				int(c.get("level", 1)), 20 if compact else 26))
		var name_l: Label = RimvaleUtils.label(str(c.get("name", "?")), 11 if compact else 13, RimvaleColors.TEXT_WHITE)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.clip_text = true
		name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(name_l)
		var lin_l: Label = RimvaleUtils.label(str(c.get("lineage", "")), 8 if compact else 9, RimvaleColors.TEXT_GRAY)
		lin_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lin_l.clip_text = true
		lin_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(lin_l)
		v.add_child(_hp_bar(int(c.get("hp", 0)), int(c.get("max_hp", 1)), compact))
		v.add_child(_stat_chips(c, true, compact))
		v.add_child(_trait_line(c, 8 if compact else 9))
		v.add_child(_gear_line(c, 8 if compact else 9))
		var cond_bits: Array = []
		for cond in (c.get("conds", {}) as Dictionary).keys():
			cond_bits.append("%s%s" % [str(COND_GLYPHS.get(str(cond), "•")), str(cond)])
		if not cond_bits.is_empty():
			var cond_l: Label = RimvaleUtils.label(" ".join(PackedStringArray(cond_bits)), 8 if compact else 9, RimvaleColors.ORANGE)
			cond_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cond_l.clip_text = true
			cond_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			v.add_child(cond_l)

	_connect_click(panel, _on_slot_clicked.bind(player, slot))
	return panel

## "⟡ Frozen Blood · Chilling Touch" — the card's lineage trait names.
func _trait_line(c: Dictionary, fs: int = 9) -> Label:
	var names: Array = []
	for tr in c.get("traits", []):
		names.append(str(tr.get("name", "")))
	var txt: String = ""
	if not names.is_empty():
		txt = "⟡ " + " · ".join(PackedStringArray(names))
	var l: Label = RimvaleUtils.label(txt, fs, RimvaleColors.CYAN)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## "⚔Longsword 🛡Chain Mail ★2 ✦1" line for a character in play.
func _gear_line(c: Dictionary, fs: int = 9) -> Label:
	var bits: Array = []
	if c.get("weapon") != null:
		bits.append("⚔%s" % CardSystem.card_title(c["weapon"]))
	if c.get("offhand") != null:
		bits.append("🗡%s" % CardSystem.card_title(c["offhand"]))
	if c.get("armor") != null:
		bits.append("🛡%s" % CardSystem.card_title(c["armor"]))
	if c.get("shield") != null:
		bits.append("🛡%s" % CardSystem.card_title(c["shield"]))
	var feats: Array = c.get("feats", [])
	if not feats.is_empty():
		bits.append("★%d" % feats.size())
	var spells: Array = c.get("spells", [])
	if not spells.is_empty():
		bits.append("✦%d" % spells.size())
	var txt: String = " ".join(PackedStringArray(bits)) if not bits.is_empty() else "no gear"
	var col: Color = RimvaleColors.TEXT_GRAY if not bits.is_empty() else RimvaleColors.TEXT_DIM
	var l: Label = RimvaleUtils.label(txt, fs, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l

func _hp_bar(cur: int, mx: int, compact: bool = false) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 8 if compact else 10)
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = float(maxi(1, mx))
	bar.value = float(clampi(cur, 0, mx))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.4)
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = RimvaleColors.DANGER.lerp(RimvaleColors.HP_GREEN, RimvaleUtils.pct(cur, mx))
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

## Border color for a slot in the current highlight mode (alpha 0 = none).
## "mine" is relative to the viewer; hostile modes light up EVERY living
## opponent's occupied slots (their rows only exist while they live).
func _slot_highlight(player: int, slot: int, occupied: bool) -> Color:
	var mine: bool = player == _viewer
	match _highlight_mode:
		"place":
			if mine and not occupied:
				return RimvaleColors.SUCCESS
		"equip":
			# Only light up characters that can actually take this card.
			if mine and occupied and _selected_hand >= 0:
				var hand: Array = CardSystem.players[CardSystem.turn].get("hand", [])
				if _selected_hand < hand.size() \
						and CardSystem.can_equip(hand[_selected_hand],
							CardSystem.players[player]["slots"][slot]):
					return RimvaleColors.SUCCESS
		"banish_target":
			if mine and occupied:
				return RimvaleColors.ACCENT
		"attack_target":
			if mine:
				if occupied and slot == _selected_slot:
					return RimvaleColors.GOLD          # the attacker
			elif occupied:
				return RimvaleColors.DANGER
		"spell_target":
			var sp: Dictionary = _pending_spell_card()
			if sp.is_empty():
				return Color.TRANSPARENT
			var kind: String = str(sp.get("kind", ""))
			var friendly: bool = kind == "heal" or kind == "buff"
			if friendly and mine and occupied:
				return RimvaleColors.SUCCESS
			if not friendly and mine and occupied and slot == _selected_slot:
				return RimvaleColors.GOLD              # the caster
			if not friendly and not mine and occupied:
				return RimvaleColors.DANGER
	return Color.TRANSPARENT

## The spell card pending targeting, or {} if the selection is stale.
func _pending_spell_card() -> Dictionary:
	if _selected_slot < 0 or _pending_spell < 0:
		return {}
	var c = CardSystem.players[CardSystem.turn]["slots"][_selected_slot]
	if c == null:
		return {}
	var spells: Array = c.get("spells", [])
	if _pending_spell >= spells.size():
		return {}
	return spells[_pending_spell]

## Replace a fresh panel's stylebox with a 2px colored-border copy.
func _highlight_panel(panel: PanelContainer, color: Color) -> void:
	var sb: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb == null:
		return
	var dup: StyleBoxFlat = sb.duplicate()
	dup.border_color = color
	dup.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", dup)

# ── Hand panels ──────────────────────────────────────────────────────────────

func _make_hand_panel(idx: int) -> PanelContainer:
	var me: int = _bottom_player()
	var hand: Array = CardSystem.players[me].get("hand", [])
	var card: Dictionary = hand[idx]
	var panel: PanelContainer = _card_frame(_type_color(card))
	panel.custom_minimum_size = HAND_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(_show_hover_preview.bind(card))
	panel.mouse_exited.connect(_hide_hover_preview)
	if me == CardSystem.turn and CardSystem.hand_over_limit(me):
		_highlight_panel(panel, RimvaleColors.DANGER)   # discard mode — clicks discard
	elif idx == _selected_hand:
		_highlight_panel(panel, RimvaleColors.GOLD)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)

	var ctype: String = str(card.get("ctype", ""))
	if ctype == "character":
		# Character card: portrait on top, name, lineage, stat chips, statline.
		v.add_child(_portrait_box(str(card.get("lineage", "")), 64.0, int(card.get("level", 1)), 30))
		var title: Label = RimvaleUtils.label(str(card.get("name", "?")), 12, RimvaleColors.TEXT_WHITE)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(title)
		var lin_l: Label = RimvaleUtils.label(str(card.get("lineage", "")), 9, RimvaleColors.TEXT_GRAY)
		lin_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lin_l.clip_text = true
		lin_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(lin_l)
		v.add_child(_stat_chips(card, false, false))
		var s: Array = card.get("stats", [0, 0, 0, 0, 0])
		var stat_l: Label = RimvaleUtils.label("S%d P%d I%d V%d D%d" % [
			int(s[0]), int(s[1]), int(s[2]), int(s[3]), int(s[4])], 9, RimvaleColors.TEXT_GRAY)
		stat_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(stat_l)
		v.add_child(_trait_line(card, 8))
	else:
		# Non-character card: big type glyph, name in the type color, chips,
		# then the rules summary.
		var tcol: Color = _type_color(card)
		var glyph: Label = RimvaleUtils.label(CardSystem.card_glyph(card), 22, tcol)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(glyph)
		var title2: Label = RimvaleUtils.label(CardSystem.card_title(card), 12, tcol)
		title2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title2.clip_text = true
		title2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(title2)
		if ctype == "spell":
			var chip_row := HBoxContainer.new()
			chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
			chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip_row.add_child(_chip("SP %d" % int(card.get("sc", 0)), RimvaleColors.SP_PURPLE, 9))
			v.add_child(chip_row)
		elif ctype == "feat":
			var chip_row2 := HBoxContainer.new()
			chip_row2.alignment = BoxContainer.ALIGNMENT_CENTER
			chip_row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip_row2.add_child(_chip("★ tier %d" % int(card.get("tier", 1)), RimvaleColors.SUCCESS, 9))
			v.add_child(chip_row2)
		var sum_l: Label = RimvaleUtils.label(CardSystem.card_summary(card), 9, RimvaleColors.TEXT_GRAY)
		sum_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sum_l.max_lines_visible = 4
		sum_l.custom_minimum_size = Vector2(120, 0)
		sum_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(sum_l)

	# Selected card carries its own discard + banish buttons along the bottom.
	if idx == _selected_hand and me == CardSystem.turn and not _input_locked():
		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 3)
		btn_row.size_flags_vertical = Control.SIZE_SHRINK_END
		v.add_child(btn_row)
		var dis: Button = RimvaleUtils.button("🗑 Discard", RimvaleColors.DANGER, 22, 10)
		dis.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		dis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dis.pressed.connect(func() -> void:
			_do_action(CardSystem.discard_card(CardSystem.turn, idx))
		)
		btn_row.add_child(dis)
		var ban: Button = RimvaleUtils.button("✦ Banish", RimvaleColors.ACCENT, 22, 10)
		ban.tooltip_text = "Remove this card from the match forever for a powerful boon."
		ban.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ban.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ban.pressed.connect(_open_banish_popup.bind(idx))
		btn_row.add_child(ban)

	_connect_click(panel, _on_hand_clicked.bind(idx))
	return panel

# ── Click routing / state machine ────────────────────────────────────────────

func _on_hand_clicked(idx: int) -> void:
	if _input_locked():
		return
	_close_popup()
	var hand: Array = CardSystem.players[CardSystem.turn].get("hand", [])
	if idx < 0 or idx >= hand.size():
		return
	if CardSystem.hand_over_limit(CardSystem.turn):
		# Discard mode — over the limit, hand clicks throw cards away instead.
		var over: int = hand.size() - CardSystem.HAND_MAX
		var err: String = CardSystem.discard_card(CardSystem.turn, idx)
		if err != "":
			_toast(err)
		elif over - 1 > 0:
			_toast("🗑 Discarded — %d more to go." % (over - 1))
		else:
			_toast("🗑 Hand legal — carry on.")
		_refresh_board()
		return
	if _selected_hand == idx:
		_clear_selection()          # toggle off
		return
	_selected_hand = idx
	_selected_slot = -1
	_pending_spell = -1
	_pending_banish = -1
	_pending_boon = ""
	var card: Dictionary = hand[idx]
	if str(card.get("ctype", "")) == "character":
		_highlight_mode = "place"
	else:
		_highlight_mode = "equip"
	_refresh_board()

func _on_slot_clicked(player: int, slot: int) -> void:
	if _input_locked():
		return
	var me: int = CardSystem.turn
	var p: Dictionary = CardSystem.players[me]
	match _highlight_mode:
		"banish_target":
			if player == me and p["slots"][slot] != null:
				_do_action(CardSystem.banish_card(me, _pending_banish, _pending_boon, slot))
			else:
				_toast("Pick one of your own characters in play.")
		"place":
			if player == me and p["slots"][slot] == null:
				_do_action(CardSystem.play_character(me, _selected_hand, slot))
			elif player == me and p["slots"][slot] != null:
				_open_sacrifice_confirm(_selected_hand, slot)
			else:
				_toast("Empty slot = play the card · your character = sacrifice to them.")
		"equip":
			if player == me and p["slots"][slot] != null:
				var hand_cards: Array = CardSystem.players[me].get("hand", [])
				var eq_card: Dictionary = hand_cards[_selected_hand] \
					if _selected_hand >= 0 and _selected_hand < hand_cards.size() else {}
				# Dual-wielders choose which hand takes the weapon.
				if not eq_card.is_empty() \
						and CardSystem.weapon_needs_hand_choice(eq_card, p["slots"][slot]):
					_open_hand_choice_popup(_selected_hand, slot)
				else:
					_do_action(CardSystem.equip_card(me, _selected_hand, slot))
			else:
				_toast("Pick one of your characters who can take this card.")
		"attack_target":
			if player != me and CardSystem.players[player]["slots"][slot] != null:
				_do_action(CardSystem.attack(me, _selected_slot, player, slot))
			else:
				_toast("Pick an enemy character — or an enemy strip for a direct hit.")
		"spell_target":
			_try_cast_at(player, slot)
		_:
			if player == me and p["slots"][slot] != null:
				_selected_slot = slot
				_open_action_popup(slot)

func _try_cast_at(player: int, slot: int) -> void:
	var me: int = CardSystem.turn
	var sp: Dictionary = _pending_spell_card()
	if sp.is_empty():
		_clear_selection()
		return
	var kind: String = str(sp.get("kind", ""))
	var friendly: bool = kind == "heal" or kind == "buff"
	var valid_side: bool
	if friendly:
		valid_side = player == me
	else:
		valid_side = player != me and int(CardSystem.players[player].get("hp", 0)) > 0
	if not valid_side or CardSystem.players[player]["slots"][slot] == null:
		_toast("Pick a valid target for %s." % str(sp.get("name", "the spell")))
		return
	# Area spells resolve against the clicked player's whole side.
	var target_slot: int = -1 if int(sp.get("area", 0)) > 0 else slot
	_do_action(CardSystem.cast_spell(me, _selected_slot, _pending_spell, player, target_slot))

## Direct attack on an opponent — their strip is the target in attack mode.
func _on_enemy_strip_clicked(seat: int) -> void:
	if _input_locked():
		return
	if _highlight_mode == "attack_target" and _selected_slot >= 0:
		_do_action(CardSystem.attack(CardSystem.turn, _selected_slot, seat, -1))

## Toast the error, or clear selection + refresh on success.
func _do_action(err: String) -> void:
	if err != "":
		_toast(err)
		return
	_clear_selection()

func _clear_selection() -> void:
	if _handoff_active or _match_over:
		return
	_selected_hand = -1
	_selected_slot = -1
	_pending_spell = -1
	_pending_banish = -1
	_pending_boon = ""
	_highlight_mode = ""
	_close_popup()
	_refresh_board()

# ── Action popup ─────────────────────────────────────────────────────────────

func _open_action_popup(slot: int) -> void:
	if _input_locked():
		return
	_close_popup()
	var me: int = CardSystem.turn
	var c = CardSystem.players[me]["slots"][slot]
	if c == null:
		return
	var wrap := CenterContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(wrap)
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_connect_click(wrap, func() -> void:
		_selected_slot = -1
		_close_popup()
	)
	var panel: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.ACCENT, 10, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(260, 0)
	wrap.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	v.add_child(RimvaleUtils.label("%s %s — AP %d/%d · SP %d/%d" % [
		CardSystem.card_glyph(c), str(c.get("name", "?")),
		int(c.get("ap", 0)), int(c.get("max_ap", 0)),
		int(c.get("max_sp", 0)) - CardSystem.spell_sp_used(c),
		int(c.get("max_sp", 0))], 14, RimvaleColors.TEXT_WHITE))

	# Escalating fatigue: this card's next action costs acts+1 AP.
	var act_cost: int = CardSystem.action_cost(c)
	var can_act: bool = CardSystem.can_act(c)

	var just_played: bool = int(c.get("played_round", -1)) == CardSystem.round_num
	var atk: Button = RimvaleUtils.button(
		"⚔ Attack (next round)" if just_played
		else "⚔ Attack (%d AP · 🎲%+d)" % [act_cost, CardSystem.attack_mod(c)],
		RimvaleColors.DANGER, 40, 13)
	atk.disabled = not can_act or just_played
	atk.pressed.connect(func() -> void:
		_selected_slot = slot
		_pending_spell = -1
		_highlight_mode = "attack_target"
		_close_popup()
		_refresh_board()
	)
	v.add_child(atk)

	var spells: Array = c.get("spells", [])
	for i in range(spells.size()):
		var sp: Dictionary = spells[i]
		var sname: String = str(sp.get("name", "?"))
		var roll_sfx: String = ""
		if bool(sp.get("atk", false)):
			roll_sfx = " · 🎲%+d" % CardSystem.spell_mod(c)
		var b: Button = RimvaleUtils.button("✦ Cast %s (%d AP%s)" % [sname, act_cost, roll_sfx], RimvaleColors.SP_PURPLE, 36, 12)
		b.disabled = CardSystem.spell_exhausted(c, sname) or not can_act
		var spell_idx: int = i
		b.pressed.connect(func() -> void:
			_on_cast_pressed(slot, spell_idx)
		)
		v.add_child(b)

	# Second wind: 1 player energy refills the card's AP (fatigue remains).
	var my_energy: int = int(CardSystem.players[me].get("energy", 0))
	var refresh: Button = RimvaleUtils.button("⚡ Refresh AP (1 energy)", RimvaleColors.WARNING, 36, 12)
	refresh.disabled = my_energy < 1 or int(c.get("ap", 0)) >= int(c.get("max_ap", 0))
	refresh.pressed.connect(func() -> void:
		_close_popup()
		_do_action(CardSystem.refresh_ap(CardSystem.turn, slot))
	)
	v.add_child(refresh)

	# ── Attribute assignment: auto vs manual, and spending banked points ──
	var manual: bool = str(c.get("stat_mode", "auto")) == "manual"
	var pts: int = int(c.get("stat_pts", 0))
	var mode_btn: Button = RimvaleUtils.button(
		"✋ Manual attributes" if manual else "🎲 Auto attributes",
		RimvaleColors.WARNING if manual else RimvaleColors.TEXT_LIGHT, 32, 12)
	mode_btn.tooltip_text = "Auto spends level-up points on the strongest stat. Manual banks them for you to place."
	mode_btn.pressed.connect(func() -> void:
		var e2: String = CardSystem.set_stat_mode(CardSystem.turn, slot, "auto" if manual else "manual")
		if e2 != "":
			_toast(e2)
		_close_popup()
		_refresh_board()
		_open_action_popup(slot)
	)
	v.add_child(mode_btn)
	if pts > 0:
		v.add_child(RimvaleUtils.label("Attribute points: %d" % pts, 12, RimvaleColors.GOLD))
		var stat_row := HBoxContainer.new()
		stat_row.add_theme_constant_override("separation", 3)
		v.add_child(stat_row)
		var cs: Array = c.get("stats", [0, 0, 0, 0, 0])
		for i in range(5):
			var sb: Button = RimvaleUtils.button("%s %d" % [
				str(CardSystem.STAT_NAMES[i]), int(cs[i])], RimvaleColors.ACCENT, 30, 11)
			sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sb.disabled = int(cs[i]) >= CardSystem.STAT_CAP
			var si: int = i
			sb.pressed.connect(func() -> void:
				var e3: String = CardSystem.assign_stat_point(CardSystem.turn, slot, si)
				if e3 != "":
					_toast(e3)
				_close_popup()
				_refresh_board()
				_open_action_popup(slot)
			)
			stat_row.add_child(sb)

	# Tactical retreat: pull the card back to hand, rested, for 1 energy.
	var stow: Button = RimvaleUtils.button("↩ Stow to hand (1 energy)", RimvaleColors.CYAN, 36, 12)
	stow.tooltip_text = "Withdraw this character to your hand. They return at full HP but keep their levels and gear."
	stow.disabled = my_energy < 1 \
		or (CardSystem.players[me].get("hand", []) as Array).size() >= CardSystem.HAND_MAX
	stow.pressed.connect(func() -> void:
		_close_popup()
		_do_action(CardSystem.stow_character(CardSystem.turn, slot))
	)
	v.add_child(stow)

	var det: Button = RimvaleUtils.button("View details", RimvaleColors.TEXT_LIGHT, 34, 12)
	det.pressed.connect(func() -> void:
		_close_popup()
		_open_detail_popup(slot)
	)
	v.add_child(det)

	var cls: Button = RimvaleUtils.button("Close", RimvaleColors.TEXT_GRAY, 30, 12)
	cls.pressed.connect(func() -> void:
		_selected_slot = -1
		_close_popup()
	)
	v.add_child(cls)
	_popup = wrap

func _on_cast_pressed(slot: int, spell_idx: int) -> void:
	if _input_locked():
		return
	var me: int = CardSystem.turn
	var c = CardSystem.players[me]["slots"][slot]
	if c == null:
		_clear_selection()
		return
	var spells: Array = c.get("spells", [])
	if spell_idx < 0 or spell_idx >= spells.size():
		_clear_selection()
		return
	var sp: Dictionary = spells[spell_idx]
	_close_popup()
	_selected_slot = slot
	_pending_spell = spell_idx
	var kind: String = str(sp.get("kind", ""))
	var friendly: bool = kind == "heal" or kind == "buff"
	if int(sp.get("area", 0)) > 0:
		if friendly:
			# Friendly area spells never need targeting — your whole side.
			_do_action(CardSystem.cast_spell(me, slot, spell_idx, me, -1))
			return
		var opps: Array = CardSystem.living_opponents(me)
		if opps.size() == 1:
			# Only one side left to hit — no targeting needed.
			_do_action(CardSystem.cast_spell(me, slot, spell_idx, int(opps[0]), -1))
			return
		# Several enemy sides: click ANY character on a side to hit them all.
		_highlight_mode = "spell_target"
		_refresh_board()
		return
	_highlight_mode = "spell_target"
	_refresh_board()

# ── Detail popup ─────────────────────────────────────────────────────────────

func _open_detail_popup(slot: int) -> void:
	_close_popup()
	var c = CardSystem.players[CardSystem.turn]["slots"][slot]
	if c == null:
		return
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_connect_click(dim, _close_popup)
	var center := CenterContainer.new()
	dim.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.ACCENT, 10, 14)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	v.add_child(_portrait_box(str(c.get("lineage", "")), 96.0, -1, 40))
	v.add_child(RimvaleUtils.label("%s %s — Lv%d %s" % [
		CardSystem.card_glyph(c), str(c.get("name", "?")),
		int(c.get("level", 1)), str(c.get("lineage", ""))], 17, RimvaleColors.GOLD))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	_fill_detail_body(body, c)

	var close: Button = RimvaleUtils.button("Close", RimvaleColors.TEXT_GRAY, 36, 13)
	close.pressed.connect(_close_popup)
	v.add_child(close)
	_popup = dim

## Shared body content for a character card's full details — used by both
## the click-to-open detail popup and the hover preview.
func _fill_detail_body(body: VBoxContainer, c: Dictionary) -> void:
	var s: Array = c.get("stats", [0, 0, 0, 0, 0])
	body.add_child(_detail_label("HP %d/%d   AP %d/%d   SP %d/%d   AC %d" % [
		int(c.get("hp", 0)), int(c.get("max_hp", 0)),
		int(c.get("ap", 0)), int(c.get("max_ap", 0)),
		int(c.get("max_sp", 0)) - CardSystem.spell_sp_used(c), int(c.get("max_sp", 0)),
		int(c.get("ac", 10))], 13, RimvaleColors.TEXT_WHITE))
	body.add_child(_detail_label("STR %d  SPD %d  INT %d  VIT %d  DIV %d" % [
		int(s[0]), int(s[1]), int(s[2]), int(s[3]), int(s[4])], 12, RimvaleColors.TEXT_LIGHT))
	body.add_child(_detail_label("Attributes: %s%s" % [
		"✋ manual" if str(c.get("stat_mode", "auto")) == "manual" else "🎲 auto",
		"  ·  %d point(s) to spend" % int(c.get("stat_pts", 0)) if int(c.get("stat_pts", 0)) > 0 else ""],
		11, RimvaleColors.GOLD if int(c.get("stat_pts", 0)) > 0 else RimvaleColors.TEXT_GRAY))
	body.add_child(_detail_label("XP %d/%d" % [int(c.get("xp", 0)), int(c.get("xp_req", 10))], 12, RimvaleColors.CYAN))
	body.add_child(_detail_label("Feat points: %d/%d used" % [
		CardSystem.feat_points_used(c), CardSystem.feat_budget(c)], 12, RimvaleColors.WARNING))
	body.add_child(_detail_label("Spell SP: %d/%d used" % [
		CardSystem.spell_sp_used(c), int(c.get("max_sp", 0))], 12, RimvaleColors.SP_PURPLE))
	body.add_child(_detail_label("Kills: %d" % int(c.get("kills", 0)), 12, RimvaleColors.TEXT_GRAY))

	body.add_child(_detail_label("— Lineage Traits —", 12, RimvaleColors.ACCENT))
	var trs: Array = c.get("traits", [])
	if trs.is_empty():
		body.add_child(_detail_label("(none)", 11, RimvaleColors.TEXT_DIM))
	for tr in trs:
		body.add_child(_detail_label("⟡ %s — %s" % [
			str(tr.get("name", "?")), str(tr.get("desc", ""))], 11, RimvaleColors.CYAN))
	if bool(c.get("cheat_death_used", false)):
		body.add_child(_detail_label("   (cheat-death already spent)", 10, RimvaleColors.TEXT_DIM))

	body.add_child(_detail_label("— Equipment —", 12, RimvaleColors.ACCENT))
	var has_gear: bool = false
	for key in ["weapon", "offhand", "armor", "shield"]:
		var item = c.get(key)
		if item != null:
			has_gear = true
			body.add_child(_detail_label("%s %s — %s" % [
				CardSystem.card_glyph(item), CardSystem.card_title(item),
				CardSystem.card_summary(item)], 11, RimvaleColors.TEXT_LIGHT))
	if not has_gear:
		body.add_child(_detail_label("(no equipment)", 11, RimvaleColors.TEXT_DIM))

	body.add_child(_detail_label("— Feats —", 12, RimvaleColors.ACCENT))
	var feats: Array = c.get("feats", [])
	if feats.is_empty():
		body.add_child(_detail_label("(none)", 11, RimvaleColors.TEXT_DIM))
	for fc in feats:
		body.add_child(_detail_label("★ %s — %s" % [str(fc.get("name", "?")), str(fc.get("desc", ""))], 11, RimvaleColors.TEXT_LIGHT))

	body.add_child(_detail_label("— Spells —", 12, RimvaleColors.ACCENT))
	var spells: Array = c.get("spells", [])
	if spells.is_empty():
		body.add_child(_detail_label("(none)", 11, RimvaleColors.TEXT_DIM))
	for sp in spells:
		var used: String = ""
		if CardSystem.spell_exhausted(c, str(sp.get("name", ""))):
			used = "  [used this round]"
		body.add_child(_detail_label("✦ %s — %s%s" % [str(sp.get("name", "?")), str(sp.get("desc", "")), used], 11, RimvaleColors.TEXT_LIGHT))

	var conds: Dictionary = c.get("conds", {})
	if not conds.is_empty():
		body.add_child(_detail_label("— Conditions —", 12, RimvaleColors.ACCENT))
		for cond in conds.keys():
			body.add_child(_detail_label("%s %s — %d turn(s) left" % [
				str(COND_GLYPHS.get(str(cond), "•")), str(cond), int(conds[cond])], 11, RimvaleColors.ORANGE))

func _detail_label(txt: String, font_size: int, color: Color) -> Label:
	var l: Label = RimvaleUtils.label(txt, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 0)
	return l

# ── Hover preview — full card details while the mouse rests on a card ────────
var _hover_panel: PanelContainer = null

func _show_hover_preview(card) -> void:
	if _handoff_active or _match_over or card == null:
		return
	_hide_hover_preview()
	var cd: Dictionary = card
	_hover_panel = _card_frame(_type_color(cd))
	_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_panel.z_index = 60
	add_child(_hover_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_panel.add_child(v)
	if str(cd.get("ctype", "")) == "character":
		v.add_child(_portrait_box(str(cd.get("lineage", "")), 80.0, -1, 34))
		v.add_child(RimvaleUtils.label("%s %s — Lv%d %s" % [
			CardSystem.card_glyph(cd), str(cd.get("name", "?")),
			int(cd.get("level", 1)), str(cd.get("lineage", ""))], 15, RimvaleColors.GOLD))
		_fill_detail_body(v, cd)
	else:
		v.add_child(RimvaleUtils.label("%s %s" % [
			CardSystem.card_glyph(cd), str(cd.get("name", "?"))], 15, _type_color(cd)))
		var kind_txt: String = str(cd.get("ctype", "")).capitalize()
		if cd.has("slot"):
			kind_txt += " — " + str(cd.get("slot", "")).capitalize() + " slot"
		v.add_child(_detail_label(kind_txt, 11, RimvaleColors.TEXT_GRAY))
		v.add_child(_detail_label(str(cd.get("desc", CardSystem.card_summary(cd))), 12, RimvaleColors.TEXT_LIGHT))
	# Anchor to the right edge, vertically centred — a side preview that is
	# never under the cursor, so it cannot flicker or block clicks.
	_hover_panel.call_deferred("set_anchors_and_offsets_preset",
		Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 14)

func _hide_hover_preview() -> void:
	if _hover_panel != null and is_instance_valid(_hover_panel):
		_hover_panel.queue_free()
	_hover_panel = null

## Ask which hand a weapon goes into. Only shown for dual-wielders who are
## already holding something — each hand shows what would happen to it, so a
## character can carry two separately-forged copies of the same weapon.
func _open_hand_choice_popup(hand_idx: int, slot: int) -> void:
	_close_popup()
	var me: int = CardSystem.turn
	var hand_cards: Array = CardSystem.players[me].get("hand", [])
	var tgt = CardSystem.players[me]["slots"][slot]
	if hand_idx < 0 or hand_idx >= hand_cards.size() or tgt == null:
		return
	var card: Dictionary = hand_cards[hand_idx]
	var wrap := CenterContainer.new()
	add_child(wrap)
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.ORANGE, 10, 14)
	wrap.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(RimvaleUtils.label("⚔ Which hand for %s?" % CardSystem.card_title(card),
		16, RimvaleColors.ORANGE))
	v.add_child(RimvaleUtils.label("%s fights with two weapons." % str(tgt["name"]),
		11, RimvaleColors.TEXT_GRAY))
	for h in [["weapon", "Main hand"], ["offhand", "Off hand"]]:
		var hand_key: String = str(h[0])
		var worn = tgt.get(hand_key)
		var action: String = CardSystem.weapon_hand_action(card, tgt, hand_key)
		var holding: String = CardSystem.card_title(worn) if worn != null else "empty"
		var btn: Button = RimvaleUtils.button(
			"%s — %s  (%s)" % [str(h[1]), holding, action if action != "" else "already +3"],
			RimvaleColors.CYAN, 40, 13)
		btn.custom_minimum_size = Vector2(300, 40)
		btn.disabled = action == ""
		btn.pressed.connect(func() -> void:
			_close_popup()
			_do_action(CardSystem.equip_card(CardSystem.turn, hand_idx, slot, hand_key))
		)
		v.add_child(btn)
	var cancel: Button = RimvaleUtils.button("Cancel", RimvaleColors.TEXT_GRAY, 32, 12)
	cancel.pressed.connect(_close_popup)
	v.add_child(cancel)
	_popup = wrap

## Confirm before feeding a hand character to one in play (+1 level).
func _open_sacrifice_confirm(hand_idx: int, slot: int) -> void:
	_close_popup()
	var me: int = CardSystem.turn
	var hand: Array = CardSystem.players[me].get("hand", [])
	var tgt = CardSystem.players[me]["slots"][slot]
	if hand_idx < 0 or hand_idx >= hand.size() or tgt == null:
		return
	var off: Dictionary = hand[hand_idx]
	if str(off.get("ctype", "")) != "character":
		_toast("Only character cards can be sacrificed.")
		return
	var wrap := CenterContainer.new()
	add_child(wrap)
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.DANGER, 10, 14)
	wrap.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(RimvaleUtils.label("⚰ Sacrifice %s?" % str(off.get("name", "?")), 16, RimvaleColors.DANGER))
	v.add_child(RimvaleUtils.label("%s gains +1 level (1 energy). The offering is lost." % str(tgt.get("name", "?")),
		12, RimvaleColors.TEXT_LIGHT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var yes: Button = RimvaleUtils.button("⚰ Sacrifice", RimvaleColors.DANGER, 36, 13)
	yes.pressed.connect(func() -> void:
		_close_popup()
		_do_action(CardSystem.sacrifice_character(CardSystem.turn, hand_idx, slot))
	)
	row.add_child(yes)
	var no: Button = RimvaleUtils.button("Cancel", RimvaleColors.TEXT_GRAY, 36, 13)
	no.pressed.connect(_close_popup)
	row.add_child(no)
	_popup = wrap

func _close_popup() -> void:
	_hide_hover_preview()
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null

# ── End turn + hotseat handoff ───────────────────────────────────────────────

## "🃏 +1 Draw" button — pay 1 energy for an extra card (engine validates).
func _on_draw_extra() -> void:
	if _input_locked():
		return
	var err: String = CardSystem.draw_extra(CardSystem.turn)
	if err != "":
		_toast(err)
	else:
		_refresh_board()

func _on_end_turn() -> void:
	if _handoff_active or _match_over:
		return
	if CardSystem.is_ai_turn():
		_toast("The enemy is taking its turn…")
		return
	if CardSystem.turn != _viewer:
		return
	_selected_hand = -1
	_selected_slot = -1
	_pending_spell = -1
	_highlight_mode = ""
	_close_popup()
	# end_turn skips dead seats and starts a new round when rotation wraps.
	# The "turn" event fires during this call, so the handoff overlay may
	# already be up by the time it returns (see _on_card_event).
	var err: String = CardSystem.end_turn(CardSystem.turn)
	if err != "":
		_toast(err)
		_refresh_board()
		return
	if _match_over:
		return                      # victory fired during upkeep
	if CardSystem.is_ai_turn():
		_refresh_board()            # no overlay — the AI's moves play out live
		return
	if CardSystem.turn != _viewer and _human_seats() >= 2:
		_show_handoff(CardSystem.turn)   # no-op if the turn event already showed it
	else:
		_viewer = CardSystem.turn
		_refresh_board()

## Opaque pass-the-device overlay. Guarded against duplicates — both
## _on_end_turn and the "turn" event may request it for the same turn.
func _show_handoff(next_player: int) -> void:
	if _match_over:
		return
	if _overlay != null and is_instance_valid(_overlay):
		return
	_close_popup()
	_handoff_active = true
	var overlay := ColorRect.new()
	overlay.color = RimvaleColors.BG_DARK               # fully opaque — no peeking
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)                                  # added last = on top of everything
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	center.add_child(v)
	var glyph: Label = RimvaleUtils.label("🂠", 42, RimvaleColors.ACCENT)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(glyph)
	var pname: String = "?"
	if next_player >= 0 and next_player < CardSystem.players.size():
		pname = str(CardSystem.players[next_player].get("name", "?"))
	var title: Label = RimvaleUtils.label("Pass to %s" % pname, 26, RimvaleColors.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub: Label = RimvaleUtils.label("No peeking — hand the device over!", 13, RimvaleColors.TEXT_GRAY)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var ready_btn: Button = RimvaleUtils.button("▶ I'm ready", RimvaleColors.SUCCESS, 54, 18)
	ready_btn.pressed.connect(func() -> void:
		_handoff_active = false
		_viewer = CardSystem.turn       # the new player takes the bottom seat
		if _overlay != null and is_instance_valid(_overlay):
			_overlay.queue_free()
		_overlay = null
		_refresh_board()
	)
	v.add_child(ready_btn)
	_overlay = overlay

# ── Victory ──────────────────────────────────────────────────────────────────

## Campaign screen shown after each conquest battle: spoils and the march
## onward, or the run's final tally.
func _show_conquest_result() -> void:
	var res: Dictionary = CardSystem.conquest_resolve()
	var won: bool = bool(res["won"])
	var complete: bool = bool(res["complete"])
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	dim.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD,
		RimvaleColors.GOLD if won else RimvaleColors.DANGER, 12, 20)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var title: Label
	if complete:
		title = RimvaleUtils.label("👑 RIMVALE CONQUERED", 26, RimvaleColors.GOLD)
	elif won:
		title = RimvaleUtils.label("🗺 %s TAKEN" % str(res["region"]).to_upper(), 24, RimvaleColors.GOLD)
	else:
		title = RimvaleUtils.label("🗺 THE CONQUEST ENDS", 24, RimvaleColors.DANGER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var sub: Label = RimvaleUtils.label(
		"%d of %d regions conquered." % [int(res["regions_taken"]), int(res["total"])],
		14, RimvaleColors.TEXT_LIGHT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	if won and not (res["rewards"] as Array).is_empty():
		v.add_child(RimvaleUtils.label("— Spoils of war —", 12, RimvaleColors.ACCENT))
		for c in res["rewards"]:
			v.add_child(RimvaleUtils.label("%s %s" % [
				CardSystem.card_glyph(c), CardSystem.card_title(c)], 12, RimvaleColors.TEXT_LIGHT))
		v.add_child(RimvaleUtils.label(
			"Your army keeps every level, weapon and feat it earned.",
			11, RimvaleColors.TEXT_GRAY))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	if won and not complete:
		var march: Button = RimvaleUtils.button("⚔ March on ▸", RimvaleColors.GOLD, 46, 15)
		march.custom_minimum_size = Vector2(200, 46)
		march.pressed.connect(func() -> void:
			var e: String = CardSystem.start_conquest_battle()
			if e != "":
				_toast(e)
				return
			get_tree().reload_current_scene())
		row.add_child(march)
	var quit_b: Button = RimvaleUtils.button(
		"Return to Title" if (complete or not won) else "Abandon run",
		RimvaleColors.TEXT_LIGHT, 46, 14)
	quit_b.custom_minimum_size = Vector2(180, 46)
	quit_b.pressed.connect(func() -> void:
		CardSystem.end_conquest()
		CardSystem.end_match()
		get_tree().change_scene_to_file("res://scenes/title/title_screen.tscn"))
	row.add_child(quit_b)

func _show_victory(data: Dictionary) -> void:
	if _match_over:
		return
	_match_over = true
	_handoff_active = false
	_close_popup()
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	# A conquest battle resolves into its own campaign screen.
	if CardSystem.conquest:
		_show_conquest_result()
		return
	var w: int = int(data.get("winner", CardSystem.winner))
	var wname: String = str(data.get("name", "?"))

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	dim.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.GOLD, 12, 20)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var title: Label
	var rounds: Label
	if bool(data.get("gauntlet", false)):
		var banked: bool = bool(data.get("banked", false))
		title = RimvaleUtils.label(
			"🌊 GAUNTLET BANKED" if banked else "🌊 THE GAUNTLET ENDS",
			26, RimvaleColors.GOLD if banked else RimvaleColors.DANGER)
		rounds = RimvaleUtils.label(
			("%s walked away undefeated after %d round(s) — %d enemies defeated." if banked
			else "%s fell after %d round(s) — %d enemies defeated.") % [
				str(data.get("runner", "The runner")), int(data.get("rounds", CardSystem.round_num)),
				int(data.get("kills", 0))], 14, RimvaleColors.GOLD)
	else:
		title = RimvaleUtils.label("🏆 %s WINS!" % wname, 26, RimvaleColors.GOLD)
		rounds = RimvaleUtils.label("Match over after %d round(s)." % CardSystem.round_num, 13, RimvaleColors.TEXT_LIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	rounds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rounds)
	for i in range(CardSystem.num_players):
		var p: Dictionary = CardSystem.players[i]
		var fell: bool = bool(p.get("eliminated", false)) or int(p.get("hp", 0)) <= 0
		var mark: String = "👑 " if i == w else ("☠ " if fell else "")
		var line: Label = RimvaleUtils.label("%s%s — %d/%d HP remaining" % [
			mark, str(p.get("name", "?")), maxi(0, int(p.get("hp", 0))), int(p.get("max_hp", 0))],
			14, RimvaleColors.GOLD if i == w else RimvaleColors.TEXT_GRAY)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(line)
	var back: Button = RimvaleUtils.button("Return to Title", RimvaleColors.GOLD, 50, 16)
	back.pressed.connect(func() -> void:
		CardSystem.end_match()
		get_tree().change_scene_to_file(TITLE_SCENE)
	)
	v.add_child(back)

# ── CardSystem events ────────────────────────────────────────────────────────

func _on_card_event(kind: String, data: Dictionary) -> void:
	match kind:
		"victory":
			_show_victory(data)
		"turn":
			var tseat: int = int(data.get("player", CardSystem.turn))
			if CardSystem.is_ai_seat(tseat):
				# An AI's turn begins — drop stale highlights while spectating.
				_clear_selection()
				_close_popup()
			elif tseat == _viewer:
				if CardSystem.ai_enabled:
					_toast("▶ Your turn")
			elif _human_seats() >= 2:
				# Another human's turn (possibly straight out of an AI turn) —
				# hide the board until they're holding the device.
				_show_handoff(tseat)
			else:
				_viewer = tseat         # safety net; a lone human is the viewer
			_refresh_board()
		"eliminated":
			_toast("☠ %s has been defeated!" % str(data.get("name", "?")), true)
			_refresh_board()
		"respawn":
			_toast("⚔ A new challenger: %s!" % str(data.get("name", "?")), true)
			_refresh_board()
		"level_up":
			var c: Dictionary = data.get("card", {})
			_toast("⭐ %s reached level %d!" % [str(c.get("name", "?")), int(c.get("level", 0))])
			_refresh_board()
		"death":
			var c2: Dictionary = data.get("card", {})
			_toast("💀 %s falls!" % str(c2.get("name", "?")))
			_refresh_board()
		"discard":
			var dseat: int = int(data.get("player", -1))
			if CardSystem.is_ai_seat(dseat) and dseat >= 0 and dseat < CardSystem.players.size():
				var c3: Dictionary = data.get("card", {})
				_toast("🤖 %s discards %s" % [
					str(CardSystem.players[dseat].get("name", "?")), str(c3.get("name", "?"))])
			_refresh_board()
		_:
			# attack / heal / damage / cast / draw / round / play / equip:
			# cheap idempotent repaint (guarded inside during handoff / victory).
			_refresh_board()

# ── Toasts + small helpers ───────────────────────────────────────────────────

func _toast(msg: String, big: bool = false) -> void:
	if _toast_layer == null or not is_instance_valid(_toast_layer):
		return
	var border: Color = RimvaleColors.DANGER if big else RimvaleColors.WARNING
	var panel: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD_DARK, border, 8, 10)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_child(RimvaleUtils.label(msg, 17 if big else 14, RimvaleColors.TEXT_WHITE))
	_toast_layer.add_child(panel)
	get_tree().create_timer(3.2 if big else 2.2).timeout.connect(func() -> void:
		if is_instance_valid(panel):
			panel.queue_free()
	)

## Route left-click on a control to `cb`; right-click clears the selection.
func _connect_click(ctrl: Control, cb: Callable) -> void:
	ctrl.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb == null or not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			cb.call()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_clear_selection()
	)

func _clear_children(node: Node) -> void:
	while node.get_child_count() > 0:
		var child: Node = node.get_child(0)
		node.remove_child(child)
		child.queue_free()
