## character_creation.gd
## 6-step character creation wizard — mirrors CharacterCreationScreen.kt

extends Control

var _e

# Wizard state
var _step: int = 0
const TOTAL_STEPS = 6
var _step_titles = [
	"Personal Details",
	"Societal Role",
	"Distribute Stat Points",
	"Assign Skill Points",
	"Select Starting Feats",
	"Hero Confirmed!"
]

# Character data being built
var _char_name: String = ""
var _lineage: String = ""
var _age: int = 25
var _alignment: String = "Unity"
var _domain: String = "Physical"
var _selected_roles: Array = []
var _stat_pending: Dictionary = {"STR":0,"SPD":0,"INT":0,"VIT":0,"DIV":0}
var _stat_points_remaining: int = 6   # PHB: 6 stat points at level 1
var _skill_points_remaining: int = 12  # PHB: 12 skill points at level 1
var _selected_feats: Array = []
const MAX_STARTING_FEATS = 4

# Data from engine
var _all_lineages: PackedStringArray
var _all_roles: PackedStringArray
var _all_feats: Array = []  # flat list of feat names
var _all_feat_categories: PackedStringArray

# UI references
var _content_area: Control
var _step_label: Label
var _progress_bar: Control
var _next_btn: Button
var _back_btn: Button
var _status_lbl: Label

# ── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_e = RimvaleAPI.engine
	_all_lineages = _e.get_all_lineages()
	_all_roles = _e.get_all_societal_roles()
	_all_feat_categories = _e.get_all_feat_categories()
	# Build flat feat list from all categories
	for cat in _all_feat_categories:
		var trees = _e.get_feat_trees_by_category(cat)
		for tree in trees:
			var feats = _e.get_feats_by_tree(tree)
			for feat in feats:
				if feat not in _all_feats:
					_all_feats.append(feat)
	if _all_lineages.size() > 0:
		_lineage = _all_lineages[0]

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RimvaleUtils.add_bg(self, RimvaleColors.BG_DARK)

	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Header
	root.add_child(_build_header())

	# Step content (scrollable)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_content_area = VBoxContainer.new()
	_content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_area.add_theme_constant_override("separation", 16)
	scroll.add_child(_content_area)

	# Footer nav
	root.add_child(_build_footer())

	_render_step()

# ── Header ────────────────────────────────────────────────────────────────────

func _build_header() -> Control:
	var hdr = ColorRect.new()
	hdr.color = RimvaleColors.BG_CARD
	hdr.custom_minimum_size = Vector2(0, 70)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + s, 14)
	hdr.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var title = RimvaleUtils.label("Create Hero", 22, RimvaleColors.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	_step_label = RimvaleUtils.label("Step 1 / 6", 14, RimvaleColors.TEXT_GRAY)
	row.add_child(_step_label)

	# Progress dots
	_progress_bar = HBoxContainer.new()
	_progress_bar.add_theme_constant_override("separation", 8)
	vbox.add_child(_progress_bar)

	return hdr

func _refresh_header() -> void:
	_step_label.text = "Step %d / %d  —  %s" % [_step + 1, TOTAL_STEPS, _step_titles[_step]]
	for i in range(_progress_bar.get_child_count()):
		var dot: ColorRect = _progress_bar.get_child(i)
		dot.color = RimvaleColors.ACCENT if i <= _step else RimvaleColors.TEXT_DIM

# ── Footer ────────────────────────────────────────────────────────────────────

func _build_footer() -> Control:
	var bg = ColorRect.new()
	bg.color = RimvaleColors.BG_CARD
	bg.custom_minimum_size = Vector2(0, 70)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + s, 12)
	bg.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	_status_lbl = RimvaleUtils.label("", 13, RimvaleColors.DANGER)
	_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(_status_lbl)

	_back_btn = RimvaleUtils.button("← Back", RimvaleColors.TEXT_GRAY, 46, 16)
	_back_btn.pressed.connect(_on_back)
	hbox.add_child(_back_btn)

	_next_btn = RimvaleUtils.button("Next Step →", RimvaleColors.ACCENT, 46, 16)
	_next_btn.custom_minimum_size = Vector2(160, 46)
	_next_btn.pressed.connect(_on_next)
	hbox.add_child(_next_btn)

	return bg

# ── Step rendering ────────────────────────────────────────────────────────────

