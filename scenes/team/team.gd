## team.gd — Strike Team / Unit Management
## Faithful PC port of TeamManagementScreen.kt + UnitDetailScreen.kt
##
## Features:
##   Director Victor Sorn card | tokens | remnant fragments | trade
##   Strike Team tab: 5 slots, rest menu, sort, summon, full hero card list
##   Player Stash tab: global item stash
##   Fusion mode: select target → select sacrifices → confirm
##   Click Details → Unit Detail screen (level-up / attributes / skills / feats)

extends Control

var _e: RimvaleEngine

# ── Stored UI references ──────────────────────────────────────────────────────
var _director_tokens_lbl:  Label
var _director_rf_lbl:      Label
var _director_msg_lbl:     Label
var _team_slots_row:       HBoxContainer
var _rest_btn:             Button
var _sort_btn:             Button
var _collection_list:      VBoxContainer
var _fusion_bar:           Control
var _fusion_bar_lbl:       Label
var _stash_list:           VBoxContainer
var _content_team:         Control
var _content_stash:        Control
var _tab_team_btn:         Button
var _tab_stash_btn:        Button
var _slot_overlay:         Control

# ── State ────────────────────────────────────────────────────────────────────
var _current_tab:       int    = 0
var _sort_order:        String = "oldest"
var _fusion_mode:       bool   = false
var _fusion_target:     int    = -1
var _fusion_sacrifices: Array  = []
var _pending_slot:      int    = -1

# ── Name pool (from mobile TeamManagementViewModel) ──────────────────────────
const SUMMON_NAMES: PackedStringArray = [
	"Aelarion","Aethric","Alvaris","Ambrion","Arveth","Arkonis","Aseron","Avaric",
	"Belric","Belvorn","Beryn","Braelor","Braxen","Caelric","Caelum","Calverin",
	"Cendros","Ceryn","Corveth","Cyridon","Damaris","Darveth","Delvar","Denric",
	"Deryn","Dravenor","Drystan","Elarion","Elricon","Elvorn","Endric","Eryndor",
	"Fendrel","Ferion","Ferris","Feryn","Galverin","Galric","Gendros","Geryn",
	"Galdric","Hadrion","Halvorn","Harven","Heryn","Icaron","Ideris","Ivaron",
	"Ivelric","Jareth","Jorven","Jorric","Kaelor","Kaereth","Kalvorn","Karven",
	"Keryn","Korveth","Lareth","Larven","Leryn","Lorven","Luthric","Malric",
	"Malverin","Meryn","Morven","Myrion","Nareth","Neryn","Norveth","Nyric",
	"Olarion","Olverin","Orven","Oryndor","Peryn","Perric","Ralven","Roderic",
	"Sareth","Sarven","Seryn","Sorven","Sylvar","Tareth","Tarven","Teryn",
	"Torveth","Tyric","Ulric","Ulverin","Uryndor","Valric","Valverin","Varyn",
	"Veldric","Velyr","Venric","Voryn","Weryn","Wulric","Wyrven","Xandric",
	"Yareth","Yeryn","Zareth","Zeryn","Zorven","Zyrion","Avenric","Ardin",
	"Belthar","Brenric","Caldris","Corlan","Dervin","Elvar","Fenric","Galden",
	"Halric","Ilden","Jorlan","Kelric","Lorcan","Marven","Neldric","Orlan",
	"Pelric","Ralden","Selric","Telric","Ulden","Velric","Warden","Zelric",
	"Aethra","Alira","Arlena","Arvessa","Belara","Beryssa","Braela","Caelia",
	"Calira","Ceryssa","Corvessa","Cyria","Delyra","Deryssa","Dravessa","Elaria",
	"Elyra","Endressa","Eryssa","Felyra","Feressa","Galira","Galessa","Helyra",
	"Ilyra","Iressa","Kaelyra","Kalessa","Keryssa","Lelyra","Liressa","Malira",
	"Melyra","Moressa","Myressa","Nelyra","Neryssa","Olyra","Oressa","Pelyra",
	"Relyra","Selyra","Telyra","Ulyra","Velyra","Zelyra","Avarra","Belessa",
	"Cendria","Delmira","Eryndra","Fendria","Galmira","Halendra","Ivarra",
	"Kelmira","Lendra","Mavira","Nendria","Ormira","Pelendra","Ralendra",
	"Selmira","Telendra","Ulmira","Velendra","Wendra","Xendra","Yendra","Zendra",
	"Vargas","Selena","Lance","Eze","Atro","Magress","Alice","Elza","Maxwell",
	"Lucius","Tilith","Aldric","Aleron","Alvar","Amara","Amaris","Andris",
	"Aneth","Anira","Ardra","Ardric","Arela","Arfen","Arion","Arkon","Arlen",
	"Armon","Arnel","Arric","Arron","Arsel","Artha","Arven","Arvin","Ashel",
	"Ashen","Aston","Athal","Atren","Aurel","Auren","Avelin","Aven","Averyn",
	"Avion","Axel","Axeron","Azaleth","Azaron","Azrel","Azurel","Baelric",
	"Baeron","Balric","Barden","Barris","Bartha","Barvin","Basel","Baven",
	"Baxel","Belden","Belvin","Benden","Benen","Berren","Bersel","Bervin",
	"Bethal","Beyrel","Bralen","Branden","Braxis","Brelyn","Brennor","Bryric",
]

