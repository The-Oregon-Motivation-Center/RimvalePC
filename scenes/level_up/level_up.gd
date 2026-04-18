## level_up.gd
## Agent Advancement — full port of LevelUpScreen.kt
## 7 sections: Stats, Skills, Feats, Magic, Identity, Equipment, Lineage

extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const SKILL_NAMES: PackedStringArray = [
	"Arcane", "Crafting", "Creature Handling", "Cunning", "Exertion",
	"Intuition", "Learnedness", "Medical", "Nimble", "Perception",
	"Perform", "Sneak", "Speechcraft", "Survival"
]
const STAT_NAMES: PackedStringArray = ["Strength", "Speed", "Intellect", "Vitality", "Divinity"]
const STAT_ICONS: PackedStringArray = ["💪", "⚡", "🧠", "❤", "✦"]
const SECTION_TITLES: PackedStringArray = ["Stats", "Skills", "Feats", "Magic", "Identity", "Equipment", "Lineage"]
const DOMAIN_FEAT_NAMES: PackedStringArray = ["Rooted Initiate", "Alchemical Adept", "Ember Manipulator", "Whispering Mind"]
const DOMAIN_NAMES: PackedStringArray = ["Biological", "Chemical", "Physical", "Spiritual"]

# ── State ─────────────────────────────────────────────────────────────────────

var _e
var _handle: int = -1
var _section: int = 0

# Pending stat tracking (not committed until Confirm)
var _confirmed_stats: Dictionary = {}
var _pending_stats: Dictionary = {}
var _available_stat_pts: int = 0

# Pending skill tracking
var _confirmed_skills: Dictionary = {}
var _pending_skills: Dictionary = {}
var _available_skill_pts: int = 0

# Feat filter state
var _feat_filter_tier: int = 0
var _feat_filter_cats: Array = []
var _feat_learned_only: bool = false

# Inventory state (Equipment tab)
var _inv_filter: String = "All"
var _stash_filter: String = "All"
var _inv_tab: int = 0

# Magic sub-tab (0=Spellbook  1=Spell Builder)
var _magic_tab: int = 0

# Spell Builder form state — persists across re-renders so the form isn't wiped on tab switch
var _sb_domain: int      = 0
var _sb_effect_idx: int  = 0
var _sb_duration_idx: int = 0
var _sb_range_idx: int   = 0
var _sb_targets: int     = 1
var _sb_area_idx: int    = 0
var _sb_die_count: int   = 0
var _sb_die_idx: int     = 1      # 0=d4 1=d6 2=d8 3=d10 4=d12
var _sb_damage_type: int = 3      # 3=Force
var _sb_is_healing: bool      = false
var _sb_is_saving_throw: bool = false
var _sb_is_teleport: bool     = false
var _sb_conditions: Array     = []   # Array of condition name Strings
var _sb_name: String          = ""
# Stored UI refs for in-place updates (no full redraw needed)
var _sb_preview_lbl: Label
var _sb_breakdown_lbl: Label
var _sb_desc_lbl: Label
var _sb_die_btns: Array = []

# ── Stored UI references ──────────────────────────────────────────────────────

var _content_area: VBoxContainer
var _section_btns: Array = []
var _header_vbox: VBoxContainer

# Stats tab live refs
var _stat_pts_lbl: Label
var _stat_val_lbls: Dictionary = {}
var _stat_confirm_holder: HBoxContainer

# Skills tab live refs
var _skill_pts_lbl: Label
var _skill_val_lbls: Dictionary = {}
var _skill_confirm_holder: HBoxContainer

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_e = RimvaleAPI.engine
	_handle = GameState.selected_hero_handle
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RimvaleUtils.add_bg(self, RimvaleColors.BG_DARK)
	_load_pending_state()
	_build_ui()

func _load_pending_state() -> void:
	if _handle == -1:
		return
	_available_stat_pts = _e.get_character_stat_points(_handle)
	_available_skill_pts = _e.get_character_skill_points(_handle)
	for i in range(STAT_NAMES.size()):
		var v: int = _e.get_character_stat(_handle, i)
		_confirmed_stats[STAT_NAMES[i]] = v
		_pending_stats[STAT_NAMES[i]] = v
	for i in range(SKILL_NAMES.size()):
		var v: int = _e.get_character_skill(_handle, i)
		_confirmed_skills[SKILL_NAMES[i]] = v
		_pending_skills[SKILL_NAMES[i]] = v

# ── UI Construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_build_header())
	root.add_child(_build_section_bar())

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_content_area = VBoxContainer.new()
	_content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_area.add_theme_constant_override("separation", 0)
	scroll.add_child(_content_area)

	_render_section()

func _build_header() -> Control:
	var hdr = ColorRect.new()
	hdr.color = RimvaleColors.BG_CARD
	hdr.custom_minimum_size = Vector2(0, 88)

	var mgn = MarginContainer.new()
	mgn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		mgn.add_theme_constant_override("margin_" + s, 12)
	hdr.add_child(mgn)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	mgn.add_child(hbox)

	_header_vbox = VBoxContainer.new()
	_header_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(_header_vbox)

	_refresh_header()

	var right_col = VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 6)
	hbox.add_child(right_col)

	var back_btn = RimvaleUtils.button("← Back", RimvaleColors.TEXT_GRAY, 38, 13)
	back_btn.pressed.connect(func():
		get_parent().get_parent().pop_screen()
	)
	right_col.add_child(back_btn)

	return hdr

func _refresh_header() -> void:
	for c in _header_vbox.get_children():
		c.queue_free()

	if _handle == -1:
		_header_vbox.add_child(RimvaleUtils.label("No hero selected", 18, RimvaleColors.TEXT_GRAY))
		return

	var name_: String = str(_e.get_character_name(_handle))
	var lineage_: String = str(_e.get_character_lineage_name(_handle))
	var level_: int = _e.get_character_level(_handle)
	var xp_: int = _e.get_character_xp(_handle)
	var xp_req_: int = _e.get_character_xp_required(_handle)
	var role_: String = str(_e.get_character_societal_role_name(_handle))
	var summoner_level: int = GameState.player_level

	# Name row + rename button
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.add_child(RimvaleUtils.label(name_, 20, RimvaleColors.TEXT_WHITE))
	var rename_btn = RimvaleUtils.button("✎", RimvaleColors.TEXT_GRAY, 24, 12)
	rename_btn.pressed.connect(func(): _show_rename_dialog())
	name_row.add_child(rename_btn)
	_header_vbox.add_child(name_row)

	# Level + Lineage
	_header_vbox.add_child(RimvaleUtils.label("Level %d  %s" % [level_, lineage_], 13, RimvaleColors.TEXT_GRAY))

	# Societal role
	if not role_.is_empty():
		_header_vbox.add_child(RimvaleUtils.label(role_, 12, RimvaleColors.TEXT_DIM))

	# Alignment + Domain
	var alignment: String = _get_alignment()
	var domain: String = _get_domain()
	if not alignment.is_empty() or not domain.is_empty():
		var al_row = HBoxContainer.new()
		al_row.add_theme_constant_override("separation", 8)
		if not alignment.is_empty():
			var al_col: Color = Color(0.08, 0.39, 0.75)
			if alignment == "Chaos": al_col = Color(0.72, 0.11, 0.11)
			elif alignment == "The Void": al_col = Color(0.29, 0.08, 0.55)
			al_row.add_child(RimvaleUtils.label(alignment, 11, al_col))
		if not alignment.is_empty() and not domain.is_empty():
			al_row.add_child(RimvaleUtils.label("·", 11, RimvaleColors.TEXT_DIM))
		if not domain.is_empty():
			var dom_col: Color = Color(0.18, 0.49, 0.20)
			if domain == "Chemical": dom_col = Color(0.96, 0.50, 0.09)
			elif domain == "Physical": dom_col = Color(0.21, 0.28, 0.31)
			elif domain == "Spiritual": dom_col = Color(0.42, 0.11, 0.60)
			al_row.add_child(RimvaleUtils.label(domain, 11, dom_col))
		_header_vbox.add_child(al_row)

	# Status / level-up button
	var can_lvl: bool = (xp_ >= xp_req_) and (level_ < summoner_level)
	if level_ >= summoner_level:
		_header_vbox.add_child(RimvaleUtils.label("Level capped (Summoner Lv %d)" % summoner_level, 10, RimvaleColors.DANGER))
	elif can_lvl:
		var lvl_btn = RimvaleUtils.button("⬆ Level Up!", Color(0.30, 0.69, 0.31), 34, 13)
		lvl_btn.pressed.connect(func():
			_e.add_xp(_handle, 0, GameState.player_level)
			_load_pending_state()
			_refresh_header()
			_render_section()
		)
		_header_vbox.add_child(lvl_btn)
	else:
		_header_vbox.add_child(RimvaleUtils.label("XP: %d / %d" % [xp_, xp_req_], 10, RimvaleColors.TEXT_DIM))

func _build_section_bar() -> Control:
	var bar = ScrollContainer.new()
	bar.custom_minimum_size = Vector2(0, 48)
	bar.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 2)
	bar.add_child(hbox)

	for i in range(SECTION_TITLES.size()):
		var idx: int = i
		var btn = RimvaleUtils.button(SECTION_TITLES[i],
			RimvaleColors.ACCENT if i == _section else RimvaleColors.TEXT_GRAY, 42, 13)
		btn.pressed.connect(func(): _on_section(idx))
		_section_btns.append(btn)
		hbox.add_child(btn)

	return bar

func _on_section(idx: int) -> void:
	_section = idx
	for i in range(_section_btns.size()):
		_section_btns[i].add_theme_color_override("font_color",
			RimvaleColors.ACCENT if i == idx else RimvaleColors.TEXT_GRAY)
	_render_section()

func _render_section() -> void:
	# Remove from scene tree immediately so layout doesn't show both old and new content.
	# queue_free() alone only marks for deletion at end of frame — the node stays in the
	# tree (and VBoxContainer still lays it out) until then.
	for child in _content_area.get_children():
		_content_area.remove_child(child)
		child.queue_free()
	_stat_val_lbls.clear()
	_skill_val_lbls.clear()

	var mgn = MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		mgn.add_theme_constant_override("margin_" + s, 16)
	_content_area.add_child(mgn)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	mgn.add_child(vbox)

	match _section:
		0: _build_stats(vbox)
		1: _build_skills(vbox)
		2: _build_feats(vbox)
		3: _build_magic(vbox)
		4: _build_identity(vbox)
		5: _build_equipment(vbox)
		6: _build_lineage(vbox)

# ── Section 0: Stats ──────────────────────────────────────────────────────────

