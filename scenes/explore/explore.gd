## explore.gd
## 3D overworld exploration — data-driven regional sandbox.
## Loads map configuration from ExploreMaps for the current subregion.
## Player moves on a tile grid rendered as a full 3D environment with
## chase camera, procedural buildings, POI landmarks, and atmosphere.
## Danger zones trigger random encounters (dungeon dives).

extends Control

const _WS = preload("res://autoload/world_systems.gd")

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
const POI_LEDGER: int     = 9
const POI_TOWN_HALL: int  = 10
const POI_GUILD: int      = 11

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
const WorldData = preload("res://autoload/world_data.gd")
const NpcBackstories = preload("res://autoload/npc_backstories.gd")

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

# ── Time-of-day system (replaces AP for region actions) ─────────────────────
var _current_hour: int = 6   # 6 = 6:00 AM, range 0-23

# ── Hidden caches ──────────────────────────────────────────────────────────
var _hidden_cache_map: Dictionary = {}   # Vector2i → cache data dict
var _cache_markers: Dictionary = {}      # Vector2i → Node3D (sparkle)
var _field_med_used: bool = false        # One field medicine per map visit

# ── Random NPCs ────────────────────────────────────────────────────────────
var _spawned_npcs: Array = []            # Array of npc data dicts with "pos" Vector2i added
var _npc_markers: Dictionary = {}        # Vector2i → Node3D marker
var _npc_positions: Dictionary = {}      # Vector2i → npc data dict (for quick lookup)
var _skills_used_this_poi: Array = []    # Skills used at current POI (for combo detection)

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
var _cam_free: bool = false           # true when WASD has panned camera away from party

# ── Player 3D state ────────────────────────────────────────────────────────
var _player_node: Node3D
var _follower_nodes: Array = []
var _player_world_pos: Vector3 = Vector3.ZERO
var _player_start_pos: Vector3 = Vector3.ZERO
var _player_target_pos: Vector3 = Vector3.ZERO
var _player_moving: bool = false
var _player_facing: float = 0.0  # yaw radians
var _move_lerp_t: float = 0.0

# ── Auto-walk pathfinding state ────────────────────────────────────────────
var _auto_path: Array = []            # Array[Vector2i] — remaining tiles to walk
var _auto_path_active: bool = false   # true while auto-walking
var _path_markers: Array = []         # Array[Node3D] — glowing path tiles

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
	# Use saved return position if coming back from a dungeon, otherwise use map spawn
	if GameState.explore_return_active:
		_player_pos = GameState.explore_return_pos
		GameState.explore_return_active = false
	else:
		_player_pos = _map_data.get("player_spawn", Vector2i(15, 19))

	# Restore time of day from GameState
	_current_hour = GameState.explore_current_hour

	var handles: Array = GameState.get_active_handles()
	_trail_max = maxi(0, handles.size() - 1)
	_trail.clear()

	_generate_map()
	_build_ui()
	_init_hidden_caches()
	_init_random_npcs()

	# Reset social cooldowns when entering a new subregion
	GameState.social_cooldowns.clear()

	# Set initial camera target on player
	_player_world_pos = _tile_to_world(_player_pos.x, _player_pos.y)
	_player_start_pos = _player_world_pos
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
		var spd: float = 8.0 if _auto_path_active else 5.0  # faster during auto-walk
		_move_lerp_t += delta * spd
		if _move_lerp_t >= 1.0:
			var overflow: float = _move_lerp_t - 1.0
			_player_moving = false
			_player_world_pos = _player_target_pos
			if _auto_path_active:
				# Continue auto-walk — carry over timing overflow for seamless chaining
				_auto_walk_next_step()
				if _player_moving and overflow > 0.0:
					_move_lerp_t = overflow  # seamless continuation
			else:
				# If a direction key is still held, immediately start the next move
				_poll_held_direction()
		else:
			# Smooth-step ease for fluid motion (accelerate then decelerate)
			var t: float = _move_lerp_t
			var smooth_t: float = t * t * (3.0 - 2.0 * t)
			_player_world_pos = _player_start_pos.lerp(_player_target_pos, smooth_t)
		_update_player_3d_pos()
		_update_follower_3d_positions()

	# WASD free camera pan (continuous while keys held)
	_poll_wasd_camera(delta)

	# Smooth camera follow — only when not in free-cam mode
	if not _cam_free:
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

# ── A* Pathfinding ─────────────────────────────────────────────────────────

func _find_path(from: Vector2i, to: Vector2i) -> Array:
	## A* pathfinding on the tile grid. Returns Array[Vector2i] (excluding `from`).
	## Returns empty array if no path exists.
	if from == to:
		return []
	if not _is_walkable(to.x, to.y):
		return []

	# Open set as a simple sorted list (grid is only 30x22 = 660 tiles, fine for linear scan)
	var open: Array = []          # Array of Vector2i
	var g_score: Dictionary = {}  # Vector2i → float
	var f_score: Dictionary = {}  # Vector2i → float
	var came_from: Dictionary = {} # Vector2i → Vector2i

	g_score[from] = 0.0
	f_score[from] = float(_heuristic(from, to))
	open.append(from)

	var directions: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while not open.is_empty():
		# Find node in open set with lowest f_score
		var current: Vector2i = open[0]
		var best_f: float = f_score.get(current, 99999.0)
		for i in range(1, open.size()):
			var cf: float = f_score.get(open[i], 99999.0)
			if cf < best_f:
				best_f = cf
				current = open[i]

		if current == to:
			# Reconstruct path
			var path: Array = []
			var node: Vector2i = to
			while node != from:
				path.push_front(node)
				node = came_from[node]
			return path

		open.erase(current)
		var cur_g: float = g_score.get(current, 99999.0)

		for dir in directions:
			var neighbor: Vector2i = current + dir
			if not _is_walkable(neighbor.x, neighbor.y):
				continue
			var tentative_g: float = cur_g + 1.0
			if tentative_g < g_score.get(neighbor, 99999.0):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + float(_heuristic(neighbor, to))
				if not open.has(neighbor):
					open.append(neighbor)

	return []  # No path found

func _heuristic(a: Vector2i, b: Vector2i) -> int:
	## Manhattan distance heuristic for A*.
	return abs(a.x - b.x) + abs(a.y - b.y)

# ── Path Visualization ────────────────────────────────────────────────────

func _show_path_markers(path: Array) -> void:
	## Draw glowing tiles along the planned path.
	_clear_path_markers()
	for pos in path:
		var marker := MeshInstance3D.new()
		var quad := PlaneMesh.new()
		quad.size = Vector2(0.7, 0.7)
		marker.mesh = quad

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.85, 1.0, 0.45)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.85, 1.0)
		mat.emission_energy_multiplier = 1.5
		mat.no_depth_test = true
		marker.material_override = mat

		var wp: Vector3 = _tile_to_world(pos.x, pos.y)
		marker.position = Vector3(wp.x, wp.y + 0.06, wp.z)
		_overlay_root.add_child(marker)
		_path_markers.append(marker)

func _clear_path_markers() -> void:
	## Remove all path visualization nodes.
	for m in _path_markers:
		if is_instance_valid(m):
			m.queue_free()
	_path_markers.clear()

# ── Auto-Walk Controller ──────────────────────────────────────────────────

func _start_auto_walk(path: Array) -> void:
	## Begin auto-walking along a computed path.
	if path.is_empty():
		return
	_auto_path = path.duplicate()
	_auto_path_active = true
	_show_path_markers(_auto_path)
	_auto_walk_next_step()

func _auto_walk_next_step() -> void:
	## Move to the next tile in the auto-walk queue.
	if _auto_path.is_empty():
		_stop_auto_walk()
		return
	var next_pos: Vector2i = _auto_path[0]
	var dir: Vector2i = next_pos - _player_pos
	# Sanity check: should be exactly 1 tile away
	if abs(dir.x) + abs(dir.y) != 1:
		_stop_auto_walk()
		return
	_auto_path.remove_at(0)
	# Update path markers — remove the one we're stepping onto
	if not _path_markers.is_empty():
		var front_marker = _path_markers[0]
		if is_instance_valid(front_marker):
			front_marker.queue_free()
		_path_markers.remove_at(0)
	_try_move(dir)

func _stop_auto_walk() -> void:
	## Cancel auto-walk and clean up path visuals.
	_auto_path.clear()
	_auto_path_active = false
	_clear_path_markers()

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
				POI_LEDGER:     return _pc("poi_ledger", Color(0.40, 0.35, 0.20))
				POI_TOWN_HALL:  return _pc("poi_town_hall", Color(0.32, 0.26, 0.42))
				POI_GUILD:      return _pc("poi_guild", Color(0.38, 0.32, 0.18))
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
			var wall_height: float = 1.25
			var wall_col: Color = _pc("wall", Color(0.18, 0.15, 0.22))

			if t == T_WALL_RICH:
				wall_height = 1.6
				wall_col = _pc("wall_rich", Color(0.30, 0.24, 0.38))
			elif t == T_WALL_POOR:
				wall_height = 1.0
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
		var h: float = 1.75 if wt == T_WALL_RICH else 1.4

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
			POI_LEDGER:     _build_poi_ledger_house(wx, wz)
			POI_TOWN_HALL:  _build_poi_town_hall(wx, wz)
			POI_GUILD:      _build_poi_merchant_guild(wx, wz)
			POI_EXIT:       _build_poi_exit_gate(wx, wz)

		# Accent light for all POIs
		var light := OmniLight3D.new()
		light.light_color = _poi_light_color(pt)
		light.light_energy = 0.8
		light.omni_range = 3.5
		light.position = Vector3(wx, 0.75, wz)
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
		POI_LEDGER:     return Color(0.80, 0.70, 0.30)
		POI_TOWN_HALL:  return Color(0.60, 0.50, 0.80)
		POI_GUILD:      return Color(0.70, 0.60, 0.30)
		POI_EXIT:       return Color(0.60, 0.60, 0.60)
	return Color(0.5, 0.5, 0.5)

func _build_poi_rest_house(wx: float, wz: float) -> void:
	# House body
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.3, 0.7)
	body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.45, 0.30)
	mat.roughness = 0.85
	body.material_override = mat
	body.position = Vector3(wx, 0.15, wz)
	_poi_root.add_child(body)
	# Roof
	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.01
	rm.bottom_radius = 0.55
	rm.height = 0.25
	rm.radial_segments = 4
	roof.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.35, 0.55, 0.30)
	rmat.roughness = 0.8
	roof.material_override = rmat
	roof.position = Vector3(wx, 0.42, wz)
	_poi_root.add_child(roof)
	# Chimney
	var chimney := MeshInstance3D.new()
	var chm := BoxMesh.new()
	chm.size = Vector3(0.1, 0.15, 0.1)
	chimney.mesh = chm
	var chmat := StandardMaterial3D.new()
	chmat.albedo_color = Color(0.40, 0.30, 0.22)
	chimney.material_override = chmat
	chimney.position = Vector3(wx + 0.2, 0.52, wz + 0.1)
	_poi_root.add_child(chimney)
	# Door
	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.15, 0.15, 0.02)
	door.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.30, 0.18, 0.08)
	door.material_override = dmat
	door.position = Vector3(wx, 0.08, wz - 0.35)
	_poi_root.add_child(door)

func _build_poi_shop(wx: float, wz: float) -> void:
	# Counter
	var counter := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.7, 0.2, 0.35)
	counter.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.40, 0.20)
	counter.material_override = mat
	counter.position = Vector3(wx, 0.1, wz)
	_poi_root.add_child(counter)
	# Awning
	var awning := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.9, 0.03, 0.6)
	awning.mesh = am
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(0.85, 0.70, 0.20)
	awning.material_override = amat
	awning.position = Vector3(wx, 0.425, wz)
	_poi_root.add_child(awning)
	# Poles
	for px in [-0.35, 0.35]:
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.02; pm.bottom_radius = 0.02; pm.height = 0.425
		pole.mesh = pm
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.40, 0.30, 0.15)
		pole.material_override = pmat
		pole.position = Vector3(wx + px, 0.2125, wz - 0.25)
		_poi_root.add_child(pole)
	# Goods on counter
	for i in range(3):
		var good := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(0.08, 0.05, 0.08)
		good.mesh = gm
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = Color.from_hsv(float(i) * 0.3, 0.6, 0.7)
		good.material_override = gmat
		good.position = Vector3(wx - 0.2 + float(i) * 0.2, 0.225, wz)
		_poi_root.add_child(good)

func _build_poi_tavern(wx: float, wz: float) -> void:
	# Building
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 0.35, 0.7)
	body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.50, 0.35, 0.18)
	body.material_override = mat
	body.position = Vector3(wx, 0.175, wz)
	_poi_root.add_child(body)
	# Sloped roof
	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.01; rm.bottom_radius = 0.60; rm.height = 0.225; rm.radial_segments = 4
	roof.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.55, 0.30, 0.12)
	roof.material_override = rmat
	roof.position = Vector3(wx, 0.46, wz)
	_poi_root.add_child(roof)
	# Hanging sign
	var sign := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.35, 0.1, 0.03)
	sign.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.85, 0.55, 0.15)
	smat.emission_enabled = true
	smat.emission = Color(0.85, 0.55, 0.15)
	smat.emission_energy_multiplier = 0.3
	sign.material_override = smat
	sign.position = Vector3(wx + 0.5, 0.3, wz)
	_poi_root.add_child(sign)

func _build_poi_blacksmith(wx: float, wz: float) -> void:
	# Forge base
	var forge := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.5, 0.2, 0.5)
	forge.mesh = fm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.22, 0.18)
	forge.material_override = mat
	forge.position = Vector3(wx, 0.1, wz)
	_poi_root.add_child(forge)
	# Chimney / smoke stack
	var stack := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.15; sm.bottom_radius = 0.18; sm.height = 0.6
	stack.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.25, 0.18, 0.14)
	stack.material_override = smat
	stack.position = Vector3(wx + 0.15, 0.3, wz + 0.15)
	_poi_root.add_child(stack)
	# Fire glow inside forge
	var fire_light := OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.55, 0.15)
	fire_light.light_energy = 1.2
	fire_light.omni_range = 2.5
	fire_light.position = Vector3(wx, 0.15, wz)
	_poi_root.add_child(fire_light)
	# Anvil
	var anvil := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.18, 0.1, 0.12)
	anvil.mesh = am
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(0.35, 0.35, 0.38)
	amat.metallic = 0.6
	amat.roughness = 0.4
	anvil.material_override = amat
	anvil.position = Vector3(wx - 0.3, 0.05, wz - 0.2)
	_poi_root.add_child(anvil)

func _build_poi_library(wx: float, wz: float) -> void:
	# Tall building
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.65, 0.5, 0.65)
	body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.32, 0.50)
	body.material_override = mat
	body.position = Vector3(wx, 0.25, wz)
	_poi_root.add_child(body)
	# Dome top
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.35; dm.height = 0.2
	dome.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.25, 0.50, 0.65)
	dmat.metallic = 0.2
	dome.material_override = dmat
	dome.position = Vector3(wx, 0.575, wz)
	_poi_root.add_child(dome)
	# Window glow
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.30, 0.65, 0.90)
	glow.light_energy = 0.6
	glow.omni_range = 2.0
	glow.position = Vector3(wx, 0.3, wz - 0.35)
	_poi_root.add_child(glow)

func _build_poi_bounty_board(wx: float, wz: float) -> void:
	# Post
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.04; pm.bottom_radius = 0.04; pm.height = 0.5
	post.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.40, 0.30, 0.18)
	post.material_override = pmat
	post.position = Vector3(wx, 0.25, wz)
	_poi_root.add_child(post)
	# Board
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.25, 0.05)
	board.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.55, 0.42, 0.22)
	board.material_override = bmat
	board.position = Vector3(wx, 0.425, wz)
	_poi_root.add_child(board)
	# Paper notices
	for i in range(3):
		var paper := MeshInstance3D.new()
		var nm := BoxMesh.new()
		nm.size = Vector3(0.12, 0.075, 0.005)
		paper.mesh = nm
		var nmat := StandardMaterial3D.new()
		nmat.albedo_color = Color(0.90, 0.85, 0.70)
		paper.material_override = nmat
		paper.position = Vector3(wx - 0.15 + float(i) * 0.15, 0.425 + float(i % 2) * 0.04, wz - 0.028)
		paper.rotation.z = (float(i) - 1.0) * 0.1
		_poi_root.add_child(paper)

func _build_poi_fountain(wx: float, wz: float) -> void:
	# Basin
	var basin := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.40; bm.bottom_radius = 0.45; bm.height = 0.15
	basin.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.50, 0.48, 0.52)
	mat.roughness = 0.5
	mat.metallic = 0.15
	basin.material_override = mat
	basin.position = Vector3(wx, 0.075, wz)
	_poi_root.add_child(basin)
	# Water inside
	var water := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.35; wm.bottom_radius = 0.35; wm.height = 0.04
	water.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.20, 0.45, 0.70, 0.7)
	wmat.roughness = 0.1
	wmat.metallic = 0.5
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = wmat
	water.position = Vector3(wx, 0.13, wz)
	_poi_root.add_child(water)
	# Center spout
	var spout := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.03; sm.bottom_radius = 0.06; sm.height = 0.3
	spout.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.55, 0.52, 0.56)
	smat.metallic = 0.3
	spout.material_override = smat
	spout.position = Vector3(wx, 0.225, wz)
	_poi_root.add_child(spout)
	# Water light
	var wl := OmniLight3D.new()
	wl.light_color = Color(0.25, 0.50, 0.85)
	wl.light_energy = 0.5
	wl.omni_range = 2.0
	wl.position = Vector3(wx, 0.2, wz)
	_poi_root.add_child(wl)