# ── _ready ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_e = RimvaleAPI.engine
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RimvaleUtils.add_bg(self, RimvaleColors.BG_DARK)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_build_director_card())
	root.add_child(_build_tab_bar())

	var content_wrap := Control.new()
	content_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content_wrap)

	_content_team = _build_team_tab()
	_content_team.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_wrap.add_child(_content_team)

	_content_stash = _build_stash_tab()
	_content_stash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_stash.visible = false
	content_wrap.add_child(_content_stash)

	_refresh_collection()
	_refresh_team_slots()
	_update_director()

# ── Director card ─────────────────────────────────────────────────────────────

func _build_director_card() -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 88)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.06, 0.22, 1.0)
	style.set_corner_radius_all(0)
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	for s in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + s, 10)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	# Avatar
	var circle := ColorRect.new()
	circle.custom_minimum_size = Vector2(52, 52)
	circle.color = RimvaleColors.ACCENT
	row.add_child(circle)
	var v_lbl := Label.new()
	v_lbl.text = "V"
	v_lbl.add_theme_font_size_override("font_size", 26)
	v_lbl.add_theme_color_override("font_color", Color.WHITE)
	v_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	circle.add_child(v_lbl)

	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 2)
	row.add_child(info_col)

	info_col.add_child(RimvaleUtils.label("Director Victor Sorn", 15, RimvaleColors.TEXT_WHITE))
	_director_msg_lbl = RimvaleUtils.label(GameState.director_message, 12, RimvaleColors.TEXT_GRAY)
	_director_msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_col.add_child(_director_msg_lbl)

	var econ_col := VBoxContainer.new()
	econ_col.add_theme_constant_override("separation", 4)
	econ_col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(econ_col)

	var tok_row := HBoxContainer.new()
	tok_row.add_theme_constant_override("separation", 4)
	econ_col.add_child(tok_row)
	tok_row.add_child(RimvaleUtils.label("🎫", 14, RimvaleColors.GOLD))
	_director_tokens_lbl = RimvaleUtils.label(str(GameState.tokens), 16, RimvaleColors.GOLD)
	tok_row.add_child(_director_tokens_lbl)

	var rf_row := HBoxContainer.new()
	rf_row.add_theme_constant_override("separation", 4)
	econ_col.add_child(rf_row)
	rf_row.add_child(RimvaleUtils.label("◆", 12, RimvaleColors.ACCENT))
	_director_rf_lbl = RimvaleUtils.label(str(GameState.remnant_fragments) + " RF", 13, RimvaleColors.ACCENT)
	rf_row.add_child(_director_rf_lbl)

	var trade_btn := Button.new()
	trade_btn.text = "⇌ Trade RF"
	trade_btn.custom_minimum_size = Vector2(72, 28)
	trade_btn.add_theme_font_size_override("font_size", 11)
	trade_btn.add_theme_color_override("font_color", RimvaleColors.ACCENT)
	trade_btn.pressed.connect(_on_trade_rf)
	econ_col.add_child(trade_btn)

	return card

# ── Tab bar ───────────────────────────────────────────────────────────────────

func _build_tab_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 48)
	RimvaleUtils.add_bg(bar, RimvaleColors.BG_CARD_DARK)

	_tab_team_btn = RimvaleUtils.button("⚔ Strike Team", RimvaleColors.ACCENT, 44, 14)
	_tab_team_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_team_btn.pressed.connect(func(): _switch_tab(0))
	bar.add_child(_tab_team_btn)

	_tab_stash_btn = RimvaleUtils.button("🎒 Player Stash", RimvaleColors.TEXT_GRAY, 44, 14)
	_tab_stash_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_stash_btn.pressed.connect(func(): _switch_tab(1))
	bar.add_child(_tab_stash_btn)

	return bar

func _switch_tab(idx: int) -> void:
	_current_tab = idx
	_content_team.visible  = (idx == 0)
	_content_stash.visible = (idx == 1)
	_tab_team_btn.add_theme_color_override("font_color",
		RimvaleColors.ACCENT if idx == 0 else RimvaleColors.TEXT_GRAY)
	_tab_stash_btn.add_theme_color_override("font_color",
		RimvaleColors.ACCENT if idx == 1 else RimvaleColors.TEXT_GRAY)
	if idx == 1:
		_refresh_stash()