func _build_stats(parent: VBoxContainer) -> void:
	if _handle == -1:
		parent.add_child(RimvaleUtils.label("No hero selected.", 14, RimvaleColors.TEXT_DIM))
		return

	# Points badge + confirm holder
	var hdr_row = HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 12)
	parent.add_child(hdr_row)

	_stat_pts_lbl = RimvaleUtils.label("Stat Points: %d" % _available_stat_pts, 16,
		Color(0.30, 0.69, 0.31) if _available_stat_pts > 0 else RimvaleColors.TEXT_DIM)
	hdr_row.add_child(_stat_pts_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_row.add_child(spacer)

	_stat_confirm_holder = HBoxContainer.new()
	hdr_row.add_child(_stat_confirm_holder)
	_update_stat_confirm_btn()

	parent.add_child(RimvaleUtils.separator())

	var stat_descs: PackedStringArray = [
		"Physical power & AP",
		"AC, Initiative & dodge",
		"Skills & max favored",
		"Max HP & endurance",
		"Spark power & max SP"
	]

	for i in range(STAT_NAMES.size()):
		var stat_idx: int = i
		var stat_name: String = STAT_NAMES[i]
		var confirmed: int = _confirmed_stats.get(stat_name, 0)
		var pending: int = _pending_stats.get(stat_name, confirmed)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 52)
		parent.add_child(row)

		# Icon + name
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)
		info.add_child(RimvaleUtils.label(STAT_ICONS[i] + " " + stat_name, 15, RimvaleColors.TEXT_WHITE))
		info.add_child(RimvaleUtils.label(stat_descs[i], 11, RimvaleColors.TEXT_DIM))

		# Confirmed value (gray) + pending (highlighted if changed)
		var val_lbl: Label
		if pending > confirmed:
			val_lbl = RimvaleUtils.label("%d → %d" % [confirmed, pending], 17, Color(0.30, 0.69, 0.31))
		else:
			val_lbl = RimvaleUtils.label(str(confirmed), 20, RimvaleColors.ACCENT)
		val_lbl.custom_minimum_size = Vector2(60, 0)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(val_lbl)
		_stat_val_lbls[stat_name] = val_lbl

		# Decrement button
		var minus_btn = RimvaleUtils.button("−", RimvaleColors.TEXT_GRAY, 40, 16)
		minus_btn.custom_minimum_size = Vector2(36, 0)
		minus_btn.pressed.connect(func(): _decrement_stat(stat_name))
		row.add_child(minus_btn)

		# Increment button
		var plus_btn = RimvaleUtils.button("+", RimvaleColors.SUCCESS, 40, 16)
		plus_btn.custom_minimum_size = Vector2(36, 0)
		plus_btn.pressed.connect(func(): _increment_stat(stat_name, stat_idx))
		row.add_child(plus_btn)

func _increment_stat(stat_name: String, stat_idx: int) -> void:
	var pending: int = _pending_stats.get(stat_name, 0)
	if pending >= 10:
		return
	var cost: int = 2 if pending >= 5 else 1
	if _available_stat_pts < cost:
		return
	_pending_stats[stat_name] = pending + 1
	_available_stat_pts -= cost
	_refresh_stat_row(stat_name)

func _decrement_stat(stat_name: String) -> void:
	var pending: int = _pending_stats.get(stat_name, 0)
	var confirmed: int = _confirmed_stats.get(stat_name, 0)
	if pending <= confirmed:
		return
	var refund: int = 2 if pending > 5 else 1
	_pending_stats[stat_name] = pending - 1
	_available_stat_pts += refund
	_refresh_stat_row(stat_name)

func _refresh_stat_row(stat_name: String) -> void:
	if _stat_pts_lbl:
		_stat_pts_lbl.text = "Stat Points: %d" % _available_stat_pts
		_stat_pts_lbl.add_theme_color_override("font_color",
			Color(0.30, 0.69, 0.31) if _available_stat_pts > 0 else RimvaleColors.TEXT_DIM)
	if stat_name in _stat_val_lbls:
		var lbl: Label = _stat_val_lbls[stat_name]
		var confirmed: int = _confirmed_stats.get(stat_name, 0)
		var pending: int = _pending_stats.get(stat_name, confirmed)
		if pending > confirmed:
			lbl.text = "%d → %d" % [confirmed, pending]
			lbl.add_theme_color_override("font_color", Color(0.30, 0.69, 0.31))
		else:
			lbl.text = str(confirmed)
			lbl.add_theme_color_override("font_color", RimvaleColors.ACCENT)
	_update_stat_confirm_btn()

func _update_stat_confirm_btn() -> void:
	if not _stat_confirm_holder:
		return
	for c in _stat_confirm_holder.get_children():
		c.queue_free()
	var has_changes: bool = false
	for sn in _pending_stats:
		if _pending_stats[sn] > _confirmed_stats.get(sn, 0):
			has_changes = true
			break
	if has_changes:
		var btn = RimvaleUtils.button("Confirm Changes", Color(0.30, 0.69, 0.31), 36, 12)
		btn.pressed.connect(func(): _confirm_stats())
		_stat_confirm_holder.add_child(btn)

func _confirm_stats() -> void:
	if _handle == -1:
		return
	for i in range(STAT_NAMES.size()):
		var sn: String = STAT_NAMES[i]
		var confirmed: int = _confirmed_stats.get(sn, 0)
		var pending: int = _pending_stats.get(sn, confirmed)
		var diff: int = pending - confirmed
		for _j in range(diff):
			_e.spend_stat_point(_handle, i)
	_load_pending_state()
	_refresh_header()
	_render_section()

# ── Section 1: Skills ─────────────────────────────────────────────────────────

func _build_skills(parent: VBoxContainer) -> void:
	if _handle == -1:
		parent.add_child(RimvaleUtils.label("No hero selected.", 14, RimvaleColors.TEXT_DIM))
		return

	var intellect: int = _e.get_character_stat(_handle, 2)
	var favored_count: int = 0
	for i in range(SKILL_NAMES.size()):
		if _e.is_favored_skill(_handle, i):
			favored_count += 1

	# Header row
	var hdr_row = HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 12)
	parent.add_child(hdr_row)

	var pts_col = VBoxContainer.new()
	pts_col.add_theme_constant_override("separation", 2)
	hdr_row.add_child(pts_col)

	_skill_pts_lbl = RimvaleUtils.label("Skill Points: %d" % _available_skill_pts, 16,
		Color(0.13, 0.59, 0.95) if _available_skill_pts > 0 else RimvaleColors.TEXT_DIM)
	pts_col.add_child(_skill_pts_lbl)
	pts_col.add_child(RimvaleUtils.label("Favored: %d / %d  (Intellect limit)" % [favored_count, intellect], 11, RimvaleColors.TEXT_DIM))

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_row.add_child(spacer)

	_skill_confirm_holder = HBoxContainer.new()
	hdr_row.add_child(_skill_confirm_holder)
	_update_skill_confirm_btn()

	parent.add_child(RimvaleUtils.separator())

	for i in range(SKILL_NAMES.size()):
		var skill_idx: int = i
		var skill_name: String = SKILL_NAMES[i]
		var confirmed: int = _confirmed_skills.get(skill_name, 0)
		var pending: int = _pending_skills.get(skill_name, confirmed)
		var is_fav: bool = _e.is_favored_skill(_handle, i)
		var can_fav: bool = is_fav or favored_count < intellect

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 28)
		parent.add_child(row)

		# Favored toggle
		var fav_col: Color = Color(0.91, 0.12, 0.39) if is_fav else RimvaleColors.TEXT_DIM
		var fav_btn = RimvaleUtils.button("❤" if is_fav else "♡", fav_col, 38, 14)
		fav_btn.custom_minimum_size = Vector2(34, 0)
		fav_btn.pressed.connect(func():
			if can_fav:
				_e.toggle_favored_skill(_handle, skill_idx)
				_render_section()
		)
		row.add_child(fav_btn)

		# Skill name
		var name_lbl = RimvaleUtils.label(skill_name, 14,
			Color(0.91, 0.12, 0.39) if is_fav else RimvaleColors.TEXT_WHITE)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		# Value label
		var val_lbl: Label
		if pending > confirmed:
			val_lbl = RimvaleUtils.label("%d → %d" % [confirmed, pending], 16, Color(0.13, 0.59, 0.95))
		else:
			val_lbl = RimvaleUtils.label(str(confirmed), 18, RimvaleColors.ACCENT)
		val_lbl.custom_minimum_size = Vector2(54, 0)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(val_lbl)
		_skill_val_lbls[skill_name] = val_lbl

		# Decrement
		var minus_btn = RimvaleUtils.button("−", RimvaleColors.TEXT_GRAY, 38, 15)
		minus_btn.custom_minimum_size = Vector2(34, 0)
		minus_btn.pressed.connect(func(): _decrement_skill(skill_name))
		row.add_child(minus_btn)

		# Increment
		var plus_btn = RimvaleUtils.button("+", Color(0.13, 0.59, 0.95), 38, 15)
		plus_btn.custom_minimum_size = Vector2(34, 0)
		plus_btn.pressed.connect(func(): _increment_skill(skill_name, skill_idx))
		row.add_child(plus_btn)

func _increment_skill(skill_name: String, skill_idx: int) -> void:
	var pending: int = _pending_skills.get(skill_name, 0)
	if pending >= 10:
		return
	var cost: int = 2 if pending >= 5 else 1
	if _available_skill_pts < cost:
		return
	_pending_skills[skill_name] = pending + 1
	_available_skill_pts -= cost
	_refresh_skill_row(skill_name)

func _decrement_skill(skill_name: String) -> void:
	var pending: int = _pending_skills.get(skill_name, 0)
	var confirmed: int = _confirmed_skills.get(skill_name, 0)
	if pending <= confirmed:
		return
	var refund: int = 2 if pending > 5 else 1
	_pending_skills[skill_name] = pending - 1
	_available_skill_pts += refund
	_refresh_skill_row(skill_name)

func _refresh_skill_row(skill_name: String) -> void:
	if _skill_pts_lbl:
		_skill_pts_lbl.text = "Skill Points: %d" % _available_skill_pts
		_skill_pts_lbl.add_theme_color_override("font_color",
			Color(0.13, 0.59, 0.95) if _available_skill_pts > 0 else RimvaleColors.TEXT_DIM)
	if skill_name in _skill_val_lbls:
		var lbl: Label = _skill_val_lbls[skill_name]
		var confirmed: int = _confirmed_skills.get(skill_name, 0)
		var pending: int = _pending_skills.get(skill_name, confirmed)
		if pending > confirmed:
			lbl.text = "%d → %d" % [confirmed, pending]
			lbl.add_theme_color_override("font_color", Color(0.13, 0.59, 0.95))
		else:
			lbl.text = str(confirmed)
			lbl.add_theme_color_override("font_color", RimvaleColors.ACCENT)
	_update_skill_confirm_btn()

