## battle_rts.gd
## Real-time RTS battle scene (Command & Conquer style) for Battle Mode.
##
## The rules engine is the BattleSystem autoload, which runs the 10 Hz sim
## by itself — this scene ONLY renders the battlefield and sends commands
## (production, orders, squads, upgrades, spells). All world geometry is
## built once in _ready; entity nodes persist and are updated per frame.
##
## Controls:
##   LMB          select unit / structure, drag = box select (Shift = add)
##   RMB          move / attack / mine (units) — set rally (structure)
##   A + LMB      attack-move (Escape cancels)
##   Ctrl+1..4    assign squad          1..4  select squad (2x = center)
##   WASD/arrows  pan   ·  wheel zoom   ·  edge-of-screen pan
##   Space pause  ·  F speed 1×/2×/3×  ·  Home jump to base  ·  Escape clear

extends Node3D

const TITLE_SCENE := "res://scenes/title/title_screen.tscn"
const CONQUEST_MAP_SCENE := "res://scenes/battle/conquest_map.tscn"

const EDGE_MARGIN := 12        # px — edge-of-screen pan band
const DRAG_THRESHOLD := 8.0    # px before a click becomes a box drag
const ZOOM_MIN := 8.0
const ZOOM_MAX := 160.0   # far enough to see a whole 300×300 battlefield
const SQUAD_DOUBLE_MS := 400   # double-tap window for squad-centering

## Region id → pleasant terrain palette {floor, wall, bush}.
const REGION_PALETTES := {
	"plains":    {"floor": Color(0.31, 0.52, 0.24), "wall": Color(0.47, 0.43, 0.36), "bush": Color(0.15, 0.34, 0.13)},
	"peaks":     {"floor": Color(0.82, 0.86, 0.92), "wall": Color(0.55, 0.60, 0.70), "bush": Color(0.36, 0.48, 0.52)},
	"shadows":   {"floor": Color(0.16, 0.22, 0.16), "wall": Color(0.22, 0.26, 0.22), "bush": Color(0.08, 0.16, 0.10)},
	"glass":     {"floor": Color(0.70, 0.76, 0.78), "wall": Color(0.50, 0.60, 0.65), "bush": Color(0.34, 0.55, 0.55)},
	"isles":     {"floor": Color(0.24, 0.46, 0.34), "wall": Color(0.40, 0.44, 0.40), "bush": Color(0.10, 0.30, 0.18)},
	"metro":     {"floor": Color(0.42, 0.42, 0.45), "wall": Color(0.30, 0.30, 0.34), "bush": Color(0.20, 0.32, 0.20)},
	"astral":    {"floor": Color(0.30, 0.24, 0.44), "wall": Color(0.42, 0.35, 0.56), "bush": Color(0.22, 0.16, 0.36)},
	"terminus":  {"floor": Color(0.28, 0.20, 0.26), "wall": Color(0.36, 0.27, 0.32), "bush": Color(0.18, 0.10, 0.16)},
	"titans":    {"floor": Color(0.45, 0.32, 0.22), "wall": Color(0.40, 0.28, 0.20), "bush": Color(0.30, 0.18, 0.10)},
	"sublimini": {"floor": Color(0.18, 0.12, 0.26), "wall": Color(0.27, 0.18, 0.35), "bush": Color(0.10, 0.06, 0.18)},
}

## Human-friendly names for TEAM_COLORS slots (victory banner).
const TEAM_COLOR_NAMES := [
	"Blue", "Red", "Green", "Yellow", "Orange",
	"Purple", "Cyan", "Pink", "Lime", "White",
]

## Structure build buttons on the base: [kind, icon, fallback cost].
const BUILD_KINDS := [
	["barracks",    "🏗", 100],
	["war_factory", "🏭", 150],
	["spire",       "🔮", 120],
	["turret",      "🗼", 80],
]

# ── State ────────────────────────────────────────────────────────────────────
var _e = null                      # RimvaleAPI.engine (guarded)
var _ms: int = 50                  # map size cached at _ready

# Entity rendering
var _nodes: Dictionary = {}        # id -> Node3D (root of the entity visual)
var _parts: Dictionary = {}        # id -> {ring, hp_bg, hp_fg, fg_mat, pip, kind, hp_y, last_hp, dimmed, ...}
var _dying: Dictionary = {}        # id -> remaining fade time (0..1 s)
var _dead_done: Dictionary = {}    # ids whose death fade already completed
var _ignored_ids: Dictionary = {}  # ids we never render (chests) — skip cheaply
var _ringed: Dictionary = {}       # ids whose selection ring is currently shown

# Shared render resources — one mesh / material reused by every entity
# (per-entity variation is done via node.scale / material_override).
const HP_BG_SIZE := Vector2(0.9, 0.11)
const HP_FG_SIZE := Vector2(0.84, 0.07)
var _shared_bar_quad: QuadMesh = null       # unit quad; bars scale the node
var _shared_disc_mesh: CylinderMesh = null  # unit-radius disc; scaled per node
var _shared_ring_unit: TorusMesh = null
var _shared_ring_struct: TorusMesh = null
var _team_disc_mats: Dictionary = {}        # team (int) -> StandardMaterial3D
var _ring_mat_gold: StandardMaterial3D = null
var _ring_mat_cyan: StandardMaterial3D = null
var _hp_bg_mat: StandardMaterial3D = null   # single shared bg material
var _hp_fg_template: StandardMaterial3D = null  # duplicated per entity (color anims)

# Effect pools — flashes/bursts reuse a capped set of nodes; extra events
# beyond the cap simply drop the visual (the log line still shows).
const MAX_EFFECT_LIGHTS := 6
const MAX_EFFECT_MARKERS := 6
var _effect_lights: Array = []     # [{light, t, dur, peak}]
var _effect_markers: Array = []    # [{lbl, t, dur}]

# Camera
var _cam: Camera3D
var _cam_focus := Vector3(25.0, 0.0, 25.0)
var _zoom := 22.0

# Selection / input
var _selection: Array = []         # selected own unit ids (order = primary first)
var _sel_structure: String = ""    # selected own structure id ("" = none)
var _pending_attack_move := false
var _pending_strike := false       # superweapon targeting mode
var _pending_patrol := false       # stance: next click sets the far leg
var _pending_wall := false         # wall placement (stays armed for chains)
var _pending_build_kind := ""      # structure placement mode ("barracks", etc.)
var _pending_debug_build := ""     # debug free-placement mode (same click flow)
var _press_pos := Vector2.ZERO
var _press_active := false
var _dragging := false
var _last_squad_key := 0
var _last_squad_ms := 0

# HUD
var _hud: CanvasLayer
var _drag_rect: Panel
var _top_labels: Dictionary = {}   # key -> Label (cached top-bar fields)
var _top_cache: Dictionary = {}    # key -> last string (skip redundant sets)
var _card: PanelContainer
var _card_box: HBoxContainer
var _chip_labels: Array = []
var _chip_ids: Array = []
var _detail_rt: RichTextLabel = null
var _queue_box: VBoxContainer = null
var _prod_grid: GridContainer = null
var _prod_count := -1
var _card_sig := -1               # chip fingerprint (ids + hp) — skip idle refresh
var _queue_sig := ""              # queue composition fingerprint — rebuild rows only on change
var _queue_pbs: Array = []        # live ProgressBars for in-place queue updates
var _spell_popup: PanelContainer = null
var _spell_checks: Array = []
var _spell_builder: PanelContainer = null
var _sb_name: LineEdit = null
var _sb_kind: String = "damage"
var _sb_dc: int = 1
var _sb_ds: int = 6
var _sb_area: int = 2
var _sb_cost_lbl: Label = null
var _sb_cond_box: VBoxContainer = null
var _sb_cond_checks: Array = []
var _minimap: TextureRect
var _minimap_tex: ImageTexture = null
var _minimap_img: Image = null     # reused buffer — no per-rebuild allocation
var _mm_drag := false
var _log_box: VBoxContainer
var _log_items: Array = []         # [{lbl, t}]
var _toast_lbl: Label
var _toast_t := 0.0
var _leave_dialog: ConfirmationDialog
var _pause_btn: Button = null       # top-bar ⏸/▶ toggle
var _pause_overlay: Control = null  # centered PAUSED banner
var _strike_btn: Button = null      # top-bar superweapon button
var _strike_txt := ""               # change-gate for its label

# Projectile visuals (pooled; see _fire_projectile)
var _projectiles: Array = []        # [{n, from, to, t, dur, arc}]
var _proj_mats: Dictionary = {}     # color+kind → shared material
var _shared_proj_mesh: BoxMesh = null

# Fog of war (player-team vision; see _update_fog)
var _fog_on := true                 # snapshot of BattleSystem.fog_enabled
var _vision: PackedByteArray = []   # 1 = currently in player sight
var _explored: PackedByteArray = [] # 1 = seen at least once (terrain memory)
var _fog_img: Image = null
var _fog_tex: ImageTexture = null
var _fog_plane: MeshInstance3D = null
var _fog_revealed := false          # battle over → whole map shown once

# Attack alerts (throttled; B jumps to the last one)
var _last_alert_pos := Vector3.INF
var _alert_base_cd := 0.0           # seconds until next base alert allowed
var _alert_unit_cd := 0.0           # seconds until next unit alert allowed

# ── Battle audio (drives the AudioManager autoload from sim events) ───────────
var _audio_muted := false           # local battle mute (🔊/🔇 toggle)
var _mute_btn: Button = null        # top-bar mute toggle
# Throttles so a busy field doesn't machine-gun the shared SFX pool.
var _sfx_atk_cd := 0.0              # gate on melee/ranged hit sounds
var _sfx_spell_cd := 0.0           # gate on spell-cast sounds
var _sfx_death_cd := 0.0           # gate on death thuds

# ── Debug panel (built only when GameState.debug_mode is on) ─────────────────
var _debug_panel: PanelContainer = null
var _alert_ping_t := 0.0            # minimap ping time remaining
var _alert_ping_tile := Vector2i(-1, -1)
var _over_shown := false
var _bb_re := RegEx.new()

# 3D markers
var _rally_lbl: Label3D


# ═════════════════════════════════════════════════════════════════════════
# Setup
# ═════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Guard: no battle running → bounce back to the title screen.
	if not BattleSystem.active:
		get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)
		return
	_e = RimvaleAPI.engine
	if _e == null or not ("_dungeon_entities" in _e):
		push_warning("BattleRTS: engine internals unavailable.")
		get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)
		return
	_ms = int(_e.MAP_SIZE)
	_bb_re.compile("\\[[^\\]]*\\]")

	_ensure_shared_resources()
	_build_environment()
	_build_world()
	_build_rift_markers()
	_build_fog()
	_build_camera()
	_build_markers()
	_build_hud()

	# Refresh timers: top bar / command card at 4 Hz, minimap at 2 Hz.
	var hud_timer := Timer.new()
	hud_timer.wait_time = 0.25
	hud_timer.autostart = true
	add_child(hud_timer)
	hud_timer.timeout.connect(_on_hud_tick)
	var mm_timer := Timer.new()
	mm_timer.wait_time = 1.0
	mm_timer.autostart = true
	add_child(mm_timer)
	mm_timer.timeout.connect(_update_minimap)
	if _fog_on:
		var fog_timer := Timer.new()
		fog_timer.wait_time = 1.0
		fog_timer.autostart = true
		add_child(fog_timer)
		fog_timer.timeout.connect(_update_fog)
		_update_fog()   # seed vision around the starting base immediately

	if BattleSystem.has_signal("sim_event"):
		BattleSystem.sim_event.connect(_on_sim_event)

	# Looping battle theme (guarded internally against missing assets).
	AudioManager.play_music("music_combat")

	_center_on_base()
	_update_camera_transform()
	_update_minimap()


## Sky + sun: battles are fought under open daylight.
func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.52, 0.86)
	sky_mat.sky_horizon_color = Color(0.72, 0.80, 0.88)
	sky_mat.ground_bottom_color = Color(0.22, 0.26, 0.24)
	sky_mat.ground_horizon_color = Color(0.60, 0.66, 0.62)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)


## Static battlefield: one floor plane + MultiMesh walls / rocks / bushes.
## Never rebuilt after _ready.
func _build_world() -> void:
	var pal: Dictionary = REGION_PALETTES.get(str(BattleSystem.region_id), REGION_PALETTES["plains"])
	var floor_col: Color = pal["floor"]
	var wall_col: Color = pal["wall"]
	var bush_col: Color = pal["bush"]

	# Floor: one big plane spanning the whole map.
	var plane := PlaneMesh.new()
	plane.size = Vector2(float(_ms) + 2.0, float(_ms) + 2.0)
	plane.material = _mat(floor_col, 1.0)
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = plane
	floor_mi.position = Vector3(float(_ms) * 0.5 - 0.5, 0.0, float(_ms) * 0.5 - 0.5)
	add_child(floor_mi)

	# Scan the map once and bucket wall / obstacle tiles.
	var wall_xf: Array = []
	var rock_xf: Array = []
	var bush_xf: Array = []
	for y in range(_ms):
		for x in range(_ms):
			var v: int = int(_e._dungeon_map[y * _ms + x])
			var h: int = (x * 73856093) ^ (y * 19349663)
			var ang: float = float(h % 628) / 100.0
			var rot := Basis(Vector3.UP, ang)
			if v == 2:
				# Border cliffs: full-tile low rock runs (no rotation → clean runs).
				wall_xf.append(Transform3D(Basis(), Vector3(float(x), 0.55, float(y))))
			elif v == 3:
				# Scattered props: alternate rock / bush per tile hash.
				if h % 2 == 0:
					rock_xf.append(Transform3D(rot, Vector3(float(x), 0.34, float(y))))
				else:
					bush_xf.append(Transform3D(rot, Vector3(float(x), 0.30, float(y))))

	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(1.0, 1.1, 1.0)
	wall_mesh.material = _mat(wall_col, 0.95)
	_add_multimesh(wall_mesh, wall_xf)

	var rock_mesh := BoxMesh.new()
	rock_mesh.size = Vector3(0.72, 0.68, 0.72)
	rock_mesh.material = _mat(wall_col.darkened(0.2), 0.95)
	_add_multimesh(rock_mesh, rock_xf)

	var bush_mesh := SphereMesh.new()
	bush_mesh.radius = 0.48
	bush_mesh.height = 0.72
	bush_mesh.material = _mat(bush_col, 1.0)
	_add_multimesh(bush_mesh, bush_xf)


func _add_multimesh(mesh: Mesh, transforms: Array) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


func _build_camera() -> void:
	_cam = Camera3D.new()
	_cam.fov = 55.0
	add_child(_cam)
	_cam.current = true


func _build_markers() -> void:
	_rally_lbl = Label3D.new()
	_rally_lbl.text = "⚑"
	_rally_lbl.font_size = 96
	_rally_lbl.outline_size = 12
	_rally_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_rally_lbl.pixel_size = 0.01
	_rally_lbl.visible = false
	add_child(_rally_lbl)


## Build the meshes / materials shared by every entity visual (one QuadMesh
## for all health bars, one CylinderMesh for all discs, one TorusMesh per
## ring size, cached team-disc + ring + bar materials). Idempotent.
func _ensure_shared_resources() -> void:
	if _shared_bar_quad != null:
		return
	_shared_bar_quad = QuadMesh.new()
	_shared_bar_quad.size = Vector2(1.0, 1.0)   # bars size via node.scale
	_shared_disc_mesh = CylinderMesh.new()
	_shared_disc_mesh.top_radius = 1.0          # discs size via node.scale
	_shared_disc_mesh.bottom_radius = 1.0
	_shared_disc_mesh.height = 0.05
	_shared_ring_unit = TorusMesh.new()
	_shared_ring_unit.inner_radius = 0.42
	_shared_ring_unit.outer_radius = 0.54
	_shared_ring_struct = TorusMesh.new()
	_shared_ring_struct.inner_radius = 0.8
	_shared_ring_struct.outer_radius = 0.95
	_ring_mat_gold = _mat(RimvaleColors.GOLD, 0.4, RimvaleColors.GOLD, 1.4, true)
	_ring_mat_cyan = _mat(RimvaleColors.CYAN, 0.4, RimvaleColors.CYAN, 1.4, true)
	_hp_bg_mat = _bar_mat(Color(0.05, 0.05, 0.07, 0.9), 1)
	_hp_fg_template = _bar_mat(RimvaleColors.HP_GREEN, 2)