func _build_poi_acf(wx: float, wz: float) -> void:
	# Larger building
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 0.4, 0.8)
	body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.22, 0.42)
	body.material_override = mat
	body.position = Vector3(wx, 0.2, wz)
	_poi_root.add_child(body)
	# Flat roof with antenna
	var roof := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(0.85, 0.03, 0.85)
	roof.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.35, 0.28, 0.50)
	rmat.metallic = 0.1
	roof.material_override = rmat
	roof.position = Vector3(wx, 0.415, wz)
	_poi_root.add_child(roof)
	# Antenna
	var ant := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.01; am.bottom_radius = 0.02; am.height = 0.25
	ant.mesh = am
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(0.50, 0.50, 0.55)
	amat.metallic = 0.5
	ant.material_override = amat
	ant.position = Vector3(wx + 0.25, 0.55, wz - 0.2)
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
	emblem.position = Vector3(wx, 0.325, wz - 0.41)
	_poi_root.add_child(emblem)

func _build_poi_exit_gate(wx: float, wz: float) -> void:
	# Two pillars
	for px in [-0.25, 0.25]:
		var pillar := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.15, 0.7, 0.15)
		pillar.mesh = pm
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.45, 0.42, 0.48)
		pmat.roughness = 0.6
		pillar.material_override = pmat
		pillar.position = Vector3(wx + px, 0.35, wz)
		_poi_root.add_child(pillar)
	# Arch top
	var arch := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.65, 0.06, 0.18)
	arch.mesh = am
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(0.48, 0.45, 0.52)
	amat.roughness = 0.6
	arch.material_override = amat
	arch.position = Vector3(wx, 0.675, wz)
	_poi_root.add_child(arch)

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 4 — PLAYER AND FOLLOWER 3D MODELS
# ══════════════════════════════════════════════════════════════════════════════


func _build_poi_ledger_house(wx: float, wz: float) -> void:
	# Vault door (main visual)
	var vault := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(0.5, 0.6, 0.08)
	vault.mesh = vm
	var vmat := StandardMaterial3D.new()
	vmat.albedo_color = Color(0.60, 0.52, 0.32)
	vmat.metallic = 0.3
	vmat.roughness = 0.4
	vault.material_override = vmat
	vault.position = Vector3(wx, 0.3, wz)
	_poi_root.add_child(vault)
	# Vault lock
	var lock := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.06
	lock.mesh = lm
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(0.90, 0.82, 0.50)
	lmat.metallic = 0.8
	lock.material_override = lmat
	lock.position = Vector3(wx, 0.30, wz - 0.045)
	_poi_root.add_child(lock)
	# Building body
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.4, 0.7)
	body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.50, 0.44, 0.32)
	body.material_override = mat
	body.position = Vector3(wx, 0.2, wz + 0.2)
	_poi_root.add_child(body)
	# Roof
	var roof := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(0.75, 0.04, 0.75)
	roof.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.45, 0.40, 0.28)
	rmat.metallic = 0.2
	roof.material_override = rmat
	roof.position = Vector3(wx, 0.42, wz + 0.2)
	_poi_root.add_child(roof)
	# Gold glow accent
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.90, 0.80, 0.40)
	glow.light_energy = 0.3
	glow.omni_range = 1.5
	glow.position = Vector3(wx, 0.30, wz)
	_poi_root.add_child(glow)

func _build_poi_town_hall(wx: float, wz: float) -> void:
	# Main hall body
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 0.5, 0.8)
	body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.50, 0.42, 0.30)
	body.material_override = mat
	body.position = Vector3(wx, 0.25, wz)
	_poi_root.add_child(body)
	# Pediment (roof peak)
	var pediment := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.85, 0.08, 0.65)
	pediment.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.55, 0.48, 0.32)
	pediment.material_override = pmat
	pediment.position = Vector3(wx, 0.55, wz)
	_poi_root.add_child(pediment)
	# Pillars (4 corners)
	for px in [-0.3, 0.3]:
		for pz in [-0.3, 0.3]:
			var pillar := MeshInstance3D.new()
			var pm2 := CylinderMesh.new()
			pm2.top_radius = 0.06; pm2.bottom_radius = 0.08; pm2.height = 0.6
			pillar.mesh = pm2
			var pilmat := StandardMaterial3D.new()
			pilmat.albedo_color = Color(0.70, 0.65, 0.50)
			pilmat.roughness = 0.7
			pillar.material_override = pilmat
			pillar.position = Vector3(wx + px, 0.3, wz + pz)
			_poi_root.add_child(pillar)
	# Clock face
	var clock := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12; cm.bottom_radius = 0.12; cm.height = 0.02
	clock.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.95, 0.90, 0.70)
	clock.material_override = cmat
	clock.position = Vector3(wx, 0.58, wz - 0.4)
	_poi_root.add_child(clock)

func _build_poi_merchant_guild(wx: float, wz: float) -> void:
	# Market stall structure
	var frame := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.7, 0.35, 0.7)
	frame.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.50, 0.40, 0.25)
	frame.material_override = fmat
	frame.position = Vector3(wx, 0.175, wz)
	_poi_root.add_child(frame)
	# Canopy roof
	var canopy := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.85, 0.04, 0.75)
	canopy.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.85, 0.50, 0.20)
	cmat.roughness = 0.6
	canopy.material_override = cmat
	canopy.position = Vector3(wx, 0.42, wz)
	_poi_root.add_child(canopy)
	# Scales (balance)
	var left_scale := MeshInstance3D.new()
	var lsm := BoxMesh.new()
	lsm.size = Vector3(0.15, 0.02, 0.15)
	left_scale.mesh = lsm
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(0.80, 0.75, 0.60)
	left_scale.material_override = lmat
	left_scale.position = Vector3(wx - 0.2, 0.35, wz)
	_poi_root.add_child(left_scale)
	var right_scale := MeshInstance3D.new()
	var rsm := BoxMesh.new()
	rsm.size = Vector3(0.15, 0.02, 0.15)
	right_scale.mesh = rsm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.80, 0.75, 0.60)
	right_scale.material_override = rmat
	right_scale.position = Vector3(wx + 0.2, 0.35, wz)
	_poi_root.add_child(right_scale)
	# Balance beam
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.55, 0.03, 0.04)
	beam.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.70, 0.65, 0.50)
	bmat.roughness = 0.5
	beam.material_override = bmat
	beam.position = Vector3(wx, 0.36, wz)
	_poi_root.add_child(beam)
	# Center pivot
	var pivot := MeshInstance3D.new()
	var pm := SphereMesh.new()
	pm.radius = 0.04
	pivot.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.90, 0.82, 0.50)
	pmat.metallic = 0.6
	pivot.material_override = pmat
	pivot.position = Vector3(wx, 0.37, wz)
	_poi_root.add_child(pivot)

func _build_3d_entities() -> void:
	var handles: Array = GameState.get_active_handles()

	# Player
	_player_node = _create_entity_model(0, handles, true)
	_player_node.position = _player_world_pos
	_entity_root.add_child(_player_node)

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
	# Arrow keys or Escape cancel auto-walk
	if _auto_path_active and event is InputEventKey and event.pressed and not event.echo:
		var cancel_keys := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ESCAPE]
		if event.keycode in cancel_keys:
			_stop_auto_walk()
			if event.keycode == KEY_ESCAPE:
				return  # Escape just cancels, doesn't move
	if event is InputEventKey and event.pressed and not event.echo:
		# Arrow keys move the party (camera-relative grid movement)
		var raw_dir := Vector2.ZERO
		match event.keycode:
			KEY_UP:    raw_dir = Vector2(0, -1)
			KEY_DOWN:  raw_dir = Vector2(0,  1)
			KEY_LEFT:  raw_dir = Vector2(-1, 0)
			KEY_RIGHT: raw_dir = Vector2( 1, 0)
			KEY_HOME:
				_cam_yaw = 0.0
				_cam_pitch = 40.0
				_cam_dist = 10.0
				_cam_free = false
		if raw_dir != Vector2.ZERO:
			var dir: Vector2i = _camera_relative_dir(raw_dir)
			if dir != Vector2i.ZERO:
				_try_move(dir)
			var vp := get_viewport()
			if vp != null:
				vp.set_input_as_handled()

## WASD free camera pan — moves the camera target freely across the map.
## Camera snaps back to the party when the player moves (arrow keys / click-to-walk).
func _poll_wasd_camera(delta: float) -> void:
	var pan_speed: float = 12.0  # world units per second
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		move.y += 1.0
	if Input.is_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move.x += 1.0
	if move == Vector2.ZERO:
		return
	# Rotate movement by camera yaw so W always pushes "forward" from the camera's perspective
	var yaw_rad: float = deg_to_rad(_cam_yaw)
	var world_dx: float = move.x * cos(yaw_rad) - move.y * sin(yaw_rad)
	var world_dz: float = move.x * sin(yaw_rad) + move.y * cos(yaw_rad)
	_cam_target.x += world_dx * pan_speed * delta
	_cam_target.z += world_dz * pan_speed * delta
	# Clamp to map bounds
	_cam_target.x = clampf(_cam_target.x, 0.0, float(GRID_W))
	_cam_target.z = clampf(_cam_target.z, 0.0, float(GRID_H))
	_cam_free = true

## Check if an arrow key is currently held and start moving if so.
func _poll_held_direction() -> void:
	var raw_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_UP):
		raw_dir = Vector2(0, -1)
	elif Input.is_key_pressed(KEY_DOWN):
		raw_dir = Vector2(0, 1)
	elif Input.is_key_pressed(KEY_LEFT):
		raw_dir = Vector2(-1, 0)
	elif Input.is_key_pressed(KEY_RIGHT):
		raw_dir = Vector2(1, 0)
	if raw_dir != Vector2.ZERO:
		var dir: Vector2i = _camera_relative_dir(raw_dir)
		if dir != Vector2i.ZERO:
			_try_move(dir)

## Convert a raw input direction into a grid direction relative to camera yaw.
## Camera yaw 0° means camera looks from +Z toward origin (south-facing),
## so "forward" (0,-1) maps to grid north. As yaw rotates, directions rotate too.
func _camera_relative_dir(raw: Vector2) -> Vector2i:
	var yaw_rad: float = deg_to_rad(-_cam_yaw)
	# Rotate the input vector by negative camera yaw so "forward" follows the camera
	var rotated_x: float = raw.x * cos(yaw_rad) - raw.y * sin(yaw_rad)
	var rotated_y: float = raw.x * sin(yaw_rad) + raw.y * cos(yaw_rad)
	# Snap to the strongest cardinal direction (only one axis moves at a time on a grid)
	if absf(rotated_x) >= absf(rotated_y):
		return Vector2i(1 if rotated_x > 0 else -1, 0)
	else:
		return Vector2i(0, 1 if rotated_y > 0 else -1)

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
		# Click while moving cancels auto-walk
		_stop_auto_walk()
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

	var target := Vector2i(tx, ty)
	if target == _player_pos:
		return

	# Compute A* path and begin auto-walk
	var path: Array = _find_path(_player_pos, target)
	if path.is_empty():
		return
	_start_auto_walk(path)

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

	# Start smooth 3D movement — snap camera back to party
	_cam_free = false
	_player_start_pos = _player_world_pos
	_player_target_pos = _tile_to_world(new_pos.x, new_pos.y)
	_player_moving = true
	_move_lerp_t = 0.0

	# Update minimap
	_update_minimap_player()

	# Check for hidden caches near new position
	_check_nearby_caches(new_pos)

	# Check if we stepped on a random NPC — stop auto-walk
	if _npc_positions.has(new_pos):
		_stop_auto_walk()
		_show_npc_panel(_npc_positions[new_pos])
		return

	var tile: int = _get_tile(new_pos.x, new_pos.y)
	if tile == T_DANGER:
		_stop_auto_walk()
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

	# Environmental hazard check — terrain-specific
	var hazard_chance: float = 0.15  # 15% chance per encounter
	if randf() < hazard_chance:
		var region_hazards: Array = []
		for h in _WS.ENVIRONMENTAL_HAZARDS:
			if GameState.current_region in h["regions"]:
				region_hazards.append(h)
		if not region_hazards.is_empty():
			var hazard: Dictionary = region_hazards[randi() % region_hazards.size()]
			_apply_environmental_hazard(hazard)
			return  # Hazard application will continue to combat after showing message

	# Bounty hunter encounter check
	var region_bounty: int = int(GameState.bounty_per_region.get(GameState.current_region, 0))
	if region_bounty > 0 and randf() < minf(0.5, float(region_bounty) / 500.0):
		var hunter_rank: int = clampi(region_bounty / 100, 0, 3)
		var level_mods: Array = [0, 1, 2, 3]
		var level_mod: int = level_mods[hunter_rank] if hunter_rank < level_mods.size() else 3
		enemy_level = clampi(base_level + level_mod, 1, 20)
		GameState.set_meta("bounty_encounter", true)

	# Save player position so we return to this tile after dungeon
	GameState.explore_return_pos = _player_pos
	GameState.explore_return_active = true
	GameState.dungeon_source = "explore"

	RimvaleAPI.engine.start_dungeon(handles, enemy_level, 0, _terrain_style)
	if GameState.recruited_allies.size() > 0:
		RimvaleAPI.engine.spawn_allies(GameState.recruited_allies)

	var main = get_tree().root.get_child(0)
	if main and main.has_method("push_screen"):
		main.push_screen("res://scenes/dungeon/dungeon.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/dungeon/dungeon.tscn")

func _apply_environmental_hazard(hazard: Dictionary) -> void:
	var handles: PackedInt64Array = GameState.get_active_handles()
	if handles.is_empty():
		return

	var hazard_name: String = str(hazard.get("name", "Environmental Hazard"))
	var save_stat: String = str(hazard.get("save", "VIT"))  # stat name like "VIT", "SPD", etc.
	var dc: int = int(hazard.get("dc", 12))
	var dmg_dice: Array = Array(hazard.get("dmg_dice", [1, 6]))  # [dice_count, die_sides]
	var effect: String = str(hazard.get("effect", ""))

	# Get the party lead (first handle in active team)
	var lead_handle: int = int(handles[0])
	var e = RimvaleAPI.engine
	var lead_dict = e.get_char_dict(lead_handle)
	if lead_dict == null:
		return

	# Map stat names to indices: STR=0, DEX=1, CON=2, INT=3, WIS=4, CHA=5
	# For Rimvale: STR=0, DEX=1, CON=2, INT=3, WIS=4, CHA=5
	# But task specifies: "use the save stat from hazard["save"], e.g., "VIT" → stats[3]"
	# "VIT" likely refers to vitality/constitution, so map accordingly
	var stat_map: Dictionary = {
		"STR": 0, "DEX": 1, "CON": 2, "INT": 3, "WIS": 4, "CHA": 5,
		"VIT": 2, "SPD": 1, "DIV": 4  # Alternative names
	}
	var stat_idx: int = stat_map.get(save_stat, 2)  # Default to CON/VIT
	var stat_val: int = int(lead_dict.get("stats", [1, 1, 1, 1, 1])[stat_idx]) if stat_idx < len(lead_dict.get("stats", [])) else 1

	# Roll save: d20 + stat modifier vs DC
	var save_roll: int = randi_range(1, 20) + (stat_val - 10) / 2
	var save_success: bool = save_roll >= dc

	# Roll damage
	var dice_count: int = int(dmg_dice[0]) if dmg_dice.size() > 0 else 1
	var die_sides: int = int(dmg_dice[1]) if dmg_dice.size() > 1 else 6
	var damage: int = 0
	for i in range(dice_count):
		damage += randi_range(1, die_sides)

	# On success, halve damage
	if save_success:
		damage = damage / 2

	# Apply damage to the party lead
	if damage > 0:
		var current_hp: int = e.get_character_hp(lead_handle)
		var new_hp: int = maxi(0, current_hp - damage)
		lead_dict["hp"] = new_hp

	# Show the hazard message with callback to start dungeon
	var msg: String = "[%s]\n" % hazard_name
	msg += "A %s appears before you!\n" % effect
	msg += "Your %s must make a DC %d save.\n" % [save_stat, dc]
	msg += "Save roll: %d vs DC %d — %s\n" % [save_roll, dc, "SUCCESS" if save_success else "FAILURE"]
	msg += "Damage taken: %d HP" % damage

	var color: Color = RimvaleColors.DANGER if damage > 10 else RimvaleColors.ORANGE
	_show_message(msg, color, _continue_encounter_after_hazard)