# ── Strike Team tab ───────────────────────────────────────────────────────────

func _build_team_tab() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)

	# Fusion header (hidden until fusion mode starts)
	_fusion_bar = _build_fusion_bar()
	_fusion_bar.visible = false
	root.add_child(_fusion_bar)

	# ── Slots section ──
	var slots_bg := ColorRect.new()
	slots_bg.color = Color(0.10, 0.05, 0.18, 1.0)
	slots_bg.custom_minimum_size = Vector2(0, 118)
	root.add_child(slots_bg)

	var slots_margin := MarginContainer.new()
	for s in ["left","right","top","bottom"]:
		slots_margin.add_theme_constant_override("margin_" + s, 8)
	slots_bg.add_child(slots_margin)

	var slots_vbox := VBoxContainer.new()
	slots_vbox.add_theme_constant_override("separation", 6)
	slots_margin.add_child(slots_vbox)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	slots_vbox.add_child(header_row)

	var h_lbl := RimvaleUtils.label("Active ACF Strike Team", 14, RimvaleColors.ACCENT)
	h_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(h_lbl)

	_rest_btn = RimvaleUtils.button("🛌 Rest", RimvaleColors.CYAN, 30, 12)
	_rest_btn.pressed.connect(_show_rest_menu)
	header_row.add_child(_rest_btn)

	_team_slots_row = HBoxContainer.new()
	_team_slots_row.add_theme_constant_override("separation", 5)
	_team_slots_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_vbox.add_child(_team_slots_row)

	# ── Collection header ──
	var coll_row := HBoxContainer.new()
	coll_row.custom_minimum_size = Vector2(0, 44)
	coll_row.add_theme_constant_override("separation", 8)
	var coll_margin := MarginContainer.new()
	for s in ["left","right"]:
		coll_margin.add_theme_constant_override("margin_" + s, 10)
	coll_margin.add_child(coll_row)
	root.add_child(coll_margin)

	var coll_lbl := RimvaleUtils.label("Unit Collection", 14, RimvaleColors.TEXT_WHITE)
	coll_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coll_row.add_child(coll_lbl)

	_sort_btn = RimvaleUtils.button("↕ Oldest", RimvaleColors.TEXT_GRAY, 34, 12)
	_sort_btn.pressed.connect(_show_sort_menu)
	coll_row.add_child(_sort_btn)

	var summon_btn := RimvaleUtils.button("✦ Summon ▾", RimvaleColors.ORANGE, 34, 13)
	summon_btn.pressed.connect(_show_summon_menu)
	coll_row.add_child(summon_btn)

	root.add_child(RimvaleUtils.separator())

	# ── Scrollable collection ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_collection_list = VBoxContainer.new()
	_collection_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_list.add_theme_constant_override("separation", 0)
	scroll.add_child(_collection_list)

	return root

# ── Fusion bar ────────────────────────────────────────────────────────────────

func _build_fusion_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 50)
	bar.add_theme_constant_override("separation", 0)
	RimvaleUtils.add_bg(bar, Color(0.35, 0.08, 0.08, 1.0))

	var bar_margin := MarginContainer.new()
	for s in ["left","right"]:
		bar_margin.add_theme_constant_override("margin_" + s, 10)
	bar_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(bar_margin)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	bar_margin.add_child(inner)

	_fusion_bar_lbl = RimvaleUtils.label("Fusion Mode", 14, RimvaleColors.DANGER)
	_fusion_bar_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(_fusion_bar_lbl)

	var cancel := RimvaleUtils.button("✕ Cancel", RimvaleColors.TEXT_GRAY, 36, 12)
	cancel.pressed.connect(_on_cancel_fusion)
	inner.add_child(cancel)

	var confirm := RimvaleUtils.button("⚡ Fuse!", RimvaleColors.DANGER, 36, 13)
	confirm.pressed.connect(_on_confirm_fusion)
	inner.add_child(confirm)

	return bar

# ── Player Stash tab ──────────────────────────────────────────────────────────

func _build_stash_tab() -> Control:
	var root := VBoxContainer.new()

	var margin := MarginContainer.new()
	for s in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + s, 12)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	vbox.add_child(RimvaleUtils.label("Base Global Stash", 16, RimvaleColors.ACCENT))
	vbox.add_child(RimvaleUtils.label(
		"Items purchased from the market or unassigned from units.", 12, RimvaleColors.TEXT_GRAY))
	vbox.add_child(RimvaleUtils.separator())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_stash_list = VBoxContainer.new()
	_stash_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stash_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_stash_list)

	return root

# ── Team slots ────────────────────────────────────────────────────────────────

