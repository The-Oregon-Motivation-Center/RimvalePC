## explore_side.gd
## EXPERIMENTAL side-view ("MapleStory-style") 2D presentation of a region map.
## Active when Settings.render_2d() is on — explore.gd defers to this scene.
##
## v1 scope: walk the city high street left/right (A/D or arrows, Space hops),
## buildings rendered as 2D facades with name signs, POIs as interactive
## kiosks, regional NPCs standing on the street (E to talk — intro line only),
## trail gates at both ends leave the region, and wilderness strips past the
## gates can trigger crawl encounters. Combat still runs the 3D dungeon.
extends Control

const RegionalNpcs = preload("res://scenes/explore/regional_npcs.gd")
const RegionalDialogues = preload("res://scenes/explore/regional_dialogues.gd")
const ExploreMaps = preload("res://scenes/explore/explore_maps.gd")

# ── Layout constants (1920×1080 design canvas) ──────────────────────────────
const GROUND_Y: float = 800.0        # street surface line
const UNIT_PX: float = 46.0          # 1 authored grid unit → px of facade width
const GAP_PX: float = 90.0           # gap between structures
const EDGE_PAD: float = 700.0        # wilderness strip beyond each gate
const WALK_SPEED: float = 420.0      # px/sec
const INTERACT_RANGE: float = 110.0

# POI type → emoji + label color
const POI_ICONS: Dictionary = {
	0: "🏛", 1: "🛍", 2: "🛏", 3: "⛩", 4: "🍺", 5: "⚒",
	6: "📚", 7: "💰", 8: "⛲", 9: "📒", 10: "🏰", 11: "🛡",
}

var _map_data: Dictionary = {}
var _subregion: String = ""
var _pal: Dictionary = {}

var _world: Node2D                   # scrolling container (manual camera)
var _bg_far: Node2D
var _bg_mid: Node2D
var _player: Node2D
var _player_sprite: Sprite2D
var _followers: Array = []           # Node2D trail
var _street_len: float = 3000.0

var _player_x: float = 960.0
var _player_vy: float = 0.0          # hop physics
var _player_h: float = 0.0           # height above street (0 = grounded)
var _facing: int = 1

var _interactables: Array = []       # [{x, kind, data, node}]
var _prompt_lbl: Label
var _hud_hint: Label
var _dialog_open: bool = false
var _steps_since_encounter: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	_subregion = GameState.current_subregion
	if _subregion.is_empty():
		_subregion = "Upper Forty"
	_map_data = ExploreMaps.get_map(_subregion)
	_pal = _map_data.get("palette", {})

	_build_sky()
	_world = Node2D.new()
	add_child(_world)
	_bg_far = Node2D.new(); _world.add_child(_bg_far)
	_bg_mid = Node2D.new(); _world.add_child(_bg_mid)
	_build_street()
	_build_buildings_and_pois()
	_build_npcs()
	_build_party()
	_build_hud()
	_player_x = _street_len * 0.5
	set_process(true)
	set_process_unhandled_input(true)

# ── Sky & parallax ───────────────────────────────────────────────────────────
func _pc(key: String, fallback: Color) -> Color:
	var v = _pal.get(key, fallback)
	return v if v is Color else fallback

func _build_sky() -> void:
	var top := ColorRect.new()
	top.color = _pc("map_bg", Color(0.16, 0.18, 0.24)).darkened(0.25)
	top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(top)
	var horizon := ColorRect.new()
	horizon.color = _pc("hud_bg", Color(0.3, 0.28, 0.3)).lightened(0.08)
	horizon.anchor_right = 1.0
	horizon.anchor_top = 0.45
	horizon.anchor_bottom = 0.74
	add_child(horizon)