func _update_skill_confirm_btn() -> void:
	if not _skill_confirm_holder:
		return
	for c in _skill_confirm_holder.get_children():
		c.queue_free()
	var has_changes: bool = false
	for sn in _pending_skills:
		if _pending_skills[sn] > _confirmed_skills.get(sn, 0):
			has_changes = true
			break
	if has_changes:
		var btn = RimvaleUtils.button("Confirm Changes", Color(0.13, 0.59, 0.95), 36, 12)
		btn.pressed.connect(func(): _confirm_skills())
		_skill_confirm_holder.add_child(btn)

func _confirm_skills() -> void:
	if _handle == -1:
		return
	for i in range(SKILL_NAMES.size()):
		var sn: String = SKILL_NAMES[i]
		var confirmed: int = _confirmed_skills.get(sn, 0)
		var pending: int = _pending_skills.get(sn, confirmed)
		var diff: int = pending - confirmed
		for _j in range(diff):
			_e.spend_skill_point(_handle, i)
	_load_pending_state()
	_render_section()

# ── Section 2: Feats ──────────────────────────────────────────────────────────

func _build_feats(parent: VBoxContainer) -> void:
	if _handle == -1:
		parent.add_child(RimvaleUtils.label("No hero selected.", 14, RimvaleColors.TEXT_DIM))
		return

	var feat_pts: int = _e.get_character_feat_points(_handle)

	# Header: points badge + filter controls
	var hdr_row = HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 8)
	parent.add_child(hdr_row)

	hdr_row.add_child(RimvaleUtils.label("Feat Points: %d" % feat_pts, 16,
		Color(0.61, 0.15, 0.69) if feat_pts > 0 else RimvaleColors.TEXT_DIM))

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_row.add_child(spacer)

	# Tier filter OptionButton
	var tier_opt = OptionButton.new()
	tier_opt.custom_minimum_size = Vector2(90, 34)
	tier_opt.add_item("All Tiers", 0)
	for t in range(1, 6):
		tier_opt.add_item("Tier %d" % t, t)
	tier_opt.selected = _feat_filter_tier
	tier_opt.item_selected.connect(func(idx: int):
		_feat_filter_tier = idx
		_render_section()
	)
	hdr_row.add_child(tier_opt)

	# Learned-only toggle
	var learned_col: Color = Color(0.13, 0.59, 0.95) if _feat_learned_only else RimvaleColors.TEXT_GRAY
	var learned_btn = RimvaleUtils.button("✓ Learned" if _feat_learned_only else "All", learned_col, 34, 12)
	learned_btn.pressed.connect(func():
		_feat_learned_only = not _feat_learned_only
		_render_section()
	)
	hdr_row.add_child(learned_btn)

	parent.add_child(RimvaleUtils.separator())

	# All feat categories for filter info
	var all_cats_raw = _e.get_all_feat_categories()
	var all_cats: Array = []
	for c in all_cats_raw:
		all_cats.append(str(c))

	# Category filter row
	var cat_scroll = ScrollContainer.new()
	cat_scroll.custom_minimum_size = Vector2(0, 36)
	cat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(cat_scroll)

	var cat_row = HBoxContainer.new()
	cat_row.add_theme_constant_override("separation", 6)
	cat_scroll.add_child(cat_row)

	var all_btn_col: Color = RimvaleColors.ACCENT if _feat_filter_cats.is_empty() else RimvaleColors.TEXT_GRAY
	var all_chip = RimvaleUtils.button("All", all_btn_col, 30, 12)
	all_chip.pressed.connect(func():
		_feat_filter_cats.clear()
		_render_section()
	)
	cat_row.add_child(all_chip)

	for cat in all_cats:
		var cat_name: String = cat
		var is_sel: bool = cat_name in _feat_filter_cats
		var chip_col: Color = Color(0.61, 0.15, 0.69) if is_sel else RimvaleColors.TEXT_GRAY
		var chip = RimvaleUtils.button(cat_name.left(12), chip_col, 30, 11)
		chip.pressed.connect(func():
			if cat_name in _feat_filter_cats:
				_feat_filter_cats.erase(cat_name)
			else:
				_feat_filter_cats.append(cat_name)
			_render_section()
		)
		cat_row.add_child(chip)

	parent.add_child(RimvaleUtils.spacer(4))

	# Tiers to display
	var tiers_to_show: Array = []
	if _feat_filter_tier == 0:
		tiers_to_show = [1, 2, 3, 4, 5]
	else:
		tiers_to_show = [_feat_filter_tier]

	for tier in tiers_to_show:
		var feats_raw = _e.get_feats_by_tier(tier)
		if feats_raw.size() == 0:
			continue

		var tier_header_added: bool = false

		for feat_raw in feats_raw:
			var feat_name: String = str(feat_raw)
			var details_raw = _e.get_feat_details(feat_name, tier)
			var description: String = str(details_raw[0]) if details_raw.size() > 0 else ""
			var category: String = str(details_raw[1]) if details_raw.size() > 1 else "Miscellaneous"
			var tree_name: String = str(details_raw[2]) if details_raw.size() > 2 else ""

			# Category filter
			if not _feat_filter_cats.is_empty():
				if category not in _feat_filter_cats:
					continue

			var current_tier: int = _e.get_character_feat_tier(_handle, feat_name)
			var is_unlocked: bool = current_tier >= tier
			var can_unlock: bool = _e.can_unlock_feat(_handle, feat_name, tier)

			# Learned-only filter
			if _feat_learned_only and not is_unlocked:
				continue

			# Add tier header once
			if not tier_header_added:
				var tier_lbl = RimvaleUtils.label("── Tier %d ──" % tier, 13, RimvaleColors.ACCENT)
				parent.add_child(tier_lbl)
				tier_header_added = true

			var card = _build_feat_card(feat_name, tier, category, tree_name, description,
				is_unlocked, can_unlock, feat_pts)
			parent.add_child(card)

func _build_feat_card(feat_name: String, tier: int, category: String, tree_name: String,
		description: String, is_unlocked: bool, can_unlock: bool, feat_pts: int) -> Control:
	# PanelContainer auto-sizes to children (ColorRect does not).
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sbox = StyleBoxFlat.new()
	sbox.bg_color = Color(0.10, 0.20, 0.10, 1.0) if is_unlocked else Color(0.10, 0.10, 0.14, 1.0)
	sbox.content_margin_left   = 10.0
	sbox.content_margin_right  = 10.0
	sbox.content_margin_top    = 10.0
	sbox.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", sbox)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)

	var status_mark: String = "✓ " if is_unlocked else ("○ " if can_unlock else "✗ ")
	var name_col: Color = Color(0.30, 0.69, 0.31) if is_unlocked else \
		(RimvaleColors.TEXT_WHITE if can_unlock else RimvaleColors.TEXT_DIM)
	var name_lbl = RimvaleUtils.label(status_mark + feat_name, 14, name_col)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_lbl)

	if not tree_name.is_empty():
		title_row.add_child(RimvaleUtils.label(tree_name.left(16), 10, RimvaleColors.TEXT_DIM))

	if not description.is_empty():
		var desc_lbl = RimvaleUtils.label(description, 11, RimvaleColors.TEXT_GRAY)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_lbl)

	var bottom_row = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 8)
	vbox.add_child(bottom_row)

	bottom_row.add_child(RimvaleUtils.label(category, 10, Color(0.61, 0.15, 0.69)))
	var sp2 = Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(sp2)

	if can_unlock and not is_unlocked and feat_pts > 0:
		var fn_cap: String = feat_name
		var tier_cap: int = tier
		var unlock_btn = RimvaleUtils.button("Unlock (T%d)" % tier, RimvaleColors.GOLD, 32, 12)
		unlock_btn.pressed.connect(func(): _confirm_feat_unlock(fn_cap, tier_cap))
		bottom_row.add_child(unlock_btn)
	elif is_unlocked:
		bottom_row.add_child(RimvaleUtils.label("Unlocked T%d" % _e.get_character_feat_tier(_handle, feat_name),
			10, Color(0.30, 0.69, 0.31)))

	return card

func _confirm_feat_unlock(feat_name: String, tier: int) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Confirm Purchase"
	dialog.dialog_text = "Unlock %s (Tier %d)?" % [feat_name, tier]
	dialog.get_ok_button().text = "Unlock"
	dialog.get_cancel_button().text = "Cancel"
	dialog.confirmed.connect(func():
		if _e.spend_feat_point(_handle, feat_name, tier):
			_render_section()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2(340, 130))

# ── Section 3: Magic ──────────────────────────────────────────────────────────

const DOMAIN_COLORS: Array = [
	Color(0.30, 0.69, 0.31),   # Biological — green
	Color(0.96, 0.65, 0.14),   # Chemical   — amber
	Color(0.40, 0.74, 1.00),   # Physical   — blue
	Color(0.74, 0.40, 1.00),   # Spiritual  — purple
]

# Effects list per domain: each entry is [name: String, base_sp: int]
const DOMAIN_EFFECTS: Array = [
	# Biological
	[["Augment Trait", 1], ["Health Regeneration", 1], ["Memory Edit", 4],
	 ["Mind Control", 6], ["Revivify", 5], ["Terrain Manipulation", 1],
	 ["Undeath", 1], ["Weather Resistance", 1]],
	# Chemical
	[["Combustion", 4], ["Damage an Object", 1], ["Mend an Object", 2],
	 ["Remove Grime", 1], ["Transmutation", 40]],
	# Physical
	[["Accuracy", 1], ["Ambient Temperature", 1], ["Create Construct", 2],
	 ["Damage Output Increase", 1], ["Damage Reduction", 2], ["Illusions", 2],
	 ["Light", 2], ["Shield", 1], ["Telekinesis", 1], ["Teleportation", 1],
	 ["Time Manipulation", 2]],
	# Spiritual
	[["Bless", 1], ["Conjure Damage or Healing", 1], ["Curse", 1],
	 ["Intangibility", 4], ["Suppress Magic", 2], ["Summon", 2]],
]
const CONDITIONS_BENEFICIAL: PackedStringArray = [
	"Calm", "Dodging", "Flying", "Hidden", "Invisible",
	"Invulnerable", "Resistance", "Shielded", "Silent", "Stoneskin"
]
const CONDITIONS_HARMFUL: PackedStringArray = [
	"Bleed", "Blinded", "Charm", "Confused", "Dazed", "Deafened",
	"Depleted", "Diseased", "Enraged", "Exhausted", "Fear", "Fever",
	"Incapacitated", "Paralyzed", "Petrified", "Poisoned", "Prone",
	"Restrained", "Slowed", "Squeeze", "Stunned", "Unconscious", "Vulnerable"
]
const DAMAGE_TYPES: PackedStringArray = [
	"Bludgeoning", "Piercing", "Slashing", "Force", "Fire", "Cold",
	"Lightning", "Acid", "Poison", "Psychic", "Radiant", "Necrotic", "Thunder"
]
# Engine damage type indices now match DAMAGE_TYPES 1:1 (bludgeoning..thunder).
# Pass-through 0-12 lines up with the expanded PHB 13-damage-type list in the engine.
const DAMAGE_TYPE_ENG: PackedInt32Array = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]

