## explore.gd
## 3D overworld exploration — data-driven regional sandbox.
## Loads map configuration from ExploreMaps for the current subregion.
## Player moves on a tile grid rendered as a full 3D environment with
## chase camera, procedural buildings, POI landmarks, and atmosphere.
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
var _poi_actions_taken: int = 0

var _region_id: String = ""
var _subregion: String = ""
var _terrain_style: int = 3

# ── 3D Viewport refs ───────────────────────────────────────────────────────
var _viewport_3d: SubViewport
var _world3d_root: Node3D
var _cam3d: Camera3D
var _tile_root: Node3D
var _wall_root: Node3D
var _entity_root: Node3D
var _poi_root: Node3D
var _overlay_root: Node3D
var _fog_root: Node3D
var _particle_root: Node3D
var _env_node: WorldEnvironment

# ── Camera state ────────────────────────────────────────────────────────────
var _cam_yaw: float = 0.0        # horizontal angle (degrees)
var _cam_pitch: float = 40.0     # vertical angle (degrees, 15-75)
var _cam_dist: float = 10.0      # distance from target (6-25)
var _cam_target: Vector3 = Vector3.ZERO
var _cam_current_pos: Vector3 = Vector3.ZERO
var _cam_dragging: bool = false
var _cam_drag_start: Vector2 = Vector2.ZERO

# ── Player 3D state ────────────────────────────────────────────────────────
var _player_node: Node3D
var _follower_nodes: Array = []
var _player_world_pos: Vector3 = Vector3.ZERO
var _player_target_pos: Vector3 = Vector3.ZERO
var _player_moving: bool = false
var _player_facing: float = 0.0  # yaw radians
var _move_lerp_t: float = 0.0

# ── UI refs ─────────────────────────────────────────────────────────────────
var _info_vbox: VBoxContainer
var _info_panel: PanelContainer
var _danger_flash_timer: float = 0.0
var _anim_timer: float = 0.0
var _time_of_day: float = 0.0    # accumulated for sky/light shifts

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

	_subregion = GameState.current_subregion
	_region_id = GameState.current_region
	if _subregion.is_empty():
		_subregion = "Upper Forty"

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

	# Set initial camera target on player
	_player_world_pos = _tile_to_world(_player_pos.x, _player_pos.y)
	_player_target_pos = _player_world_pos
	_cam_target = _player_world_pos
	_update_camera_pos()

func _process(delta: float) -> void:
	if not is_inside_tree():
		return
	_time_of_day += delta * 0.02
	_anim_timer += delta

	# Smooth player movement lerp
	if _player_moving:
		_move_lerp_t += delta * 5.0  # ~0.2s per tile
		if _move_lerp_t >= 1.0:
			_move_lerp_t = 1.0
			_player_moving = false
			_player_world_pos = _player_target_pos
		else:
			_player_world_pos = _player_world_pos.lerp(_player_target_pos, _move_lerp_t)
		_update_player_3d_pos()
		_update_follower_3d_positions()

	# Smooth camera follow
	_cam_target = _cam_target.lerp(_player_world_pos, delta * 6.0)
	_update_camera_pos()

	# Danger tile pulse via emission
	if _anim_timer > 0.05:
		_anim_timer = 0.0
		_danger_flash_timer += 0.05
		_update_danger_pulse_3d()

	# Idle bob for player
	if _player_node != null and is_instance_valid(_player_node):
		var bob: float = sin(_time_of_day * 50.0) * 0.03
		_player_node.position.y = _get_tile_y(_player_pos.x, _player_pos.y) + bob

# ══════════════════════════════════════════════════════════════════════════════
#  MAP GENERATION — grid-string driven (unchanged logic)
# ══════════════════════════════════════════════════════════════════════════════

func _generate_map() -> void:
	_map.resize(GRID_W * GRID_H)
	_map.fill(T_GROUND)
	_poi_map.clear()
	_building_labels.clear()
	_street_labels.clear()

	var grid: Array = _map_data.get("grid", [])
	for y in range(mini(grid.size(), GRID_H)):
		var row: String = str(grid[y])
		for xi in range(mini(row.length(), GRID_W)):
			var ch: String = row[xi]
			var tile: int = CHAR_TILE.get(ch, T_GROUND)
			_set_tile(xi, y, tile)

	var pois: Array = _map_data.get("pois", [])
	for p in pois:
		_place_poi(int(p[0]), int(p[1]), int(p[2]), str(p[3]))

	var buildings: Array = _map_data.get("buildings", [])
	for b in buildings:
		_building_labels.append({
			"rect": [int(b[0]), int(b[1]), int(b[2]), int(b[3])],
			"name": str(b[4]),
			"wall_type": int(b[5]) if b.size() > 5 else T_WALL
		})

	_street_labels = _map_data.get("street_labels", [])

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

# ── 3D Coordinate helpers ──────────────────────────────────────────────────

func _tile_to_world(tx: int, ty: int) -> Vector3:
	return Vector3(float(tx) + 0.5, _get_tile_y(tx, ty), float(ty) + 0.5)

func _get_tile_y(tx: int, ty: int) -> float:
	var t: int = _get_tile(tx, ty)
	if t == T_WATER:
		return -0.15
	return 0.0

# ══════════════════════════════════════════════════════════════════════════════
#  UI CONSTRUCTION — 3D viewport + info panel
# ══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	var root_hbox := HBoxContainer.new()
	root_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_hbox.add_theme_constant_override("separation", 0)
	add_child(root_hbox)

	# ── Left: 3D map viewport ───────────────────────────────────────────────
	var map_panel := Control.new()
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_stretch_ratio = 3.0
	map_panel.clip_contents = true
	root_hbox.add_child(map_panel)

	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	map_panel.add_child(svc)
	svc.gui_input.connect(_on_3d_input)

	_viewport_3d = SubViewport.new()
	_viewport_3d.size = Vector2i(1280, 960)
	_viewport_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_3d.transparent_bg = false
	svc.add_child(_viewport_3d)

	# ── Build 3D world ──────────────────────────────────────────────────────
	_world3d_root = Node3D.new()
	_world3d_root.name = "ExploreWorld3D"
	_viewport_3d.add_child(_world3d_root)

	_build_environment()
	_build_camera()
	_build_lights()
	_build_scene_roots()
	_build_3d_tiles()
	_build_3d_walls()
	_build_3d_pois()
	_build_3d_water()
	_build_3d_entities()
	_build_3d_danger_particles()
	_build_3d_ambience()
	_build_3d_street_labels()

	# ── HUD overlay on top of 3D viewport ───────────────────────────────────
	_build_hud(map_panel)

	# ── Right: Info panel ───────────────────────────────────────────────────
	_build_info_panel(root_hbox)
	_show_location_info()

# ── Environment (Phase 7) ──────────────────────────────────────────────────