func _refresh_team_slots() -> void:
	for c in _team_slots_row.get_children():
		c.queue_free()
	for i in range(GameState.ACTIVE_TEAM_SIZE):
		_team_slots_row.add_child(_build_team_slot(i))

func _build_team_slot(slot: int) -> Control:
	var handle: int  = GameState.active_team[slot]
	var is_leader: bool = (slot == 0)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 82)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.flat = true

	var bg := ColorRect.new()
	bg.color = Color(0.18, 0.10, 0.30, 1.0) if handle >= 0 else Color(0.10, 0.06, 0.18, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(bg)

	# Bottom border coloured by role
	var border := ColorRect.new()
	border.color = RimvaleColors.GOLD if is_leader else RimvaleColors.CYAN
	border.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	border.offset_top = -3
	btn.add_child(border)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	btn.add_child(col)

	if handle >= 0:
		var tex := TextureRect.new()
		tex.texture = RimvaleUtils.get_portrait(_e.get_character_lineage_name(handle))
		tex.custom_minimum_size = Vector2(42, 42)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(tex)

		var nl := RimvaleUtils.label(_e.get_character_name(handle), 10, RimvaleColors.TEXT_WHITE)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.clip_text = true
		col.add_child(nl)

		var ll := RimvaleUtils.label("Lv " + str(_e.get_character_level(handle)), 10, RimvaleColors.CYAN)
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(ll)
	else:
		var plus := RimvaleUtils.label("+", 28, RimvaleColors.TEXT_GRAY)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(plus)
		var sl := RimvaleUtils.label(
			("★ Leader" if is_leader else "Slot %d" % (slot + 1)), 10,
			RimvaleColors.GOLD if is_leader else RimvaleColors.TEXT_GRAY)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(sl)

	var cap_slot: int = slot
	btn.pressed.connect(func(): _on_slot_pressed(cap_slot))
	return btn

func _on_slot_pressed(slot: int) -> void:
	if _fusion_mode:
		return
	var h: int = GameState.active_team[slot]
	if h >= 0:
		# Remove from slot
		GameState.active_team[slot] = -1
		_refresh_team_slots()
		_refresh_collection()
	else:
		_show_slot_picker(slot)

# ── Slot picker overlay ───────────────────────────────────────────────────────

func _show_slot_picker(slot: int) -> void:
	_pending_slot = slot
	if is_instance_valid(_slot_overlay):
		_slot_overlay.queue_free()

	_slot_overlay = Control.new()
	_slot_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close_slot_picker()
	)
	_slot_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -160; panel.offset_right = 160
	panel.offset_top  = -240; panel.offset_bottom = 240
	_slot_overlay.add_child(panel)

	var margin := MarginContainer.new()
	for s in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + s, 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	vbox.add_child(RimvaleUtils.label("Assign Agent to Slot %d" % (slot + 1), 16, RimvaleColors.ACCENT))
	vbox.add_child(RimvaleUtils.separator())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)

	# Build set of already-slotted handles
	var team_set: Dictionary = {}
	for h in GameState.active_team:
		if h >= 0:
			team_set[h] = true

	for h in GameState.collection:
		if h in team_set:
			continue
		var busy: bool = h in GameState.busy_handles

		var row := Button.new()
		row.flat = true
		row.custom_minimum_size = Vector2(0, 56)
		row.disabled = busy

		var row_bg := ColorRect.new()
		row_bg.color = Color(0.15, 0.08, 0.24, 1.0) if not busy else Color(0.08, 0.08, 0.08, 0.5)
		row_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.add_child(row_bg)

		var inner := HBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.add_theme_constant_override("separation", 8)
		row.add_child(inner)

		var port := TextureRect.new()
		port.texture = RimvaleUtils.get_portrait(_e.get_character_lineage_name(h))
		port.custom_minimum_size = Vector2(44, 44)
		port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		inner.add_child(port)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		info.add_child(RimvaleUtils.label(_e.get_character_name(h), 14, RimvaleColors.TEXT_WHITE))
		info.add_child(RimvaleUtils.label(
			_e.get_character_lineage_name(h) + "  ·  Lv " + str(_e.get_character_level(h))
			+ ("  [BUSY]" if busy else ""),
			11, RimvaleColors.DANGER if busy else RimvaleColors.TEXT_GRAY))
		inner.add_child(info)

		var cap: int = h
		row.pressed.connect(func():
			GameState.active_team[_pending_slot] = cap
			_close_slot_picker()
			_refresh_team_slots()
			_refresh_collection()
		)
		list.add_child(row)

	if list.get_child_count() == 0:
		list.add_child(RimvaleUtils.label("All units are already slotted.", 13, RimvaleColors.TEXT_GRAY))

	var close_btn := RimvaleUtils.button("✕ Cancel", RimvaleColors.TEXT_GRAY, 38, 13)
	close_btn.pressed.connect(_close_slot_picker)
	vbox.add_child(close_btn)

	add_child(_slot_overlay)

