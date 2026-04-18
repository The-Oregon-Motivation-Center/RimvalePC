## explore.gd
## Top-down overworld exploration — data-driven regional sandbox.
## Loads map configuration from ExploreMaps for the current subregion.
## Player moves on a tile grid; active team trails behind snake-style.
## Danger zones trigger random encounters (dungeon dives).

extends Control

# ── Tile type constants ─────────────────────────────────────────────────────
const T_ROAD: int      = 0
const T_GROUND: int    = 1
const T_WALL: int      = 2
const T_DANGER: int    = 3
const T_POI: int       = 4
const T_PLAZA: int     = 5
const T_PARK: int      = 6
const T_RUBBLE: int    = 7
const T_WATER: int     = 8
const T_MARKET: int    = 9
const T_WALL_RICH: int = 10
const T_WALL_POOR: int = 11

## POI sub-types
const POI_ACF: int        = 0
const POI_SHOP: int       = 1
const POI_REST: int       = 2
const POI_EXIT: int       = 3
const POI_TAVERN: int     = 4
const POI_BLACKSMITH: int = 5
const POI_LIBRARY: int    = 6
const POI_BOUNTY: int     = 7
const POI_FOUNTAIN: int   = 8

## Grid constants
const GRID_W: int  = 30
const GRID_H: int  = 22
const TILE_PX: int = 48

## Grid character → tile type mapping
const CHAR_TILE := {
	".": 1, "#": 2, "+": 10, "x": 11, "=": 0,
	"!": 3, "@": 4, "$": 5, "T": 6, "%": 7,
	"~": 8, "M": 9,
}

const ExploreMaps = preload("res://scenes/explore/explore_maps.gd")

# ── Map data (loaded from ExploreMaps) ──────────────────────────────────────
var _map_data: Dictionary = {}
var _pal: Dictionary = {}       # colour palette
var _content: Dictionary = {}   # text content

# ── State ───────────────────────────────────────────────────────────────────
var _map: PackedInt32Array
var _poi_map: Dictionary = {}
var _building_labels: Array = []
var _street_labels: Array = []

var _player_pos: Vector2i = Vector2i(15, 19)
var _trail: Array = []
var _trail_max: int = 0
var _steps_since_encounter: int = 0
var _encounter_rate: float = 0.18
var _encounter_guarantee: int = 8

# ── AP action cost tracking (Rimvale Mobile parity) ─────────────────────────
# 1st action = 1 AP, 2nd = 2 AP, 3rd = 3 AP, etc.
var _poi_actions_taken: int = 0

var _region_id: String = ""
var _subregion: String = ""
var _terrain_style: int = 3

# UI refs
var _canvas: Control
var _tile_rects: Array = []
var _player_sprite: Control
var _follower_sprites: Array = []
var _poi_labels: Array = []
var _info_vbox: VBoxContainer
var _info_panel: PanelContainer
var _danger_flash_timer: float = 0.0
var _camera_offset: Vector2 = Vector2.ZERO
var _anim_timer: float = 0.0

# ── Palette helper ──────────────────────────────────────────────────────────
func _pc(key: String, fallback: Color = Color(0.5, 0.0, 0.5)) -> Color:
	return _pal.get(key, fallback)

# ══════════════════════════════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RimvaleUtils.add_bg(self, RimvaleColors.BG_DARK)
	set_process_input(true)

	# Determine which map to load
	_subregion = GameState.current_subregion
	_region_id = GameState.current_region
	if _subregion.is_empty():
		_subregion = "Upper Forty"

	# Load map configuration from ExploreMaps data class
	_map_data = ExploreMaps.get_map(_subregion)
	_pal = _map_data.get("palette", {})
	_content = _map_data.get("content", {})
	_terrain_style = int(_map_data.get("terrain_style", 3))
	_encounter_rate = float(_map_data.get("encounter_rate", 0.18))
	_encounter_guarantee = int(_map_data.get("encounter_guarantee", 8))
	_player_pos = _map_data.get("player_spawn", Vector2i(15, 19))

	var handles: Array = GameState.get_active_handles()
	_trail_max = maxi(0, handles.size() - 1)
	_trail.clear()

	_generate_map()
	_build_ui()
	_center_camera()

func _process(delta: float) -> void:
	if not is_inside_tree():
		return
	_anim_timer += delta
	if _anim_timer > 0.6:
		_anim_timer = 0.0
		_danger_flash_timer += 0.6
		_update_danger_pulse()

# ══════════════════════════════════════════════════════════════════════════════
#  MAP GENERATION — grid-string driven
# ══════════════════════════════════════════════════════════════════════════════

func _generate_map() -> void:
	_map.resize(GRID_W * GRID_H)
	_map.fill(T_GROUND)
	_poi_map.clear()
	_building_labels.clear()
	_street_labels.clear()

	# Parse grid strings from map data
	var grid: Array = _map_data.get("grid", [])
	for y in range(mini(grid.size(), GRID_H)):
		var row: String = str(grid[y])
		for xi in range(mini(row.length(), GRID_W)):
			var ch: String = row[xi]
			var tile: int = CHAR_TILE.get(ch, T_GROUND)
			_set_tile(xi, y, tile)

	# Place POIs from data array: [x, y, poi_type, "label"]
	var pois: Array = _map_data.get("pois", [])
	for p in pois:
		_place_poi(int(p[0]), int(p[1]), int(p[2]), str(p[3]))

	# Register building labels: [x, y, w, h, "name", wall_type]
	var buildings: Array = _map_data.get("buildings", [])
	for b in buildings:
		_building_labels.append({
			"rect": [int(b[0]), int(b[1]), int(b[2]), int(b[3])],
			"name": str(b[4]),
			"wall_type": int(b[5]) if b.size() > 5 else T_WALL
		})

	# Street labels
	_street_labels = _map_data.get("street_labels", [])

	# Ensure player spawn and adjacent tiles are walkable
	_set_tile(_player_pos.x, _player_pos.y, T_ROAD)
	for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		var nx: int = _player_pos.x + d.x
		var ny: int = _player_pos.y + d.y
		if nx >= 0 and nx < GRID_W and ny >= 0 and ny < GRID_H:
			var t: int = _get_tile(nx, ny)
			if t == T_GROUND or t == T_DANGER:
				_set_tile(nx, ny, T_ROAD)

# ── Tile helpers ────────────────────────────────────────────────────────────

func _set_tile(x: int, y: int, t: int) -> void:
	if x >= 0 and x < GRID_W and y >= 0 and y < GRID_H:
		_map[y * GRID_W + x] = t

func _get_tile(x: int, y: int) -> int:
	if x < 0 or x >= GRID_W or y < 0 or y >= GRID_H:
		return T_WALL
	return _map[y * GRID_W + x]

func _is_walkable(x: int, y: int) -> bool:
	var t: int = _get_tile(x, y)
	return t != T_WALL and t != T_WALL_RICH and t != T_WALL_POOR and t != T_WATER

func _place_poi(x: int, y: int, poi_type: int, label_text: String) -> void:
	_set_tile(x, y, T_POI)
	_poi_map[Vector2i(x, y)] = { "type": poi_type, "label": label_text }