## Unshaded billboard bar material (bg shared; fg duplicated per entity
## because its albedo animates green→red with the HP fraction).
func _bar_mat(col: Color, priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.render_priority = priority
	return m


## Cached team-disc material (one per team, not one per unit).
func _disc_mat(team: int, col: Color) -> StandardMaterial3D:
	var key := maxi(team, 0)
	if _team_disc_mats.has(key):
		return _team_disc_mats[key]
	var m := _mat(col, 0.6, col, 0.6)
	_team_disc_mats[key] = m
	return m


## Recursively disable shadow casting (unit sprites, bars, pips, discs …).
func _set_no_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_set_no_shadows(c)


## Shared StandardMaterial3D factory.
func _mat(col: Color, roughness := 0.8, emit := Color.BLACK, emit_energy := 0.0, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = roughness
	if emit_energy > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = emit_energy
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


# ═════════════════════════════════════════════════════════════════════════
# Per-frame update
# ═════════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if _e == null:
		return
	_handle_camera(delta)
	_sync_entities(delta)
	_update_dying(delta)
	_update_effects(delta)
	_update_projectiles(delta)
	_alert_base_cd = maxf(0.0, _alert_base_cd - delta)
	_alert_unit_cd = maxf(0.0, _alert_unit_cd - delta)
	_alert_ping_t = maxf(0.0, _alert_ping_t - delta)
	_sfx_atk_cd = maxf(0.0, _sfx_atk_cd - delta)
	_sfx_spell_cd = maxf(0.0, _sfx_spell_cd - delta)
	_sfx_death_cd = maxf(0.0, _sfx_death_cd - delta)
	_prune_selection()
	_update_rally_marker()
	_drain_battle_log()
	_update_log_fade(delta)
	_update_toast(delta)


## WASD / arrows / edge-of-screen pan + camera transform.
func _handle_camera(delta: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.y += 1.0
	# A doubles as attack-move; it only pans while nothing is selected.
	if (Input.is_physical_key_pressed(KEY_A) and _selection.is_empty()) \
			or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0

	# Edge pan — only when the window is focused AND the mouse is inside it.
	if get_window().has_focus():
		var vp := get_viewport().get_visible_rect()
		var mp := get_viewport().get_mouse_position()
		if vp.has_point(mp):
			if mp.x <= float(EDGE_MARGIN):
				pan.x -= 1.0
			elif mp.x >= vp.size.x - float(EDGE_MARGIN):
				pan.x += 1.0
			if mp.y <= float(EDGE_MARGIN):
				pan.y -= 1.0
			elif mp.y >= vp.size.y - float(EDGE_MARGIN):
				pan.y += 1.0

	if pan != Vector2.ZERO:
		var speed := 14.0 * (_zoom / 18.0)
		var dir3 := Vector3(pan.x, 0.0, pan.y).normalized()
		_cam_focus += dir3 * speed * delta
		_clamp_focus()
	_update_camera_transform()


func _clamp_focus() -> void:
	_cam_focus.x = clampf(_cam_focus.x, 0.0, float(_ms - 1))
	_cam_focus.z = clampf(_cam_focus.z, 0.0, float(_ms - 1))
	_cam_focus.y = 0.0


## Classic RTS rig: pitched ~55° down, fixed yaw, zoom = distance to focus.
func _update_camera_transform() -> void:
	if _cam == null:
		return
	var pitch := deg_to_rad(55.0)
	var offset := Vector3(0.0, sin(pitch), cos(pitch)) * _zoom
	_cam.position = _cam_focus + offset
	_cam.look_at(_cam_focus, Vector3.UP)


## Rift regions get two glowing 🌀 gates on the field (visual only — the
## teleport itself lives in the sim).
func _build_rift_markers() -> void:
	if str(BattleSystem.region_effect) != "rift" or BattleSystem.rift_a.x < 0:
		return
	for rp_v in [BattleSystem.rift_a, BattleSystem.rift_b]:
		var rp: Vector2i = rp_v
		var lbl := Label3D.new()
		lbl.text = "🌀"
		lbl.font_size = 96
		lbl.pixel_size = 0.008
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lbl.position = Vector3(float(rp.x), 1.1, float(rp.y))
		add_child(lbl)
		var l := OmniLight3D.new()
		l.light_color = Color(0.7, 0.35, 1.0)
		l.omni_range = 4.0
		l.light_energy = 1.3
		l.shadow_enabled = false
		l.position = Vector3(float(rp.x), 1.0, float(rp.y))
		add_child(l)


# ── Fog of war ────────────────────────────────────────────────────────────
## Classic RTS shroud: unexplored = black, explored-but-unseen = dimmed
## terrain with enemy UNITS hidden, in-sight = clear. Structures and
## resource nodes are remembered once seen. Rendering-only — the sim is
## unchanged (and hidden enemies can't be clicked because their nodes are
## invisible and skipped by picking).
func _build_fog() -> void:
	_fog_on = bool(BattleSystem.fog_enabled)
	if not _fog_on:
		return
	_vision.resize(_ms * _ms)
	_explored.resize(_ms * _ms)
	_vision.fill(0)
	_explored.fill(0)
	_fog_img = Image.create_empty(_ms, _ms, false, Image.FORMAT_RGBA8)
	_fog_img.fill(Color(0.02, 0.02, 0.04, 1.0))
	_fog_tex = ImageTexture.create_from_image(_fog_img)
	var plane := PlaneMesh.new()
	plane.size = Vector2(float(_ms), float(_ms))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _fog_tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	plane.material = m
	_fog_plane = MeshInstance3D.new()
	_fog_plane.mesh = plane
	_fog_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fog_plane.position = Vector3(float(_ms) * 0.5 - 0.5, 0.06, float(_ms) * 0.5 - 0.5)
	add_child(_fog_plane)

## Recompute player vision at 2.5 Hz and repaint the shroud texture.
func _update_fog() -> void:
	if not _fog_on or _fog_img == null:
		return
	# Battle decided (or free play) → the whole map reveals, once.
	if (BattleSystem.finished or BattleSystem.sandbox) and not _fog_revealed:
		_fog_revealed = true
		_vision.fill(1)
		_explored.fill(1)
		_fog_img.fill(Color(0, 0, 0, 0))
		_fog_tex.update(_fog_img)
		return
	if _fog_revealed:
		return
	_vision.fill(0)
	var pt: int = BattleSystem.player_team
	for ent_v in _e._dungeon_entities:
		var ent: Dictionary = ent_v
		if bool(ent.get("is_dead", false)):
			continue
		if int(ent.get("battle_team", -1)) != pt:
			continue
		var r: int = 9
		if int(ent.get("speed", 0)) <= 0:
			var sk := str(ent.get("structure_kind", ""))
			if sk == "turret":
				r = 10
			elif sk == "tech_watch":
				r = 16   # the Old Watchtower earns its name
			else:
				r = 8
		var ex: int = int(ent.get("x", 0))
		var ey: int = int(ent.get("y", 0))
		var x0: int = maxi(0, ex - r)
		var x1: int = mini(_ms - 1, ex + r)
		var y0: int = maxi(0, ey - r)
		var y1: int = mini(_ms - 1, ey + r)
		for vy in range(y0, y1 + 1):
			var row: int = vy * _ms
			for vx in range(x0, x1 + 1):
				_vision[row + vx] = 1
	# Paint into a raw RGBA byte buffer — ~20× faster than per-pixel set_pixel.
	var total: int = _ms * _ms
	var buf := PackedByteArray()
	buf.resize(total * 4)
	var bi: int = 0
	for i in range(total):
		if _vision[i] == 1:
			_explored[i] = 1
			buf[bi] = 0; buf[bi + 1] = 0; buf[bi + 2] = 0; buf[bi + 3] = 0
		elif _explored[i] == 1:
			buf[bi] = 3; buf[bi + 1] = 3; buf[bi + 2] = 8; buf[bi + 3] = 128
		else:
			buf[bi] = 5; buf[bi + 1] = 5; buf[bi + 2] = 10; buf[bi + 3] = 255
		bi += 4
	_fog_img = Image.create_from_data(_ms, _ms, false, Image.FORMAT_RGBA8, buf)
	if _fog_tex == null:
		_fog_tex = ImageTexture.create_from_image(_fog_img)
	else:
		_fog_tex.update(_fog_img)

## Is this entity visible to the player under fog rules?
func _fog_sees(ent: Dictionary) -> bool:
	if not _fog_on or _fog_revealed:
		return true
	if int(ent.get("battle_team", -1)) == BattleSystem.player_team:
		return true
	var i: int = int(ent.get("y", 0)) * _ms + int(ent.get("x", 0))
	if i < 0 or i >= _vision.size():
		return true
	# Immobile things are remembered; mobile enemies need live sight.
	if bool(ent.get("is_resource_node", false)) or int(ent.get("speed", 1)) <= 0:
		return _explored[i] == 1
	return _vision[i] == 1

## Throttled attack alert: toast + minimap ping + B-key camera target.
func _raise_alert(text: String, pos: Vector3, is_base: bool) -> void:
	_last_alert_pos = pos
	_alert_ping_t = 3.0
	_alert_ping_tile = Vector2i(clampi(int(pos.x), 0, _ms - 1), clampi(int(pos.z), 0, _ms - 1))
	if is_base:
		_alert_base_cd = 8.0
	else:
		_alert_unit_cd = 12.0
	_toast_show("%s  (B = go there)" % text)
	_add_log(text)
	# Distinct UI klaxon — bases get the heavier alert.
	_play_sfx("attack_crit" if is_base else "block", 0.0, 2.0)


func _center_on_base() -> void:
	for ent in _e._dungeon_entities:
		if bool(ent.get("is_battle_base", false)) and not bool(ent.get("is_dead", false)) \
				and int(ent.get("battle_team", -1)) == BattleSystem.player_team:
			_cam_focus = Vector3(float(int(ent["x"])), 0.0, float(int(ent["y"])))
			_clamp_focus()
			return


func _center_on_ids(ids: Array) -> void:
	if ids.is_empty():
		return
	var acc := Vector3.ZERO
	var n := 0
	for uid in ids:
		var ent = _e._dung_find(str(uid))
		if ent != null and not bool(ent.get("is_dead", false)):
			acc += Vector3(float(int(ent["x"])), 0.0, float(int(ent["y"])))
			n += 1
	if n > 0:
		_cam_focus = acc / float(n)
		_clamp_focus()


# ═════════════════════════════════════════════════════════════════════════
# Entity rendering
# ═════════════════════════════════════════════════════════════════════════

## Spawn / move / update a persistent node per live entity; start a death
## fade for anything dead or removed. Node churn only on spawn and death.
func _sync_entities(delta: float) -> void:
	var seen: Dictionary = {}
	var cam_x: float = _cam_focus.x
	var cam_z: float = _cam_focus.z
	var cull_r: float = _zoom * 1.5   # entities beyond this radius skip visual updates
	var hide_bars: bool = _zoom > 50.0  # hide HP bars when very zoomed out
	for ent_v in _e._dungeon_entities:
		var ent: Dictionary = ent_v
		var id := str(ent.get("id", ""))
		if id == "" or _ignored_ids.has(id):
			continue
		var is_res := bool(ent.get("is_resource_node", false))
		if not is_res and not bool(ent.get("is_crate", false)) \
				and bool(ent.get("is_chest", false)):
			_ignored_ids[id] = true   # never rendered — skip with one lookup
			continue
		if bool(ent.get("is_dead", false)) and not is_res:
			if _nodes.has(id) and not _dying.has(id):
				_dying[id] = 1.0
			continue
		seen[id] = true
		if _dead_done.has(id):
			_dead_done.erase(id)
		var n: Node3D = _nodes.get(id, null)
		var tx := int(ent.get("x", 0))
		var ty := int(ent.get("y", 0))
		if n == null:
			n = _spawn_entity_node(ent, id)
			n.position = Vector3(float(tx), 0.0, float(ty))   # snap, no lerp-in
		var p: Dictionary = _parts.get(id, {})
		if p.is_empty():
			continue
		# Fog of war: enemies outside player sight are hidden wholesale.
		var fvis: bool = _fog_sees(ent)
		if fvis != bool(p.get("fog_vis", true)):
			p["fog_vis"] = fvis
			n.visible = fvis
		# LOD: skip expensive visual updates for entities far from camera.
		var dx_cam: float = float(tx) - cam_x
		var dz_cam: float = float(ty) - cam_z
		if (dx_cam * dx_cam + dz_cam * dz_cam) > cull_r * cull_r:
			continue
		# Position: lerp only while unsettled; snap when close, then skip
		# all movement work until the sim tile actually changes.
		if tx != int(p["tx"]) or ty != int(p["ty"]):
			p["tx"] = tx
			p["ty"] = ty
			p["settled"] = false
		if not bool(p["settled"]):
			var target := Vector3(float(tx), 0.0, float(ty))
			if n.position.distance_to(target) <= 0.02:
				n.position = target
				p["settled"] = true
			elif n.position.distance_to(target) > 6.0:
				n.position = target   # rift teleport — pop, don't streak
			else:
				n.position = n.position.lerp(target, minf(1.0, 10.0 * delta))
		# Hide health bars when zoomed far out — reduces visual clutter.
		if p.has("hp_fg") and is_instance_valid(p["hp_fg"]):
			(p["hp_fg"] as Node3D).visible = not hide_bars
		if p.has("hp_bg") and is_instance_valid(p["hp_bg"]):
			(p["hp_bg"] as Node3D).visible = not hide_bars
		_update_entity_visuals(ent, p)
	# Entities that vanished from the roster entirely.
	for id in _nodes.keys():
		if not seen.has(id) and not _dying.has(id):
			_dying[id] = 1.0


## Death fade: shrink + sink over 1 s, then free the node.
func _update_dying(delta: float) -> void:
	for id in _dying.keys():
		var t: float = float(_dying[id]) - delta
		var n: Node3D = _nodes.get(id, null)
		if n == null or not is_instance_valid(n):
			_dying.erase(id)
			_nodes.erase(id)
			_parts.erase(id)
			_ringed.erase(id)
			continue
		if t <= 0.0:
			n.queue_free()
			_dying.erase(id)
			_nodes.erase(id)
			_parts.erase(id)
			_ringed.erase(id)
			_dead_done[id] = true
			continue
		_dying[id] = t
		var s := clampf(t, 0.02, 1.0)
		n.scale = Vector3.ONE * s
		n.position.y = -(1.0 - t) * 0.4


## True when a sprite art path resolves on disk — via the resource system OR
## the raw filesystem (mirrors RimvaleUtils._safe_load_texture, which covers
## PNGs whose .import metadata is missing).
func _sprite_file_exists(path: String) -> bool:
	if ResourceLoader.exists(path):
		return true
	return FileAccess.file_exists(ProjectSettings.globalize_path(path))


## Build the persistent visual for one entity. Returns the root Node3D.
func _spawn_entity_node(ent: Dictionary, id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "ent_%s" % id
	add_child(root)
	_nodes[id] = root

	var team := int(ent.get("battle_team", -1))
	var team_col: Color = BattleSystem.get_team_color(maxi(team, 0))
	var p := {
		"ring": null, "hp_bg": null, "hp_fg": null,
		"fg_mat": null, "pip": null, "kind": "unit", "hp_y": 1.35,
		"last_hp": -1, "last_max": -1, "pip_state": -1,
		"tx": -9999, "ty": -9999, "settled": false, "is_struct": false,
		"dimmed": false, "crystal_light": null, "crystal_mats": [],
		"busy": null, "busy_state": 0,
	}

	if bool(ent.get("is_resource_node", false)):
		p["kind"] = "node"
		_build_crystal_visual(root, p)
		_parts[id] = p
		return root

	if bool(ent.get("is_crate", false)):
		# Supply crate: a small golden box with a beacon glint.
		p["kind"] = "crate"
		var cb := MeshInstance3D.new()
		var cbm := BoxMesh.new()
		cbm.size = Vector3(0.55, 0.45, 0.55)
		cbm.material = _mat(Color(0.75, 0.6, 0.25), 0.1, Color(1.0, 0.85, 0.4), 0.9)
		cb.mesh = cbm
		cb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cb.position = Vector3(0.0, 0.23, 0.0)
		root.add_child(cb)
		var ct := Label3D.new()
		ct.text = "📦"
		ct.font_size = 40
		ct.pixel_size = 0.006
		ct.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		ct.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ct.position = Vector3(0.0, 1.0, 0.0)
		root.add_child(ct)
		_parts[id] = p
		return root

	var is_struct := bool(ent.get("is_battle_base", false)) or bool(ent.get("is_battle_structure", false))
	p["is_struct"] = is_struct
	# Visual bulk: sim size 1 → 1.0×, size 2 → 1.7×, size 3 (kaiju) → 2.4×.
	# int() of legacy string sizes ("Colossal") is 0, clamped back to 1.
	var usize: int = maxi(1, int(ent.get("size", 1)))
	var uscale: float = 1.0 + 0.7 * float(usize - 1)
	if is_struct:
		p["kind"] = "structure"
		var is_base := bool(ent.get("is_battle_base", false))
		p["hp_y"] = 2.35 if is_base else 2.0
		_build_structure_visual(root, ent, team_col, is_base)
	elif bool(ent.get("is_vehicle", false)):
		p["kind"] = "vehicle"
		p["hp_y"] = 1.3 * uscale
		var vm: Node3D = CharacterModelBuilder.build_vehicle_sprite_model(
			str(ent.get("lineage_name", ent.get("name", "Vehicle"))), 1.3)
		vm.scale = Vector3.ONE * uscale
		_set_no_shadows(vm)
		root.add_child(vm)
		_add_team_disc(root, team, team_col, 0.5 * uscale)
	else:
		# Art resolution order: the explicit `ent["sprite"]` path stamped by
		# the unit builders in battle_system.gd wins; the lineage-name lookup
		# (previous behavior) is second; the procedural placeholder inside
		# build_sprite_model is the LAST resort. Passing the verified file's
		# basename as the lookup key routes mob/militia/kaiju art through the
		# same billboard pipeline (sizing, alpha cut, team rim light) that
		# lineage troops already use.
		var model_key: String = str(ent.get("lineage_name", ""))
		var sprite_path: String = str(ent.get("sprite", ""))
		if sprite_path != "" and _sprite_file_exists(sprite_path):
			model_key = sprite_path.get_file().get_basename()
		var model: Node3D = CharacterModelBuilder.build_sprite_model(
			model_key,
			str(ent.get("equipped_weapon", "None")),
			str(ent.get("equipped_armor", "None")),
			str(ent.get("equipped_shield", "None")),
			0.9, team_col)
		model.scale = Vector3.ONE * uscale
		_set_no_shadows(model)
		root.add_child(model)
		p["hp_y"] = 1.35 * uscale
		if bool(ent.get("is_hero", false)):
			# Story heroes read as GOLD on the field (99 = synthetic cache
			# key — real teams cap at 10, so it never collides).
			_add_team_disc(root, 99, Color(1.0, 0.82, 0.25), 0.38)
		else:
			_add_team_disc(root, team, team_col, 0.38 * uscale)

	# Selection ring (hidden until selected) — shared mesh + shared gold /
	# cyan materials, swapped via material_override in _refresh_rings.
	# Large units get a proportionally wider ring (footprint, not feet).
	var ring := MeshInstance3D.new()
	ring.mesh = _shared_ring_struct if is_struct else _shared_ring_unit
	ring.material_override = _ring_mat_gold
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(1.0, 0.25, 1.0) if is_struct \
			else Vector3(uscale, 0.25, uscale)
	ring.position = Vector3(0.0, 0.04, 0.0)
	ring.visible = false
	root.add_child(ring)
	p["ring"] = ring

	# Health bars: shared unit quad sized via node.scale; bg material shared,
	# fg material duplicated (its color animates green→red per unit).
	var hp_y := float(p["hp_y"])
	var bg := MeshInstance3D.new()
	bg.mesh = _shared_bar_quad
	bg.material_override = _hp_bg_mat
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bg.scale = Vector3(HP_BG_SIZE.x, HP_BG_SIZE.y, 1.0)
	bg.position = Vector3(0.0, hp_y, 0.0)
	root.add_child(bg)
	var fg_mat: StandardMaterial3D = _hp_fg_template.duplicate()
	var fg := MeshInstance3D.new()
	fg.mesh = _shared_bar_quad
	fg.material_override = fg_mat
	fg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fg.scale = Vector3(HP_FG_SIZE.x, HP_FG_SIZE.y, 1.0)
	fg.position = Vector3(0.0, hp_y, 0.0)
	root.add_child(fg)
	bg.visible = false
	fg.visible = false
	p["hp_bg"] = bg
	p["hp_fg"] = fg
	p["fg_mat"] = fg_mat

	# Spell pip: tiny star that dims while any spell cools down.
	if not is_struct:
		var pip := Label3D.new()
		pip.text = "✦"
		pip.font_size = 40
		pip.pixel_size = 0.006
		pip.outline_size = 6
		pip.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pip.position = Vector3(0.0, hp_y + 0.22, 0.0)
		pip.visible = false
		root.add_child(pip)
		p["pip"] = pip

	# Busy glyph (player units): ⚔ while engaged, ⛏ while on mining duty.
	if not is_struct and int(ent.get("battle_team", -1)) == BattleSystem.player_team:
		var busy := Label3D.new()
		busy.text = "⚔"
		busy.font_size = 44
		busy.pixel_size = 0.006
		busy.outline_size = 7
		busy.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		busy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		busy.outline_modulate = Color(0.05, 0.04, 0.03, 0.95)
		busy.position = Vector3(0.32, hp_y + 0.22, 0.0)
		busy.visible = false
		root.add_child(busy)
		p["busy"] = busy

	_parts[id] = p
	return root


## Team-colored disc under a unit so its allegiance always reads.
## Shared mesh (scaled per node) + one cached material per team.
func _add_team_disc(root: Node3D, team: int, col: Color, radius: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _shared_disc_mesh
	mi.material_override = _disc_mat(team, col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(radius, 1.0, radius)
	mi.position = Vector3(0.0, 0.025, 0.0)
	root.add_child(mi)


## Resource node: teal crystal spike cluster + soft glint light.
func _build_crystal_visual(root: Node3D, p: Dictionary) -> void:
	var teal := Color(0.15, 0.85, 0.80)
	var mats: Array = []
	var offsets := [
		Vector3(0.0, 0.0, 0.0), Vector3(0.28, 0.0, -0.16),
		Vector3(-0.24, 0.0, 0.2), Vector3(0.1, 0.0, 0.3),
	]
	var heights := [1.0, 0.65, 0.55, 0.4]
	for i in range(offsets.size()):
		var prism := PrismMesh.new()
		prism.size = Vector3(0.3, float(heights[i]), 0.3)
		var m := _mat(teal, 0.15, teal, 1.6)
		prism.material = m
		mats.append(m)
		var mi := MeshInstance3D.new()
		mi.mesh = prism
		mi.position = offsets[i] + Vector3(0.0, float(heights[i]) * 0.5, 0.0)
		mi.rotation_degrees = Vector3(0.0, float(i) * 47.0, 0.0)
		root.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = teal
	light.omni_range = 3.0
	light.light_energy = 1.1
	light.position = Vector3(0.0, 0.8, 0.0)
	root.add_child(light)
	p["crystal_light"] = light
	p["crystal_mats"] = mats


## Region-building look: team-tinted body, prism roof, door, lit windows,
## floating name sign (dungeon.gd battle-structure style, scaled up).
func _build_structure_visual(root: Node3D, ent: Dictionary, team_col: Color, is_base: bool) -> void:
	# Wall segments: a plain low rampart block — no roof, door or sign.
	if str(ent.get("structure_kind", "")) == "wall":
		var wb := BoxMesh.new()
		wb.size = Vector3(0.96, 0.85, 0.96)
		wb.material = _mat(team_col.lerp(Color(0.55, 0.53, 0.5), 0.7), 0.9)
		var wb_mi := MeshInstance3D.new()
		wb_mi.mesh = wb
		wb_mi.position = Vector3(0.0, 0.43, 0.0)
		root.add_child(wb_mi)
		return
	var w := 1.6 if is_base else 1.2
	var h := 1.4 if is_base else 1.1
	var wall_col := team_col.lerp(Color(0.72, 0.68, 0.62), 0.55)

	var body := BoxMesh.new()
	body.size = Vector3(w, h, w)
	body.material = _mat(wall_col, 0.85)
	var body_mi := MeshInstance3D.new()
	body_mi.mesh = body
	body_mi.position = Vector3(0.0, h * 0.5, 0.0)
	root.add_child(body_mi)

	var roof := PrismMesh.new()
	roof.size = Vector3(w * 1.15, 0.5, w * 1.15)
	roof.material = _mat(team_col.darkened(0.25), 0.8)
	var roof_mi := MeshInstance3D.new()
	roof_mi.mesh = roof
	roof_mi.position = Vector3(0.0, h + 0.25, 0.0)
	root.add_child(roof_mi)

	var door := BoxMesh.new()
	door.size = Vector3(0.3, 0.52, 0.06)
	door.material = _mat(wall_col.darkened(0.5), 0.9)
	var door_mi := MeshInstance3D.new()
	door_mi.mesh = door
	door_mi.position = Vector3(0.0, 0.26, w * 0.5 + 0.01)
	root.add_child(door_mi)

	var win := BoxMesh.new()
	win.size = Vector3(0.22, 0.22, 0.05)
	win.material = _mat(Color(1.0, 0.9, 0.6), 0.4, Color(1.0, 0.85, 0.45), 1.3)
	for sx in [-0.32, 0.32]:
		var win_mi := MeshInstance3D.new()
		win_mi.mesh = win
		win_mi.position = Vector3(float(sx), h * 0.62, w * 0.5 + 0.01)
		root.add_child(win_mi)

	var name_sign := Label3D.new()
	name_sign.text = str(ent.get("name", "Structure"))
	name_sign.font_size = 30
	name_sign.pixel_size = 0.006
	name_sign.outline_size = 8
	name_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_sign.modulate = team_col.lightened(0.45)
	name_sign.outline_modulate = Color(0.05, 0.04, 0.03, 0.95)
	name_sign.position = Vector3(0.0, h + 1.1, 0.0)
	root.add_child(name_sign)


## Cheap per-frame property updates: HP bar + spell pip + node depletion.
## Every branch is change-gated — nothing is written unless a cached value
## actually flipped since the previous frame.
func _update_entity_visuals(ent: Dictionary, p: Dictionary) -> void:
	if str(p["kind"]) == "crate":
		return   # nothing dynamic on a crate
	if str(p["kind"]) == "node":
		# Depleted veins dim; replenished veins light back up (3-min refill).
		var looted := bool(ent.get("looted", false))
		if looted != bool(p["dimmed"]):
			p["dimmed"] = looted
			var light = p["crystal_light"]
			if light != null and is_instance_valid(light):
				light.visible = not looted
			for m in p["crystal_mats"]:
				if looted:
					m.albedo_color = Color(0.35, 0.42, 0.42)
					m.emission_energy_multiplier = 0.0
				else:
					# Restore the original crystal look (_build_crystal_visual).
					m.albedo_color = Color(0.15, 0.85, 0.80)
					m.emission_energy_multiplier = 1.6
		return

	# Health bar — only touched when the integer hp / max_hp changed.
	var hp := int(ent.get("hp", 0))
	var max_hp := maxi(1, int(ent.get("max_hp", 1)))
	if hp != int(p["last_hp"]) or max_hp != int(p["last_max"]):
		p["last_hp"] = hp
		p["last_max"] = max_hp
		var bg = p["hp_bg"]
		var fg = p["hp_fg"]
		if bg != null:
			var frac := clampf(float(hp) / float(max_hp), 0.0, 1.0)
			var damaged := frac < 0.999
			bg.visible = damaged
			fg.visible = damaged
			if damaged:
				fg.scale = Vector3(HP_FG_SIZE.x * maxf(frac, 0.02), HP_FG_SIZE.y, 1.0)
				# green → yellow → red across the HP fraction.
				var m = p["fg_mat"]
				if m != null:
					m.albedo_color = Color.from_hsv(frac * 0.33, 0.85, 0.92)

	# Spell pip — only touched when hidden/ready/cooling state flips.
	var pip = p["pip"]
	if pip != null:
		var state := 0   # 0 hidden · 1 ready · 2 cooling
		var spells: Array = ent.get("spells", [])
		if not spells.is_empty():
			state = 1
			for s in spells:
				if s is Dictionary and int(s.get("cd_left", 0)) > 0:
					state = 2
					break
		if state != int(p["pip_state"]):
			p["pip_state"] = state
			pip.visible = state != 0
			if state != 0:
				pip.modulate = Color(0.35, 0.45, 0.65, 0.55) if state == 2 else Color(0.55, 0.85, 1.0, 1.0)

	# Busy glyph — only touched when idle/fighting/mining state flips.
	var busy = p["busy"]
	if busy != null:
		var bstate := 0   # 0 idle · 1 fighting · 2 mining
		if str(ent.get("order_target", "")) != "" or str(ent.get("auto_tgt", "")) != "":
			bstate = 1
		elif str(ent.get("miner_node_id", "")) != "":
			bstate = 2
		if bstate != int(p["busy_state"]):
			p["busy_state"] = bstate
			busy.visible = bstate != 0
			if bstate == 1:
				busy.text = "⚔"
				busy.modulate = Color(1.0, 0.45, 0.35, 0.95)
			elif bstate == 2:
				busy.text = "⛏"
				busy.modulate = Color(0.25, 0.9, 0.85, 0.95)

	# Invincibility glow — bright golden shield on god-mode units.
	var is_god: bool = "invulnerable" in ent.get("conditions", [])
	var god_state: bool = bool(p.get("god_vis", false))
	if is_god != god_state:
		p["god_vis"] = is_god
		var eid: String = str(ent.get("id", ""))
		var node: Node3D = _nodes.get(eid)
		if node != null and is_instance_valid(node):
			var god_label = p.get("god_label")
			if god_label == null:
				# Create the label lazily on first toggle.
				god_label = Label3D.new()
				god_label.text = "🛡"
				god_label.font_size = 52
				god_label.pixel_size = 0.006
				god_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				god_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				god_label.modulate = Color(1.0, 0.85, 0.2, 0.95)
				god_label.outline_size = 8
				god_label.outline_modulate = Color(0.4, 0.3, 0.0, 0.8)
				god_label.position = Vector3(-0.32, float(p.get("hp_y", 1.35)) + 0.22, 0.0)
				node.add_child(god_label)
				p["god_label"] = god_label
			god_label.visible = is_god


# ═════════════════════════════════════════════════════════════════════════
# Sim events (flashes + log)
# ═════════════════════════════════════════════════════════════════════════

## One-shot battle SFX through the shared AudioManager. Silent while muted;
## AudioManager itself guards every load with ResourceLoader.exists(), so an
## unknown/missing id is a harmless no-op — sound can never crash the battle.
func _play_sfx(id: String, pitch_var: float = 0.08, vol_db: float = 0.0) -> void:
	if _audio_muted:
		return
	AudioManager.play_sfx(id, pitch_var, vol_db)


func _on_sim_event(kind: String, data: Dictionary) -> void:
	match kind:
		"dot":
			# Damage over time has no attacker — show what's killing them.
			if int(data.get("x", -1)) >= 0:
				var dpos := Vector3(float(int(data["x"])), 1.2, float(int(data["y"])))
				_show_ground_marker(dpos, "-%d 🩸" % int(data.get("amount", 0)),
					Color(0.95, 0.35, 0.15))
			var did := str(data.get("id", ""))
			if did != "" and _nodes.has(did):
				_flash_node(did, Color(0.9, 0.4, 0.1))
		"blood_cast":
			# Casting costs HP in Battle Mode — show the price being paid.
			if int(data.get("x", -1)) >= 0:
				var bpos := Vector3(float(int(data["x"])), 1.4, float(int(data["y"])))
				_show_ground_marker(bpos, "-%d ❤" % int(data.get("hp", 0)),
					Color(0.9, 0.15, 0.2))
		"attack":
			var tid := str(data.get("target", data.get("target_id", "")))
			_flash_node(tid, Color(1.0, 0.25, 0.2))
			# Throttled impact: piercing whistle for ranged, slash for melee.
			# Ranged is inferred from attacker→target distance, matching the
			# ≥1.6-tile threshold _fire_projectile uses to draw a missile.
			if _sfx_atk_cd <= 0.0:
				_sfx_atk_cd = 0.09
				var ranged := false
				var an: Node3D = _nodes.get(str(data.get("attacker", "")), null)
				var bn: Node3D = _nodes.get(tid, null)
				if an != null and is_instance_valid(an) \
						and bn != null and is_instance_valid(bn):
					ranged = an.position.distance_to(bn.position) >= 1.6
				_play_sfx("attack_pierce" if ranged else "attack_slash")
			# Ranged weapon (bow / turret) → arrow. Melee is skipped by the
			# distance check inside _fire_projectile.
			_fire_projectile(str(data.get("attacker", "")), tid,
				Color(0.78, 0.62, 0.38), false)
			# Player under fire? Raise a throttled C&C-style alert.
			var v_ent = _e._dung_find(tid)
			if v_ent != null and int(v_ent.get("battle_team", -1)) == BattleSystem.player_team:
				var vpos := Vector3(float(int(v_ent.get("x", 0))), 0.0, float(int(v_ent.get("y", 0))))
				var v_struct := bool(v_ent.get("is_battle_structure", false)) \
					or bool(v_ent.get("is_battle_base", false))
				if v_struct and _alert_base_cd <= 0.0:
					_raise_alert("🚨 BASE UNDER ATTACK!", vpos, true)
				elif not v_struct and _alert_unit_cd <= 0.0 and _alert_base_cd <= 0.0:
					_raise_alert("⚔ Your forces are under attack!", vpos, false)
		"spell":
			var tid := str(data.get("target", data.get("target_id", "")))
			var hint := str(data.get("kind_hint", ""))
			var scol := _element_color(str(data.get("dt", "")), hint)
			# Throttled cast sound, picked by element / effect.
			if _sfx_spell_cd <= 0.0:
				_sfx_spell_cd = 0.12
				var dt := str(data.get("dt", "")).to_lower()
				var sid := "spell_cast"
				if hint == "heal":
					sid = "spell_heal"
				elif dt.contains("fire") or dt.contains("flame"):
					sid = "spell_fire"
				elif dt.contains("cold") or dt.contains("ice") or dt.contains("frost"):
					sid = "spell_ice"
				elif dt.contains("light") or dt.contains("shock") or dt.contains("thunder"):
					sid = "spell_lightning"
				_play_sfx(sid, 0.05)
			var ipos := Vector3.INF
			if data.has("x") and int(data.get("x", -1)) >= 0:
				ipos = Vector3(float(int(data["x"])), 0.0, float(int(data["y"])))
			# Offensive magic flies as a glowing bolt; heals/buffs just glow.
			if hint == "damage" or hint == "curse":
				_fire_projectile(str(data.get("caster", "")), tid, scol, true, ipos)
			if tid != "" and _nodes.has(tid):
				_flash_node(tid, scol if hint != "heal" else Color(0.35, 1.0, 0.5))
			elif ipos.is_finite():
				_burst_at(ipos, scol)
			# Blast spells detonate: extra bursts scale with the AOE radius.
			var aoe := int(data.get("aoe", 0))
			if aoe > 0 and ipos.is_finite():
				_burst_at(ipos + Vector3(float(aoe) * 0.7, 0.0, 0.4), scol)
				_burst_at(ipos + Vector3(-0.5, 0.0, float(aoe) * -0.6), scol)
			# AoE ground circle: shows the affected area as a translucent disc.
			if aoe > 0 and ipos.is_finite():
				_spawn_aoe_circle(ipos, float(aoe) + 0.5, hint == "heal" or hint == "buff")
			var stx := str(data.get("text", ""))
			if stx != "":
				_add_log(stx)
		"death":
			var t := str(data.get("text", ""))
			if t == "" and data.has("name"):
				t = "💀 %s falls." % str(data["name"])
			if t != "":
				_add_log(t)
			if _sfx_death_cd <= 0.0:
				_sfx_death_cd = 0.14
				_play_sfx("death")
		"spawn":
			pass  # _sync_entities spawns the node next frame
		"structure":
			var t := str(data.get("text", ""))
			if t != "":
				_add_log(t)
		"income":
			pass  # rendered by the top bar
		"strike":
			if data.has("x") and data.has("y"):
				var sp := Vector3(float(int(data["x"])), 0.0, float(int(data["y"])))
				_burst_at(sp, Color(1.0, 0.55, 0.15))
				_burst_at(sp + Vector3(0.8, 0.0, 0.6), Color(1.0, 0.35, 0.1))
				_burst_at(sp + Vector3(-0.7, 0.0, -0.8), Color(1.0, 0.75, 0.25))
				_play_sfx("hit_heavy", 0.0, 3.0)   # arcane strike detonation
		"mind_control":
			var mid := str(data.get("id", ""))
			if mid != "":
				_flash_node(mid, Color(0.85, 0.3, 1.0))
		"capture":
			var cid := str(data.get("id", ""))
			if cid != "":
				_flash_node(cid, Color(0.3, 1.0, 0.5))
			_play_sfx("coin")   # structure captured
		"promote":
			_play_sfx("spell_heal", 0.0, -2.0)   # veterancy chime (🎖 log covers text)
		"kaiju":
			var kpos := Vector3(float(int(data.get("x", 25))), 0.0, float(int(data.get("y", 25))))
			_raise_alert("🚨 A WILD KAIJU has risen mid-map!", kpos, false)
			_burst_at(kpos, Color(1.0, 0.2, 0.1))
			_burst_at(kpos + Vector3(1.5, 0.0, 1.0), Color(1.0, 0.45, 0.1))
			_play_sfx("hit_heavy", 0.0, 5.0)   # the ground-shaking rise
		"crate":
			if int(data.get("team", -1)) == BattleSystem.player_team:
				_toast_show("📦 %s" % str(data.get("reward", "Crate opened!")))
			_burst_at(Vector3(float(int(data.get("x", 0))), 0.0,
				float(int(data.get("y", 0)))), Color(1.0, 0.85, 0.4))
		"crate_drop":
			pass  # the 📦 log line covers it; scouting finds the rest
		"region_fx":
			var fx_pos := Vector3(float(int(data.get("x", 0))), 0.0, float(int(data.get("y", 0))))
			var fx_col := Color(0.8, 0.8, 1.0)
			match str(data.get("type", "")):
				"blizzard":
					fx_col = Color(0.55, 0.8, 1.0)
				"lava":
					fx_col = Color(1.0, 0.4, 0.05)
				"spores":
					fx_col = Color(0.55, 0.9, 0.35)
				"gloom":
					fx_col = Color(0.45, 0.2, 0.6)
				"rift_jump":
					fx_col = Color(0.7, 0.35, 1.0)
			_burst_at(fx_pos, fx_col)
			if str(data.get("type", "")) != "rift_jump":
				_burst_at(fx_pos + Vector3(1.2, 0.0, 0.8), fx_col)
				_burst_at(fx_pos + Vector3(-1.0, 0.0, -1.1), fx_col)
			if str(data.get("type", "")) == "lava":
				_play_sfx("spell_fire", 0.0, 1.0)   # erupting lava vent
		"elim":
			var t := str(data.get("text", ""))
			if t == "" and data.has("team"):
				t = "💀 Team %d has been eliminated!" % int(data["team"])
			if t != "":
				_add_log(t)
		"over":
			_show_over(int(data.get("winner", -1)))


## Quick colored light flash on an entity node (attack hit / spell impact).
## Pooled — events beyond MAX_EFFECT_LIGHTS skip the visual.
func _flash_node(id: String, col: Color) -> void:
	var n: Node3D = _nodes.get(id, null)
	if n == null or not is_instance_valid(n):
		return
	_spawn_effect_light(n.position + Vector3(0.0, 0.8, 0.0), col, 2.6, 3.2, 0.35)


## Spawn a translucent ground circle showing AoE radius.
## Red for damage, green for healing. Fades out over ~1.5 s.
func _spawn_aoe_circle(center: Vector3, radius: float, is_heal: bool) -> void:
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.04
	cyl.radial_segments = 24
	mesh_inst.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if is_heal:
		mat.albedo_color = Color(0.15, 0.95, 0.3, 0.35)
	else:
		mat.albedo_color = Color(0.95, 0.15, 0.1, 0.35)
	mesh_inst.set_surface_override_material(0, mat)
	mesh_inst.position = center + Vector3(0.0, 0.05, 0.0)
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_inst)
	# Fade out via tween.
	var tw := create_tween()
	tw.tween_method(func(a: float): mat.albedo_color.a = a, 0.35, 0.0, 1.5)
	tw.tween_callback(mesh_inst.queue_free)


## Colored burst at a world position (ground-targeted spells). Pooled.
func _burst_at(pos: Vector3, col: Color) -> void:
	_spawn_effect_light(pos + Vector3(0.0, 0.9, 0.0), col, 3.5, 3.5, 0.45)


# ── Projectiles (pooled) ──────────────────────────────────────────────────
## Visible missiles: arrows for ranged weapon hits, glowing bolts for
## ranged spells. Purely cosmetic — damage already landed in the sim.

const MAX_PROJECTILES := 16

## Launch a missile between two entity nodes (or toward an impact point).
## Skips melee-distance shots and anything beyond the pool cap.
func _fire_projectile(from_id: String, to_id: String, col: Color,
		magic: bool, impact: Vector3 = Vector3.INF) -> void:
	var a: Node3D = _nodes.get(from_id, null)
	if a == null or not is_instance_valid(a):
		return
	var to_pos: Vector3 = impact
	var b: Node3D = _nodes.get(to_id, null)
	if b != null and is_instance_valid(b):
		to_pos = b.position
	if not to_pos.is_finite():
		return
	var from: Vector3 = a.position + Vector3(0.0, 1.0, 0.0)
	var to: Vector3 = to_pos + Vector3(0.0, 0.8, 0.0)
	var dist: float = from.distance_to(to)
	if dist < 1.6:
		return   # melee swing — no missile
	# Grab a free pooled projectile.
	var slot: Dictionary = {}
	for p_v in _projectiles:
		var p: Dictionary = p_v
		if float(p["t"]) >= 1.0:
			slot = p
			break
	if slot.is_empty():
		if _projectiles.size() >= MAX_PROJECTILES:
			return   # cap reached — drop the visual
		var mi := MeshInstance3D.new()
		if _shared_proj_mesh == null:
			_shared_proj_mesh = BoxMesh.new()
			_shared_proj_mesh.size = Vector3(0.07, 0.07, 0.42)
		mi.mesh = _shared_proj_mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		slot = {"n": mi, "from": Vector3.ZERO, "to": Vector3.ZERO,
			"t": 1.0, "dur": 0.2, "arc": 0.0}
		_projectiles.append(slot)
	var n: MeshInstance3D = slot["n"]
	n.set_surface_override_material(0, _proj_mat(col, magic))
	slot["from"] = from
	slot["to"] = to
	slot["t"] = 0.0
	slot["dur"] = clampf(dist * 0.045, 0.1, 0.45)
	slot["arc"] = 0.15 if magic else 0.9   # arrows lob, bolts fly flat
	n.position = from
	n.visible = true

## Spell visuals take the color of their ELEMENT (the spell's damage type),
## so a Frost Lance streaks ice-blue while a Fireball burns orange.
func _element_color(dt: String, hint: String) -> Color:
	match dt:
		"fire":
			return Color(1.0, 0.42, 0.08)
		"cold":
			return Color(0.45, 0.85, 1.0)
		"lightning":
			return Color(1.0, 0.95, 0.25)
		"force":
			return Color(0.95, 0.55, 1.0)
		"radiant":
			return Color(1.0, 0.95, 0.65)
		"necrotic":
			return Color(0.45, 0.85, 0.35)
		"poison", "acid":
			return Color(0.55, 0.9, 0.15)
		"cold_fire":
			return Color(0.6, 0.7, 1.0)
		"slashing", "piercing", "bludgeoning":
			return Color(0.85, 0.85, 0.92)
	# No element on record — fall back to the spell's role.
	if hint == "heal":
		return Color(0.35, 1.0, 0.5)
	if hint == "damage":
		return Color(1.0, 0.5, 0.15)
	return Color(0.7, 0.4, 1.0)   # curses stay violet

## Per-color projectile material cache (arrows tan, bolts emissive).
func _proj_mat(col: Color, magic: bool) -> StandardMaterial3D:
	var key := "%s_%s" % [col.to_html(false), "m" if magic else "a"]
	if _proj_mats.has(key):
		return _proj_mats[key]
	var m: StandardMaterial3D
	if magic:
		m = _mat(col, 0.2, col, 2.2)
	else:
		m = _mat(col, 0.0, Color.BLACK, 0.0)
	_proj_mats[key] = m
	return m

## Advance every live projectile along its flight path.
func _update_projectiles(delta: float) -> void:
	for p_v in _projectiles:
		var p: Dictionary = p_v
		var t: float = float(p["t"])
		if t >= 1.0:
			continue
		t = minf(1.0, t + delta / float(p["dur"]))
		p["t"] = t
		var n: MeshInstance3D = p["n"]
		if t >= 1.0:
			n.visible = false
			continue
		var from: Vector3 = p["from"]
		var to: Vector3 = p["to"]
		var pos: Vector3 = from.lerp(to, t)
		pos.y += sin(t * PI) * float(p["arc"])
		var dir: Vector3 = (to - from).normalized()
		if dir.length_squared() > 0.001:
			n.look_at_from_position(pos, pos + dir, Vector3.UP)
		else:
			n.position = pos


## Grab a free pooled OmniLight (or grow the pool up to the cap) and
## restart it. No per-event instancing / tweens / queue_free.
func _spawn_effect_light(pos: Vector3, col: Color, rng: float, energy: float, dur: float) -> void:
	var slot: Dictionary = {}
	for e_v in _effect_lights:
		var e: Dictionary = e_v
		if float(e["t"]) <= 0.0:
			slot = e
			break
	if slot.is_empty():
		if _effect_lights.size() >= MAX_EFFECT_LIGHTS:
			return   # cap reached — drop the visual, keep the log line
		var l := OmniLight3D.new()
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		slot = {"light": l, "t": 0.0, "dur": dur, "peak": energy}
		_effect_lights.append(slot)
	var light: OmniLight3D = slot["light"]
	light.light_color = col
	light.omni_range = rng
	light.light_energy = energy
	light.position = pos
	light.visible = true
	slot["t"] = dur
	slot["dur"] = dur
	slot["peak"] = energy


## Short-lived floating glyph at a ground point (attack-move ⚔ etc.).
## Pooled Label3Ds — beyond MAX_EFFECT_MARKERS the visual is skipped.
func _show_ground_marker(pos: Vector3, txt: String, col: Color) -> void:
	var slot: Dictionary = {}
	for e_v in _effect_markers:
		var e: Dictionary = e_v
		if float(e["t"]) <= 0.0:
			slot = e
			break
	if slot.is_empty():
		if _effect_markers.size() >= MAX_EFFECT_MARKERS:
			return
		var l := Label3D.new()
		l.font_size = 96
		l.pixel_size = 0.01
		l.outline_size = 10
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		l.visible = false
		add_child(l)
		slot = {"lbl": l, "t": 0.0, "dur": 1.0}
		_effect_markers.append(slot)
	var lbl: Label3D = slot["lbl"]
	if lbl.text != txt:   # Label3D text set rebuilds geometry — guard it
		lbl.text = txt
	lbl.modulate = col
	lbl.position = pos + Vector3(0.0, 0.7, 0.0)
	lbl.visible = true
	slot["t"] = 1.0
	slot["dur"] = 1.0


## Per-frame decay of pooled effect lights / markers (hide, never free).
func _update_effects(delta: float) -> void:
	for e_v in _effect_lights:
		var e: Dictionary = e_v
		var t := float(e["t"])
		if t <= 0.0:
			continue
		t -= delta
		e["t"] = t
		var light: OmniLight3D = e["light"]
		if t <= 0.0:
			light.visible = false
			light.light_energy = 0.0
		else:
			light.light_energy = float(e["peak"]) * (t / float(e["dur"]))
	for e_v in _effect_markers:
		var e: Dictionary = e_v
		var t := float(e["t"])
		if t <= 0.0:
			continue
		t -= delta
		e["t"] = t
		var lbl: Label3D = e["lbl"]
		if t <= 0.0:
			lbl.visible = false
		else:
			lbl.modulate.a = clampf(t / float(e["dur"]), 0.0, 1.0)


# ═════════════════════════════════════════════════════════════════════════
# Input
# ═════════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)


func _handle_mouse_button(ev: InputEventMouseButton) -> void:
	match ev.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if ev.pressed:
				_zoom = clampf(_zoom - maxf(2.0, _zoom * 0.12), ZOOM_MIN, ZOOM_MAX)
		MOUSE_BUTTON_WHEEL_DOWN:
			if ev.pressed:
				_zoom = clampf(_zoom + maxf(2.0, _zoom * 0.12), ZOOM_MIN, ZOOM_MAX)
		MOUSE_BUTTON_LEFT:
			if ev.pressed:
				# Pending strike / attack-move / patrol / wall consume clicks.
				if _pending_strike:
					_do_strike(ev.position)
					return
				if _pending_attack_move:
					_do_attack_move(ev.position)
					return
				if _pending_patrol:
					_do_patrol(ev.position)
					return
				if _pending_wall:
					_do_place_wall(ev.position)
					return
				if _pending_debug_build != "":
					_do_debug_place_structure(ev.position)
					return
				if _pending_build_kind != "":
					_do_place_structure(ev.position)
					return
				_press_pos = ev.position
				_press_active = true
				_dragging = false
			else:
				if _dragging:
					_finish_drag_select(ev.position, ev.shift_pressed)
				elif _press_active:
					_click_select(ev.position, ev.shift_pressed)
				_press_active = false
				_dragging = false
				if _drag_rect != null:
					_drag_rect.visible = false
		MOUSE_BUTTON_RIGHT:
			if ev.pressed:
				_right_click(ev.position)


func _handle_mouse_motion(ev: InputEventMouseMotion) -> void:
	if not _press_active:
		return
	if not _dragging and ev.position.distance_to(_press_pos) > DRAG_THRESHOLD:
		_dragging = true
		if _drag_rect != null:
			_drag_rect.visible = true
	if _dragging and _drag_rect != null:
		var r := Rect2(_press_pos, ev.position - _press_pos).abs()
		_drag_rect.position = r.position
		_drag_rect.size = r.size


func _handle_key(ev: InputEventKey) -> void:
	match ev.keycode:
		KEY_ESCAPE:
			if _pending_strike:
				_pending_strike = false
				_toast_show("Strike cancelled.")
			elif _pending_patrol:
				_pending_patrol = false
				_toast_show("Patrol cancelled.")
			elif _pending_debug_build != "":
				_pending_debug_build = ""
				_toast_show("Debug placement cancelled.")
			elif _pending_build_kind != "":
				_pending_build_kind = ""
				_toast_show("Placement cancelled.")
			elif _pending_wall:
				_pending_wall = false
				_toast_show("Wall placement done.")
			elif _pending_attack_move:
				_pending_attack_move = false
				_toast_show("Attack-move cancelled.")
			elif _spell_popup != null and _spell_popup.visible:
				_spell_popup.visible = false
			else:
				_set_selection([], "")
		KEY_SPACE:
			_toggle_pause()
		KEY_F:
			# Cycle 1× → 2× → 3× → 1×.
			if BattleSystem.time_scale <= 1.0:
				BattleSystem.time_scale = 2.0
			elif BattleSystem.time_scale <= 2.0:
				BattleSystem.time_scale = 3.0
			else:
				BattleSystem.time_scale = 1.0
			_toast_show("⏩ Speed x%.0f" % BattleSystem.time_scale)
		KEY_HOME:
			_center_on_base()
		KEY_B:
			# Jump to the most recent attack alert.
			if _last_alert_pos.is_finite():
				_cam_focus = Vector3(_last_alert_pos.x, 0.0, _last_alert_pos.z)
				_clamp_focus()
		KEY_A:
			if not _selection.is_empty():
				_pending_attack_move = true
				_toast_show("⚔ Attack-move: left-click target ground (Esc cancels)")
		KEY_1, KEY_2, KEY_3, KEY_4:
			var sid := ev.keycode - KEY_1 + 1
			if ev.ctrl_pressed:
				if not _selection.is_empty():
					BattleSystem.assign_squad(sid, _selection)
					_toast_show("Squad %d assigned (%d units)" % [sid, _selection.size()])
			else:
				_select_squad(sid)


func _select_squad(sid: int) -> void:
	var members: Array = BattleSystem.squad_members(sid)
	if members.is_empty():
		_toast_show("Squad %d is empty." % sid)
		return
	_set_selection(members, "")
	var now := Time.get_ticks_msec()
	if _last_squad_key == sid and now - _last_squad_ms <= SQUAD_DOUBLE_MS:
		_center_on_ids(members)
	_last_squad_key = sid
	_last_squad_ms = now


## Project the mouse ray onto the y=0 ground plane (mathematical unproject —
## no physics needed). Returns Vector3.INF when the ray misses the ground.
func _mouse_ground(mpos: Vector2) -> Vector3:
	var origin := _cam.project_ray_origin(mpos)
	var dir := _cam.project_ray_normal(mpos)
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t := -origin.y / dir.y
	if t < 0.0:
		return Vector3.INF
	return origin + dir * t


func _ground_tile(world: Vector3) -> Vector2i:
	return Vector2i(
		clampi(int(round(world.x)), 0, _ms - 1),
		clampi(int(round(world.z)), 0, _ms - 1))


## Nearest living entity around a ground point. `filter`:
##   "own"   — player-team units & structures (units preferred)
##   "enemy" — hostile combatants (any other team)
##   "node"  — resource nodes
## Returns the entity Dictionary or {}.
func _pick_entity(world: Vector3, filter: String) -> Dictionary:
	var best: Dictionary = {}
	var best_score := 999.0
	for ent_v in _e._dungeon_entities:
		var ent: Dictionary = ent_v
		if bool(ent.get("is_dead", false)):
			continue
		var is_res := bool(ent.get("is_resource_node", false))
		var is_struct := bool(ent.get("is_battle_base", false)) or bool(ent.get("is_battle_structure", false))
		var team := int(ent.get("battle_team", -1))
		match filter:
			"own":
				if is_res or team != BattleSystem.player_team:
					continue
			"enemy":
				if is_res or bool(ent.get("is_chest", false)):
					continue
				if team < 0 or team == BattleSystem.player_team:
					continue
				if not _fog_sees(ent):
					continue   # can't order attacks on what you can't see
			"node":
				if not is_res:
					continue
			_:
				continue
		var dx := float(int(ent.get("x", 0))) - world.x
		var dz := float(int(ent.get("y", 0))) - world.z
		var d := sqrt(dx * dx + dz * dz)
		var radius := 0.9 if is_struct else (0.7 if is_res else 0.6)
		if d > radius:
			continue
		# Prefer units over structures when both overlap the click.
		var score := d + (0.5 if is_struct else 0.0)
		if score < best_score:
			best_score = score
			best = ent
	return best


func _click_select(mpos: Vector2, shift: bool) -> void:
	var world := _mouse_ground(mpos)
	if not world.is_finite():
		return
	var hit := _pick_entity(world, "own")
	if hit.is_empty():
		if not shift:
			_set_selection([], "")
		return
	var id := str(hit.get("id", ""))
	var is_struct := bool(hit.get("is_battle_base", false)) or bool(hit.get("is_battle_structure", false))
	if is_struct:
		_set_selection([], id)
		return
	if shift:
		var sel := _selection.duplicate()
		if sel.has(id):
			sel.erase(id)
		else:
			sel.append(id)
		_set_selection(sel, "")
	else:
		_set_selection([id], "")


func _finish_drag_select(mpos: Vector2, shift: bool) -> void:
	var r := Rect2(_press_pos, mpos - _press_pos).abs()
	var ids: Array = []
	for ent_v in _e._dungeon_entities:
		var ent: Dictionary = ent_v
		if bool(ent.get("is_dead", false)) or bool(ent.get("is_chest", false)):
			continue
		if bool(ent.get("is_resource_node", false)):
			continue
		if int(ent.get("battle_team", -1)) != BattleSystem.player_team:
			continue
		if bool(ent.get("is_battle_base", false)) or bool(ent.get("is_battle_structure", false)):
			continue  # box select grabs mobile units only
		var world := Vector3(float(int(ent.get("x", 0))), 0.5, float(int(ent.get("y", 0))))
		if _cam.is_position_behind(world):
			continue
		if r.has_point(_cam.unproject_position(world)):
			ids.append(str(ent.get("id", "")))
	if shift:
		var merged := _selection.duplicate()
		for id in ids:
			if not merged.has(id):
				merged.append(id)
		_set_selection(merged, "")
	elif not ids.is_empty():
		_set_selection(ids, "")
	else:
		_set_selection([], "")


func _right_click(mpos: Vector2) -> void:
	var world := _mouse_ground(mpos)
	if not world.is_finite():
		return
	var tile := _ground_tile(world)

	# Structure selected → right-click sets the rally point.
	if _sel_structure != "" and _selection.is_empty():
		BattleSystem.set_rally(BattleSystem.player_team, tile.x, tile.y)
		_toast_show("⚑ Rally point set.")
		return
	if _selection.is_empty():
		return

	# Enemy under cursor → attack order.
	var foe := _pick_entity(world, "enemy")
	if not foe.is_empty():
		var fid := str(foe.get("id", ""))
		if _selection.size() > 1:
			BattleSystem.order_group_attack(_selection, fid)
		else:
			BattleSystem.issue_attack_order(str(_selection[0]), fid)
		_show_ground_marker(world, "✖", Color(1.0, 0.3, 0.25))
		return

	# Resource node under cursor → mining duty (units walk in, park beside
	# the vein, and re-approach on their own if they get bumped away).
	var node := _pick_entity(world, "node")
	if not node.is_empty():
		var nid := str(node.get("id", ""))
		var n := BattleSystem.order_group_mine(_selection, nid)
		if n > 0:
			_toast_show("⛏ %d unit%s mining" % [n, "s" if n != 1 else ""])
		_show_ground_marker(world, "⛏", Color(0.2, 0.9, 0.85))
		return

	# Plain ground → move order.
	if _selection.size() > 1:
		BattleSystem.order_group_move(_selection, tile.x, tile.y)
	else:
		BattleSystem.issue_move_order(str(_selection[0]), tile.x, tile.y)
	_show_ground_marker(world, "➤", Color(0.4, 1.0, 0.5))


## Superweapon strike: aim anywhere; 6d10 to everything in the blast —
## friend or foe alike, so keep your own troops clear.
func _do_strike(mpos: Vector2) -> void:
	_pending_strike = false
	var world := _mouse_ground(mpos)
	if not world.is_finite():
		return
	var tile := _ground_tile(world)
	var err: String = BattleSystem.call_strike(BattleSystem.player_team, tile.x, tile.y)
	if err != "":
		_toast_show(err)
		return
	_show_ground_marker(world, "☄", Color(1.0, 0.55, 0.15))


## Patrol stance: second click defines the far leg of the loop.
func _do_patrol(mpos: Vector2) -> void:
	_pending_patrol = false
	var world := _mouse_ground(mpos)
	if not world.is_finite() or _selection.is_empty():
		return
	var tile := _ground_tile(world)
	var n: int = BattleSystem.set_stance(_selection, "patrol", tile.x, tile.y)
	if n > 0:
		_toast_show("🔁 Patrolling ×%d" % n)
	_show_ground_marker(world, "🔁", Color(0.5, 0.8, 1.0))


## Wall placement: stays armed so you can chain segments (Esc to finish).
func _do_place_wall(mpos: Vector2) -> void:
	var world := _mouse_ground(mpos)
	if not world.is_finite():
		return
	var tile := _ground_tile(world)
	var err: String = BattleSystem.place_wall(BattleSystem.player_team, tile.x, tile.y)
	if err != "":
		_toast_show(err)
		if err.begins_with("Need") or err.begins_with("Wall limit"):
			_pending_wall = false
		return
	_show_ground_marker(world, "🧱", Color(0.8, 0.75, 0.65))


func _do_attack_move(mpos: Vector2) -> void:
	_pending_attack_move = false
	var world := _mouse_ground(mpos)
	if not world.is_finite() or _selection.is_empty():
		return
	var tile := _ground_tile(world)
	BattleSystem.set_aggro_move(_selection, tile.x, tile.y)
	_show_ground_marker(world, "⚔", Color(1.0, 0.25, 0.2))


## First walkable floor tile adjacent to (x, y); falls back to (x, y).
func _adjacent_floor(x: int, y: int) -> Vector2i:
	for oy in [-1, 0, 1]:
		for ox in [-1, 0, 1]:
			if ox == 0 and oy == 0:
				continue
			var nx: int = x + ox
			var ny: int = y + oy
			if nx < 0 or ny < 0 or nx >= _ms or ny >= _ms:
				continue
			if int(_e._dungeon_map[ny * _ms + nx]) == 1:
				return Vector2i(nx, ny)
	return Vector2i(clampi(x, 0, _ms - 1), clampi(y, 0, _ms - 1))


# ═════════════════════════════════════════════════════════════════════════
# Selection state
# ═════════════════════════════════════════════════════════════════════════

func _set_selection(ids: Array, structure_id: String) -> void:
	_selection = []
	for uid in ids:
		var s := str(uid)
		if s != "" and not _selection.has(s):
			_selection.append(s)
	_sel_structure = structure_id
	_pending_attack_move = _pending_attack_move and not _selection.is_empty()
	_refresh_rings()
	_rebuild_card()


## Drop dead / vanished ids from the live selection each frame.
func _prune_selection() -> void:
	var changed := false
	for uid in _selection.duplicate():
		var ent = _e._dung_find(str(uid))
		if ent == null or bool(ent.get("is_dead", false)):
			_selection.erase(uid)
			changed = true
	if _sel_structure != "":
		var s = _e._dung_find(_sel_structure)
		if s == null or bool(s.get("is_dead", false)):
			_sel_structure = ""
			changed = true
	if changed:
		_refresh_rings()
		_rebuild_card()


## Gold ring on the primary selection / structure, cyan on the rest.
## Delta-only: `_ringed` caches what is currently shown (id → "gold"/"cyan")
## so only nodes whose membership or tint changed are touched.
func _refresh_rings() -> void:
	var primary := str(_selection[0]) if not _selection.is_empty() else _sel_structure
	var next: Dictionary = {}
	for id in _selection:
		next[str(id)] = true
	if _sel_structure != "":
		next[_sel_structure] = true
	# Hide rings that dropped out of the selection.
	for id in _ringed.keys():
		if next.has(id):
			continue
		var p: Dictionary = _parts.get(id, {})
		if not p.is_empty():
			var ring = p["ring"]
			if ring != null and is_instance_valid(ring):
				ring.visible = false
		_ringed.erase(id)
	# Show / retint rings that joined or changed primary status.
	for id in next.keys():
		var want := "gold" if id == primary else "cyan"
		if str(_ringed.get(id, "")) == want:
			continue
		var p: Dictionary = _parts.get(id, {})
		if p.is_empty():
			continue
		var ring = p["ring"]
		if ring == null or not is_instance_valid(ring):
			continue
		ring.material_override = _ring_mat_gold if want == "gold" else _ring_mat_cyan
		ring.visible = true
		_ringed[id] = want


## ⚑ marker at the player's rally point while one of their structures is
## selected.
func _update_rally_marker() -> void:
	if _rally_lbl == null:
		return
	if _sel_structure == "":
		_rally_lbl.visible = false
		return
	var rp: Vector2i = BattleSystem.get_rally(BattleSystem.player_team)
	if rp.x < 0 or rp.y < 0:
		_rally_lbl.visible = false
		return
	_rally_lbl.visible = true
	_rally_lbl.modulate = BattleSystem.get_team_color(BattleSystem.player_team)
	_rally_lbl.position = Vector3(float(rp.x), 0.9, float(rp.y))


# ═════════════════════════════════════════════════════════════════════════
# HUD
# ═════════════════════════════════════════════════════════════════════════

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)

	_build_top_bar()
	_build_command_card()
	_build_minimap()
	_build_log_ticker()
	_build_toast()

	# Drag-select rectangle overlay.
	_drag_rect = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.8, 1.0, 0.12)
	sb.border_color = Color(0.3, 0.9, 1.0, 0.8)
	sb.set_border_width_all(1)
	_drag_rect.add_theme_stylebox_override("panel", sb)
	_drag_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_rect.visible = false
	_hud.add_child(_drag_rect)

	# Leave confirmation.
	_leave_dialog = ConfirmationDialog.new()
	_leave_dialog.dialog_text = "Abandon the battle and return to the title screen?"
	_leave_dialog.ok_button_text = "Leave"
	_leave_dialog.confirmed.connect(_leave_battle)
	_hud.add_child(_leave_dialog)

	# Paused banner — a centered, unmistakable overlay. Orders can still be
	# issued while paused (tactical pause); only the sim clock stops.
	_pause_overlay = Control.new()
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.visible = false
	_hud.add_child(_pause_overlay)
	var pp := PanelContainer.new()
	pp.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pp.position = Vector2(-170.0, 96.0)
	pp.custom_minimum_size = Vector2(340, 0)
	pp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.05, 0.03, 0.10, 0.85)
	psb.border_color = RimvaleColors.GOLD
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(10)
	psb.set_content_margin_all(14)
	pp.add_theme_stylebox_override("panel", psb)
	_pause_overlay.add_child(pp)
	var pv := VBoxContainer.new()
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pp.add_child(pv)
	var pl := RimvaleUtils.label("⏸ PAUSED", 26, RimvaleColors.GOLD)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(pl)
	var ps := RimvaleUtils.label(
		"You can still select units and give orders.\nSpace or ▶ Resume to continue.",
		12, RimvaleColors.TEXT_GRAY)
	ps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(ps)


## Arm superweapon targeting (top-bar ☄ button).
func _arm_strike() -> void:
	var wait: float = BattleSystem.strike_ready_in(BattleSystem.player_team)
	if wait > 0.0:
		_toast_show("☄ Strike ready in %ds." % int(ceil(wait)))
		return
	_pending_strike = true
	_toast_show("☄ Strike armed: left-click the target (Esc cancels)")


## Single pause path for the Space key and the top-bar button.
func _toggle_pause() -> void:
	BattleSystem.paused = not BattleSystem.paused
	_toast_show("⏸ Paused" if BattleSystem.paused else "▶ Resumed")
	if _pause_overlay != null:
		_pause_overlay.visible = BattleSystem.paused
	if _pause_btn != null:
		_pause_btn.text = "▶ Resume" if BattleSystem.paused else "⏸ Pause"


## Mute / unmute all battle audio: gates the SFX helper and stops or restarts
## the looping theme. Local to the battle — does not touch global settings.
func _toggle_mute() -> void:
	_audio_muted = not _audio_muted
	if _audio_muted:
		AudioManager.stop_music()
	else:
		AudioManager.play_music("music_combat")
	if _mute_btn != null:
		_mute_btn.text = "🔇" if _audio_muted else "🔊"
	_toast_show("🔇 Audio muted" if _audio_muted else "🔊 Audio on")


# ── Debug tools (panel gated on GameState.debug_mode at HUD-build time) ───────
## Show/hide the debug panel, building it lazily on first open.
func _toggle_debug_panel() -> void:
	if _debug_panel == null:
		_build_debug_panel()
	_debug_panel.visible = not _debug_panel.visible

func _build_debug_panel() -> void:
	_debug_panel = PanelContainer.new()
	_debug_panel.add_theme_stylebox_override("panel", _panel_style())
	_debug_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_debug_panel.offset_left = 12.0
	_debug_panel.offset_top = 96.0
	_debug_panel.custom_minimum_size = Vector2(230, 0)
	_hud.add_child(_debug_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_debug_panel.add_child(box)

	box.add_child(RimvaleUtils.label("🐞 DEBUG", 15, RimvaleColors.CYAN))

	box.add_child(RimvaleUtils.label("Add supply", 11, RimvaleColors.TEXT_GRAY))
	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 6)
	box.add_child(res_row)
	for amt in [100, 1000, 10000]:
		var rb := RimvaleUtils.button("+%d" % amt, RimvaleColors.GOLD, 30, 12)
		rb.custom_minimum_size = Vector2(66, 30)
		rb.pressed.connect(_debug_add_supply.bind(amt))
		res_row.add_child(rb)

	box.add_child(HSeparator.new())

	var reveal_btn := RimvaleUtils.button("👁 Reveal map", RimvaleColors.PRIMARY, 30, 12)
	reveal_btn.tooltip_text = "Toggle fog of war off / on."
	reveal_btn.pressed.connect(_debug_toggle_reveal)
	box.add_child(reveal_btn)

	var strike_btn := RimvaleUtils.button("☄ Charge strike", RimvaleColors.PRIMARY, 30, 12)
	strike_btn.pressed.connect(_debug_charge_strike)
	box.add_child(strike_btn)

	var kaiju_btn := RimvaleUtils.button("🦖 Spawn kaiju", RimvaleColors.PRIMARY, 30, 12)
	kaiju_btn.pressed.connect(_debug_spawn_kaiju)
	box.add_child(kaiju_btn)

	box.add_child(HSeparator.new())
	box.add_child(RimvaleUtils.label("Spawn building (free)", 11, RimvaleColors.TEXT_GRAY))
	var b_glyphs := {
		"barracks": "🏠", "war_factory": "🏭", "command_post": "🏰",
		"spire": "🔮", "turret": "🗼", "wall": "🧱",
	}
	var b_row1 := HBoxContainer.new()
	b_row1.add_theme_constant_override("separation", 3)
	box.add_child(b_row1)
	var b_row2 := HBoxContainer.new()
	b_row2.add_theme_constant_override("separation", 3)
	box.add_child(b_row2)
	var b_i: int = 0
	for kind in BattleSystem.STRUCTURE_KINDS:
		var kb := RimvaleUtils.button("%s %s" % [
			str(b_glyphs.get(kind, "🏗")),
			str(BattleSystem.STRUCTURE_KINDS[kind]["label"]).left(8)],
			RimvaleColors.PRIMARY, 26, 10)
		kb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kk: String = str(kind)
		kb.pressed.connect(func() -> void: _debug_spawn_structure(kk))
		if b_i < 3:
			b_row1.add_child(kb)
		else:
			b_row2.add_child(kb)
		b_i += 1

	box.add_child(HSeparator.new())

	var wipe_btn := RimvaleUtils.button("💀 Eliminate enemy units", RimvaleColors.ORANGE, 30, 12)
	wipe_btn.tooltip_text = "Kill all enemy units; their structures stay standing."
	wipe_btn.pressed.connect(_debug_eliminate_units)
	box.add_child(wipe_btn)

	var win_btn := RimvaleUtils.button("🏆 Instant win", RimvaleColors.DANGER, 30, 12)
	win_btn.pressed.connect(_debug_instant_win)
	box.add_child(win_btn)

	var god_btn := RimvaleUtils.button("🛡 God mode (selected)", RimvaleColors.PRIMARY, 30, 12)
	god_btn.tooltip_text = "Toggle invincibility on selected units. Heals to full."
	god_btn.pressed.connect(_debug_toggle_invincible)
	box.add_child(god_btn)

	box.add_child(HSeparator.new())

	var close_btn := RimvaleUtils.button("Close", RimvaleColors.TEXT_GRAY, 28, 12)
	close_btn.pressed.connect(func(): _debug_panel.visible = false)
	box.add_child(close_btn)

func _debug_add_supply(amount: int) -> void:
	BattleSystem.debug_add_supply(BattleSystem.player_team, amount)
	_toast_show("🐞 +%d⛃" % amount)

func _debug_charge_strike() -> void:
	BattleSystem.debug_charge_strike(BattleSystem.player_team)
	_toast_show("🐞 Arcane Strike charged.")

func _debug_spawn_kaiju() -> void:
	BattleSystem.debug_spawn_kaiju()
	_toast_show("🐞 Kaiju summoned!")

## Arm free placement: the next click drops the structure on that tile.
func _debug_spawn_structure(kind: String) -> void:
	_pending_attack_move = false
	_pending_strike = false
	_pending_patrol = false
	_pending_wall = false
	_pending_build_kind = ""
	_pending_debug_build = kind
	if _debug_panel != null:
		_debug_panel.visible = false      # get out of the way of the map
	_toast_show("🐞 Place %s: click a tile (Esc cancels)" % str(
		BattleSystem.STRUCTURE_KINDS[kind]["label"]))

## Click handler for debug placement — free, but the tile must be buildable.
func _do_debug_place_structure(mpos: Vector2) -> void:
	var world := _mouse_ground(mpos)
	if not world.is_finite():
		return
	var tile := _ground_tile(world)
	var kind: String = _pending_debug_build
	var err: String = BattleSystem.debug_spawn_structure_at(
		BattleSystem.player_team, kind, tile.x, tile.y)
	if err != "":
		_toast_show(err)          # bad tile — stay armed so the next click retries
		return
	_show_ground_marker(world, "🏗", RimvaleColors.CYAN)
	_pending_debug_build = ""
	_toast_show("🐞 %s built." % str(BattleSystem.STRUCTURE_KINDS[kind]["label"]))

func _debug_eliminate_units() -> void:
	BattleSystem.debug_eliminate_enemy_units()
	_toast_show("🐞 Enemy units eliminated.")

func _debug_instant_win() -> void:
	if _debug_panel != null:
		_debug_panel.visible = false
	BattleSystem.debug_player_win()

func _debug_toggle_invincible() -> void:
	if _selection.is_empty():
		_toast_show("🐞 Select units first.")
		return
	var on: bool = BattleSystem.debug_toggle_invincible(_selection)
	var count: int = _selection.size()
	if on:
		_toast_show("🐞 🛡 %d unit%s now INVINCIBLE." % [count, "" if count == 1 else "s"])
	else:
		_toast_show("🐞 Invincibility removed from %d unit%s." % [count, "" if count == 1 else "s"])

## Toggle a full-map reveal. Reuses the fog engine's _fog_revealed latch: on →
## fill vision/explored and clear the shroud; off → let the 2.5 Hz _update_fog
## recompute normal player vision on its next tick.
func _debug_toggle_reveal() -> void:
	if not _fog_on or _fog_img == null:
		_toast_show("🐞 Fog is already off.")
		return
	_fog_revealed = not _fog_revealed
	if _fog_revealed:
		_vision.fill(1)
		_explored.fill(1)
		_fog_img.fill(Color(0, 0, 0, 0))
		_fog_tex.update(_fog_img)
		_toast_show("🐞 Map revealed.")
	else:
		_update_fog()
		_toast_show("🐞 Fog restored.")


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.12, 0.92)
	sb.border_color = RimvaleColors.DIVIDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	return sb


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _panel_style())
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, 48)
	_hud.add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	bar.add_child(row)

	for key in ["supply", "income", "miners", "teams", "clock", "state"]:
		var col: Color = RimvaleColors.TEXT_WHITE
		if key == "supply":
			col = RimvaleColors.GOLD
		elif key == "income":
			col = RimvaleColors.SUCCESS
		elif key == "state":
			col = RimvaleColors.WARNING
		var lbl := RimvaleUtils.label("", 15, col)
		row.add_child(lbl)
		_top_labels[key] = lbl
		_top_cache[key] = ""

	var spring := Control.new()
	spring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spring)

	var hint := RimvaleUtils.label("Space pause · F speed 1/2/3× · A attack-move · B alert · Ctrl+1-4 squads", 11, RimvaleColors.TEXT_DIM)
	row.add_child(hint)

	_strike_btn = RimvaleUtils.button("☄ 60s", Color(1.0, 0.55, 0.15), 32, 13)
	_strike_btn.custom_minimum_size = Vector2(110, 32)
	_strike_btn.tooltip_text = "Arcane Strike: 6d10 damage in a blast zone.\nHits friend and foe alike — aim carefully."
	_strike_btn.pressed.connect(_arm_strike)
	row.add_child(_strike_btn)

	_pause_btn = RimvaleUtils.button("⏸ Pause", RimvaleColors.GOLD, 32, 13)
	_pause_btn.custom_minimum_size = Vector2(96, 32)
	_pause_btn.pressed.connect(_toggle_pause)
	row.add_child(_pause_btn)

	_mute_btn = RimvaleUtils.button("🔊", RimvaleColors.TEXT_LIGHT, 32, 15)
	_mute_btn.custom_minimum_size = Vector2(44, 32)
	_mute_btn.tooltip_text = "Mute / unmute battle audio."
	_mute_btn.pressed.connect(_toggle_mute)
	row.add_child(_mute_btn)

	# Debug button — only when the global debug flag (profile screen) is on.
	if bool(GameState.debug_mode):
		var dbg := RimvaleUtils.button("🐞", RimvaleColors.CYAN, 32, 15)
		dbg.custom_minimum_size = Vector2(44, 32)
		dbg.tooltip_text = "Debug tools (debug mode is on)."
		dbg.pressed.connect(_toggle_debug_panel)
		row.add_child(dbg)

	var leave := RimvaleUtils.button("✖ Leave", RimvaleColors.DANGER, 32, 13)
	leave.custom_minimum_size = Vector2(96, 32)
	leave.pressed.connect(func(): _leave_dialog.popup_centered())
	row.add_child(leave)


