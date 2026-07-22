## card_setup.gd
## Card Mode deck-building screen — lobby + hotseat setup for 2-4 players.
## Seat 0's screen doubles as the lobby: pick the player count and flag every
## other seat as a hotseat human or an AI (easy/medium/hard picker shown while
## any AI seat exists — one seat is AI by default). Each human seat then names
## themselves, picks a Conquest region, deals a card pool from it, and checks
## exactly CardSystem.DECK_SIZE cards (with at least CardSystem.MIN_CHARACTERS
## characters) to form their deck; the screen repeats per human seat. A custom
## spell forge lets players add bespoke spell cards to the pool. AI seats get
## a random region and an auto-built deck. Once every deck is ready,
## CardSystem.start_match runs and we jump to card_mode.tscn. Reached from
## the title screen.

extends Control

const CARD_MODE_SCENE := "res://scenes/cards/card_mode.tscn"
const TITLE_SCENE := "res://scenes/title/title_screen.tscn"
const LINEAGES_SHOWN := 6           # lineage names previewed under the region picker

# ── State ────────────────────────────────────────────────────────────────────
var _num_players: int = 2                 # total seats in the match (2..4)
var _seat_ai: Array = [false, true, true, true]   # seat -> AI-controlled? (seat 0 always human)
var _ai_difficulty: String = "medium"  # AI tier: "easy" / "medium" / "hard"
var _mode: String = "versus"           # versus | gauntlet | spectate | conquest
var _mode_btns: Dictionary = {}        # mode id -> mode toggle Button
var _p_names: Array = ["", "", "", ""]
var _p_regions: Array = ["", "", "", ""]
var _p_decks: Array = [[], [], [], []]
var _human_seats: Array = []              # computed at seat 0's confirm: human seat numbers, e.g. [0, 2]
var _phase: int = 0                       # index into _human_seats — whose deck we're building
var _pool: Array = []               # current player's dealt pool (card dicts)
var _checks: Array = []             # checkbox refs parallel to _pool
var _region_ids: Array = []         # option index -> region id
var _regions: Array = []            # cached CardSystem.get_regions()
var _error_text: String = ""        # shown once on the next rebuild (launch errors)

# ── UI refs (freed + rebuilt every phase) ────────────────────────────────────
var _root: VBoxContainer = null     # centred content column
var _wrap: ScrollContainer = null   # full-rect scroll wrapper around _root
var _back_btn: Button = null
var _name_edit: LineEdit = null
var _players_btns: Dictionary = {}  # player count (2-4) -> count toggle Button (phase 0)
var _seat_btns: Dictionary = {}     # [seat, is_ai] -> Human/AI toggle Button (phase 0)
var _seats_box: VBoxContainer = null  # holds the per-seat Human/AI rows (phase 0)
var _dbg_btns: Dictionary = {}      # debug on/off -> toggle Button (phase 0)
var _diff_btns: Dictionary = {}     # difficulty id -> tier toggle Button (phase 0)
var _diff_row: Control = null       # AI difficulty row — hidden while no seat is AI (phase 0)
var _region_opt: OptionButton = null
var _lineage_lbl: Label = null
var _pool_vbox: VBoxContainer = null
var _pool_hint: Label = null        # "deal a pool" placeholder inside the list
var _counter_lbl: Label = null
var _confirm_btn: Button = null

# ── Custom spell builder popup refs ──────────────────────────────────────────
var _popup_layer: Control = null
var _spell_kind: String = "damage"
var _kind_btns: Dictionary = {}     # kind id -> Button
var _spell_name_edit: LineEdit = null
var _dc_slider: HSlider = null
var _dc_lbl: Label = null
var _ds_slider: HSlider = null
var _ds_lbl: Label = null
var _area_check: CheckBox = null
var _cond_checks: Dictionary = {}   # condition name -> CheckBox
var _sp_lbl: Label = null
var _spell_err_lbl: Label = null


# ── Setup ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RimvaleUtils.add_bg(self, RimvaleColors.BG_DARK)
	_build_phase_ui()