func _render_step() -> void:
	for child in _content_area.get_children():
		child.queue_free()
	for child in _progress_bar.get_children():
		child.queue_free()

	# Rebuild progress dots
	for i in range(TOTAL_STEPS):
		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(28, 6)
		dot.color = RimvaleColors.ACCENT if i <= _step else RimvaleColors.TEXT_DIM
		_progress_bar.add_child(dot)

	_refresh_header()
	_status_lbl.text = ""

	match _step:
		0: _build_step0()
		1: _build_step1()
		2: _build_step2()
		3: _build_step3()
		4: _build_step4()
		5: _build_step5()

	# Adjust buttons
	_back_btn.text = "← Back" if _step > 0 else "✕ Cancel"
	_next_btn.text = "Begin Adventure! ✦" if _step == TOTAL_STEPS - 1 else "Next Step →"

# ── Step 0: Personal Details ──────────────────────────────────────────────────

func _build_step0() -> void:
	var margin = _margin_wrap(_content_area)

	_section_label(margin, "CHARACTER NAME")
	var name_edit = LineEdit.new()
	name_edit.placeholder_text = "Enter a name..."
	name_edit.text = _char_name
	name_edit.custom_minimum_size = Vector2(0, 52)
	name_edit.add_theme_font_size_override("font_size", 20)
	name_edit.text_changed.connect(func(t): _char_name = t)
	margin.add_child(name_edit)

	_section_label(margin, "LINEAGE  (%d available)" % _all_lineages.size())
	var lineage_row = HBoxContainer.new()
	lineage_row.add_theme_constant_override("separation", 14)
	margin.add_child(lineage_row)

	# Portrait
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(80, 80)
	var _cc_p1 := RimvaleUtils.get_sprite_portrait(_lineage)
	if _cc_p1 != null: portrait.texture = _cc_p1
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lineage_row.add_child(portrait)

	var lin_col = VBoxContainer.new()
	lin_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lin_col.add_theme_constant_override("separation", 8)
	lineage_row.add_child(lin_col)

	var lin_opt = OptionButton.new()
	lin_opt.custom_minimum_size = Vector2(0, 48)
	lin_opt.add_theme_font_size_override("font_size", 17)
	# Group lineages by region if the engine exposes that registry (new API).
	# Falls back to flat list if get_all_lineage_regions is missing.
	var used_grouped: bool = false
	if _e.has_method("get_all_lineage_regions"):
		var regions: PackedStringArray = _e.get_all_lineage_regions()
		if regions.size() > 0:
			used_grouped = true
			var item_idx: int = 0
			for region_name in regions:
				var region_lins: PackedStringArray = _e.get_lineages_for_region(region_name)
				if region_lins.is_empty(): continue
				# Non-selectable separator showing region header
				lin_opt.add_separator(region_name)
				item_idx += 1
				for lin in region_lins:
					lin_opt.add_item(lin)
					if lin == _lineage:
						lin_opt.select(item_idx)
					item_idx += 1
	if not used_grouped:
		for lin in _all_lineages:
			lin_opt.add_item(lin)
		for i in range(_all_lineages.size()):
			if _all_lineages[i] == _lineage:
				lin_opt.select(i)
				break
	lin_col.add_child(lin_opt)

	var lin_desc = RichTextLabel.new()
	lin_desc.custom_minimum_size = Vector2(0, 70)
	lin_desc.bbcode_enabled = true
	lin_desc.scroll_active = false
	lin_desc.add_theme_font_size_override("normal_font_size", 13)
	lin_desc.add_theme_color_override("default_color", RimvaleColors.TEXT_GRAY)
	lin_col.add_child(lin_desc)
	_update_lineage_desc(lin_desc)

	lin_opt.item_selected.connect(func(idx):
		# With region-grouped separators in the list, idx may land on a non-
		# selectable header. Read the actual text from the item and skip
		# empty/separator entries.
		var sel_txt: String = lin_opt.get_item_text(idx)
		if sel_txt.is_empty():
			return
		_lineage = sel_txt
		var _cc_p2 := RimvaleUtils.get_sprite_portrait(_lineage)
		if _cc_p2 != null: portrait.texture = _cc_p2
		_update_lineage_desc(lin_desc)
	)

	_section_label(margin, "AGE  (affects starting gold and societal roles)")
	var age_row = HBoxContainer.new()
	age_row.add_theme_constant_override("separation", 12)
	margin.add_child(age_row)

	var age_lbl = RimvaleUtils.label(str(_age), 20, RimvaleColors.ACCENT)
	age_row.add_child(age_lbl)

	var age_slider = HSlider.new()
	age_slider.min_value = 18
	age_slider.max_value = 200
	age_slider.value = _age
	age_slider.step = 1
	age_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	age_row.add_child(age_slider)

	var gold_lbl = RimvaleUtils.label("Starting Gold: ~%d" % (_age * 10), 14, RimvaleColors.GOLD)
	margin.add_child(gold_lbl)
	var roles_lbl = RimvaleUtils.label("Max Societal Roles: %d" % _max_roles(), 14, RimvaleColors.TEXT_GRAY)
	margin.add_child(roles_lbl)

	age_slider.value_changed.connect(func(v):
		_age = int(v)
		age_lbl.text = str(_age)
		gold_lbl.text = "Starting Gold: ~%d" % (_age * 10)
		roles_lbl.text = "Max Societal Roles: %d" % _max_roles()
	)

	_section_label(margin, "ALIGNMENT AFFINITY")
	var align_row = HBoxContainer.new()
	align_row.add_theme_constant_override("separation", 10)
	margin.add_child(align_row)
	for a in ["Unity", "Chaos", "The Void"]:
		var btn = _toggle_btn(a, _alignment == a)
		btn.pressed.connect(func():
			_alignment = a
			_render_step()  # re-render to update toggles
		)
		align_row.add_child(btn)

	_section_label(margin, "DOMAIN AFFINITY")
	var domain_row = HBoxContainer.new()
	domain_row.add_theme_constant_override("separation", 10)
	margin.add_child(domain_row)
	for d in ["Biological", "Chemical", "Physical", "Spiritual"]:
		var btn = _toggle_btn(d, _domain == d)
		btn.pressed.connect(func():
			_domain = d
			_render_step()
		)
		domain_row.add_child(btn)