func _continue_encounter_after_hazard() -> void:
	# After hazard message, proceed to normal encounter
	var handles: PackedInt64Array = GameState.get_active_handles()
	if handles.is_empty():
		return

	var base_level: int = maxi(1, GameState.player_level)
	var enemy_level: int = clampi(base_level + randi_range(-1, 1), 1, 15)

	GameState.explore_return_pos = _player_pos
	GameState.explore_return_active = true
	GameState.dungeon_source = "explore"

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
	_skills_used_this_poi.clear()

	match int(poi["type"]):
		POI_ACF:        _show_acf_panel()
		POI_SHOP:       _show_shop_panel()
		POI_REST:       _show_rest_panel()
		POI_TAVERN:     _show_tavern_panel()
		POI_BLACKSMITH: _show_blacksmith_panel()
		POI_LIBRARY:    _show_library_panel()
		POI_BOUNTY:     _show_bounty_panel()
		POI_FOUNTAIN:   _show_fountain_panel()
		POI_LEDGER:     _show_ledger_house_panel()
		POI_TOWN_HALL:  _show_town_hall_panel()
		POI_GUILD:      _show_merchant_guild_panel()
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

	# Government type and effects
	var gov_type: String = str(_WS.REGION_GOVERNMENTS.get(GameState.current_region, "republic"))
	var gov: Dictionary = _WS.GOVERNMENT_TYPES.get(gov_type, {})
	var gov_name: String = str(gov.get("name", gov_type))
	_info_vbox.add_child(RimvaleUtils.spacer(4))
	_info_vbox.add_child(RimvaleUtils.label("⚔ %s" % gov_name, 12, RimvaleColors.ORANGE))
	var gov_desc: String = str(gov.get("desc", "Government type unknown"))
	var gd := RimvaleUtils.label(gov_desc, 10, RimvaleColors.TEXT_DIM)
	gd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(gd)

	# Faction presence
	var rk: String = WorldData.subregion_to_key(_subregion)
	var faction_info: Dictionary = WorldData.get_faction_for_region(rk)
	if not faction_info.is_empty():
		var fname: String = str(faction_info.get("name", ""))
		_info_vbox.add_child(RimvaleUtils.spacer(4))
		_info_vbox.add_child(RimvaleUtils.label("⚜ %s Territory" % fname, 12, RimvaleColors.GOLD))
		var tf := RimvaleUtils.label(str(faction_info.get("territory_feature", "")), 10, RimvaleColors.TEXT_DIM)
		tf.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info_vbox.add_child(tf)
		# Show faction reputation
		var rep: int = int(GameState.faction_reputation.get(fname, 0))
		var tier: String = GameState.get_faction_tier(fname)
		var rep_col: Color = RimvaleColors.HP_GREEN if rep >= 25 else (RimvaleColors.DANGER if rep <= -25 else RimvaleColors.TEXT_GRAY)
		_info_vbox.add_child(RimvaleUtils.label("Standing: %s (%d)" % [tier, rep], 10, rep_col))

	_info_vbox.add_child(RimvaleUtils.separator())
	_add_time_status(_info_vbox)
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

	# Field Medicine button
	_info_vbox.add_child(RimvaleUtils.spacer(4))
	var med_info: Array = _best_party_skill("Medical")
	var med_mod: int = med_info[1]
	var med_dc: int = 10 + GameState.player_level
	var med_color: Color = RimvaleColors.TEXT_DIM if _field_med_used else RimvaleColors.HP_GREEN
	var med_suffix: String = " (used)" if _field_med_used else " (2 hrs)"
	var med_btn := RimvaleUtils.button(
		"🩺 Field Medicine [Medical +%d vs DC %d]%s" % [med_mod, med_dc, med_suffix],
		med_color, 36, 11)
	if _field_med_used:
		med_btn.disabled = true
	med_btn.pressed.connect(_do_field_medicine)
	_info_vbox.add_child(med_btn)

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

	# Terrain hazard damage info
	var subregions: Dictionary = _WS.SUBREGIONS.get(GameState.current_region, {})
	for sub_name in subregions.keys():
		if sub_name == GameState.current_subregion:
			var terrain_str: String = str(subregions[sub_name].get("terrain", ""))
			var teff: Dictionary = _WS.TERRAIN_EFFECTS.get(terrain_str, {})
			if teff.has("dot_dmg"):
				_info_vbox.add_child(RimvaleUtils.separator())
				_info_vbox.add_child(RimvaleUtils.label(
					"Terrain hazard: %s (1d%d dmg/step)" % [terrain_str, int(teff.get("dot_dmg", 1))],
					10, RimvaleColors.DANGER))
			break

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

## Formats an hour (0-23) as a 12-hour time string.
func _hour_to_str(h: int) -> String:
	var wrapped: int = h % 24
	var suffix: String = "AM" if wrapped < 12 else "PM"
	var display: int = wrapped % 12
	if display == 0:
		display = 12
	return "%d:00 %s" % [display, suffix]

## Returns the current time-of-day period label and colour.
func _time_period() -> Array:
	if _current_hour < 6:
		return ["Night", RimvaleColors.SP_PURPLE]
	elif _current_hour < 12:
		return ["Morning", RimvaleColors.GOLD]
	elif _current_hour < 17:
		return ["Afternoon", RimvaleColors.ORANGE]
	elif _current_hour < 21:
		return ["Evening", RimvaleColors.CYAN]
	else:
		return ["Night", RimvaleColors.SP_PURPLE]

## Advance time by the given number of hours. Returns true if time is still available.
func _advance_time(hours: int = 1) -> bool:
	_current_hour += hours
	GameState.explore_current_hour = _current_hour
	return _current_hour < 24

func _time_cost_str(hours: int = 1) -> String:
	if hours == 1:
		return "(1 hr)"
	return "(%d hrs)" % hours

## Returns true if the day has ended (midnight or later).
func _is_day_over() -> bool:
	return _current_hour >= 24

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

func _add_time_status(parent: VBoxContainer) -> void:
	var period: Array = _time_period()
	var period_name: String = str(period[0])
	var period_col: Color = period[1]
	parent.add_child(RimvaleUtils.label(
		"🕐 %s — %s" % [_hour_to_str(_current_hour), period_name], 12, period_col))
	if _current_hour >= 21:
		parent.add_child(RimvaleUtils.label(
			"It grows late. Rest soon.", 10, RimvaleColors.WARNING))
	elif _current_hour >= 24:
		parent.add_child(RimvaleUtils.label(
			"The day is over. You must rest.", 10, RimvaleColors.DANGER))

func _try_action(return_panel: Callable, hours: int = 1) -> bool:
	if _is_day_over():
		_show_message("The day is over. Find a place to rest.", RimvaleColors.DANGER, return_panel)
		return false
	_advance_time(hours)
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
	_add_time_status(_info_vbox)
	_info_vbox.add_child(RimvaleUtils.spacer(4))

	var heal_btn := RimvaleUtils.button("🩹 Request Medical Aid %s" % _time_cost_str(), RimvaleColors.HP_GREEN, 44, 13)
	heal_btn.pressed.connect(func():
		if not _try_action(_show_acf_panel): return
		for h in GameState.get_active_handles():
			RimvaleAPI.engine.long_rest(h)
		_show_message("All agents restored to full health.", RimvaleColors.HP_GREEN, _show_acf_panel)
	)
	_info_vbox.add_child(heal_btn)

	var brief_btn := RimvaleUtils.button("📋 Accept Field Briefing (+50 XP) %s" % _time_cost_str(), RimvaleColors.CYAN, 44, 13)
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

	# Stationed ACF personnel
	var region_key: String = WorldData.subregion_to_key(_subregion)
	var stationed: Array = WorldData.get_acf_agents_for_region(region_key)
	if stationed.size() > 0:
		_info_vbox.add_child(RimvaleUtils.separator())
		_info_vbox.add_child(RimvaleUtils.label("👥 Stationed Personnel", 13, RimvaleColors.ACCENT))
		_info_vbox.add_child(RimvaleUtils.spacer(2))
		for npc in stationed:
			var npc_card := RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.DIVIDER, 4, 6)
			var cv := VBoxContainer.new()
			cv.add_theme_constant_override("separation", 2)
			npc_card.add_child(cv)
			var role_col: Color = RimvaleColors.GOLD if str(npc.get("role", "")).find("Archmage") >= 0 or str(npc.get("role", "")).find("Grand") >= 0 else RimvaleColors.ACCENT
			cv.add_child(RimvaleUtils.label("%s — %s" % [str(npc.get("name", "Unknown")), str(npc.get("role", "Agent"))], 12, role_col))
			var lineage_lbl := RimvaleUtils.label("%s • %s" % [str(npc.get("lineage", "")), str(npc.get("description", ""))], 10, RimvaleColors.TEXT_GRAY)
			lineage_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cv.add_child(lineage_lbl)
			_info_vbox.add_child(npc_card)

	# Multi-step dialogue encounter
	var acf_dialogue_key: String = "acf_dialogue::" + _subregion
	if not GameState.social_cooldowns.has(acf_dialogue_key):
		var dialogue_btn := RimvaleUtils.button("📋 Field Intelligence Briefing %s" % _time_cost_str(2), RimvaleColors.CYAN, 44, 13)
		dialogue_btn.pressed.connect(func():
			GameState.social_cooldowns[acf_dialogue_key] = true
			_start_dialogue(ACF_DIALOGUES, _show_acf_panel)
		)
		_info_vbox.add_child(dialogue_btn)

	# Intel report button
	var intel_btn := RimvaleUtils.button("🔍 View Intelligence Report", RimvaleColors.CYAN, 38, 12)
	intel_btn.pressed.connect(func(): _show_intel_panel(_show_acf_panel))
	_info_vbox.add_child(intel_btn)

	# Social interactions
	_add_social_section(_info_vbox, "acf", [
		["Medical", "Field Surgery", "heal:full", "Expert triage! All agents restored to full HP.", "heal:half", "Rough patching. Half HP restored.", "🩺"],
		["Arcane", "Assist Arcane Research", "sp:4", "Your arcane insight aids the researchers. +4 SP to all.", "none", "The research is beyond your current understanding.", "✨"],
		["Speechcraft", "Requisition Supplies", "item:Health Potion|item:Potion of Revive", "Supply officer approves your request. Health Potion and Potion of Revive added to stash!", "none", "\"Request denied. Fill out form 27-B.\"", "🗣"],
	], _show_acf_panel)

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
	_add_time_status(_info_vbox)
	_info_vbox.add_child(RimvaleUtils.label("Gold: %d" % GameState.gold, 13, RimvaleColors.GOLD))
	# Reputation price modifier
	var shop_rk: String = WorldData.subregion_to_key(_subregion)
	var shop_fi: Dictionary = WorldData.get_faction_for_region(shop_rk)
	var shop_fname: String = str(shop_fi.get("name", ""))
	var shop_rep: int = int(GameState.faction_reputation.get(shop_fname, 0)) if not shop_fname.is_empty() else 0
	var price_mult: float = 1.0 - (shop_rep * 0.002)  # ±20% at ±100 rep
	price_mult = clampf(price_mult, 0.8, 1.2)
	if shop_rep >= 25:
		_info_vbox.add_child(RimvaleUtils.label("Friendly discount applied!", 10, RimvaleColors.HP_GREEN))
	elif shop_rep <= -25:
		_info_vbox.add_child(RimvaleUtils.label("Prices marked up — low standing.", 10, RimvaleColors.DANGER))
	_info_vbox.add_child(RimvaleUtils.separator())

	var shop_items: Array = _content.get("shop_items", [
		["Health Potion", 50, "Restores 15 HP to the first wounded agent."],
		["Energy Tonic", 75, "Restores 5 AP to the first depleted agent."],
		["Smoke Bomb", 40, "Nullifies the next 5 danger-zone steps."],
		["Field Rations", 30, "Restores 5 HP to every team member."],
	])
	for item in shop_items:
		var item_name: String = str(item[0])
		var price: int = maxi(1, int(int(item[1]) * price_mult))
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

		var buy_btn := RimvaleUtils.button("Buy %s" % _time_cost_str(), RimvaleColors.GOLD, 28, 11)
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

	# Barter encounter
	var barter_key: String = "barter::" + _subregion
	if not GameState.social_cooldowns.has(barter_key):
		var barter_btn := RimvaleUtils.button("🤝 Browse Special Wares %s" % _time_cost_str(), RimvaleColors.GOLD, 44, 13)
		barter_btn.pressed.connect(func():
			GameState.social_cooldowns[barter_key] = true
			_start_barter(_show_shop_panel)
		)
		_info_vbox.add_child(barter_btn)

	# Social interactions
	_add_social_section(_info_vbox, "shop", [
		["Speechcraft", "Haggle for Discount", "gold:25", "The merchant relents and refunds 25 gold. A shrewd bargain!", "none", "The merchant scoffs. \"My prices are fair.\"", "🗣"],
		["Intuition", "Appraise Stock", "item:Health Potion", "You spot an underpriced gem! Health Potion added to stash for free.", "none", "Everything looks fairly priced. Nothing stands out.", "👁"],
		["Cunning", "Sleight of Hand", "item:Energy Tonic", "Quick fingers! Energy Tonic slipped into your pack unnoticed.", "lose_gold:50", "Caught red-handed! You pay a gold fine.", "🤏"],
	], _show_shop_panel)

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
	_add_time_status(_info_vbox)
	_info_vbox.add_child(RimvaleUtils.spacer(4))

	var rest_btn := RimvaleUtils.button("💤 Rest (Fully Heal Party — sleep until dawn)", RimvaleColors.HP_GREEN, 50, 14)
	rest_btn.pressed.connect(func():
		for h in GameState.get_active_handles():
			RimvaleAPI.engine.long_rest(h)
		_current_hour = 6   # Next morning
		GameState.explore_current_hour = 6
		GameState.social_cooldowns.clear()
		GameState.save_game()
		_show_message("Your team rests through the night. All HP, AP, and SP restored. A new day begins.", RimvaleColors.HP_GREEN, _show_rest_panel)
	)
	_info_vbox.add_child(rest_btn)

	_info_vbox.add_child(RimvaleUtils.spacer(8))
	var save_btn := RimvaleUtils.button("💾 Save Game", RimvaleColors.CYAN, 44, 13)
	save_btn.pressed.connect(func():
		GameState.save_game()
		_show_message("Game saved.", RimvaleColors.CYAN, _show_rest_panel)
	)
	_info_vbox.add_child(save_btn)

	# Social interactions
	_add_social_section(_info_vbox, "rest", [
		["Medical", "Tend to Wounds", "heal:full", "Expert care! Everyone is fully restored and refreshed.", "none", "Bandages applied, but the technique was rough. Normal rest is enough.", "🩺"],
		["Survival", "Forage Supplies", "item:Field Rations|item:Antitoxin", "You gather useful herbs and provisions. Field Rations and Antitoxin added to stash.", "none", "Slim pickings in the area. Nothing useful found.", "🌿"],
	], _show_rest_panel)

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
	_add_time_status(_info_vbox)
	_info_vbox.add_child(RimvaleUtils.spacer(4))

	var round_btn := RimvaleUtils.button("🍻 Buy a Round (25g, +30 XP) %s" % _time_cost_str(), RimvaleColors.ORANGE, 44, 13)
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

	var rumour_btn := RimvaleUtils.button("👂 Gather Rumours %s" % _time_cost_str(), RimvaleColors.CYAN, 44, 13)
	rumour_btn.pressed.connect(func():
		if not _try_action(_show_tavern_panel): return
		var rumours: Array = _content.get("rumours", ["Nothing interesting today."])
		var r: String = str(rumours[randi() % rumours.size()])
		_show_message("\"" + r + "\"", RimvaleColors.TEXT_LIGHT, _show_tavern_panel)
	)
	_info_vbox.add_child(rumour_btn)

	_info_vbox.add_child(RimvaleUtils.separator())
	var rest_btn := RimvaleUtils.button("☕ Short Rest (Restore Half HP) %s" % _time_cost_str(2), RimvaleColors.HP_GREEN, 38, 12)
	rest_btn.pressed.connect(func():
		if not _try_action(_show_tavern_panel, 2): return
		for h in GameState.get_active_handles():
			RimvaleAPI.engine.short_rest(h)
		GameState.save_game()
		_show_message("A brief rest. Your team recovers.", RimvaleColors.HP_GREEN, _show_tavern_panel)
	)
	_info_vbox.add_child(rest_btn)

	# Multi-step dialogue encounter
	var tavern_dialogue_key: String = "tavern_dialogue::" + _subregion
	if not GameState.social_cooldowns.has(tavern_dialogue_key):
		var story_btn := RimvaleUtils.button("🗣 Approach the Mysterious Stranger %s" % _time_cost_str(), RimvaleColors.ACCENT, 44, 13)
		story_btn.pressed.connect(func():
			GameState.social_cooldowns[tavern_dialogue_key] = true
			_start_dialogue(TAVERN_DIALOGUES, _show_tavern_panel)
		)
		_info_vbox.add_child(story_btn)

	# Group check encounter (high value)
	var group_key: String = "group_check::" + _subregion
	if not GameState.social_cooldowns.has(group_key):
		var group_btn := RimvaleUtils.button("⚡ Investigate the Commotion %s" % _time_cost_str(2), RimvaleColors.WARNING, 44, 13)
		group_btn.pressed.connect(func():
			GameState.social_cooldowns[group_key] = true
			_show_group_check_encounter(_show_tavern_panel)
		)
		_info_vbox.add_child(group_btn)

	# Social interactions
	_add_social_section(_info_vbox, "tavern", [
		["Speechcraft", "Sweet-Talk the Barkeep", "gold:30", "The barkeep shares secrets and comps your tab. +30 Gold.", "none", "The barkeep sees through your flattery. Maybe next time.", "🗣"],
		["Perform", "Entertain the Crowd", "xp:50|gold:20", "The crowd roars! Tips and fame. +50 XP, +20 Gold.", "none", "Tough crowd. A few polite claps.", "🎵"],
		["Intuition", "Read the Room", "xp:25|intel:Local power dynamics and hidden alliances observed", "You sense who is lying and who speaks truth. Valuable intel gained. +25 XP.", "none", "Too many conversations at once. You can't get a clear read.", "👁"],
		["Cunning", "Cheat at Cards", "gold:60", "Nobody suspects a thing. +60 Gold.", "lose_gold:30", "Caught! You pay gold to avoid a beating.", "🃏"],
	], _show_tavern_panel)

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
	_add_time_status(_info_vbox)
	_info_vbox.add_child(RimvaleUtils.spacer(4))

	var sharpen_btn := RimvaleUtils.button("⚔ Sharpen Weapons (+20 XP, 40g) %s" % _time_cost_str(), RimvaleColors.GOLD, 44, 13)
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

	var reinforce_btn := RimvaleUtils.button("🛡 Reinforce Armour (+1 AC, 60g) %s" % _time_cost_str(), RimvaleColors.CYAN, 44, 13)
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

	# Social interactions
	_add_social_section(_info_vbox, "smith", [
		["Crafting", "Assist at the Forge", "xp:40", "You work the bellows expertly. The smith is impressed. +40 XP.", "none", "You singe your eyebrows but learn nothing useful.", "🔨"],
		["Speechcraft", "Negotiate Bulk Deal", "gold:40", "The smith agrees to a standing discount. +40 Gold refund.", "none", "\"I don't do deals. Price is price.\"", "🗣"],
		["Creature Handling", "Calm the Pack Beast", "xp:30|item:Iron Shield", "The beast settles. The grateful smith gives you a spare shield. +30 XP.", "none", "The beast snorts and you back away carefully.", "🐴"],
	], _show_blacksmith_panel)

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
	_add_time_status(_info_vbox)
	_info_vbox.add_child(RimvaleUtils.spacer(4))

	var study_btn := RimvaleUtils.button("📖 Study Texts (+80 XP, 50g) %s" % _time_cost_str(), RimvaleColors.CYAN, 44, 13)
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

	var meditate_btn := RimvaleUtils.button("🧘 Meditate (Restore SP) %s" % _time_cost_str(), RimvaleColors.SP_PURPLE, 44, 13)
	meditate_btn.pressed.connect(func():
		if not _try_action(_show_library_panel): return
		for h in GameState.get_active_handles():
			RimvaleAPI.engine.restore_character_sp(h, 3)
		GameState.save_game()
		_show_message("Quiet meditation. +3 SP restored to each agent.", RimvaleColors.SP_PURPLE, _show_library_panel)
	)
	_info_vbox.add_child(meditate_btn)

	# Multi-step dialogue encounter
	var lib_dialogue_key: String = "library_dialogue::" + _subregion
	if not GameState.social_cooldowns.has(lib_dialogue_key):
		var scholar_btn := RimvaleUtils.button("📜 Speak with the Scholar %s" % _time_cost_str(), RimvaleColors.CYAN, 44, 13)
		scholar_btn.pressed.connect(func():
			GameState.social_cooldowns[lib_dialogue_key] = true
			_start_dialogue(LIBRARY_DIALOGUES, _show_library_panel)
		)
		_info_vbox.add_child(scholar_btn)

	# Social interactions
	_add_social_section(_info_vbox, "library", [
		["Learnedness", "Deep Study", "xp:100", "Breakthrough! Ancient knowledge flows into your mind. +100 XP.", "xp:20", "The texts are dense, but you learn a little. +20 XP.", "📖"],
		["Arcane", "Decipher Ancient Tome", "sp:5", "The arcane text resonates with your spirit. +5 SP to all.", "none", "The symbols swim before your eyes. Incomprehensible.", "✨"],
		["Intuition", "Search the Hidden Stacks", "item:Scroll of Protection", "Behind a false shelf you find a Scroll of Protection!", "none", "The library is vast but you find nothing unusual.", "🔍"],
	], _show_library_panel)