## Tear down and rebuild the whole deck-building UI for the current phase.
func _build_phase_ui() -> void:
	_close_spell_builder()
	if is_instance_valid(_wrap):
		_wrap.queue_free()
	if is_instance_valid(_back_btn):
		_back_btn.queue_free()
	_pool = []
	_checks = []
	_pool_hint = null

	# Scroll wrapper so the column can never overflow the viewport.
	_wrap = ScrollContainer.new()
	_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_wrap)

	# Outer column fills the scroll viewport and vertically centres content
	# when it is shorter than the screen.
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	_wrap.add_child(outer)

	# Centred content column, rebuilt from scratch each phase.
	_root = VBoxContainer.new()
	_root.custom_minimum_size = Vector2(700, 0)
	_root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_root.add_theme_constant_override("separation", 10)
	outer.add_child(_root)

	_root.add_child(RimvaleUtils.spacer(18))

	# ── Title ────────────────────────────────────────────────────────────────
	var seat: int = _current_seat()
	var title := RimvaleUtils.label(
		"🃏 CARD MODE — PLAYER %d DECK" % (seat + 1), 26, RimvaleColors.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(title)

	var subtitle := RimvaleUtils.label(
		"Deal a pool from your region, then pick exactly %d cards — at least %d characters." % [
			CardSystem.DECK_SIZE, CardSystem.MIN_CHARACTERS],
		12, RimvaleColors.TEXT_GRAY)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(subtitle)

	# Launch errors (from CardSystem.start_match) surface here once.
	if _error_text != "":
		var err_lbl := RimvaleUtils.label(_error_text, 13, RimvaleColors.DANGER)
		err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		err_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_root.add_child(err_lbl)
		_error_text = ""

	_root.add_child(RimvaleUtils.separator())

	# ── Player identity + region ─────────────────────────────────────────────
	var id_card := RimvaleUtils.card()
	_root.add_child(id_card)
	var idv := VBoxContainer.new()
	idv.add_theme_constant_override("separation", 6)
	id_card.add_child(idv)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	idv.add_child(name_row)
	var name_tag := RimvaleUtils.label("Name", 13, RimvaleColors.TEXT_GRAY)
	name_tag.custom_minimum_size = Vector2(64, 0)
	name_row.add_child(name_tag)
	_name_edit = LineEdit.new()
	_name_edit.text = str(_p_names[seat]) if str(_p_names[seat]) != "" else "Player %d" % (seat + 1)
	_name_edit.custom_minimum_size = Vector2(0, 34)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_edit)

	# Lobby controls — player count, per-seat Human/AI toggles, AI difficulty.
	# Seat 0 is always human and only their screen (phase 0) shows the lobby.
	_players_btns = {}
	_seat_btns = {}
	_seats_box = null
	_diff_btns = {}
	_diff_row = null
	if _phase == 0:
		# Mode: standard versus, or the endless gauntlet — every other seat
		# is an AI, and defeated challengers are replaced two rounds later.
		var mode_row := HBoxContainer.new()
		mode_row.add_theme_constant_override("separation", 10)
		idv.add_child(mode_row)
		var mode_tag := RimvaleUtils.label("Mode", 13, RimvaleColors.TEXT_GRAY)
		mode_tag.custom_minimum_size = Vector2(64, 0)
		mode_row.add_child(mode_tag)
		_mode_btns = {}
		var modes: Array = [
			["versus", "⚔ Versus", RimvaleColors.CYAN],
			["gauntlet", "🌊 Gauntlet", RimvaleColors.ACCENT],
			["spectate", "👁 Spectate", RimvaleColors.SP_PURPLE],
			["conquest", "🗺 Conquest", RimvaleColors.GOLD],
		]
		for m_v in modes:
			var g: String = str(m_v[0])
			var mb := _hand(RimvaleUtils.button(str(m_v[1]), m_v[2], 34, 12))
			mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mb.pressed.connect(_select_mode.bind(g))
			mode_row.add_child(mb)
			_mode_btns[g] = mb

		var players_row := HBoxContainer.new()
		players_row.add_theme_constant_override("separation", 10)
		idv.add_child(players_row)
		var players_tag := RimvaleUtils.label("Players", 13, RimvaleColors.TEXT_GRAY)
		players_tag.custom_minimum_size = Vector2(64, 0)
		players_row.add_child(players_tag)
		for n in range(2, 5):
			var pb := _hand(RimvaleUtils.button(str(n), RimvaleColors.CYAN, 34, 13))
			pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pb.pressed.connect(_select_num_players.bind(n))
			players_row.add_child(pb)
			_players_btns[n] = pb

		# One Human/AI row per opposing seat — refilled when the count changes.
		_seats_box = VBoxContainer.new()
		_seats_box.add_theme_constant_override("separation", 6)
		idv.add_child(_seats_box)

		# AI difficulty selector — visible while any seat is AI-controlled.
		var diff_row := HBoxContainer.new()
		diff_row.add_theme_constant_override("separation", 10)
		idv.add_child(diff_row)
		_diff_row = diff_row
		var diff_tag := RimvaleUtils.label("Difficulty", 13, RimvaleColors.TEXT_GRAY)
		diff_tag.custom_minimum_size = Vector2(64, 0)
		diff_row.add_child(diff_tag)
		var diffs: Array = [
			["easy",   "😌 Easy",   RimvaleColors.SUCCESS],
			["medium", "⚖ Medium", RimvaleColors.GOLD],
			["hard",   "💀 Hard",   RimvaleColors.DANGER],
		]
		for d_v in diffs:
			var d: String = str(d_v[0])
			var db := _hand(RimvaleUtils.button(str(d_v[1]), d_v[2], 34, 13))
			db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			db.pressed.connect(_select_difficulty.bind(d))
			diff_row.add_child(db)
			_diff_btns[d] = db

		# Debug tools — flipped here, used in-match via the 🐞 button on the
		# board. Shared with Battle Mode's debug panel.
		var dbg_row := HBoxContainer.new()
		dbg_row.add_theme_constant_override("separation", 10)
		idv.add_child(dbg_row)
		var dbg_tag := RimvaleUtils.label("Debug", 13, RimvaleColors.TEXT_GRAY)
		dbg_tag.custom_minimum_size = Vector2(64, 0)
		dbg_row.add_child(dbg_tag)
		_dbg_btns = {}
		for g_v in [[false, "Off", RimvaleColors.TEXT_GRAY], [true, "🐞 Debug tools", RimvaleColors.CYAN]]:
			var g: bool = bool(g_v[0])
			var gb := _hand(RimvaleUtils.button(str(g_v[1]), g_v[2], 34, 13))
			gb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gb.tooltip_text = "Card spawner, energy refill and discard tools, available in-match."
			gb.pressed.connect(_select_debug.bind(g))
			dbg_row.add_child(gb)
			_dbg_btns[g] = gb

	var region_row := HBoxContainer.new()
	region_row.add_theme_constant_override("separation", 10)
	idv.add_child(region_row)
	var region_tag := RimvaleUtils.label("Region", 13, RimvaleColors.TEXT_GRAY)
	region_tag.custom_minimum_size = Vector2(64, 0)
	region_row.add_child(region_tag)
	_region_opt = OptionButton.new()
	_region_opt.custom_minimum_size = Vector2(0, 34)
	_region_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_region_opt.add_theme_font_size_override("font_size", 13)
	_regions = CardSystem.get_regions()
	_region_ids = []
	for r_v in _regions:
		var r: Dictionary = r_v
		_region_opt.add_item(str(r.get("name", "?")))
		_region_ids.append(str(r.get("id", "")))
	_region_opt.item_selected.connect(_on_region_selected)
	region_row.add_child(_region_opt)

	# Small gray preview of the region's native lineages.
	_lineage_lbl = RimvaleUtils.label("", 11, RimvaleColors.TEXT_GRAY)
	_lineage_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	idv.add_child(_lineage_lbl)

	# Restore the previously chosen region when revisiting this phase.
	if _region_opt.item_count > 0:
		var sel_idx: int = 0
		var prev: int = _region_ids.find(str(_p_regions[seat]))
		if prev >= 0:
			sel_idx = prev
		_region_opt.select(sel_idx)
		_on_region_selected(sel_idx)

	var deal_btn := _hand(RimvaleUtils.button("🎴 Deal Card Pool", RimvaleColors.CYAN, 42, 15))
	deal_btn.pressed.connect(_on_deal_pressed)
	idv.add_child(deal_btn)

	# ── Card pool / deck picker ──────────────────────────────────────────────
	var pool_card := RimvaleUtils.card(RimvaleColors.BG_CARD_DARK)
	_root.add_child(pool_card)
	var poolv := VBoxContainer.new()
	poolv.add_theme_constant_override("separation", 6)
	pool_card.add_child(poolv)

	poolv.add_child(RimvaleUtils.label(
		"CARD POOL — checked cards form your deck", 15, RimvaleColors.ACCENT))

	var pool_scroll := ScrollContainer.new()
	pool_scroll.custom_minimum_size = Vector2(660, 380)
	pool_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	poolv.add_child(pool_scroll)

	_pool_vbox = VBoxContainer.new()
	_pool_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pool_vbox.add_theme_constant_override("separation", 2)
	pool_scroll.add_child(_pool_vbox)

	_counter_lbl = RimvaleUtils.label("", 14, RimvaleColors.DANGER)
	poolv.add_child(_counter_lbl)

	# ── Actions ──────────────────────────────────────────────────────────────
	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 10)
	_root.add_child(act_row)

	var spell_btn := _hand(RimvaleUtils.button("✦ Build Custom Spell Card", RimvaleColors.ACCENT, 44, 14))
	spell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spell_btn.pressed.connect(_open_spell_builder)
	act_row.add_child(spell_btn)

	_confirm_btn = _hand(RimvaleUtils.button("Confirm Deck ▸", RimvaleColors.SUCCESS, 44, 14))
	_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	act_row.add_child(_confirm_btn)

	_root.add_child(RimvaleUtils.spacer(18))

	# ── Back button (top-left, floats above the scroll wrapper) ──────────────
	_back_btn = _hand(RimvaleUtils.button("◂ Back", RimvaleColors.TEXT_LIGHT, 36, 13))
	_back_btn.custom_minimum_size = Vector2(96, 36)
	_back_btn.position = Vector2(16, 16)
	_back_btn.pressed.connect(_on_back_pressed)
	add_child(_back_btn)

	# Initial lobby highlights + confirm button title. Phase 0 derives both
	# from the lobby config; later phases only need the confirm title.
	if _phase == 0:
		_select_num_players(_num_players)
		_select_difficulty(_ai_difficulty)
		_select_mode(_mode)
		_select_debug(bool(GameState.debug_mode))
	elif _phase + 1 < _human_seats.size():
		_confirm_btn.text = "Next: Seat %d ▸" % (int(_human_seats[_phase + 1]) + 1)
	else:
		_confirm_btn.text = "Start Match ▸"

	_rebuild_pool_rows()
	_update_counter()