func _close_slot_picker() -> void:
	if is_instance_valid(_slot_overlay):
		_slot_overlay.queue_free()
	_slot_overlay = null

# ── Collection list ───────────────────────────────────────────────────────────

func _refresh_collection() -> void:
	for c in _collection_list.get_children():
		c.queue_free()

	if GameState.collection.is_empty():
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 24)
		_collection_list.add_child(spacer)
		var lbl := RimvaleUtils.label(
			"No units in your collection.\nPress ✦ Summon to recruit agents.", 14, RimvaleColors.TEXT_GRAY)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_collection_list.add_child(lbl)
		return

	for h in _get_sorted_collection():
		_collection_list.add_child(_build_hero_card(h))
		_collection_list.add_child(RimvaleUtils.separator())

func _get_sorted_collection() -> Array:
	var arr: Array = GameState.collection.duplicate()
	match _sort_order:
		"newest":   arr.reverse()
		"name":     arr.sort_custom(func(a, b): return _e.get_character_name(a) < _e.get_character_name(b))
		"lineage":  arr.sort_custom(func(a, b): return _e.get_character_lineage_name(a) < _e.get_character_lineage_name(b))
		"level":    arr.sort_custom(func(a, b): return _e.get_character_level(a) > _e.get_character_level(b))
	return arr

# ── Hero card ─────────────────────────────────────────────────────────────────