func _build_parallax_hills(layer: Node2D, base_y: float, hue: Color, count: int, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in range(count):
		var cx: float = rng.randf_range(-EDGE_PAD, _street_len + EDGE_PAD)
		var w: float = rng.randf_range(340, 720)
		var h: float = rng.randf_range(120, 260)
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(cx - w * 0.5, base_y),
			Vector2(cx, base_y - h),
			Vector2(cx + w * 0.5, base_y),
		])
		poly.color = hue
		layer.add_child(poly)

# ── Street & structures ──────────────────────────────────────────────────────
func _build_street() -> void:
	# Compute street length first from structure count
	var buildings: Array = _map_data.get("buildings", [])
	var pois: Array = _map_data.get("pois", [])
	var total_w: float = 0.0
	for b in buildings:
		total_w += maxf(2.0, float(int(b[2]))) * UNIT_PX + GAP_PX
	total_w += float(pois.size()) * (150.0 + GAP_PX)
	_street_len = maxf(2400.0, total_w + 500.0)

	# Parallax silhouettes (drawn before street so they sit behind)
	_build_parallax_hills(_bg_far, GROUND_Y - 150.0,
		_pc("wall", Color(0.3, 0.3, 0.35)).darkened(0.55), 14, hash(_subregion) % 100000)
	_build_parallax_hills(_bg_mid, GROUND_Y - 60.0,
		_pc("wall", Color(0.3, 0.3, 0.35)).darkened(0.35), 10, hash(_subregion) % 77777 + 3)

	# Road surface
	var road := ColorRect.new()
	road.color = _pc("road", Color(0.45, 0.42, 0.38))
	road.position = Vector2(-EDGE_PAD * 2.0, GROUND_Y)
	road.size = Vector2(_street_len + EDGE_PAD * 4.0, 1080.0 - GROUND_Y)
	_world.add_child(road)
	var curb := ColorRect.new()
	curb.color = _pc("road_alt", Color(0.5, 0.47, 0.42)).lightened(0.1)
	curb.position = Vector2(-EDGE_PAD * 2.0, GROUND_Y)
	curb.size = Vector2(_street_len + EDGE_PAD * 4.0, 10.0)
	_world.add_child(curb)

	# Wilderness tint strips past the gates (danger zones)
	for side_x in [-EDGE_PAD * 2.0, _street_len]:
		var wild := ColorRect.new()
		wild.color = Color(_pc("danger", Color(0.6, 0.25, 0.2)), 0.10)
		wild.position = Vector2(side_x + (0.0 if side_x < 0.0 else EDGE_PAD), 0.0)
		wild.size = Vector2(EDGE_PAD, 1080.0)
		# left strip covers [-2*PAD, -PAD]; right covers [len+PAD, len+2*PAD]
		if side_x < 0.0:
			wild.position.x = -EDGE_PAD * 2.0
		else:
			wild.position.x = _street_len + EDGE_PAD
		_world.add_child(wild)

func _wall_color(wall_type: int) -> Color:
	match wall_type:
		10: return _pc("wall_rich", Color(0.75, 0.68, 0.5))
		11: return _pc("wall_poor", Color(0.4, 0.35, 0.28))
		_:  return _pc("wall", Color(0.55, 0.5, 0.45))

func _build_buildings_and_pois() -> void:
	var buildings: Array = _map_data.get("buildings", []).duplicate()
	var pois: Array = _map_data.get("pois", []).duplicate()
	# Preserve authored left-to-right ordering
	buildings.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	pois.sort_custom(func(a, b): return int(a[0]) < int(b[0]))

	# Interleave: distribute POI kiosks evenly among buildings
	var slots: Array = []
	var poi_i: int = 0
	var per: float = float(pois.size()) / maxf(1.0, float(buildings.size()))
	var acc: float = 0.0
	for b in buildings:
		slots.append(["b", b])
		acc += per
		while acc >= 1.0 and poi_i < pois.size():
			slots.append(["p", pois[poi_i]])
			poi_i += 1
			acc -= 1.0
	while poi_i < pois.size():
		slots.append(["p", pois[poi_i]])
		poi_i += 1

	var x: float = 260.0
	for slot in slots:
		if slot[0] == "b":
			x = _place_building(slot[1], x)
		else:
			x = _place_poi(slot[1], x)

	# Trail gates at both ends
	_place_gate(40.0, "West Gate")
	_place_gate(_street_len - 40.0, "East Gate")

