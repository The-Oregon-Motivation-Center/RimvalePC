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

const DIFFICULTIES := [
	["easy",   "😴 Easy",   "Lazy warbands — they guard their turf and rarely strike out."],
	["medium", "⚔ Medium",  "Raiding parties probe your lines — but never the full army."],
	["hard",   "💀 Hard",   "Ruthless: focused full-army assaults on the weakest team."],
]

const RESOURCE_LEVELS := [
	["low",    "🪨 Low",     "Lean veins: 1 home node per team, 2 contested. Every ⛃ matters."],
	["medium", "⛃ Medium",   "Classic economy: 2 home nodes per team, 4 in the midfield."],
	["high",   "💎 High",    "Rich veins: 3 home nodes per team, 6 contested."],
	["insane", "🌋 INSANE",  "The map drips supply: 4 home, 8 contested, 8 wild veins."],
]
var _teams_slider: HSlider
var _teams_val_lbl: Label
var _level_slider: HSlider
var _level_val_lbl: Label
var _diff_hint_lbl: Label
var _res_hint_lbl: Label
var _fog_check: CheckBox
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

	# ── Fog of war toggle ────────────────────────────────────────────────────
	_fog_check = CheckBox.new()
	_fog_check.text = "🌫 Fog of War — scout to reveal the map (recommended)"
	_fog_check.button_pressed = true
	_fog_check.add_theme_font_size_override("font_size", 13)
	_fog_check.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_fog_check)

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

	# ── Rules card ────────────────────────────