func _build_hero_card(handle: int) -> Control:
	var cname:    String = _e.get_character_name(handle)
	var lineage:  String = _e.get_character_lineage_name(handle)
	var level:    int    = _e.get_character_level(handle)
	var xp:       int    = _e.get_character_xp(handle)
	var xp_req:   int    = _e.get_character_xp_required(handle)
	var hp:       int    = _e.get_character_hp(handle)
	var max_hp:   int    = _e.get_character_max_hp(handle)
	var ap:       int    = _e.get_character_ap(handle)
	var max_ap:   int    = _e.get_character_max_ap(handle)
	var sp:       int    = _e.get_character_sp(handle)
	var max_sp:   int    = _e.get_character_max_sp(handle)
	var ac:       int    = _e.get_character_ac(handle)
	var speed:    int    = _e.get_character_movement_speed(handle)
	var weapon:   String = _e.get_equipped_weapon(handle)
	var stat_pts: int    = _e.get_character_stat_points(handle)
	var feat_pts: int    = _e.get_character_feat_points(handle)
	var skill_pts: int   = _e.get_character_skill_points(handle)

	var in_team:   bool = handle in GameState.active_team
	var is_busy:   bool = handle in GameState.busy_handles
	var is_target: bool = _fusion_mode and handle == _fusion_target
	var is_sac:    bool = _fusion_mode and handle in _fusion_sacrifices

	# Card container
	var card := Control.new()
	card.custom_minimum_size = Vector2(0, 130)

	var bg := ColorRect.new()
	if is_target:   bg.color = Color(0.38, 0.18, 0.05, 1.0)
	elif is_sac:    bg.color = Color(0.28, 0.05, 0.05, 1.0)
	elif in_team:   bg.color = Color(0.08, 0.16, 0.28, 1.0)
	else:           bg.color = RimvaleColors.BG_CARD
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(bg)

	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left","right","top","bottom"]:
		m.add_theme_constant_override("margin_" + s, 8)
	card.add_child(m)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	m.add_child(row)

	# Portrait + level badge
	var pcol := VBoxContainer.new()
	pcol.custom_minimum_size = Vector2(70, 0)
	pcol.add_theme_constant_override("separation", 3)
	row.add_child(pcol)

	var tex := TextureRect.new()
	tex.texture = RimvaleUtils.get_portrait(lineage)
	tex.custom_minimum_size = Vector2(66, 66)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	pcol.add_child(tex)

	var lv_bg := ColorRect.new()
	lv_bg.color = RimvaleColors.ACCENT
	lv_bg.custom_minimum_size = Vector2(0, 18)
	pcol.add_child(lv_bg)
	var lv_lbl := RimvaleUtils.label("Lv %d" % level, 11, Color.WHITE)
	lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lv_bg.add_child(lv_lbl)

	# Info column
	var icol := VBoxContainer.new()
	icol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icol.add_theme_constant_override("separation", 3)
	row.add_child(icol)

	# Name + point badges
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 5)
	icol.add_child(name_row)
	var nlbl := RimvaleUtils.label(cname, 15, RimvaleColors.TEXT_WHITE)
	nlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(nlbl)
	if stat_pts > 0:  name_row.add_child(_badge("S+%d" % stat_pts, RimvaleColors.HP_GREEN))
	if feat_pts > 0:  name_row.add_child(_badge("F+%d" % feat_pts, RimvaleColors.CYAN))
	if skill_pts > 0: name_row.add_child(_badge("K+%d" % skill_pts, RimvaleColors.SP_PURPLE))

	# Lineage + AC/Speed
	var sub_row := HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 6)
	icol.add_child(sub_row)
	sub_row.add_child(RimvaleUtils.label(lineage, 11, RimvaleColors.TEXT_GRAY))
	var sp_filler := Control.new()
	sp_filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_row.add_child(sp_filler)
	sub_row.add_child(RimvaleUtils.label("AC %d" % ac, 11, RimvaleColors.ACCENT))
	sub_row.add_child(RimvaleUtils.label("Spd %d" % speed, 11, RimvaleColors.CYAN))

	# Resource bars
	icol.add_child(_mini_bar("HP", hp, max_hp, RimvaleColors.HP_GREEN))
	icol.add_child(_mini_bar("AP", ap, max_ap, RimvaleColors.AP_BLUE))
	icol.add_child(_mini_bar("SP", sp, max_sp, RimvaleColors.SP_PURPLE))

	# XP bar
	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 4)
	icol.add_child(xp_row)
	xp_row.add_child(RimvaleUtils.label("XP", 10, RimvaleColors.GOLD))
	var xpbar := _progress_bar(xp, xp_req, RimvaleColors.GOLD)
	xpbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_row.add_child(xpbar)
	xp_row.add_child(RimvaleUtils.label("%d/%d" % [xp, xp_req], 10, RimvaleColors.TEXT_GRAY))

	# Weapon + status badges
	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 5)
	icol.add_child(badge_row)
	if weapon != "None" and weapon != "":
		badge_row.add_child(RimvaleUtils.label("⚔ " + weapon, 11, RimvaleColors.TEXT_GRAY))
	if in_team:   badge_row.add_child(_badge("TEAM", RimvaleColors.CYAN))
	if is_busy:   badge_row.add_child(_badge("BUSY", RimvaleColors.DANGER))
	if is_target: badge_row.add_child(_badge("TARGET", RimvaleColors.ORANGE))
	if is_sac:    badge_row.add_child(_badge("SACRIFICE", RimvaleColors.DANGER))

	# Action buttons
	var bcol := VBoxContainer.new()
	bcol.add_theme_constant_override("separation", 4)
	bcol.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(bcol)

	var cap: int = handle
	if not _fusion_mode:
		var det_btn := RimvaleUtils.button("📋 Details", RimvaleColors.ACCENT, 32, 11)
		det_btn.pressed.connect(func(): _on_open_detail(cap))
		bcol.add_child(det_btn)

		var eq_btn := RimvaleUtils.button("🎒 Equip", RimvaleColors.GOLD, 32, 11)
		eq_btn.pressed.connect(func(): _on_open_inventory(cap))
		bcol.add_child(eq_btn)

		var fuse_btn := RimvaleUtils.button("⚗ Fuse", Color(0.55, 0.25, 0.85, 1.0), 32, 11)
		fuse_btn.pressed.connect(func(): _on_start_fusion(cap))
		bcol.add_child(fuse_btn)
	else:
		if is_target:
			bcol.add_child(RimvaleUtils.label("TARGET", 11, RimvaleColors.ORANGE))
		else:
			var sac_lbl: String = "✓ Selected" if is_sac else "Sacrifice"
			var sac_col: Color  = RimvaleColors.DANGER if is_sac else RimvaleColors.TEXT_GRAY
			var sac_btn := RimvaleUtils.button(sac_lbl, sac_col, 36, 12)
			sac_btn.pressed.connect(func(): _on_toggle_sacrifice(cap))
			bcol.add_child(sac_btn)

	return card

# ── Resource bar helpers ──────────────────────────────────────────────────────