func _build_environment() -> void:
	_env_node = WorldEnvironment.new()
	var env := Environment.new()

	# Region-specific atmosphere
	var region_envs: Dictionary = {
		"plains":   { "bg": Color(0.55, 0.72, 0.90), "amb": Color(0.35, 0.30, 0.20), "amb_e": 0.8, "fog_col": Color(0.50, 0.60, 0.75), "fog_d": 0.008 },
		"peaks":    { "bg": Color(0.75, 0.80, 0.90), "amb": Color(0.25, 0.28, 0.38), "amb_e": 0.6, "fog_col": Color(0.70, 0.75, 0.85), "fog_d": 0.025 },
		"shadows":  { "bg": Color(0.05, 0.03, 0.10), "amb": Color(0.10, 0.06, 0.18), "amb_e": 0.4, "fog_col": Color(0.06, 0.03, 0.12), "fog_d": 0.04 },
		"glass":    { "bg": Color(0.60, 0.65, 0.80), "amb": Color(0.40, 0.42, 0.55), "amb_e": 1.0, "fog_col": Color(0.55, 0.58, 0.72), "fog_d": 0.01 },
		"isles":    { "bg": Color(0.40, 0.65, 0.85), "amb": Color(0.25, 0.35, 0.45), "amb_e": 0.9, "fog_col": Color(0.35, 0.55, 0.75), "fog_d": 0.012 },
		"metro":    { "bg": Color(0.18, 0.15, 0.25), "amb": Color(0.20, 0.15, 0.28), "amb_e": 0.7, "fog_col": Color(0.12, 0.10, 0.20), "fog_d": 0.015 },
		"astral":   { "bg": Color(0.08, 0.02, 0.18), "amb": Color(0.15, 0.08, 0.30), "amb_e": 0.5, "fog_col": Color(0.10, 0.05, 0.22), "fog_d": 0.02 },
		"terminus": { "bg": Color(0.25, 0.20, 0.30), "amb": Color(0.18, 0.12, 0.22), "amb_e": 0.6, "fog_col": Color(0.20, 0.15, 0.28), "fog_d": 0.018 },
		"titans":   { "bg": Color(0.30, 0.12, 0.06), "amb": Color(0.35, 0.15, 0.08), "amb_e": 0.7, "fog_col": Color(0.25, 0.10, 0.05), "fog_d": 0.02 },
		"sublimini":{ "bg": Color(0.02, 0.01, 0.05), "amb": Color(0.08, 0.04, 0.15), "amb_e": 0.3, "fog_col": Color(0.04, 0.02, 0.10), "fog_d": 0.035 },
	}
	var re: Dictionary = region_envs.get(_region_id, region_envs["metro"])

	env.background_mode = Environment.BG_COLOR
	env.background_color = re["bg"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = re["amb"]
	env.ambient_light_energy = re["amb_e"]
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.12
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 1.2
	env.fog_enabled = true
	env.fog_light_color = re["fog_col"]
	env.fog_density = re["fog_d"]
	env.fog_aerial_perspective = 0.4
	_env_node.environment = env
	_world3d_root.add_child(_env_node)

# ── Camera (Phase 3) ──────────────────────────────────────────────────────

func _build_camera() -> void:
	_cam3d = Camera3D.new()
	_cam3d.name = "ExploreCam"
	_cam3d.fov = 65.0
	_cam3d.near = 0.1
	_cam3d.far = 200.0
	_cam3d.current = true
	_world3d_root.add_child(_cam3d)

func _update_camera_pos() -> void:
	if _cam3d == null:
		return
	var pitch_rad: float = deg_to_rad(_cam_pitch)
	var yaw_rad: float = deg_to_rad(_cam_yaw)

	var horiz: float = _cam_dist * cos(pitch_rad)
	var vert: float = _cam_dist * sin(pitch_rad)

	var offset := Vector3(
		sin(yaw_rad) * horiz,
		vert,
		cos(yaw_rad) * horiz
	)

	var target_pos: Vector3 = _cam_target + offset
	# Smooth camera position
	if _cam_current_pos == Vector3.ZERO:
		_cam_current_pos = target_pos
	else:
		_cam_current_pos = _cam_current_pos.lerp(target_pos, 0.15)

	_cam3d.global_position = _cam_current_pos
	_cam3d.look_at(_cam_target + Vector3(0, 0.8, 0), Vector3.UP)

# ── Lights (Phase 7) ──────────────────────────────────────────────────────

func _build_lights() -> void:
	var region_light: Dictionary = {
		"plains":   { "col": Color(1.0, 0.95, 0.80),  "energy": 1.3, "rot": Vector3(-55, 35, 0) },
		"peaks":    { "col": Color(0.80, 0.85, 1.0),   "energy": 1.0, "rot": Vector3(-60, 20, 0) },
		"shadows":  { "col": Color(0.40, 0.30, 0.60),  "energy": 0.5, "rot": Vector3(-70, -20, 0) },
		"glass":    { "col": Color(0.90, 0.92, 1.0),   "energy": 1.4, "rot": Vector3(-50, 40, 0) },
		"isles":    { "col": Color(1.0, 0.90, 0.75),   "energy": 1.2, "rot": Vector3(-50, 30, 0) },
		"metro":    { "col": Color(0.85, 0.78, 0.95),  "energy": 0.9, "rot": Vector3(-65, 25, 0) },
		"astral":   { "col": Color(0.60, 0.40, 0.90),  "energy": 0.7, "rot": Vector3(-45, 0, 0) },
		"terminus": { "col": Color(0.70, 0.55, 0.80),  "energy": 0.8, "rot": Vector3(-55, -30, 0) },
		"titans":   { "col": Color(1.0, 0.60, 0.30),   "energy": 1.1, "rot": Vector3(-50, 45, 0) },
		"sublimini":{ "col": Color(0.30, 0.20, 0.50),  "energy": 0.4, "rot": Vector3(-60, 10, 0) },
	}
	var rl: Dictionary = region_light.get(_region_id, region_light["metro"])

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_color = rl["col"]
	sun.light_energy = rl["energy"]
	sun.shadow_enabled = true
	sun.rotation_degrees = rl["rot"]
	_world3d_root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_color = Color(rl["col"], 0.5).lerp(Color(0.3, 0.2, 0.4), 0.5)
	fill.light_energy = rl["energy"] * 0.3
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(rl["rot"].x + 90, rl["rot"].y + 180, 0)
	_world3d_root.add_child(fill)

# ── Scene roots ────────────────────────────────────────────────────────────

func _build_scene_roots() -> void:
	_tile_root = Node3D.new();     _tile_root.name = "Tiles";       _world3d_root.add_child(_tile_root)
	_wall_root = Node3D.new();     _wall_root.name = "Walls";       _world3d_root.add_child(_wall_root)
	_poi_root = Node3D.new();      _poi_root.name = "POIs";         _world3d_root.add_child(_poi_root)
	_entity_root = Node3D.new();   _entity_root.name = "Entities";  _world3d_root.add_child(_entity_root)
	_overlay_root = Node3D.new();  _overlay_root.name = "Overlays"; _world3d_root.add_child(_overlay_root)
	_fog_root = Node3D.new();      _fog_root.name = "Fog";          _world3d_root.add_child(_fog_root)
	_particle_root = Node3D.new(); _particle_root.name = "Particles"; _world3d_root.add_child(_particle_root)

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 1 — GROUND PLANE TILES
# ══════════════════════════════════════════════════════════════════════════════

func _build_3d_tiles() -> void:
	for y in range(GRID_H):
		for x in range(GRID_W):
			var t: int = _get_tile(x, y)
			if t == T_WALL or t == T_WALL_RICH or t == T_WALL_POOR:
				continue  # walls handled separately
			if t == T_WATER:
				continue  # water handled separately

			var tile_mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.98, 0.08, 0.98)
			tile_mesh.mesh = box

			var mat := StandardMaterial3D.new()
			mat.albedo_color = _tile_color_3d(x, y)
			mat.roughness = 0.85
			mat.metallic = 0.0

			# Subtle variation based on position
			var seed_val: int = (x * 73856093) ^ (y * 19349663)
			var variation: float = (float(seed_val % 100) / 100.0 - 0.5) * 0.06
			mat.albedo_color = mat.albedo_color.lightened(variation)

			tile_mesh.material_override = mat
			tile_mesh.position = Vector3(float(x) + 0.5, -0.04, float(y) + 0.5)
			_tile_root.add_child(tile_mesh)

			# Road markings — subtle lighter center line
			if t == T_ROAD and (x + y) % 3 == 0:
				var mark := MeshInstance3D.new()
				var mark_box := BoxMesh.new()
				mark_box.size = Vector3(0.12, 0.002, 0.12)
				mark.mesh = mark_box
				var mark_mat := StandardMaterial3D.new()
				mark_mat.albedo_color = mat.albedo_color.lightened(0.15)
				mark_mat.roughness = 0.7
				mark.material_override = mark_mat
				mark.position = Vector3(float(x) + 0.5, 0.001, float(y) + 0.5)
				_tile_root.add_child(mark)

			# Park tiles — add grass tufts
			if t == T_PARK:
				_add_grass_tuft(x, y, seed_val)

			# Plaza tiles — decorative pattern
			if t == T_PLAZA and seed_val % 5 == 0:
				_add_plaza_decoration(x, y, seed_val)

			# Market tiles — stall decorations
			if t == T_MARKET and seed_val % 3 == 0:
				_add_market_stall(x, y, seed_val)

			# Rubble tiles — scattered debris
			if t == T_RUBBLE:
				_add_rubble_debris(x, y, seed_val)