func _build_command_card() -> void:
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", _panel_style())
	_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_card.offset_top = -164.0
	_card.custom_minimum_size = Vector2(0, 160)
	_card.visible = false
	_hud.add_child(_card)

	_card_box = HBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 14)
	_card.add_child(_card_box)


func _build_minimap() -> void:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _panel_style())
	frame.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	frame.offset_left = -204.0
	frame.offset_top = -374.0
	frame.offset_right = -8.0
	frame.offset_bottom = -178.0
	_hud.add_child(frame)

	_minimap = TextureRect.new()
	_minimap.custom_minimum_size = Vector2(180, 180)
	_minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_minimap.stretch_mode = TextureRect.STRETCH_SCALE
	_minimap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	_minimap.gui_input.connect(_on_minimap_input)
	frame.add_child(_minimap)


func _build_log_ticker() -> void:
	_log_box = VBoxContainer.new()
	_log_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_log_box.offset_left = 12.0
	_log_box.offset_top = -286.0
	_log_box.offset_right = 560.0
	_log_box.offset_bottom = -172.0
	_log_box.alignment = BoxContainer.ALIGNMENT_END
	_log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_log_box)


func _build_toast() -> void:
	_toast_lbl = RimvaleUtils.label("", 15, RimvaleColors.TEXT_WHITE)
	_toast_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_lbl.offset_top = -200.0
	_toast_lbl.offset_bottom = -176.0
	_toast_lbl.offset_left = -300.0
	_toast_lbl.offset_right = 300.0
	_toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_lbl.visible = false
	_hud.add_child(_toast_lbl)