const DURATION_LABELS: PackedStringArray = ["Instant", "1 Minute", "10 Minutes", "1 Hour", "1 Day"]
const DURATION_ROUNDS: PackedInt32Array  = [0, 10, 100, 600, 14400]
const DURATION_MULT:   PackedInt32Array  = [1, 2, 3, 5, 10]

const RANGE_LABELS:   PackedStringArray = ["Self", "Touch", "15 ft", "30 ft", "100 ft", "500 ft", "1000 ft"]
const RANGE_SP_COST:  PackedInt32Array  = [0, 0, 1, 2, 3, 6, 10]

const AREA_LABELS: PackedStringArray = ["Single Target", "Small (10 ft cube)", "Large (30 ft cube)", "Massive (100 ft cube)"]
const AREA_MULT:   PackedInt32Array  = [1, 2, 3, 10]

const DIE_LABELS:    PackedStringArray = ["d4", "d6", "d8", "d10", "d12"]
const DIE_SIDES_MOD: PackedInt32Array  = [0, 1, 2, 3, 4]   # extra SP cost per die

# ── Magic: SP cost (matches mobile formula exactly) ───────────────────────────

func _calc_spell_cost(effect_base_sp: int, duration_idx: int, range_idx: int,
		targets: int, area_idx: int, die_count: int, die_idx: int,
		is_saving_throw: bool, harmful_cond_count: int,
		beneficial_cond_count: int) -> int:
	var type_cost: int   = 1 if is_saving_throw else 0
	var sides_mod: int   = DIE_SIDES_MOD[die_idx] if die_idx < DIE_SIDES_MOD.size() else 0
	var dice_cost: int   = die_count * (1 + sides_mod)
	var dur_mult: int    = DURATION_MULT[duration_idx] if duration_idx < DURATION_MULT.size() else 1
	var base_effect: int = effect_base_sp + dice_cost
	var base_with_dur: int = base_effect if duration_idx == 0 else base_effect * dur_mult
	var range_cost: int  = RANGE_SP_COST[range_idx] if range_idx < RANGE_SP_COST.size() else 0
	var target_cost: int = 0
	if targets > 1:
		# PHB multi-target: cumulative sum 2+4+8+16+… per additional target.
		# targets=2 → 2, 3 → 2+4=6, 4 → 2+4+8=14, 5 → 2+4+8+16=30, 6 → 62…
		for i in range(targets - 1):
			target_cost += int(pow(2.0, float(i + 1)))
	var cond_cost: int   = (harmful_cond_count * 3) - (beneficial_cond_count * 2)
	var area_mult: int   = AREA_MULT[area_idx] if area_idx < AREA_MULT.size() else 1
	var base_sum: int    = type_cost + base_with_dur + range_cost + target_cost + cond_cost
	var total: int       = base_sum * area_mult
	if total <= 0 and (dur_mult > 1 or area_mult > 1):
		total = 1
	elif total < 0:
		total = 0
	return total

func _sb_effect_base_sp() -> int:
	var effects: Array = DOMAIN_EFFECTS[_sb_domain] if _sb_domain < DOMAIN_EFFECTS.size() else []
	if _sb_effect_idx < effects.size():
		return int(effects[_sb_effect_idx][1])
	return 1

func _sb_update_preview() -> void:
	if not is_instance_valid(_sb_preview_lbl):
		return
	var harmful: int     = 0
	var beneficial: int  = 0
	for cname in _sb_conditions:
		if cname in CONDITIONS_HARMFUL: harmful += 1
		else: beneficial += 1

	# Individual cost components for breakdown
	var effect_base: int = _sb_effect_base_sp()
	var sides_mod: int   = DIE_SIDES_MOD[_sb_die_idx] if _sb_die_idx < DIE_SIDES_MOD.size() else 0
	var dice_cost: int   = _sb_die_count * (1 + sides_mod)
	var dur_mult: int    = DURATION_MULT[_sb_duration_idx] if _sb_duration_idx < DURATION_MULT.size() else 1
	var range_cost: int  = RANGE_SP_COST[_sb_range_idx] if _sb_range_idx < RANGE_SP_COST.size() else 0
	var target_cost: int = 0
	if _sb_targets > 1:
		for i in range(_sb_targets - 1):
			target_cost += int(pow(2.0, float(i + 1)))
	var cond_cost: int   = (harmful * 3) - (beneficial * 2)
	var type_cost: int   = 1 if _sb_is_saving_throw else 0

	var cost = _calc_spell_cost(
		effect_base, _sb_duration_idx, _sb_range_idx,
		_sb_targets, _sb_area_idx, _sb_die_count, _sb_die_idx,
		_sb_is_saving_throw, harmful, beneficial
	)
	_sb_preview_lbl.text = "Total SP Cost: %d" % cost

	# Breakdown
	if is_instance_valid(_sb_breakdown_lbl):
		var effects_arr: Array = DOMAIN_EFFECTS[_sb_domain] if _sb_domain < DOMAIN_EFFECTS.size() else []
		var effect_name: String = effects_arr[_sb_effect_idx][0] if _sb_effect_idx < effects_arr.size() else "Unknown"
		var lines: PackedStringArray = []
		lines.append("Base Effect (%s): %d" % [effect_name, effect_base])
		if dice_cost > 0:
			lines.append("Dice (%dd%d): +%d" % [_sb_die_count, [4,6,8,10,12][_sb_die_idx], dice_cost])
		if dur_mult > 1:
			lines.append("Duration (×%d): applied" % dur_mult)
		if range_cost > 0:
			lines.append("Range (%s): +%d" % [RANGE_LABELS[_sb_range_idx], range_cost])
		if target_cost > 0:
			lines.append("Multi-target (%d): +%d" % [_sb_targets, target_cost])
		if cond_cost != 0:
			lines.append("Conditions: %s%d" % ["+" if cond_cost > 0 else "", cond_cost])
		if type_cost > 0:
			lines.append("Saving throw: +1")
		var area_mult: int = AREA_MULT[_sb_area_idx] if _sb_area_idx < AREA_MULT.size() else 1
		if area_mult > 1:
			lines.append("Area (×%d): applied" % area_mult)
		_sb_breakdown_lbl.text = "\n".join(lines)

	# Description
	if is_instance_valid(_sb_desc_lbl):
		_sb_desc_lbl.text = _sb_generate_description()

# ── Magic: main builder ───────────────────────────────────────────────────────

func _build_magic(parent: VBoxContainer) -> void:
	if _handle == -1:
		parent.add_child(RimvaleUtils.label("No hero selected.", 14, RimvaleColors.TEXT_DIM))
		return

	var cur_sp: int   = _e.get_character_sp(_handle)
	var max_sp: int   = _e.get_character_max_sp(_handle)
	var div_stat: int = _e.get_character_stat(_handle, 4)  # Divinity = stat index 4

	# ── SP pool bar ──
	var sp_card = PanelContainer.new()
	sp_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sp_sbox = StyleBoxFlat.new()
	sp_sbox.bg_color = Color(0.10, 0.08, 0.20, 1.0)
	sp_sbox.content_margin_left  = 12.0
	sp_sbox.content_margin_right = 12.0
	sp_sbox.content_margin_top   = 10.0
	sp_sbox.content_margin_bottom = 10.0
	sp_card.add_theme_stylebox_override("panel", sp_sbox)
	parent.add_child(sp_card)

	var sp_vbox = VBoxContainer.new()
	sp_vbox.add_theme_constant_override("separation", 4)
	sp_card.add_child(sp_vbox)

	var sp_row = HBoxContainer.new()
	sp_row.add_theme_constant_override("separation", 12)
	sp_vbox.add_child(sp_row)
	sp_row.add_child(RimvaleUtils.label("✦ SPELL POOL", 13, RimvaleColors.SP_PURPLE))
	var sp_val = RimvaleUtils.label("%d / %d SP" % [cur_sp, max_sp], 18, Color(0.74, 0.40, 1.0))
	sp_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp_row.add_child(sp_val)
	sp_row.add_child(RimvaleUtils.label("DIV %d" % div_stat, 12, RimvaleColors.TEXT_DIM))

	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.15, 0.12, 0.25, 1.0)
	bar_bg.custom_minimum_size = Vector2(0, 6)
	sp_vbox.add_child(bar_bg)
	var bar_fill = ColorRect.new()
	bar_fill.color = Color(0.55, 0.22, 0.90, 1.0)
	var pct: float = float(cur_sp) / float(max_sp) if max_sp > 0 else 0.0
	bar_fill.anchor_right = pct
	bar_fill.anchor_bottom = 1.0
	bar_bg.add_child(bar_fill)

	# ── Sub-tab bar ──
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 0)
	parent.add_child(tab_row)

	var tab_labels = ["📖 Spellbook", "⚗ Spell Builder"]
	for ti in range(2):
		var ti_cap: int = ti
		var tbtn = RimvaleUtils.button(tab_labels[ti],
			RimvaleColors.ACCENT if ti == _magic_tab else RimvaleColors.TEXT_GRAY, 42, 14)
		tbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tbtn.pressed.connect(func():
			_magic_tab = ti_cap
			_render_section()
		)
		tab_row.add_child(tbtn)

	parent.add_child(RimvaleUtils.separator())

	if _magic_tab == 0:
		_build_spellbook(parent)
	else:
		_build_spell_builder_inline(parent)

# ── Spellbook tab ─────────────────────────────────────────────────────────────