func _place_building(b: Array, x: float) -> float:
	var bw: float = maxf(2.0, float(int(b[2]))) * UNIT_PX
	var bh: float = clampf(float(int(b[3])) * 85.0, 150.0, 460.0)
	var wall_t: int = int(b[5]) if b.size() > 5 else 2
	var col: Color = _wall_color(wall_t)
	var name_s: String = str(b[4])

	var facade := ColorRect.new()
	facade.color = col
	facade.position = Vector2(x, GROUND_Y - bh)
	facade.size = Vector2(bw, bh)
	_world.add_child(facade)

	# Roof
	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([
		Vector2(x - 14, GROUND_Y - bh),
		Vector2(x + bw * 0.5, GROUND_Y - bh - 56.0),
		Vector2(x + bw + 14, GROUND_Y - bh),
	])
	roof.color = col.darkened(0.35)
	_world.add_child(roof)

	# Door
	var door := ColorRect.new()
	door.color = col.darkened(0.5)
	door.position = Vector2(x + bw * 0.5 - 22, GROUND_Y - 64)
	door.size = Vector2(44, 64)
	_world.add_child(door)

	# Windows
	var win_col: Color = Color(1.0, 0.9, 0.6, 0.85)
	var rows: int = int(maxf(1.0, (bh - 90.0) / 110.0))
	var cols: int = int(maxf(1.0, bw / 120.0))
	for r in range(rows):
		for c in range(cols):
			var w := ColorRect.new()
			w.color = win_col
			w.size = Vector2(26, 34)
			w.position = Vector2(
				x + (c + 0.5) * (bw / cols) - 13.0,
				GROUND_Y - bh + 34.0 + r * 110.0)
			_world.add_child(w)

	# Name sign
	var sign := Label.new()
	sign.text = name_s
	sign.add_theme_font_size_override("font_size", 20)
	sign.add_theme_color_override("font_color", _pc("building_label_default", Color(0.9, 0.85, 0.7)))
	sign.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	sign.add_theme_constant_override("outline_size", 6)
	sign.position = Vector2(x, GROUND_Y - bh - 96.0)
	sign.size = Vector2(bw, 30)
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world.add_child(sign)

	return x + bw + GAP_PX

func _place_poi(p: Array, x: float) -> float:
	var ptype: int = int(p[2])
	var pname: String = str(p[3])
	var kiosk_w: float = 150.0

	var booth := ColorRect.new()
	booth.color = _pc("poi_shop", Color(0.8, 0.65, 0.3)).darkened(0.1) if ptype != 0 \
		else _pc("poi_acf", Color(0.5, 0.3, 0.6))
	booth.position = Vector2(x, GROUND_Y - 120.0)
	booth.size = Vector2(kiosk_w, 120.0)
	_world.add_child(booth)

	var awning := Polygon2D.new()
	awning.polygon = PackedVector2Array([
		Vector2(x - 10, GROUND_Y - 120.0),
		Vector2(x + kiosk_w + 10, GROUND_Y - 120.0),
		Vector2(x + kiosk_w - 6, GROUND_Y - 150.0),
		Vector2(x + 6, GROUND_Y - 150.0),
	])
	awning.color = booth.color.darkened(0.3)
	_world.add_child(awning)

	var icon := Label.new()
	icon.text = str(POI_ICONS.get(ptype, "❔"))
	icon.add_theme_font_size_override("font_size", 44)
	icon.position = Vector2(x + kiosk_w * 0.5 - 26, GROUND_Y - 108.0)
	_world.add_child(icon)

	var sign := Label.new()
	sign.text = pname
	sign.add_theme_font_size_override("font_size", 17)
	sign.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	sign.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	sign.add_theme_constant_override("outline_size", 5)
	sign.position = Vector2(x - 40, GROUND_Y - 186.0)
	sign.size = Vector2(kiosk_w + 80, 26)
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world.add_child(sign)

	_interactables.append({
		"x": x + kiosk_w * 0.5, "kind": "poi",
		"name": pname, "ptype": ptype,
	})
	return x + kiosk_w + GAP_PX