func _toast_show(text: String) -> void:
	_toast_lbl.text = text
	_toast_lbl.modulate.a = 1.0
	_toast_lbl.visible = true
	_toast_t = 2.2


func _update_toast(delta: float) -> void:
	if not _toast_lbl.visible:
		return
	_toast_t -= delta
	if _toast_t <= 0.0:
		_toast_lbl.visible = false
	elif _toast_t < 0.6:
		_toast_lbl.modulate.a = _toast_t / 0.6


# ── Log ticker ───────────────────────────────────────────────────────────

func _drain_battle_log() -> void:
	# Mass battles can generate dozens of hit lines per frame — cap the
	# per-frame work and drop the oldest backlog (the ticker only shows the
	# newest few lines anyway).
	var backlog: int = BattleSystem.battle_log_extra.size()
	if backlog > 40:
		for _i in range(backlog - 20):
			BattleSystem.battle_log_extra.pop_front()
	var drained: int = 0
	while not BattleSystem.battle_log_extra.is_empty() and drained < 6:
		var line = BattleSystem.battle_log_extra.pop_front()
		_add_log(str(line))
		drained += 1


func _add_log(text: String) -> void:
	# Battle log lines may carry BBCode — strip tags for the plain ticker.
	var clean := _bb_re.sub(text, "", true).strip_edges()
	if clean == "":
		return
	var lbl := RimvaleUtils.label(clean, 12, RimvaleColors.TEXT_LIGHT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_box.add_child(lbl)
	_log_items.append({"lbl": lbl, "t": 7.0})
	while _log_items.size() > 4:
		var old: Dictionary = _log_items.pop_front()
		if is_instance_valid(old["lbl"]):
			old["lbl"].queue_free()


func _update_log_fade(delta: float) -> void:
	for i in range(_log_items.size() - 1, -1, -1):
		var item: Dictionary = _log_items[i]
		item["t"] = float(item["t"]) - delta
		var lbl = item["lbl"]
		if not is_instance_valid(lbl):
			_log_items.remove_at(i)
			continue
		if float(item["t"]) <= 0.0:
			lbl.queue_free()
			_log_items.remove_at(i)
		elif float(item["t"]) < 2.0:
			lbl.modulate.a = float(item["t"]) / 2.0


# ── Top bar + card refresh (4 Hz) ────────────────────────────────────────

func _on_hud_tick() -> void:
	if _e == null:
		return
	var pt: int = BattleSystem.player_team
	var secs := int(BattleSystem.get_battle_time())
	var state := ""
	if BattleSystem.paused:
		state = "⏸ PAUSED"
	elif BattleSystem.time_scale > 1.0:
		state = "⏩ x%.0f" % BattleSystem.time_scale
	# Superweapon button label (change-gated: Label re-text is not free).
	if _strike_btn != null:
		var wait: float = BattleSystem.strike_ready_in(pt)
		var stxt: String = "☄ STRIKE" if wait <= 0.0 else "☄ %ds" % int(ceil(wait))
		if stxt != _strike_txt:
			_strike_txt = stxt
			_strike_btn.text = stxt
	_set_top("supply", "⛃ %d" % BattleSystem.get_supply(pt))
	_set_top("income", "+%d" % BattleSystem.get_last_income(pt))
	_set_top("miners", "⛏ %d" % BattleSystem.get_miner_count(pt))
	_set_top("teams", "Teams alive: %d" % BattleSystem.teams_alive_count())
	_set_top("clock", "%02d:%02d" % [int(float(secs) / 60.0), secs % 60])
	_set_top("state", state)

	_refresh_card_dynamic()

	# Belt-and-braces: catch battle end even if the "over" event fired
	# before this scene connected.
	if BattleSystem.finished and not _over_shown:
		_show_over(BattleSystem.winner)


func _set_top(key: String, text: String) -> void:
	if str(_top_cache.get(key, "")) == text:
		return
	_top_cache[key] = text
	var lbl = _top_labels.get(key, null)
	if lbl != null:
		lbl.text = text


# ═════════════════════════════════════════════════════════════════════════
# Command card (bottom panel)
# ═════════════════════════════════════════════════════════════════════════

func _rebuild_card() -> void:
	if _card == null:
		return
	for c in _card_box.get_children():
		c.queue_free()
	_chip_labels = []
	_chip_ids = []
	_detail_rt = null
	_queue_box = null
	_prod_grid = null
	_prod_count = -1
	_card_sig = -1
	_queue_sig = ""
	_queue_pbs = []

	if _sel_structure != "":
		_build_structure_card()
	elif not _selection.is_empty():
		_build_unit_card()
	_card.visible = _sel_structure != "" or not _selection.is_empty()


## 4 Hz in-place refresh of dynamic card content (no widget churn under
## the mouse — buttons persist, only labels / queue bars update).
func _refresh_card_dynamic() -> void:
	if _card == null or not _card.visible:
		return
	# Selection chips: cheap fingerprint (id hashes + hp values) — the whole
	# label pass is skipped while nothing changed.
	var sig := 0
	for uid_v in _chip_ids:
		var uid := str(uid_v)
		sig += int(uid.hash() & 0xFFFFFF)
		var ent = _e._dung_find(uid)
		if ent != null:
			sig += int(ent.get("hp", 0)) * 131 + int(ent.get("max_hp", 0)) * 17
	if sig != _card_sig:
		_card_sig = sig
		for i in range(_chip_ids.size()):
			if i >= _chip_labels.size():
				break
			var lbl = _chip_labels[i]
			if not is_instance_valid(lbl):
				continue
			var txt := _chip_text(str(_chip_ids[i]))
			if lbl.text != txt:
				lbl.text = txt
	# Single-unit detail (class / gear / spell cooldowns) — only reassign
	# when the rendered string actually changed.
	if _detail_rt != null and is_instance_valid(_detail_rt) and _selection.size() == 1:
		var dtxt := _detail_text(str(_selection[0]))
		if _detail_rt.text != dtxt:
			_detail_rt.text = dtxt
	# Structure card: queue bars + production grid growth (War Factory).
	if _sel_structure != "":
		if _queue_box != null and is_instance_valid(_queue_box):
			_fill_queue_box()
		if _prod_grid != null and is_instance_valid(_prod_grid):
			var cat: Array = BattleSystem.get_unit_catalog(BattleSystem.player_team)
			if cat.size() != _prod_count:
				_fill_prod_grid(cat)


func _chip_text(uid: String) -> String:
	var ent = _e._dung_find(uid)
	if ent == null:
		return "—"
	return "%s  %d/%d" % [str(ent.get("name", "?")), int(ent.get("hp", 0)), int(ent.get("max_hp", 0))]


func _detail_text(uid: String) -> String:
	var ent = _e._dung_find(uid)
	if ent == null:
		return ""
	var lines: Array = []
	var cls := str(ent.get("npc_class", ""))
	if cls != "":
		lines.append("[color=#ce93d8]%s[/color]" % cls)
	lines.append("🗡 %s   🛡 %s (AC %d)" % [
		str(ent.get("equipped_weapon", "None")),
		str(ent.get("equipped_armor", "None")),
		int(ent.get("ac", 10))])
	var spells: Array = BattleSystem.get_unit_spells(uid)
	for s_v in spells:
		var s: Dictionary = s_v
		var cd := int(s.get("cd_left", 0))
		if cd > 0:
			lines.append("[color=#8899aa]✦ %s %ds[/color]" % [str(s.get("name", "?")), cd])
		else:
			lines.append("[color=#66ff88]✦ %s ready[/color]" % str(s.get("name", "?")))
	return "\n".join(lines)


func _build_unit_card() -> void:
	# LEFT: selection chips + single-unit detail.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(420, 0)
	left.add_theme_constant_override("separation", 4)
	_card_box.add_child(left)

	var head := RimvaleUtils.label("%d unit%s selected" % [_selection.size(), "" if _selection.size() == 1 else "s"], 13, RimvaleColors.ACCENT)
	left.add_child(head)

	var chips := GridContainer.new()
	chips.columns = 2
	chips.add_theme_constant_override("h_separation", 14)
	left.add_child(chips)
	var shown := mini(_selection.size(), 8)
	for i in range(shown):
		var uid := str(_selection[i])
		var lbl := RimvaleUtils.label(_chip_text(uid), 12, RimvaleColors.TEXT_LIGHT)
		chips.add_child(lbl)
		_chip_labels.append(lbl)
		_chip_ids.append(uid)
	if _selection.size() > 8:
		left.add_child(RimvaleUtils.label("… +%d more" % (_selection.size() - 8), 11, RimvaleColors.TEXT_DIM))

	if _selection.size() == 1:
		_detail_rt = RichTextLabel.new()
		_detail_rt.bbcode_enabled = true
		_detail_rt.fit_content = true
		_detail_rt.scroll_active = false
		_detail_rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_detail_rt.add_theme_font_size_override("normal_font_size", 12)
		_detail_rt.text = _detail_text(str(_selection[0]))
		left.add_child(_detail_rt)

	_card_box.add_child(VSeparator.new())

	# RIGHT: unit actions (apply to every selected unit).
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	_card_box.add_child(right)

	right.add_child(RimvaleUtils.label("ARMORY (needs Barracks)", 11, RimvaleColors.TEXT_GRAY))

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	right.add_child(row1)
	var up_w := RimvaleUtils.button("⬆ Weapon", RimvaleColors.PRIMARY, 30, 12)
	up_w.pressed.connect(func(): _apply_upgrade("weapon"))
	row1.add_child(up_w)
	var up_a := RimvaleUtils.button("⬆ Armor", RimvaleColors.PRIMARY, 30, 12)
	up_a.pressed.connect(func(): _apply_upgrade("armor"))
	row1.add_child(up_a)
	var up_v := RimvaleUtils.button("★ Veteran", RimvaleColors.GOLD, 30, 12)
	up_v.pressed.connect(func(): _apply_upgrade("veteran"))
	row1.add_child(up_v)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	right.add_child(row2)
	var class_ob := OptionButton.new()
	class_ob.custom_minimum_size = Vector2(170, 30)
	class_ob.add_theme_font_size_override("font_size", 12)
	class_ob.add_item("— class —")
	for cls in EnemyArchetype.class_names():
		class_ob.add_item(str(cls))
	class_ob.item_selected.connect(func(idx: int): _apply_class(idx, class_ob))
	row2.add_child(class_ob)
	var sp_btn := RimvaleUtils.button("✦ Spells", RimvaleColors.SP_PURPLE, 30, 12)
	sp_btn.pressed.connect(_open_spell_popup)
	row2.add_child(sp_btn)

	# Duty row: mining mode + stances.
	var row_duty := HBoxContainer.new()
	row_duty.add_theme_constant_override("separation", 6)
	right.add_child(row_duty)
	var mine_b := RimvaleUtils.button("⛏ Mine", Color(0.25, 0.9, 0.85), 28, 11)
	mine_b.tooltip_text = "Mining mode: each unit finds its own nearest vein and gets to work (auto-relocates when veins run dry)."
	mine_b.pressed.connect(func():
		var nm: int = BattleSystem.order_group_mine_auto(_selection)
		_toast_show("⛏ %d unit%s mining" % [nm, "s" if nm != 1 else ""] if nm > 0 else "No live veins found."))
	row_duty.add_child(mine_b)
	var guard_b := RimvaleUtils.button("🛡 Guard", RimvaleColors.PRIMARY, 28, 11)
	guard_b.tooltip_text = "Hold this position: fight what comes close, never chase far, return to post after."
	guard_b.pressed.connect(func():
		var ng: int = BattleSystem.set_stance(_selection, "guard")
		_toast_show("🛡 Guarding ×%d" % ng if ng > 0 else "Nothing to set."))
	row_duty.add_child(guard_b)
	var pat_b := RimvaleUtils.button("🔁 Patrol", RimvaleColors.PRIMARY, 28, 11)
	pat_b.tooltip_text = "Loop between here and a point you click, engaging anything sighted."
	pat_b.pressed.connect(func():
		if not _selection.is_empty():
			_pending_patrol = true
			_toast_show("🔁 Patrol: left-click the far point (Esc cancels)"))
	row_duty.add_child(pat_b)
	var stop_b := RimvaleUtils.button("✋ Stop", RimvaleColors.TEXT_GRAY, 28, 11)
	stop_b.tooltip_text = "Clear all orders, duties and stances."
	stop_b.pressed.connect(func():
		for uid in _selection:
			BattleSystem.clear_orders(str(uid))
		BattleSystem.set_stance(_selection, "off")
		_toast_show("✋ Holding."))
	row_duty.add_child(stop_b)

	# Attack mode: how the selection fights when ordered onto an enemy.
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 6)
	right.add_child(row3)
	row3.add_child(RimvaleUtils.label("Fight with:", 11, RimvaleColors.TEXT_GRAY))
	for m in [["auto", "🔄 Auto", "Weapons + spells together (default)."],
			["weapons", "⚔ Weapons", "Offensive spells sheathed — heals and blessings still cast."],
			["magic", "✦ Magic", "Weapon sheathed; holds at spell range and fights with offensive magic (needs an offensive spell equipped)."]]:
		var mid: String = str(m[0])
		var mb := RimvaleUtils.button(str(m[1]), RimvaleColors.PRIMARY, 28, 11)
		mb.tooltip_text = str(m[2])
		mb.pressed.connect(func(): _apply_attack_mode(mid))
		row3.add_child(mb)