func _build_spellbook(parent: VBoxContainer) -> void:
	var level_: int      = _e.get_character_level(_handle)
	var learned_raw = _e.get_learned_spells(_handle)
	var learned: Array   = []
	for s in learned_raw:
		learned.append(str(s))
	var all_spells = _e.get_all_spells()
	var custom_spells = _e.get_custom_spells()

	# ── Known spells ──
	parent.add_child(RimvaleUtils.label("KNOWN SPELLS", 12, RimvaleColors.TEXT_DIM))

	if learned.is_empty():
		parent.add_child(RimvaleUtils.label("No spells learned yet.", 13, RimvaleColors.TEXT_GRAY))
	else:
		# Build lookup: name -> [domain_idx, cost, desc]
		var lookup: Dictionary = {}
		for sd in all_spells:
			lookup[str(sd[0])] = [int(str(sd[1])), int(str(sd[2])), str(sd[3]) if sd.size() > 3 else ""]
		for sd in custom_spells:
			lookup[str(sd[0])] = [int(str(sd[1])), int(str(sd[2])), str(sd[3]) if sd.size() > 3 else ""]

		for sname in learned:
			var info: Array = lookup.get(sname, [0, 0, ""])
			var dom_name: String = DOMAIN_NAMES[info[0]] if info[0] < DOMAIN_NAMES.size() else ""
			parent.add_child(_build_spell_card(sname, info[0], dom_name, info[1], info[2], true, false))

	parent.add_child(RimvaleUtils.separator())
	parent.add_child(RimvaleUtils.label("LEARN NEW SPELLS", 12, RimvaleColors.TEXT_DIM))
	parent.add_child(RimvaleUtils.label(
		"Requires the domain feat at the needed tier  ·  level >= SP cost", 10, RimvaleColors.TEXT_DIM))

	var any_shown: bool = false
	for spell_data in all_spells:
		var sname: String   = str(spell_data[0])
		if sname in learned: continue
		var dom_idx: int    = int(str(spell_data[1]))
		var cost: int       = int(str(spell_data[2]))
		var desc: String    = str(spell_data[3]) if spell_data.size() > 3 else ""
		var dom_name: String = DOMAIN_NAMES[dom_idx] if dom_idx < DOMAIN_NAMES.size() else "Unknown"
		var dom_feat: String = DOMAIN_FEAT_NAMES[dom_idx] if dom_idx < DOMAIN_FEAT_NAMES.size() else ""
		var tier_req: int   = 1
		if cost > 7: tier_req = 3
		elif cost > 4: tier_req = 2
		var has_feat: bool  = _e.get_character_feat_tier(_handle, dom_feat) >= tier_req if dom_feat else false
		var can_learn: bool = has_feat and (cost <= level_ or level_ >= 20)
		parent.add_child(_build_spell_card(sname, dom_idx, dom_name, cost, desc, false, can_learn))
		any_shown = true

	# Custom spells also learnable from spellbook
	for spell_data in custom_spells:
		var sname: String   = str(spell_data[0])
		if sname in learned: continue
		var dom_idx: int    = int(str(spell_data[1]))
		var cost: int       = int(str(spell_data[2]))
		var desc: String    = str(spell_data[3]) if spell_data.size() > 3 else ""
		var dom_name: String = DOMAIN_NAMES[dom_idx] if dom_idx < DOMAIN_NAMES.size() else "Unknown"
		var dom_feat: String = DOMAIN_FEAT_NAMES[dom_idx] if dom_idx < DOMAIN_FEAT_NAMES.size() else ""
		var tier_req: int   = 1
		if cost > 7: tier_req = 3
		elif cost > 4: tier_req = 2
		var has_feat: bool  = _e.get_character_feat_tier(_handle, dom_feat) >= tier_req if dom_feat else false
		var can_learn: bool = has_feat and (cost <= level_ or level_ >= 20)
		parent.add_child(_build_spell_card(sname, dom_idx, dom_name, cost, desc, false, can_learn))
		any_shown = true

	if not any_shown:
		parent.add_child(RimvaleUtils.label("All available spells already learned.", 13, RimvaleColors.TEXT_GRAY))

func _build_spell_card(spell_name: String, domain_idx: int, domain_name: String, cost: int,
		desc: String, is_learned: bool, can_learn: bool) -> Control:
	var dom_col: Color = DOMAIN_COLORS[domain_idx] if domain_idx < DOMAIN_COLORS.size() else RimvaleColors.TEXT_DIM
	var cur_sp: int    = _e.get_character_sp(_handle) if _handle != -1 else 0
	var can_cast: bool = is_learned and cur_sp >= cost and cost > 0

	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sbox = StyleBoxFlat.new()
	sbox.bg_color = Color(0.08, 0.12, 0.22, 1.0) if is_learned else Color(0.10, 0.10, 0.14, 1.0)
	sbox.content_margin_left   = 10.0
	sbox.content_margin_right  = 10.0
	sbox.content_margin_top    = 10.0
	sbox.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", sbox)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Title row
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)

	var icon: String  = "🔮 " if is_learned else "○ "
	var name_col: Color = Color(0.74, 0.50, 1.0) if is_learned else 		(RimvaleColors.TEXT_WHITE if can_learn else RimvaleColors.TEXT_DIM)
	var name_lbl = RimvaleUtils.label(icon + spell_name, 14, name_col)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_lbl)

	if cost > 0:
		var cost_col: Color = Color(0.55, 0.22, 0.90) if is_learned else RimvaleColors.TEXT_DIM
		title_row.add_child(RimvaleUtils.label("%d SP" % cost, 13, cost_col))

	if not domain_name.is_empty():
		vbox.add_child(RimvaleUtils.label(domain_name + " Domain", 10, dom_col))

	if not desc.is_empty():
		var dl = RimvaleUtils.label(desc, 11, RimvaleColors.TEXT_GRAY)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(dl)

	if not can_learn and not is_learned and cost > 0:
		var tr: int = 1
		if cost > 7: tr = 3
		elif cost > 4: tr = 2
		var df: String = DOMAIN_FEAT_NAMES[domain_idx] if domain_idx < DOMAIN_FEAT_NAMES.size() else "domain feat"
		vbox.add_child(RimvaleUtils.label("Requires %s T%d  ·  level >= %d" % [df, tr, cost], 10, RimvaleColors.DANGER))

	if is_learned and not can_cast and cost > 0:
		vbox.add_child(RimvaleUtils.label("Not enough SP to cast", 10, RimvaleColors.DANGER))

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)
	var sp2 = Control.new(); sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(sp2)

	var sn_cap: String = spell_name
	var sc_cap: int    = cost
	if is_learned:
		var cast_btn = RimvaleUtils.button("Cast", Color(0.55, 0.22, 0.90), 34, 12)
		cast_btn.disabled = not can_cast
		cast_btn.pressed.connect(func():
			if _e.spend_character_sp(_handle, sc_cap):
				_render_section()
			else:
				OS.alert("Not enough SP!", "Spell")
		)
		btn_row.add_child(cast_btn)
		var forget_btn = RimvaleUtils.button("Forget", RimvaleColors.DANGER, 30, 12)
		forget_btn.pressed.connect(func(): _e.forget_spell(_handle, sn_cap); _render_section())
		btn_row.add_child(forget_btn)
	elif can_learn:
		var learn_btn = RimvaleUtils.button("Learn", Color(0.13, 0.59, 0.95), 34, 12)
		learn_btn.pressed.connect(func(): _e.learn_spell(_handle, sn_cap); _render_section())
		btn_row.add_child(learn_btn)

	return card

# ── Spell Builder tab (inline, matching Rimvale Mobile) ───────────────────────