func _tile_color_3d(x: int, y: int) -> Color:
	var t: int = _get_tile(x, y)
	match t:
		T_ROAD:
			return _pc("road", Color(0.35, 0.32, 0.38)) if (x + y) % 2 == 0 \
				else _pc("road_alt", Color(0.37, 0.34, 0.40))
		T_GROUND:    return _pc("ground", Color(0.28, 0.30, 0.22))
		T_DANGER:    return _pc("danger", Color(0.22, 0.32, 0.16))
		T_PLAZA:
			return _pc("plaza", Color(0.42, 0.38, 0.44)) if (x + y) % 2 == 0 \
				else _pc("plaza_alt", Color(0.44, 0.40, 0.46))
		T_PARK:      return _pc("park", Color(0.18, 0.38, 0.14))
		T_RUBBLE:    return _pc("rubble", Color(0.32, 0.26, 0.18))
		T_MARKET:    return _pc("market", Color(0.40, 0.32, 0.20))
		T_POI:
			var poi: Dictionary = _poi_map.get(Vector2i(x, y), {})
			match int(poi.get("type", -1)):
				POI_ACF:        return _pc("poi_acf", Color(0.30, 0.24, 0.44))
				POI_SHOP:       return _pc("poi_shop", Color(0.40, 0.32, 0.18))
				POI_REST:       return _pc("poi_rest", Color(0.24, 0.36, 0.38))
				POI_TAVERN:     return _pc("poi_tavern", Color(0.38, 0.28, 0.16))
				POI_BLACKSMITH: return _pc("poi_smith", Color(0.36, 0.22, 0.16))
				POI_LIBRARY:    return _pc("poi_lib", Color(0.22, 0.22, 0.38))
				POI_BOUNTY:     return _pc("poi_bounty", Color(0.38, 0.30, 0.22))
				POI_FOUNTAIN:   return _pc("water", Color(0.16, 0.28, 0.42))
				POI_EXIT:       return _pc("road", Color(0.35, 0.32, 0.38))
			return _pc("ground", Color(0.28, 0.30, 0.22))
	return _pc("ground", Color(0.28, 0.30, 0.22))

func _add_grass_tuft(x: int, y: int, seed_val: int) -> void:
	var count: int = 2 + (seed_val % 3)
	for i in range(count):
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.04, 0.12 + float(i) * 0.04, 0.04)
		blade.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.15, 0.45 + float(i) * 0.08, 0.10)
		mat.roughness = 0.9
		blade.material_override = mat
		var ox: float = (float((seed_val + i * 37) % 80) / 80.0 - 0.5) * 0.7
		var oz: float = (float((seed_val + i * 53) % 80) / 80.0 - 0.5) * 0.7
		blade.position = Vector3(float(x) + 0.5 + ox, bm.size.y * 0.5, float(y) + 0.5 + oz)
		blade.rotation.y = float((seed_val + i) % 628) / 100.0
		_tile_root.add_child(blade)

func _add_plaza_decoration(x: int, y: int, seed_val: int) -> void:
	var dec := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.10
	cyl.height = 0.03
	dec.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _pc("plaza", Color(0.42, 0.38, 0.44)).lightened(0.2)
	mat.roughness = 0.6
	mat.metallic = 0.1
	dec.material_override = mat
	dec.position = Vector3(float(x) + 0.5, 0.015, float(y) + 0.5)
	_tile_root.add_child(dec)

func _add_market_stall(x: int, y: int, seed_val: int) -> void:
	# Table
	var table := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.6, 0.04, 0.4)
	table.mesh = tb
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.50, 0.35, 0.18)
	mat.roughness = 0.8
	table.material_override = mat
	table.position = Vector3(float(x) + 0.5, 0.35, float(y) + 0.5)
	_tile_root.add_child(table)
	# Legs
	for lx in [-0.25, 0.25]:
		for lz in [-0.15, 0.15]:
			var leg := MeshInstance3D.new()
			var lb := BoxMesh.new()
			lb.size = Vector3(0.04, 0.33, 0.04)
			leg.mesh = lb
			var lmat := StandardMaterial3D.new()
			lmat.albedo_color = Color(0.40, 0.28, 0.14)
			leg.material_override = lmat
			leg.position = Vector3(float(x) + 0.5 + lx, 0.165, float(y) + 0.5 + lz)
			_tile_root.add_child(leg)
	# Canopy
	var canopy := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(0.7, 0.02, 0.5)
	canopy.mesh = cb
	var cmat := StandardMaterial3D.new()
	var canopy_hue: float = float(seed_val % 360) / 360.0
	cmat.albedo_color = Color.from_hsv(canopy_hue, 0.5, 0.7)
	cmat.roughness = 0.7
	canopy.material_override = cmat
	canopy.position = Vector3(float(x) + 0.5, 0.75, float(y) + 0.5)
	_tile_root.add_child(canopy)

func _add_rubble_debris(x: int, y: int, seed_val: int) -> void:
	var count: int = 3 + (seed_val % 4)
	for i in range(count):
		var deb := MeshInstance3D.new()
		var sz: float = 0.06 + float((seed_val + i * 17) % 10) / 100.0
		if (seed_val + i) % 3 == 0:
			var sph := SphereMesh.new()
			sph.radius = sz
			sph.height = sz * 1.5
			deb.mesh = sph
		else:
			var bx := BoxMesh.new()
			bx.size = Vector3(sz, sz * 0.7, sz * 1.2)
			deb.mesh = bx
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.28, 0.20).darkened(float(i) * 0.05)
		mat.roughness = 0.95
		deb.material_override = mat
		var ox: float = (float((seed_val + i * 41) % 80) / 80.0 - 0.5) * 0.7
		var oz: float = (float((seed_val + i * 67) % 80) / 80.0 - 0.5) * 0.7
		deb.position = Vector3(float(x) + 0.5 + ox, sz * 0.35, float(y) + 0.5 + oz)
		deb.rotation = Vector3(float(i) * 0.3, float(i) * 0.7, float(i) * 0.5)
		_tile_root.add_child(deb)

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 2 — WALLS AND BUILDINGS
# ══════════════════════════════════════════════════════════════════════════════