# ── Region picker ────────────────────────────────────────────────────────────

## Update the lineage preview under the region OptionButton.
func _on_region_selected(idx: int) -> void:
	if idx < 0 or idx >= _regions.size() or not is_instance_valid(_lineage_lbl):
		return
	var r: Dictionary = _regions[idx]
	var lins: Array = r.get("lineages", [])
	var shown: Array = []
	for i in range(mini(LINEAGES_SHOWN, lins.size())):
		shown.append(str(lins[i]))
	var txt: String = ", ".join(shown)
	if lins.size() > LINEAGES_SHOWN:
		txt += "…"
	_lineage_lbl.text = ("Lineages: %s" % txt) if txt != "" else ""


# ── Lobby controls (phase 0) ─────────────────────────────────────────────────

## Pick how many seats the match has, dim the unselected count toggles, and
## refill the per-seat Human/AI rows to match.
func _select_num_players(n: int) -> void:
	_num_players = n
	for key in _players_btns:
		var b: Button = _players_btns[key]
		if is_instance_valid(b):
			b.modulate = Color(1, 1, 1, 1.0) if int(key) == n else Color(1, 1, 1, 0.45)
	_rebuild_seat_rows()
	_update_lobby_state()

## Refill _seats_box with one "Seat N | 🎮 Human | 🤖 AI" row per opposing
## seat (1.._num_players-1). _seat_ai survives refills, so hidden seats keep
## their setting and reappear unchanged when the count grows again.
func _rebuild_seat_rows() -> void:
	if not is_instance_valid(_seats_box):
		return
	for child in _seats_box.get_children():
		child.queue_free()
	_seat_btns = {}
	for s in range(1, _num_players):
		var seat_row := HBoxContainer.new()
		seat_row.add_theme_constant_override("separation", 10)
		_seats_box.add_child(seat_row)
		var seat_tag := RimvaleUtils.label("Seat %d" % (s + 1), 13, RimvaleColors.TEXT_GRAY)
		seat_tag.custom_minimum_size = Vector2(64, 0)
		seat_row.add_child(seat_tag)
		var kinds: Array = [
			[false, "🎮 Human", RimvaleColors.CYAN],
			[true,  "🤖 AI",    RimvaleColors.ORANGE],
		]
		for k_v in kinds:
			var is_ai: bool = bool(k_v[0])
			var sb := _hand(RimvaleUtils.button(str(k_v[1]), k_v[2], 34, 13))
			sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sb.pressed.connect(_select_seat_ai.bind(s, is_ai))
			seat_row.add_child(sb)
			_seat_btns[[s, is_ai]] = sb
		_highlight_seat(s)