func _place_gate(x: float, label_s: String) -> void:
	var post_col: Color = _pc("wall", Color(0.5, 0.5, 0.5)).darkened(0.2)
	for dx in [-60.0, 60.0]:
		var post := ColorRect.new()
		post.color = post_col
		post.position = Vector2(x + dx - 12, GROUND_Y - 210)
		post.size = Vector2(24, 210)
		_world.add_child(post)
	var arch := ColorRect.new()
	arch.color = post_col.darkened(0.15)
	arch.position = Vector2(x - 78, GROUND_Y - 236)
	arch.size = Vector2(156, 26)
	_world.add_child(arch)
	var sign := Label.new()
	sign.text = "⛩ %s — leave region" % label_s
	sign.add_theme_font_size_override("font_size", 16)
	sign.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	sign.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	sign.add_theme_constant_override("outline_size", 5)
	sign.position = Vector2(x - 110, GROUND_Y - 270)
	sign.size = Vector2(220, 24)
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world.add_child(sign)
	_interactables.append({"x": x, "kind": "gate", "name": label_s, "ptype": -1})

# ── NPCs ─────────────────────────────────────────────────────────────────────
func _build_npcs() -> void:
	var roster: Array = RegionalNpcs.get_roster(_subregion)
	if roster.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_subregion + "_npcs")
	for npc in roster:
		var nx: float = rng.randf_range(300.0, _street_len - 300.0)
		var holder := Node2D.new()
		holder.position = Vector2(nx, GROUND_Y)
		_world.add_child(holder)
		var spr := Sprite2D.new()
		spr.texture = RimvaleUtils.get_sprite_portrait(str(npc.get("lineage", "Elf")))
		if spr.texture != null:
			var th: float = float(spr.texture.get_height())
			var scale_f: float = 96.0 / maxf(1.0, th)
			spr.scale = Vector2(scale_f, scale_f)
			spr.position = Vector2(0, -48.0)
		spr.modulate = npc.get("portrait_tint", Color.WHITE)
		holder.add_child(spr)
		var nm := Label.new()
		nm.text = str(npc.get("name", "???"))
		nm.add_theme_font_size_override("font_size", 14)
		nm.add_theme_color_override("font_color", Color(0.82, 0.85, 0.92))
		nm.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		nm.add_theme_constant_override("outline_size", 4)
		nm.position = Vector2(-70, -128)
		nm.size = Vector2(140, 20)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		holder.add_child(nm)
		_interactables.append({
			"x": nx, "kind": "npc", "name": str(npc.get("name", "???")),
			"ptype": -1, "npc": npc,
		})

# ── Party ────────────────────────────────────────────────────────────────────
func _make_char_sprite(handle: int) -> Node2D:
	var holder := Node2D.new()
	var spr := Sprite2D.new()
	var lineage: String = str(RimvaleAPI.engine.get_character_lineage_name(handle))
	spr.texture = RimvaleUtils.get_sprite_portrait(lineage)
	if spr.texture != null:
		var th: float = float(spr.texture.get_height())
		var scale_f: float = 104.0 / maxf(1.0, th)
		spr.scale = Vector2(scale_f, scale_f)
		spr.position = Vector2(0, -52.0)
	holder.add_child(spr)
	return holder