func _build_3d_walls() -> void:
	for y in range(GRID_H):
		for x in range(GRID_W):
			var t: int = _get_tile(x, y)
			if t != T_WALL and t != T_WALL_RICH and t != T_WALL_POOR:
				continue

			var seed_val: int = (x * 73856093) ^ (y * 19349663)
			var wall_height: float = 2.5
			var wall_col: Color = _pc("wall", Color(0.18, 0.15, 0.22))

			if t == T_WALL_RICH:
				wall_height = 3.2
				wall_col = _pc("wall_rich", Color(0.30, 0.24, 0.38))
			elif t == T_WALL_POOR:
				wall_height = 2.0
				wall_col = _pc("wall_poor", Color(0.14, 0.11, 0.16))

			# Check if this is an edge wall (adjacent to walkable tile)
			var is_edge: bool = false
			for d in [Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,0), Vector2i(1,0)]:
				var nt: int = _get_tile(x + d.x, y + d.y)
				if nt != T_WALL and nt != T_WALL_RICH and nt != T_WALL_POOR:
					is_edge = true
					break

			# Base wall block
			var wall := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(1.0, wall_height, 1.0)
			wall.mesh = box
			var mat := StandardMaterial3D.new()
			mat.albedo_color = wall_col
			mat.roughness = 0.9
			mat.metallic = 0.02 if t == T_WALL_RICH else 0.0
			wall.material_override = mat
			wall.position = Vector3(float(x) + 0.5, wall_height * 0.5, float(y) + 0.5)
			_wall_root.add_child(wall)

			# Wall details for edge walls
			if is_edge:
				_add_wall_detail(x, y, t, wall_height, wall_col, seed_val)

	# Building name labels — floating text via 3D labels
	for bld in _building_labels:
		var r: Array = bld["rect"]
		var bname: String = str(bld["name"])
		var cx: float = float(int(r[0])) + float(int(r[2])) * 0.5
		var cy: float = float(int(r[1])) + float(int(r[3])) * 0.5
		var wt: int = int(bld["wall_type"])
		var h: float = 3.5 if wt == T_WALL_RICH else 2.8

		# Signpost with name
		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.03
		post_mesh.bottom_radius = 0.03
		post_mesh.height = h
		post.mesh = post_mesh
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.35, 0.28, 0.20)
		post.material_override = pmat
		post.position = Vector3(cx, h * 0.5, cy)
		_wall_root.add_child(post)

		# Sign board
		var sign_board := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(1.2, 0.3, 0.05)
		sign_board.mesh = sb
		var smat := StandardMaterial3D.new()
		if wt == T_WALL_RICH:
			smat.albedo_color = Color(0.25, 0.20, 0.35)
		elif wt == T_WALL_POOR:
			smat.albedo_color = Color(0.18, 0.14, 0.10)
		else:
			smat.albedo_color = Color(0.22, 0.18, 0.15)
		smat.roughness = 0.7
		sign_board.material_override = smat
		sign_board.position = Vector3(cx, h + 0.15, cy)
		_wall_root.add_child(sign_board)

		# Glow light for signs
		var sign_light := OmniLight3D.new()
		sign_light.light_color = Color(0.9, 0.8, 0.5)
		sign_light.light_energy = 0.4
		sign_light.omni_range = 2.0
		sign_light.position = Vector3(cx, h + 0.3, cy)
		_wall_root.add_child(sign_light)

func _add_wall_detail(x: int, y: int, wall_type: int, height: float, base_col: Color, seed_val: int) -> void:
	# Cornice / ledge at top
	var ledge := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(1.06, 0.08, 1.06)
	ledge.mesh = lb
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = base_col.lightened(0.15)
	lmat.roughness = 0.7
	ledge.material_override = lmat
	ledge.position = Vector3(float(x) + 0.5, height - 0.04, float(y) + 0.5)
	_wall_root.add_child(ledge)

	# Base foundation strip
	var base := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(1.04, 0.15, 1.04)
	base.mesh = bb
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = base_col.darkened(0.2)
	bmat.roughness = 0.95
	base.material_override = bmat
	base.position = Vector3(float(x) + 0.5, 0.075, float(y) + 0.5)
	_wall_root.add_child(base)

	# Rich walls: window-like indents
	if wall_type == T_WALL_RICH and seed_val % 3 == 0:
		var window := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.3, 0.4, 0.06)
		window.mesh = wm
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.45, 0.55, 0.70, 0.6)
		wmat.roughness = 0.2
		wmat.metallic = 0.3
		wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		window.material_override = wmat
		# Place on a face adjacent to walkable tile
		var wx: float = float(x) + 0.5
		var wz: float = float(y) + 0.5
		var wy: float = height * 0.55
		if _is_walkable(x, y - 1):
			wz -= 0.48
		elif _is_walkable(x, y + 1):
			wz += 0.48
		elif _is_walkable(x - 1, y):
			wx -= 0.48
			window.rotation.y = PI * 0.5
		elif _is_walkable(x + 1, y):
			wx += 0.48
			window.rotation.y = PI * 0.5
		window.position = Vector3(wx, wy, wz)
		_wall_root.add_child(window)

		# Window light
		var wl := OmniLight3D.new()
		wl.light_color = Color(1.0, 0.85, 0.55)
		wl.light_energy = 0.3
		wl.omni_range = 1.5
		wl.position = window.position
		_wall_root.add_child(wl)

	# Poor walls: cracks / damage
	if wall_type == T_WALL_POOR and seed_val % 2 == 0:
		var crack := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.02, 0.6, 0.02)
		crack.mesh = cm
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = base_col.darkened(0.4)
		crack.material_override = cmat
		var cx: float = float(x) + 0.5 + (float(seed_val % 40) / 80.0 - 0.25)
		crack.position = Vector3(cx, height * 0.4, float(y) + 0.01)
		crack.rotation.z = (float(seed_val % 30) / 30.0 - 0.5) * 0.4
		_wall_root.add_child(crack)

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 1 CONT — WATER
# ══════════════════════════════════════════════════════════════════════════════

func _build_3d_water() -> void:
	for y in range(GRID_H):
		for x in range(GRID_W):
			if _get_tile(x, y) != T_WATER:
				continue
			var water := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.98, 0.06, 0.98)
			water.mesh = box
			var mat := StandardMaterial3D.new()
			mat.albedo_color = _pc("water", Color(0.12, 0.25, 0.45, 0.75))
			mat.roughness = 0.15
			mat.metallic = 0.4
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			water.material_override = mat
			water.position = Vector3(float(x) + 0.5, -0.12, float(y) + 0.5)
			_tile_root.add_child(water)

			# Subtle water glow
			if (x + y) % 4 == 0:
				var wl := OmniLight3D.new()
				wl.light_color = Color(0.15, 0.30, 0.55)
				wl.light_energy = 0.2
				wl.omni_range = 1.5
				wl.position = Vector3(float(x) + 0.5, 0.1, float(y) + 0.5)
				_tile_root.add_child(wl)

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 5 — POI LANDMARK STRUCTURES
# ══════════════════════════════════════════════════════════════════════════════

func _build_3d_pois() -> void:
	for pos_key in _poi_map:
		var poi: Dictionary = _poi_map[pos_key]
		var pt: int = int(poi["type"])
		var wx: float = float(pos_key.x) + 0.5
		var wz: float = float(pos_key.y) + 0.5

		match pt:
			POI_REST:       _build_poi_rest_house(wx, wz)
			POI_SHOP:       _build_poi_shop(wx, wz)
			POI_TAVERN:     _build_poi_tavern(wx, wz)
			POI_BLACKSMITH: _build_poi_blacksmith(wx, wz)
			POI_LIBRARY:    _build_poi_library(wx, wz)
			POI_BOUNTY:     _build_poi_bounty_board(wx, wz)
			POI_FOUNTAIN:   _build_poi_fountain(wx, wz)
			POI_ACF:        _build_poi_acf(wx, wz)
			POI_EXIT:       _build_poi_exit_gate(wx, wz)

		# Accent light for all POIs
		var light := OmniLight3D.new()
		light.light_color = _poi_light_color(pt)
		light.light_energy = 0.8
		light.omni_range = 3.5
		light.position = Vector3(wx, 1.5, wz)
		_poi_root.add_child(light)

func _poi_light_color(pt: int) -> Color:
	match pt:
		POI_ACF:        return Color(0.50, 0.30, 0.80)
		POI_SHOP:       return Color(0.90, 0.75, 0.30)
		POI_REST:       return Color(0.30, 0.80, 0.40)
		POI_TAVERN:     return Color(0.90, 0.60, 0.20)
		POI_BLACKSMITH: return Color(0.90, 0.50, 0.20)
		POI_LIBRARY:    return Color(0.30, 0.70, 0.90)
		POI_BOUNTY:     return Color(0.90, 0.40, 0.20)
		POI_FOUNTAIN:   return Color(0.30, 0.50, 0.90)
		POI_EXIT:       return Color(0.60, 0.60, 0.60)
	return Color(0.5, 0.5, 0.5)