func _update_lineage_desc(lbl: RichTextLabel) -> void:
	if not is_instance_valid(lbl):
		return
	var raw = _e.get_lineage_details(_lineage)
	var desc = ""
	if raw is PackedStringArray:
		desc = "\n".join(Array(raw))
	elif raw is String:
		desc = raw
	lbl.text = desc if not desc.is_empty() else "[i]No description.[/i]"

func _max_roles() -> int:
	return 1 + int((_age - 20) / 10)

# ── Step 1: Societal Role ─────────────────────────────────────────────────────

func _build_step1() -> void:
	var margin = _margin_wrap(_content_area)
	margin.add_child(RimvaleUtils.label(
		"For every 10 years over 20, you may pick an additional role.", 14, RimvaleColors.TEXT_GRAY))
	margin.add_child(RimvaleUtils.label(
		"Selected: %d / %d" % [_selected_roles.size(), _max_roles()], 15, RimvaleColors.ACCENT))
	margin.add_child(RimvaleUtils.separator())

	for role_name in _all_roles:
		var is_sel = role_name in _selected_roles
		var card = Button.new()
		card.text = ""
		card.flat = true
		card.custom_minimum_size = Vector2(0, 70)

		var cbg = ColorRect.new()
		cbg.color = Color(RimvaleColors.ACCENT, 0.15) if is_sel else RimvaleColors.BG_CARD_DARK
		cbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cbg)

		var cmgn = MarginContainer.new()
		cmgn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for s in ["left","right","top","bottom"]:
			cmgn.add_theme_constant_override("margin_" + s, 10)
		cmgn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cmgn)

		var cvbox = VBoxContainer.new()
		cvbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cmgn.add_child(cvbox)

		var rrow = HBoxContainer.new()
		rrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cvbox.add_child(rrow)

		var check = RimvaleUtils.label("✓ " if is_sel else "  ", 16, RimvaleColors.ACCENT)
		rrow.add_child(check)
		rrow.add_child(RimvaleUtils.label(role_name, 16, RimvaleColors.TEXT_WHITE))

		var details = _e.get_societal_role_details(role_name)
		var details_str = ""
		if details is PackedStringArray and details.size() > 0:
			details_str = details[0]
		elif details is String:
			details_str = details
		if not details_str.is_empty():
			cvbox.add_child(RimvaleUtils.label(details_str, 13, RimvaleColors.TEXT_GRAY))

		# Surface the +1d4 skill bonus pair so the player knows which skills
		# this role empowers mechanically (engine applies it inside roll_skill_check).
		var role_skills: PackedInt32Array = _e.get_role_skills(role_name)
		if role_skills.size() == 2 and role_skills[0] >= 0 and role_skills[1] >= 0:
			var sk1: String = SKILL_NAMES[role_skills[0]] if role_skills[0] < SKILL_NAMES.size() else "?"
			var sk2: String = SKILL_NAMES[role_skills[1]] if role_skills[1] < SKILL_NAMES.size() else "?"
			var bonus_lbl = RimvaleUtils.label(
				"Skill bonus: +1d4 to %s & %s" % [sk1, sk2], 11, RimvaleColors.ACCENT)
			cvbox.add_child(bonus_lbl)

		card.pressed.connect(func():
			if role_name in _selected_roles:
				_selected_roles.erase(role_name)
			elif _selected_roles.size() < _max_roles():
				_selected_roles.append(role_name)
			_render_step()
		)
		margin.add_child(card)