# ── Bounty Board ────────────────────────────────────────────────────────────

func _show_bounty_panel() -> void:
	_clear_info()
	_info_vbox.add_child(RimvaleUtils.label("📜  Bounty Board", 16, RimvaleColors.WARNING))
	var desc := RimvaleUtils.label(_content.get("bounty_desc",
		"Posted bounties. Each one pays on completion."), 11, RimvaleColors.TEXT_GRAY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(desc)
	_info_vbox.add_child(RimvaleUtils.separator())
	_add_time_status(_info_vbox)
	_info_vbox.add_child(RimvaleUtils.spacer(4))

	# Show player's current bounty status
	var region_bounty: int = int(GameState.bounty_per_region.get(GameState.current_region, 0))
	var bounty_rank: String = GameState.get_bounty_rank(GameState.current_region)
	var bounty_hbox = HBoxContainer.new()
	bounty_hbox.add_theme_constant_override("separation", 12)
	_info_vbox.add_child(bounty_hbox)

	var bounty_label: String = "Bounty Status: %s" % bounty_rank
	if region_bounty > 0:
		bounty_label += " (%d gold)" % region_bounty
	bounty_hbox.add_child(RimvaleUtils.label(bounty_label, 11, RimvaleColors.WARNING))

	if region_bounty > 0:
		var pay_btn = RimvaleUtils.button("Pay Bounty", RimvaleColors.WARNING, 24, 10)
		var cost_label = RimvaleUtils.label("(costs %d gold)" % region_bounty, 9, RimvaleColors.TEXT_GRAY)
		var pay_vbox = VBoxContainer.new()
		pay_vbox.add_theme_constant_override("separation", 2)
		pay_vbox.add_child(pay_btn)
		pay_vbox.add_child(cost_label)
		pay_btn.pressed.connect(func():
			if GameState.pay_bounty(GameState.current_region):
				GameState.save_game()
				_show_message("Bounty paid! You are now Clean.", RimvaleColors.ACCENT, _show_bounty_panel)
			else:
				_show_message("Insufficient gold to pay bounty.", RimvaleColors.DANGER, _show_bounty_panel)
		)
		bounty_hbox.add_child(pay_vbox)

	_info_vbox.add_child(RimvaleUtils.separator())
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

		var accept_btn := RimvaleUtils.button("Accept %s" % _time_cost_str(), RimvaleColors.WARNING, 28, 11)
		accept_btn.custom_minimum_size.x = 90
		var cap_terrain := bterrain; var cap_reward := breward
		accept_btn.pressed.connect(func():
			if not _try_action(_show_bounty_panel): return
			_launch_bounty(cap_terrain, cap_reward)
		)
		row.add_child(accept_btn)
		cvbox.add_child(row)
		_info_vbox.add_child(card)

	# Social interactions
	_add_social_section(_info_vbox, "bounty", [
		["Survival", "Track the Target", "xp:40", "You find tracks and shortcuts. The next bounty will be easier. +40 XP.", "none", "The trail goes cold. No useful leads.", "🐾"],
		["Perception", "Spot a Hidden Contract", "gold:80|intel:Private bounty contracts available for skilled agents", "A sealed note behind the board! A private contract worth 80 gold.", "none", "The board seems straightforward. Nothing hidden.", "👁"],
		["Cunning", "Forge a Completion Slip", "gold:100", "A convincing forgery. The clerk pays out 100 gold, no questions asked.", "lose_gold:40", "The clerk spots the fake! You pay a 40 gold penalty.", "📝"],
	], _show_bounty_panel)

func _launch_bounty(terrain: int, gold_reward: int) -> void:
	var handles: PackedInt64Array = GameState.get_active_handles()
	if handles.is_empty():
		_show_message("No active team!", RimvaleColors.DANGER, _show_bounty_panel)
		return

	var base_level: int = maxi(1, GameState.player_level)
	var enemy_level: int = clampi(base_level + randi_range(0, 2), 1, 15)
	GameState.earn_gold(gold_reward)
	GameState.save_game()

	# Save player position so we return to this tile after dungeon
	GameState.explore_return_pos = _player_pos
	GameState.explore_return_active = true
	GameState.dungeon_source = "explore"

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
	_add_time_status(_info_vbox)
	_info_vbox.add_child(RimvaleUtils.spacer(4))

	var wish_btn := RimvaleUtils.button("🪙 Toss a Coin (1 gold) %s" % _time_cost_str(), RimvaleColors.AP_BLUE, 44, 13)
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

	# Social interactions
	_add_social_section(_info_vbox, "fountain", [
		["Arcane", "Attune to the Waters", "sp:3|ap:3", "The waters sing with power. +3 SP and +3 AP to all.", "none", "The water is just... water.", "✨"],
		["Perception", "Search the Basin", "gold:45", "Glinting beneath the surface — coins! +45 Gold recovered.", "none", "Nothing but murky water and old pennies.", "👁"],
		["Perform", "Sing at the Fountain", "xp:60", "Passersby stop to listen. A crowd gathers, captivated. +60 XP.", "none", "Your voice echoes off the stone. Nobody stops.", "🎵"],
	], _show_fountain_panel)

# ══════════════════════════════════════════════════════════════════════════════
# ── Ledger House (Banking) ──────────────────────────────────────────────────────

func _show_ledger_house_panel() -> void:
	_clear_info()
	_info_vbox.add_child(RimvaleUtils.label("🏦  Ledger House", 16, RimvaleColors.GOLD))
	var desc := RimvaleUtils.label("A secure vault for deposits. Interest accrues at 5% per game day.", 11, RimvaleColors.TEXT_GRAY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(desc)
	_info_vbox.add_child(RimvaleUtils.separator())
	_add_time_status(_info_vbox)
	
	var balance: int = GameState.bank_balance
	_info_vbox.add_child(RimvaleUtils.label("Bank Balance: %d gold" % balance, 13, RimvaleColors.GOLD))
	_info_vbox.add_child(RimvaleUtils.label("Interest Rate: 5%% per day", 11, RimvaleColors.TEXT_DIM))
	
	if GameState.vault_seals.size() > 0:
		_info_vbox.add_child(RimvaleUtils.label("Vault Seals: %d" % GameState.vault_seals.size(), 11, RimvaleColors.ACCENT))
	
	_info_vbox.add_child(RimvaleUtils.separator())
	
	# Deposit controls
	var deposit_label := RimvaleUtils.label("DEPOSIT", 12, RimvaleColors.ACCENT)
	_info_vbox.add_child(deposit_label)
	
	var d100_btn := RimvaleUtils.button("Deposit 100g %s" % _time_cost_str(), RimvaleColors.GOLD, 44, 12)
	d100_btn.pressed.connect(func():
		if not _try_action(_show_ledger_house_panel): return
		if GameState.gold >= 100:
			GameState.gold -= 100
			GameState.bank_deposit(100)
			GameState.save_game()
			_show_message("100 gold deposited. Interest accrues daily.", RimvaleColors.GOLD, _show_ledger_house_panel)
		else:
			_show_message("Not enough gold!", RimvaleColors.DANGER, _show_ledger_house_panel)
	)
	_info_vbox.add_child(d100_btn)
	
	var dall_btn := RimvaleUtils.button("Deposit All %s" % _time_cost_str(), RimvaleColors.GOLD, 44, 12)
	dall_btn.pressed.connect(func():
		if not _try_action(_show_ledger_house_panel): return
		if GameState.gold > 0:
			var amt: int = GameState.gold
			GameState.gold = 0
			GameState.bank_deposit(amt)
			GameState.save_game()
			_show_message("%d gold deposited." % amt, RimvaleColors.GOLD, _show_ledger_house_panel)
		else:
			_show_message("No gold to deposit.", RimvaleColors.TEXT_DIM, _show_ledger_house_panel)
	)
	_info_vbox.add_child(dall_btn)
	
	_info_vbox.add_child(RimvaleUtils.spacer(6))
	
	# Withdraw controls
	var withdraw_label := RimvaleUtils.label("WITHDRAW", 12, RimvaleColors.ACCENT)
	_info_vbox.add_child(withdraw_label)
	
	var w100_btn := RimvaleUtils.button("Withdraw 100g %s" % _time_cost_str(), RimvaleColors.GOLD, 44, 12)
	w100_btn.pressed.connect(func():
		if not _try_action(_show_ledger_house_panel): return
		if GameState.bank_withdraw(100):
			GameState.gold += 100
			GameState.save_game()
			_show_message("100 gold withdrawn.", RimvaleColors.GOLD, _show_ledger_house_panel)
		else:
			_show_message("Insufficient bank balance!", RimvaleColors.DANGER, _show_ledger_house_panel)
	)
	_info_vbox.add_child(w100_btn)
	
	var wall_btn := RimvaleUtils.button("Withdraw All %s" % _time_cost_str(), RimvaleColors.GOLD, 44, 12)
	wall_btn.pressed.connect(func():
		if not _try_action(_show_ledger_house_panel): return
		if GameState.bank_balance > 0:
			var amt: int = GameState.bank_balance
			GameState.bank_withdraw(amt)
			GameState.gold += amt
			GameState.save_game()
			_show_message("%d gold withdrawn." % amt, RimvaleColors.GOLD, _show_ledger_house_panel)
		else:
			_show_message("Bank is empty.", RimvaleColors.TEXT_DIM, _show_ledger_house_panel)
	)
	_info_vbox.add_child(wall_btn)
	
	_info_vbox.add_child(RimvaleUtils.spacer(6))
	
	# Vault seal upgrades
	var seal_btn := RimvaleUtils.button("🔐 Buy Vault Seal (500g) %s" % _time_cost_str(), RimvaleColors.ACCENT, 44, 12)
	seal_btn.pressed.connect(func():
		if not _try_action(_show_ledger_house_panel): return
		if GameState.gold >= 500:
			GameState.gold -= 500
			GameState.vault_seals.append({"region_pair": GameState.current_region})
			GameState.save_game()
			_show_message("Vault seal acquired! Cross-region banking now available.", RimvaleColors.ACCENT, _show_ledger_house_panel)
		else:
			_show_message("Not enough gold for seal upgrade.", RimvaleColors.DANGER, _show_ledger_house_panel)
	)
	_info_vbox.add_child(seal_btn)

# ── Town Hall (Civic Rites) ─────────────────────────────────────────────────────

func _show_town_hall_panel() -> void:
	_clear_info()
	_info_vbox.add_child(RimvaleUtils.label("🏛  Town Hall", 16, Color(0.70, 0.60, 0.90)))
	var desc := RimvaleUtils.label("Center of civic governance. Perform rites to influence settlement development.", 11, RimvaleColors.TEXT_GRAY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(desc)
	_info_vbox.add_child(RimvaleUtils.separator())
	_add_time_status(_info_vbox)
	
	var sp: int = GameState.settlement_sp.get(GameState.current_region, 0)
	_info_vbox.add_child(RimvaleUtils.label("Settlement Points: %d" % sp, 13, RimvaleColors.SP_PURPLE))
	
	if _WS.REGION_GOVERNMENTS.has(GameState.current_region):
		var gov_type: String = str(_WS.REGION_GOVERNMENTS[GameState.current_region])
		var gov_name: String = gov_type
		if _WS.GOVERNMENT_TYPES.has(gov_type):
			gov_name = str(_WS.GOVERNMENT_TYPES[gov_type].get("name", gov_type))
		_info_vbox.add_child(RimvaleUtils.label("Government: %s" % gov_name, 11, RimvaleColors.TEXT_GRAY))
	
	_info_vbox.add_child(RimvaleUtils.separator())
	_info_vbox.add_child(RimvaleUtils.label("AVAILABLE RITES", 12, RimvaleColors.ACCENT))
	
	if sp < 1:
		_info_vbox.add_child(RimvaleUtils.label("(Earn settlement points to unlock civic rites)", 10, RimvaleColors.TEXT_DIM))
	else:
		for rite in _WS.CIVIC_RITES:
			var rite_name: String = str(rite.get("name", "Unknown Rite"))
			var sp_cost: int = int(rite.get("cost", 5))
			if sp >= sp_cost:
				var card := RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.DIVIDER, 6, 8)
				var cvbox := VBoxContainer.new()
				cvbox.add_theme_constant_override("separation", 4)
				card.add_child(cvbox)
				cvbox.add_child(RimvaleUtils.label(rite_name, 12, RimvaleColors.TEXT_WHITE))
				var eff := RimvaleUtils.label(str(rite.get("description", "")), 10, RimvaleColors.TEXT_GRAY)
				eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				cvbox.add_child(eff)
				
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 6)
				row.add_child(RimvaleUtils.label("Cost: %d SP" % sp_cost, 10, RimvaleColors.SP_PURPLE))
				var sp_ctrl := Control.new(); sp_ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(sp_ctrl)
				
				var perform_btn := RimvaleUtils.button("Perform %s" % _time_cost_str(), RimvaleColors.SP_PURPLE, 28, 11)
				perform_btn.custom_minimum_size.x = 80
				var cap_cost: int = sp_cost; var cap_rite: Dictionary = rite
				perform_btn.pressed.connect(func():
					if not _try_action(_show_town_hall_panel): return
					var current_sp: int = GameState.settlement_sp.get(GameState.current_region, 0)
					if current_sp >= cap_cost:
						GameState.settlement_sp[GameState.current_region] = current_sp - cap_cost
						GameState.save_game()
						_show_message("Civic rite performed! Settlement influenced.", RimvaleColors.SP_PURPLE, _show_town_hall_panel)
					else:
						_show_message("Not enough settlement points!", RimvaleColors.DANGER, _show_town_hall_panel)
				)
				row.add_child(perform_btn)
				cvbox.add_child(row)
				_info_vbox.add_child(card)

# ── Merchant Guild (Trading) ────────────────────────────────────────────────────

func _show_merchant_guild_panel() -> void:
	_clear_info()
	_info_vbox.add_child(RimvaleUtils.label("⚖  Merchant Guild", 16, RimvaleColors.ORANGE))
	var desc := RimvaleUtils.label("Trade goods and commodities. Prices vary by region and supply.", 11, RimvaleColors.TEXT_GRAY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(desc)
	_info_vbox.add_child(RimvaleUtils.separator())
	_add_time_status(_info_vbox)
	_info_vbox.add_child(RimvaleUtils.label("Gold: %d" % GameState.gold, 13, RimvaleColors.GOLD))
	
	if not GameState.has_meta("trade_inventory"):
		GameState.set_meta("trade_inventory", {})
	var inv: Dictionary = GameState.get_meta("trade_inventory")
	
	_info_vbox.add_child(RimvaleUtils.separator())
	_info_vbox.add_child(RimvaleUtils.label("TRADE GOODS", 12, RimvaleColors.ACCENT))
	_info_vbox.add_child(RimvaleUtils.spacer(2))
	
	for good in _WS.TRADE_GOODS:
		var good_name: String = str(good.get("name", "Good"))
		var base_value: int = int(good.get("base_value", 100))
		
		# Calculate regional price modifier
		var price_category: String = str(good.get("price_category", "standard"))
		var price_mod: float = 1.0
		if _WS.REGIONAL_PRICE_MODIFIERS.has(price_category):
			var mod_dict: Dictionary = _WS.REGIONAL_PRICE_MODIFIERS[price_category]
			if mod_dict.has(GameState.current_region):
				price_mod = float(mod_dict[GameState.current_region])
		
		# Vary price with randomness (seeded per region)
		var seed_val: int = hash(GameState.current_region + good_name) + GameState.day_counter
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val
		var buy_price: int = maxi(1, int(float(base_value) * price_mod * (0.8 + rng.randf() * 0.4)))
		var sell_price: int = maxi(1, int(float(base_value) * price_mod * 0.6))
		
		var quantity: int = inv.get(good_name, 0)
		
		var card := RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.DIVIDER, 6, 8)
		var cvbox := VBoxContainer.new()
		cvbox.add_theme_constant_override("separation", 4)
		card.add_child(cvbox)
		
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 4)
		title_row.add_child(RimvaleUtils.label(good_name, 12, RimvaleColors.TEXT_WHITE))
		if quantity > 0:
			var qty_lbl := RimvaleUtils.label("(x%d)" % quantity, 10, RimvaleColors.TEXT_DIM)
			title_row.add_child(qty_lbl)
		cvbox.add_child(title_row)
		
		var prices_row := HBoxContainer.new()
		prices_row.add_theme_constant_override("separation", 12)
		prices_row.add_child(RimvaleUtils.label("Buy: %dg" % buy_price, 10, RimvaleColors.GOLD))
		prices_row.add_child(RimvaleUtils.label("Sell: %dg" % sell_price, 10, RimvaleColors.ORANGE))
		cvbox.add_child(prices_row)
		
		var buttons_row := HBoxContainer.new()
		buttons_row.add_theme_constant_override("separation", 4)
		
		var buy_btn := RimvaleUtils.button("Buy", RimvaleColors.GOLD, 20, 10)
		buy_btn.custom_minimum_size.x = 40
		var cap_good := good_name; var cap_buy := buy_price
		buy_btn.pressed.connect(func():
			if not _try_action(_show_merchant_guild_panel): return
			if GameState.gold >= cap_buy:
				GameState.gold -= cap_buy
				var current_inv: Dictionary = GameState.get_meta("trade_inventory")
				current_inv[cap_good] = current_inv.get(cap_good, 0) + 1
				GameState.save_game()
				_show_merchant_guild_panel()
			else:
				_show_message("Not enough gold!", RimvaleColors.DANGER, _show_merchant_guild_panel)
		)
		buttons_row.add_child(buy_btn)
		
		var sell_btn := RimvaleUtils.button("Sell", RimvaleColors.ORANGE, 20, 10)
		sell_btn.custom_minimum_size.x = 40
		var cap_sell := sell_price
		sell_btn.pressed.connect(func():
			if not _try_action(_show_merchant_guild_panel): return
			var current_inv: Dictionary = GameState.get_meta("trade_inventory")
			if current_inv.get(cap_good, 0) > 0:
				current_inv[cap_good] -= 1
				# Apply government tax on selling
				var gov_type_sell: String = str(_WS.REGION_GOVERNMENTS.get(GameState.current_region, "republic"))
				var gov_sell: Dictionary = _WS.GOVERNMENT_TYPES.get(gov_type_sell, {})
				var tax_rate: float = float(gov_sell.get("tax_rate", 0.08))
				var gold_after_tax: int = int(float(cap_sell) * (1.0 - tax_rate))
				GameState.gold += gold_after_tax
				GameState.save_game()
				_show_merchant_guild_panel()
			else:
				_show_message("None in inventory!", RimvaleColors.DANGER, _show_merchant_guild_panel)
		)
		buttons_row.add_child(sell_btn)
		cvbox.add_child(buttons_row)
		_info_vbox.add_child(card)

