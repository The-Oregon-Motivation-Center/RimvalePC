## battle_setup.gd
## Battle Mode entry screen — pick a region, team count, and unit level,
## then launch an RTS-style skirmish on the dungeon scene via BattleSystem.
## Reached from the title screen; entirely separate from story saves.

extends Control

# ── State ────────────────────────────────────────────────────────────────────
var _sel_region: String = ""
var _region_btns: Dictionary = {}   # region_id -> Button
var _sel_difficulty: String = "medium"
var _diff_btns: Dictionary = {}     # difficulty id -> Button
var _sel_resources: String = "medium"
var _res_btns: Dictionary = {}      # abundance id -> Button
var _sel_map_size: String = "medium"
var _map_size_btns: Dictionary = {}  # size id -> Button

const DIFFICULTIES := [
	["easy",   "😴 Easy",   "Lazy warbands (max 25 units) — they guard their turf and rarely strike out."],
	["medium", "⚔ Medium",  "Raiding parties (max 50 units) probe your lines — but never the full army."],
	["hard",   "💀 Hard",   "Ruthless (max 100 units): focused full-army assaults on the weakest team."],
]

const RESOURCE_LEVELS := [
	["low",    "🪨 Low",     "Lean veins: 1 home node per team, 2 contested. Every ⛃ matters."],
	["medium", "⛃ Medium",   "Classic economy: 2 home nodes per team, 4 in the midfield."],
	["high",   "💎 High",    "Rich veins: 3 home nodes per team, 6 contested."],
	["insane", "🌋 INSANE",  "The map drips supply: 4 home, 8 contested, 8 wild veins."],
]
const MAP_SIZES := [
	["small",  "🗺 Small (75)",   "Quick skirmish — compact 75×75 battlefield.", 75],
	["medium", "🗺 Medium (150)", "Standard field — 150×150 tiles of open warfare.", 150],
	["large",  "🗺 Large (300)",  "Epic scale — massive 300×300 battlefield. May impact performance.", 300],
]
var _map_size_hint_lbl: Label

var _teams_slider: HSlider
var _teams_val_lbl: Label
var _level_slider: HSlider
var _level_val_lbl: Label
var _diff_hint_lbl: Label
var _res_hint_lbl: Label
var _fog_check: CheckBox
var _spectate_check: CheckBox
var _debug_check: CheckBox

# ── Heroes (story characters joining as read-only battle copies) ────────────
const MAX_HEROES := 3            # must match BattleSystem.MAX_HEROES
const MAX_HERO_CHOICES := 6      # roster rows shown in the picker
var _sel_heroes: Array = []      # checked character handles, oldest first
var _hero_checks: Dictionary = {}   # handle (int) -> CheckBox
var _hero_hint_lbl: Label
const HERO_HINT_DEFAULT := "Bring up to 3 heroes — battle copies only, the story party is never at risk."

const BATTLE_RTS_SCENE := "res://scenes/battle/battle_rts.tscn"
const TITLE_SCENE := "res://scenes/title/title_screen.tscn"