func _build_poi_rest_house(wx: float, wz: float) -> void:
	# House body
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.6, 0.7)
	body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.45, 0.30)
	mat.roughness = 0.85
	body.material_override = mat
	body.position = Vector3(wx, 0.3, wz)
	_poi_root.add_child(body)
	# Roof (pyramid via rotated box)
	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.01
	rm.bottom_radius = 0.55
	rm.height = 0.5
	rm.radial_segments = 4
	roof.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.35, 0.55, 0.30)
	rmat.roughness = 0.8
	roof.material_override = rmat
	roof.position = Vector3(wx, 0.85, wz)
	_poi_root.add_child(roof)
	# Chimney
	var chimney := MeshInstance3D.new()
	var chm := BoxMesh.new()
	chm.size = Vector3(0.1, 0.3, 0.1)
	chimney.mesh = chm
	var chmat := StandardMaterial3D.new()
	chmat.albedo_color = Color(0.40, 0.30, 0.22)
	chimney.material_override = chmat
	chimney.position = Vector3(wx + 0.2, 1.05, wz + 0.1)
	_poi_root.add_child(chimney)
	# Door
	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.15, 0.3, 0.02)
	door.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.30, 0.18, 0.08)
	door.material_override = dmat
	door.position = Vector3(wx, 0.15, wz - 0.35)
	_poi_root.add_child(door)

func _build_poi_shop(wx: float, wz: float) -> void:
	# Counter
	var counter := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.7, 0.4, 0.35)
	counter.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.40, 0.20)
	counter.material_override = mat
	counter.position = Vector3(wx, 0.2, wz)
	_poi_root.add_child(counter)
	# Awning
	var awning := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.9, 0.03, 0.6)
	awning.mesh = am
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(0.85, 0.70, 0.20)
	awning.material_override = amat
	awning.position = Vector3(wx, 0.85, wz)
	_poi_root.add_child(awning)
	# Poles
	for px in [-0.35, 0.35]:
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.02; pm.bottom_radius = 0.02; pm.height = 0.85
		pole.mesh = pm
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.40, 0.30, 0.15)
		pole.material_override = pmat
		pole.position = Vector3(wx + px, 0.425, wz - 0.25)
		_poi_root.add_child(pole)
	# Goods on counter
	for i in range(3):
		var good := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(0.08, 0.10, 0.08)
		good.mesh = gm
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = Color.from_hsv(float(i) * 0.3, 0.6, 0.7)
		good.material_override = gmat
		good.position = Vector3(wx - 0.2 + float(i) * 0.2, 0.45, wz)
		_poi_root.add_child(good)

func _build_poi_tavern(wx: float, wz: float) -> void:
	# Building
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 0.7, 0.7)
	body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.50, 0.35, 0.18)
	body.material_override = mat
	body.position = Vector3(wx, 0.35, wz)
	_poi_root.add_child(body)
	# Sloped roof
	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.01; rm.bottom_radius = 0.60; rm.height = 0.45; rm.radial_segments = 4
	roof.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.55, 0.30, 0.12)
	roof.material_override = rmat
	roof.position = Vector3(wx, 0.92, wz)
	_poi_root.add_child(roof)
	# Hanging sign
	var sign := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.35, 0.2, 0.03)
	sign.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.85, 0.55, 0.15)
	smat.emission_enabled = true
	smat.emission = Color(0.85, 0.55, 0.15)
	smat.emission_energy_multiplier = 0.3
	sign.material_override = smat
	sign.position = Vector3(wx + 0.5, 0.6, wz)
	_poi_root.add_child(sign)

func _build_poi_blacksmith(wx: float, wz: float) -> void:
	# Forge base
	var forge := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.5, 0.4, 0.5)
	forge.mesh = fm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.22, 0.18)
	forge.material_override = mat
	forge.position = Vector3(wx, 0.2, wz)
	_poi_root.add_child(forge)
	# Chimney / smoke stack
	var stack := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.15; sm.bottom_radius = 0.18; sm.height = 1.2
	stack.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.25, 0.18, 0.14)
	stack.material_override = smat
	stack.position = Vector3(wx + 0.15, 0.6, wz + 0.15)
	_poi_root.add_child(stack)
	# Fire glow inside forge
	var fire_light := OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.55, 0.15)
	fire_light.light_energy = 1.2
	fire_light.omni_range = 2.5
	fire_light.position = Vector3(wx, 0.3, wz)
	_poi_root.add_child(fire_light)
	# Anvil
	var anvil := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.18, 0.2, 0.12)
	anvil.mesh = am
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(0.35, 0.35, 0.38)
	amat.metallic = 0.6
	amat.roughness = 0.4
	anvil.material_override = amat
	anvil.position = Vector3(wx - 0.3, 0.1, wz - 0.2)
	_poi_root.add_child(anvil)

func _build_poi_library(wx: float, wz: float) -> void:
	# Tall building
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.65, 1.0, 0.65)
	body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.32, 0.50)
	body.material_override = mat
	body.position = Vector3(wx, 0.5, wz)
	_poi_root.add_child(body)
	# Dome top
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.35; dm.height = 0.4
	dome.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.25, 0.50, 0.65)
	dmat.metallic = 0.2
	dome.material_override = dmat
	dome.position = Vector3(wx, 1.15, wz)
	_poi_root.add_child(dome)
	# Window glow
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.30, 0.65, 0.90)
	glow.light_energy = 0.6
	glow.omni_range = 2.0
	glow.position = Vector3(wx, 0.6, wz - 0.35)
	_poi_root.add_child(glow)

func _build_poi_bounty_board(wx: float, wz: float) -> void:
	# Post
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.04; pm.bottom_radius = 0.04; pm.height = 1.0
	post.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.40, 0.30, 0.18)
	post.material_override = pmat
	post.position = Vector3(wx, 0.5, wz)
	_poi_root.add_child(post)
	# Board
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.5, 0.05)
	board.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.55, 0.42, 0.22)
	board.material_override = bmat
	board.position = Vector3(wx, 0.85, wz)
	_poi_root.add_child(board)
	# Paper notices
	for i in range(3):
		var paper := MeshInstance3D.new()
		var nm := BoxMesh.new()
		nm.size = Vector3(0.12, 0.15, 0.005)
		paper.mesh = nm
		var nmat := StandardMaterial3D.new()
		nmat.albedo_color = Color(0.90, 0.85, 0.70)
		paper.material_override = nmat
		paper.position = Vector3(wx - 0.15 + float(i) * 0.15, 0.85 + float(i % 2) * 0.08, wz - 0.028)
		paper.rotation.z = (float(i) - 1.0) * 0.1
		_poi_root.add_child(paper)

func _build_poi_fountain(wx: float, wz: float) -> void:
	# Basin
	var basin := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.40; bm.bottom_radius = 0.45; bm.height = 0.3
	basin.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.50, 0.48, 0.52)
	mat.roughness = 0.5
	mat.metallic = 0.15
	basin.material_override = mat
	basin.position = Vector3(wx, 0.15, wz)
	_poi_root.add_child(basin)
	# Water inside
	var water := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.35; wm.bottom_radius = 0.35; wm.height = 0.08
	water.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.20, 0.45, 0.70, 0.7)
	wmat.roughness = 0.1
	wmat.metallic = 0.5
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = wmat
	water.position = Vector3(wx, 0.26, wz)
	_poi_root.add_child(water)
	# Center spout
	var spout := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.03; sm.bottom_radius = 0.06; sm.height = 0.6
	spout.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.55, 0.52, 0.56)
	smat.metallic = 0.3
	spout.material_override = smat
	spout.position = Vector3(wx, 0.45, wz)
	_poi_root.add_child(spout)
	# Water light
	var wl := OmniLight3D.new()
	wl.light_color = Color(0.25, 0.50, 0.85)
	wl.light_energy = 0.5
	wl.omni_range = 2.0
	wl.position = Vector3(wx, 0.4, wz)
	_poi_root.add_child(wl)