#  RANDOM NPC ENCOUNTER & RECRUITMENT SYSTEM
# ══════════════════════════════════════════════════════════════════════════════

func _init_random_npcs() -> void:
	_spawned_npcs.clear()
	_npc_positions.clear()
	_npc_markers.clear()

	# Get 3-5 random NPCs seeded by subregion name (deterministic per map)
	var seed_val: int = hash(_subregion) + 9999
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var npc_count: int = rng.randi_range(3, 5)
	var npcs: Array = NpcBackstories.get_random_npcs(npc_count, seed_val)

	# Filter out already-recruited NPCs
	var available: Array = []
	for npc in npcs:
		if not GameState.recruited_npc_names.has(str(npc.get("name", ""))):
			available.append(npc)

	# Place each NPC on a walkable tile
	var placed: int = 0
	var attempts: int = 0
	var spawn: Vector2i = _map_data.get("player_spawn", Vector2i(15, 19))
	while placed < available.size() and attempts < 300:
		attempts += 1
		var tx: int = rng.randi_range(2, GRID_W - 3)
		var ty: int = rng.randi_range(2, GRID_H - 3)
		if not _is_walkable(tx, ty): continue
		if _poi_map.has(Vector2i(tx, ty)): continue
		if _hidden_cache_map.has(Vector2i(tx, ty)): continue
		if _npc_positions.has(Vector2i(tx, ty)): continue
		if abs(tx - spawn.x) + abs(ty - spawn.y) < 4: continue

		var npc: Dictionary = available[placed].duplicate()
		var pos := Vector2i(tx, ty)
		npc["pos"] = pos
		_spawned_npcs.append(npc)
		_npc_positions[pos] = npc

		# Build 3D marker using lineage portrait
		var npc_lineage: String = str(npc.get("lineage", "Elf"))
		var marker := _build_npc_marker(pos, npc_lineage)
		_npc_markers[pos] = marker
		placed += 1

	# Place named NPCs for the current region
	for npc_data in _WS.NAMED_NPCS:
		if str(npc_data.get("region", "")) != GameState.current_region:
			continue
		# Skip if already recruited
		if GameState.recruited_npc_names.has(str(npc_data.get("name", ""))):
			continue
		# Try to find a walkable spawn position
		var named_attempts: int = 0
		while named_attempts < 100:
			named_attempts += 1
			var tx: int = rng.randi_range(2, GRID_W - 3)
			var ty: int = rng.randi_range(2, GRID_H - 3)
			if not _is_walkable(tx, ty): continue
			if _poi_map.has(Vector2i(tx, ty)): continue
			if _hidden_cache_map.has(Vector2i(tx, ty)): continue
			if _npc_positions.has(Vector2i(tx, ty)): continue
			if abs(tx - spawn.x) + abs(ty - spawn.y) < 4: continue

			var npc: Dictionary = npc_data.duplicate()
			var pos := Vector2i(tx, ty)
			npc["pos"] = pos
			npc["is_named"] = true  # Mark as named NPC for special handling
			_spawned_npcs.append(npc)
			_npc_positions[pos] = npc

			# Build 3D marker using lineage portrait (use Human default for named NPCs)
			var marker := _build_npc_marker(pos, "Human")
			_npc_markers[pos] = marker
			break

func _build_npc_marker(pos: Vector2i, lineage: String) -> Node3D:
	var marker := Node3D.new()
	var world_pos: Vector3 = _tile_to_world(pos.x, pos.y)
	marker.position = world_pos

	# Build a sprite model using the NPC's lineage portrait
	var npc_color := Color(0.3, 0.85, 1.0)  # cyan tint for NPC identification
	var model: Node3D = CharacterModelBuilder.build_sprite_model(
		lineage, "None", "None", "None", 0.50, npc_color)
	if model != null:
		model.position.y = 0.0
		marker.add_child(model)
	else:
		# Fallback capsule if no portrait available
		var capsule := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.12; cm.height = 0.5
		capsule.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = npc_color
		mat.emission_enabled = true
		mat.emission = npc_color
		mat.emission_energy_multiplier = 1.5
		capsule.material_override = mat
		capsule.position.y = 0.3
		marker.add_child(capsule)

	# Floating question mark diamond above the NPC
	var icon_mesh := MeshInstance3D.new()
	var icon_box := BoxMesh.new()
	icon_box.size = Vector3(0.08, 0.08, 0.08)
	icon_mesh.mesh = icon_box
	icon_mesh.position = Vector3(0, 0.7, 0)
	icon_mesh.rotation_degrees = Vector3(45, 45, 0)
	var icon_mat := StandardMaterial3D.new()
	icon_mat.albedo_color = Color(1.0, 0.9, 0.3, 0.9)
	icon_mat.emission_enabled = true
	icon_mat.emission = Color(1.0, 0.9, 0.3)
	icon_mat.emission_energy_multiplier = 2.5
	icon_mesh.material_override = icon_mat
	marker.add_child(icon_mesh)

	_world3d_root.add_child(marker)
	return marker

func _show_npc_panel(npc: Dictionary) -> void:
	_clear_info()
	var npc_name: String = str(npc.get("name", "Stranger"))
	var lineage: String = str(npc.get("lineage", "Unknown"))
	var personality: String = str(npc.get("personality", ""))
	var backstory: String = str(npc.get("backstory", ""))
	var skill_affinity: String = str(npc.get("skill_affinity", "Speechcraft"))
	var recruit_quest: String = str(npc.get("recruit_quest", ""))
	var recruit_dc: int = int(npc.get("recruit_dc", 12))
	var combat_class: String = str(npc.get("combat_class", "warrior"))
	var trust: int = int(GameState.npc_trust.get(npc_name, 0))

	# Special handling for named NPCs
	var is_named: bool = bool(npc.get("is_named", false))
	if is_named:
		var npc_desc: String = str(npc.get("desc", ""))
		var npc_dialogue: Array = npc.get("dialogue", [])
		var npc_quest_hook: String = str(npc.get("quest_hook", ""))
		backstory = npc_desc
		personality = "Named Lore NPC"
		recruit_quest = npc_quest_hook if not npc_quest_hook.is_empty() else npc_dialogue[0] if not npc_dialogue.is_empty() else "Seek knowledge."
		recruit_dc = 10

	# Header
	_info_vbox.add_child(RimvaleUtils.label("👤 " + npc_name, 16, RimvaleColors.CYAN))
	var subtitle := RimvaleUtils.label("%s • %s • %s" % [lineage, personality, combat_class.capitalize()], 11, RimvaleColors.TEXT_GRAY)
	_info_vbox.add_child(subtitle)
	_info_vbox.add_child(RimvaleUtils.spacer(2))

	var story_lbl := RimvaleUtils.label(backstory, 11, RimvaleColors.TEXT_DIM)
	story_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(story_lbl)
	_info_vbox.add_child(RimvaleUtils.separator())

	# Trust level display
	var trust_names: Array = ["Stranger", "Acquaintance", "Trusted", "Recruited"]
	var trust_colors: Array = [RimvaleColors.TEXT_DIM, RimvaleColors.WARNING, RimvaleColors.HP_GREEN, RimvaleColors.GOLD]
	var trust_idx: int = clampi(trust, 0, 3)
	_info_vbox.add_child(RimvaleUtils.label("Trust: %s (%d/3)" % [trust_names[trust_idx], trust], 12, trust_colors[trust_idx]))

	# Relationship event text
	var rel_event: String = _get_relationship_event(npc, trust)
	if not rel_event.is_empty():
		var ev_lbl := RimvaleUtils.label(rel_event, 11, RimvaleColors.CYAN)
		ev_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info_vbox.add_child(ev_lbl)

	# Personality modifier hint
	var pers_mod: int = _npc_personality_dc_mod(npc)
	if pers_mod < 0:
		_info_vbox.add_child(RimvaleUtils.label("Personality: Approachable (DC -%d)" % abs(pers_mod), 10, RimvaleColors.HP_GREEN))
	elif pers_mod > 0:
		_info_vbox.add_child(RimvaleUtils.label("Personality: Guarded (DC +%d)" % pers_mod, 10, RimvaleColors.WARNING))

	_info_vbox.add_child(RimvaleUtils.spacer(4))
	_add_time_status(_info_vbox)
	_info_vbox.add_child(RimvaleUtils.spacer(4))

	var cap_npc: Dictionary = npc
	var cap_name: String = npc_name

	if trust < 3:
		# Social interaction to build trust
		var talk_skill: String = skill_affinity
		var talk_info: Array = _best_party_skill(talk_skill)
		var talk_mod: int = talk_info[1]
		var talk_dc: int = recruit_dc + _npc_personality_dc_mod(npc)
		var talk_key: String = "npc::" + npc_name

		var already_talked: bool = GameState.social_cooldowns.has(talk_key)
		var talk_color: Color = RimvaleColors.TEXT_DIM if already_talked else RimvaleColors.ACCENT
		var talk_suffix: String = " (done)" if already_talked else " %s" % _time_cost_str()
		var talk_btn := RimvaleUtils.button(
			"🗣 Talk [%s +%d vs DC %d]%s" % [talk_skill, talk_mod, talk_dc, talk_suffix],
			talk_color, 38, 11)
		if already_talked:
			talk_btn.disabled = true
		var cap_skill: String = talk_skill
		var cap_dc: int = talk_dc
		var cap_key: String = talk_key
		talk_btn.pressed.connect(func():
			if not _try_action(func(): _show_npc_panel(cap_npc)): return
			var best: Array = _best_party_skill(cap_skill)
			var h: int = best[0]
			if h < 0:
				_show_message("No party member available.", RimvaleColors.DANGER, func(): _show_npc_panel(cap_npc))
				return
			var result: PackedStringArray = RimvaleAPI.engine.execute_skill_challenge(h, cap_skill, cap_dc)
			var passed: bool = str(result[0]) == "1"
			var detail: String = str(result[4])
			GameState.social_cooldowns[cap_key] = true
			if passed:
				var old_trust: int = int(GameState.npc_trust.get(cap_name, 0))
				GameState.npc_trust[cap_name] = mini(old_trust + 1, 2)
				GameState.save_game()
				if GameState.npc_trust[cap_name] >= 2:
					_show_skill_result(detail, "%s trusts you now! They ask for your help: \"%s\"" % [cap_name, str(cap_npc.get("recruit_quest", "Help me."))], RimvaleColors.HP_GREEN, func(): _show_npc_panel(cap_npc))
				else:
					_show_skill_result(detail, "%s warms up to you. Trust increased!" % cap_name, RimvaleColors.HP_GREEN, func(): _show_npc_panel(cap_npc))
			else:
				_show_skill_result(detail, "%s remains guarded. Try again next visit." % cap_name, RimvaleColors.WARNING, func(): _show_npc_panel(cap_npc))
		)
		_info_vbox.add_child(talk_btn)

		# Perform skill — alternate social approach
		if talk_skill != "Perform":
			var perf_info: Array = _best_party_skill("Perform")
			var perf_mod: int = perf_info[1]
			var perf_key: String = "npc_perf::" + npc_name
			var perf_done: bool = GameState.social_cooldowns.has(perf_key)
			var perf_color: Color = RimvaleColors.TEXT_DIM if perf_done else RimvaleColors.ACCENT
			var perf_suffix: String = " (done)" if perf_done else " %s" % _time_cost_str()
			var perf_btn := RimvaleUtils.button(
				"🎵 Perform [Perform +%d vs DC %d]%s" % [perf_mod, talk_dc, perf_suffix],
				perf_color, 38, 11)
			if perf_done:
				perf_btn.disabled = true
			var cap_perf_key: String = perf_key
			perf_btn.pressed.connect(func():
				if not _try_action(func(): _show_npc_panel(cap_npc)): return
				var best: Array = _best_party_skill("Perform")
				var h: int = best[0]
				if h < 0:
					_show_message("No party member available.", RimvaleColors.DANGER, func(): _show_npc_panel(cap_npc))
					return
				var result: PackedStringArray = RimvaleAPI.engine.execute_skill_challenge(h, "Perform", cap_dc)
				var passed: bool = str(result[0]) == "1"
				var detail: String = str(result[4])
				GameState.social_cooldowns[cap_perf_key] = true
				if passed:
					var old_trust: int = int(GameState.npc_trust.get(cap_name, 0))
					GameState.npc_trust[cap_name] = mini(old_trust + 1, 2)
					GameState.save_game()
					_show_skill_result(detail, "%s is charmed by your performance! Trust increased." % cap_name, RimvaleColors.HP_GREEN, func(): _show_npc_panel(cap_npc))
				else:
					_show_skill_result(detail, "A lukewarm reception. %s is unimpressed." % cap_name, RimvaleColors.WARNING, func(): _show_npc_panel(cap_npc))
			)
			_info_vbox.add_child(perf_btn)

		# If trust is at 2 (Trusted), show the quest/recruit option
		if trust >= 2:
			_info_vbox.add_child(RimvaleUtils.separator())
			_info_vbox.add_child(RimvaleUtils.label("📋 Quest: %s" % recruit_quest, 12, RimvaleColors.WARNING))
			_info_vbox.add_child(RimvaleUtils.spacer(2))

			var has_active_quest: bool = GameState.npc_active_quests.has(npc_name)
			if not has_active_quest:
				var accept_btn := RimvaleUtils.button("✦ Accept Quest %s" % _time_cost_str(), RimvaleColors.WARNING, 38, 12)
				accept_btn.pressed.connect(func():
					if not _try_action(func(): _show_npc_panel(cap_npc)): return
					GameState.npc_active_quests[cap_name] = str(cap_npc.get("recruit_quest", ""))
					GameState.save_game()
					_show_message("Quest accepted! Complete a dungeon bounty to fulfill %s's request." % cap_name, RimvaleColors.WARNING, func(): _show_npc_panel(cap_npc))
				)
				_info_vbox.add_child(accept_btn)
			else:
				_info_vbox.add_child(RimvaleUtils.label("Quest active — complete a bounty dungeon to fulfill it.", 11, RimvaleColors.TEXT_DIM))
				# Complete quest button (requires having done at least 1 bounty/dungeon)
				var complete_btn := RimvaleUtils.button("✦ Complete Quest & Recruit %s" % _time_cost_str(), RimvaleColors.HP_GREEN, 38, 12)
				complete_btn.pressed.connect(func():
					if not _try_action(func(): _show_npc_panel(cap_npc)): return
					_recruit_npc(cap_npc)
				)
				_info_vbox.add_child(complete_btn)
	else:
		# Already recruited
		_info_vbox.add_child(RimvaleUtils.label("✅ %s has joined your roster!" % npc_name, 13, RimvaleColors.GOLD))

	# Gift option — costs gold for trust
	if trust < 3:
		_info_vbox.add_child(RimvaleUtils.spacer(4))
		var gift_cost: int = 25 + GameState.player_level * 5
		var gift_key: String = "npc_gift::" + npc_name
		var gift_done: bool = GameState.social_cooldowns.has(gift_key)
		var gift_color: Color = RimvaleColors.TEXT_DIM if gift_done else RimvaleColors.GOLD
		var gift_suffix: String = " (done)" if gift_done else ""
		var gift_btn := RimvaleUtils.button(
			"🎁 Give Gift (%dg)%s" % [gift_cost, gift_suffix],
			gift_color, 34, 11)
		if gift_done or GameState.gold < gift_cost:
			gift_btn.disabled = true
		var cap_gift_key: String = gift_key
		var cap_gift_cost: int = gift_cost
		gift_btn.pressed.connect(func():
			if GameState.gold < cap_gift_cost:
				_show_message("Not enough gold.", RimvaleColors.DANGER, func(): _show_npc_panel(cap_npc))
				return
			GameState.gold -= cap_gift_cost
			GameState.social_cooldowns[cap_gift_key] = true
			var old_trust: int = int(GameState.npc_trust.get(cap_name, 0))
			GameState.npc_trust[cap_name] = mini(old_trust + 1, 2)
			GameState.save_game()
			_show_message("%s gratefully accepts your gift. Trust increased!" % cap_name, RimvaleColors.HP_GREEN, func(): _show_npc_panel(cap_npc))
		)
		_info_vbox.add_child(gift_btn)