func _apply_attack_mode(mode: String) -> void:
	var n: int = BattleSystem.set_attack_mode(_selection, mode)
	if n > 0:
		var label: String = {"auto": "🔄 Auto", "weapons": "⚔ Weapons only",
			"magic": "✦ Magic only"}.get(mode, mode)
		_toast_show("%s ×%d" % [label, n])
	else:
		_toast_show("No units accepted that mode.")


func _apply_upgrade(kind: String) -> void:
	var err := ""
	var ok := 0
	for uid in _selection:
		var r: String = BattleSystem.upgrade_unit(str(uid), kind)
		if r == "":
			ok += 1
		elif err == "":
			err = r
	if ok > 0:
		_toast_show("⬆ %s upgraded ×%d" % [kind.capitalize(), ok])
		_refresh_card_dynamic()
	elif err != "":
		_toast_show(err)


func _apply_class(idx: int, ob: OptionButton) -> void:
	if idx <= 0:
		return
	var cls := ob.get_item_text(idx)
	var err := ""
	var ok := 0
	for uid in _selection:
		var r: String = BattleSystem.set_unit_class(str(uid), cls)
		if r == "":
			ok += 1
		elif err == "":
			err = r
	if ok > 0:
		_toast_show("Class set: %s ×%d" % [cls, ok])
		_refresh_card_dynamic()
	elif err != "":
		_toast_show(err)
	ob.select(0)