# ══════════════════════════════════════════════════════════════════════════════
#  UI CONSTRUCTION
# ══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	var root_hbox := HBoxContainer.new()
	root_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_hbox.add_theme_constant_override("separation", 0)
	add_child(root_hbox)

	# ── Left: Map viewport area ─────────────────────────────────────────────
	var map_panel := Control.new()
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_stretch_ratio = 3.0
	map_panel.clip_contents = true
	root_hbox.add_child(map_panel)

	var map_bg := ColorRect.new()
	map_bg.color = _pc("map_bg", Color(0.04, 0.03, 0.06))
	map_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_panel.add_child(map_bg)

	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(GRID_W * TILE_PX, GRID_H * TILE_PX)
	_canvas.size = _canvas.custom_minimum_size
	map_panel.add_child(_canvas)
	map_panel.gui_input.connect(_on_map_input)

	# ── Draw tiles ──────────────────────────────────────────────────────────
	_tile_rects.clear()
	for y in range(GRID_H):
		for x in range(GRID_W):
			var rect := ColorRect.new()
			rect.position = Vector2(x * TILE_PX, y * TILE_PX)
			rect.size = Vector2(TILE_PX - 1, TILE_PX - 1)
			rect.color = _tile_color(x, y)
			_canvas.add_child(rect)
			_tile_rects.append(rect)

	# ── Building name labels ────────────────────────────────────────────────
	for bld in _building_labels:
		var r: Array = bld["rect"]
		var bname: String = str(bld["name"])
		var cx: float = (int(r[0]) + int(r[2]) * 0.5) * TILE_PX
		var cy: float = (int(r[1]) + int(r[3]) * 0.5) * TILE_PX
		var lbl := Label.new()
		lbl.text = bname
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = Vector2(cx - 40, cy - 6)
		lbl.custom_minimum_size = Vector2(80, 14)
		var wt: int = int(bld["wall_type"])
		if wt == T_WALL_RICH:
			lbl.add_theme_color_override("font_color", _pc("building_label_rich", Color(0.65, 0.55, 0.80, 0.85)))
		elif wt == T_WALL_POOR:
			lbl.add_theme_color_override("font_color", _pc("building_label_poor", Color(0.45, 0.35, 0.30, 0.75)))
		else:
			lbl.add_theme_color_override("font_color", _pc("building_label_default", Color(0.50, 0.48, 0.55, 0.80)))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(lbl)

	# ── Street / path name labels ───────────────────────────────────────────
	for sl in _street_labels:
		var slbl := Label.new()
		slbl.text = str(sl["text"])
		slbl.add_theme_font_size_override("font_size", 7)
		slbl.add_theme_color_override("font_color", _pc("street_label", Color(0.50, 0.45, 0.60, 0.6)))
		slbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sx: float = float(sl["x"]) * TILE_PX
		var sy: float = float(sl["y"]) * TILE_PX
		if bool(sl.get("vertical", false)):
			slbl.position = Vector2(sx + 2, sy)
			slbl.rotation = -PI / 2
		else:
			slbl.position = Vector2(sx, sy - 10)
		_canvas.add_child(slbl)

	# ── POI overlays (icons + labels) ───────────────────────────────────────
	_poi_labels.clear()
	for pos_key in _poi_map:
		var poi: Dictionary = _poi_map[pos_key]
		var lbl := Label.new()
		lbl.text = str(poi["label"])
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.position = Vector2(pos_key.x * TILE_PX - 10, pos_key.y * TILE_PX - 14)
		lbl.add_theme_color_override("font_color", _poi_label_color(int(poi["type"])))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(lbl)
		_poi_labels.append(lbl)

		var icon_lbl := Label.new()
		icon_lbl.text = _poi_icon(int(poi["type"]))
		icon_lbl.add_theme_font_size_override("font_size", 22)
		icon_lbl.position = Vector2(pos_key.x * TILE_PX + 6, pos_key.y * TILE_PX + 2)
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(icon_lbl)

	# ── Player + followers ──────────────────────────────────────────────────
	_player_sprite = _make_entity_sprite(true, 0)
	_canvas.add_child(_player_sprite)
	_update_sprite_pos(_player_sprite, _player_pos)

	_follower_sprites.clear()
	var handles: Array = GameState.get_active_handles()
	for i in range(1, handles.size()):
		var fs := _make_entity_sprite(false, i)
		fs.visible = false
		_canvas.add_child(fs)
		_follower_sprites.append(fs)

	# ── HUD + info panel ────────────────────────────────────────────────────
	_build_hud(map_panel)
	_build_info_panel(root_hbox)
	_show_location_info()

func _poi_icon(poi_type: int) -> String:
	match poi_type:
		POI_ACF:        return "🏢"
		POI_SHOP:       return "🛒"
		POI_REST:       return "🏠"
		POI_EXIT:       return "🚪"
		POI_TAVERN:     return "🍺"
		POI_BLACKSMITH: return "⚒"
		POI_LIBRARY:    return "📚"
		POI_BOUNTY:     return "📜"
		POI_FOUNTAIN:   return "⛲"
	return "?"

func _poi_label_color(poi_type: int) -> Color:
	match poi_type:
		POI_ACF:        return RimvaleColors.ACCENT
		POI_SHOP:       return RimvaleColors.GOLD
		POI_REST:       return RimvaleColors.HP_GREEN
		POI_TAVERN:     return RimvaleColors.ORANGE
		POI_BLACKSMITH: return Color(0.85, 0.45, 0.25)
		POI_LIBRARY:    return RimvaleColors.CYAN
		POI_BOUNTY:     return RimvaleColors.WARNING
		POI_FOUNTAIN:   return RimvaleColors.AP_BLUE
		POI_EXIT:       return RimvaleColors.TEXT_GRAY
	return RimvaleColors.TEXT_WHITE

func _make_entity_sprite(is_player: bool, idx: int) -> Control:
	var handles: Array = GameState.get_active_handles()
	var container := Control.new()
	container.custom_minimum_size = Vector2(TILE_PX, TILE_PX)
	container.size = Vector2(TILE_PX, TILE_PX)
	container.clip_contents = true

	if is_player:
		var ring := ColorRect.new()
		ring.color = Color(RimvaleColors.GOLD, 0.6)
		ring.size = Vector2(TILE_PX, TILE_PX)
		ring.position = Vector2.ZERO
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(ring)

	var tex: Texture2D = null
	if idx < handles.size():
		var h: int = handles[idx]
		var lineage: String = RimvaleAPI.engine.get_character_lineage_name(h)
		tex = RimvaleUtils.get_sprite_portrait(lineage)

	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.anchor_left = 0.0; tr.anchor_top = 0.0
		tr.anchor_right = 1.0; tr.anchor_bottom = 1.0
		tr.offset_left = 2; tr.offset_top = 2
		tr.offset_right = -2; tr.offset_bottom = -2
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(tr)
	else:
		var dot := ColorRect.new()
		dot.color = RimvaleColors.ACCENT if is_player else RimvaleColors.CYAN
		dot.size = Vector2(TILE_PX - 8, TILE_PX - 8)
		dot.position = Vector2(4, 4)
		container.add_child(dot)

	return container