func _recruit_npc(npc: Dictionary) -> void:
	var npc_name: String = str(npc.get("name", "Recruit"))
	var lineage: String = str(npc.get("lineage", "Elf"))
	var combat_class: String = str(npc.get("combat_class", "warrior"))
	var skill_affinity: String = str(npc.get("skill_affinity", "Exertion"))

	# Skill name → index: Arcane=0, Crafting=1, Creature Handling=2, Cunning=3,
	# Exertion=4, Intuition=5, Learnedness=6, Medical=7, Nimble=8, Perception=9,
	# Perform=10, Sneak=11, Speechcraft=12, Survival=13
	const SKILL_LOOKUP: Dictionary = {
		"Arcane": 0, "Crafting": 1, "Creature Handling": 2, "Cunning": 3,
		"Exertion": 4, "Intuition": 5, "Learnedness": 6, "Medical": 7,
		"Nimble": 8, "Perception": 9, "Perform": 10, "Sneak": 11,
		"Speechcraft": 12, "Survival": 13,
	}

	# Create the character in the engine
	var age: int = randi_range(18, 50)
	var h: int = RimvaleAPI.engine.create_character(npc_name, lineage, age)

	# Level up to match player level
	var target_level: int = maxi(1, GameState.player_level)
	var cd: Dictionary = RimvaleAPI.engine.get_char_dict(h)
	if cd != null:
		cd["level"] = target_level
		cd["max_hp"] = 20 + (target_level - 1) * 8
		cd["hp"] = cd["max_hp"]
		cd["max_sp"] = 6 + (target_level - 1) * 2
		cd["sp"] = cd["max_sp"]
		cd["ac"] = 10 + target_level / 3
		cd["stat_pts"] = 0
		cd["feat_pts"] = target_level / 3
		cd["skill_pts"] = 0
		cd["xp"] = 0
		cd["xp_req"] = 100 * target_level

		# Ensure skills array exists
		var skills: Array = cd.get("skills", [0,0,0,0,0,0,0,0,0,0,0,0,0,0])
		while skills.size() < 14: skills.append(0)

		# Set base stats and skills by combat class
		var stats: Array = cd.get("stats", [1,1,1,1,1])
		match combat_class:
			"warrior":
				stats[0] = 3 + target_level / 2  # STR
				stats[3] = 2 + target_level / 3  # VIT
				skills[4] = 3 + target_level      # Exertion
				skills[8] = 1 + target_level / 2  # Nimble
				cd["ac"] += 2; cd["max_hp"] += target_level * 3
				cd["hp"] = cd["max_hp"]
			"mage":
				stats[4] = 3 + target_level / 2  # DIV
				stats[2] = 2 + target_level / 3  # INT
				skills[0] = 3 + target_level      # Arcane
				skills[6] = 2 + target_level / 2  # Learnedness
				cd["max_sp"] += target_level * 2; cd["sp"] = cd["max_sp"]
			"healer":
				stats[2] = 3 + target_level / 2  # INT
				stats[4] = 2 + target_level / 3  # DIV
				skills[7] = 3 + target_level      # Medical
				skills[5] = 2 + target_level / 2  # Intuition
				cd["max_sp"] += target_level; cd["sp"] = cd["max_sp"]
			"rogue":
				stats[1] = 3 + target_level / 2  # SPD
				stats[2] = 2 + target_level / 3  # INT
				skills[11] = 3 + target_level     # Sneak
				skills[3] = 2 + target_level / 2  # Cunning
				skills[8] = 1 + target_level / 2  # Nimble
			"ranger":
				stats[3] = 3 + target_level / 2  # VIT
				stats[0] = 2 + target_level / 3  # STR
				skills[13] = 3 + target_level     # Survival
				skills[9] = 2 + target_level / 2  # Perception
				skills[2] = 1 + target_level / 2  # Creature Handling
			"support":
				stats[4] = 3 + target_level / 2  # DIV
				stats[2] = 2 + target_level / 3  # INT
				skills[12] = 3 + target_level     # Speechcraft
				skills[10] = 2 + target_level / 2 # Perform
				skills[5] = 1 + target_level / 2  # Intuition
		cd["stats"] = stats

		# Boost their affinity skill
		var aff_idx: int = SKILL_LOOKUP.get(skill_affinity, -1)
		if aff_idx >= 0:
			skills[aff_idx] = maxi(skills[aff_idx], 3 + target_level)
		cd["skills"] = skills

	# Add to collection so they appear on the Units page
	GameState.add_to_collection(h)

	# Mark as recruited
	GameState.npc_trust[npc_name] = 3
	GameState.recruited_npc_names.append(npc_name)
	if GameState.npc_active_quests.has(npc_name):
		GameState.npc_active_quests.erase(npc_name)

	# Remove NPC marker from map
	var pos: Vector2i = npc.get("pos", Vector2i(-1, -1))
	if _npc_markers.has(pos):
		_npc_markers[pos].queue_free()
		_npc_markers.erase(pos)
	if _npc_positions.has(pos):
		_npc_positions.erase(pos)

	# Grant XP for recruitment
	for ph in GameState.get_active_handles():
		RimvaleAPI.engine.add_xp(ph, 50, 20)
	GameState.player_xp += 50
	GameState.save_game()

	_show_message("✦ %s has joined your roster! +50 XP. Assign them to your active team at any ACF outpost." % npc_name, RimvaleColors.GOLD, _show_location_info)

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
		POI_LEDGER:     return "🏦"
		POI_TOWN_HALL:  return "🏛"
		POI_GUILD:      return "⚖"
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
		POI_LEDGER:     return RimvaleColors.GOLD
		POI_TOWN_HALL:  return Color(0.70, 0.60, 0.90)
		POI_GUILD:      return RimvaleColors.ORANGE
		POI_EXIT:       return RimvaleColors.TEXT_GRAY
	return RimvaleColors.TEXT_WHITE

# ══════════════════════════════════════════════════════════════════════════════
#  SOCIAL SKILL INTERACTIONS
# ══════════════════════════════════════════════════════════════════════════════

## Returns the best party member handle + total modifier for a given skill.
func _best_party_skill(skill_name: String) -> Array:  # [handle, modifier]
	var e = RimvaleAPI.engine
	const SK_NAMES: Array = [
		"Arcane","Crafting","Creature Handling","Cunning","Exertion",
		"Intuition","Learnedness","Medical","Nimble","Perception",
		"Perform","Sneak","Speechcraft","Survival"
	]
	const SK_STAT: Array = [4,2,0,1,0, 4,2,2,1,3, 4,1,4,3]
	var skill_idx: int = SK_NAMES.find(skill_name)
	if skill_idx < 0: return [-1, 0]
	var best_h: int = -1
	var best_mod: int = -999
	for h in GameState.get_active_handles():
		var cd: Dictionary = e.get_char_dict(h)
		if cd == null: continue
		var rank: int = e.get_character_skill(h, skill_idx)
		var stats: Array = cd.get("stats", [1,1,1,1,1])
		var mod: int = rank + int(stats[SK_STAT[skill_idx]])
		if mod > best_mod:
			best_mod = mod; best_h = h
	return [best_h, best_mod]

## Base DC that scales with region difficulty (player level).
## Faction reputation modifies the DC: high rep lowers it, low rep raises it.
func _social_dc() -> int:
	var base: int = 8 + GameState.player_level
	var region_key: String = WorldData.subregion_to_key(_subregion)
	var f_info: Dictionary = WorldData.get_faction_for_region(region_key)
	var f_name: String = str(f_info.get("name", ""))
	if not f_name.is_empty():
		var rep: int = int(GameState.faction_reputation.get(f_name, 0))
		# Every 25 rep = +/-1 DC adjustment
		base -= rep / 25
	base += _get_consequence_penalty()
	return maxi(5, base)

## Adds a "Social Interactions" section to the given parent VBox.
## actions: Array of arrays: [skill_name, label, success_reward, success_msg, fail_reward, fail_msg, icon]
## Reward format: "gold:30", "xp:50", "sp:5", "item:Health Potion", "heal:full", "heal:half",
##   "ap:3", "lose_gold:30", "none", or combined "gold:20|xp:50"
func _add_social_section(parent: VBoxContainer, poi_key: String,
		actions: Array, return_panel: Callable) -> void:
	parent.add_child(RimvaleUtils.separator())
	parent.add_child(RimvaleUtils.label("💬 Social Interactions", 13, RimvaleColors.ACCENT))
	parent.add_child(RimvaleUtils.spacer(2))

	for act in actions:
		var skill_name: String = str(act[0])
		var btn_label: String = str(act[1])
		var s_reward: String = str(act[2])
		var s_msg: String = str(act[3])
		var f_reward: String = str(act[4])
		var f_msg: String = str(act[5])
		var icon: String = str(act[6]) if act.size() > 6 else "🎭"

		var cooldown_key: String = poi_key + "::" + skill_name
		var already_used: bool = GameState.social_cooldowns.has(cooldown_key)

		var info: Array = _best_party_skill(skill_name)
		var best_mod: int = info[1]
		var dc: int = _social_dc()
		# Show combo potential
		var combo_preview: int = _check_skill_combo(skill_name)
		# Undo the append from preview since we're just displaying
		if _skills_used_this_poi.size() > 0 and _skills_used_this_poi[-1] == skill_name:
			_skills_used_this_poi.pop_back()
		var combo_str: String = " +%d combo" % combo_preview if combo_preview > 0 else ""

		var color: Color = RimvaleColors.TEXT_DIM if already_used else RimvaleColors.ACCENT
		var suffix: String = " (done)" if already_used else " %s" % _time_cost_str()
		var btn := RimvaleUtils.button(
			"%s %s [%s +%d vs DC %d]%s%s" % [icon, btn_label, skill_name, best_mod, dc, combo_str, suffix],
			color, 38, 11)
		if already_used:
			btn.disabled = true

		var sk_cap: String = skill_name
		var cd_cap: String = cooldown_key
		var sr_cap: String = s_reward
		var sm_cap: String = s_msg
		var fr_cap: String = f_reward
		var fm_cap: String = f_msg
		var rp_cap: Callable = return_panel
		btn.pressed.connect(func():
			if not _try_action(rp_cap): return
			var best: Array = _best_party_skill(sk_cap)
			var h: int = best[0]
			if h < 0:
				_show_message("No party member available.", RimvaleColors.DANGER, rp_cap)
				return
			# Apply skill combo bonus (lowers effective DC)
			var combo_bonus: int = _check_skill_combo(sk_cap)
			var effective_dc: int = maxi(5, _social_dc() - combo_bonus)
			var result: PackedStringArray = RimvaleAPI.engine.execute_skill_challenge(h, sk_cap, effective_dc)
			var passed: bool = str(result[0]) == "1"
			var detail: String = str(result[4])
			if combo_bonus > 0:
				detail += "\n[Skill Combo: -%d DC]" % combo_bonus
			GameState.social_cooldowns[cd_cap] = true
			# Auto-adjust faction reputation based on result
			var region_key: String = WorldData.subregion_to_key(_subregion)
			var f_info: Dictionary = WorldData.get_faction_for_region(region_key)
			var f_name: String = str(f_info.get("name", ""))
			if passed:
				_apply_social_reward(sr_cap)
				if not f_name.is_empty():
					var rep_gain: int = 5
					if sk_cap == "Cunning":
						rep_gain = -3  # Criminal success still risky
					GameState.change_faction_rep(f_name, rep_gain)
				_show_skill_result(detail, sm_cap, RimvaleColors.HP_GREEN, rp_cap)
			else:
				_apply_social_reward(fr_cap)
				if not f_name.is_empty():
					var rep_loss: int = -2
					if sk_cap == "Cunning":
						rep_loss = -10  # Getting caught is bad
						GameState.social_consequences["caught_stealing"] = true
					GameState.change_faction_rep(f_name, rep_loss)
				_show_skill_result(detail, fm_cap, RimvaleColors.WARNING, rp_cap)
		)
		parent.add_child(btn)

## Apply a reward string like "gold:30", "xp:50|gold:20", "item:Health Potion", etc.
func _apply_social_reward(reward_str: String) -> void:
	if reward_str == "none" or reward_str.is_empty():
		return
	var parts: PackedStringArray = reward_str.split("|")
	for part in parts:
		var kv: PackedStringArray = part.split(":", true, 1)
		if kv.size() < 2: continue
		var key: String = kv[0].strip_edges()
		var val: String = kv[1].strip_edges()
		match key:
			"gold":
				GameState.earn_gold(int(val))
			"xp":
				for h in GameState.get_active_handles():
					RimvaleAPI.engine.add_xp(h, int(val), 20)
				GameState.player_xp += int(val)
			"sp":
				for h in GameState.get_active_handles():
					RimvaleAPI.engine.restore_character_sp(h, int(val))
			"ap":
				for h in GameState.get_active_handles():
					var cd: Dictionary = RimvaleAPI.engine.get_char_dict(h)
					if cd != null:
						cd["ap"] = mini(int(cd.get("ap", 0)) + int(val), int(cd.get("max_ap", 10)))
			"item":
				GameState.add_to_stash(val)
			"heal":
				if val == "full":
					for h in GameState.get_active_handles():
						var cd: Dictionary = RimvaleAPI.engine.get_char_dict(h)
						if cd != null:
							cd["hp"] = int(cd.get("max_hp", 20))
							cd["ap"] = int(cd.get("max_ap", 10))
				elif val == "half":
					for h in GameState.get_active_handles():
						RimvaleAPI.engine.short_rest(h)
				else:
					for h in GameState.get_active_handles():
						var cd: Dictionary = RimvaleAPI.engine.get_char_dict(h)
						if cd != null:
							var heal_amt: int = int(val)
							cd["hp"] = mini(int(cd.get("hp", 1)) + heal_amt, int(cd.get("max_hp", 20)))
			"lose_gold":
				var loss: int = mini(int(val), GameState.gold)
				GameState.gold -= loss
				# Apply crime severity based on government type
				var gov_type: String = str(_WS.REGION_GOVERNMENTS.get(GameState.current_region, "republic"))
				var gov: Dictionary = _WS.GOVERNMENT_TYPES.get(gov_type, {})
				var crime_sev: float = float(gov.get("crime_severity", 1.0))
				if crime_sev > 0:
					GameState.add_bounty(GameState.current_region, int(20 * crime_sev))
					GameState.add_reputation_event("crime", -int(10 * crime_sev), GameState.current_region)
			"rep":
				# Format: "rep:FactionName:delta" — handled by split on ":"
				# Already split on ":", so val contains "FactionName:delta"
				var rep_parts: PackedStringArray = val.split(":", true, 1)
				if rep_parts.size() >= 2:
					GameState.change_faction_rep(rep_parts[0].strip_edges(), int(rep_parts[1]))
			"intel":
				if not GameState.gathered_intel.has(val):
					GameState.gathered_intel.append(val)
			"consequence":
				GameState.social_consequences[val] = true
	GameState.save_game()