func _build_spell_builder_inline(parent: VBoxContainer) -> void:
	_sb_die_btns.clear()
	_sb_preview_lbl = null
	_sb_breakdown_lbl = null
	_sb_desc_lbl = null

	# ── Header ──
	parent.add_child(RimvaleUtils.label("Spell Crafter", 18, RimvaleColors.TEXT_WHITE))
	parent.add_child(RimvaleUtils.spacer(4))

	# ── Spell Name (at top, matching mobile) ──
	var name_edit = LineEdit.new()
	name_edit.placeholder_text = "Spell Name"
	name_edit.text = _sb_name
	name_edit.custom_minimum_size = Vector2(0, 40)
	name_edit.add_theme_font_size_override("font_size", 15)
	name_edit.text_changed.connect(func(t: String): _sb_name = t)
	parent.add_child(name_edit)
	parent.add_child(RimvaleUtils.spacer(4))

	# ── Domain ──
	var domain_opt = OptionButton.new()
	for dn in DOMAIN_NAMES:
		domain_opt.add_item(dn)
	domain_opt.selected = _sb_domain
	domain_opt.item_selected.connect(func(i: int):
		_sb_domain = i
		_sb_effect_idx = 0
		_render_section()
	)
	parent.add_child(_sb_lrow("Domain", domain_opt))

	# ── Effect ──
	var effect_opt = OptionButton.new()
	var effects_for_domain: Array = DOMAIN_EFFECTS[_sb_domain] if _sb_domain < DOMAIN_EFFECTS.size() else []
	for ef in effects_for_domain:
		effect_opt.add_item(ef[0])
	effect_opt.selected = mini(_sb_effect_idx, max(0, effects_for_domain.size() - 1))
	effect_opt.item_selected.connect(func(i: int):
		_sb_effect_idx = i
		_sb_update_preview()
	)
	parent.add_child(_sb_lrow("Effect", effect_opt))

	# ── Duration ──
	var dur_opt = OptionButton.new()
	for dl in DURATION_LABELS:
		dur_opt.add_item(dl)
	dur_opt.selected = _sb_duration_idx
	dur_opt.item_selected.connect(func(i: int):
		_sb_duration_idx = i
		_sb_update_preview()
	)
	parent.add_child(_sb_lrow("Duration", dur_opt))

	# ── Range ──
	var range_opt = OptionButton.new()
	for rl in RANGE_LABELS:
		range_opt.add_item(rl)
	range_opt.selected = _sb_range_idx
	range_opt.item_selected.connect(func(i: int):
		_sb_range_idx = i
		_sb_update_preview()
	)
	parent.add_child(_sb_lrow("Range", range_opt))

	# ── Targets (1-10) ──
	var tgt_val_lbl = RimvaleUtils.label("Targets: %d" % _sb_targets, 13, RimvaleColors.TEXT_GRAY)
	parent.add_child(tgt_val_lbl)
	var tgt_slider = HSlider.new()
	tgt_slider.min_value = 1; tgt_slider.max_value = 10; tgt_slider.step = 1
	tgt_slider.value = _sb_targets
	tgt_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tgt_slider.value_changed.connect(func(v: float):
		_sb_targets = int(v)
		tgt_val_lbl.text = "Targets: %d" % _sb_targets
		_sb_update_preview()
	)
	parent.add_child(tgt_slider)

	# ── Area ──
	var area_opt = OptionButton.new()
	for al in AREA_LABELS:
		area_opt.add_item(al)
	area_opt.selected = _sb_area_idx
	area_opt.item_selected.connect(func(i: int):
		_sb_area_idx = i
		_sb_update_preview()
	)
	parent.add_child(_sb_lrow("Area", area_opt))

	# ── Dice Count (0-10) ──
	var dice_val_lbl = RimvaleUtils.label("Dice Count: %d" % _sb_die_count, 13, RimvaleColors.TEXT_GRAY)
	parent.add_child(dice_val_lbl)
	var dice_slider = HSlider.new()
	dice_slider.min_value = 0; dice_slider.max_value = 10; dice_slider.step = 1
	dice_slider.value = _sb_die_count
	dice_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dice_slider.value_changed.connect(func(v: float):
		_sb_die_count = int(v)
		dice_val_lbl.text = "Dice Count: %d" % _sb_die_count
		_sb_update_preview()
	)
	parent.add_child(dice_slider)

	# ── Die Type ──
	parent.add_child(RimvaleUtils.label("Die Type", 13, RimvaleColors.TEXT_GRAY))
	var die_type_row = HBoxContainer.new()
	die_type_row.add_theme_constant_override("separation", 6)
	for di in range(DIE_LABELS.size()):
		var di_cap: int = di
		var col: Color = RimvaleColors.ACCENT if di == _sb_die_idx else RimvaleColors.TEXT_GRAY
		var dbtn = RimvaleUtils.button(DIE_LABELS[di], col, 34, 13)
		dbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dbtn.pressed.connect(func():
			_sb_die_idx = di_cap
			for k in range(_sb_die_btns.size()):
				_sb_die_btns[k].add_theme_color_override("font_color",
					RimvaleColors.ACCENT if k == _sb_die_idx else RimvaleColors.TEXT_GRAY)
			_sb_update_preview()
		)
		_sb_die_btns.append(dbtn)
		die_type_row.add_child(dbtn)
	parent.add_child(die_type_row)

	# ── Damage Type ──
	var dmg_opt = OptionButton.new()
	for dt in DAMAGE_TYPES:
		dmg_opt.add_item(dt)
	dmg_opt.selected = _sb_damage_type
	dmg_opt.item_selected.connect(func(i: int):
		_sb_damage_type = i
		_sb_update_preview()
	)
	parent.add_child(_sb_lrow("Damage Type", dmg_opt))

	parent.add_child(RimvaleUtils.separator())

	# ── Toggle flags (checkboxes matching mobile layout) ──
	var heal_row = HBoxContainer.new()
	heal_row.add_theme_constant_override("separation", 20)
	var heal_chk = CheckBox.new(); heal_chk.text = "Healing Spell"
	heal_chk.button_pressed = _sb_is_healing
	heal_chk.add_theme_font_size_override("font_size", 13)
	heal_chk.toggled.connect(func(b: bool): _sb_is_healing = b; _sb_update_preview())
	heal_row.add_child(heal_chk)
	var save_chk = CheckBox.new(); save_chk.text = "No Attack Roll\n(Target saves)"
	save_chk.button_pressed = _sb_is_saving_throw
	save_chk.add_theme_font_size_override("font_size", 13)
	save_chk.toggled.connect(func(b: bool): _sb_is_saving_throw = b; _sb_update_preview())
	heal_row.add_child(save_chk)
	parent.add_child(heal_row)

	var tele_chk = CheckBox.new(); tele_chk.text = "Teleportation"
	tele_chk.button_pressed = _sb_is_teleport
	tele_chk.add_theme_font_size_override("font_size", 13)
	tele_chk.toggled.connect(func(b: bool): _sb_is_teleport = b; _sb_update_preview())
	parent.add_child(tele_chk)

	parent.add_child(RimvaleUtils.separator())

	# ── Conditions (two columns: Beneficial | Harmful) ──
	parent.add_child(RimvaleUtils.label("Conditions", 14, RimvaleColors.TEXT_WHITE))
	parent.add_child(RimvaleUtils.spacer(2))

	var cond_outer = HBoxContainer.new()
	cond_outer.add_theme_constant_override("separation", 16)
	parent.add_child(cond_outer)

	# Beneficial column
	var ben_col = VBoxContainer.new()
	ben_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ben_col.add_theme_constant_override("separation", 0)
	cond_outer.add_child(ben_col)
	ben_col.add_child(RimvaleUtils.label("Beneficial", 12, Color(0.30, 0.69, 0.31)))
	for cname in CONDITIONS_BENEFICIAL:
		var cn_cap: String = cname
		var chk = CheckBox.new()
		chk.text = cname
		chk.button_pressed = cname in _sb_conditions
		chk.add_theme_font_size_override("font_size", 12)
		chk.toggled.connect(func(b: bool):
			if b:
				if cn_cap not in _sb_conditions: _sb_conditions.append(cn_cap)
			else:
				_sb_conditions.erase(cn_cap)
			_sb_update_preview()
		)
		ben_col.add_child(chk)

	# Harmful column
	var harm_col = VBoxContainer.new()
	harm_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	harm_col.add_theme_constant_override("separation", 0)
	cond_outer.add_child(harm_col)
	harm_col.add_child(RimvaleUtils.label("Harmful", 12, Color(0.90, 0.40, 0.40)))
	for cname in CONDITIONS_HARMFUL:
		var cn_cap: String = cname
		var chk = CheckBox.new()
		chk.text = cname
		chk.button_pressed = cname in _sb_conditions
		chk.add_theme_font_size_override("font_size", 12)
		chk.toggled.connect(func(b: bool):
			if b:
				if cn_cap not in _sb_conditions: _sb_conditions.append(cn_cap)
			else:
				_sb_conditions.erase(cn_cap)
			_sb_update_preview()
		)
		harm_col.add_child(chk)

	parent.add_child(RimvaleUtils.spacer(8))

	# ── SP Cost preview card (matching mobile's bottom card) ──
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.14, 0.12, 0.22, 1.0)
	card_style.corner_radius_top_left = 8; card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8; card_style.corner_radius_bottom_right = 8
	card_style.content_margin_left = 16.0; card_style.content_margin_right = 16.0
	card_style.content_margin_top = 14.0; card_style.content_margin_bottom = 14.0
	card.add_theme_stylebox_override("panel", card_style)
	parent.add_child(card)

	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)
	card.add_child(card_vbox)

	_sb_preview_lbl = RimvaleUtils.label("Total SP Cost: —", 20, Color(0.74, 0.40, 1.0))
	card_vbox.add_child(_sb_preview_lbl)

	_sb_breakdown_lbl = RimvaleUtils.label("", 11, RimvaleColors.TEXT_DIM)
	_sb_breakdown_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(_sb_breakdown_lbl)

	card_vbox.add_child(RimvaleUtils.spacer(4))
	card_vbox.add_child(RimvaleUtils.label("Description:", 13, RimvaleColors.TEXT_WHITE))
	_sb_desc_lbl = RimvaleUtils.label("", 12, Color(0.70, 0.75, 0.85))
	_sb_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(_sb_desc_lbl)

	_sb_update_preview()   # populate cost, breakdown, description

	card_vbox.add_child(RimvaleUtils.spacer(8))

	# ── Register button ──
	# ── Helper lambda: build the spell dict and register it globally ───────────
	var _do_register_spell: Callable = func(also_learn: bool) -> void:
		var sname: String = _sb_name.strip_edges()
		if sname.is_empty():
			OS.alert("Please enter a spell name.", "Spell Builder")
			return

		var harmful: int    = 0
		var beneficial: int = 0
		for cname in _sb_conditions:
			if cname in CONDITIONS_HARMFUL: harmful += 1
			else: beneficial += 1

		var final_cost: int = _calc_spell_cost(
			_sb_effect_base_sp(), _sb_duration_idx, _sb_range_idx,
			_sb_targets, _sb_area_idx, _sb_die_count, _sb_die_idx,
			_sb_is_saving_throw, harmful, beneficial
		)

		var die_sides: int   = [4, 6, 8, 10, 12][_sb_die_idx]
		var dur_rounds: int  = DURATION_ROUNDS[_sb_duration_idx]
		var eng_dmg_type: int = DAMAGE_TYPE_ENG[_sb_damage_type] if _sb_damage_type < DAMAGE_TYPE_ENG.size() else 3
		var cond_csv: String  = ",".join(_sb_conditions)

		_e.add_custom_spell(
			sname, _sb_domain, final_cost, _sb_generate_description(),
			_sb_range_idx, not _sb_is_saving_throw,
			_sb_die_count, die_sides, eng_dmg_type,
			_sb_is_healing, dur_rounds, _sb_targets,
			_sb_area_idx, cond_csv, _sb_is_teleport
		)

		# Also add it to this hero's learned spells immediately
		if also_learn and _handle != -1:
			_e.learn_spell(_handle, sname)

		_sb_name = ""
		_magic_tab = 0
		_render_section()

	var register_btn = RimvaleUtils.button("Register Custom Spell", Color(0.35, 0.28, 0.65), 48, 14)
	register_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	register_btn.pressed.connect(func(): _do_register_spell.call(true))
	card_vbox.add_child(register_btn)

## Generate a human-readable spell description (matches mobile layout).
func _sb_generate_description() -> String:
	var effects_arr: Array = DOMAIN_EFFECTS[_sb_domain] if _sb_domain < DOMAIN_EFFECTS.size() else []
	var effect_name: String = effects_arr[_sb_effect_idx][0] if _sb_effect_idx < effects_arr.size() else "Unknown"
	var domain_name: String = DOMAIN_NAMES[_sb_domain] if _sb_domain < DOMAIN_NAMES.size() else "Unknown"
	var target_desc: String = "a single target" if _sb_targets <= 1 else "up to %d targets" % _sb_targets
	var range_desc: String = "on yourself" if _sb_range_idx == 0 else "within %s" % RANGE_LABELS[_sb_range_idx]
	var area_desc: String = "" if _sb_area_idx == 0 else " affecting a %s" % AREA_LABELS[_sb_area_idx]
	var dur_desc: String = DURATION_LABELS[_sb_duration_idx]
	var save_desc: String = ". Targets may roll a saving throw to resist or halve the effect." if _sb_is_saving_throw else "."

	if _sb_is_teleport:
		var tele_target: String = "yourself" if _sb_range_idx == 0 else "a target %s" % range_desc
		return "Instantly teleport %s to a selected location. SP cost scales with distance: 10ft=1SP, 20ft=2SP, 30ft=4SP. Unwilling creatures resist with a Divinity save." % tele_target

	var action_word: String = "heals for" if _sb_is_healing else "deals"
	var dice_desc: String = ""
	if _sb_die_count > 0:
		dice_desc = " %dd%d" % [_sb_die_count, [4,6,8,10,12][_sb_die_idx]]
	var type_desc: String = ""
	if not _sb_is_healing and _sb_die_count > 0:
		type_desc = " %s damage" % DAMAGE_TYPES[_sb_damage_type]
	elif _sb_is_healing and _sb_die_count > 0:
		type_desc = " hit points"

	return "Using the %s domain, you weave a spell of %s that %s%s%s targeting %s %s%s. The effect lasts for %s%s" % [
		domain_name, effect_name, action_word, dice_desc, type_desc,
		target_desc, range_desc, area_desc, dur_desc, save_desc]