# ── Structure card (production) ──────────────────────────────────────────

func _build_structure_card() -> void:
	var ent = _e._dung_find(_sel_structure)
	var is_base := ent != null and bool(ent.get("is_battle_base", false))
	var skind := str(ent.get("structure_kind", "")) if ent != null else ""
	# Only the Command Post / Barracks / War Factory run build queues.
	var is_producer := is_base or skind == "barracks" or skind == "war_factory"

	# LEFT: structure info + queue + hint.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(280, 0)
	left.add_theme_constant_override("separation", 4)
	_card_box.add_child(left)

	var title := "Structure"
	if ent != null:
		title = "%s  %d/%d" % [str(ent.get("name", "?")), int(ent.get("hp", 0)), int(ent.get("max_hp", 0))]
	var t_lbl := RimvaleUtils.label(title, 13, RimvaleColors.ACCENT)
	left.add_child(t_lbl)
	_chip_labels.append(t_lbl)
	_chip_ids.append(_sel_structure)
	# Chip refresh writes plain chip text; wrap via lambda-free approach:
	# structure title uses the same "name hp/max" format, good enough.

	if is_producer:
		left.add_child(RimvaleUtils.label("BUILD QUEUE (this structure)", 11, RimvaleColors.TEXT_GRAY))
		_queue_box = VBoxContainer.new()
		_queue_box.add_theme_constant_override("separation", 2)
		left.add_child(_queue_box)
		_fill_queue_box()

	left.add_child(RimvaleUtils.label("Right-click ground to set rally ⚑", 11, RimvaleColors.TEXT_DIM))

	if is_producer:
		_card_box.add_child(VSeparator.new())

		# MID: this structure's own production line.
		var mid := VBoxContainer.new()
		mid.add_theme_constant_override("separation", 4)
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_card_box.add_child(mid)
		mid.add_child(RimvaleUtils.label("PRODUCTION", 11, RimvaleColors.TEXT_GRAY))
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		mid.add_child(scroll)
		_prod_grid = GridContainer.new()
		_prod_grid.columns = 4
		_prod_grid.add_theme_constant_override("h_separation", 6)
		_prod_grid.add_theme_constant_override("v_separation", 4)
		scroll.add_child(_prod_grid)
		_fill_prod_grid(BattleSystem.get_unit_catalog(BattleSystem.player_team))

	# RIGHT: base-only structure construction.
	if is_base:
		_card_box.add_child(VSeparator.new())
		var right := VBoxContainer.new()
		right.add_theme_constant_override("separation", 6)
		_card_box.add_child(right)
		right.add_child(RimvaleUtils.label("CONSTRUCT", 11, RimvaleColors.TEXT_GRAY))
		for row in BUILD_KINDS:
			var kind := str(row[0])
			var icon := str(row[1])
			var cfg: Dictionary = BattleSystem.STRUCTURE_KINDS.get(kind, {})
			var label := str(cfg.get("label", kind.capitalize()))
			var cost := int(cfg.get("cost", int(row[2])))
			var b := RimvaleUtils.button("%s %s (%d⛃)" % [icon, label, cost], RimvaleColors.ORANGE, 28, 12)
			b.tooltip_text = "Click to enter placement mode, then click a tile to build. Esc cancels."
			b.pressed.connect(func(): _enter_build_placement(kind, icon, label))
			right.add_child(b)
		# Walls are placed by hand — arm placement mode instead.
		var wall_cost := int(BattleSystem.STRUCTURE_KINDS.get("wall", {}).get("cost", 15))
		var wall_b := RimvaleUtils.button("🧱 Wall (%d⛃)" % wall_cost, RimvaleColors.ORANGE, 28, 12)
		wall_b.tooltip_text = "Click tiles to place wall segments; Esc to finish. Walls block movement."
		wall_b.pressed.connect(func():
			_pending_wall = true
			_toast_show("🧱 Wall placement: click tiles (Esc to finish)"))
		right.add_child(wall_b)