func _update_sprite_pos(sprite: Control, grid_pos: Vector2i) -> void:
	sprite.position = Vector2(grid_pos.x * TILE_PX, grid_pos.y * TILE_PX)

func _build_hud(parent: Control) -> void:
	var hud := PanelContainer.new()
	hud.anchor_left = 0.0; hud.anchor_right = 1.0
	hud.anchor_top = 0.0; hud.anchor_bottom = 0.0
	hud.offset_bottom = 44
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = _pc("hud_bg", Color(0.06, 0.04, 0.10, 0.88))
	hud_style.content_margin_left = 12; hud_style.content_margin_right = 12
	hud_style.content_margin_top = 6;   hud_style.content_margin_bottom = 6
	hud.add_theme_stylebox_override("panel", hud_style)
	parent.add_child(hud)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hud.add_child(hbox)

	var hud_title: String = _map_data.get("hud_title", "Exploring: " + _subregion)
	hbox.add_child(RimvaleUtils.label(hud_title, 14, RimvaleColors.GOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	hbox.add_child(RimvaleUtils.label("WASD / Arrows / Click to move", 11, RimvaleColors.TEXT_DIM))

	var exit_btn := RimvaleUtils.button("← Leave", RimvaleColors.TEXT_GRAY, 32, 12)
	exit_btn.custom_minimum_size.x = 80
	exit_btn.pressed.connect(_on_exit)
	hbox.add_child(exit_btn)

func _build_info_panel(parent: HBoxContainer) -> void:
	_info_panel = PanelContainer.new()
	_info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_panel.size_flags_stretch_ratio = 1.0
	_info_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.04, 0.10, 1.0)
	st.border_width_left = 2
	st.border_color = _pc("info_border", Color(0.30, 0.20, 0.50))
	st.content_margin_left = 12; st.content_margin_right = 12
	st.content_margin_top = 12;  st.content_margin_bottom = 12
	_info_panel.add_theme_stylebox_override("panel", st)
	parent.add_child(_info_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_panel.add_child(scroll)

	_info_vbox = VBoxContainer.new()
	_info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(_info_vbox)

# ══════════════════════════════════════════════════════════════════════════════
#  TILE COLOURS — palette driven
# ══════════════════════════════════════════════════════════════════════════════

func _tile_color(x: int, y: int) -> Color:
	var t: int = _get_tile(x, y)
	match t:
		T_ROAD:
			return _pc("road", Color(0.24, 0.22, 0.30)) if (x + y) % 2 == 0 \
				else _pc("road_alt", Color(0.26, 0.23, 0.32))
		T_GROUND:    return _pc("ground", Color(0.17, 0.19, 0.15))
		T_WALL:      return _pc("wall", Color(0.11, 0.09, 0.13))
		T_WALL_RICH: return _pc("wall_rich", Color(0.18, 0.14, 0.22))
		T_WALL_POOR: return _pc("wall_poor", Color(0.08, 0.06, 0.09))
		T_DANGER:    return _pc("danger", Color(0.14, 0.24, 0.10))
		T_PLAZA:
			return _pc("plaza", Color(0.28, 0.25, 0.32)) if (x + y) % 2 == 0 \
				else _pc("plaza_alt", Color(0.30, 0.27, 0.34))
		T_PARK:      return _pc("park", Color(0.12, 0.26, 0.10))
		T_RUBBLE:    return _pc("rubble", Color(0.20, 0.16, 0.12))
		T_WATER:     return _pc("water", Color(0.10, 0.18, 0.30))
		T_MARKET:    return _pc("market", Color(0.28, 0.22, 0.14))
		T_POI:
			var poi: Dictionary = _poi_map.get(Vector2i(x, y), {})
			match int(poi.get("type", -1)):
				POI_ACF:        return _pc("poi_acf", Color(0.20, 0.16, 0.32))
				POI_SHOP:       return _pc("poi_shop", Color(0.28, 0.22, 0.12))
				POI_REST:       return _pc("poi_rest", Color(0.16, 0.24, 0.26))
				POI_TAVERN:     return _pc("poi_tavern", Color(0.26, 0.18, 0.10))
				POI_BLACKSMITH: return _pc("poi_smith", Color(0.24, 0.14, 0.10))
				POI_LIBRARY:    return _pc("poi_lib", Color(0.14, 0.14, 0.26))
				POI_BOUNTY:     return _pc("poi_bounty", Color(0.26, 0.20, 0.14))
				POI_FOUNTAIN:   return _pc("water", Color(0.10, 0.18, 0.30))
				POI_EXIT:       return _pc("road", Color(0.24, 0.22, 0.30))
			return _pc("ground", Color(0.17, 0.19, 0.15))
	return _pc("ground", Color(0.17, 0.19, 0.15))

func _update_danger_pulse() -> void:
	if _tile_rects.is_empty():
		return
	var pulse: float = (sin(_danger_flash_timer * 2.5) + 1.0) * 0.5
	var col_a: Color = _pc("danger", Color(0.14, 0.24, 0.10))
	var col_b: Color = _pc("danger_pulse", Color(0.22, 0.36, 0.16))
	for y in range(GRID_H):
		for x in range(GRID_W):
			if _get_tile(x, y) == T_DANGER:
				var idx: int = y * GRID_W + x
				if idx >= 0 and idx < _tile_rects.size():
					var rect = _tile_rects[idx]
					if is_instance_valid(rect):
						rect.color = col_a.lerp(col_b, pulse)

# ══════════════════════════════════════════════════════════════════════════════
#  CAMERA
# ══════════════════════════════════════════════════════════════════════════════

func _center_camera() -> void:
	if _canvas == null or not is_instance_valid(_canvas):
		return
	var parent: Control = _canvas.get_parent() as Control
	if parent == null or not is_instance_valid(parent):
		return
	var viewport_size: Vector2 = parent.size
	if viewport_size.x < 10.0 or viewport_size.y < 10.0:
		return
	var player_px: Vector2 = Vector2(_player_pos.x * TILE_PX + TILE_PX * 0.5,
									  _player_pos.y * TILE_PX + TILE_PX * 0.5)
	_camera_offset = viewport_size * 0.5 - player_px
	var map_size := Vector2(GRID_W * TILE_PX, GRID_H * TILE_PX)
	_camera_offset.x = clampf(_camera_offset.x, -(map_size.x - viewport_size.x), 0.0)
	_camera_offset.y = clampf(_camera_offset.y, -(map_size.y - viewport_size.y), 0.0)
	_canvas.position = _camera_offset

# ══════════════════════════════════════════════════════════════════════════════
#  INPUT
# ══════════════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var dir := Vector2i.ZERO
		match event.keycode:
			KEY_W, KEY_UP:    dir = Vector2i(0, -1)
			KEY_S, KEY_DOWN:  dir = Vector2i(0,  1)
			KEY_A, KEY_LEFT:  dir = Vector2i(-1, 0)
			KEY_D, KEY_RIGHT: dir = Vector2i( 1, 0)
		if dir != Vector2i.ZERO:
			_try_move(dir)
			var vp := get_viewport()
			if vp != null:
				vp.set_input_as_handled()

func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = event.position - _camera_offset
		var target := Vector2i(int(local_pos.x) / TILE_PX, int(local_pos.y) / TILE_PX)
		if target == _player_pos:
			return
		var diff := target - _player_pos
		var dir := Vector2i.ZERO
		if abs(diff.x) >= abs(diff.y):
			dir.x = 1 if diff.x > 0 else -1
		else:
			dir.y = 1 if diff.y > 0 else -1
		_try_move(dir)

# ══════════════════════════════════════════════════════════════════════════════
#  MOVEMENT
# ══════════════════════════════════════════════════════════════════════════════

func _try_move(dir: Vector2i) -> void:
	var new_pos: Vector2i = _player_pos + dir
	if not _is_walkable(new_pos.x, new_pos.y):
		return

	if _trail_max > 0:
		_trail.push_front(_player_pos)
		if _trail.size() > _trail_max:
			_trail.resize(_trail_max)

	_player_pos = new_pos
	if is_instance_valid(_player_sprite):
		_update_sprite_pos(_player_sprite, _player_pos)

	for i in range(_follower_sprites.size()):
		var fs = _follower_sprites[i]
		if not is_instance_valid(fs):
			continue
		if i < _trail.size():
			fs.visible = true
			_update_sprite_pos(fs, _trail[i])
		else:
			fs.visible = false

	_center_camera()

	var tile: int = _get_tile(new_pos.x, new_pos.y)
	if tile == T_DANGER:
		_on_danger_step()
	elif tile == T_POI:
		_on_poi_step(new_pos)
	elif tile == T_MARKET:
		_show_market_info()
	elif tile == T_PARK:
		_show_park_info()
	elif tile == T_RUBBLE:
		_show_rubble_info()
	else:
		_steps_since_encounter = 0
		_show_location_info()

# ── Danger zones / encounters ───────────────────────────────────────────────

func _on_danger_step() -> void:
	_steps_since_encounter += 1
	var roll: float = randf()
	var trigger: bool = roll < _encounter_rate or _steps_since_encounter >= _encounter_guarantee
	_show_danger_info()
	if trigger:
		_steps_since_encounter = 0
		_trigger_encounter()

func _trigger_encounter() -> void:
	var handles: PackedInt64Array = GameState.get_active_handles()
	if handles.is_empty():
		_show_message("No active team! Return to base and deploy units.", RimvaleColors.DANGER)
		return

	var base_level: int = maxi(1, GameState.player_level)
	var enemy_level: int = clampi(base_level + randi_range(-1, 1), 1, 15)

	RimvaleAPI.engine.start_dungeon(handles, enemy_level, 0, _terrain_style)
	if GameState.recruited_allies.size() > 0:
		RimvaleAPI.engine.spawn_allies(GameState.recruited_allies)

	var main = get_tree().root.get_child(0)
	if main and main.has_method("push_screen"):
		main.push_screen("res://scenes/dungeon/dungeon.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/dungeon/dungeon.tscn")

# ── POI interactions ────────────────────────────────────────────────────────

func _on_poi_step(pos: Vector2i) -> void:
	var poi: Dictionary = _poi_map.get(pos, {})
	if poi.is_empty():
		return
	_steps_since_encounter = 0
	_poi_actions_taken = 0   # reset action cost counter on entering a POI

	match int(poi["type"]):
		POI_ACF:        _show_acf_panel()
		POI_SHOP:       _show_shop_panel()
		POI_REST:       _show_rest_panel()
		POI_TAVERN:     _show_tavern_panel()
		POI_BLACKSMITH: _show_blacksmith_panel()
		POI_LIBRARY:    _show_library_panel()
		POI_BOUNTY:     _show_bounty_panel()
		POI_FOUNTAIN:   _show_fountain_panel()
		POI_EXIT:       _on_exit()

# ══════════════════════════════════════════════════════════════════════════════
#  INFO PANEL CONTENT — all text driven from _content dictionary
# ══════════════════════════════════════════════════════════════════════════════

func _clear_info() -> void:
	for c in _info_vbox.get_children():
		c.queue_free()

func _show_location_info() -> void:
	_clear_info()
	var icon: String = _content.get("icon", "🗺")
	var loc_name: String = _content.get("name", _subregion)
	_info_vbox.add_child(RimvaleUtils.label(icon + "  " + loc_name, 16, RimvaleColors.GOLD))
	var desc := RimvaleUtils.label(_content.get("desc", "An explorable region of Rimvale."), 11, RimvaleColors.TEXT_GRAY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(desc)
	_info_vbox.add_child(RimvaleUtils.separator())

	_info_vbox.add_child(RimvaleUtils.label("PARTY", 13, RimvaleColors.ACCENT))
	var handles: Array = GameState.get_active_handles()
	if handles.is_empty():
		_info_vbox.add_child(RimvaleUtils.label("No active team!", 12, RimvaleColors.DANGER))
	else:
		for h in handles:
			var nm: String = RimvaleAPI.engine.get_character_name(h)
			var lineage: String = RimvaleAPI.engine.get_character_lineage_name(h)
			var hp: int = RimvaleAPI.engine.get_character_hp(h)
			var max_hp: int = RimvaleAPI.engine.get_character_max_hp(h)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var tex: Texture2D = RimvaleUtils.get_sprite_portrait(lineage)
			if tex != null:
				var portrait_container := Control.new()
				portrait_container.custom_minimum_size = Vector2(28, 28)
				portrait_container.size = Vector2(28, 28)
				portrait_container.clip_contents = true
				var tr := TextureRect.new()
				tr.texture = tex
				tr.anchor_left = 0.0; tr.anchor_top = 0.0
				tr.anchor_right = 1.0; tr.anchor_bottom = 1.0
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				portrait_container.add_child(tr)
				row.add_child(portrait_container)
			var col: Color = RimvaleColors.HP_GREEN if hp > max_hp / 2 else RimvaleColors.DANGER
			row.add_child(RimvaleUtils.label("%s  %d/%d HP" % [nm, hp, max_hp], 11, col))
			_info_vbox.add_child(row)

	_info_vbox.add_child(RimvaleUtils.separator())
	_info_vbox.add_child(RimvaleUtils.label("LEGEND", 13, RimvaleColors.TEXT_GRAY))
	var legend: Dictionary = _content.get("legend", {})
	_info_vbox.add_child(_legend_row("█", _pc("road", Color(0.24, 0.22, 0.30)), legend.get("road", "Path")))
	_info_vbox.add_child(_legend_row("█", _pc("plaza", Color(0.28, 0.25, 0.32)), legend.get("plaza", "Plaza")))
	_info_vbox.add_child(_legend_row("█", _pc("danger", Color(0.14, 0.24, 0.10)), legend.get("danger", "Danger zone")))
	_info_vbox.add_child(_legend_row("█", _pc("park", Color(0.12, 0.26, 0.10)), legend.get("park", "Nature")))
	if not legend.get("market", "").is_empty():
		_info_vbox.add_child(_legend_row("█", _pc("market", Color(0.28, 0.22, 0.14)), legend.get("market", "Market")))
	_info_vbox.add_child(_legend_row("█", _pc("water", Color(0.10, 0.18, 0.30)), legend.get("water", "Water")))

func _legend_row(icon: String, col: Color, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(RimvaleUtils.label(icon, 12, col))
	row.add_child(RimvaleUtils.label(text, 11, RimvaleColors.TEXT_LIGHT))
	return row

func _show_danger_info() -> void:
	_clear_info()
	_info_vbox.add_child(RimvaleUtils.label("⚠  Danger Zone", 16, RimvaleColors.WARNING))
	var desc := RimvaleUtils.label(
		_content.get("danger_desc", "A dangerous area. Hostile creatures may ambush at any step."),
		11, RimvaleColors.TEXT_GRAY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(desc)
	_info_vbox.add_child(RimvaleUtils.separator())
	_info_vbox.add_child(RimvaleUtils.label(
		"Steps in danger: %d" % _steps_since_encounter, 12, RimvaleColors.ORANGE))
	var pct_chance: int = mini(100, int(_encounter_rate * 100) + (_steps_since_encounter * 8))
	_info_vbox.add_child(RimvaleUtils.label(
		"Encounter risk: ~%d%%" % pct_chance, 11, RimvaleColors.TEXT_DIM))

func _show_market_info() -> void:
	_clear_info()
	var market_label: String = _content.get("legend", {}).get("market", "Market Stalls")
	_info_vbox.add_child(RimvaleUtils.label("🏪  " + market_label, 16, RimvaleColors.GOLD))
	var desc := RimvaleUtils.label(
		_content.get("market_desc", "Vendors sell various wares. A safe area."),
		11, RimvaleColors.TEXT_GRAY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(desc)
	_info_vbox.add_child(RimvaleUtils.label("A safe area.", 10, RimvaleColors.TEXT_DIM))

func _show_park_info() -> void:
	_clear_info()
	var park_label: String = _content.get("legend", {}).get("park", "Garden")
	_info_vbox.add_child(RimvaleUtils.label("🌳  " + park_label, 16, RimvaleColors.HP_GREEN))
	var desc := RimvaleUtils.label(
		_content.get("park_desc", "A tranquil natural space. Safe to linger."),
		11, RimvaleColors.TEXT_GRAY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(desc)
	_info_vbox.add_child(RimvaleUtils.label("A safe area.", 10, RimvaleColors.TEXT_DIM))

func _show_rubble_info() -> void:
	_clear_info()
	_info_vbox.add_child(RimvaleUtils.label("🧱  Rubble", 16, RimvaleColors.ORANGE))
	var desc := RimvaleUtils.label(
		_content.get("rubble_desc", "Debris and wreckage. Something happened here."),
		11, RimvaleColors.TEXT_GRAY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(desc)

## Returns the AP cost for the NEXT action (1-based: 1st=1, 2nd=2, …).
func _next_action_ap_cost() -> int:
	return _poi_actions_taken + 1

## Try to spend AP from a single unit for the next action.
## Picks the first unit in the active team that can afford the full cost.
## Returns the handle of the unit that paid, or -1 if nobody can afford it.
func _spend_action_ap() -> int:
	var cost: int = _next_action_ap_cost()
	for h in GameState.get_active_handles():
		var cd: Dictionary = RimvaleAPI.engine.get_char_dict(h)
		if cd == null:
			continue
		var ap: int = int(cd.get("ap", 0))
		if ap >= cost:
			cd["ap"] = ap - cost
			_poi_actions_taken += 1
			_regen_party_ap()   # end-of-action AP regen for the whole team
			return h
	return -1

## Regen AP for every active unit: each recovers STR points (min 1) up to max.
## Feats that grant "+1 AP regen" are checked via the feat dictionary.
func _regen_party_ap() -> void:
	for h in GameState.get_active_handles():
		var cd: Dictionary = RimvaleAPI.engine.get_char_dict(h)
		if cd == null:
			continue
		var stats: Array = cd.get("stats", [1, 1, 1, 1, 1])
		var str_val: int = maxi(1, int(stats[0]))   # STR = index 0
		# Check feats for bonus AP regen
		var bonus: int = 0
		var feats: Dictionary = cd.get("feats", {})
		for feat_name in feats.keys():
			var fl: String = str(feat_name).to_lower()
			# Feats whose description mentions "+1 AP regen" grant +1
			if "ap regen" in fl or "endurance" in fl or "second wind" in fl:
				bonus += 1
		var regen: int = str_val + bonus
		var ap: int  = int(cd.get("ap", 0))
		var cap: int = int(cd.get("max_ap", 10))
		cd["ap"] = mini(ap + regen, cap)

## Convenience: returns text like "(1 AP)" for button labels.
func _ap_cost_str() -> String:
	return "(%d AP)" % _next_action_ap_cost()

## Show a temporary message, then optionally return to a panel after a delay.
## If return_callback is provided, the panel is re-shown after 1.2 seconds.
func _show_message(text: String, col: Color, return_callback: Callable = Callable()) -> void:
	_clear_info()
	var lbl := RimvaleUtils.label(text, 14, col)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(lbl)
	if return_callback.is_valid():
		await get_tree().create_timer(1.2).timeout
		if is_instance_valid(self):
			return_callback.call()

# ── ACF Office ──────────────────────────────────────────────────────────────

## Adds per-unit AP status lines to a panel.
func _add_ap_status(parent: VBoxContainer) -> void:
	var cost: int = _next_action_ap_cost()
	var e = RimvaleAPI.engine
	var any_can_act: bool = false
	for h in GameState.get_active_handles():
		var cd: Dictionary = e.get_char_dict(h)
		if cd == null:
			continue
		var name_: String = e.get_character_name(h)
		var ap: int = int(cd.get("ap", 0))
		var max_ap: int = int(cd.get("max_ap", 10))
		var col: Color = RimvaleColors.AP_BLUE if ap >= cost else RimvaleColors.TEXT_DIM
		if ap >= cost:
			any_can_act = true
		parent.add_child(RimvaleUtils.label(
			"%s  AP: %d/%d" % [name_, ap, max_ap], 11, col))
	var cost_col: Color = RimvaleColors.AP_BLUE if any_can_act else RimvaleColors.DANGER
	parent.add_child(RimvaleUtils.label(
		"Next action: %d AP" % cost, 11, cost_col))

## Wraps an action with the AP cost check.  Deducts from the first unit that
## can afford the full cost.  Returns true if AP was spent.
func _try_action(return_panel: Callable) -> bool:
	var spender: int = _spend_action_ap()
	if spender < 0:
		_show_message("Not enough AP! Rest to recover.", RimvaleColors.DANGER, return_panel)
		return false
	return true

func _show_acf_panel() -> void:
	_clear_info()
	var acf_name: String = _content.get("acf_name", "ACF Field Office")
	_info_vbox.add_child(RimvaleUtils.label("🏢  " + acf_name, 16, RimvaleColors.ACCENT))
	var desc := RimvaleUtils.label(_content.get("acf_desc",
		"A reinforced outpost. Medical bays and a direct line to Command."), 11, RimvaleColors.TEXT_GRAY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(desc)
	_info_vbox.add_child(RimvaleUtils.separator())
	_add_ap_status(_info_vbox)
	_info_vbox.add_child(RimvaleUtils.spacer(4))

	var heal_btn := RimvaleUtils.button("🩹 Request Medical Aid %s" % _ap_cost_str(), RimvaleColors.HP_GREEN, 44, 13)
	heal_btn.pressed.connect(func():
		if not _try_action(_show_acf_panel): return
		for h in GameState.get_active_handles():
			RimvaleAPI.engine.long_rest(h)
		_show_message("All agents restored to full health.", RimvaleColors.HP_GREEN, _show_acf_panel)
	)
	_info_vbox.add_child(heal_btn)

	var brief_btn := RimvaleUtils.button("📋 Accept Field Briefing (+50 XP) %s" % _ap_cost_str(), RimvaleColors.CYAN, 44, 13)
	brief_btn.pressed.connect(func():
		if not _try_action(_show_acf_panel): return
		for h in GameState.get_active_handles():
			RimvaleAPI.engine.add_xp(h, 50, 20)
		GameState.player_xp += 50
		GameState.save_game()
		_show_message("Briefing received. +50 XP to all agents.", RimvaleColors.CYAN, _show_acf_panel)
	)
	_info_vbox.add_child(brief_btn)

	_info_vbox.add_child(RimvaleUtils.separator())
	var manage_btn := RimvaleUtils.button("⚔ Manage Units", RimvaleColors.ACCENT, 38, 12)
	manage_btn.pressed.connect(func():
		GameState.save_game()
		var main_node = get_tree().root.get_child(0)
		if main_node and main_node.has_method("go_to_tab"):
			main_node.go_to_tab(0)
	)
	_info_vbox.add_child(manage_btn)

# ── Supply Shop ─────────────────────────────────────────────────────────────

func _show_shop_panel() -> void:
	_clear_info()
	var shop_name: String = _content.get("shop_name", "Supply Shop")
	_info_vbox.add_child(RimvaleUtils.label("🛒  " + shop_name, 16, RimvaleColors.GOLD))
	var desc := RimvaleUtils.label(_content.get("shop_desc",
		"A well-stocked supplier. The shopkeeper slides items across the counter."), 11, RimvaleColors.TEXT_GRAY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(desc)
	_info_vbox.add_child(RimvaleUtils.separator())
	_add_ap_status(_info_vbox)
	_info_vbox.add_child(RimvaleUtils.label("Gold: %d" % GameState.gold, 13, RimvaleColors.GOLD))
	_info_vbox.add_child(RimvaleUtils.separator())

	var shop_items: Array = _content.get("shop_items", [
		["Health Potion", 50, "Restores 15 HP to the first wounded agent."],
		["AP Tonic", 75, "Restores 5 AP to the first depleted agent."],
		["Smoke Bomb", 40, "Nullifies the next 5 danger-zone steps."],
		["Field Rations", 30, "Restores 5 HP to every team member."],
	])
	for item in shop_items:
		var item_name: String = str(item[0])
		var price: int = int(item[1])
		var item_desc: String = str(item[2])

		var card := RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.DIVIDER, 6, 8)
		var cvbox := VBoxContainer.new()
		cvbox.add_theme_constant_override("separation", 4)
		card.add_child(cvbox)
		cvbox.add_child(RimvaleUtils.label(item_name, 13, RimvaleColors.TEXT_WHITE))
		var d := RimvaleUtils.label(item_desc, 10, RimvaleColors.TEXT_GRAY)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cvbox.add_child(d)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(RimvaleUtils.label("%d gold" % price, 11, RimvaleColors.GOLD))
		var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)

		var buy_btn := RimvaleUtils.button("Buy %s" % _ap_cost_str(), RimvaleColors.GOLD, 28, 11)
		buy_btn.custom_minimum_size.x = 80
		var cap_name := item_name; var cap_price := price
		buy_btn.pressed.connect(func():
			if not _try_action(_show_shop_panel): return
			if GameState.gold >= cap_price:
				GameState.gold -= cap_price
				_apply_shop_item(cap_name)
				_show_shop_panel()
			else:
				_show_message("Not enough gold!", RimvaleColors.DANGER, _show_shop_panel)
		)
		row.add_child(buy_btn)
		cvbox.add_child(row)
		_info_vbox.add_child(card)

func _apply_shop_item(item_name: String) -> void:
	var handles: Array = GameState.get_active_handles()
	if handles.is_empty():
		return
	# Standard item effects — name-based matching
	var lower: String = item_name.to_lower()
	if "health" in lower or "potion" in lower or "salve" in lower or "balm" in lower:
		for h in handles:
			var cd: Dictionary = RimvaleAPI.engine.get_char_dict(h)
			if cd == null: continue
			var hp: int = int(cd.get("hp", 0))
			var max_hp: int = int(cd.get("max_hp", 20))
			if hp < max_hp:
				cd["hp"] = mini(hp + 15, max_hp)
				break
	elif "ap" in lower or "tonic" in lower or "energy" in lower or "stimulant" in lower:
		for h in handles:
			var cd: Dictionary = RimvaleAPI.engine.get_char_dict(h)
			if cd == null: continue
			var ap: int = int(cd.get("ap", 0))
			var max_ap: int = int(cd.get("max_ap", 10))
			if ap < max_ap:
				cd["ap"] = mini(ap + 5, max_ap)
				break
	elif "smoke" in lower or "ward" in lower or "repel" in lower or "cloak" in lower:
		_steps_since_encounter = -5
	elif "ration" in lower or "food" in lower or "meal" in lower or "stew" in lower:
		for h in handles:
			var cd: Dictionary = RimvaleAPI.engine.get_char_dict(h)
			if cd == null: continue
			var hp: int = int(cd.get("hp", 0))
			var max_hp: int = int(cd.get("max_hp", 20))
			cd["hp"] = mini(hp + 5, max_hp)
	GameState.save_game()

# ── Rest House ──────────────────────────────────────────────────────────────

func _show_rest_panel() -> void:
	_clear_info()
	var rest_name: String = _content.get("rest_name", "Rest House")
	_info_vbox.add_child(RimvaleUtils.label("🏠  " + rest_name, 16, RimvaleColors.HP_GREEN))
	var desc := RimvaleUtils.label(_content.get("rest_desc",
		"A safe place to rest and recover. Free for ACF agents."), 11, RimvaleColors.TEXT_GRAY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(desc)
	_info_vbox.add_child(RimvaleUtils.separator())
	_add_ap_status(_info_vbox)
	_info_vbox.add_child(RimvaleUtils.spacer(4))

	var rest_btn := RimvaleUtils.button("💤 Rest (Fully Heal Party) %s" % _ap_cost_str(), RimvaleColors.HP_GREEN, 50, 14)
	rest_btn.pressed.connect(func():
		if not _try_action(_show_rest_panel): return
		for h in GameState.get_active_handles():
			RimvaleAPI.engine.long_rest(h)
		# Reset escalating action cost — the party is freshly rested
		_poi_actions_taken = 0
		GameState.save_game()
		_show_message("Your team rests peacefully. All HP, AP, and SP restored.", RimvaleColors.HP_GREEN, _show_rest_panel)
	)
	_info_vbox.add_child(rest_btn)

	_info_vbox.add_child(RimvaleUtils.spacer(8))
	var save_btn := RimvaleUtils.button("💾 Save Game", RimvaleColors.CYAN, 44, 13)
	save_btn.pressed.connect(func():
		GameState.save_game()
		_show_message("Game saved.", RimvaleColors.CYAN, _show_rest_panel)
	)
	_info_vbox.add_child(save_btn)

# ── Tavern ──────────────────────────────────────────────────────────────────

func _show_tavern_panel() -> void:
	_clear_info()
	var tavern_name: String = _content.get("tavern_name", "Tavern")
	_info_vbox.add_child(RimvaleUtils.label("🍺  " + tavern_name, 16, RimvaleColors.ORANGE))
	var desc := RimvaleUtils.label(_content.get("tavern_desc",
		"A watering hole. Good for morale and loose lips."), 11, RimvaleColors.TEXT_GRAY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(desc)
	_info_vbox.add_child(RimvaleUtils.separator())
	_add_ap_status(_info_vbox)
	_info_vbox.add_child(RimvaleUtils.spacer(4))

	var round_btn := RimvaleUtils.button("🍻 Buy a Round (25g, +30 XP) %s" % _ap_cost_str(), RimvaleColors.ORANGE, 44, 13)
	round_btn.pressed.connect(func():
		if not _try_action(_show_tavern_panel): return
		if GameState.gold >= 25:
			GameState.gold -= 25
			for h in GameState.get_active_handles():
				RimvaleAPI.engine.add_xp(h, 30, 20)
			GameState.player_xp += 30
			GameState.save_game()
			_show_message("Cheers all around! +30 XP.", RimvaleColors.ORANGE, _show_tavern_panel)
		else:
			_show_message("Not enough gold for a round.", RimvaleColors.DANGER, _show_tavern_panel)
	)
	_info_vbox.add_child(round_btn)

	var rumour_btn := RimvaleUtils.button("👂 Gather Rumours %s" % _ap_cost_str(), RimvaleColors.CYAN, 44, 13)
	rumour_btn.pressed.connect(func():
		if not _try_action(_show_tavern_panel): return
		var rumours: Array = _content.get("rumours", ["Nothing interesting today."])
		var r: String = str(rumours[randi() % rumours.size()])
		_show_message("\"" + r + "\"", RimvaleColors.TEXT_LIGHT, _show_tavern_panel)
	)
	_info_vbox.add_child(rumour_btn)

	_info_vbox.add_child(RimvaleUtils.separator())
	var rest_btn := RimvaleUtils.button("☕ Short Rest (Restore Half HP) %s" % _ap_cost_str(), RimvaleColors.HP_GREEN, 38, 12)
	rest_btn.pressed.connect(func():
		if not _try_action(_show_tavern_panel): return
		for h in GameState.get_active_handles():
			RimvaleAPI.engine.short_rest(h)
		# Reset escalating action cost — the party rested
		_poi_actions_taken = 0
		GameState.save_game()
		_show_message("A brief rest. Your team recovers.", RimvaleColors.HP_GREEN, _show_tavern_panel)
	)
	_info_vbox.add_child(rest_btn)

# ── Blacksmith ──────────────────────────────────────────────────────────────

func _show_blacksmith_panel() -> void:
	_clear_info()
	var smith_name: String = _content.get("smith_name", "Blacksmith")
	_info_vbox.add_child(RimvaleUtils.label("⚒  " + smith_name, 16, Color(0.85, 0.45, 0.25)))
	var desc := RimvaleUtils.label(_content.get("smith_desc",
		"A forge glows hot. Weapons and armour can be improved here."), 11, RimvaleColors.TEXT_GRAY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(desc)
	_info_vbox.add_child(RimvaleUtils.separator())
	_add_ap_status(_info_vbox)
	_info_vbox.add_child(RimvaleUtils.spacer(4))

	var sharpen_btn := RimvaleUtils.button("⚔ Sharpen Weapons (+20 XP, 40g) %s" % _ap_cost_str(), RimvaleColors.GOLD, 44, 13)
	sharpen_btn.pressed.connect(func():
		if not _try_action(_show_blacksmith_panel): return
		if GameState.gold >= 40:
			GameState.gold -= 40
			for h in GameState.get_active_handles():
				RimvaleAPI.engine.add_xp(h, 20, 20)
			GameState.save_game()
			_show_message("Weapons honed to a razor edge. +20 XP.", Color(0.85, 0.45, 0.25), _show_blacksmith_panel)
		else:
			_show_message("Not enough gold.", RimvaleColors.DANGER, _show_blacksmith_panel)
	)
	_info_vbox.add_child(sharpen_btn)

	var reinforce_btn := RimvaleUtils.button("🛡 Reinforce Armour (+1 AC, 60g) %s" % _ap_cost_str(), RimvaleColors.CYAN, 44, 13)
	reinforce_btn.pressed.connect(func():
		if not _try_action(_show_blacksmith_panel): return
		if GameState.gold >= 60:
			GameState.gold -= 60
			for h in GameState.get_active_handles():
				var cd: Dictionary = RimvaleAPI.engine.get_char_dict(h)
				if cd != null:
					cd["feat_ac_bonus"] = int(cd.get("feat_ac_bonus", 0)) + 1
			GameState.save_game()
			_show_message("Armour reinforced. +1 AC for the party.", Color(0.85, 0.45, 0.25), _show_blacksmith_panel)
		else:
			_show_message("Not enough gold.", RimvaleColors.DANGER, _show_blacksmith_panel)
	)
	_info_vbox.add_child(reinforce_btn)

# ── Library ─────────────────────────────────────────────────────────────────

func _show_library_panel() -> void:
	_clear_info()
	var lib_name: String = _content.get("library_name", "Library")
	_info_vbox.add_child(RimvaleUtils.label("📚  " + lib_name, 16, RimvaleColors.CYAN))
	var desc := RimvaleUtils.label(_content.get("library_desc",
		"Shelves of knowledge stretch into shadow. Study brings power."), 11, RimvaleColors.TEXT_GRAY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(desc)
	_info_vbox.add_child(RimvaleUtils.separator())
	_add_ap_status(_info_vbox)
	_info_vbox.add_child(RimvaleUtils.spacer(4))

	var study_btn := RimvaleUtils.button("📖 Study Texts (+80 XP, 50g) %s" % _ap_cost_str(), RimvaleColors.CYAN, 44, 13)
	study_btn.pressed.connect(func():
		if not _try_action(_show_library_panel): return
		if GameState.gold >= 50:
			GameState.gold -= 50
			for h in GameState.get_active_handles():
				RimvaleAPI.engine.add_xp(h, 80, 20)
			GameState.player_xp += 80
			GameState.save_game()
			_show_message("Hours among ancient tomes. +80 XP.", RimvaleColors.CYAN, _show_library_panel)
		else:
			_show_message("A donation of 50 gold is required.", RimvaleColors.DANGER, _show_library_panel)
	)
	_info_vbox.add_child(study_btn)

	var meditate_btn := RimvaleUtils.button("🧘 Meditate (Restore SP) %s" % _ap_cost_str(), RimvaleColors.SP_PURPLE, 44, 13)
	meditate_btn.pressed.connect(func():
		if not _try_action(_show_library_panel): return
		for h in GameState.get_active_handles():
			RimvaleAPI.engine.restore_character_sp(h, 3)
		GameState.save_game()
		_show_message("Quiet meditation. +3 SP restored to each agent.", RimvaleColors.SP_PURPLE, _show_library_panel)
	)
	_info_vbox.add_child(meditate_btn)

# ── Bounty Board ────────────────────────────────────────────────────────────

func _show_bounty_panel() -> void:
	_clear_info()
	_info_vbox.add_child(RimvaleUtils.label("📜  Bounty Board", 16, RimvaleColors.WARNING))
	var desc := RimvaleUtils.label(_content.get("bounty_desc",
		"Posted bounties. Each one pays on completion."), 11, RimvaleColors.TEXT_GRAY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(desc)
	_info_vbox.add_child(RimvaleUtils.separator())
	_add_ap_status(_info_vbox)
	_info_vbox.add_child(RimvaleUtils.spacer(4))

	var bounties: Array = _content.get("bounties", [
		["Clear the Nest", 3, 100, "Creatures breeding in the shadows."],
		["Gang Sweep", 3, 80, "Bandits harassing the locals."],
		["Rogue Construct", 5, 150, "A malfunctioning sentinel."],
		["Spy Hunt", 5, 200, "An informant hiding nearby."],
	])
	for b in bounties:
		var bname: String = str(b[0])
		var bterrain: int = int(b[1])
		var breward: int = int(b[2])
		var bdesc: String = str(b[3])

		var card := RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.DIVIDER, 6, 8)
		var cvbox := VBoxContainer.new()
		cvbox.add_theme_constant_override("separation", 4)
		card.add_child(cvbox)
		cvbox.add_child(RimvaleUtils.label(bname, 13, RimvaleColors.TEXT_WHITE))
		var d := RimvaleUtils.label(bdesc, 10, RimvaleColors.TEXT_GRAY)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cvbox.add_child(d)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(RimvaleUtils.label("%d gold reward" % breward, 11, RimvaleColors.GOLD))
		var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)

		var accept_btn := RimvaleUtils.button("Accept %s" % _ap_cost_str(), RimvaleColors.WARNING, 28, 11)
		accept_btn.custom_minimum_size.x = 90
		var cap_terrain := bterrain; var cap_reward := breward
		accept_btn.pressed.connect(func():
			if not _try_action(_show_bounty_panel): return
			_launch_bounty(cap_terrain, cap_reward)
		)
		row.add_child(accept_btn)
		cvbox.add_child(row)
		_info_vbox.add_child(card)

func _launch_bounty(terrain: int, gold_reward: int) -> void:
	var handles: PackedInt64Array = GameState.get_active_handles()
	if handles.is_empty():
		_show_message("No active team!", RimvaleColors.DANGER, _show_bounty_panel)
		return

	var base_level: int = maxi(1, GameState.player_level)
	var enemy_level: int = clampi(base_level + randi_range(0, 2), 1, 15)
	GameState.earn_gold(gold_reward)
	GameState.save_game()

	RimvaleAPI.engine.start_dungeon(handles, enemy_level, 0, terrain)
	if GameState.recruited_allies.size() > 0:
		RimvaleAPI.engine.spawn_allies(GameState.recruited_allies)

	var main = get_tree().root.get_child(0)
	if main and main.has_method("push_screen"):
		main.push_screen("res://scenes/dungeon/dungeon.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/dungeon/dungeon.tscn")

# ── Fountain ────────────────────────────────────────────────────────────────

func _show_fountain_panel() -> void:
	_clear_info()
	var fountain_name: String = _content.get("fountain_name", "Fountain")
	_info_vbox.add_child(RimvaleUtils.label("⛲  " + fountain_name, 16, RimvaleColors.AP_BLUE))
	var desc := RimvaleUtils.label(_content.get("fountain_desc",
		"Water cascades over ancient stone. Locals say wishes made here sometimes come true."), 11, RimvaleColors.TEXT_GRAY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(desc)
	_info_vbox.add_child(RimvaleUtils.separator())
	_add_ap_status(_info_vbox)
	_info_vbox.add_child(RimvaleUtils.spacer(4))

	var wish_btn := RimvaleUtils.button("🪙 Toss a Coin (1 gold) %s" % _ap_cost_str(), RimvaleColors.AP_BLUE, 44, 13)
	wish_btn.pressed.connect(func():
		if not _try_action(_show_fountain_panel): return
		if GameState.gold >= 1:
			GameState.gold -= 1
			var boons: Array = _content.get("fountain_boons", [
				["The water shimmers. +2 HP to all.", "hp", 2],
				["A golden light pulses. +1 AP to all.", "ap", 1],
				["Whispers from the deep. +1 SP to all.", "sp", 1],
				["The coin vanishes. +15 XP.", "xp", 15],
				["Nothing happens... +5 gold found!", "gold", 5],
			])
			var pick: Array = boons[randi() % boons.size()]
			var boon_type: String = str(pick[1])
			var boon_val: int = int(pick[2])
			match boon_type:
				"hp":
					for h in GameState.get_active_handles():
						var cd: Dictionary = RimvaleAPI.engine.get_char_dict(h)
						if cd != null:
							cd["hp"] = mini(int(cd.get("hp", 20)) + boon_val, int(cd.get("max_hp", 20)))
				"ap":
					for h in GameState.get_active_handles():
						var cd: Dictionary = RimvaleAPI.engine.get_char_dict(h)
						if cd != null:
							cd["ap"] = mini(int(cd.get("ap", 6)) + boon_val, int(cd.get("max_ap", 10)))
				"sp":
					for h in GameState.get_active_handles():
						RimvaleAPI.engine.restore_character_sp(h, boon_val)
				"xp":
					for h in GameState.get_active_handles():
						RimvaleAPI.engine.add_xp(h, boon_val, 20)
					GameState.player_xp += boon_val
				"gold":
					GameState.earn_gold(boon_val)
			GameState.save_game()
			_show_message(str(pick[0]), RimvaleColors.AP_BLUE, _show_fountain_panel)
		else:
			_show_message("You have no coins to spare.", RimvaleColors.TEXT_DIM, _show_fountain_panel)
	)
	_info_vbox.add_child(wish_btn)

# ══════════════════════════════════════════════════════════════════════════════
#  EXIT
# ══════════════════════════════════════════════════════════════════════════════

func _on_exit() -> void:
	GameState.save_game()
	var main = get_tree().root.get_child(0)
	if main and main.has_method("pop_screen"):
		main.pop_screen()
	else:
		get_tree().change_scene_to_file("res://scenes/main/main.tscn")