## Flip one seat between hotseat human and AI control.
func _select_seat_ai(seat_num: int, is_ai: bool) -> void:
	_seat_ai[seat_num] = is_ai
	_highlight_seat(seat_num)
	_update_lobby_state()

## Dim the unselected Human/AI toggle on one seat row.
func _highlight_seat(seat_num: int) -> void:
	for flag in [false, true]:
		var b: Button = _seat_btns.get([seat_num, flag])
		if is_instance_valid(b):
			b.modulate = Color(1, 1, 1, 1.0) if bool(_seat_ai[seat_num]) == bool(flag) else Color(1, 1, 1, 0.45)

## True when any opposing seat in the current lobby config is AI-controlled.
func _any_ai_seat() -> bool:
	for s in range(1, _num_players):
		if bool(_seat_ai[s]):
			return true
	return false

## Human seat numbers for the current lobby config, in seat order (always
## starts with seat 0).
func _computed_human_seats() -> Array:
	if _mode == "spectate":
		return []          # nobody builds a deck; the AI plays itself
	var out: Array = [0]
	for s in range(1, _num_players):
		if not bool(_seat_ai[s]):
			out.append(s)
	return out

func _update_lobby_state() -> void:
	if is_instance_valid(_diff_row):
		_diff_row.visible = _any_ai_seat()
	if is_instance_valid(_confirm_btn) and _phase == 0:
		var humans: Array = _computed_human_seats()
		if humans.size() <= 1:
			_confirm_btn.text = _start_button_label()
		else:
			_confirm_btn.text = "Next: Seat %d ▸" % (int(humans[1]) + 1)