func _build_poi_acf(wx: float, wz: float) -> void:
	# Larger building
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 0.8, 0.8)
	body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.22, 0.42)
	body.material_override = mat
	body.position = Vector3(wx, 0.4, wz)
	_poi_root.add_child(body)
	# Flat roof with antenna
	var roof := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(0.85, 0.06, 0.85)
	roof.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.35, 0.28, 0.50)
	rmat.metallic = 0.1
	roof.material_override = rmat
	roof.position = Vector3(wx, 0.83, wz)
	_poi_root.add_child(roof)
	# Antenna
	var ant := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.01; am.bottom_radius = 0.02; am.height = 0.5
	ant.mesh = am
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(0.50, 0.50, 0.55)
	amat.metallic = 0.5
	ant.material_override = amat
	ant.position = Vector3(wx + 0.25, 1.1, wz - 0.2)
	_poi_root.add_child(ant)
	# Emblem glow
	var emblem := MeshInstance3D.new()
	var em := SphereMesh.new()
	em.radius = 0.08; em.height = 0.16
	emblem.mesh = em
	var emat := StandardMaterial3D.new()
	emat.albedo_color = Color(0.50, 0.30, 0.85)
	emat.emission_enabled = true
	emat.emission = Color(0.50, 0.30, 0.85)
	emat.emission_energy_multiplier = 1.5
	emblem.material_override = emat
	emblem.position = Vector3(wx, 0.65, wz - 0.41)
	_poi_root.add_child(emblem)

func _build_poi_exit_gate(wx: float, wz: float) -> void:
	# Two pillars
	for px in [-0.25, 0.25]:
		var pillar := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.15, 1.4, 0.15)
		pillar.mesh = pm
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.45, 0.42, 0.48)
		pmat.roughness = 0.6
		pillar.material_override = pmat
		pillar.position = Vector3(wx + px, 0.7, wz)
		_poi_root.add_child(pillar)
	# Arch top
	var arch := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.65, 0.12, 0.18)
	arch.mesh = am
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(0.48, 0.45, 0.52)
	amat.roughness = 0.6
	arch.material_override = amat
	arch.position = Vector3(wx, 1.35, wz)
	_poi_root.add_child(arch)

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 4 — PLAYER AND FOLLOWER 3D MODELS
# ══════════════════════════════════════════════════════════════════════════════

func _build_3d_entities() -> void:
	var handles: Array = GameState.get_active_handles()

	# Player
	_player_node = _create_entity_model(0, handles, true)
	_player_node.position = _player_world_pos
	_entity_root.add_child(_player_node)

	# Selection ring
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.30
	tm.outer_radius = 0.42
	tm.rings = 12
	tm.ring_segments = 16
	ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.95, 0.80, 0.20)
	rmat.emission_enabled = true
	rmat.emission = Color(0.95, 0.80, 0.20)
	rmat.emission_energy_multiplier = 1.5
	ring.material_override = rmat
	ring.position = Vector3(0, 0.02, 0)
	ring.rotation.x = -PI * 0.5
	_player_node.add_child(ring)

	# Followers
	_follower_nodes.clear()
	for i in range(1, handles.size()):
		var fnode := _create_entity_model(i, handles, false)
		fnode.visible = false
		_entity_root.add_child(fnode)
		_follower_nodes.append(fnode)

func _create_entity_model(idx: int, handles: Array, is_player: bool) -> Node3D:
	var root := Node3D.new()

	if idx < handles.size():
		var h: int = handles[idx]
		var lineage: String = RimvaleAPI.engine.get_character_lineage_name(h)
		var weapon: String = str(RimvaleAPI.engine.get_char_dict(h).get("weapon_name", "None"))
		var armor: String = str(RimvaleAPI.engine.get_char_dict(h).get("armor_name", "None"))
		var shield: String = str(RimvaleAPI.engine.get_char_dict(h).get("shield_name", "None"))
		var team_col: Color = Color(0.20, 0.55, 0.92) if is_player else Color(0.20, 0.78, 0.40)

		var model: Node3D = CharacterModelBuilder.build_sprite_model(
			lineage, weapon, armor, shield, 0.55, team_col)
		if model != null:
			model.position.y = 0.0
			root.add_child(model)
		else:
			# Fallback capsule
			var capsule := MeshInstance3D.new()
			var cm := CapsuleMesh.new()
			cm.radius = 0.18; cm.height = 0.8
			capsule.mesh = cm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = team_col
			capsule.material_override = mat
			capsule.position.y = 0.4
			root.add_child(capsule)

	# Entity light
	var elight := OmniLight3D.new()
	elight.light_color = Color(0.20, 0.55, 0.92) if is_player else Color(0.20, 0.78, 0.40)
	elight.light_energy = 0.4
	elight.omni_range = 2.0
	elight.position.y = 0.8
	root.add_child(elight)

	return root

func _update_player_3d_pos() -> void:
	if _player_node != null and is_instance_valid(_player_node):
		_player_node.position.x = _player_world_pos.x
		_player_node.position.z = _player_world_pos.z
		# Face movement direction
		if _player_moving:
			var dir3: Vector3 = _player_target_pos - _player_world_pos
			if dir3.length_squared() > 0.001:
				_player_facing = atan2(dir3.x, dir3.z)
				_player_node.rotation.y = _player_facing

func _update_follower_3d_positions() -> void:
	for i in range(_follower_nodes.size()):
		var fnode = _follower_nodes[i]
		if not is_instance_valid(fnode):
			continue
		if i < _trail.size():
			fnode.visible = true
			var tpos: Vector3 = _tile_to_world(_trail[i].x, _trail[i].y)
			fnode.position = fnode.position.lerp(tpos, 0.15)
			# Face toward the entity ahead
			var ahead_pos: Vector3 = _player_world_pos if i == 0 else _tile_to_world(_trail[i - 1].x, _trail[i - 1].y)
			var dir: Vector3 = ahead_pos - fnode.position
			if dir.length_squared() > 0.01:
				fnode.rotation.y = atan2(dir.x, dir.z)
		else:
			fnode.visible = false

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 6 — DANGER ZONE PARTICLES
# ══════════════════════════════════════════════════════════════════════════════

var _danger_tile_meshes: Array = []

func _build_3d_danger_particles() -> void:
	_danger_tile_meshes.clear()
	for y in range(GRID_H):
		for x in range(GRID_W):
			if _get_tile(x, y) != T_DANGER:
				continue

			# Store reference to the ground tile for pulsing
			# We'll find it by index (danger tiles have their mesh in _tile_root)

			# Mist particles on danger tiles
			var seed_val: int = (x * 31 + y * 47)
			if seed_val % 2 == 0:
				var mist := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.15; sm.height = 0.2
				mist.mesh = sm
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.40, 0.15, 0.20, 0.25)
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.emission_enabled = true
				mat.emission = Color(0.50, 0.15, 0.10)
				mat.emission_energy_multiplier = 0.4
				mist.material_override = mat
				var ox: float = (float(seed_val % 60) / 60.0 - 0.5) * 0.5
				var oz: float = (float((seed_val * 3) % 60) / 60.0 - 0.5) * 0.5
				mist.position = Vector3(float(x) + 0.5 + ox, 0.15, float(y) + 0.5 + oz)
				_particle_root.add_child(mist)
				_danger_tile_meshes.append(mist)

			# Low red light on some danger tiles
			if seed_val % 4 == 0:
				var dl := OmniLight3D.new()
				dl.light_color = Color(0.80, 0.20, 0.15)
				dl.light_energy = 0.3
				dl.omni_range = 1.5
				dl.position = Vector3(float(x) + 0.5, 0.3, float(y) + 0.5)
				_particle_root.add_child(dl)

func _update_danger_pulse_3d() -> void:
	var pulse: float = (sin(_danger_flash_timer * 3.0) + 1.0) * 0.5
	for mist in _danger_tile_meshes:
		if is_instance_valid(mist):
			var mat = mist.material_override
			if mat != null:
				mat.albedo_color.a = 0.15 + pulse * 0.20
				mat.emission_energy_multiplier = 0.3 + pulse * 0.5

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 7 — AMBIENT PARTICLES & ATMOSPHERE
# ══════════════════════════════════════════════════════════════════════════════