# ── Setup ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RimvaleUtils.add_bg(self, Color(0.05, 0.02, 0.10, 1.0))

	# Scroll wrapper so the content can never overflow the viewport.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	# Outer column fills the scroll viewport and vertically centres content
	# when it is shorter than the screen.
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(outer)

	# Centred content column
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(940, 0)
	vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_theme_constant_override("separation", 14)
	outer.add_child(vbox)

	vbox.add_child(RimvaleUtils.spacer(24))

	# ── Title ────────────────────────────────────────────────────────────────
	var title := RimvaleUtils.label("⚔ BATTLE MODE", 28, RimvaleColors.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := RimvaleUtils.label(
		"Claim the region. Crush the other warbands. Last team standing wins.",
		13, RimvaleColors.TEXT_GRAY)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	vbox.add_child(RimvaleUtils.separator())

	# ── Region picker ────────────────────────────────────────────────────────
	vbox.add_child(RimvaleUtils.label("REGION", 15, RimvaleColors.ACCENT))

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)

	var rids: Array = BattleSystem.get_region_ids()
	for rid_v in rids:
		var rid: String = str(rid_v)
		var b := Button.new()
		b.text = BattleSystem.get_region_display(rid)
		b.custom_minimum_size = Vector2(178, 46)
		b.add_theme_font_size_override("font_size", 13)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.clip_text = true
		b.pressed.connect(func(): _select_region(rid))
		grid.add_child(b)
		_region_btns[rid] = b
	if not rids.is_empty():
		_select_region(str(rids[0]))

	vbox.add_child(RimvaleUtils.separator())

	# ── Teams slider ─────────────────────────────────────────────────────────
	var teams_row := _make_slider_row("TEAMS", 2, 10, 4)
	_teams_slider = teams_row["slider"]
	_teams_val_lbl = teams_row["value_label"]
	_teams_slider.value_changed.connect(func(v: float):
		_teams_val_lbl.text = "%d teams" % int(v))
	_teams_val_lbl.text = "%d teams" % int(_teams_slider.value)
	vbox.add_child(teams_row["row"])

	# ── Unit level slider ────────────────────────────────────────────────────
	var level_row := _make_slider_row("UNIT LEVEL", 1, 10, 3)
	_level_slider = level_row["slider"]
	_level_val_lbl = level_row["value_label"]
	_level_slider.value_changed.connect(func(v: float):
		_level_val_lbl.text = "Level %d" % int(v))
	_level_val_lbl.text = "Level %d" % int(_level_slider.value)
	vbox.add_child(level_row["row"])

	# ── Difficulty picker ────────────────────────────────────────────────────
	vbox.add_child(RimvaleUtils.label("DIFFICULTY", 15, RimvaleColors.ACCENT))

	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 10)
	diff_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(diff_row)

	for d in DIFFICULTIES:
		var did: String = str(d[0])
		var db := Button.new()
		db.text = str(d[1])
		db.tooltip_text = str(d[2])
		db.custom_minimum_size = Vector2(178, 46)
		db.add_theme_font_size_override("font_size", 13)
		db.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		db.pressed.connect(func(): _select_difficulty(did))
		diff_row.add_child(db)
		_diff_btns[did] = db

	var diff_hint := RimvaleUtils.label(
		str(DIFFICULTIES[1][2]), 11, RimvaleColors.TEXT_DIM)
	diff_hint.name = "DiffHint"
	diff_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(diff_hint)
	_diff_hint_lbl = diff_hint
	_select_difficulty("medium")

	# ── Resource abundance picker ────────────────────────────────────────────
	vbox.add_child(RimvaleUtils.label("RESOURCES", 15, RimvaleColors.ACCENT))

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 10)
	res_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(res_row)

	for r in RESOURCE_LEVELS:
		var rid_r: String = str(r[0])
		var rb := Button.new()
		rb.text = str(r[1])
		rb.tooltip_text = str(r[2])
		rb.custom_minimum_size = Vector2(132, 46)
		rb.add_theme_font_size_override("font_size", 13)
		rb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		rb.pressed.connect(func(): _select_resources(rid_r))
		res_row.add_child(rb)
		_res_btns[rid_r] = rb

	var res_hint := RimvaleUtils.label(
		str(RESOURCE_LEVELS[1][2]), 11, RimvaleColors.TEXT_DIM)
	res_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(res_hint)
	_res_hint_lbl = res_hint
	_select_resources("medium")

	# ── Map size picker ──────────────────────────────────────────────────────
	vbox.add_child(RimvaleUtils.label("MAP SIZE", 15, RimvaleColors.ACCENT))

	var map_row := HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 10)
	map_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(map_row)

	for m in MAP_SIZES:
		var mid: String = str(m[0])
		var mb := Button.new()
		mb.text = str(m[1])
		mb.tooltip_text = str(m[2])
		mb.custom_minimum_size = Vector2(178, 46)
		mb.add_theme_font_size_override("font_size", 13)
		mb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mb.pressed.connect(func(): _select_map_size(mid))
		map_row.add_child(mb)
		_map_size_btns[mid] = mb

	var map_hint := RimvaleUtils.label(
		str(MAP_SIZES[1][2]), 11, RimvaleColors.TEXT_DIM)
	map_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(map_hint)
	_map_size_hint_lbl = map_hint
	_select_map_size("medium")

	# ── Fog of war toggle ────────────────────────────────────────────────────
	_fog_check = CheckBox.new()
	_fog_check.text = "🌫 Fog of War — scout to reveal the map (recommended)"
	_fog_check.button_pressed = true
	_fog_check.add_theme_font_size_override("font_size", 13)
	_fog_check.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_fog_check)

	# ── Spectator toggle: every army is AI-run and you just watch ────────────
	_spectate_check = CheckBox.new()
	_spectate_check.text = "👁 Spectate — all armies are AI-controlled, you observe"
	_spectate_check.button_pressed = false
	_spectate_check.add_theme_font_size_override("font_size", 13)
	_spectate_check.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_spectate_check)

	# ── Debug mode toggle (same global flag as the Profile screen) ───────────
	# Enables the in-battle 🐞 debug panel (add supply, reveal map, spawn kaiju,
	# instant win, etc.). Persists globally, so it also turns on story cheats.
	_debug_check = CheckBox.new()
	_debug_check.text = "🐛 Debug Mode — enables the in-battle 🐞 debug panel"
	_debug_check.button_pressed = bool(GameState.debug_mode)
	_debug_check.add_theme_font_size_override("font_size", 13)
	_debug_check.add_theme_color_override("font_color", RimvaleColors.DANGER)
	_debug_check.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_debug_check.toggled.connect(func(on: bool):
		GameState.debug_mode = on
		GameState.save_game())
	vbox.add_child(_debug_check)

	# ── Heroes: story characters join the battle ─────────────────────────────
	vbox.add_child(RimvaleUtils.label("HEROES", 15, RimvaleColors.ACCENT))
	_build_hero_section(vbox)

	# ── Rules card ───────────────────────────────────────────────────────────
	var rules_card := RimvaleUtils.card()
	var rules := RimvaleUtils.label(
		"• Each team starts with a Command Post, 3 units, and 100 supply.\n" +
		"• Produce lineage units native to the region — plus mobs, militia, monsters, adversaries, apex monsters, and kaiju.\n" +
		"• Park units beside resource nodes to mine supply each round.\n" +
		"• Destroy every rival team's forces. Last team standing takes the region.",
		11, RimvaleColors.TEXT_DIM)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_card.add_child(rules)
	vbox.add_child(rules_card)

	vbox.add_child(RimvaleUtils.spacer(6))

	# ── Start button ─────────────────────────────────────────────────────────
	var start_btn := RimvaleUtils.button("⚔  START BATTLE", RimvaleColors.GOLD, 64, 22)
	start_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var start_sb := StyleBoxFlat.new()
	start_sb.bg_color = Color(RimvaleColors.GOLD.r, RimvaleColors.GOLD.g, RimvaleColors.GOLD.b, 0.10)
	start_sb.border_color = RimvaleColors.GOLD
	start_sb.set_border_width_all(2)
	start_sb.set_corner_radius_all(8)
	start_btn.add_theme_stylebox_override("normal", start_sb)
	var start_sb_hover: StyleBoxFlat = start_sb.duplicate()
	start_sb_hover.bg_color = Color(RimvaleColors.GOLD.r, RimvaleColors.GOLD.g, RimvaleColors.GOLD.b, 0.22)
	start_btn.add_theme_stylebox_override("hover", start_sb_hover)
	start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(start_btn)

	# ── Back button ──────────────────────────────────────────────────────────
	var back_btn := RimvaleUtils.button("← Back to Title", RimvaleColors.TEXT_GRAY, 36, 13)
	back_btn.flat = true
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_btn.custom_minimum_size = Vector2(200, 36)
	back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_btn.pressed.connect(func():
		get_tree().change_scene_to_file(TITLE_SCENE)
	)
	vbox.add_child(back_btn)

	vbox.add_child(RimvaleUtils.spacer(24))

	start_btn.call_deferred("grab_focus")