# ── Step 2: Stats ─────────────────────────────────────────────────────────────

var _stat_labels: Dictionary = {}

func _build_step2() -> void:
	var margin = _margin_wrap(_content_area)
	var pts_lbl = RimvaleUtils.label("Points Remaining: %d" % _stat_points_remaining,
		18, RimvaleColors.ACCENT if _stat_points_remaining > 0 else RimvaleColors.DANGER)
	margin.add_child(pts_lbl)
	margin.add_child(RimvaleUtils.label("(1pt per rank 1-4, 2pts per rank 5+, max 10)", 13, RimvaleColors.TEXT_GRAY))
	margin.add_child(RimvaleUtils.separator())

	var stats = [
		["STR", "Strength", "AP & Physical Power"],
		["SPD", "Speed", "AC & Initiative"],
		["INT", "Intellect", "Skills & Reasoning"],
		["VIT", "Vitality", "Health & Life Force"],
		["DIV", "Divinity", "Spark & Magic Power"],
	]
	for stat_data in stats:
		margin.add_child(_build_stat_row(stat_data[0], stat_data[1], stat_data[2], pts_lbl))

func _build_stat_row(key: String, name_: String, desc: String, pts_lbl: Label) -> Control:
	var val: int = _stat_pending.get(key, 0)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 52)

	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(RimvaleUtils.label(name_, 16, RimvaleColors.TEXT_WHITE))
	info.add_child(RimvaleUtils.label(desc, 12, RimvaleColors.TEXT_GRAY))

	var minus_btn = RimvaleUtils.button("−", RimvaleColors.DANGER, 40, 20)
	minus_btn.custom_minimum_size = Vector2(40, 40)
	row.add_child(minus_btn)

	var val_lbl = RimvaleUtils.label(str(val), 18, RimvaleColors.ACCENT)
	val_lbl.custom_minimum_size = Vector2(30, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(val_lbl)

	var plus_btn = RimvaleUtils.button("+", RimvaleColors.SUCCESS, 40, 20)
	plus_btn.custom_minimum_size = Vector2(40, 40)
	row.add_child(plus_btn)

	plus_btn.pressed.connect(func():
		var cost = 2 if _stat_pending.get(key, 0) >= 4 else 1
		if _stat_points_remaining >= cost and _stat_pending.get(key, 0) < 10:
			_stat_pending[key] = _stat_pending.get(key, 0) + 1
			_stat_points_remaining -= cost
			val_lbl.text = str(_stat_pending[key])
			pts_lbl.text = "Points Remaining: %d" % _stat_points_remaining
	)
	minus_btn.pressed.connect(func():
		if _stat_pending.get(key, 0) > 0:
			var refund = 2 if _stat_pending.get(key, 0) > 4 else 1
			_stat_pending[key] = _stat_pending.get(key, 0) - 1
			_stat_points_remaining += refund
			val_lbl.text = str(_stat_pending[key])
			pts_lbl.text = "Points Remaining: %d" % _stat_points_remaining
	)

	return row

# ── Step 3: Skills ────────────────────────────────────────────────────────────

## Rimvale PHB skill names (matches rimvale_fallback_engine.gd index order)
const SKILL_NAMES: Array = [
	"Arcane", "Crafting", "Creature Handling", "Cunning",
	"Exertion", "Intuition", "Learnedness", "Medical",
	"Nimble", "Perception", "Perform", "Sneak",
	"Speechcraft", "Survival"
]
const STAT_ABBREVS: PackedStringArray = ["STR", "SPD", "INT", "VIT", "DIV"]
const SKILL_STAT: PackedInt32Array = [
	4, 2, 0, 1, 0,   # Arcane(DIV), Crafting(INT), CreatureHandling(STR), Cunning(SPD), Exertion(STR)
	4, 2, 2, 1, 3,   # Intuition(DIV), Learnedness(INT), Medical(INT), Nimble(SPD), Perception(VIT)
	4, 1, 4, 3        # Perform(DIV), Sneak(SPD), Speechcraft(DIV), Survival(VIT)
]

## Skill ranks selected so far during creation (index → rank 0-10)
var _skill_ranks: Array = [0,0,0,0,0,0,0,0,0,0,0,0,0,0]

func _skill_pt_cost(current_rank: int) -> int:
	# Ranks 1-5 cost 1pt; ranks 6-10 cost 2pts each
	return 1 if current_rank < 5 else 2

func _build_step3() -> void:
	var margin = _margin_wrap(_content_area)

	# Points remaining header — rebuilt every time
	var pts_lbl = RimvaleUtils.label("Skill Points Remaining: %d / 12" % _skill_points_remaining,
		18, RimvaleColors.ACCENT if _skill_points_remaining > 0 else RimvaleColors.DANGER)
	margin.add_child(pts_lbl)
	margin.add_child(RimvaleUtils.label(
		"12 starting points  ·  Ranks 1–5 cost 1 pt  ·  Ranks 6–10 cost 2 pts  ·  Cap 5 at creation",
		11, RimvaleColors.TEXT_GRAY))
	margin.add_child(RimvaleUtils.separator())

	for i in range(SKILL_NAMES.size()):
		var si: int = i   # capture
		var rank: int = _skill_ranks[i]

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var stat_tag: String = STAT_ABBREVS[SKILL_STAT[i]]
		var name_lbl = RimvaleUtils.label("%s (%s)" % [SKILL_NAMES[i], stat_tag], 13, RimvaleColors.TEXT_WHITE)
		name_lbl.custom_minimum_size = Vector2(170, 0)
		row.add_child(name_lbl)

		# Minus button
		var minus_btn = RimvaleUtils.button("–", RimvaleColors.DANGER, 32, 14)
		minus_btn.disabled = rank == 0
		minus_btn.pressed.connect(func():
			if _skill_ranks[si] > 0:
				var refund: int = _skill_pt_cost(_skill_ranks[si] - 1)
				_skill_ranks[si] -= 1
				_skill_points_remaining += refund
				_render_step()
		)
		row.add_child(minus_btn)

		# Rank display
		var rank_lbl = RimvaleUtils.label(str(rank), 15,
			RimvaleColors.ACCENT if rank > 0 else RimvaleColors.TEXT_DIM)
		rank_lbl.custom_minimum_size = Vector2(24, 0)
		rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(rank_lbl)

		# Plus button
		var cost: int = _skill_pt_cost(rank)
		var plus_btn = RimvaleUtils.button("+", RimvaleColors.SUCCESS, 32, 14)
		# PHB: creation rank cap is 5; higher ranks require leveling up
		plus_btn.disabled = (_skill_points_remaining < cost) or (rank >= 5)
		plus_btn.pressed.connect(func():
			var c: int = _skill_pt_cost(_skill_ranks[si])
			if _skill_points_remaining >= c and _skill_ranks[si] < 5:
				_skill_ranks[si] += 1
				_skill_points_remaining -= c
				_render_step()
		)
		row.add_child(plus_btn)

		# Cost hint
		row.add_child(RimvaleUtils.label("(%d pt)" % cost, 10, RimvaleColors.TEXT_DIM))

		margin.add_child(row)

# ── Step 4: Feats ─────────────────────────────────────────────────────────────

func _build_step4() -> void:
	var margin = _margin_wrap(_content_area)
	margin.add_child(RimvaleUtils.label("Select %d Starting Feats" % MAX_STARTING_FEATS, 18, RimvaleColors.ACCENT))
	margin.add_child(RimvaleUtils.label("Selected: %d / %d" % [_selected_feats.size(), MAX_STARTING_FEATS], 15,
		RimvaleColors.SUCCESS if _selected_feats.size() == MAX_STARTING_FEATS else RimvaleColors.TEXT_GRAY))
	margin.add_child(RimvaleUtils.separator())

	var display_feats = _all_feats.slice(0, mini(80, _all_feats.size()))
	for feat_name in display_feats:
		var is_sel: bool = feat_name in _selected_feats
		var card = Button.new()
		card.flat = true
		card.custom_minimum_size = Vector2(0, 56)

		var fbg = ColorRect.new()
		fbg.color = Color(RimvaleColors.ACCENT, 0.15) if is_sel else RimvaleColors.BG_CARD_DARK
		fbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(fbg)

		var fmgn = MarginContainer.new()
		fmgn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for s in ["left","right","top","bottom"]:
			fmgn.add_theme_constant_override("margin_" + s, 8)
		fmgn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(fmgn)

		var fhbox = HBoxContainer.new()
		fhbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fmgn.add_child(fhbox)

		fhbox.add_child(RimvaleUtils.label("✓ " if is_sel else "  ", 15, RimvaleColors.ACCENT))
		var fvbox = VBoxContainer.new()
		fvbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fhbox.add_child(fvbox)
		fvbox.add_child(RimvaleUtils.label(feat_name, 15, RimvaleColors.TEXT_WHITE))
		var fdesc = _e.get_feat_description(feat_name, 1)
		if fdesc and not fdesc.is_empty():
			fvbox.add_child(RimvaleUtils.label(fdesc.substr(0, 80) + ("…" if fdesc.length() > 80 else ""),
				12, RimvaleColors.TEXT_GRAY))

		card.pressed.connect(func():
			if feat_name in _selected_feats:
				_selected_feats.erase(feat_name)
			elif _selected_feats.size() < MAX_STARTING_FEATS:
				_selected_feats.append(feat_name)
			_render_step()
		)
		margin.add_child(card)

# ── Step 5: Finalize ──────────────────────────────────────────────────────────

func _build_step5() -> void:
	var margin = _margin_wrap(_content_area)

	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(100, 100)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var _cc_p3 := RimvaleUtils.get_sprite_portrait(_lineage)
	if _cc_p3 != null: portrait.texture = _cc_p3
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	margin.add_child(portrait)

	margin.add_child(RimvaleUtils.label(_char_name if not _char_name.is_empty() else "Unnamed Hero",
		28, RimvaleColors.GOLD))
	margin.add_child(RimvaleUtils.label(_lineage + "  •  Age " + str(_age), 16, RimvaleColors.ACCENT))
	margin.add_child(RimvaleUtils.label("Alignment: %s  |  Domain: %s" % [_alignment, _domain],
		14, RimvaleColors.TEXT_GRAY))

	if not _selected_roles.is_empty():
		margin.add_child(RimvaleUtils.label("Roles: " + ", ".join(_selected_roles), 14, RimvaleColors.TEXT_GRAY))

	margin.add_child(RimvaleUtils.separator())
	margin.add_child(RimvaleUtils.label("STARTING STATS", 14, RimvaleColors.TEXT_DIM))

	var stats_grid = GridContainer.new()
	stats_grid.columns = 5
	stats_grid.add_theme_constant_override("h_separation", 24)
	margin.add_child(stats_grid)
	for key in ["STR","SPD","INT","VIT","DIV"]:
		var vb = VBoxContainer.new()
		vb.add_child(RimvaleUtils.label(key, 12, RimvaleColors.TEXT_DIM))
		vb.add_child(RimvaleUtils.label(str(_stat_pending.get(key, 0)), 20, RimvaleColors.ACCENT))
		stats_grid.add_child(vb)

	margin.add_child(RimvaleUtils.separator())
	margin.add_child(RimvaleUtils.label("STARTING FEATS", 14, RimvaleColors.TEXT_DIM))
	for f in _selected_feats:
		margin.add_child(RimvaleUtils.label("• " + f, 14, RimvaleColors.TEXT_LIGHT))

	margin.add_child(RimvaleUtils.label("+ Bonus Domain Feat (%s)" % _domain, 13, RimvaleColors.ACCENT))
	margin.add_child(RimvaleUtils.label("+ Bonus Alignment Feat (%s)" % _alignment, 13, RimvaleColors.ACCENT))

	margin.add_child(RimvaleUtils.separator())
	margin.add_child(RimvaleUtils.label(
		"Adventure awaits in the fractured world of Rimvale!", 14, RimvaleColors.TEXT_GRAY))

# ── Navigation ────────────────────────────────────────────────────────────────

func _on_next() -> void:
	_status_lbl.text = ""
	if _step == TOTAL_STEPS - 1:
		_finalize()
		return
	# Validation per step
	match _step:
		0:
			if _char_name.strip_edges().is_empty():
				_status_lbl.text = "Please enter a character name."
				return
	_step = mini(_step + 1, TOTAL_STEPS - 1)
	_render_step()

func _on_back() -> void:
	if _step == 0:
		# Cancel — go back to main
		var main = get_tree().root.get_child(0)
		if main and main.has_method("pop_screen"):
			main.pop_screen()
		return
	_step = maxi(_step - 1, 0)
	_render_step()

func _finalize() -> void:
	var final_name = _char_name.strip_edges()
	if final_name.is_empty():
		final_name = "Agent-%04d" % randi_range(1, 9999)

	var handle = _e.create_character(final_name, _lineage, _age)
	if handle == 0:
		_status_lbl.text = "Failed to create character."
		return

	# Store alignment + domain, apply chosen stats, recalculate derived values
	var cd = _e.get_char_dict(handle)
	if cd != null:
		cd["alignment"] = _alignment
		cd["domain"]    = _domain

		# Apply chosen stat points matching level_up.gd order: STR=0, SPD=1, INT=2, VIT=3, DIV=4
		var stat_keys = ["STR", "SPD", "INT", "VIT", "DIV"]
		var stats_arr: Array = [0, 0, 0, 0, 0]
		for ki in range(stat_keys.size()):
			stats_arr[ki] = _stat_pending.get(stat_keys[ki], 0)
		cd["stats"] = stats_arr

		# Apply PHB formulas: HP = 3 + 3*lvl + VIT; AP = 3 + STR; SP = 3 + lvl + DIV
		var lv: int  = cd.get("level", 1)
		var str_v: int = stats_arr[0]   # index 0 = Strength
		var vit_v: int = stats_arr[3]   # index 3 = Vitality
		var div_v: int = stats_arr[4]   # index 4 = Divinity
		var new_hp: int = maxi(1, 3 + 3 * lv + vit_v)
		var new_ap: int = maxi(1, 3 + str_v)
		var new_sp: int = maxi(1, 3 + lv + div_v)
		cd["hp"] = new_hp;  cd["max_hp"] = new_hp
		cd["ap"] = new_ap;  cd["max_ap"] = new_ap
		cd["sp"] = new_sp;  cd["max_sp"] = new_sp

		# Apply starting skill ranks chosen in step 3
		var skills_arr: Array = cd.get("skills", [0,0,0,0,0,0,0,0,0,0,0,0,0,0])
		for si in range(mini(_skill_ranks.size(), skills_arr.size())):
			skills_arr[si] = maxi(skills_arr[si], _skill_ranks[si])
		cd["skills"] = skills_arr

	# Apply chosen societal role — first selected role drives the +1d4 skill bonus.
	# (The engine tracks one role slot; extra roles selected are recorded but
	# currently only the first role's skill bonus is applied.)
	if not _selected_roles.is_empty():
		_e.set_societal_role(handle, _selected_roles[0])

	# Apply starting feats
	for feat in _selected_feats:
		_e.spend_feat_point(handle, feat, 1)

	# Apply starting gold — PHB: 30 + (age - 20) * 5 gold
	# Example from PHB: age 34 → 30 + 70 = 100 gold
	var starting_gold: int = 30 + maxi(0, _age - 20) * 5
	_e.add_gold(handle, starting_gold)

	GameState.add_to_collection(handle)

	# Go to team tab
	var main = get_tree().root.get_child(0)
	if main and main.has_method("go_to_tab"):
		main.go_to_tab(0)  # Units tab

# ── Helpers ───────────────────────────────────────────────────────────────────

func _margin_wrap(parent: Node) -> VBoxContainer:
	var margin = MarginContainer.new()
	for s in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + s, 20)
	parent.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	return vbox

func _section_label(parent: Node, txt: String) -> void:
	var lbl = RimvaleUtils.label(txt, 13, RimvaleColors.TEXT_DIM)
	parent.add_child(lbl)

func _toggle_btn(txt: String, active: bool) -> Button:
	var btn = RimvaleUtils.button(txt,
		RimvaleColors.ACCENT if active else RimvaleColors.TEXT_GRAY, 40, 14)
	if active:
		btn.add_theme_color_override("font_color", RimvaleColors.BG_DARK)
	return btn