func _build_3d_ambience() -> void:
	# Region-specific ambient effects
	match _region_id:
		"plains":
			_add_ambient_dust(Color(0.85, 0.80, 0.50, 0.15), 40)
		"peaks":
			_add_ambient_dust(Color(0.90, 0.92, 1.0, 0.20), 60)  # snow-like
		"shadows":
			_add_ambient_dust(Color(0.30, 0.15, 0.50, 0.12), 30)
		"titans":
			_add_ambient_embers()
		"astral":
			_add_ambient_stars()
		"isles":
			_add_ambient_dust(Color(0.60, 0.70, 0.85, 0.10), 25)  # sea mist
		"terminus":
			_add_ambient_dust(Color(0.50, 0.40, 0.60, 0.15), 50)  # storm particles
		_:
			_add_ambient_dust(Color(0.60, 0.55, 0.50, 0.08), 20)

	# Torches/lanterns along walls near walkable areas
	_add_wall_torches()

func _add_ambient_dust(col: Color, count: int) -> void:
	for i in range(count):
		var dust := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.03; sm.height = 0.06
		dust.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(col.r, col.g, col.b)
		mat.emission_energy_multiplier = 0.3
		dust.material_override = mat
		dust.position = Vector3(
			randf() * GRID_W,
			0.5 + randf() * 3.0,
			randf() * GRID_H
		)
		_particle_root.add_child(dust)

func _add_ambient_embers() -> void:
	for i in range(35):
		var ember := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.02; sm.height = 0.04
		ember.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.50, 0.10, 0.6)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.45, 0.05)
		mat.emission_energy_multiplier = 2.0
		ember.material_override = mat
		ember.position = Vector3(randf() * GRID_W, 0.3 + randf() * 2.5, randf() * GRID_H)
		_particle_root.add_child(ember)

func _add_ambient_stars() -> void:
	for i in range(50):
		var star := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.015; sm.height = 0.03
		star.mesh = sm
		var mat := StandardMaterial3D.new()
		var hue: float = randf() * 0.3 + 0.6  # purple-blue range
		mat.albedo_color = Color.from_hsv(hue, 0.5, 0.9, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color.from_hsv(hue, 0.4, 1.0)
		mat.emission_energy_multiplier = 1.5
		star.material_override = mat
		star.position = Vector3(randf() * GRID_W, 1.0 + randf() * 4.0, randf() * GRID_H)
		_particle_root.add_child(star)

func _add_wall_torches() -> void:
	for y in range(GRID_H):
		for x in range(GRID_W):
			var t: int = _get_tile(x, y)
			if t != T_WALL and t != T_WALL_RICH and t != T_WALL_POOR:
				continue
			# Only on wall tiles adjacent to walkable, and sparsely
			var seed_val: int = (x * 73856093) ^ (y * 19349663)
			if seed_val % 7 != 0:
				continue
			var is_edge: bool = false
			for d in [Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,0), Vector2i(1,0)]:
				if _is_walkable(x + d.x, y + d.y):
					is_edge = true
					break
			if not is_edge:
				continue

			var wall_h: float = 2.5 if t == T_WALL else (3.2 if t == T_WALL_RICH else 2.0)
			# Torch bracket
			var bracket := MeshInstance3D.new()
			var bm := CylinderMesh.new()
			bm.top_radius = 0.02; bm.bottom_radius = 0.025; bm.height = 0.25
			bracket.mesh = bm
			var bmat := StandardMaterial3D.new()
			bmat.albedo_color = Color(0.35, 0.25, 0.15)
			bracket.material_override = bmat
			bracket.position = Vector3(float(x) + 0.5, wall_h * 0.6, float(y) + 0.5)
			_particle_root.add_child(bracket)

			# Flame (emissive sphere)
			var flame := MeshInstance3D.new()
			var fm := SphereMesh.new()
			fm.radius = 0.06; fm.height = 0.12
			flame.mesh = fm
			var fmat := StandardMaterial3D.new()
			fmat.albedo_color = Color(1.0, 0.70, 0.20)
			fmat.emission_enabled = true
			fmat.emission = Color(1.0, 0.65, 0.15)
			fmat.emission_energy_multiplier = 2.5
			flame.material_override = fmat
			flame.position = Vector3(float(x) + 0.5, wall_h * 0.6 + 0.15, float(y) + 0.5)
			_particle_root.add_child(flame)

			# Torch light
			var tl := OmniLight3D.new()
			tl.light_color = Color(1.0, 0.75, 0.35)
			tl.light_energy = 0.6
			tl.omni_range = 3.0
			tl.position = flame.position
			_particle_root.add_child(tl)

# ── Street labels in 3D ───────────────────────────────────────────────────

func _build_3d_street_labels() -> void:
	# Street labels as small floating markers (signpost + glow)
	for sl in _street_labels:
		var sx: float = float(sl["x"]) + 0.5
		var sy: float = float(sl["y"]) + 0.5
		# Small marker post
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.015; pm.bottom_radius = 0.02; pm.height = 0.6
		post.mesh = pm
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.40, 0.35, 0.30)
		post.material_override = pmat
		post.position = Vector3(sx, 0.3, sy)
		_overlay_root.add_child(post)
		# Sign plate
		var plate := MeshInstance3D.new()
		var plm := BoxMesh.new()
		plm.size = Vector3(0.4, 0.12, 0.02)
		plate.mesh = plm
		var plmat := StandardMaterial3D.new()
		plmat.albedo_color = Color(0.30, 0.28, 0.35)
		plate.material_override = plmat
		plate.position = Vector3(sx, 0.6, sy)
		if bool(sl.get("vertical", false)):
			plate.rotation.y = PI * 0.5
		_overlay_root.add_child(plate)

# ══════════════════════════════════════════════════════════════════════════════
#  HUD OVERLAY + INFO PANEL (preserved from original)
# ══════════════════════════════════════════════════════════════════════════════

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
	hbox.add_child(RimvaleUtils.label("WASD / Arrows to move  |  Right-drag to rotate  |  Scroll to zoom", 11, RimvaleColors.TEXT_DIM))

	var exit_btn := RimvaleUtils.button("← Leave", RimvaleColors.TEXT_GRAY, 32, 12)
	exit_btn.custom_minimum_size.x = 80
	exit_btn.pressed.connect(_on_exit)
	hbox.add_child(exit_btn)

	# Minimap in bottom-left corner
	_build_minimap(parent)

func _build_minimap(parent: Control) -> void:
	var minimap_size: int = 140
	var mm_panel := PanelContainer.new()
	mm_panel.anchor_left = 0.0; mm_panel.anchor_top = 1.0
	mm_panel.anchor_right = 0.0; mm_panel.anchor_bottom = 1.0
	mm_panel.offset_left = 8; mm_panel.offset_top = -(minimap_size + 8)
	mm_panel.offset_right = minimap_size + 8; mm_panel.offset_bottom = -8
	var mm_style := StyleBoxFlat.new()
	mm_style.bg_color = Color(0.02, 0.01, 0.05, 0.85)
	mm_style.border_width_left = 1; mm_style.border_width_right = 1
	mm_style.border_width_top = 1; mm_style.border_width_bottom = 1
	mm_style.border_color = Color(0.30, 0.25, 0.40, 0.6)
	mm_style.corner_radius_top_left = 4; mm_style.corner_radius_top_right = 4
	mm_style.corner_radius_bottom_left = 4; mm_style.corner_radius_bottom_right = 4
	mm_style.content_margin_left = 2; mm_style.content_margin_right = 2
	mm_style.content_margin_top = 2; mm_style.content_margin_bottom = 2
	mm_panel.add_theme_stylebox_override("panel", mm_style)
	mm_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(mm_panel)

	var mm_canvas := Control.new()
	mm_canvas.custom_minimum_size = Vector2(minimap_size, minimap_size)
	mm_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mm_panel.add_child(mm_canvas)

	var tile_w: float = float(minimap_size) / float(GRID_W)
	var tile_h: float = float(minimap_size) / float(GRID_H)

	for y in range(GRID_H):
		for x in range(GRID_W):
			var rect := ColorRect.new()
			rect.position = Vector2(x * tile_w, y * tile_h)
			rect.size = Vector2(tile_w, tile_h)
			var t: int = _get_tile(x, y)
			match t:
				T_WALL, T_WALL_RICH, T_WALL_POOR:
					rect.color = Color(0.12, 0.10, 0.15)
				T_WATER:
					rect.color = Color(0.10, 0.20, 0.40)
				T_DANGER:
					rect.color = Color(0.30, 0.15, 0.10)
				T_POI:
					rect.color = _poi_minimap_color(_poi_map.get(Vector2i(x, y), {}))
				_:
					rect.color = Color(0.22, 0.20, 0.25)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mm_canvas.add_child(rect)

	# Player dot on minimap — will be updated
	var player_dot := ColorRect.new()
	player_dot.name = "PlayerDot"
	player_dot.color = Color(0.95, 0.85, 0.20)
	player_dot.size = Vector2(tile_w * 1.5, tile_h * 1.5)
	player_dot.position = Vector2(_player_pos.x * tile_w - tile_w * 0.25,
								   _player_pos.y * tile_h - tile_h * 0.25)
	player_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mm_canvas.add_child(player_dot)