func _build_party() -> void:
	var handles: Array = GameState.get_active_handles()
	if handles.is_empty():
		_player = Node2D.new()
		_player_sprite = Sprite2D.new()
		_player.add_child(_player_sprite)
		_world.add_child(_player)
		return
	_player = _make_char_sprite(handles[0])
	_player_sprite = _player.get_child(0) as Sprite2D
	_world.add_child(_player)
	for i in range(1, handles.size()):
		var f := _make_char_sprite(handles[i])
		f.modulate = Color(1, 1, 1, 0.92)
		_world.add_child(f)
		_followers.append(f)

# ── HUD ──────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	var bar := ColorRect.new()
	bar.color = Color(0.05, 0.05, 0.08, 0.85)
	bar.anchor_right = 1.0
	bar.custom_minimum_size = Vector2(0, 44)
	bar.size = Vector2(1920, 44)
	add_child(bar)
	var title := Label.new()
	title.text = "%s   —   SIDE-VIEW (experimental 2D)" % str(_map_data.get("hud_title", _subregion))
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	title.position = Vector2(16, 10)
	add_child(title)
	_hud_hint = Label.new()
	_hud_hint.text = "A/D or ←/→ walk   ·   Space hop   ·   E interact   ·   gates leave region"
	_hud_hint.add_theme_font_size_override("font_size", 13)
	_hud_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	_hud_hint.position = Vector2(640, 12)
	add_child(_hud_hint)
	var leave_btn := Button.new()
	leave_btn.text = "← Leave"
	leave_btn.position = Vector2(1800, 6)
	leave_btn.size = Vector2(104, 32)
	leave_btn.pressed.connect(_leave_region)
	add_child(leave_btn)

	_prompt_lbl = Label.new()
	_prompt_lbl.add_theme_font_size_override("font_size", 20)
	_prompt_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_prompt_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt_lbl.add_theme_constant_override("outline_size", 6)
	_prompt_lbl.position = Vector2(760, 640)
	_prompt_lbl.size = Vector2(400, 30)
	_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_lbl.visible = false
	add_child(_prompt_lbl)

# ── Main loop ────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _dialog_open:
		return
	var dir: float = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  dir -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir += 1.0
	if dir != 0.0:
		_player_x += dir * WALK_SPEED * delta
		_facing = 1 if dir > 0.0 else -1
		# Wilderness encounter pressure past the gates
		if _player_x < 0.0 or _player_x > _street_len:
			_steps_since_encounter += delta
			if _steps_since_encounter > 1.0:
				_steps_since_encounter = 0.0
				if randf() < 0.22:
					_trigger_side_encounter()
					return
	_player_x = clampf(_player_x, -EDGE_PAD * 1.6, _street_len + EDGE_PAD * 1.6)

	# Hop physics (cosmetic)
	if _player_h > 0.0 or _player_vy != 0.0:
		_player_vy -= 2600.0 * delta
		_player_h = maxf(0.0, _player_h + _player_vy * delta)
		if _player_h == 0.0:
			_player_vy = 0.0

	_player.position = Vector2(_player_x, GROUND_Y - _player_h)
	if _player_sprite != null:
		_player_sprite.flip_h = (_facing < 0)

	# Followers trail behind the leader
	for i in range(_followers.size()):
		var fx: float = _player_x - float(i + 1) * 64.0 * float(_facing)
		var f: Node2D = _followers[i]
		f.position = f.position.lerp(Vector2(fx, GROUND_Y), 0.12)
		var fs := f.get_child(0) as Sprite2D
		if fs != null:
			fs.flip_h = (_facing < 0)

	# Manual camera scroll (+ parallax)
	var cam_x: float = clampf(_player_x - 960.0, -EDGE_PAD * 1.6, _street_len + EDGE_PAD * 1.6 - 1920.0)
	_world.position.x = -cam_x
	_bg_far.position.x = cam_x * 0.8    # net movement = 0.2× scroll
	_bg_mid.position.x = cam_x * 0.5    # net movement = 0.5× scroll

	# Interaction prompt
	var near: Dictionary = _nearest_interactable()
	if near.is_empty():
		_prompt_lbl.visible = false
	else:
		_prompt_lbl.visible = true
		_prompt_lbl.text = "[E]  %s" % str(near.get("name", ""))