# ── Helper: labeled two-column row for spell builder ─────────────────────────

func _sb_lrow(label_text: String, ctrl: Control) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl = RimvaleUtils.label(label_text, 13, RimvaleColors.TEXT_GRAY)
	lbl.custom_minimum_size = Vector2(140, 0)
	row.add_child(lbl)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ctrl)
	return row

# ── Section 4: Identity ───────────────────────────────────────────────────────

func _build_identity(parent: VBoxContainer) -> void:
	if _handle == -1:
		parent.add_child(RimvaleUtils.label("No hero selected.", 14, RimvaleColors.TEXT_DIM))
		return

	# ── Safeguard stat chooser ──
	var safeguard_tier: int = _e.get_character_feat_tier(_handle, "Safeguard")
	if safeguard_tier >= 1 and safeguard_tier <= 4:
		var max_choices: int = 2
		if safeguard_tier == 3: max_choices = 3
		elif safeguard_tier == 4: max_choices = 4

		# PanelContainer auto-sizes to children (ColorRect does not).
		var saf_card = PanelContainer.new()
		saf_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var saf_style = StyleBoxFlat.new()
		saf_style.bg_color = Color(0.10, 0.14, 0.20, 1.0)
		saf_style.content_margin_left   = 10.0
		saf_style.content_margin_right  = 10.0
		saf_style.content_margin_top    = 10.0
		saf_style.content_margin_bottom = 10.0
		saf_card.add_theme_stylebox_override("panel", saf_style)
		var saf_vbox = VBoxContainer.new()
		saf_vbox.add_theme_constant_override("separation", 6)
		saf_card.add_child(saf_vbox)

		saf_vbox.add_child(RimvaleUtils.label(
			"Safeguard (T%d) — Choose %d Stats" % [safeguard_tier, max_choices], 14, RimvaleColors.ACCENT))
		saf_vbox.add_child(RimvaleUtils.label("Chosen stats get doubled modifiers on saving throws.", 11, RimvaleColors.TEXT_GRAY))

		var chosen_raw = _e.get_safeguard_chosen_stats(_handle)
		var chosen: Array = []
		for c in chosen_raw:
			chosen.append(int(c))

		var chip_row = HBoxContainer.new()
		chip_row.add_theme_constant_override("separation", 6)
		saf_vbox.add_child(chip_row)

		for si in range(STAT_NAMES.size()):
			var stat_idx_cap: int = si
			var is_chosen: bool = si in chosen
			var can_add: bool = is_chosen or chosen.size() < max_choices
			var chip_col: Color = Color(0.30, 0.69, 0.31) if is_chosen else \
				(RimvaleColors.TEXT_GRAY if can_add else RimvaleColors.TEXT_DIM)
			var chip = RimvaleUtils.button(STAT_NAMES[si].left(3), chip_col, 30, 11)
			chip.custom_minimum_size = Vector2(52, 0)
			chip.pressed.connect(func():
				if can_add or is_chosen:
					var new_chosen: Array = chosen.duplicate()
					if stat_idx_cap in new_chosen:
						new_chosen.erase(stat_idx_cap)
					else:
						new_chosen.append(stat_idx_cap)
					var arr = PackedInt32Array(new_chosen)
					_e.set_safeguard_chosen_stats(_handle, arr)
					_render_section()
			)
			chip_row.add_child(chip)

		parent.add_child(saf_card)
		parent.add_child(RimvaleUtils.separator())

	# ── Societal Roles ──
	parent.add_child(RimvaleUtils.label("SOCIETAL ROLE", 13, RimvaleColors.TEXT_DIM))

	var current_role: String = str(_e.get_character_societal_role_name(_handle))
	if not current_role.is_empty():
		parent.add_child(RimvaleUtils.label("Current: " + current_role, 14, Color(0.30, 0.69, 0.31)))
	else:
		parent.add_child(RimvaleUtils.label("No role selected", 13, RimvaleColors.TEXT_GRAY))

	parent.add_child(RimvaleUtils.separator())

	var roles_raw = _e.get_all_societal_roles()
	for role_raw in roles_raw:
		var role_name: String = str(role_raw)
		var details_raw = _e.get_societal_role_details(role_name)
		var primary: String = str(details_raw[0]) if details_raw.size() > 0 else ""
		var secondary: String = str(details_raw[1]) if details_raw.size() > 1 else ""
		var role_desc: String = str(details_raw[2]) if details_raw.size() > 2 else ""
		var is_selected: bool = role_name == current_role

		# PanelContainer auto-sizes to children (ColorRect does not).
		var rcard = PanelContainer.new()
		rcard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rcard_style = StyleBoxFlat.new()
		rcard_style.bg_color = Color(0.07, 0.22, 0.07, 1.0) if is_selected else Color(0.10, 0.10, 0.14, 1.0)
		rcard_style.content_margin_left   = 10.0
		rcard_style.content_margin_right  = 10.0
		rcard_style.content_margin_top    = 10.0
		rcard_style.content_margin_bottom = 10.0
		rcard.add_theme_stylebox_override("panel", rcard_style)

		var rvbox = VBoxContainer.new()
		rvbox.add_theme_constant_override("separation", 4)
		rcard.add_child(rvbox)

		var rtitle_row = HBoxContainer.new()
		rtitle_row.add_theme_constant_override("separation", 8)
		rvbox.add_child(rtitle_row)

		var rname_col: Color = Color(0.30, 0.69, 0.31) if is_selected else RimvaleColors.TEXT_WHITE
		var rname_lbl = RimvaleUtils.label(role_name, 15, rname_col)
		rname_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rtitle_row.add_child(rname_lbl)

		if is_selected:
			rtitle_row.add_child(RimvaleUtils.label("✓ Selected", 11, Color(0.30, 0.69, 0.31)))

		if not role_desc.is_empty():
			var rdesc = RimvaleUtils.label(role_desc, 11, RimvaleColors.TEXT_GRAY)
			rdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rvbox.add_child(rdesc)

		if not primary.is_empty():
			rvbox.add_child(RimvaleUtils.label("Primary: " + primary, 12, RimvaleColors.TEXT_LIGHT))
		if not secondary.is_empty():
			rvbox.add_child(RimvaleUtils.label("Secondary: " + secondary, 12, RimvaleColors.TEXT_LIGHT))

		var rn_cap: String = role_name
		rcard.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_e.set_societal_role(_handle, rn_cap)
				_refresh_header()
				_render_section()
		)
		rcard.mouse_filter = Control.MOUSE_FILTER_STOP

		parent.add_child(rcard)
		parent.add_child(RimvaleUtils.spacer(4))

# ── Section 5: Equipment ──────────────────────────────────────────────────────

func _build_equipment(parent: VBoxContainer) -> void:
	if _handle == -1:
		parent.add_child(RimvaleUtils.label("No hero selected.", 14, RimvaleColors.TEXT_DIM))
		return

	# Gold
	parent.add_child(RimvaleUtils.label("💰 Gold: %d GP" % GameState.gold, 16, RimvaleColors.GOLD))

	# Equipped slots row
	parent.add_child(RimvaleUtils.label("EQUIPPED", 12, RimvaleColors.TEXT_DIM))
	var slots_row = HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 8)
	parent.add_child(slots_row)

	var weapon: String = str(_e.get_equipped_weapon(_handle))
	var armor: String = str(_e.get_equipped_armor(_handle))
	var shield: String = str(_e.get_equipped_shield(_handle))

	var slot_data = [
		["⚔ Weapon", weapon, 0],
		["🛡 Armor", armor, 1],
		["🔰 Shield", shield, 2]
	]
	for sd in slot_data:
		var slot_label: String = sd[0]
		var item_name: String = sd[1]
		var slot_idx: int = sd[2]

		var slot_card = ColorRect.new()
		slot_card.color = Color(0.10, 0.14, 0.20, 1.0)
		slot_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_card.custom_minimum_size = Vector2(0, 64)

		var smgn = MarginContainer.new()
		smgn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for s in ["left", "right", "top", "bottom"]:
			smgn.add_theme_constant_override("margin_" + s, 8)
		slot_card.add_child(smgn)

		var svbox = VBoxContainer.new()
		svbox.add_theme_constant_override("separation", 3)
		smgn.add_child(svbox)

		svbox.add_child(RimvaleUtils.label(slot_label, 11, RimvaleColors.TEXT_DIM))
		var item_is_empty: bool = item_name.is_empty()
		svbox.add_child(RimvaleUtils.label(
			item_name if not item_is_empty else "None",
			12, RimvaleColors.TEXT_WHITE if not item_is_empty else RimvaleColors.TEXT_DIM))

		if not item_is_empty:
			var si_cap: int = slot_idx
			var unequip_btn = RimvaleUtils.button("✕ Unequip", RimvaleColors.DANGER, 26, 10)
			unequip_btn.pressed.connect(func(): _e.unequip_item(_handle, si_cap); _render_section())
			svbox.add_child(unequip_btn)

		slots_row.add_child(slot_card)

	parent.add_child(RimvaleUtils.separator())

	# Tab bar: Inventory / Stash
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 0)
	parent.add_child(tab_row)

	for ti in range(2):
		var tab_idx: int = ti
		var tab_label: String = "Inventory" if ti == 0 else "Stash"
		var is_active: bool = _inv_tab == ti
		var tbtn = RimvaleUtils.button(tab_label,
			RimvaleColors.ACCENT if is_active else RimvaleColors.TEXT_GRAY, 38, 13)
		tbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tbtn.pressed.connect(func(): _inv_tab = tab_idx; _render_section())
		tab_row.add_child(tbtn)

	# Category filter chips
	var filter_scroll = ScrollContainer.new()
	filter_scroll.custom_minimum_size = Vector2(0, 34)
	filter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(filter_scroll)

	var chip_row = HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 6)
	filter_scroll.add_child(chip_row)

	var active_filter: String = _inv_filter if _inv_tab == 0 else _stash_filter
	for cat in ["All", "Weapons", "Armor", "Magic", "Misc"]:
		var cat_name: String = cat
		var cc: Color = RimvaleColors.ACCENT if cat == active_filter else RimvaleColors.TEXT_GRAY
		var chip = RimvaleUtils.button(cat, cc, 30, 12)
		chip.pressed.connect(func():
			if _inv_tab == 0: _inv_filter = cat_name
			else: _stash_filter = cat_name
			_render_section()
		)
		chip_row.add_child(chip)

	# Items
	if _inv_tab == 0:
		_build_inventory_list(parent)
	else:
		_build_stash_list(parent)