# ── Region selection ─────────────────────────────────────────────────────────
func _select_region(rid: String) -> void:
	_sel_region = rid
	for id in _region_btns.keys():
		_style_region_btn(_region_btns[id], id == rid)


# ── Difficulty selection ─────────────────────────────────────────────────────
func _select_difficulty(did: String) -> void:
	_sel_difficulty = did
	for id in _diff_btns.keys():
		_style_region_btn(_diff_btns[id], id == did)
	if _diff_hint_lbl != null:
		for d in DIFFICULTIES:
			if str(d[0]) == did:
				_diff_hint_lbl.text = str(d[2])
				break


# ── Resource abundance selection ─────────────────────────────────────────────
func _select_resources(rid: String) -> void:
	_sel_resources = rid
	for id in _res_btns.keys():
		_style_region_btn(_res_btns[id], id == rid)
	if _res_hint_lbl != null:
		for r in RESOURCE_LEVELS:
			if str(r[0]) == rid:
				_res_hint_lbl.text = str(r[2])
				break


# ── Map size selection ───────────────────────────────────────────────────────
func _select_map_size(mid: String) -> void:
	_sel_map_size = mid
	for id in _map_size_btns.keys():
		_style_region_btn(_map_size_btns[id], id == mid)
	if _map_size_hint_lbl != null:
		for m in MAP_SIZES:
			if str(m[0]) == mid:
				_map_size_hint_lbl.text = str(m[2])
				break


func _style_region_btn(btn: Button, selected: bool) -> void:
	var sb := StyleBoxFlat.new()
	if selected:
		sb.bg_color = Color(RimvaleColors.GOLD.r, RimvaleColors.GOLD.g, RimvaleColors.GOLD.b, 0.18)
		sb.border_color = RimvaleColors.GOLD
	else:
		sb.bg_color = Color(1, 1, 1, 0.04)
		sb.border_color = RimvaleColors.DIVIDER
	sb.set_border_width_all(2 if selected else 1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", sb)
	var sb_hover: StyleBoxFlat = sb.duplicate()
	sb_hover.bg_color = Color(1, 1, 1, 0.10) if not selected else sb.bg_color
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb_hover)
	btn.add_theme_color_override("font_color",
		RimvaleColors.GOLD if selected else RimvaleColors.TEXT_LIGHT)