## Pick Versus or Gauntlet. Gauntlet locks every other seat to AI and
## hides the per-seat rows; Versus restores them.
func _select_mode(m: String) -> void:
	_mode = m
	for key in _mode_btns:
		var b: Button = _mode_btns[key]
		if is_instance_valid(b):
			b.modulate = Color(1, 1, 1, 1.0) if str(key) == m else Color(1, 1, 1, 0.45)
	# Gauntlet and Conquest need every other seat hostile; Spectate makes
	# ALL seats AI (including seat 0) so the player just watches.
	if m == "gauntlet" or m == "conquest" or m == "spectate":
		for s2 in range(1, 4):
			_seat_ai[s2] = true
	if is_instance_valid(_seats_box):
		_seats_box.visible = (m == "versus")
	_update_lobby_state()

## Pick the AI difficulty tier and dim the two unselected tier buttons.
## Label for the confirm button, which changes with the chosen mode.
func _start_button_label() -> String:
	match _mode:
		"gauntlet":
			return "Start Gauntlet ▸"
		"spectate":
			return "👁 Watch Match ▸"
		"conquest":
			return "🗺 Begin Conquest ▸"
	return "Start Match ▸"

## Flip the shared debug flag and highlight the chosen state.
func _select_debug(on: bool) -> void:
	GameState.debug_mode = on
	for key in _dbg_btns:
		var b: Button = _dbg_btns[key]
		if is_instance_valid(b):
			b.modulate = Color(1, 1, 1, 1.0) if bool(key) == on else Color(1, 1, 1, 0.45)

## Pick the AI difficulty tier and dim the two unselected tier buttons.
func _select_difficulty(d: String) -> void:
	_ai_difficulty = d
	for key in _diff_btns:
		var b: Button = _diff_btns[key]
		if is_instance_valid(b):
			b.modulate = Color(1, 1, 1, 1.0) if str(key) == d else Color(1, 1, 1, 0.45)


# ── Pool dealing + deck picking ──────────────────────────────────────────────

## Deal (or re-deal) a card pool from the selected region.
func _on_deal_pressed() -> void:
	var idx: int = _region_opt.selected
	if idx < 0 or idx >= _region_ids.size():
		return
	_pool = CardSystem.generate_pool(str(_region_ids[idx]))
	_rebuild_pool_rows()
	_update_counter()

## Rebuild every pool row from _pool. Auto-checks the first DECK_SIZE cards
## (which checks the whole pool when it fits inside a deck).
func _rebuild_pool_rows() -> void:
	for child in _pool_vbox.get_children():
		child.queue_free()
	_checks = []
	_pool_hint = null
	if _pool.is_empty():
		_pool_hint = RimvaleUtils.label(
			"No cards yet — press 🎴 Deal Card Pool to draw from your region.",
			12, RimvaleColors.TEXT_DIM)
		_pool_vbox.add_child(_pool_hint)
		return
	# Pre-select a RANDOM set of DECK_SIZE cards from the pool (not simply
	# the first N in dealt order). The pool holds 14 characters, so any
	# random 40-of-48 keeps at least the 6 characters a legal deck needs —
	# the player can still fine-tune every checkbox afterwards.
	var order: Array = range(_pool.size())
	order.shuffle()
	var chosen: Dictionary = {}
	for k in range(mini(CardSystem.DECK_SIZE, _pool.size())):
		chosen[int(order[k])] = true
	for i in range(_pool.size()):
		_add_pool_row(_pool[i], chosen.has(i))

## Append one checkbox row for a card. _checks stays parallel to _pool.
func _add_pool_row(card: Dictionary, checked: bool) -> void:
	if is_instance_valid(_pool_hint):
		_pool_hint.queue_free()
		_pool_hint = null
	var cb := CheckBox.new()
	cb.text = "%s %s — %s" % [CardSystem.card_glyph(card), str(card["name"]), CardSystem.card_summary(card)]
	cb.add_theme_font_size_override("font_size", 12)
	cb.set_pressed_no_signal(checked)
	cb.toggled.connect(_on_card_toggled)
	_pool_vbox.add_child(cb)
	_checks.append(cb)

func _on_card_toggled(_toggled_on: bool) -> void:
	_update_counter()

## Count checked cards and checked character cards.
func _deck_counts() -> Dictionary:
	var total: int = 0
	var chars: int = 0
	for i in range(_checks.size()):
		var cb: CheckBox = _checks[i]
		if is_instance_valid(cb) and cb.button_pressed:
			total += 1
			if str((_pool[i] as Dictionary).get("ctype", "")) == "character":
				chars += 1
	return {"total": total, "chars": chars}