func _build_inventory_list(parent: VBoxContainer) -> void:
	var items_raw = _e.get_inventory_items(_handle)
	if items_raw.size() == 0:
		parent.add_child(RimvaleUtils.label("Inventory is empty.", 13, RimvaleColors.TEXT_DIM))
		return

	for item_raw in items_raw:
		var item_name: String = str(item_raw)
		var details_raw = _e.get_item_details(_handle, item_name)
		var rarity: String = str(details_raw[0]) if details_raw.size() > 0 else "Mundane"
		var cur_hp: int = int(str(details_raw[1])) if details_raw.size() > 1 else 0
		var max_hp: int = int(str(details_raw[2])) if details_raw.size() > 2 else 0
		var item_type: String = str(details_raw[4]) if details_raw.size() > 4 else "General"
		var is_magical: bool = rarity != "Mundane"

		# Category filter
		var pass_filter: bool = _inv_filter == "All"
		match _inv_filter:
			"Weapons": pass_filter = item_type == "Weapon" and not is_magical
			"Armor":   pass_filter = (item_type == "Armor" or item_type == "Shield") and not is_magical
			"Magic":   pass_filter = is_magical
			"Misc":    pass_filter = item_type != "Weapon" and item_type != "Armor" and item_type != "Shield" and not is_magical

		if not pass_filter:
			continue

		var rarity_col: Color = _rarity_color(rarity)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 46)
		parent.add_child(row)

		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)

		var name_col: Color = rarity_col if is_magical else RimvaleColors.TEXT_WHITE
		var prefix: String = "✦ " if is_magical else ""
		info.add_child(RimvaleUtils.label(prefix + item_name, 14, name_col))
		info.add_child(RimvaleUtils.label("%s  Dur: %d/%d" % [item_type, cur_hp, max_hp], 10, RimvaleColors.TEXT_DIM))

		var in_cap: String = item_name
		if item_type == "Consumable":
			var use_btn = RimvaleUtils.button("Use", RimvaleColors.SUCCESS, 34, 12)
			use_btn.pressed.connect(func(): _e.use_consumable(_handle, in_cap); _render_section())
			row.add_child(use_btn)
		elif item_type != "General":
			var eq_btn = RimvaleUtils.button("Equip", RimvaleColors.ACCENT, 34, 12)
			eq_btn.pressed.connect(func(): _e.equip_item(_handle, in_cap); _render_section())
			row.add_child(eq_btn)

		var stash_btn = RimvaleUtils.button("Stash", RimvaleColors.TEXT_GRAY, 34, 12)
		stash_btn.pressed.connect(func():
			_e.remove_item_from_inventory(_handle, in_cap)
			if in_cap not in GameState.stash:
				GameState.stash.append(in_cap)
			_render_section()
		)
		row.add_child(stash_btn)

func _build_stash_list(parent: VBoxContainer) -> void:
	if GameState.stash.size() == 0:
		parent.add_child(RimvaleUtils.label("The stash is empty.", 13, RimvaleColors.TEXT_DIM))
		return

	for item_name in GameState.stash:
		var details_raw = _e.get_registry_item_details(item_name)
		var item_type: String = str(details_raw[4]) if details_raw.size() > 4 else "General"
		var rarity: String = str(details_raw[0]) if details_raw.size() > 0 else "Mundane"
		var is_magical: bool = rarity != "Mundane"

		var pass_filter: bool = _stash_filter == "All"
		match _stash_filter:
			"Weapons": pass_filter = item_type == "Weapon" and not is_magical
			"Armor":   pass_filter = (item_type == "Armor" or item_type == "Shield") and not is_magical
			"Magic":   pass_filter = is_magical
			"Misc":    pass_filter = item_type != "Weapon" and item_type != "Armor" and item_type != "Shield" and not is_magical

		if not pass_filter:
			continue

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 46)
		parent.add_child(row)

		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)
		info.add_child(RimvaleUtils.label(item_name, 14, RimvaleColors.TEXT_WHITE))
		info.add_child(RimvaleUtils.label(item_type, 10, RimvaleColors.TEXT_DIM))

		var in_cap: String = item_name
		var take_btn = RimvaleUtils.button("Take", RimvaleColors.SUCCESS, 34, 12)
		take_btn.pressed.connect(func():
			GameState.stash.erase(in_cap)
			_e.add_item_to_inventory(_handle, in_cap)
			_render_section()
		)
		row.add_child(take_btn)

# ── Section 6: Lineage ────────────────────────────────────────────────────────

func _build_lineage(parent: VBoxContainer) -> void:
	if _handle == -1:
		parent.add_child(RimvaleUtils.label("No hero selected.", 14, RimvaleColors.TEXT_DIM))
		return

	var lineage_: String = str(_e.get_character_lineage_name(_handle))
	var raw = _e.get_lineage_details(lineage_)

	var lin_type: String = str(raw[0]) if raw.size() > 0 else ""
	var lin_speed: int = int(str(raw[1])) if raw.size() > 1 else 0
	var lin_features_raw: String = str(raw[2]) if raw.size() > 2 else ""
	var lin_languages: String = str(raw[3]) if raw.size() > 3 else ""
	var lin_desc: String = str(raw[4]) if raw.size() > 4 else ""
	var lin_culture: String = str(raw[5]) if raw.size() > 5 else ""
	var lin_features: PackedStringArray = lin_features_raw.split("||", false)

	# Portrait
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(80, 80)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var _lu_p := RimvaleUtils.get_sprite_portrait(lineage_)
	if _lu_p != null: portrait.texture = _lu_p
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(portrait)

	parent.add_child(RimvaleUtils.label(lineage_, 22, RimvaleColors.ACCENT))

	# Type + Speed badges row
	if not lin_type.is_empty() or lin_speed > 0:
		var badges_row = HBoxContainer.new()
		badges_row.add_theme_constant_override("separation", 8)
		parent.add_child(badges_row)
		if not lin_type.is_empty():
			badges_row.add_child(_make_badge(lin_type, RimvaleColors.ACCENT))
		if lin_speed > 0:
			badges_row.add_child(_make_badge("Speed %d ft" % lin_speed, Color(0.13, 0.59, 0.95)))

	parent.add_child(RimvaleUtils.separator())

	# Description
	if not lin_desc.is_empty():
		var desc_lbl = RimvaleUtils.label(lin_desc, 13, RimvaleColors.TEXT_LIGHT)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(desc_lbl)

	# Culture
	if not lin_culture.is_empty():
		parent.add_child(RimvaleUtils.separator())
		parent.add_child(RimvaleUtils.label("Culture", 14, RimvaleColors.ACCENT))
		var cult_lbl = RimvaleUtils.label(lin_culture, 13, RimvaleColors.TEXT_LIGHT)
		cult_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(cult_lbl)

	# Languages
	if not lin_languages.is_empty():
		parent.add_child(RimvaleUtils.separator())
		parent.add_child(RimvaleUtils.label("Languages", 14, RimvaleColors.ACCENT))
		parent.add_child(RimvaleUtils.label(lin_languages, 13, RimvaleColors.TEXT_LIGHT))

	# Features
	if lin_features.size() > 0:
		parent.add_child(RimvaleUtils.separator())
		parent.add_child(RimvaleUtils.label("Lineage Features", 14, RimvaleColors.ACCENT))
		for feature in lin_features:
			var feature_str: String = str(feature).strip_edges()
			if feature_str.is_empty():
				continue
			var fcard = ColorRect.new()
			fcard.color = Color(0.10, 0.10, 0.16, 1.0)
			fcard.custom_minimum_size = Vector2(0, 0)
			var fmgn = MarginContainer.new()
			fmgn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			for s in ["left", "right", "top", "bottom"]:
				fmgn.add_theme_constant_override("margin_" + s, 8)
			fcard.add_child(fmgn)
			var flbl = RimvaleUtils.label(feature_str, 12, RimvaleColors.TEXT_LIGHT)
			flbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			fmgn.add_child(flbl)
			parent.add_child(fcard)
			parent.add_child(RimvaleUtils.spacer(2))

# ── Rename Dialog ─────────────────────────────────────────────────────────────

func _show_rename_dialog() -> void:
	if _handle == -1:
		return
	var dialog = ConfirmationDialog.new()
	dialog.title = "Rename Agent"
	dialog.get_ok_button().text = "Rename"
	dialog.get_cancel_button().text = "Cancel"

	var name_edit = LineEdit.new()
	name_edit.text = str(_e.get_character_name(_handle))
	name_edit.placeholder_text = "Enter name..."
	name_edit.custom_minimum_size = Vector2(280, 36)
	dialog.add_child(name_edit)

	dialog.confirmed.connect(func():
		var new_name: String = name_edit.text.strip_edges()
		if not new_name.is_empty():
			_e.set_character_name(_handle, new_name)
			_refresh_header()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2(320, 140))

# ── Helpers ───────────────────────────────────────────────────────────────────

func _get_alignment() -> String:
	if _handle == -1:
		return ""
	var checks = [
		["Unity Scholar Initiate", "Unity"],
		["Unity Pact Initiate", "Unity"],
		["Chaos Initiate", "Chaos"],
		["Chaos Pact Initiate", "Chaos"],
		["Void Initiate", "The Void"],
		["Void Pact Initiate", "The Void"]
	]
	for check in checks:
		if _e.get_character_feat_tier(_handle, check[0]) > 0:
			return check[1]
	return ""

func _get_domain() -> String:
	if _handle == -1:
		return ""
	for i in range(DOMAIN_FEAT_NAMES.size()):
		if _e.get_character_feat_tier(_handle, DOMAIN_FEAT_NAMES[i]) > 0:
			return DOMAIN_NAMES[i]
	return ""

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"Common":    return Color(0.30, 0.69, 0.31)
		"Uncommon":  return Color(0.13, 0.59, 0.95)
		"Rare":      return Color(0.61, 0.15, 0.69)
		"Very Rare": return Color(1.0, 0.60, 0.0)
		"Legendary": return Color(0.96, 0.26, 0.21)
		"Apex":      return Color(1.0, 0.92, 0.23)
	return RimvaleColors.TEXT_DIM

func _make_badge(text: String, col: Color) -> Control:
	var bg = ColorRect.new()
	bg.color = Color(col, 0.2)
	bg.custom_minimum_size = Vector2(0, 26)
	var mgn = MarginContainer.new()
	mgn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		mgn.add_theme_constant_override("margin_" + s, 4)
	bg.add_child(mgn)
	mgn.add_child(RimvaleUtils.label(text, 11, col))
	return bg