# ── Slider row builder ───────────────────────────────────────────────────────
## Returns { "row": Control, "slider": HSlider, "value_label": Label }.
func _make_slider_row(title_txt: String, min_v: int, max_v: int, default_v: int) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var lbl := RimvaleUtils.label(title_txt, 15, RimvaleColors.ACCENT)
	lbl.custom_minimum_size = Vector2(140, 0)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = 1
	slider.value = default_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(300, 0)
	row.add_child(slider)

	var val_lbl := RimvaleUtils.label("", 14, RimvaleColors.TEXT_WHITE)
	val_lbl.custom_minimum_size = Vector2(110, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)

	return {"row": row, "slider": slider, "value_label": val_lbl}


# ── Hero picker ──────────────────────────────────────────────────────────────
## Up to MAX_HERO_CHOICES roster characters as toggle boxes (max MAX_HEROES
## checked — the OLDEST pick is silently released when a fourth is checked).
## With no story save loaded, shows a dim hint instead.
func _build_hero_section(vbox: VBoxContainer) -> void:
	var handles: Array = _roster_handles()
	if handles.is_empty():
		var empty_hint := RimvaleUtils.label(
			"Load a story save to bring heroes into battle.",
			11, RimvaleColors.TEXT_DIM)
		empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(empty_hint)
		return

	var e = RimvaleAPI.engine
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)

	for h_v in handles:
		var h: int = int(h_v)
		var cb := CheckBox.new()
		cb.text = "%s  (Lv %d %s)" % [
			str(e.get_character_name(h)),
			int(e.get_character_level(h)),
			str(e.get_character_lineage_name(h))]
		cb.add_theme_font_size_override("font_size", 12)
		cb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cb.toggled.connect(func(on: bool): _on_hero_toggled(h, on))
		grid.add_child(cb)
		_hero_checks[h] = cb

	var hero_hint := RimvaleUtils.label(HERO_HINT_DEFAULT, 11, RimvaleColors.TEXT_DIM)
	hero_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hero_hint)
	_hero_hint_lbl = hero_hint


## Story roster handles for the picker: active strike team first, then the
## rest of the collection, capped at MAX_HERO_CHOICES. Empty when no story
## save is loaded (the engine's roster is empty).
func _roster_handles() -> Array:
	var e = RimvaleAPI.engine
	if e == null or not e.has_method("get_all_character_handles"):
		return []
	var all: Array = e.get_all_character_handles()
	if all.is_empty():
		return []
	var out: Array = []
	for h in GameState.get_active_handles():
		if out.size() >= MAX_HERO_CHOICES:
			break
		if all.has(h) and not out.has(h):
			out.append(h)
	for h in all:
		if out.size() >= MAX_HERO_CHOICES:
			break
		if not out.has(h):
			out.append(h)
	return out


func _on_hero_toggled(handle: int, on: bool) -> void:
	if on:
		if not _sel_heroes.has(handle):
			_sel_heroes.append(handle)
		# Over the cap: silently release the OLDEST pick so the newest lands.
		while _sel_heroes.size() > MAX_HEROES:
			var oldest: int = int(_sel_heroes.pop_front())
			if _hero_checks.has(oldest):
				(_hero_checks[oldest] as CheckBox).set_pressed_no_signal(false)
	else:
		_sel_heroes.erase(handle)
	if _hero_hint_lbl != null:
		if _sel_heroes.is_empty():
			_hero_hint_lbl.text = HERO_HINT_DEFAULT
		else:
			_hero_hint_lbl.text = "✦ %d / %d heroes will take the field." % [
				_sel_heroes.size(), MAX_HEROES]


# ── Actions ──────────────────────────────────────────────────────────────────
func _on_start_pressed() -> void:
	if _sel_region == "":
		return
	# BattleSystem.active is the canonical "battle running" flag. (Do NOT set
	# properties on GameState here — it has no battle fields, and assigning an
	# unknown property is a runtime error that kills this handler.)
	# A manual skirmish is never a conquest battle — clear any stale flag so
	# winning here can't accidentally claim a region on the world map.
	Conquest.abandon()
	# Apply map size from the picker.
	for m in MAP_SIZES:
		if str(m[0]) == _sel_map_size:
			BattleSystem.battle_map_size = int(m[3])
			break
	BattleSystem.fog_enabled = _fog_check == null or _fog_check.button_pressed
	BattleSystem.start_battle(_sel_region, int(_teams_slider.value),
			int(_level_slider.value), _sel_difficulty, _sel_resources,
			_sel_heroes.duplicate(),
			_spectate_check != null and _spectate_check.button_pressed)
	get_tree().change_scene_to_file(BATTLE_RTS_SCENE)