## Legal deck: exactly DECK_SIZE cards, at least MIN_CHARACTERS characters.
func _deck_is_legal() -> bool:
	var c: Dictionary = _deck_counts()
	return int(c["total"]) == CardSystem.DECK_SIZE and int(c["chars"]) >= CardSystem.MIN_CHARACTERS

## Refresh the "Deck: N/DECK_SIZE — characters: N (min 6)" line and the confirm button.
func _update_counter() -> void:
	if not is_instance_valid(_counter_lbl):
		return
	var c: Dictionary = _deck_counts()
	var legal: bool = int(c["total"]) == CardSystem.DECK_SIZE and int(c["chars"]) >= CardSystem.MIN_CHARACTERS
	_counter_lbl.text = "Deck: %d/%d — characters: %d (min %d)" % [
		int(c["total"]), CardSystem.DECK_SIZE, int(c["chars"]), CardSystem.MIN_CHARACTERS]
	_counter_lbl.add_theme_color_override("font_color",
		RimvaleColors.SUCCESS if legal else RimvaleColors.DANGER)
	if is_instance_valid(_confirm_btn):
		_confirm_btn.disabled = not legal

## The checked cards, in pool order.
func _selected_deck() -> Array:
	var deck: Array = []
	for i in range(_checks.size()):
		var cb: CheckBox = _checks[i]
		if is_instance_valid(cb) and cb.button_pressed:
			deck.append(_pool[i])
	return deck


# ── Confirm / back / launch ──────────────────────────────────────────────────

## The seat whose deck the current phase's screen is building. Phase 0 is
## always seat 0; later phases walk _human_seats (set at seat 0's confirm).
func _current_seat() -> int:
	if _phase <= 0 or _phase >= _human_seats.size():
		return 0
	return int(_human_seats[_phase])

## Store the current seat's setup, then advance to the next human seat's
## deck screen — or launch once every human deck is in.
func _on_confirm_pressed() -> void:
	if not _deck_is_legal():
		return   # button is disabled when illegal; belt and braces
	var seat: int = _current_seat()
	var pname: String = _name_edit.text.strip_edges()
	if pname == "":
		pname = "Player %d" % (seat + 1)
	_p_names[seat] = pname
	var idx: int = _region_opt.selected
	_p_regions[seat] = str(_region_ids[idx]) if idx >= 0 and idx < _region_ids.size() else ""
	_p_decks[seat] = _selected_deck()
	if _phase == 0:
		# Seat 0's confirm locks the lobby: freeze the human seat order.
		_human_seats = _computed_human_seats()
	if _phase + 1 < _human_seats.size():
		_phase += 1
		_build_phase_ui()
	else:
		_finalize_and_launch()

## Fill every AI seat with a random region (a human's own is fine) plus an
## auto-built deck, then hand all seat configs to CardSystem in seat order
## and enter the match scene.
func _finalize_and_launch() -> void:
	var rids: Array = []
	for r_v in CardSystem.get_regions():
		rids.append(str((r_v as Dictionary).get("id", "")))
	var ai_seats: Array = []
	for s in range(1, _num_players):
		if bool(_seat_ai[s]):
			ai_seats.append(s)
	for s_v in ai_seats:
		var s: int = int(s_v)
		var rid: String = str(rids.pick_random()) if not rids.is_empty() else ""
		_p_regions[s] = rid
		_p_decks[s] = CardSystem.build_ai_deck(rid)
		if _mode == "gauntlet":
			_p_names[s] = "🤖 Challenger %d (%s)" % [
				ai_seats.find(s_v) + 1, _ai_difficulty.capitalize()]
		elif ai_seats.size() == 1:
			_p_names[s] = "🤖 Enemy AI (%s)" % _ai_difficulty.capitalize()
		else:
			_p_names[s] = "🤖 AI %d (%s)" % [s + 1, _ai_difficulty.capitalize()]
	# Spectate turns EVERY seat over to the AI, including seat 0.
	if _mode == "spectate":
		for s in range(_num_players):
			_seat_ai[s] = true
			_p_names[s] = "🤖 AI %d (%s)" % [s + 1, _ai_difficulty.capitalize()]
			if str(_p_regions[s]) == "":
				var rid2: Array = []
				for r2 in CardSystem.get_regions():
					rid2.append(str(r2["id"]))
				_p_regions[s] = str(rid2.pick_random()) if not rid2.is_empty() else ""
			_p_decks[s] = CardSystem.build_ai_deck(str(_p_regions[s]))
	# Conquest runs its own launcher: one deck, carried through every region.
	if _mode == "conquest":
		var cq_err: String = CardSystem.start_conquest(
			str(_p_names[0]), _p_decks[0], _num_players, _ai_difficulty)
		if cq_err != "":
			_error_text = cq_err
			_phase = 0
			_build_phase_ui()
			return
		get_tree().change_scene_to_file(CARD_MODE_SCENE)
		return
	var configs: Array = []
	for s in range(_num_players):
		configs.append({
			"name": str(_p_names[s]),
			"region": str(_p_regions[s]),
			"deck": _p_decks[s],
			"ai": bool(_seat_ai[s]) if s > 0 else (_mode == "spectate"),
		})
	var err: String = CardSystem.start_match(configs, _ai_difficulty, _mode == "gauntlet")
	if err != "":
		# Surface the problem and drop back to the first deck screen.
		_error_text = err
		_phase = 0
		_build_phase_ui()
		return
	get_tree().change_scene_to_file(CARD_MODE_SCENE)