func _poi_minimap_color(poi: Dictionary) -> Color:
	match int(poi.get("type", -1)):
		POI_ACF:        return Color(0.45, 0.30, 0.70)
		POI_SHOP:       return Color(0.80, 0.65, 0.20)
		POI_REST:       return Color(0.25, 0.65, 0.35)
		POI_TAVERN:     return Color(0.75, 0.50, 0.15)
		POI_BLACKSMITH: return Color(0.70, 0.40, 0.20)
		POI_LIBRARY:    return Color(0.25, 0.55, 0.75)
		POI_BOUNTY:     return Color(0.75, 0.35, 0.15)
		POI_FOUNTAIN:   return Color(0.20, 0.40, 0.70)
		POI_EXIT:       return Color(0.50, 0.50, 0.50)
	return Color(0.22, 0.20, 0.25)

func _update_minimap_player() -> void:
	# Find the player dot on the minimap and update its position
	var mm_panels := get_tree().get_nodes_in_group("minimap")  # won't work, search manually
	# Walk through children to find PlayerDot
	for child in get_children():
		_find_and_update_player_dot(child)

func _find_and_update_player_dot(node: Node) -> void:
	if node.name == "PlayerDot" and node is ColorRect:
		var minimap_size: float = 140.0
		var tile_w: float = minimap_size / float(GRID_W)
		var tile_h: float = minimap_size / float(GRID_H)
		node.position = Vector2(_player_pos.x * tile_w - tile_w * 0.25,
								_player_pos.y * tile_h - tile_h * 0.25)
		return
	for child in node.get_children():
		_find_and_update_player_dot(child)

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
#  INPUT — keyboard movement + 3D camera control
# ══════════════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	if _player_moving:
		return  # ignore input during movement animation
	if event is InputEventKey and event.pressed and not event.echo:
		var dir := Vector2i.ZERO
		match event.keycode:
			KEY_W, KEY_UP:    dir = Vector2i(0, -1)
			KEY_S, KEY_DOWN:  dir = Vector2i(0,  1)
			KEY_A, KEY_LEFT:  dir = Vector2i(-1, 0)
			KEY_D, KEY_RIGHT: dir = Vector2i( 1, 0)
			KEY_HOME:
				_cam_yaw = 0.0
				_cam_pitch = 40.0
				_cam_dist = 10.0
		if dir != Vector2i.ZERO:
			_try_move(dir)
			var vp := get_viewport()
			if vp != null:
				vp.set_input_as_handled()

func _on_3d_input(event: InputEvent) -> void:
	# Camera rotation via right-mouse drag
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cam_dragging = event.pressed
			_cam_drag_start = event.position
		# Scroll zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_dist = clampf(_cam_dist - 1.0, 5.0, 25.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_dist = clampf(_cam_dist + 1.0, 5.0, 25.0)
		# Left click for tile interaction
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_3d_click(event.position)

	elif event is InputEventMouseMotion and _cam_dragging:
		var delta: Vector2 = event.relative
		_cam_yaw += delta.x * 0.3
		_cam_pitch = clampf(_cam_pitch - delta.y * 0.3, 15.0, 75.0)
		if _cam_yaw > 360.0: _cam_yaw -= 360.0
		if _cam_yaw < 0.0: _cam_yaw += 360.0

func _on_3d_click(screen_pos: Vector2) -> void:
	if _player_moving:
		return
	# Raycast from camera to find clicked tile
	if _cam3d == null:
		return
	var from: Vector3 = _cam3d.project_ray_origin(screen_pos)
	var dir: Vector3 = _cam3d.project_ray_normal(screen_pos)

	# Intersect with Y=0 ground plane
	if absf(dir.y) < 0.001:
		return
	var t: float = -from.y / dir.y
	if t < 0:
		return
	var hit: Vector3 = from + dir * t
	var tx: int = int(floor(hit.x))
	var ty: int = int(floor(hit.z))

	if tx < 0 or tx >= GRID_W or ty < 0 or ty >= GRID_H:
		return

	# Move one step toward clicked tile
	var diff := Vector2i(tx, ty) - _player_pos
	if diff == Vector2i.ZERO:
		return
	var move_dir := Vector2i.ZERO
	if abs(diff.x) >= abs(diff.y):
		move_dir.x = 1 if diff.x > 0 else -1
	else:
		move_dir.y = 1 if diff.y > 0 else -1
	_try_move(move_dir)

# ══════════════════════════════════════════════════════════════════════════════
#  MOVEMENT (game logic preserved, 3D animation added)
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

	# Start smooth 3D movement
	_player_target_pos = _tile_to_world(new_pos.x, new_pos.y)
	_player_moving = true
	_move_lerp_t = 0.0

	# Update minimap
	_update_minimap_player()

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
	_poi_actions_taken = 0

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
	_info_vbox.add_child(RimvaleUtils.label("CONTROLS", 13, RimvaleColors.TEXT_GRAY))
	_info_vbox.add_child(RimvaleUtils.label("WASD / Arrows — Move", 10, RimvaleColors.TEXT_DIM))
	_info_vbox.add_child(RimvaleUtils.label("Right-drag — Rotate camera", 10, RimvaleColors.TEXT_DIM))
	_info_vbox.add_child(RimvaleUtils.label("Scroll — Zoom in/out", 10, RimvaleColors.TEXT_DIM))
	_info_vbox.add_child(RimvaleUtils.label("Home — Reset camera", 10, RimvaleColors.TEXT_DIM))
	_info_vbox.add_child(RimvaleUtils.label("Click — Move toward tile", 10, RimvaleColors.TEXT_DIM))

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
			_regen_party_ap()
			return h
	return -1

func _regen_party_ap() -> void:
	for h in GameState.get_active_handles():
		var cd: Dictionary = RimvaleAPI.engine.get_char_dict(h)
		if cd == null:
			continue
		var stats: Array = cd.get("stats", [1, 1, 1, 1, 1])
		var str_val: int = maxi(1, int(stats[0]))
		var bonus: int = 0
		var feats: Dictionary = cd.get("feats", {})
		for feat_name in feats.keys():
			var fl: String = str(feat_name).to_lower()
			if "ap regen" in fl or "endurance" in fl or "second wind" in fl:
				bonus += 1
		var regen: int = str_val + bonus
		var ap: int  = int(cd.get("ap", 0))
		var cap: int = int(cd.get("max_ap", 10))
		cd["ap"] = mini(ap + regen, cap)

func _ap_cost_str() -> String:
	return "(%d AP)" % _next_action_ap_cost()

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
#  POI ICON / LABEL HELPERS (preserved for info panel use)
# ══════════════════════════════════════════════════════════════════════════════

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