## Enter placement mode — the next left-click on a tile will build the
## structure there. Pre-checks supply so the player isn't left clicking
## around only to learn they can't afford it.
func _enter_build_placement(kind: String, icon: String, label: String) -> void:
	# Quick supply gate so the player finds out NOW, not after picking a tile.
	var cost: int = int(BattleSystem.STRUCTURE_KINDS.get(kind, {}).get("cost", 0))
	if int(BattleSystem.supply[BattleSystem.player_team]) < cost:
		_toast_show("Need %d supply." % cost)
		return
	# Cancel any other pending mode first.
	_pending_attack_move = false
	_pending_strike = false
	_pending_patrol = false
	_pending_wall = false
	_pending_build_kind = kind
	_toast_show("%s Place %s: click a tile (Esc cancels)" % [icon, label])


## Click handler for structure placement — mirrors _do_place_wall().
func _do_place_structure(mpos: Vector2) -> void:
	var world := _mouse_ground(mpos)
	if not world.is_finite():
		return
	var tile := _ground_tile(world)
	var kind: String = _pending_build_kind
	var err: String = BattleSystem.build_structure_at(
		BattleSystem.player_team, kind, tile.x, tile.y)
	if err != "":
		_toast_show(err)
		# Out of supply or at limit — exit placement mode.
		if err.begins_with("Need") or err.contains("limit") or err.contains("already"):
			_pending_build_kind = ""
		return
	var icon: String = ""
	for row in BUILD_KINDS:
		if str(row[0]) == kind:
			icon = str(row[1])
			break
	_show_ground_marker(world, icon if icon != "" else "🏗", RimvaleColors.ORANGE)
	# Single placement — exit placement mode after building.
	_pending_build_kind = ""
	_toast_show("🏗 %s placed!" % kind.capitalize())


func _fill_prod_grid(cat: Array) -> void:
	_prod_count = cat.size()
	for c in _prod_grid.get_children():
		c.queue_free()
	for entry_v in cat:
		var entry: Dictionary = entry_v
		var key := str(entry.get("key", ""))
		var label := str(entry.get("label", entry.get("name", key)))
		var cost := int(entry.get("cost", 0))
		var b := RimvaleUtils.button("%s (%d⛃)" % [label, cost], RimvaleColors.PRIMARY, 26, 11)
		b.custom_minimum_size = Vector2(150, 26)
		b.clip_text = true
		b.pressed.connect(func(): _do_queue_production(key))
		_prod_grid.add_child(b)


func _do_queue_production(key: String) -> void:
	# Production goes to the SELECTED structure's own queue — extra
	# Barracks / War Factories mean parallel build lines.
	var err: String = BattleSystem.queue_production(
		BattleSystem.player_team, key, _sel_structure)
	if err != "":
		_toast_show(err)
	else:
		_fill_queue_box()