## Phase 0 -> title screen; later phases -> the previous human seat's screen.
func _on_back_pressed() -> void:
	if _phase == 0:
		get_tree().change_scene_to_file(TITLE_SCENE)
	else:
		_phase -= 1
		_build_phase_ui()


# ── Custom spell builder popup ───────────────────────────────────────────────

## Open the centred "forge a spell card" popup over a dimmed backdrop.
func _open_spell_builder() -> void:
	if is_instance_valid(_popup_layer):
		return
	_spell_kind = "damage"
	_kind_btns = {}
	_cond_checks = {}

	_popup_layer = Control.new()
	_popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_popup_layer)

	# Dimmer that also blocks clicks on the screen behind the popup.
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup_layer.add_child(center)

	var panel := RimvaleUtils.card(RimvaleColors.BG_CARD_DARK, RimvaleColors.ACCENT, 10, 16)
	panel.custom_minimum_size = Vector2(500, 0)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var title := RimvaleUtils.label("✦ CUSTOM SPELL CARD", 18, RimvaleColors.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	# Name.
	vb.add_child(RimvaleUtils.label("Spell name", 12, RimvaleColors.TEXT_GRAY))
	_spell_name_edit = LineEdit.new()
	_spell_name_edit.max_length = 24
	_spell_name_edit.placeholder_text = "e.g. Ember Coil"
	_spell_name_edit.custom_minimum_size = Vector2(0, 32)
	vb.add_child(_spell_name_edit)

	# Kind selector (highlighted via modulate).
	vb.add_child(RimvaleUtils.label("Kind", 12, RimvaleColors.TEXT_GRAY))
	var krow := HBoxContainer.new()
	krow.add_theme_constant_override("separation", 6)
	vb.add_child(krow)
	var kinds: Array = [
		["damage", "🔥 Damage", RimvaleColors.ORANGE],
		["heal",   "💚 Heal",   RimvaleColors.HP_GREEN],
		["buff",   "🛡 Buff",   RimvaleColors.CYAN],
		["debuff", "💀 Debuff", RimvaleColors.DANGER],
	]
	for k_v in kinds:
		var kid: String = str(k_v[0])
		var kb := _hand(RimvaleUtils.button(str(k_v[1]), k_v[2], 34, 13))
		kb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kb.pressed.connect(_select_spell_kind.bind(kid))
		krow.add_child(kb)
		_kind_btns[kid] = kb

	# Dice count slider (1-4).
	var dc_row := HBoxContainer.new()
	dc_row.add_theme_constant_override("separation", 10)
	vb.add_child(dc_row)
	var dc_tag := RimvaleUtils.label("Dice count", 12, RimvaleColors.TEXT_GRAY)
	dc_tag.custom_minimum_size = Vector2(96, 0)
	dc_row.add_child(dc_tag)
	_dc_slider = HSlider.new()
	_dc_slider.min_value = 1
	_dc_slider.max_value = 4
	_dc_slider.step = 1
	_dc_slider.value = 1
	_dc_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dc_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dc_slider.value_changed.connect(_on_spell_dice_changed)
	dc_row.add_child(_dc_slider)
	_dc_lbl = RimvaleUtils.label("1", 13, RimvaleColors.TEXT_WHITE)
	_dc_lbl.custom_minimum_size = Vector2(36, 0)
	dc_row.add_child(_dc_lbl)

	# Dice sides slider (d4-d12, even sides only).
	var ds_row := HBoxContainer.new()
	ds_row.add_theme_constant_override("separation", 10)
	vb.add_child(ds_row)
	var ds_tag := RimvaleUtils.label("Dice sides", 12, RimvaleColors.TEXT_GRAY)
	ds_tag.custom_minimum_size = Vector2(96, 0)
	ds_row.add_child(ds_tag)
	_ds_slider = HSlider.new()
	_ds_slider.min_value = 4
	_ds_slider.max_value = 12
	_ds_slider.step = 2
	_ds_slider.value = 6
	_ds_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ds_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ds_slider.value_changed.connect(_on_spell_dice_changed)
	ds_row.add_child(_ds_slider)
	_ds_lbl = RimvaleUtils.label("d6", 13, RimvaleColors.TEXT_WHITE)
	_ds_lbl.custom_minimum_size = Vector2(36, 0)
	ds_row.add_child(_ds_lbl)

	# Area toggle.
	_area_check = CheckBox.new()
	_area_check.text = "Hits ALL characters on the target side (+2 SP)"
	_area_check.add_theme_font_size_override("font_size", 12)
	_area_check.toggled.connect(func(_on: bool): _update_spell_sp())
	vb.add_child(_area_check)

	# Conditions — kept enabled for every kind: buffs/debuffs are built from
	# them, and damage/heal spells may carry them as riders.
	vb.add_child(RimvaleUtils.label(
		"Conditions (optional riders) — +2 SP each", 12, RimvaleColors.TEXT_GRAY))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 2)
	vb.add_child(grid)
	for cond_v in CardSystem.COND_DURATION.keys():
		var cond: String = str(cond_v)
		var cc := CheckBox.new()
		cc.text = cond.capitalize()
		cc.add_theme_font_size_override("font_size", 12)
		cc.toggled.connect(func(_on: bool): _update_spell_sp())
		grid.add_child(cc)
		_cond_checks[cond] = cc

	vb.add_child(RimvaleUtils.separator())

	# Live SP requirement + error line.
	_sp_lbl = RimvaleUtils.label("SP requirement: 1", 14, RimvaleColors.CYAN)
	vb.add_child(_sp_lbl)
	_spell_err_lbl = RimvaleUtils.label("", 12, RimvaleColors.DANGER)
	_spell_err_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_spell_err_lbl)

	# Create / cancel.
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 10)
	vb.add_child(brow)
	var create_btn := _hand(RimvaleUtils.button("✦ Create Card", RimvaleColors.GOLD, 40, 14))
	create_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_btn.pressed.connect(_on_spell_create_pressed)
	brow.add_child(create_btn)
	var cancel_btn := _hand(RimvaleUtils.button("Cancel", RimvaleColors.TEXT_GRAY, 40, 14))
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(_close_spell_builder)
	brow.add_child(cancel_btn)

	# Initial highlight, dice labels, and SP preview.
	_select_spell_kind("damage")
	_on_spell_dice_changed(0.0)