## Skill result message with roll detail shown above the outcome.
func _show_skill_result(detail: String, msg: String, col: Color, return_panel: Callable) -> void:
	_clear_info()
	var detail_lbl := RimvaleUtils.label(detail, 11, RimvaleColors.TEXT_GRAY)
	detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(detail_lbl)
	_info_vbox.add_child(RimvaleUtils.spacer(4))
	var msg_lbl := RimvaleUtils.label(msg, 14, col)
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(msg_lbl)
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(self):
		return_panel.call()

# ══════════════════════════════════════════════════════════════════════════════
#  FIELD MEDICINE (Medical skill anywhere on the map)
# ══════════════════════════════════════════════════════════════════════════════

func _do_field_medicine() -> void:
	if _field_med_used:
		_show_message("Already used field medicine on this expedition.", RimvaleColors.TEXT_DIM)
		return
	if _is_day_over():
		_show_message("The day is over. Find a place to rest.", RimvaleColors.DANGER)
		return
	_advance_time(2)
	_field_med_used = true
	var e = RimvaleAPI.engine
	var best: Array = _best_party_skill("Medical")
	var h: int = best[0]
	if h < 0:
		_show_message("No party member can attempt this.", RimvaleColors.DANGER)
		return
	var dc: int = 10 + GameState.player_level
	var result: PackedStringArray = e.execute_skill_challenge(h, "Medical", dc)
	var passed: bool = str(result[0]) == "1"
	var detail: String = str(result[4])
	if passed:
		for hh in GameState.get_active_handles():
			var cd: Dictionary = e.get_char_dict(hh)
			if cd != null:
				var heal: int = int(int(cd.get("max_hp", 20)) * 0.30)
				cd["hp"] = mini(int(cd.get("hp", 1)) + heal, int(cd.get("max_hp", 20)))
		GameState.save_game()
		_show_skill_result(detail, "Field surgery successful! Party healed 30% HP.", RimvaleColors.HP_GREEN, _show_location_info)
	else:
		for hh in GameState.get_active_handles():
			var cd: Dictionary = e.get_char_dict(hh)
			if cd != null:
				var heal: int = int(int(cd.get("max_hp", 20)) * 0.10)
				cd["hp"] = mini(int(cd.get("hp", 1)) + heal, int(cd.get("max_hp", 20)))
		GameState.save_game()
		_show_skill_result(detail, "Rough patch job. Party healed 10% HP.", RimvaleColors.WARNING, _show_location_info)

# ══════════════════════════════════════════════════════════════════════════════
#  HIDDEN CACHE SYSTEM (Perception)
# ══════════════════════════════════════════════════════════════════════════════

func _init_hidden_caches() -> void:
	_hidden_cache_map.clear()
	var caches: Array = _content.get("hidden_caches", [])

	# Auto-generate caches if the map doesn't define any
	if caches.is_empty():
		caches = _generate_default_caches()

	for c in caches:
		# Format: [x, y, type, label, dc, reward_type, reward_val]
		if c.size() < 7: continue
		var pos := Vector2i(int(c[0]), int(c[1]))
		var cache_key: String = _subregion + "::" + str(pos.x) + "," + str(pos.y)
		if cache_key in GameState.discovered_caches:
			continue  # already found — skip
		_hidden_cache_map[pos] = {
			"type": str(c[2]),
			"label": str(c[3]),
			"dc": int(c[4]),
			"reward_type": str(c[5]),
			"reward_val": int(c[6]),
			"key": cache_key
		}

## Generate 4 hidden caches on random walkable tiles.
func _generate_default_caches() -> Array:
	var result: Array = []
	var cache_templates: Array = [
		["stash", "Hidden Gold Stash", "gold", 40 + GameState.player_level * 10],
		["stash", "Concealed Cache", "gold", 30 + GameState.player_level * 8],
		["lore", "Ancient Inscription", "xp", 50 + GameState.player_level * 15],
		["item", "Health Potion", "item", 0],
		["stash", "Buried Treasure", "gold", 60 + GameState.player_level * 12],
		["lore", "Forgotten Lore Fragment", "xp", 70 + GameState.player_level * 10],
		["item", "Potion of Revive", "item", 0],
		["heal", "Healing Spring", "hp", 15 + GameState.player_level * 3],
	]
	# Use a seeded RNG based on subregion name for consistency
	var seed_val: int = hash(_subregion)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var placed: int = 0
	var attempts: int = 0
	while placed < 4 and attempts < 200:
		attempts += 1
		var tx: int = rng.randi_range(2, GRID_W - 3)
		var ty: int = rng.randi_range(2, GRID_H - 3)
		if not _is_walkable(tx, ty): continue
		# Don't place on POIs
		if _poi_map.has(Vector2i(tx, ty)): continue
		# Don't place too close to spawn
		var spawn: Vector2i = _map_data.get("player_spawn", Vector2i(15, 19))
		if abs(tx - spawn.x) + abs(ty - spawn.y) < 5: continue
		# Don't overlap existing caches
		var overlap: bool = false
		for existing in result:
			if int(existing[0]) == tx and int(existing[1]) == ty:
				overlap = true; break
		if overlap: continue

		var template: Array = cache_templates[rng.randi_range(0, cache_templates.size() - 1)]
		var dc: int = 10 + GameState.player_level + rng.randi_range(-2, 3)
		result.append([tx, ty, template[0], template[1], dc, template[2], template[3]])
		placed += 1
	return result

func _check_nearby_caches(pos: Vector2i) -> void:
	# Check the 9 tiles in a 1-tile radius around player
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var check := Vector2i(pos.x + dx, pos.y + dy)
			if not _hidden_cache_map.has(check): continue
			var cache: Dictionary = _hidden_cache_map[check]
			var best: Array = _best_party_skill("Perception")
			if best[0] < 0: continue
			var result: PackedStringArray = RimvaleAPI.engine.execute_skill_challenge(
				best[0], "Perception", int(cache["dc"]))
			var passed: bool = str(result[0]) == "1"
			if passed:
				_reveal_cache(check, cache, str(result[4]))

func _reveal_cache(pos: Vector2i, cache: Dictionary, detail: String) -> void:
	# Mark as discovered
	GameState.discovered_caches.append(cache["key"])
	_hidden_cache_map.erase(pos)
	GameState.save_game()

	# Build 3D sparkle marker
	var marker := _build_cache_marker(pos)
	_cache_markers[pos] = marker

	# Show discovery in info panel
	_clear_info()
	_info_vbox.add_child(RimvaleUtils.label("✨ Hidden Discovery!", 16, RimvaleColors.GOLD))
	var det_lbl := RimvaleUtils.label(detail, 11, RimvaleColors.TEXT_GRAY)
	det_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(det_lbl)
	_info_vbox.add_child(RimvaleUtils.spacer(4))
	_info_vbox.add_child(RimvaleUtils.label(str(cache["label"]), 14, RimvaleColors.GOLD))
	_info_vbox.add_child(RimvaleUtils.spacer(4))

	# Award the reward
	var rtype: String = cache["reward_type"]
	var rval: int = cache["reward_val"]
	var reward_msg: String = ""
	match rtype:
		"gold":
			GameState.earn_gold(rval)
			reward_msg = "+%d Gold found!" % rval
		"xp":
			for h in GameState.get_active_handles():
				RimvaleAPI.engine.add_xp(h, rval, 20)
			GameState.player_xp += rval
			reward_msg = "+%d XP gained!" % rval
		"item":
			var item_name: String = str(cache.get("label", "Health Potion"))
			GameState.add_to_stash(item_name)
			reward_msg = "%s added to stash!" % item_name
		"hp":
			for h in GameState.get_active_handles():
				var cd: Dictionary = RimvaleAPI.engine.get_char_dict(h)
				if cd != null:
					cd["hp"] = mini(int(cd.get("hp", 1)) + rval, int(cd.get("max_hp", 20)))
			reward_msg = "Party healed +%d HP!" % rval
		"sp":
			for h in GameState.get_active_handles():
				RimvaleAPI.engine.restore_character_sp(h, rval)
			reward_msg = "Party restored +%d SP!" % rval
	_info_vbox.add_child(RimvaleUtils.label(reward_msg, 14, RimvaleColors.HP_GREEN))
	GameState.save_game()

func _build_cache_marker(pos: Vector2i) -> Node3D:
	var marker := Node3D.new()
	var world_pos: Vector3 = _tile_to_world(pos.x, pos.y)
	marker.position = world_pos + Vector3(0, 0.6, 0)
	# Glowing diamond shape
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.15, 0.15, 0.15)
	mesh_inst.mesh = box
	mesh_inst.rotation_degrees = Vector3(45, 45, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.20, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.20)
	mat.emission_energy_multiplier = 3.0
	mesh_inst.material_override = mat
	marker.add_child(mesh_inst)
	_world3d_root.add_child(marker)
	return marker

# ══════════════════════════════════════════════════════════════════════════════
#  MULTI-STEP DIALOGUE ENCOUNTERS
# ══════════════════════════════════════════════════════════════════════════════

## Dialogue node format: { "text": String, "speaker": String, "choices": [ { "label": String,
##   "skill": String (optional), "dc": int, "next_pass": int, "next_fail": int,
##   "reward": String, "fail_reward": String }, ... ] }
## A choice with no "skill" is just a narrative branch (auto-pass).

const TAVERN_DIALOGUES: Array = [
	# Node 0 — entry
	{ "speaker": "Mysterious Stranger", "text": "A hooded figure beckons from a shadowed booth. \"You look capable. I have a proposition — interested?\"",
	  "choices": [
		{ "label": "\"I'm listening.\"", "next_pass": 1 },
		{ "label": "\"Not interested.\"", "next_pass": 5 },
	]},
	# Node 1 — the pitch
	{ "speaker": "Mysterious Stranger", "text": "\"There's a cache hidden beneath the old well. Guarded by wards. I need someone to disable them and split the take. 50-50.\"",
	  "choices": [
		{ "label": "[Intuition] Read their intentions", "skill": "Intuition", "dc_offset": 2, "next_pass": 2, "next_fail": 3 },
		{ "label": "[Speechcraft] Negotiate 70-30 in your favor", "skill": "Speechcraft", "dc_offset": 4, "next_pass": 4, "next_fail": 3 },
		{ "label": "\"Deal. Let's go.\"", "next_pass": 3 },
	]},
	# Node 2 — read intentions success
	{ "speaker": "Narrator", "text": "You sense genuine desperation — not deceit. This person needs help and the treasure is real.",
	  "choices": [
		{ "label": "\"Alright, I'll help.\"", "next_pass": 3, "reward": "xp:30" },
		{ "label": "\"I'll help, but I want 70%.\"", "skill": "Speechcraft", "dc_offset": 0, "next_pass": 4, "next_fail": 3 },
	]},
	# Node 3 — standard deal
	{ "speaker": "Mysterious Stranger", "text": "\"Excellent. Here's your half.\" They slide a pouch across the table and vanish into the crowd.",
	  "choices": [
		{ "label": "Take the payment", "next_pass": -1, "reward": "gold:60|xp:40" },
	]},
	# Node 4 — better deal
	{ "speaker": "Mysterious Stranger", "text": "\"Fine, fine. 70-30. You drive a hard bargain.\" A heavier pouch appears.",
	  "choices": [
		{ "label": "Take the payment", "next_pass": -1, "reward": "gold:100|xp:50" },
	]},
	# Node 5 — decline
	{ "speaker": "Mysterious Stranger", "text": "The figure shrugs and melts back into shadow. Perhaps another time.",
	  "choices": [
		{ "label": "Return", "next_pass": -1 },
	]},
]

const ACF_DIALOGUES: Array = [
	# Node 0 — briefing
	{ "speaker": "ACF Commander", "text": "\"Agent, we've intercepted coded messages from an unknown faction. We need you to decode them. This requires a sharp mind.\"",
	  "choices": [
		{ "label": "[Learnedness] Analyze the cipher", "skill": "Learnedness", "dc_offset": 2, "next_pass": 1, "next_fail": 2 },
		{ "label": "[Cunning] Cross-reference with known codes", "skill": "Cunning", "dc_offset": 0, "next_pass": 1, "next_fail": 2 },
		{ "label": "\"I need more context first.\"", "next_pass": 3 },
	]},
	# Node 1 — decoded
	{ "speaker": "ACF Commander", "text": "\"Brilliant work! The messages reveal a smuggling route. We can set up an ambush. Will you lead the strike team?\"",
	  "choices": [
		{ "label": "[Survival] Scout the route first", "skill": "Survival", "dc_offset": 0, "next_pass": 4, "next_fail": 5 },
		{ "label": "\"Send another team. I have other duties.\"", "next_pass": 6, "reward": "xp:60" },
	]},
	# Node 2 — failed decode
	{ "speaker": "ACF Commander", "text": "\"The cipher is beyond your current abilities. We'll assign the cryptanalysis team. Dismissed — but here's partial pay for the attempt.\"",
	  "choices": [
		{ "label": "Accept and leave", "next_pass": -1, "reward": "xp:20|gold:15" },
	]},
	# Node 3 — more context
	{ "speaker": "ACF Commander", "text": "\"The messages were found on a captured courier. They use a rotating substitution cipher with Velhari numerals. That's all we know.\"",
	  "choices": [
		{ "label": "[Arcane] Use arcane analysis", "skill": "Arcane", "dc_offset": 3, "next_pass": 1, "next_fail": 2 },
		{ "label": "\"I'll pass on this one.\"", "next_pass": -1, "reward": "xp:10" },
	]},
	# Node 4 — scouted successfully
	{ "speaker": "Narrator", "text": "Your scouting reveals the perfect ambush point. The operation is a resounding success.",
	  "choices": [
		{ "label": "Collect rewards", "next_pass": -1, "reward": "gold:120|xp:80|intel:Smuggling route through the region uncovered" },
	]},
	# Node 5 — scouting failed
	{ "speaker": "Narrator", "text": "The ambush goes poorly — the smugglers spot your team. They escape, but you recover some contraband.",
	  "choices": [
		{ "label": "Return with what you have", "next_pass": -1, "reward": "gold:30|xp:30" },
	]},
	# Node 6 — delegate
	{ "speaker": "ACF Commander", "text": "\"Understood. Your intelligence work was invaluable regardless. Report dismissed.\"",
	  "choices": [
		{ "label": "Leave", "next_pass": -1, "reward": "xp:60" },
	]},
]

const LIBRARY_DIALOGUES: Array = [
	# Node 0
	{ "speaker": "Elderly Scholar", "text": "\"Ah, a fellow seeker of knowledge! I've been studying a peculiar text — an ancient map fragment. Care to help me piece it together?\"",
	  "choices": [
		{ "label": "[Learnedness] Study the fragment", "skill": "Learnedness", "dc_offset": 0, "next_pass": 1, "next_fail": 2 },
		{ "label": "[Perception] Examine the physical document", "skill": "Perception", "dc_offset": 2, "next_pass": 3, "next_fail": 2 },
		{ "label": "\"I don't have time for this.\"", "next_pass": -1 },
	]},
	# Node 1
	{ "speaker": "Elderly Scholar", "text": "\"Remarkable! You've identified this as a pre-Cataclysm navigation chart. The markings indicate a hidden vault!\"",
	  "choices": [
		{ "label": "\"Where does it lead?\"", "next_pass": 4, "reward": "xp:50|intel:Ancient vault location hinted at by pre-Cataclysm map" },
	]},
	# Node 2
	{ "speaker": "Elderly Scholar", "text": "\"Hmm, the text resists interpretation. Perhaps with more study another day. Here, take this for your trouble.\"",
	  "choices": [
		{ "label": "Accept the gift", "next_pass": -1, "reward": "xp:20" },
	]},
	# Node 3
	{ "speaker": "Narrator", "text": "You notice the parchment has a hidden watermark — alchemical ink only visible at certain angles. It reveals a second layer of text!",
	  "choices": [
		{ "label": "[Arcane] Decode the hidden text", "skill": "Arcane", "dc_offset": 3, "next_pass": 4, "next_fail": 2 },
		{ "label": "Share the discovery with the scholar", "next_pass": 1 },
	]},
	# Node 4
	{ "speaker": "Elderly Scholar", "text": "\"This changes everything! The vault lies beneath the old quarter. Take this — you've earned far more than coin.\"",
	  "choices": [
		{ "label": "Accept", "next_pass": -1, "reward": "gold:50|xp:80|sp:3|intel:Hidden vault confirmed beneath the old quarter" },
	]},
]

## Starts a multi-step dialogue encounter.
func _start_dialogue(dialogue_tree: Array, return_panel: Callable) -> void:
	_show_dialogue_node(dialogue_tree, 0, return_panel)