func _fill_queue_box() -> void:
	if _queue_box == null or not is_instance_valid(_queue_box):
		return
	var q: Array = BattleSystem.get_build_queue(BattleSystem.player_team, _sel_structure)
	var shown := mini(q.size(), 4)
	# Composition fingerprint: while the same items sit in the queue, only
	# nudge the existing progress bars — no child churn at 4 Hz.
	var sig := "%d" % q.size()
	for i in range(shown):
		var item: Dictionary = q[i]
		sig += "|" + str(item.get("name", item.get("key", "?")))
	if sig == _queue_sig and _queue_pbs.size() == shown:
		for i in range(shown):
			var item: Dictionary = q[i]
			var pb = _queue_pbs[i]
			if is_instance_valid(pb):
				var total := maxf(0.01, float(item.get("total", 1.0)))
				pb.value = clampf(1.0 - float(item.get("t_left", 0.0)) / total, 0.0, 1.0)
		return
	_queue_sig = sig
	_queue_pbs = []
	for c in _queue_box.get_children():
		c.queue_free()
	if q.is_empty():
		_queue_box.add_child(RimvaleUtils.label("(idle)", 11, RimvaleColors.TEXT_DIM))
		return
	for i in range(shown):
		var item: Dictionary = q[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_lbl := RimvaleUtils.label(str(item.get("name", item.get("key", "?"))), 11, RimvaleColors.TEXT_LIGHT)
		name_lbl.custom_minimum_size = Vector2(120, 0)
		name_lbl.clip_text = true
		row.add_child(name_lbl)
		var pb := ProgressBar.new()
		pb.min_value = 0.0
		pb.max_value = 1.0
		var total := maxf(0.01, float(item.get("total", 1.0)))
		pb.value = clampf(1.0 - float(item.get("t_left", 0.0)) / total, 0.0, 1.0)
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(120, 12)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(pb)
		_queue_box.add_child(row)
		_queue_pbs.append(pb)
	if q.size() > shown:
		_queue_box.add_child(RimvaleUtils.label("… +%d queued" % (q.size() - shown), 10, RimvaleColors.TEXT_DIM))


# ── Spell loadout popup ──────────────────────────────────────────────────

func _open_spell_popup() -> void:
	if _selection.is_empty():
		return
	if _spell_popup != null and is_instance_valid(_spell_popup):
		_spell_popup.queue_free()
	_spell_popup = PanelContainer.new()
	_spell_popup.add_theme_stylebox_override("panel", _panel_style())
	_spell_popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_spell_popup.custom_minimum_size = Vector2(420, 0)
	_hud.add_child(_spell_popup)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_spell_popup.add_child(box)
	box.add_child(RimvaleUtils.label("✦ BATTLE SPELLS — pick up to 2 (needs Arcane Spire)", 13, RimvaleColors.SP_PURPLE))

	# Pre-check the current loadout when a single unit is selected.
	var current: Array = []
	if _selection.size() == 1:
		for s in BattleSystem.get_unit_spells(str(_selection[0])):
			if s is Dictionary:
				current.append(str(s.get("name", "")))

	_spell_checks = []
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for sp_v in BattleSystem.get_battle_spell_catalog():
		var sp: Dictionary = sp_v
		var sname := str(sp.get("name", "?"))
		var cb := CheckBox.new()
		# Battle casters pay in HP and then wait out a cooldown.
		if int(sp.get("hp_cost", 0)) > 0:
			cb.text = "%s  (🩸%d HP · ⏱%.1fs) — %s" % [sname,
				int(sp.get("hp_cost", 0)), float(sp.get("cd", 0.0)), str(sp.get("desc", ""))]
		else:
			cb.text = "%s  (aura) — %s" % [sname, str(sp.get("desc", ""))]
		cb.add_theme_font_size_override("font_size", 12)
		cb.set_meta("spell_name", sname)
		cb.button_pressed = current.has(sname)
		cb.toggled.connect(func(on: bool): _on_spell_check(on, cb))
		list.add_child(cb)
		_spell_checks.append(cb)

	box.add_child(HSeparator.new())
	var create_btn := RimvaleUtils.button("✦ Create Custom Spell", RimvaleColors.SP_PURPLE, 32, 13)
	create_btn.tooltip_text = "Design an always-on aura spell (requires Arcane Spire + supply)."
	if not BattleSystem._team_has_structure(BattleSystem.player_team, "spire"):
		create_btn.disabled = true
		create_btn.tooltip_text = "Requires an Arcane Spire."
	create_btn.pressed.connect(_open_spell_builder)
	box.add_child(create_btn)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(btn_row)
	var apply := RimvaleUtils.button("Apply", RimvaleColors.SUCCESS, 32, 13)
	apply.custom_minimum_size = Vector2(120, 32)
	apply.pressed.connect(_apply_spells)
	btn_row.add_child(apply)
	var cancel := RimvaleUtils.button("Cancel", RimvaleColors.TEXT_GRAY, 32, 13)
	cancel.custom_minimum_size = Vector2(120, 32)
	cancel.pressed.connect(func(): _spell_popup.visible = false)
	btn_row.add_child(cancel)


## Hard cap: never more than 2 boxes checked.
func _on_spell_check(on: bool, cb: CheckBox) -> void:
	if not on:
		return
	var n := 0
	for c in _spell_checks:
		if is_instance_valid(c) and c.button_pressed:
			n += 1
	if n > 2:
		cb.set_pressed_no_signal(false)
		_toast_show("Max 2 spells per unit.")


func _apply_spells() -> void:
	var names: Array = []
	for c in _spell_checks:
		if is_instance_valid(c) and c.button_pressed:
			names.append(str(c.get_meta("spell_name")))
	var err := ""
	var ok := 0
	for uid in _selection:
		var r: String = BattleSystem.set_unit_spells(str(uid), names)
		if r == "":
			ok += 1
		elif err == "":
			err = r
	if ok > 0:
		_toast_show("✦ Spells set for %d unit%s" % [ok, "" if ok == 1 else "s"])
	elif err != "":
		_toast_show(err)
	if _spell_popup != null and is_instance_valid(_spell_popup):
		_spell_popup.visible = false


# ── Custom spell builder ────────────────────────────────────────────────

func _open_spell_builder() -> void:
	if _spell_builder != null and is_instance_valid(_spell_builder):
		_spell_builder.queue_free()
	_spell_builder = PanelContainer.new()
	_spell_builder.add_theme_stylebox_override("panel", _panel_style())
	_spell_builder.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_spell_builder.custom_minimum_size = Vector2(420, 0)
	_hud.add_child(_spell_builder)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_spell_builder.add_child(box)

	box.add_child(RimvaleUtils.label("✦ CUSTOM SPELL BUILDER", 16, RimvaleColors.SP_PURPLE))
	box.add_child(RimvaleUtils.label("Design an always-on aura spell.", 11, RimvaleColors.TEXT_GRAY))

	# ── Name ──
	box.add_child(RimvaleUtils.label("Spell Name", 12, RimvaleColors.ACCENT))
	_sb_name = LineEdit.new()
	_sb_name.placeholder_text = "e.g. Flame Shroud"
	_sb_name.max_length = 24
	_sb_name.add_theme_font_size_override("font_size", 13)
	box.add_child(_sb_name)

	# ── Kind ──
	box.add_child(RimvaleUtils.label("Aura Type", 12, RimvaleColors.ACCENT))
	var kind_row := HBoxContainer.new()
	kind_row.add_theme_constant_override("separation", 6)
	box.add_child(kind_row)
	var kinds := [["damage", "🔥 Damage"], ["heal", "💚 Heal"], ["buff", "🛡 Buff"], ["debuff", "💀 Debuff"]]
	for k in kinds:
		var kb := Button.new()
		kb.text = str(k[1])
		kb.custom_minimum_size = Vector2(95, 32)
		kb.add_theme_font_size_override("font_size", 12)
		kb.pressed.connect(_sb_select_kind.bind(str(k[0])))
		kind_row.add_child(kb)

	# ── Dice count ──
	var dc_row := HBoxContainer.new()
	dc_row.add_theme_constant_override("separation", 8)
	box.add_child(dc_row)
	dc_row.add_child(RimvaleUtils.label("Dice Count", 12, RimvaleColors.TEXT_WHITE))
	var dc_lbl := Label.new()
	dc_lbl.text = "1"
	dc_lbl.add_theme_font_size_override("font_size", 12)
	dc_lbl.add_theme_color_override("font_color", RimvaleColors.GOLD)
	dc_row.add_child(dc_lbl)
	var dc_slider := HSlider.new()
	dc_slider.min_value = 1; dc_slider.max_value = 4; dc_slider.step = 1; dc_slider.value = 1
	dc_slider.custom_minimum_size = Vector2(120, 0)
	dc_slider.value_changed.connect(func(v: float):
		_sb_dc = int(v); dc_lbl.text = str(int(v)); _sb_update_cost())
	dc_row.add_child(dc_slider)

	# ── Dice sides ──
	var ds_row := HBoxContainer.new()
	ds_row.add_theme_constant_override("separation", 8)
	box.add_child(ds_row)
	ds_row.add_child(RimvaleUtils.label("Dice Sides", 12, RimvaleColors.TEXT_WHITE))
	var ds_lbl := Label.new()
	ds_lbl.text = "d6"
	ds_lbl.add_theme_font_size_override("font_size", 12)
	ds_lbl.add_theme_color_override("font_color", RimvaleColors.GOLD)
	ds_row.add_child(ds_lbl)
	var ds_slider := HSlider.new()
	ds_slider.min_value = 4; ds_slider.max_value = 12; ds_slider.step = 2; ds_slider.value = 6
	ds_slider.custom_minimum_size = Vector2(120, 0)
	ds_slider.value_changed.connect(func(v: float):
		_sb_ds = int(v); ds_lbl.text = "d%d" % int(v); _sb_update_cost())
	ds_row.add_child(ds_slider)

	# ── Area radius ──
	var area_row := HBoxContainer.new()
	area_row.add_theme_constant_override("separation", 8)
	box.add_child(area_row)
	area_row.add_child(RimvaleUtils.label("Aura Radius", 12, RimvaleColors.TEXT_WHITE))
	var area_lbl := Label.new()
	area_lbl.text = "2 tiles"
	area_lbl.add_theme_font_size_override("font_size", 12)
	area_lbl.add_theme_color_override("font_color", RimvaleColors.GOLD)
	area_row.add_child(area_lbl)
	var area_slider := HSlider.new()
	area_slider.min_value = 1; area_slider.max_value = 4; area_slider.step = 1; area_slider.value = 2
	area_slider.custom_minimum_size = Vector2(120, 0)
	area_slider.value_changed.connect(func(v: float):
		_sb_area = int(v); area_lbl.text = "%d tiles" % int(v); _sb_update_cost())
	area_row.add_child(area_slider)

	# ── Conditions (for buff/debuff) ──
	_sb_cond_box = VBoxContainer.new()
	_sb_cond_box.add_theme_constant_override("separation", 2)
	box.add_child(_sb_cond_box)
	_sb_cond_box.add_child(RimvaleUtils.label("Conditions (buff/debuff only)", 11, RimvaleColors.TEXT_GRAY))
	_sb_cond_checks = []
	var buff_conds := ["dodging", "resistant", "hidden", "haste"]
	var debuff_conds := ["bleeding", "slowed", "stunned", "frightened", "vulnerable"]
	var all_conds := buff_conds + debuff_conds
	var cond_grid := GridContainer.new()
	cond_grid.columns = 3
	cond_grid.add_theme_constant_override("h_separation", 8)
	_sb_cond_box.add_child(cond_grid)
	for cond in all_conds:
		var cb := CheckBox.new()
		cb.text = cond.capitalize()
		cb.add_theme_font_size_override("font_size", 11)
		cb.toggled.connect(func(_on: bool): _sb_update_cost())
		cond_grid.add_child(cb)
		cb.set_meta("cond_name", cond)
		_sb_cond_checks.append(cb)
	_sb_cond_box.visible = false   # hidden until buff/debuff selected

	box.add_child(HSeparator.new())

	# ── Cost preview ──
	_sb_cost_lbl = RimvaleUtils.label("Cost: 100⛃", 14, RimvaleColors.GOLD)
	box.add_child(_sb_cost_lbl)
	_sb_update_cost()

	# ── Buttons ──
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	box.add_child(btn_row)
	var create_btn := RimvaleUtils.button("✦ Create", RimvaleColors.SP_PURPLE, 34, 14)
	create_btn.custom_minimum_size = Vector2(140, 34)
	create_btn.pressed.connect(_sb_create)
	btn_row.add_child(create_btn)
	var cancel_btn := RimvaleUtils.button("Cancel", RimvaleColors.TEXT_GRAY, 34, 13)
	cancel_btn.pressed.connect(func():
		if _spell_builder != null and is_instance_valid(_spell_builder):
			_spell_builder.queue_free())
	btn_row.add_child(cancel_btn)

	_sb_kind = "damage"
	_sb_dc = 1
	_sb_ds = 6
	_sb_area = 2

func _sb_select_kind(kind: String) -> void:
	_sb_kind = kind
	if _sb_cond_box != null:
		_sb_cond_box.visible = (kind == "buff" or kind == "debuff")
	_sb_update_cost()

func _sb_update_cost() -> void:
	var num_conds: int = 0
	for cb in _sb_cond_checks:
		if is_instance_valid(cb) and cb.button_pressed:
			num_conds += 1
	var cost: int = BattleSystem.custom_spell_cost(_sb_dc, _sb_ds, _sb_area, num_conds)
	if _sb_cost_lbl != null and is_instance_valid(_sb_cost_lbl):
		_sb_cost_lbl.text = "Cost: %d⛃   |   %dd%d  •  radius %d" % [cost, _sb_dc, _sb_ds, _sb_area]

func _sb_create() -> void:
	if _sb_name == null or _sb_name.text.strip_edges() == "":
		_toast_show("Enter a spell name.")
		return
	var conds: Array = []
	if _sb_kind == "buff" or _sb_kind == "debuff":
		for cb in _sb_cond_checks:
			if is_instance_valid(cb) and cb.button_pressed:
				conds.append(str(cb.get_meta("cond_name")))
		if conds.is_empty():
			_toast_show("Pick at least one condition.")
			return
	var err: String = BattleSystem.create_custom_spell(
		_sb_name.text.strip_edges(), _sb_kind, _sb_dc, _sb_ds,
		_sb_area, conds, BattleSystem.player_team)
	if err != "":
		_toast_show(err)
		return
	_toast_show("✦ Custom spell created: %s" % _sb_name.text.strip_edges())
	if _spell_builder != null and is_instance_valid(_spell_builder):
		_spell_builder.queue_free()
	# Refresh the spell popup to include the new spell.
	if _spell_popup != null and is_instance_valid(_spell_popup):
		_spell_popup.queue_free()
	_open_spell_popup()


# ═════════════════════════════════════════════════════════════════════════
# Minimap (2 Hz rebuild)
# ═════════════════════════════════════════════════════════════════════════

func _update_minimap() -> void:
	if _e == null or _minimap == null:
		return
	var pal: Dictionary = REGION_PALETTES.get(str(BattleSystem.region_id), REGION_PALETTES["plains"])
	var floor_c: Color = (pal["floor"] as Color).darkened(0.45)
	var wall_c := Color(0.45, 0.45, 0.48)
	var obst_c := Color(0.42, 0.30, 0.18)
	if _minimap_img == null:
		_minimap_img = Image.create_empty(_ms, _ms, false, Image.FORMAT_RGB8)
	var img := _minimap_img

	var fogged: bool = _fog_on and not _fog_revealed and _explored.size() == _ms * _ms
	var total: int = _ms * _ms
	var buf := PackedByteArray()
	buf.resize(total * 3)   # RGB8
	var floor_r: int = clampi(int(floor_c.r * 255), 0, 255)
	var floor_g: int = clampi(int(floor_c.g * 255), 0, 255)
	var floor_b: int = clampi(int(floor_c.b * 255), 0, 255)
	var wall_r: int = 115; var wall_g: int = 115; var wall_b: int = 122
	var obst_r: int = 107; var obst_g: int = 77; var obst_b: int = 46
	var void_r: int = 13; var void_g: int = 13; var void_b: int = 18
	var bi: int = 0
	for i in range(total):
		var v: int = int(_e._dungeon_map[i])
		var r: int; var g: int; var b: int
		if v == 1:
			r = floor_r; g = floor_g; b = floor_b
		elif v == 2:
			r = wall_r; g = wall_g; b = wall_b
		elif v == 3:
			r = obst_r; g = obst_g; b = obst_b
		else:
			r = void_r; g = void_g; b = void_b
		if fogged:
			if _explored[i] == 0:
				r = 5; g = 5; b = 8
			elif _vision[i] == 0:
				r = r * 45 / 100; g = g * 45 / 100; b = b * 45 / 100
		buf[bi] = r; buf[bi + 1] = g; buf[bi + 2] = b
		bi += 3
	img = Image.create_from_data(_ms, _ms, false, Image.FORMAT_RGB8, buf)

	# Entities: 2×2 team-colored dots; resource nodes teal. Fog-filtered.
	for ent_v in _e._dungeon_entities:
		var ent: Dictionary = ent_v
		if bool(ent.get("is_dead", false)):
			continue
		if fogged and not _fog_sees(ent):
			continue
		var c: Color
		if bool(ent.get("is_resource_node", false)):
			c = Color(0.15, 0.9, 0.85) if not bool(ent.get("looted", false)) else Color(0.3, 0.4, 0.4)
		elif bool(ent.get("is_crate", false)):
			c = Color(1.0, 0.85, 0.3)
		elif ent.has("battle_team"):
			c = BattleSystem.get_team_color(int(ent["battle_team"]))
		else:
			continue
		var ex := int(ent.get("x", 0))
		var ey := int(ent.get("y", 0))
		for oy in range(2):
			for ox in range(2):
				var px := clampi(ex + ox, 0, _ms - 1)
				var py := clampi(ey + oy, 0, _ms - 1)
				img.set_pixel(px, py, c)

	# Camera view: white rectangle around the current focus.
	var half_w := int(_zoom * 0.9)
	var half_h := int(_zoom * 0.62)
	var cx := int(_cam_focus.x)
	var cy := int(_cam_focus.z)
	var white := Color(1, 1, 1)
	for x in range(maxi(cx - half_w, 0), mini(cx + half_w, _ms - 1) + 1):
		img.set_pixel(x, clampi(cy - half_h, 0, _ms - 1), white)
		img.set_pixel(x, clampi(cy + half_h, 0, _ms - 1), white)
	for y in range(maxi(cy - half_h, 0), mini(cy + half_h, _ms - 1) + 1):
		img.set_pixel(clampi(cx - half_w, 0, _ms - 1), y, white)
		img.set_pixel(clampi(cx + half_w, 0, _ms - 1), y, white)

	# Attack-alert ping: blinking red square at the last alert tile.
	if _alert_ping_t > 0.0 and _alert_ping_tile.x >= 0 \
			and int(_alert_ping_t * 6.0) % 2 == 0:
		var red := Color(1.0, 0.15, 0.1)
		for py in range(-2, 3):
			for px in range(-2, 3):
				if absi(px) < 2 and absi(py) < 2:
					continue   # hollow square reads better
				img.set_pixel(
					clampi(_alert_ping_tile.x + px, 0, _ms - 1),
					clampi(_alert_ping_tile.y + py, 0, _ms - 1), red)

	if _minimap_tex == null:
		_minimap_tex = ImageTexture.create_from_image(img)
		_minimap.texture = _minimap_tex
	else:
		_minimap_tex.update(img)


func _on_minimap_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_mm_drag = ev.pressed
		if ev.pressed:
			_minimap_jump(ev.position)
	elif ev is InputEventMouseMotion and _mm_drag:
		_minimap_jump(ev.position)


func _minimap_jump(local_pos: Vector2) -> void:
	var sz := _minimap.size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	_cam_focus = Vector3(
		clampf(local_pos.x / sz.x, 0.0, 1.0) * float(_ms),
		0.0,
		clampf(local_pos.y / sz.y, 0.0, 1.0) * float(_ms))
	_clamp_focus()


# ═════════════════════════════════════════════════════════════════════════
# Battle end
# ═════════════════════════════════════════════════════════════════════════

func _show_over(winner: int) -> void:
	if _over_shown:
		return
	_over_shown = true

	# Region Conquest: a battle launched from the world map carries a pending
	# region id. Winning it claims the region (claim() clears the flag). A loss
	# or draw leaves the flag set so "🔁 Rematch" retries the same conquest
	# battle; the flag is cleared instead when the player leaves the battle.
	var conquest_rid: String = Conquest.pending_region
	var is_conquest: bool = conquest_rid != ""
	if is_conquest and winner == BattleSystem.player_team:
		Conquest.claim(conquest_rid)

	# Outcome sting (guarded internally against missing assets).
	if winner == BattleSystem.player_team:
		AudioManager.play_sfx("jingle_victory")
	elif winner < 0:
		AudioManager.play_sfx("jingle_quest")
	else:
		AudioManager.play_sfx("jingle_defeat")

	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(460, 0)
	overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	var title_txt: String
	var title_col: Color
	if winner == BattleSystem.player_team:
		var cname := str(TEAM_COLOR_NAMES[clampi(winner, 0, TEAM_COLOR_NAMES.size() - 1)])
		title_txt = "🏆 VICTORY — %s holds the region" % cname
		title_col = RimvaleColors.GOLD
	elif winner < 0:
		title_txt = "🕊 DRAW — the region lies in ruin"
		title_col = RimvaleColors.TEXT_LIGHT
	else:
		var wname := str(TEAM_COLOR_NAMES[clampi(winner, 0, TEAM_COLOR_NAMES.size() - 1)])
		title_txt = "💀 DEFEAT — %s holds the region" % wname
		title_col = RimvaleColors.DANGER
	var title := RimvaleUtils.label(title_txt, 22, title_col)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := RimvaleUtils.label(
		"Battle time %02d:%02d" % [int(BattleSystem.get_battle_time() / 60.0), int(BattleSystem.get_battle_time()) % 60],
		12, RimvaleColors.TEXT_GRAY)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	# ── Score report ─────────────────────────────────────────────────────
	var stats: Dictionary = BattleSystem.get_battle_stats()
	var pt: int = BattleSystem.player_team
	box.add_child(HSeparator.new())
	for line in _score_lines(stats, pt):
		var sl := RimvaleUtils.label(str(line), 12, RimvaleColors.TEXT_LIGHT)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sl)
	box.add_child(HSeparator.new())

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(btns)

	var back: Button
	if is_conquest:
		back = RimvaleUtils.button("🗺 Back to World Map", RimvaleColors.GOLD, 40, 14)
		back.pressed.connect(_leave_to_map)
	else:
		back = RimvaleUtils.button("Back to Title", RimvaleColors.GOLD, 40, 14)
		back.pressed.connect(_leave_battle)
	back.custom_minimum_size = Vector2(200, 40)
	btns.add_child(back)

	var again := RimvaleUtils.button("🔁 Rematch", RimvaleColors.PRIMARY, 40, 14)
	again.custom_minimum_size = Vector2(150, 40)
	again.tooltip_text = "Same region, teams, difficulty, resources and heroes."
	again.pressed.connect(func():
		BattleSystem.rematch()
		get_tree().reload_current_scene())
	btns.add_child(again)

	var watch := RimvaleUtils.button("🏖 Keep playing", RimvaleColors.TEXT_GRAY, 40, 14)
	watch.custom_minimum_size = Vector2(170, 40)
	watch.tooltip_text = "Free play: the sim keeps running — move units, mine, build, cast. Leave whenever you like."
	watch.pressed.connect(func():
		overlay.visible = false
		BattleSystem.resume_sandbox()
		_toast_show("🏖 Free play — the field is yours."))
	btns.add_child(watch)


## Human-readable score lines for the outcome modal.
func _score_lines(stats: Dictionary, pt: int) -> Array:
	var out: Array = []
	var kills: Array = stats.get("kills", [])
	var mined: Array = stats.get("mined", [])
	var built: Array = stats.get("built", [])
	var lost: Array = stats.get("lost", [])
	var caps: Array = stats.get("captures", [])
	var my_kills: int = int(kills[pt]) if pt < kills.size() else 0
	# Best rival by kills, for bragging context.
	var best_t: int = -1
	var best_k: int = -1
	for t in range(kills.size()):
		if t == pt:
			continue
		if int(kills[t]) > best_k:
			best_k = int(kills[t])
			best_t = t
	var rival: String = ""
	if best_t >= 0:
		rival = "  ·  best rival Team %d: %d" % [best_t + 1, best_k]
	out.append("⚔ Kills — you: %d%s" % [my_kills, rival])
	out.append("⛏ Supply mined: %d⛃    🏭 Built: %d    💀 Lost: %d" % [
		int(mined[pt]) if pt < mined.size() else 0,
		int(built[pt]) if pt < built.size() else 0,
		int(lost[pt]) if pt < lost.size() else 0])
	if pt < caps.size() and int(caps[pt]) > 0:
		out.append("🔧 Structures captured: %d" % int(caps[pt]))
	var blast: Dictionary = stats.get("blast", {})
	if not blast.is_empty():
		out.append("💥 Biggest blast — %s, %d damage (Team %d)" % [
			str(blast.get("spell", "?")), int(blast.get("dmg", 0)),
			int(blast.get("team", 0)) + 1])
	var mvp: Dictionary = stats.get("mvp", {})
	if not mvp.is_empty():
		var mvp_tag: String = "your" if int(mvp.get("team", -1)) == pt else "Team %d's" % (int(mvp.get("team", 0)) + 1)
		out.append("🎖 MVP — %s (%s unit, %d kills)" % [
			str(mvp.get("name", "?")), mvp_tag, int(mvp.get("kills", 0))])
	return out


func _leave_battle() -> void:
	# Clear any conquest flag so a manual skirmish can't inherit it.
	Conquest.abandon()
	BattleSystem.end_battle()
	get_tree().change_scene_to_file(TITLE_SCENE)


## Return to the Region Conquest world map after a conquest battle. A win has
## already been claimed in _show_over; here we just clear the pending flag and
## end the battle. The map re-reads Conquest.owned to repaint (and shows the
## triumph screen if that win completed the campaign).
func _leave_to_map() -> void:
	Conquest.abandon()
	BattleSystem.end_battle()
	get_tree().change_scene_to_file(CONQUEST_MAP_SCENE)