func _close_spell_builder() -> void:
	if is_instance_valid(_popup_layer):
		_popup_layer.queue_free()
	_popup_layer = null

## Pick the spell kind and dim the other three kind buttons.
func _select_spell_kind(kind: String) -> void:
	_spell_kind = kind
	for kid in _kind_btns:
		var b: Button = _kind_btns[kid]
		if is_instance_valid(b):
			b.modulate = Color(1, 1, 1, 1.0) if str(kid) == kind else Color(1, 1, 1, 0.45)
	_update_spell_sp()

## Shared handler for both dice sliders: refresh their labels + the SP preview.
func _on_spell_dice_changed(_v: float) -> void:
	if not is_instance_valid(_dc_lbl) or not is_instance_valid(_ds_lbl):
		return
	_dc_lbl.text = str(int(_dc_slider.value))
	_ds_lbl.text = "d%d" % int(_ds_slider.value)
	_update_spell_sp()

## Currently ticked condition names.
func _selected_conds() -> Array:
	var out: Array = []
	for cond in _cond_checks:
		var cc: CheckBox = _cond_checks[cond]
		if is_instance_valid(cc) and cc.button_pressed:
			out.append(str(cond))
	return out

## Recompute the live "SP requirement: N" line from the current controls.
func _update_spell_sp() -> void:
	if not is_instance_valid(_sp_lbl):
		return
	var sp: int = CardSystem.custom_spell_sp(
		_spell_kind, int(_dc_slider.value), int(_ds_slider.value),
		1 if _area_check.button_pressed else 0, _selected_conds().size())
	_sp_lbl.text = "SP requirement: %d" % sp

## Forge the card. On success it joins the pool (checked if the deck has room).
func _on_spell_create_pressed() -> void:
	var card: Dictionary = CardSystem.make_custom_spell_card(
		_spell_name_edit.text, _spell_kind,
		int(_dc_slider.value), int(_ds_slider.value),
		1 if _area_check.button_pressed else 0, _selected_conds())
	if card.has("err"):
		_spell_err_lbl.text = str(card["err"])
		return
	var room: bool = int(_deck_counts()["total"]) < CardSystem.DECK_SIZE
	_pool.append(card)
	_add_pool_row(card, room)
	_update_counter()
	_close_spell_builder()


# ── Misc ─────────────────────────────────────────────────────────────────────

## Give a button the pointing-hand cursor (house style).
func _hand(b: Button) -> Button:
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b