func _show_dialogue_node(tree: Array, node_idx: int, return_panel: Callable) -> void:
	if node_idx < 0 or node_idx >= tree.size():
		return_panel.call()
		return
	_clear_info()
	var node: Dictionary = tree[node_idx]
	var speaker: String = str(node.get("speaker", "???"))
	var text: String = str(node.get("text", "..."))

	_info_vbox.add_child(RimvaleUtils.label(speaker, 14, RimvaleColors.ACCENT))
	_info_vbox.add_child(RimvaleUtils.spacer(4))
	var text_lbl := RimvaleUtils.label(text, 12, RimvaleColors.TEXT_LIGHT)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(text_lbl)
	_info_vbox.add_child(RimvaleUtils.spacer(8))

	var choices: Array = node.get("choices", [])
	for choice in choices:
		var label_text: String = str(choice.get("label", "Continue"))
		var skill: String = str(choice.get("skill", ""))
		var dc_offset: int = int(choice.get("dc_offset", 0))
		var next_pass: int = int(choice.get("next_pass", -1))
		var next_fail: int = int(choice.get("next_fail", -1))
		var reward: String = str(choice.get("reward", ""))
		var fail_reward: String = str(choice.get("fail_reward", ""))

		var btn_col: Color = RimvaleColors.ACCENT
		if not skill.is_empty():
			var info: Array = _best_party_skill(skill)
			var dc: int = _social_dc() + dc_offset
			label_text += " [+%d vs DC %d]" % [info[1], dc]

		var cap_tree := tree
		var cap_skill := skill
		var cap_dc_off := dc_offset
		var cap_np := next_pass
		var cap_nf := next_fail
		var cap_rw := reward
		var cap_frw := fail_reward
		var cap_rp := return_panel
		var btn := RimvaleUtils.button(label_text, btn_col, 38, 11)
		btn.pressed.connect(func():
			if not _try_action(func(): _show_dialogue_node(cap_tree, node_idx, cap_rp)): return
			if cap_skill.is_empty():
				# No skill check — auto pass
				if not cap_rw.is_empty():
					_apply_social_reward(cap_rw)
				_show_dialogue_node(cap_tree, cap_np, cap_rp)
			else:
				var best: Array = _best_party_skill(cap_skill)
				var h: int = best[0]
				if h < 0:
					_show_message("No party member available.", RimvaleColors.DANGER,
						func(): _show_dialogue_node(cap_tree, node_idx, cap_rp))
					return
				var dc: int = _social_dc() + cap_dc_off
				var result: PackedStringArray = RimvaleAPI.engine.execute_skill_challenge(h, cap_skill, dc)
				var passed: bool = str(result[0]) == "1"
				if passed:
					if not cap_rw.is_empty():
						_apply_social_reward(cap_rw)
					_show_dialogue_node(cap_tree, cap_np, cap_rp)
				else:
					if not cap_frw.is_empty():
						_apply_social_reward(cap_frw)
					if cap_nf >= 0:
						_show_dialogue_node(cap_tree, cap_nf, cap_rp)
					else:
						_show_dialogue_node(cap_tree, cap_np, cap_rp)
		)
		_info_vbox.add_child(btn)

# ══════════════════════════════════════════════════════════════════════════════
#  BARTER & TRADE NEGOTIATION
# ══════════════════════════════════════════════════════════════════════════════

## Barter encounter: player offers gold, NPC counters, skill checks influence outcome.
func _start_barter(poi_panel: Callable) -> void:
	if not _try_action(poi_panel):
		return
	_clear_info()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var item_pool: Array = [
		["Enchanted Amulet", 120, "Grants +1 to all saving throws."],
		["Masterwork Blade", 150, "A finely balanced weapon."],
		["Tome of Insight", 100, "+50 XP on study."],
		["Healer's Kit Deluxe", 80, "Fully restores one character's HP."],
		["Cloak of Shadows", 130, "Advantage on Sneak checks."],
		["Ring of Vitality", 110, "+5 max HP permanently."],
	]
	var pick: Array = item_pool[rng.randi_range(0, item_pool.size() - 1)]
	var item_name: String = str(pick[0])
	var base_price: int = int(pick[1])
	var item_desc: String = str(pick[2])

	_info_vbox.add_child(RimvaleUtils.label("🤝 Traveling Merchant", 15, RimvaleColors.GOLD))
	_info_vbox.add_child(RimvaleUtils.spacer(4))
	var intro := RimvaleUtils.label(
		"\"I have something special today — a %s. %s I'm asking %d gold.\"" % [item_name, item_desc, base_price],
		12, RimvaleColors.TEXT_LIGHT)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(intro)
	_info_vbox.add_child(RimvaleUtils.spacer(6))
	_info_vbox.add_child(RimvaleUtils.label("Gold: %d" % GameState.gold, 12, RimvaleColors.GOLD))
	_info_vbox.add_child(RimvaleUtils.spacer(4))

	# Haggle button
	var cap_item := item_name
	var cap_base := base_price
	var cap_panel := poi_panel
	var haggle_btn := RimvaleUtils.button(
		"[Speechcraft] Haggle for a lower price %s" % _time_cost_str(), RimvaleColors.ACCENT, 38, 11)
	haggle_btn.pressed.connect(func():
		if not _try_action(cap_panel): return
		var best: Array = _best_party_skill("Speechcraft")
		var h: int = best[0]
		if h < 0:
			_show_message("No party member available.", RimvaleColors.DANGER, cap_panel)
			return
		var result: PackedStringArray = RimvaleAPI.engine.execute_skill_challenge(h, "Speechcraft", _social_dc() + 2)
		var passed: bool = str(result[0]) == "1"
		var discount: int = cap_base / 3 if passed else 0
		var final_price: int = cap_base - discount
		_clear_info()
		if passed:
			_info_vbox.add_child(RimvaleUtils.label("\"Fine, %d gold. Final offer.\"" % final_price, 12, RimvaleColors.HP_GREEN))
		else:
			_info_vbox.add_child(RimvaleUtils.label("\"My price is firm. %d gold.\"" % final_price, 12, RimvaleColors.WARNING))
		_info_vbox.add_child(RimvaleUtils.spacer(4))
		var buy_btn := RimvaleUtils.button("Buy for %d gold" % final_price, RimvaleColors.GOLD, 38, 12)
		var cap_fp := final_price; var cap_it := cap_item
		buy_btn.pressed.connect(func():
			if GameState.gold >= cap_fp:
				GameState.gold -= cap_fp
				GameState.add_to_stash(cap_it)
				GameState.save_game()
				_show_message("Acquired: %s!" % cap_it, RimvaleColors.GOLD, cap_panel)
			else:
				_show_message("Not enough gold!", RimvaleColors.DANGER, cap_panel)
		)
		_info_vbox.add_child(buy_btn)
		var decline := RimvaleUtils.button("Decline", RimvaleColors.TEXT_DIM, 38, 11)
		decline.pressed.connect(func(): cap_panel.call())
		_info_vbox.add_child(decline)
	)
	_info_vbox.add_child(haggle_btn)

	# Buy at full price
	var buy_full := RimvaleUtils.button("Buy for %d gold" % base_price, RimvaleColors.GOLD, 38, 11)
	buy_full.pressed.connect(func():
		if GameState.gold >= cap_base:
			GameState.gold -= cap_base
			GameState.add_to_stash(cap_item)
			GameState.save_game()
			_show_message("Acquired: %s!" % cap_item, RimvaleColors.GOLD, cap_panel)
		else:
			_show_message("Not enough gold!", RimvaleColors.DANGER, cap_panel)
	)
	_info_vbox.add_child(buy_full)

	var decline_btn := RimvaleUtils.button("\"No thanks.\"", RimvaleColors.TEXT_DIM, 38, 11)
	decline_btn.pressed.connect(func(): cap_panel.call())
	_info_vbox.add_child(decline_btn)

# ══════════════════════════════════════════════════════════════════════════════
#  INTEL GATHERING
# ══════════════════════════════════════════════════════════════════════════════

## Regional intel pool — seeded by subregion for variety.
func _get_region_intel() -> Array:
	var rk: String = WorldData.subregion_to_key(_subregion)
	var faction_info: Dictionary = WorldData.get_faction_for_region(rk)
	var fname: String = str(faction_info.get("name", "unknown faction"))
	return [
		"The %s have been stockpiling weapons at a hidden depot." % fname,
		"A secret passage connects the old quarter to the underground tunnels.",
		"There's a bounty on a rogue mage operating in this region.",
		"%s agents have been spotted meeting with outsiders at midnight." % fname,
		"The local well water has unusual properties — alchemists pay well for it.",
		"An ancient ward stone beneath the central plaza keeps this area safe from incursions.",
		"Smugglers use the abandoned warehouses for contraband exchanges.",
		"A powerful artifact was supposedly lost in the ruins to the east.",
		"The garrison is running low on supplies and may need help soon.",
		"An underground fighting ring operates beneath the tavern district.",
	]

## Show intel panel with gathered intelligence.
func _show_intel_panel(return_panel: Callable) -> void:
	_clear_info()
	_info_vbox.add_child(RimvaleUtils.label("🔍 Intelligence Report", 15, RimvaleColors.CYAN))
	_info_vbox.add_child(RimvaleUtils.spacer(4))
	if GameState.gathered_intel.is_empty():
		_info_vbox.add_child(RimvaleUtils.label("No intelligence gathered yet. Use social skills at POIs to uncover secrets.", 11, RimvaleColors.TEXT_DIM))
	else:
		for entry in GameState.gathered_intel:
			var card := RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.DIVIDER, 4, 6)
			var lbl := RimvaleUtils.label("• " + str(entry), 11, RimvaleColors.TEXT_LIGHT)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.add_child(lbl)
			_info_vbox.add_child(card)
	_info_vbox.add_child(RimvaleUtils.spacer(8))
	var back := RimvaleUtils.button("Back", RimvaleColors.TEXT_DIM, 38, 11)
	back.pressed.connect(func(): return_panel.call())
	_info_vbox.add_child(back)

# ══════════════════════════════════════════════════════════════════════════════
#  SKILL COMBOS & SOCIAL CONSEQUENCES
# ══════════════════════════════════════════════════════════════════════════════

## Check if using this skill creates a combo with previously used skills.
## Returns a bonus modifier (0 if no combo).
func _check_skill_combo(skill_name: String) -> int:
	var combo_bonus: int = 0
	# Define synergistic skill pairs
	var combos: Dictionary = {
		"Speechcraft": ["Intuition", "Perform"],
		"Intuition": ["Perception", "Speechcraft"],
		"Cunning": ["Sneak", "Nimble"],
		"Perception": ["Survival", "Intuition"],
		"Medical": ["Learnedness", "Survival"],
		"Arcane": ["Learnedness", "Intuition"],
		"Survival": ["Perception", "Creature Handling"],
		"Perform": ["Speechcraft", "Cunning"],
		"Crafting": ["Arcane", "Learnedness"],
		"Sneak": ["Cunning", "Nimble"],
	}
	var synergies: Array = combos.get(skill_name, [])
	for used_skill in _skills_used_this_poi:
		if synergies.has(used_skill):
			combo_bonus += 2
	_skills_used_this_poi.append(skill_name)
	return combo_bonus

## Check for active social consequences that affect interactions.
func _get_consequence_penalty() -> int:
	var penalty: int = 0
	if GameState.social_consequences.has("caught_stealing"):
		penalty += 2  # Merchants are wary
	if GameState.social_consequences.has("bar_fight"):
		penalty += 1  # Reputation precedes you
	if GameState.social_consequences.has("failed_forgery"):
		penalty += 3  # Officials are on alert
	return penalty

# ══════════════════════════════════════════════════════════════════════════════
#  GROUP SKILL CHECKS
# ══════════════════════════════════════════════════════════════════════════════

## Run a group skill check where multiple party members contribute.
## Each member rolls; if majority pass, the group passes.
## Returns [passed: bool, detail: String].
func _group_skill_check(skill_name: String, dc: int) -> Array:
	var handles: Array = GameState.get_active_handles()
	var pass_count: int = 0
	var total: int = 0
	var details: PackedStringArray = []
	for h in handles:
		var cd: Dictionary = RimvaleAPI.engine.get_char_dict(h)
		if cd == null:
			continue
		total += 1
		var result: PackedStringArray = RimvaleAPI.engine.execute_skill_challenge(h, skill_name, dc)
		var passed: bool = str(result[0]) == "1"
		var name_: String = RimvaleAPI.engine.get_character_name(h)
		if passed:
			pass_count += 1
			details.append("%s: passed" % name_)
		else:
			details.append("%s: failed" % name_)
	var group_pass: bool = pass_count >= ceili(total / 2.0)
	var summary: String = "Group check [%s vs DC %d]: %d/%d passed. %s!" % [
		skill_name, dc, pass_count, total,
		"SUCCESS" if group_pass else "FAILURE"]
	return [group_pass, summary + "\n" + "\n".join(details)]

## Show a group skill check encounter (high-value POI event).
func _show_group_check_encounter(return_panel: Callable) -> void:
	if not _try_action(return_panel, 2):
		return
	_clear_info()
	var encounters: Array = [
		{ "title": "Collapsing Structure", "desc": "The building groans ominously. Your entire team must work together to shore up the supports!",
		  "skill": "Exertion", "dc_offset": 2, "pass_reward": "xp:80|gold:40",
		  "pass_msg": "Working together, the team stabilizes the structure and discovers valuables in the rubble!",
		  "fail_msg": "The structure partially collapses. Minor injuries all around, but everyone survives." },
		{ "title": "Arcane Barrier", "desc": "A shimmering ward blocks the passage. It requires the combined magical focus of your entire team to dispel.",
		  "skill": "Arcane", "dc_offset": 3, "pass_reward": "sp:4|xp:60|intel:Arcane barrier patterns recorded for future reference",
		  "pass_msg": "The ward shatters! Behind it lies a cache of magical energy and forgotten knowledge.",
		  "fail_msg": "The ward holds firm. The arcane backlash drains some of the party's reserves." },
		{ "title": "Ambush!", "desc": "Hostile figures emerge from the shadows! Your team must react together or be overwhelmed!",
		  "skill": "Perception", "dc_offset": 1, "pass_reward": "xp:60|gold:50",
		  "pass_msg": "Your team spots the ambush in time! The would-be attackers scatter and drop their loot.",
		  "fail_msg": "Caught off guard! The attackers steal some gold before fleeing." },
		{ "title": "Plague Victim", "desc": "A gravely ill person collapses in the street. Your entire team must coordinate to provide emergency care.",
		  "skill": "Medical", "dc_offset": 0, "pass_reward": "xp:50|heal:half",
		  "pass_msg": "Your combined medical expertise saves the victim. The grateful family rewards you. Your own team feels invigorated.",
		  "fail_msg": "Despite your best efforts, the situation is beyond field medicine. Local healers take over." },
	]
	var pick: Dictionary = encounters[randi() % encounters.size()]

	_info_vbox.add_child(RimvaleUtils.label("⚡ %s" % str(pick["title"]), 15, RimvaleColors.WARNING))
	_info_vbox.add_child(RimvaleUtils.spacer(4))
	var desc := RimvaleUtils.label(str(pick["desc"]), 12, RimvaleColors.TEXT_LIGHT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(desc)
	_info_vbox.add_child(RimvaleUtils.spacer(4))
	_info_vbox.add_child(RimvaleUtils.label("This is a GROUP CHECK — all party members contribute!", 11, RimvaleColors.CYAN))
	_info_vbox.add_child(RimvaleUtils.spacer(6))

	var cap_pick := pick
	var cap_rp := return_panel
	var skill_name: String = str(pick["skill"])
	var dc: int = _social_dc() + int(pick.get("dc_offset", 0))
	var attempt_btn := RimvaleUtils.button(
		"[%s — Group Check vs DC %d] %s" % [skill_name, dc, _time_cost_str(2)], RimvaleColors.ACCENT, 38, 12)
	attempt_btn.pressed.connect(func():
		var check_result: Array = _group_skill_check(str(cap_pick["skill"]),
			_social_dc() + int(cap_pick.get("dc_offset", 0)))
		var passed: bool = check_result[0]
		var detail: String = str(check_result[1])
		_clear_info()
		var detail_lbl := RimvaleUtils.label(detail, 11, RimvaleColors.TEXT_GRAY)
		detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info_vbox.add_child(detail_lbl)
		_info_vbox.add_child(RimvaleUtils.spacer(4))
		if passed:
			_apply_social_reward(str(cap_pick.get("pass_reward", "")))
			var msg := RimvaleUtils.label(str(cap_pick["pass_msg"]), 13, RimvaleColors.HP_GREEN)
			msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_info_vbox.add_child(msg)
		else:
			var msg := RimvaleUtils.label(str(cap_pick["fail_msg"]), 13, RimvaleColors.WARNING)
			msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_info_vbox.add_child(msg)
		_info_vbox.add_child(RimvaleUtils.spacer(6))
		var back := RimvaleUtils.button("Continue", RimvaleColors.TEXT_DIM, 38, 11)
		back.pressed.connect(func(): cap_rp.call())
		_info_vbox.add_child(back)
	)
	_info_vbox.add_child(attempt_btn)

	var flee_btn := RimvaleUtils.button("Avoid the situation", RimvaleColors.TEXT_DIM, 38, 11)
	flee_btn.pressed.connect(func(): cap_rp.call())
	_info_vbox.add_child(flee_btn)

# ══════════════════════════════════════════════════════════════════════════════
#  NPC RELATIONSHIP EVENTS
# ══════════════════════════════════════════════════════════════════════════════

## NPC personality modifiers for interaction DCs.
func _npc_personality_dc_mod(npc: Dictionary) -> int:
	var personality: String = str(npc.get("personality", "")).to_lower()
	if "friendly" in personality or "kind" in personality or "warm" in personality:
		return -2
	elif "suspicious" in personality or "gruff" in personality or "stern" in personality:
		return 2
	elif "cunning" in personality or "shrewd" in personality:
		return 1
	return 0

## Get relationship event text based on trust level.
func _get_relationship_event(npc: Dictionary, trust: int) -> String:
	var name_: String = str(npc.get("name", ""))
	match trust:
		1: return "%s nods in recognition as you approach. \"Good to see you again.\"" % name_
		2: return "%s greets you warmly. \"I've been meaning to tell you something...\"" % name_
		_: return ""

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