func _unhandled_input(event: InputEvent) -> void:
	if _dialog_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and _player_h <= 0.0:
			_player_vy = 900.0
			_player_h = 0.001
		elif event.keycode == KEY_E:
			var near: Dictionary = _nearest_interactable()
			if not near.is_empty():
				_interact(near)

func _nearest_interactable() -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = INTERACT_RANGE
	for it in _interactables:
		var d: float = absf(float(it["x"]) - _player_x)
		if d < best_d:
			best_d = d
			best = it
	return best

# ── Interactions ─────────────────────────────────────────────────────────────
func _interact(it: Dictionary) -> void:
	match str(it.get("kind", "")):
		"gate":
			_leave_region()
		"poi":
			_show_dialog(str(it.get("name", "")),
				"You stand before the %s.\n\n(Side-view v1: interiors and services open in 3D mode — toggle 2D Mode off in Profile → Dev Tools for the full visit.)" % str(it.get("name", "")))
		"npc":
			var npc: Dictionary = it.get("npc", {})
			var tree_id: String = str(npc.get("dialogue_tree_id", ""))
			var tree: Array = RegionalDialogues.get_tree(tree_id)
			var line: String = "…"
			var speaker: String = str(npc.get("name", "???"))
			if not tree.is_empty() and tree[0] is Dictionary:
				line = str(tree[0].get("text", "…"))
				speaker = str(tree[0].get("speaker", speaker))
			_show_dialog("%s  ·  %s" % [speaker, str(npc.get("role", ""))],
				line + "\n\n(Full conversations with skill checks run in 3D mode for now.)")

func _show_dialog(title_s: String, body_s: String) -> void:
	_dialog_open = true
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(560, 340)
	panel.custom_minimum_size = Vector2(800, 0)
	dim.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var t := Label.new()
	t.text = title_s
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	vb.add_child(t)
	var b := Label.new()
	b.text = body_s
	b.add_theme_font_size_override("font_size", 15)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(760, 0)
	vb.add_child(b)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(140, 38)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func():
		dim.queue_free()
		_dialog_open = false
	)
	vb.add_child(close)
	close.grab_focus()

# ── Encounters & exits ───────────────────────────────────────────────────────
func _trigger_side_encounter() -> void:
	var handles: PackedInt64Array = GameState.get_active_handles()
	if handles.is_empty():
		return
	var base_level: int = maxi(1, GameState.player_level)
	var enemy_level: int = clampi(base_level + randi_range(-1, 1), 1, 15)
	GameState.explore_return_active = false   # side view doesn't use tile return
	GameState.dungeon_source = "explore"
	RimvaleAPI.engine.start_dungeon_crawl(handles, enemy_level,
		int(_map_data.get("terrain_style", 1)))
	if GameState.recruited_allies.size() > 0:
		RimvaleAPI.engine.spawn_allies(GameState.recruited_allies)
	var main = _find_main_shell()
	if main != null:
		main.push_screen("res://scenes/dungeon/dungeon.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/dungeon/dungeon.tscn")

func _leave_region() -> void:
	var main = _find_main_shell()
	if main != null:
		main.pop_screen()
	else:
		# Never load world.tscn standalone — that strands the player without
		# the nav shell. Rebuild the shell instead.
		get_tree().change_scene_to_file("res://scenes/main/main.tscn")

## Walk up the tree to the main shell (the node exposing push/pop_screen).
func _find_main_shell() -> Node:
	var n: Node = get_parent()
	while n != null and not n.has_method("pop_screen"):
		n = n.get_parent()
	return n