func _mini_bar(lbl_txt: String, cur: int, mx: int, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.custom_minimum_size = Vector2(0, 14)
	var lbl := RimvaleUtils.label(lbl_txt, 10, color)
	lbl.custom_minimum_size = Vector2(16, 0)
	row.add_child(lbl)
	var bar := _progress_bar(cur, mx, color)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	row.add_child(RimvaleUtils.label("%d/%d" % [cur, mx], 10, RimvaleColors.TEXT_GRAY))
	return row

func _progress_bar(cur: int, mx: int, color: Color) -> Control:
	var track := ColorRect.new()
	track.color = Color(color.r * 0.22, color.g * 0.22, color.b * 0.22, 1.0)
	track.custom_minimum_size = Vector2(0, 8)
	var fill := ColorRect.new()
	fill.color = color
	var pct: float = float(cur) / float(mx) if mx > 0 else 0.0
	fill.anchor_right = clampf(pct, 0.0, 1.0)
	fill.anchor_bottom = 1.0
	track.add_child(fill)
	return track

func _badge(txt: String, color: Color) -> Control:
	var bg := ColorRect.new()
	bg.color = Color(color.r, color.g, color.b, 0.22)
	bg.custom_minimum_size = Vector2(0, 16)
	var lbl := RimvaleUtils.label(txt, 9, color)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bg.add_child(lbl)
	return bg

# ── Summon ────────────────────────────────────────────────────────────────────

func _show_summon_menu() -> void:
	var menu := PopupMenu.new()
	menu.add_item("Summon x1   (1 token)",    0)
	menu.add_item("Summon x5   (5 tokens)",   1)
	menu.add_item("Summon x10  (10 tokens)",  2)
	menu.add_item("Summon x50  (50 tokens)",  3)
	menu.add_separator()
	menu.add_item("Custom Lineage x1  (10 tokens)", 4)
	menu.add_separator()
	menu.add_item("Trade 100 RF → 1 Token",   5)

	var costs := [1, 5, 10, 50]
	for i in range(costs.size()):
		menu.set_item_disabled(i, GameState.tokens < costs[i])
	menu.set_item_disabled(4, GameState.tokens < 10)
	# separator at index 5, trade at 6
	menu.set_item_disabled(6, GameState.remnant_fragments < 100)

	menu.id_pressed.connect(_on_summon_id)
	add_child(menu)
	menu.popup_centered()

func _on_summon_id(id: int) -> void:
	match id:
		0: _do_summon(1)
		1: _do_summon(5)
		2: _do_summon(10)
		3: _do_summon(50)
		4: _show_custom_lineage_dialog()
		5:
			GameState.trade_rf_for_tokens()
			_update_director()
			_show_notice("Traded 100 RF → 1 Token.")

func _do_summon(count: int) -> void:
	if not GameState.spend_tokens(count):
		_show_notice("Not enough tokens!")
		return
	var lineages: PackedStringArray = _e.get_all_lineages()
	if lineages.is_empty():
		_show_notice("No lineages available.")
		return
	for _i in range(count):
		var rname: String = SUMMON_NAMES[randi() % SUMMON_NAMES.size()]
		var rlin: String  = str(lineages[randi() % lineages.size()])
		var h: int = _e.create_character(rname, rlin, 25)
		if h >= 0:
			GameState.add_to_collection(h)
	_show_notice("Summoned %d agent%s!" % [count, "s" if count > 1 else ""])
	_refresh_collection()
	_update_director()

func _show_custom_lineage_dialog() -> void:
	var lineages: PackedStringArray = _e.get_all_lineages()
	if lineages.is_empty():
		return

	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -150; panel.offset_right = 150
	panel.offset_top = -160; panel.offset_bottom = 160
	overlay.add_child(panel)

	var margin := MarginContainer.new()
	for s in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + s, 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	vbox.add_child(RimvaleUtils.label("Choose Lineage  (10 tokens)", 15, RimvaleColors.ACCENT))
	vbox.add_child(RimvaleUtils.separator())

	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(0, 42)
	for lin in lineages:
		opt.add_item(str(lin))
	vbox.add_child(opt)

	var conf := RimvaleUtils.button("✦ Summon", RimvaleColors.ORANGE, 42, 14)
	conf.pressed.connect(func():
		if not GameState.spend_tokens(10):
			_show_notice("Not enough tokens!")
		else:
			var rname: String = SUMMON_NAMES[randi() % SUMMON_NAMES.size()]
			var chosen: String = str(lineages[opt.get_selected_id()])
			var h: int = _e.create_character(rname, chosen, 25)
			if h >= 0:
				GameState.add_to_collection(h)
			_show_notice("Summoned " + rname + " (" + chosen + ")!")
			_refresh_collection()
			_update_director()
		overlay.queue_free()
	)
	vbox.add_child(conf)

	var canc := RimvaleUtils.button("Cancel", RimvaleColors.TEXT_GRAY, 38, 13)
	canc.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(canc)

	add_child(overlay)

# ── Sort ──────────────────────────────────────────────────────────────────────

func _show_sort_menu() -> void:
	var menu := PopupMenu.new()
	menu.add_item("Oldest First",  0)
	menu.add_item("Newest First",  1)
	menu.add_item("By Name",       2)
	menu.add_item("By Lineage",    3)
	menu.add_item("By Level",      4)
	menu.id_pressed.connect(_on_sort_id)
	add_child(menu)
	menu.popup_centered()

func _on_sort_id(id: int) -> void:
	var labels := ["Oldest","Newest","Name","Lineage","Level"]
	var keys   := ["oldest","newest","name","lineage","level"]
	_sort_order = keys[id]
	_sort_btn.text = "↕ " + labels[id]
	_refresh_collection()

# ── Rest ──────────────────────────────────────────────────────────────────────

func _show_rest_menu() -> void:
	var menu := PopupMenu.new()
	menu.add_item("Short Rest  (%d/%d used)" % [GameState.short_rests_used, GameState.MAX_SHORT_RESTS], 0)
	menu.add_item("Long Rest", 1)
	menu.set_item_disabled(0, GameState.short_rests_used >= GameState.MAX_SHORT_RESTS)
	menu.id_pressed.connect(_on_rest_id)
	add_child(menu)
	menu.popup_centered()

func _on_rest_id(id: int) -> void:
	if id == 0:
		# do_short_rest() internally calls engine.rest_party() on the active team
		if GameState.do_short_rest():
			_show_notice("Short rest taken (%d/%d). Team partially restored." % [
				GameState.short_rests_used, GameState.MAX_SHORT_RESTS])
			_refresh_collection()
		else:
			_show_notice("3 short rests used! Take a long rest first.")
	else:
		# do_long_rest() internally calls engine.long_rest() for all collection
		GameState.do_long_rest()
		_show_notice("Long rest taken. Strike team fully recovered.")
		_refresh_collection()

# ── Fusion ────────────────────────────────────────────────────────────────────

func _on_start_fusion(handle: int) -> void:
	_fusion_mode = true
	_fusion_target = handle
	_fusion_sacrifices = []
	_fusion_bar.visible = true
	_rest_btn.visible = false
	_update_fusion_bar()
	_refresh_collection()

func _on_toggle_sacrifice(handle: int) -> void:
	if handle in _fusion_sacrifices:
		_fusion_sacrifices.erase(handle)
	else:
		_fusion_sacrifices.append(handle)
	_update_fusion_bar()
	_refresh_collection()

func _update_fusion_bar() -> void:
	var tname: String = _e.get_character_name(_fusion_target) if _fusion_target >= 0 else "?"
	_fusion_bar_lbl.text = "⚗ Fusing: %s  ·  Sacrifices: %d selected" % [tname, _fusion_sacrifices.size()]

func _on_confirm_fusion() -> void:
	if _fusion_sacrifices.is_empty():
		_show_notice("Select at least one sacrifice first.")
		return
	var tname: String = _e.get_character_name(_fusion_target)
	for sac in _fusion_sacrifices:
		_e.fuse_characters(_fusion_target, sac)
		GameState.remove_from_collection(sac)
		# Remove from team if slotted
		for i in range(GameState.ACTIVE_TEAM_SIZE):
			if GameState.active_team[i] == sac:
				GameState.active_team[i] = -1
	_show_notice("Fusion complete! %s has grown stronger." % tname)
	_on_cancel_fusion()

func _on_cancel_fusion() -> void:
	_fusion_mode = false
	_fusion_target = -1
	_fusion_sacrifices = []
	_fusion_bar.visible = false
	_rest_btn.visible = true
	_refresh_collection()
	_refresh_team_slots()

# ── Navigation ────────────────────────────────────────────────────────────────

func _on_open_detail(handle: int) -> void:
	GameState.selected_hero_handle = handle
	get_parent().get_parent().push_screen("res://scenes/level_up/level_up.tscn")

func _on_open_inventory(handle: int) -> void:
	GameState.selected_hero_handle = handle
	get_parent().get_parent().push_screen("res://scenes/inventory/inventory.tscn")

# ── Trade ─────────────────────────────────────────────────────────────────────

func _on_trade_rf() -> void:
	if GameState.remnant_fragments < 100:
		_show_notice("Need 100 RF to trade for 1 Token.")
		return
	GameState.trade_rf_for_tokens()
	_update_director()
	_show_notice("Traded 100 RF → 1 Token.")

# ── Director refresh ──────────────────────────────────────────────────────────

func _update_director() -> void:
	_director_tokens_lbl.text = str(GameState.tokens)
	_director_rf_lbl.text     = str(GameState.remnant_fragments) + " RF"

# ── Stash ─────────────────────────────────────────────────────────────────────

func _refresh_stash() -> void:
	for c in _stash_list.get_children():
		c.queue_free()
	_stash_list.add_child(RimvaleUtils.label(
		"Stash is empty. Visit the Market or unassign items from units.", 13, RimvaleColors.TEXT_GRAY))

# ── Toast ─────────────────────────────────────────────────────────────────────

func _show_notice(msg: String) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color.WHITE)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.90)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	lbl.add_theme_stylebox_override("normal", style)

	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	lbl.offset_top  = -72
	lbl.offset_bottom = -16
	lbl.offset_left  = 30
	lbl.offset_right = -30
	add_child(lbl)

	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tween.tween_callback(lbl.queue_free)
