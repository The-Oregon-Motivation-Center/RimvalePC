## dungeon.gd  —  Segment 2 rewrite
## 3-column action panel, expanded entity card, move confirmation,
## target-selection mode, individual turn queue (Next Unit / End Phase).

extends Control

# ── Engine reference ──────────────────────────────────────────────────────────
var _e  # RimvaleAPI.engine

# ── Dungeon data ──────────────────────────────────────────────────────────────
var _map: PackedInt32Array
var _fog: PackedByteArray          # 625 bytes: 0=unseen, 1=remembered, 2=visible
var _elevation: PackedInt32Array   # 625 ints: 0=pit, 1=normal, 2=platform
var _entities: Array = []
var _selected_id: String = ""
var _valid_moves: Array = []
var _log_lines: Array = []

# Terrain-driven tile colours (overridden from engine palette on load)
var _c_floor:     Color = Color(0.48, 0.42, 0.32)
var _c_floor_alt: Color = Color(0.44, 0.38, 0.29)
var _c_wall:      Color = Color(0.22, 0.20, 0.18)
var _c_obstacle:  Color = Color(0.30, 0.25, 0.20)
var _c_accent:    Color = Color(0.55, 0.45, 0.30)

# Render style — "classic" or "region" — read from GameState on load.
# Classic = grid-token tactical render (current behavior).
# Region  = region-map-styled render (procedural terrain, atmosphere, props)
#           — see _apply_region_style_overrides() for the visual deltas.
var _render_style: String = "classic"

# Biome metadata from palette
var _biome_prop_set:     String = "cave"
var _biome_light_color:  Color  = Color(1.0, 0.65, 0.25)
var _biome_light_energy: float  = 2.8
var _biome_fog_color:    Color  = Color(0.08, 0.06, 0.04)
var _biome_fog_density:  float  = 0.3
var _biome_ceiling:      String = "stalactites"
var _biome_wall_style:   String = "rock"

# Encounter outcome state
var _outcome: String = "ongoing"   # "ongoing", "victory", "defeat"

# UI — encounter banner
var _banner_bar:   Control
var _banner_label: Label

# UI — victory / defeat modal
var _modal:        Control
var _modal_title:  Label
var _modal_body:   Label
var _modal_btn:    Button

# UI — stash dialog
var _stash_overlay:   Control
var _stash_list_vbox: VBoxContainer
var _stash_header:    Label
var _btn_stash:       Button   # header shortcut button

# UI — equipment overlay (in-dungeon equip management)
var _equip_overlay:      Control
var _equip_slots_vbox:   VBoxContainer

# UI — custom spell dialog (full PHB spell builder)
var _spell_overlay:        Control
var _spell_inner:          VBoxContainer   # rebuilt each time domain/effect changes

# PHB spell builder state
var _sb_name:          String = ""
var _sb_domain:        int = 0
var _sb_effect_idx:    int = 0
var _sb_duration_idx:  int = 0
var _sb_range_idx:     int = 1   # default Touch
var _sb_targets:       int = 1
var _sb_area_idx:      int = 0
var _sb_die_count:     int = 1
var _sb_die_idx:       int = 0   # 0=d4, 1=d6 ...
var _sb_damage_type:   int = 3   # default Force
var _sb_is_healing:    bool = false
var _sb_is_saving_throw: bool = false
var _sb_is_teleport:   bool = false
var _sb_tp_range:      int = 5         # teleport max distance in tiles (when teleport enabled)
var _sb_tp_range_row:  HBoxContainer   # teleport range slider row (shown/hidden)
var _sb_is_combustion: bool = false
var _sb_conditions:    Array = []
var _sb_preview_lbl:   Label
var _sb_breakdown_lbl: Label
var _sb_desc_lbl:      Label

# PHB spell formula constants (mirror level_up.gd)
const SB_DOMAIN_NAMES: PackedStringArray = ["Biological", "Chemical", "Physical", "Spiritual"]
const SB_DOMAIN_EFFECTS: Array = [
	[["Augment Trait", 1], ["Health Regeneration", 1], ["Memory Edit", 4],
	 ["Mind Control", 6], ["Revivify", 5], ["Terrain Manipulation", 1],
	 ["Undeath", 1], ["Weather Resistance", 1]],
	[["Combustion", 4], ["Damage an Object", 1], ["Mend an Object", 2],
	 ["Remove Grime", 1], ["Transmutation", 40]],
	[["Accuracy", 1], ["Ambient Temperature", 1], ["Create Construct", 2],
	 ["Damage Output Increase", 1], ["Damage Reduction", 2], ["Illusions", 2],
	 ["Light", 2], ["Shield", 1], ["Telekinesis", 1], ["Teleportation", 1],
	 ["Time Manipulation", 2]],
	[["Bless", 1], ["Conjure Damage or Healing", 1], ["Curse", 1],
	 ["Intangibility", 4], ["Suppress Magic", 2], ["Summon", 2]],
]
const SB_CONDITIONS_BENEFICIAL: PackedStringArray = [
	"Calm", "Dodging", "Flying", "Hidden", "Invisible",
	"Invulnerable", "Resistance", "Shielded", "Silent", "Stoneskin"
]
const SB_CONDITIONS_HARMFUL: PackedStringArray = [
	"Bleed", "Blinded", "Charm", "Confused", "Dazed", "Deafened",
	"Depleted", "Diseased", "Enraged", "Exhausted", "Fear", "Fever",
	"Incapacitated", "Paralyzed", "Petrified", "Poisoned", "Prone",
	"Restrained", "Slowed", "Squeeze", "Stunned", "Unconscious", "Vulnerable"
]
const SB_DAMAGE_TYPES: PackedStringArray = [
	"Bludgeoning", "Piercing", "Slashing", "Force", "Fire", "Cold",
	"Lightning", "Acid", "Poison", "Psychic", "Radiant", "Necrotic", "Thunder"
]
const SB_DURATION_LABELS: PackedStringArray = ["Instant", "1 Minute", "10 Minutes", "1 Hour", "1 Day"]
const SB_DURATION_ROUNDS: PackedInt32Array  = [0, 10, 100, 600, 14400]
const SB_DURATION_MULT:   PackedInt32Array  = [1, 2, 3, 5, 10]
const SB_RANGE_LABELS:   PackedStringArray = ["Self", "Touch", "15 ft", "30 ft", "100 ft", "500 ft", "1000 ft"]
const SB_RANGE_SP_COST:  PackedInt32Array  = [0, 0, 1, 2, 3, 6, 10]
const SB_AREA_LABELS: PackedStringArray = ["Single Target", "Small (10 ft cube)", "Large (30 ft cube)", "Massive (100 ft cube)"]
const SB_AREA_MULT:   PackedInt32Array  = [1, 2, 3, 10]
const SB_DIE_LABELS:    PackedStringArray = ["d4", "d6", "d8", "d10", "d12"]
const SB_DIE_SIDES_MOD: PackedInt32Array  = [0, 1, 2, 3, 4]

# UI — terrain selector dialog
var _terrain_overlay:      Control
var _terrain_region_vbox:  VBoxContainer
var _terrain_sub_vbox:     VBoxContainer
var _terrain_sel_region:   String = ""
var _terrain_sel_name:     String = ""
var _terrain_sel_style:    int    = 0
var _terrain_swatch:       ColorRect

# Pending state
var _pending_action: Dictionary = {}   # action dict waiting for a target click
var _pending_move: Dictionary   = {}   # {x, y} waiting for confirm
# Area-spell targeting state
var _area_mode: bool              = false
var _area_action: Dictionary      = {}
var _area_radius: int             = 0
var _area_preview: Vector2i       = Vector2i(-1, -1)  # tile under cursor
var _area_tp_origin: Vector2i     = Vector2i(-1, -1)  # teleport range center (caster pos)
# Multi-target spell selection state
var _multi_target_mode: bool      = false
var _multi_target_action: Dictionary = {}
var _multi_target_list: Array     = []   # array of entity id strings
var _multi_target_max: int        = 1
var _multi_target_friendly: bool  = true

## Map size — read from the engine on load. Standard dungeons = 25,
## Dungeon Crawl mode = 50 (or whatever the engine sets). All rendering /
## fog / pathfinding loops use this var directly. Synced via _sync_map_size().
var MAP_SIZE: int = 25
const TILE_SIZE: int = 32

# Tile colours
const C_VOID      := Color(0.07, 0.07, 0.08)
const C_FLOOR     := Color(0.48, 0.42, 0.32)
const C_FLOOR_ALT := Color(0.44, 0.38, 0.29)
const C_WALL      := Color(0.22, 0.20, 0.18)
const C_OBSTACLE  := Color(0.30, 0.25, 0.20)
const C_MOVE_HL   := Color(0.25, 0.82, 0.25, 0.45)
const C_SEL_HL    := Color(1.00, 0.88, 0.10, 0.70)
const C_TARGET_HL := Color(0.90, 0.30, 0.10, 0.60)
const C_MOVE_PEND := Color(0.20, 0.90, 0.90, 0.55)
const C_AREA_HL   := Color(0.70, 0.25, 0.90, 0.40)   # area-spell radius fill
const C_AREA_RING := Color(0.85, 0.45, 1.00, 0.80)   # area-spell radius border
const C_PLAYER    := Color(0.20, 0.55, 0.92)
const C_ENEMY     := Color(0.88, 0.22, 0.22)
const C_DEAD      := Color(0.35, 0.35, 0.35)
const C_HP_BAR    := Color(0.22, 0.72, 0.22)
const C_HP_BG     := Color(0.55, 0.15, 0.15)
const C_AP_BAR    := Color(0.22, 0.60, 0.90)
const C_SP_BAR    := Color(0.75, 0.35, 0.80)

# Fog of war
const C_FOG_UNSEEN     := Color(0.03, 0.03, 0.03, 0.96)   # near-black shroud
const C_FOG_REMEMBERED := Color(0.00, 0.00, 0.00, 0.55)   # dimming overlay for seen tiles

# ── Spell Crafter constants (matching level_up.gd / mobile parity) ───────────
const SC_DOMAIN_NAMES: PackedStringArray = ["Biological", "Chemical", "Physical", "Spiritual"]
const SC_DOMAIN_EFFECTS: Array = [
	[["Augment Trait",1],["Health Regeneration",1],["Memory Edit",4],["Mind Control",6],
	 ["Revivify",5],["Terrain Manipulation",1],["Undeath",1],["Weather Resistance",1]],
	[["Combustion",4],["Damage an Object",1],["Mend an Object",2],["Remove Grime",1],["Transmutation",40]],
	[["Accuracy",1],["Ambient Temperature",1],["Create Construct",2],["Damage Output Increase",1],
	 ["Damage Reduction",2],["Illusions",2],["Light",2],["Shield",1],["Telekinesis",1],
	 ["Teleportation",1],["Time Manipulation",2]],
	[["Bless",1],["Conjure Damage or Healing",1],["Curse",1],["Intangibility",4],
	 ["Suppress Magic",2],["Summon",2]],
]
const SC_DURATION_LABELS: PackedStringArray = ["Instant","1 Minute","10 Minutes","1 Hour","1 Day"]
const SC_DURATION_ROUNDS: PackedInt32Array  = [0,10,100,600,14400]
const SC_DURATION_MULT:   PackedInt32Array  = [1,2,3,5,10]
const SC_RANGE_LABELS: PackedStringArray = ["Self","Touch","15 ft","30 ft","100 ft","500 ft","1000 ft"]
const SC_RANGE_SP:     PackedInt32Array  = [0,0,1,2,3,6,10]
const SC_AREA_LABELS:  PackedStringArray = ["Single Target","Small (10 ft cube)","Large (30 ft cube)","Massive (100 ft cube)"]
const SC_AREA_MULT:    PackedInt32Array  = [1,2,3,10]
const SC_DIE_LABELS:   PackedStringArray = ["d4","d6","d8","d10","d12"]
const SC_DIE_SIDES_MOD:PackedInt32Array  = [0,1,2,3,4]
const SC_DAMAGE_TYPES: PackedStringArray = [
	"Bludgeoning","Piercing","Slashing","Force","Fire","Cold",
	"Lightning","Acid","Poison","Psychic","Radiant","Necrotic","Thunder"]
const SC_COND_BENEFICIAL: PackedStringArray = [
	"Calm","Dodging","Flying","Hidden","Invisible","Invulnerable","Resistance","Shielded","Silent","Stoneskin"]
const SC_COND_HARMFUL: PackedStringArray = [
	"Bleed","Blinded","Charm","Confused","Dazed","Deafened","Depleted","Diseased",
	"Enraged","Exhausted","Fear","Fever","Incapacitated","Paralyzed","Petrified",
	"Poisoned","Prone","Restrained","Slowed","Squeeze","Stunned","Unconscious","Vulnerable"]
# Spell crafter state
var _sc_overlay: Control = null
var _sc_domain: int = 0; var _sc_effect_idx: int = 0; var _sc_duration_idx: int = 0
var _sc_range_idx: int = 0; var _sc_targets: int = 1; var _sc_area_idx: int = 0
var _sc_die_count: int = 0; var _sc_die_idx: int = 1; var _sc_damage_type: int = 3
var _sc_is_healing: bool = false; var _sc_is_saving_throw: bool = false
var _sc_is_teleport: bool = false; var _sc_tp_range: int = 5; var _sc_tp_range_row: HBoxContainer
var _sc_conditions: Array = []; var _sc_name: String = ""
var _sc_cost_lbl: Label; var _sc_breakdown_lbl: Label; var _sc_desc_lbl: Label
var _sc_die_btns: Array = []

# Shapeshift dialog state
var _ss_overlay: Control = null
var _ss_pending_action: Dictionary = {}

# Summon creature builder state
var _sb_overlay: Control = null
var _sb_pending_action: Dictionary = {}
var _sb_stats: Array = [0, 0, 0, 0, 0]  # STR, SPD, INT, VIT, DIV
var _sb_feats: Dictionary = {}
var _sb_abilities: Array = []
var _sb_cost_lbl: Label = null

# Create Construct builder state
var _cb_overlay: Control = null
var _cb_pending_action: Dictionary = {}
var _cb_mode: int = 0              # 0=equipment, 1=structure
var _cb_weapon_idx: int = 0        # 0=none, 1=light, 2=martial, 3=heavy
var _cb_armor_idx: int = 0         # 0=none, 1=light, 2=medium, 3=heavy
var _cb_shield_idx: int = 0        # 0=none, 1=shield, 2=tower shield
var _cb_trr: int = 0               # 0-10 TRR rating
var _cb_struct_tier: int = 1       # 1=5x5x5(1 tile), 2=10x10x10, etc.
var _cb_cost_lbl: Label = null
var _cb_stats_lbl: Label = null

# Elevation tints (applied on top of floor colour)
const C_ELEV_HIGH := Color(1.00, 1.00, 1.00, 0.22)   # brightened for raised platform
const C_ELEV_LOW  := Color(0.00, 0.00, 0.00, 0.30)   # darkened for pit/low ground
const C_ELEV_EDGE := Color(0.65, 0.50, 0.20, 0.85)   # border around elevation changes

# ── UI references ─────────────────────────────────────────────────────────────
var _grid_view:        Control         # SubViewportContainer (3D)
var _scroll:           ScrollContainer # unused in 3D mode (kept for compat)

# ── 3D Rendering ──────────────────────────────────────────────────────────────
var _viewport_3d:       SubViewport    = null
# Cached on map load from GameState.dungeon_quality. Drives prop density,
# viewport size, and shadow toggles in the region-style render path.
# Values: "low" / "medium" / "high".
var _quality: String = "medium"

# ── Render-distance culling (chunked rendering) ────────────────────────────
# Big crawl maps don't need every tile drawn — only tiles within Chebyshev
# `_render_radius` of ANY player are built into the scene. When a player
# moves `_render_chunk_step` tiles from the last anchor, set _map_dirty so
# the next _update_3d_view rebuilds the visible chunk.
# Disabled (radius=0 / step=0) for standard 25×25 dungeons; auto-enables at
# MAP_SIZE > 30 (i.e., crawl).
var _render_radius:     int = 0
var _render_chunk_step: int = 0
# Per-player anchor tile recorded the last time tiles were rebuilt.
var _last_render_anchors: Array = []
# Region-style prop root — populated only when _render_style == "region".
# Holds grass tufts, stone cornices, streetlamps, benches, and the daylight
# DirectionalLight. Lives as a child of _world3d_root, cleared + rebuilt
# whenever _rebuild_region_style_props() runs.
var _region_prop_root:  Node3D         = null
var _cam3d:             Camera3D       = null
var _world3d_root:      Node3D         = null
var _tile_root:         Node3D         = null
var _entity_root:       Node3D         = null
var _overlay_root:      Node3D         = null
var _torch_root:        Node3D         = null
var _fog_root:          Node3D         = null
var _particle_root:     Node3D         = null
var _env_node:          WorldEnvironment = null
var _map_dirty:         bool           = true   # full tile rebuild needed

# ── Camera orbit state ────────────────────────────────────────────────────────
var _cam_yaw:   float = 0.0     # horizontal orbit angle (degrees, 0 = south)
var _cam_pitch: float = 55.0    # elevation angle (degrees above horizon)
var _cam_dist:  float = 24.0    # distance from map centre
var _cam_target_offset: Vector3 = Vector3.ZERO   # pan offset from map centre
var _cam_dragging:  bool    = false
var _cam_drag_last: Vector2 = Vector2.ZERO
var _log_text:         RichTextLabel
var _btn_next_unit:    Button
var _btn_end_phase:    Button
var _btn_end_dungeon:  Button
var _btn_back:         Button
var _phase_label:      Label
var _round_label:      Label

# Left panel
var _lp_name:          Label
var _lp_hp_bar:        ProgressBar
var _lp_hp_val:        Label
var _lp_ap_bar:        ProgressBar
var _lp_ap_val:        Label
var _lp_sp_bar:        ProgressBar
var _lp_sp_val:        Label
var _lp_weapon:        Label
var _lp_conditions:    Label
var _lp_matrices:      Label
var _lp_roster:        VBoxContainer

# Right panel — action columns
var _col_weapons_vbox: VBoxContainer
var _col_magic_vbox:   VBoxContainer
var _col_abil_vbox:    VBoxContainer
var _action_mode_lbl:  Label    # shows "Select target…" when in target mode

# Bottom bar — mobile-style layout
var _unit_tabs_hbox:   HBoxContainer
var _badge_name:       Label
var _badge_hp:         Label
var _badge_ap:         Label
var _badge_sp:         Label
var _badge_weapon:     Label
var _badge_light:      Label
var _badge_conditions: HBoxContainer   # holds colored condition chip Labels
var _badge_matrices:   Label
var _actions_area:     Control
var _weapons_panel:    Control
var _cast_panel:       Control
var _abil_panel:       Control
var _active_category:  String = ""
var _btn_weapons:      Button
var _btn_cast:         Button
var _btn_abilities:    Button

# Move confirm popup
var _move_popup:       Control
var _move_popup_lbl:   Label
var _move_confirm_btn: Button

# Loot popup
var _loot_popup:          Control
var _loot_title_lbl:      Label
var _loot_items_vbox:     VBoxContainer
var _loot_entity_id:      String = ""

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_e = RimvaleAPI.engine
	# Ensure all ritual spells are registered before combat begins
	GameState.ensure_ritual_spells_registered()
	_map = _e.get_dungeon_map()
	if _map.is_empty():
		var handles: Array = GameState.get_active_handles()
		if handles.is_empty():
			pass
		else:
			_e.start_dungeon(handles, 1, 0, 0)
			_map = _e.get_dungeon_map()
	_fog       = _e.get_dungeon_fog()
	_elevation = _e.get_dungeon_elevation_map()
	# Pull map size from the engine so Dungeon Crawl's 50×50 layout drives
	# all the rendering / camera / fog loops correctly.
	if _e.get("MAP_SIZE") != null:
		MAP_SIZE = int(_e.get("MAP_SIZE"))
	_load_terrain_palette()

	# Read the render-style toggle from GameState. Set on the world Dungeon
	# tab (Classic / Region Map Style). "region" swaps in explore-map visuals.
	_render_style = str(GameState.get("dungeon_render_style"))
	if _render_style != "region":
		_render_style = "classic"
	# Render-quality preference (low / medium / high).
	_quality = str(GameState.get("dungeon_quality"))
	if not (_quality == "low" or _quality == "medium" or _quality == "high"):
		_quality = "medium"
	# Render-distance culling — only enabled on big maps. Radius is now the
	# Chebyshev half-width of the visible chunk; the rendered area is a
	# (2 × radius + 1) square. Smaller chunks = less per-rebuild work and
	# tighter draw budget. Chunk step is the move-distance threshold that
	# retriggers the rebuild — small step keeps the chunk centered on the
	# party as they walk, so edges don't visibly pop in.
	if MAP_SIZE > 30:
		match _quality:
			"low":  _render_radius = 6     # 13×13 visible chunk
			"high": _render_radius = 10    # 21×21
			_:      _render_radius = 8     # 17×17
		_render_chunk_step = 2
	else:
		_render_radius = 0     # 0 disables culling entirely
		_render_chunk_step = 0
	_last_render_anchors.clear()
	print("[Dungeon] render style = %s, quality = %s, map = %d×%d, cull radius = %d"
		% [_render_style, _quality, MAP_SIZE, MAP_SIZE, _render_radius])
	if _render_style == "region":
		_apply_region_style_overrides()

	_build_ui()
	_build_banner()
	_build_stash_dialog()
	_build_equip_overlay()
	_build_victory_modal()
	_build_custom_spell_dialog()
	_build_terrain_selector_dialog()

	# Auto-apply a random terrain so the dungeon renders immediately without
	# the player having to manually open the terrain dialog first.
	_on_terrain_random()
	if not _terrain_sel_name.is_empty():
		_on_terrain_confirm()

	_refresh()
	_update_banner()
	_add_log("[color=gold]You enter the dungeon...[/color]")
	_auto_select_first()
	# Defer an additional build so the camera is definitely current
	_map_dirty = true
	call_deferred("_first_3d_build")

# ── First 3D build (deferred one frame after _ready) ─────────────────────────
func _first_3d_build() -> void:
	_sync_viewport_size()
	if _cam3d != null:
		_cam3d.make_current()
		_update_camera_pos()
	_map_dirty = true
	_update_3d_view()

## No-op — viewport uses a fixed internal resolution with stretch=true.
func _sync_viewport_size() -> void:
	pass

## No per-frame sync needed — SubViewportContainer.stretch handles scaling.
func _process(_delta: float) -> void:
	pass

## Recompute the camera's world position from the current orbit parameters.
## Call whenever _cam_yaw, _cam_pitch, or _cam_dist changes.
func _update_camera_pos() -> void:
	if _cam3d == null: return
	var half: float    = MAP_SIZE * 0.5
	var target: Vector3 = Vector3(half, 0.0, half) + _cam_target_offset
	var yaw_r:   float = deg_to_rad(_cam_yaw)
	var pitch_r: float = deg_to_rad(_cam_pitch)
	var horiz: float   = _cam_dist * cos(pitch_r)
	var vert:  float   = _cam_dist * sin(pitch_r)
	var cam_pos: Vector3 = Vector3(
		target.x + horiz * sin(yaw_r),
		vert,
		target.z + horiz * cos(yaw_r)
	)
	_cam3d.look_at_from_position(cam_pos, target, Vector3.UP)

# ── Terrain palette ───────────────────────────────────────────────────────────
func _load_terrain_palette() -> void:
	var pal: Dictionary = _e.get_terrain_palette()
	if pal.is_empty(): return
	var f  = pal.get("floor",     [0.48, 0.42, 0.32])
	var fa = pal.get("floor_alt", [0.44, 0.38, 0.29])
	var w  = pal.get("wall",      [0.22, 0.20, 0.18])
	var ob = pal.get("obstacle",  [0.30, 0.25, 0.20])
	var ac = pal.get("accent",    [0.55, 0.45, 0.30])
	_c_floor     = Color(float(f[0]),  float(f[1]),  float(f[2]))
	_c_floor_alt = Color(float(fa[0]), float(fa[1]), float(fa[2]))
	_c_wall      = Color(float(w[0]),  float(w[1]),  float(w[2]))
	_c_obstacle  = Color(float(ob[0]), float(ob[1]), float(ob[2]))
	_c_accent    = Color(float(ac[0]), float(ac[1]), float(ac[2]))

	# Biome metadata
	_biome_prop_set     = pal.get("prop_set", "cave")
	_biome_wall_style   = pal.get("wall_style", "rock")
	_biome_ceiling      = pal.get("ceiling_style", "stalactites")
	var lc = pal.get("light_color", [1.0, 0.65, 0.25])
	_biome_light_color  = Color(float(lc[0]), float(lc[1]), float(lc[2]))
	_biome_light_energy = float(pal.get("light_energy", 2.8))
	var fc2 = pal.get("fog_color", [0.08, 0.06, 0.04])
	_biome_fog_color    = Color(float(fc2[0]), float(fc2[1]), float(fc2[2]))
	_biome_fog_density  = float(pal.get("fog_density", 0.3))

## Override dungeon palette + biome atmosphere with region-map-styled values
## when the "Region Map Style" toggle is active on the world Dungeon tab.
##
## The region-map look in explore.gd has brighter, higher-contrast floors,
## plaza/park accents, gentler fog, warmer ambient light, and procedural
## building silhouettes. This function substitutes those values so the same
## dungeon layout reads as an outdoor/urban region rather than a cavern.
##
## Phase 1 (this pass): palette + atmosphere overrides — makes the dungeon
##   feel visually region-ish without changing the grid/combat logic.
## Phase 2 (TBD): port explore.gd's procedural building + POI props into
##   dungeon.gd via a new `_build_region_style_scene()` that runs after
##   `_first_3d_build()` when `_render_style == "region"`.
func _apply_region_style_overrides() -> void:
	# Brighter, higher-saturation floor colors reminiscent of explore.gd.
	_c_floor     = Color(0.42, 0.55, 0.35)   # grassy green (vs. cave brown)
	_c_floor_alt = Color(0.48, 0.60, 0.38)
	_c_wall      = Color(0.26, 0.35, 0.42)   # cool stone instead of near-black
	_c_obstacle  = Color(0.38, 0.42, 0.30)
	_c_accent    = Color(0.72, 0.60, 0.30)   # warm path/road color

	# Biome overrides — push toward the outdoor explore vibe.
	_biome_prop_set     = "region_outdoor"   # consumed by prop-spawner; unknown keys gracefully skip
	_biome_wall_style   = "stone_block"
	_biome_ceiling      = "open_sky"
	_biome_light_color  = Color(1.0, 0.92, 0.78)   # daylight cream
	_biome_light_energy = 3.4
	_biome_fog_color    = Color(0.70, 0.82, 0.92)  # soft sky haze
	_biome_fog_density  = 0.12                      # much thinner than cave fog

	# Camera — match explore.gd's framing so dungeon tiles read at the same
	# on-screen size as region-map tiles. Tile meshes are already 1:1 with
	# the region grid (both ~0.98 world units), so the only thing that
	# made dungeon tiles feel small was the farther camera distance + a
	# steeper pitch. Pulling in closer + lowering the pitch matches explore.
	_cam_dist  = 10.0   # was 24.0
	_cam_pitch = 40.0   # was 55.0

## Rebuild the Region-Style prop overlay. Runs after the classic tile/wall
## rebuild when _render_style == "region". Adds outdoor visuals on top of
## the base tiles without modifying classic code paths.
##
## What it spawns:
##   - Daylight DirectionalLight (warm cream)
##   - Grass tufts on walkable tiles (sparse, deterministic)
##   - Stone cornices on wall edges facing walkable tiles
##   - Streetlamps at regular intervals on walkable tiles
##   - Wooden benches at a handful of scripted spots
##   - Path markings (thin accent boxes) to suggest streets
##
## Everything is parented to _region_prop_root so toggling back to classic
## wipes it cleanly. Uses deterministic RNG seeded by MAP_SIZE so repeated
## rebuilds look stable across the session.
## Returns true when `(tx, ty)` is within `_render_radius` Chebyshev distance
## of ANY living player. When `_render_radius == 0` (standard 25×25 maps),
## returns true unconditionally — culling is off.
func _tile_in_render_radius(tx: int, ty: int) -> bool:
	if _render_radius <= 0:
		return true
	for ent in _entities:
		if not bool(ent.get("is_player", false)):
			continue
		if bool(ent.get("is_dead", false)):
			continue
		var dx: int = absi(int(ent["x"]) - tx)
		var dy: int = absi(int(ent["y"]) - ty)
		if maxi(dx, dy) <= _render_radius:
			return true
	return false

## Snapshot every live player's tile, used to compare against last frame's
## rebuild anchors. Returns an Array of Vector2i.
func _current_player_anchors() -> Array:
	var out: Array = []
	for ent in _entities:
		if bool(ent.get("is_player", false)) and not bool(ent.get("is_dead", false)):
			out.append(Vector2i(int(ent["x"]), int(ent["y"])))
	return out

## True if any live player has moved `_render_chunk_step` or more tiles from
## their position at the last rebuild. Trips a re-render so the visible
## chunk slides with the party.
func _player_moved_past_chunk_step() -> bool:
	if _render_chunk_step <= 0:
		return false
	var current: Array = _current_player_anchors()
	# First call after load — record and don't trigger.
	if _last_render_anchors.is_empty() or _last_render_anchors.size() != current.size():
		_last_render_anchors = current.duplicate()
		return false
	for i in range(current.size()):
		var c: Vector2i = current[i]
		var last: Vector2i = _last_render_anchors[i]
		var dx: int = absi(c.x - last.x)
		var dy: int = absi(c.y - last.y)
		if maxi(dx, dy) >= _render_chunk_step:
			_last_render_anchors = current.duplicate()
			return true
	return false

func _rebuild_region_style_props() -> void:
	if _region_prop_root == null:
		return
	# Clear any previous pass.
	for c in _region_prop_root.get_children():
		c.free()
	if _map.is_empty():
		return

	# ── Daylight ────────────────────────────────────────────────────────────
	# Warm cream directional + a soft blue fill, mirroring explore.gd's
	# outdoor lighting. These stack on top of the existing dungeon lights —
	# combined effect is a notably brighter, less-cavernous scene.
	# Shadow casting is the single biggest perf cost on big maps; only
	# enabled on High quality.
	var sun := DirectionalLight3D.new()
	sun.light_color   = Color(1.00, 0.92, 0.78)   # daylight cream
	sun.light_energy  = 1.30
	sun.shadow_enabled = (_quality == "high")
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	_region_prop_root.add_child(sun)

	var sky_fill := DirectionalLight3D.new()
	sky_fill.light_color   = Color(0.75, 0.85, 1.00)
	sky_fill.light_energy  = 0.40
	sky_fill.shadow_enabled = false
	sky_fill.rotation_degrees = Vector3(30.0, -150.0, 0.0)
	_region_prop_root.add_child(sky_fill)

	# ── Deterministic RNG (stable visuals across rebuilds) ──────────────────
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242 + int(MAP_SIZE)

	# ── Density tuning ──────────────────────────────────────────────────────
	# A 50×50 crawl is 4× the area of a 25×25 standard, so the standard
	# density values would multiply prop count by 4 too. Auto-shrink density
	# in big maps + further by quality preference.
	# Final prop density factor (multiplies the per-tile spawn chances).
	var density_mul: float = 1.0
	if MAP_SIZE > 30:
		density_mul *= 0.45        # crawl mode = sparser baseline
	match _quality:
		"low":  density_mul *= 0.50
		"high": density_mul *= 1.00
		_:      density_mul *= 0.85  # medium = mild trim
	# Lamppost spacing in tiles. Wider spacing = fewer lights = cheaper.
	var lamp_spacing: int = 6
	if MAP_SIZE > 30:
		lamp_spacing = 10
	if _quality == "low":
		lamp_spacing = maxi(lamp_spacing + 4, 12)
	# Skip cornices entirely on low quality (they're per-wall-tile).
	var draw_cornices: bool = _quality != "low"
	# Bench chance per tile.
	var bench_chance: float = 0.02 * density_mul
	# Path-mark chance per qualifying tile.
	var path_chance: float = 0.35 * density_mul
	# Grass chance per walkable tile.
	var grass_chance: float = 0.22 * density_mul

	# Pre-built meshes reused across tiles.
	var grass_blade := BoxMesh.new()
	grass_blade.size = Vector3(0.04, 0.14, 0.04)
	var cornice_mesh := BoxMesh.new()
	cornice_mesh.size = Vector3(0.98, 0.10, 0.22)
	var lamp_post_mesh := CylinderMesh.new()
	lamp_post_mesh.top_radius = 0.04
	lamp_post_mesh.bottom_radius = 0.05
	lamp_post_mesh.height = 0.90
	var lamp_bulb_mesh := SphereMesh.new()
	lamp_bulb_mesh.radius = 0.10
	lamp_bulb_mesh.height = 0.20
	var bench_seat_mesh := BoxMesh.new()
	bench_seat_mesh.size = Vector3(0.55, 0.06, 0.18)
	var bench_leg_mesh := BoxMesh.new()
	bench_leg_mesh.size = Vector3(0.05, 0.20, 0.05)
	var path_mark_mesh := BoxMesh.new()
	path_mark_mesh.size = Vector3(0.12, 0.02, 0.40)

	# Shared materials.
	var path_mat := _make_mat(Color(0.82, 0.74, 0.40), 0.0, 0.80)
	var cornice_mat := _make_mat(Color(0.62, 0.66, 0.58), 0.0, 0.70)
	var lamp_post_mat := _make_mat(Color(0.20, 0.17, 0.14), 0.1, 0.45)
	var lamp_bulb_mat := _make_mat(
		Color(1.0, 0.90, 0.55), 0.0, 0.25,
		Color(1.0, 0.85, 0.45), 1.8)
	var bench_wood_mat := _make_mat(Color(0.50, 0.32, 0.18), 0.0, 0.75)
	var bench_leg_mat  := _make_mat(Color(0.30, 0.22, 0.14), 0.1, 0.60)

	# ── Walk the map ────────────────────────────────────────────────────────
	# Render-distance culling: skip tiles outside the live render chunk on
	# big maps. Saves ~75% of prop work on a 50×50 crawl.
	for ty in range(MAP_SIZE):
		for tx in range(MAP_SIZE):
			if not _tile_in_render_radius(tx, ty):
				continue
			var idx: int = ty * MAP_SIZE + tx
			var tile: int = _map[idx]
			var cx: float = float(tx) + 0.5
			var cz: float = float(ty) + 0.5
			var is_walkable: bool = (tile == 1)

			if is_walkable:
				# Grass tufts — density-scaled, 2–4 blades each.
				if rng.randf() < grass_chance:
					var blade_count: int = rng.randi_range(2, 4)
					for b in range(blade_count):
						var ox: float = rng.randf_range(-0.30, 0.30)
						var oz: float = rng.randf_range(-0.30, 0.30)
						var blade_col := Color(
							0.16 + rng.randf() * 0.08,
							0.48 + rng.randf() * 0.12,
							0.14 + rng.randf() * 0.06)
						var blade_mat := _make_mat(blade_col, 0.0, 0.85)
						_make_mesh_inst(grass_blade, blade_mat,
							cx + ox, 0.15 + rng.randf() * 0.03, cz + oz,
							_region_prop_root)
				# Path markings — every 4th tile diagonally, density-scaled.
				if (tx + ty) % 4 == 0 and rng.randf() < path_chance:
					_make_mesh_inst(path_mark_mesh, path_mat,
						cx, 0.11, cz, _region_prop_root)
				# Streetlamps — spacing scales with map size + quality.
				if (tx % lamp_spacing == 2) and (ty % lamp_spacing == 2):
					# Post
					_make_mesh_inst(lamp_post_mesh, lamp_post_mat,
						cx, 0.55, cz, _region_prop_root)
					# Bulb
					_make_mesh_inst(lamp_bulb_mesh, lamp_bulb_mat,
						cx, 1.05, cz, _region_prop_root)
					# Actual point light
					var lamp := OmniLight3D.new()
					lamp.light_color = Color(1.0, 0.92, 0.60)
					lamp.light_energy = 0.8
					lamp.omni_range = 4.0
					lamp.position = Vector3(cx, 1.05, cz)
					_region_prop_root.add_child(lamp)
				# Benches — density-scaled.
				if rng.randf() < bench_chance:
					var bench := Node3D.new()
					bench.position = Vector3(cx, 0.0, cz)
					bench.rotation_degrees = Vector3(0.0, float(rng.randi_range(0, 3)) * 90.0, 0.0)
					_region_prop_root.add_child(bench)
					# Seat
					var seat := MeshInstance3D.new()
					seat.mesh = bench_seat_mesh
					seat.set_surface_override_material(0, bench_wood_mat)
					seat.position = Vector3(0.0, 0.23, 0.0)
					bench.add_child(seat)
					# Legs
					for sx in [-0.22, 0.22]:
						for sz in [-0.07, 0.07]:
							var leg := MeshInstance3D.new()
							leg.mesh = bench_leg_mesh
							leg.set_surface_override_material(0, bench_leg_mat)
							leg.position = Vector3(sx, 0.10, sz)
							bench.add_child(leg)
			else:
				# Wall-adjacency cornice: if this wall tile has a walkable
				# neighbour, add a stone cornice facing that neighbour.
				# Skipped entirely on Low quality (cornices = per-wall mesh).
				if not draw_cornices:
					continue
				var n := _region_wall_walkable_neighbour(tx, ty)
				if n != Vector2i.ZERO:
					var c_pos_x: float = cx + float(n.x) * 0.40
					var c_pos_z: float = cz + float(n.y) * 0.40
					var cornice := MeshInstance3D.new()
					cornice.mesh = cornice_mesh
					cornice.set_surface_override_material(0, cornice_mat)
					cornice.position = Vector3(c_pos_x, 1.30, c_pos_z)
					# Rotate cornice to run along the wall face.
					if n.x != 0:
						cornice.rotation_degrees = Vector3(0.0, 90.0, 0.0)
					_region_prop_root.add_child(cornice)

	# Phase 3: building signposts from flood-filled wall clusters.
	_spawn_region_building_signposts(rng)

## Phase 3: procedural building signposts from connected wall clusters.
## Flood-fill connected wall tiles into "buildings"; for each building with
## enough tiles, pick a signpost position on a visible edge and spawn a
## name + glow so the cluster reads as a named building, not just a wall.
const _REGION_BUILDING_NAMES: Array = [
	"Guildhall",      "Stonemarket",   "Ironward Watch",   "Bellwether Hall",
	"The Veiled Inn", "Corvus Archive","Emberforge",        "Candlegate Chapel",
	"Wayfarer's Rest","Tallow & Thread","Lighthouse Ward",  "Almsgiver's Door",
	"Crow's Assembly","Mint Annex",    "Harvest Vault",     "Salter's Row",
	"The Ashen Bough","Velvet Warren", "Loom Ward",         "Knotgate",
]

func _spawn_region_building_signposts(rng: RandomNumberGenerator) -> void:
	if _map.is_empty() or _region_prop_root == null:
		return

	# Flood-fill wall tiles into contiguous clusters.
	var visited: Dictionary = {}
	var clusters: Array = []
	for ty in range(MAP_SIZE):
		for tx in range(MAP_SIZE):
			var idx: int = ty * MAP_SIZE + tx
			if _map[idx] == 1:
				continue
			var key: int = tx * MAP_SIZE + ty
			if visited.has(key):
				continue
			# BFS this wall cluster.
			var cluster: Array = []
			var queue: Array = [Vector2i(tx, ty)]
			visited[key] = true
			while queue.size() > 0:
				var p: Vector2i = queue.pop_front()
				cluster.append(p)
				for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var nx: int = p.x + d.x
					var ny: int = p.y + d.y
					if nx < 0 or ny < 0 or nx >= MAP_SIZE or ny >= MAP_SIZE:
						continue
					var nidx: int = ny * MAP_SIZE + nx
					if nidx < 0 or nidx >= _map.size():
						continue
					if _map[nidx] == 1:
						continue
					var nkey: int = nx * MAP_SIZE + ny
					if visited.has(nkey):
						continue
					visited[nkey] = true
					queue.append(Vector2i(nx, ny))
			if cluster.size() >= 4:
				clusters.append(cluster)

	# Performance: in big maps + low quality, skip the warm OmniLight per
	# signpost (the post + plate still render). 50×50 with 30 wall clusters
	# was dropping ~30 lights — too many for low-end hardware.
	var attach_signpost_light: bool = true
	if MAP_SIZE > 30 and _quality == "low":
		attach_signpost_light = false
	# Hard cap on signpost lights regardless of quality.
	var max_signpost_lights: int = 12 if _quality == "high" else (8 if _quality == "medium" else 4)
	var signpost_lights_used: int = 0

	# For each qualifying cluster, spawn one signpost on the edge facing
	# the most walkable neighbours — feels like a building's "front door".
	var name_idx: int = rng.randi_range(0, _REGION_BUILDING_NAMES.size() - 1)
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.04
	post_mesh.bottom_radius = 0.05
	post_mesh.height = 0.80
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(1.10, 0.28, 0.05)
	var post_mat := _make_mat(Color(0.38, 0.30, 0.22), 0.0, 0.75)
	var plate_mat := _make_mat(
		Color(0.92, 0.82, 0.55), 0.0, 0.45,
		Color(0.85, 0.72, 0.45), 0.8)

	for cluster in clusters:
		# Cull: only spawn signposts for clusters whose centroid is within
		# the live render chunk. Distant buildings show their wall meshes
		# (already culled) but no glowing signs that would betray them.
		if _render_radius > 0:
			var any_in_radius: bool = false
			for ct in cluster:
				if _tile_in_render_radius(ct.x, ct.y):
					any_in_radius = true
					break
			if not any_in_radius:
				continue
		# Find the wall tile in this cluster whose neighbour-count of
		# walkable tiles is highest — that's the "front" of the building.
		var best_tile: Vector2i = cluster[0]
		var best_face: Vector2i = Vector2i.ZERO
		var best_score: int = -1
		for p in cluster:
			var score: int = 0
			var first_walkable: Vector2i = Vector2i.ZERO
			for d in [Vector2i(0,-1), Vector2i(0,1), Vector2i(1,0), Vector2i(-1,0)]:
				var nx: int = p.x + d.x
				var ny: int = p.y + d.y
				if nx < 0 or ny < 0 or nx >= MAP_SIZE or ny >= MAP_SIZE:
					continue
				var nidx: int = ny * MAP_SIZE + nx
				if _map[nidx] == 1:
					score += 1
					if first_walkable == Vector2i.ZERO:
						first_walkable = d
			if score > best_score:
				best_score = score
				best_tile = p
				best_face = first_walkable
		if best_score <= 0 or best_face == Vector2i.ZERO:
			continue  # fully enclosed wall, no signpost

		# Drop the signpost on the walkable tile adjacent to best_tile's face
		# so it reads as standing in front of the building.
		var sx: float = float(best_tile.x) + 0.5 + float(best_face.x) * 0.55
		var sz: float = float(best_tile.y) + 0.5 + float(best_face.y) * 0.55

		# Post.
		_make_mesh_inst(post_mesh, post_mat, sx, 0.50, sz, _region_prop_root)

		# Name plate — rotated to face toward the walkable tile.
		var plate := MeshInstance3D.new()
		plate.mesh = plate_mesh
		plate.set_surface_override_material(0, plate_mat)
		plate.position = Vector3(sx, 1.05, sz)
		if best_face.x != 0:
			plate.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		_region_prop_root.add_child(plate)

		# Small warm accent light at the plate so signs glow at night.
		# Capped on big maps / low quality to keep light count reasonable.
		if attach_signpost_light and signpost_lights_used < max_signpost_lights:
			var accent := OmniLight3D.new()
			accent.light_color = Color(1.0, 0.85, 0.55)
			accent.light_energy = 0.5
			accent.omni_range = 2.2
			accent.position = Vector3(sx, 1.15, sz)
			_region_prop_root.add_child(accent)
			signpost_lights_used += 1

		# Tint the plate by cluster size: bigger buildings get richer plates.
		var tier: int = clampi(cluster.size() / 6, 0, 2)
		match tier:
			1:
				plate.set_surface_override_material(0, _make_mat(
					Color(0.95, 0.76, 0.42), 0.05, 0.45,
					Color(0.95, 0.72, 0.35), 1.0))
			2:
				plate.set_surface_override_material(0, _make_mat(
					Color(0.95, 0.62, 0.32), 0.15, 0.40,
					Color(0.95, 0.60, 0.28), 1.3))

		# Rotate the name-pool index for variety across clusters.
		name_idx = (name_idx + 1) % _REGION_BUILDING_NAMES.size()

## Helper: if tile (tx, ty) is a wall, return the direction (as a unit
## Vector2i) of the first walkable neighbour, or Vector2i.ZERO if none.
## Used to orient cornices along the outward face of a wall.
func _region_wall_walkable_neighbour(tx: int, ty: int) -> Vector2i:
	# Priority order: N, S, E, W. Returns the step direction from the wall
	# TOWARD the walkable tile so the cornice hangs over that edge.
	var candidates: Array = [
		Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(1, 0),  Vector2i(-1, 0),
	]
	for d in candidates:
		var nx: int = tx + d.x
		var ny: int = ty + d.y
		if nx < 0 or ny < 0 or nx >= MAP_SIZE or ny >= MAP_SIZE:
			continue
		var nidx: int = ny * MAP_SIZE + nx
		if nidx < 0 or nidx >= _map.size():
			continue
		if _map[nidx] == 1:
			return d
	return Vector2i.ZERO

## Update WorldEnvironment to match current biome palette.
func _update_biome_environment() -> void:
	if _env_node == null: return
	var env: Environment = _env_node.environment
	if env == null: return

	# Region Map Style: outdoor sky environment overrides cavern darkness.
	# Background switches to a procedural sky; ambient light, fog, and glow
	# are all tuned for daylight rather than torchlight.
	if _render_style == "region":
		env.background_mode = Environment.BG_SKY
		var sky_res: Sky = env.sky
		if sky_res == null:
			sky_res = Sky.new()
			env.sky = sky_res
		var proc_mat: ProceduralSkyMaterial = sky_res.sky_material as ProceduralSkyMaterial
		if proc_mat == null:
			proc_mat = ProceduralSkyMaterial.new()
			sky_res.sky_material = proc_mat
		# Bright daylight sky — a touch of warmth in the sun zone, soft
		# horizon haze, deep cool blue overhead.
		proc_mat.sky_top_color     = Color(0.45, 0.62, 0.86)
		proc_mat.sky_horizon_color = Color(0.78, 0.86, 0.92)
		proc_mat.sky_curve         = 0.15
		proc_mat.sky_energy_multiplier = 1.00
		proc_mat.ground_bottom_color = Color(0.30, 0.32, 0.28)
		proc_mat.ground_horizon_color = Color(0.62, 0.66, 0.60)
		proc_mat.ground_curve      = 0.05
		proc_mat.ground_energy_multiplier = 1.00
		proc_mat.sun_angle_max     = 30.0
		proc_mat.sun_curve         = 0.05
		# Daylight ambient — strong cream, mild fog, gentle bloom.
		env.ambient_light_color = Color(0.82, 0.85, 0.78)
		env.ambient_light_energy = 1.10
		env.fog_enabled = true
		env.fog_light_color = Color(0.78, 0.86, 0.92)
		env.fog_density = 0.012   # very thin haze, not soup
		env.glow_enabled = true
		env.glow_intensity = 0.65
		env.glow_bloom = 0.18
		# Update directional lights to daylight too — even if the cavern
		# pass set them, they get overridden in region mode.
		for child in _world3d_root.get_children():
			if child is DirectionalLight3D:
				if child.name == "SunLight":
					child.light_color = Color(1.00, 0.95, 0.82)
					child.light_energy = 1.20
				elif child.name == "FillLight":
					child.light_color = Color(0.75, 0.85, 1.00)
					child.light_energy = 0.40
		return

	# Classic / cavern path (unchanged):
	# Background — derived from biome fog color, deeper
	env.background_color = _biome_fog_color.darkened(0.6)

	# Ambient light — tinted from biome light color
	env.ambient_light_color = _biome_light_color.lerp(Color(0.15, 0.12, 0.20), 0.6)
	env.ambient_light_energy = 0.5 + _biome_light_energy * 0.08

	# Fog — from biome palette
	env.fog_light_color = _biome_fog_color
	env.fog_density = _biome_fog_density * 0.08  # scale down for 3D view

	# Glow — warmer for fire/volcanic, cooler for ice/void
	match _biome_prop_set:
		"volcanic", "infernal":
			env.glow_intensity = 0.9; env.glow_bloom = 0.25
		"ice", "frozen":
			env.glow_intensity = 0.5; env.glow_bloom = 0.10
		"void":
			env.glow_intensity = 1.0; env.glow_bloom = 0.30
		_:
			env.glow_intensity = 0.6; env.glow_bloom = 0.15

	# Update directional lights to match biome
	for child in _world3d_root.get_children():
		if child is DirectionalLight3D:
			if child.name == "SunLight":
				child.light_color = _biome_light_color.lerp(Color(0.85, 0.78, 0.95), 0.5)
				child.light_energy = 0.8 + _biome_light_energy * 0.1
			elif child.name == "FillLight":
				child.light_color = _biome_fog_color.lightened(0.3)

## Spawn ambient particles based on current biome.
func _spawn_biome_particles() -> void:
	if _particle_root == null: return
	for c in _particle_root.get_children():
		c.queue_free()

	var half: float = MAP_SIZE * 0.5
	var center: Vector3 = Vector3(half, 4.0, half)

	match _biome_prop_set:
		"cave":
			_add_ambient_particles(center, Color(0.45, 0.35, 0.20, 0.3), 0.08, 40, Vector3(0, -0.3, 0))
		"grassland":
			_add_ambient_particles(center, Color(0.80, 0.85, 0.50, 0.2), 0.04, 24, Vector3(0.2, 0.1, 0.1))
		"forest", "overgrown":
			_add_ambient_particles(center, Color(0.40, 0.60, 0.15, 0.3), 0.05, 36, Vector3(0.05, -0.15, 0.05))
		"volcanic", "infernal":
			_add_ambient_particles(center, Color(1.0, 0.45, 0.10, 0.5), 0.06, 50, Vector3(0, 0.6, 0))
		"ice", "frozen":
			_add_ambient_particles(center, Color(0.80, 0.90, 1.0, 0.4), 0.05, 40, Vector3(0.1, -0.4, 0.15))
		"aquatic", "coral":
			_add_ambient_particles(center, Color(0.30, 0.60, 0.85, 0.3), 0.06, 32, Vector3(0.05, 0.15, 0.05))
		"void":
			_add_ambient_particles(center, Color(0.50, 0.20, 0.80, 0.4), 0.04, 30, Vector3(0, 0.2, 0))
		"desert":
			_add_ambient_particles(center, Color(0.85, 0.75, 0.50, 0.2), 0.05, 28, Vector3(0.3, -0.1, 0.2))
		"swamp":
			_add_ambient_particles(center, Color(0.30, 0.50, 0.15, 0.35), 0.07, 40, Vector3(0, 0.1, 0))
		"necropolis":
			_add_ambient_particles(center, Color(0.20, 0.55, 0.15, 0.3), 0.05, 32, Vector3(0, 0.3, 0))
		"arcane":
			_add_ambient_particles(center, Color(0.55, 0.30, 0.90, 0.4), 0.04, 36, Vector3(0, 0.2, 0))
		"clockwork":
			_add_ambient_particles(center, Color(0.80, 0.60, 0.20, 0.2), 0.03, 20, Vector3(0, 0.15, 0))
		_:
			_add_ambient_particles(center, Color(0.50, 0.45, 0.35, 0.2), 0.05, 30, Vector3(0, -0.2, 0))

func _add_ambient_particles(pos: Vector3, color: Color, size: float,
		amount: int, direction: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 6.0
	particles.randomness = 0.8
	particles.visibility_aabb = AABB(Vector3(-15, -3, -15), Vector3(30, 10, 30))
	particles.position = pos

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(12.0, 3.0, 12.0)
	mat.direction = direction.normalized() if direction.length() > 0 else Vector3(0, -1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 0.1
	mat.initial_velocity_max = 0.5
	mat.gravity = Vector3(0.0, -0.05, 0.0)
	mat.damping_min = 0.5; mat.damping_max = 1.5
	mat.scale_min = 0.5; mat.scale_max = 1.5
	mat.color = color
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = size; mesh.height = size * 2
	particles.draw_pass_1 = mesh

	_particle_root.add_child(particles)

# ── Encounter banner ──────────────────────────────────────────────────────────
## Builds a thin colour-coded strip that sits above the content area.
## Visibility and text are set later by _update_banner().
func _build_banner() -> void:
	_banner_bar = ColorRect.new()
	_banner_bar.color = Color(0.30, 0.20, 0.05)
	_banner_bar.custom_minimum_size = Vector2(0, 30)
	_banner_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner_bar.visible = false

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	_banner_bar.add_child(margin)

	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 13)
	_banner_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.20))
	margin.add_child(_banner_label)

	add_child(_banner_bar)

func _update_banner() -> void:
	var dtype: int    = _e.get_dungeon_type()
	var dname: String = _e.get_dungeon_encounter_name()
	var tname: String = _e.get_dungeon_terrain_name()
	var terrain_suffix: String = (" — %s" % tname) if tname != "" and tname != "Cave" else ""

	match dtype:
		0:  # Standard — hide banner (terrain shown in header title only)
			_banner_bar.visible = false
		1:  # Kaiju
			_banner_bar.color = Color(0.50, 0.00, 0.00)
			_banner_label.text = "⚠  KAIJU HUNT — %s%s" % [dname, terrain_suffix]
			_banner_label.add_theme_color_override("font_color", Color(1.0, 0.80, 0.05))
			_banner_bar.visible = true
		2:  # Apex
			_banner_bar.color = Color(0.28, 0.00, 0.50)
			_banner_label.text = "✦  APEX ENCOUNTER — %s%s" % [dname, terrain_suffix]
			_banner_label.add_theme_color_override("font_color", Color(0.80, 0.58, 0.95))
			_banner_bar.visible = true
		3:  # Militia
			_banner_bar.color = Color(0.00, 0.38, 0.40)
			_banner_label.text = "🛡  MILITIA ENGAGEMENT — %s%s" % [dname, terrain_suffix]
			_banner_label.add_theme_color_override("font_color", Color(0.50, 0.88, 0.95))
			_banner_bar.visible = true
		4:  # Mob
			_banner_bar.color = Color(0.30, 0.20, 0.10)
			_banner_label.text = "👥  MOB ENCOUNTER — %s%s" % [dname, terrain_suffix]
			_banner_label.add_theme_color_override("font_color", Color(1.0, 0.80, 0.50))
			_banner_bar.visible = true

# ── Stash dialog ─────────────────────────────────────────────────────────────
func _build_stash_dialog() -> void:
	_stash_overlay = ColorRect.new()
	(_stash_overlay as ColorRect).color = Color(0.0, 0.0, 0.0, 0.68)
	_stash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stash_overlay.visible = false
	add_child(_stash_overlay)

	# Panel
	var panel := ColorRect.new()
	panel.color = Color(0.09, 0.08, 0.06)
	panel.custom_minimum_size = Vector2(380, 420)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -190.0
	panel.offset_right  =  190.0
	panel.offset_top    = -210.0
	panel.offset_bottom =  210.0
	_stash_overlay.add_child(panel)

	# Border
	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color(0, 0, 0, 0)
	border_style.border_width_left   = 2
	border_style.border_width_right  = 2
	border_style.border_width_top    = 2
	border_style.border_width_bottom = 2
	border_style.border_color = Color(0.55, 0.45, 0.18, 0.90)
	panel.add_theme_stylebox_override("panel", border_style)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(outer_vbox)

	# Header bar
	var header_bar := ColorRect.new()
	header_bar.color = Color(0.16, 0.13, 0.06)
	header_bar.custom_minimum_size = Vector2(0, 40)
	outer_vbox.add_child(header_bar)

	var hdr_margin := MarginContainer.new()
	hdr_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:
		hdr_margin.add_theme_constant_override("margin_" + side, 6)
	header_bar.add_child(hdr_margin)

	var hdr_hbox := HBoxContainer.new()
	hdr_margin.add_child(hdr_hbox)

	_stash_header = Label.new()
	_stash_header.text = "🎒  Party Stash  (0 items)"
	_stash_header.add_theme_font_size_override("font_size", 15)
	_stash_header.add_theme_color_override("font_color", Color(0.95, 0.80, 0.40))
	_stash_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_hbox.add_child(_stash_header)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(_on_close_stash)
	hdr_hbox.add_child(close_btn)

	# Scroll area for item list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(scroll)

	var scroll_margin := MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left","right","top","bottom"]:
		scroll_margin.add_theme_constant_override("margin_" + side, 8)
	scroll.add_child(scroll_margin)

	_stash_list_vbox = VBoxContainer.new()
	_stash_list_vbox.add_theme_constant_override("separation", 4)
	scroll_margin.add_child(_stash_list_vbox)

	# Footer note
	var footer := Label.new()
	footer.text = "Select a character on the left, then press Take to move items."
	footer.add_theme_font_size_override("font_size", 10)
	footer.add_theme_color_override("font_color", Color(0.55, 0.55, 0.52))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var footer_margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		footer_margin.add_theme_constant_override("margin_" + side, 6)
	footer_margin.add_child(footer)
	outer_vbox.add_child(footer_margin)

func _on_open_stash() -> void:
	_populate_stash_list()
	_stash_overlay.visible = true

func _on_close_stash() -> void:
	_stash_overlay.visible = false

func _populate_stash_list() -> void:
	for child in _stash_list_vbox.get_children():
		child.queue_free()

	var items: PackedStringArray = _e.get_stash_items()
	_stash_header.text = "🎒  Party Stash  (%d item%s)" % [items.size(), "s" if items.size() != 1 else ""]

	if items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "The stash is empty."
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.52))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stash_list_vbox.add_child(empty_lbl)
		return

	# Show each item individually (to display per-copy durability)
	var _hp_counter: Dictionary = {}  # track which copy index per item name
	for item_raw in items:
		var item_name: String = str(item_raw)
		var copy_idx: int = int(_hp_counter.get(item_name, 0))
		_hp_counter[item_name] = copy_idx + 1
		var item_hp: int = GameState.get_stash_item_hp(item_name, copy_idx)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var display_text: String = item_name
		# Add durability info for weapons/armor/shields
		var max_hp: int = _e._weapon_max_hp(item_name)
		if max_hp <= 0: max_hp = _e._armor_max_hp(item_name)
		if max_hp > 0 and item_hp >= 0:
			display_text += "  [%d/%d HP]" % [maxi(0, item_hp), max_hp]
		var name_lbl := Label.new()
		name_lbl.text = display_text
		name_lbl.add_theme_font_size_override("font_size", 13)
		var lbl_color: Color = Color(0.90, 0.85, 0.72)
		if max_hp > 0 and item_hp >= 0 and item_hp <= 0:
			lbl_color = Color(1.0, 0.5, 0.3)  # orange for broken
		name_lbl.add_theme_color_override("font_color", lbl_color)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		# "Equip" button — equips on selected character (weapons/armor/shields/lights)
		var cap_equip: String = item_name
		if _is_equipable_stash_item(item_name):
			var equip_btn := Button.new()
			equip_btn.text = "Equip"
			equip_btn.add_theme_font_size_override("font_size", 12)
			equip_btn.custom_minimum_size = Vector2(56, 0)
			equip_btn.pressed.connect(func():
				_on_stash_equip_item(cap_equip))
			row.add_child(equip_btn)

		# "Take" button — moves one copy to the selected character (if any)
		var take_btn := Button.new()
		take_btn.text = "Take"
		take_btn.add_theme_font_size_override("font_size", 12)
		take_btn.custom_minimum_size = Vector2(56, 0)
		var captured_name: String = item_name
		take_btn.pressed.connect(func():
			_on_stash_take_item(captured_name))
		row.add_child(take_btn)

		# "Drop" button — removes from stash entirely
		var drop_btn := Button.new()
		drop_btn.text = "Drop"
		drop_btn.add_theme_font_size_override("font_size", 12)
		drop_btn.custom_minimum_size = Vector2(52, 0)
		var captured_name2: String = item_name
		drop_btn.pressed.connect(func():
			_e.remove_from_stash(captured_name2)
			_populate_stash_list())
		row.add_child(drop_btn)

		var row_bg := PanelContainer.new()
		row_bg.add_child(row)
		_stash_list_vbox.add_child(row_bg)

func _build_equip_overlay() -> void:
	_equip_overlay = ColorRect.new()
	(_equip_overlay as ColorRect).color = Color(0.0, 0.0, 0.0, 0.68)
	_equip_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_equip_overlay.visible = false
	add_child(_equip_overlay)

	var panel := ColorRect.new()
	panel.color = Color(0.10, 0.09, 0.07)
	panel.custom_minimum_size = Vector2(420, 380)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	_equip_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + s, 14)
	margin.add_child(vbox)
	panel.add_child(margin)

	var title := Label.new()
	title.text = "⚔  Equipment"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.95, 0.80, 0.40))
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_equip_slots_vbox = VBoxContainer.new()
	_equip_slots_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equip_slots_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(_equip_slots_vbox)
	vbox.add_child(scroll)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.custom_minimum_size = Vector2(80, 36)
	close_btn.pressed.connect(func(): _equip_overlay.visible = false)
	vbox.add_child(close_btn)

func _on_open_equip_overlay() -> void:
	if _selected_id == "":
		_add_log("[color=orange]Select a character first.[/color]")
		return
	var ent: Dictionary = _get_entity(_selected_id)
	if ent.is_empty() or not bool(ent.get("is_player", false)):
		_add_log("[color=orange]Select a player character.[/color]")
		return
	_populate_equip_overlay(ent)
	_equip_overlay.visible = true

func _populate_equip_overlay(ent: Dictionary) -> void:
	for child in _equip_slots_vbox.get_children():
		child.queue_free()
	var handle: int = int(ent.get("handle", -1))
	if handle < 0 or not _e._chars.has(handle): return
	var c: Dictionary = _e._chars[handle]
	var char_name: String = str(ent["name"])

	# Current equipment display with durability
	var slots: Array = [
		["⚔ Weapon", "weapon", str(c.get("weapon", "None"))],
		["🛡 Armor", "armor", str(c.get("armor", "None"))],
		["🔰 Shield", "shield", str(c.get("shield", "None"))],
		["🔥 Light", "light", str(c.get("light", "None"))],
	]
	for slot_data in slots:
		var label_prefix: String = slot_data[0]
		var slot_key: String = slot_data[1]
		var item_name: String = slot_data[2]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var lbl := Label.new()
		if item_name == "None" or item_name == "":
			lbl.text = "%s: (empty)" % label_prefix
			lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			var dur_str: String = ""
			if slot_key in ["weapon", "armor", "shield"]:
				var cur_hp: int = _e._get_equip_hp(c, slot_key)
				var max_hp: int = _e._get_equip_max_hp(c, slot_key)
				if max_hp > 0:
					dur_str = "  [%d/%d HP]" % [maxi(0, cur_hp), max_hp]
					if cur_hp <= 0:
						dur_str += " BROKEN"
			lbl.text = "%s: %s%s" % [label_prefix, item_name, dur_str]
			lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		# Unequip button
		if item_name != "None" and item_name != "":
			var unequip_btn := Button.new()
			unequip_btn.text = "Unequip"
			unequip_btn.add_theme_font_size_override("font_size", 11)
			unequip_btn.custom_minimum_size = Vector2(70, 0)
			var cap_slot: String = slot_key; var cap_item: String = item_name
			unequip_btn.pressed.connect(func():
				_on_unequip_slot(handle, cap_slot, cap_item)
				_populate_equip_overlay(ent))
			row.add_child(unequip_btn)
		_equip_slots_vbox.add_child(row)

	# Separator + available items from stash
	_equip_slots_vbox.add_child(RimvaleUtils.separator())
	var stash_title := Label.new()
	stash_title.text = "Equip from Stash:"
	stash_title.add_theme_font_size_override("font_size", 13)
	stash_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_equip_slots_vbox.add_child(stash_title)

	var stash_items: PackedStringArray = _e.get_stash_items()
	var equipable_items: Array = []
	var _eq_hp_idx: Dictionary = {}
	for item in stash_items:
		var s: String = str(item)
		if not _is_equipable_stash_item(s): continue
		var cidx: int = int(_eq_hp_idx.get(s, 0))
		_eq_hp_idx[s] = cidx + 1
		var ihp: int = GameState.get_stash_item_hp(s, cidx)
		equipable_items.append([s, ihp])

	if equipable_items.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No equipable items in stash."
		none_lbl.add_theme_font_size_override("font_size", 11)
		none_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_equip_slots_vbox.add_child(none_lbl)
	else:
		for eq_entry in equipable_items:
			var iname: String = eq_entry[0]
			var ihp: int = eq_entry[1]
			var irow := HBoxContainer.new()
			irow.add_theme_constant_override("separation", 6)
			var display: String = iname
			var imhp: int = _e._weapon_max_hp(iname)
			if imhp <= 0: imhp = _e._armor_max_hp(iname)
			if imhp > 0 and ihp >= 0:
				display += "  [%d/%d HP]" % [maxi(0, ihp), imhp]
			var ilbl := Label.new()
			ilbl.text = display
			ilbl.add_theme_font_size_override("font_size", 12)
			ilbl.add_theme_color_override("font_color", Color(0.8, 0.9, 0.75) if ihp != 0 else Color(1.0, 0.5, 0.3))
			ilbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			irow.add_child(ilbl)
			var eq_btn := Button.new()
			eq_btn.text = "Equip"
			eq_btn.add_theme_font_size_override("font_size", 11)
			eq_btn.custom_minimum_size = Vector2(60, 0)
			var cap_iname: String = iname
			eq_btn.pressed.connect(func():
				_on_stash_equip_item(cap_iname)
				_populate_equip_overlay(ent))
			irow.add_child(eq_btn)
			_equip_slots_vbox.add_child(irow)

func _on_unequip_slot(handle: int, slot: String, item_name: String) -> void:
	if not _e._chars.has(handle): return
	var c: Dictionary = _e._chars[handle]
	# Save current durability HP before unequipping
	var cur_hp: int = -1  # -1 = full
	if slot in ["weapon", "armor", "shield"]:
		cur_hp = _e._get_equip_hp(c, slot)
	# Move item back to stash with its durability
	_e.add_to_stash(item_name, cur_hp)
	# Clear the slot
	if slot == "light":
		c["light"] = "None"
	else:
		c[slot] = "None"
		if slot == "weapon":
			c["equipped_weapon"] = "None"
		if slot in ["armor", "shield"]:
			c["ac"] = _e._compute_ac(handle)
	# Sync entity
	var ent: Dictionary = _get_entity(_selected_id)
	if not ent.is_empty():
		ent["equipped_weapon"] = str(c.get("weapon", "None"))
		ent["equipped_light"] = str(c.get("light", "None"))
		ent["ac"] = int(c.get("ac", 10))
	_add_log("[color=gold]%s unequips %s (returned to stash).[/color]" % [
		str(_e.get_character_name(handle)), item_name])
	_refresh()

func _is_equipable_stash_item(item_name: String) -> bool:
	# Check if item is a weapon, armor, shield, or light source
	var details: PackedStringArray = _e._format_item_details(item_name)
	if details.size() >= 5:
		var ui_type: String = str(details[4])
		if ui_type in ["Weapon", "Armor", "Shield", "Light"]:
			return true
	# Fallback: check exact name lists on engine
	if item_name in _e._WEAPON_EXACT: return true
	if _e._ARMOR_EXACT.has(item_name): return true
	if item_name in _e._LIGHT_EXACT: return true
	return false

func _on_stash_equip_item(item_name: String) -> void:
	if _selected_id == "":
		_add_log("[color=orange]Select a character first to equip the item.[/color]")
		return
	var ent: Dictionary = _get_entity(_selected_id)
	if ent.is_empty() or not bool(ent.get("is_player", false)):
		_add_log("[color=orange]Select a player character to equip the item.[/color]")
		return
	var handle: int = int(ent.get("handle", -1))
	if handle < 0:
		_add_log("[color=orange]No valid character handle.[/color]")
		return
	# Remove from stash (returns stored HP), equip on character
	var stored_hp: int = _e.remove_from_stash(item_name)
	_e.equip_item(handle, item_name)
	# Apply stored durability HP if not full
	if stored_hp >= 0 and _e._chars.has(handle):
		var c: Dictionary = _e._chars[handle]
		# Determine which slot was equipped
		if str(c.get("weapon", "")) == item_name:
			c["weapon_hp"] = stored_hp
		elif str(c.get("armor", "")) == item_name:
			c["armor_hp"] = stored_hp
		elif str(c.get("shield", "")) == item_name:
			c["shield_hp"] = stored_hp
	# Sync entity equipped_weapon / equipped_light if relevant
	if _e._chars.has(handle):
		var c: Dictionary = _e._chars[handle]
		ent["equipped_weapon"] = str(c.get("weapon", "None"))
		ent["equipped_light"] = str(c.get("light", "None"))
		ent["ac"] = int(c.get("ac", 10))
	_add_log("[color=gold]%s equips %s from the stash.[/color]" % [str(ent["name"]), item_name])
	_populate_stash_list()
	_refresh()

func _on_stash_take_item(item_name: String) -> void:
	# Move item to selected player (if a player is selected)
	if _selected_id == "":
		_add_log("[color=orange]Select a character first.[/color]")
		return
	var ent: Dictionary = _get_entity(_selected_id)
	if ent.is_empty() or not bool(ent["is_player"]):
		_add_log("[color=orange]Select a player character to receive the item.[/color]")
		return
	var handle: int = int(ent.get("handle", -1))
	if handle < 0:
		_add_log("[color=orange]No valid character handle.[/color]")
		return
	_e.move_stash_item_to_character(item_name, handle)
	_add_log("[color=gold]%s takes %s from the stash.[/color]" % [str(ent["name"]), item_name])
	_populate_stash_list()

# ── Victory / Defeat modal ────────────────────────────────────────────────────
func _build_victory_modal() -> void:
	_modal = ColorRect.new()
	(_modal as ColorRect).color = Color(0.0, 0.0, 0.0, 0.72)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.visible = false
	add_child(_modal)

	# Centred panel
	var panel := ColorRect.new()
	panel.color = Color(0.10, 0.09, 0.07)
	panel.custom_minimum_size = Vector2(380, 280)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -190.0
	panel.offset_right  =  190.0
	panel.offset_top    = -140.0
	panel.offset_bottom =  140.0
	_modal.add_child(panel)

	# Border
	var border := ColorRect.new()
	border.color = Color(0.0, 0.0, 0.0, 0.0)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color(0, 0, 0, 0)
	border_style.border_width_left   = 2
	border_style.border_width_right  = 2
	border_style.border_width_top    = 2
	border_style.border_width_bottom = 2
	border_style.border_color = Color(0.65, 0.55, 0.20, 0.90)
	panel.add_theme_stylebox_override("panel", border_style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	vbox.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	margin.add_child(inner)

	_modal_title = Label.new()
	_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_title.add_theme_font_size_override("font_size", 32)
	inner.add_child(_modal_title)

	var divider := ColorRect.new()
	divider.color = Color(0.50, 0.42, 0.15, 0.60)
	divider.custom_minimum_size = Vector2(0, 2)
	inner.add_child(divider)

	_modal_body = Label.new()
	_modal_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_body.add_theme_font_size_override("font_size", 14)
	_modal_body.add_theme_color_override("font_color", Color(0.85, 0.82, 0.72))
	_modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_modal_body)

	_modal_btn = Button.new()
	_modal_btn.text = "Back to Map"
	_modal_btn.add_theme_font_size_override("font_size", 16)
	_modal_btn.custom_minimum_size = Vector2(180, 40)
	_modal_btn.pressed.connect(_on_back)
	inner.add_child(_modal_btn)

## Call after every action to check whether the combat has ended.
func _check_outcome() -> void:
	if _outcome != "ongoing": return
	var result: String = _e.check_dungeon_outcome()
	if result == "ongoing": return
	_outcome = result
	# Disable action buttons
	_btn_next_unit.disabled = true
	_btn_end_phase.disabled = true
	if result == "victory":
		_phase_label.text = "VICTORY!"
		_phase_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.10))
		_add_log("[color=gold]✦ All enemies defeated! Victory![/color]")
		_add_log("[color=yellow]You may continue exploring. Press \"End Dungeon\" when ready.[/color]")
		# Re-enable movement so the player can keep exploring
		_btn_next_unit.disabled = false
		_btn_end_phase.disabled = false
		# Show the End Dungeon button
		_btn_end_dungeon.visible = true
	else:
		_phase_label.text = "DEFEAT"
		_phase_label.add_theme_color_override("font_color", Color(0.85, 0.20, 0.20))
		_add_log("[color=red]✗ Your party has fallen![/color]")
		# Defeat: show modal immediately
		_show_outcome_modal.call_deferred(result)

func _on_end_dungeon_pressed() -> void:
	_btn_end_dungeon.visible = false
	_btn_next_unit.disabled = true
	_btn_end_phase.disabled = true
	_show_outcome_modal("victory")

func _show_outcome_modal(result: String) -> void:
	if result == "victory":
		_modal_title.text = "✦ VICTORY ✦"
		_modal_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.20))
		# Slow pulsing glow on the victory title
		var tween := create_tween()
		tween.set_loops()
		tween.tween_property(_modal_title, "modulate", Color(1.0, 1.0, 1.0, 0.55), 1.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(_modal_title, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

		var data: Dictionary = _e.get_dungeon_outcome_data()
		var xp: int   = int(data.get("xp",   0))
		var gold: int = int(data.get("gold",  0))
		var raw_items = data.get("items", PackedStringArray())
		var item_lines: Array = []
		for it in raw_items:
			var s: String = str(it)
			if not s.contains("Gold Coin"):
				item_lines.append(s)
				# Auto-add non-gold loot to stash with randomized durability
				_e.add_to_stash_with_random_hp(s)

		# ── Award rewards to GameState ──────────────────────────────────────────
		# complete_dungeon_quest awards the dungeon drops + any linked quest bonus
		var completed_quest: Dictionary = GameState.complete_dungeon_quest(gold, xp)

		# Check for level-up (check_level_up called inside complete_dungeon_quest)
		var level_up_str: String = ""
		if GameState.player_level > 1 and GameState.player_xp < 50:
			# Rough heuristic: freshly leveled up (XP was reset)
			level_up_str = "\n\n🎉 Level Up! You are now Level %d (%s)!" % [
				GameState.player_level, GameState.player_rank]

		var total_gold: int = gold + int(completed_quest.get("reward_gold", 0))
		var total_xp:   int = xp   + int(completed_quest.get("reward_xp",   0))
		var item_str: String = "\n".join(item_lines) if not item_lines.is_empty() else "—"

		var quest_str: String = ""
		if not completed_quest.is_empty():
			quest_str = "\n\n✦ Quest Complete: %s\nBonus: +%dg +%dxp" % [
				str(completed_quest.get("title", "Unknown")),
				int(completed_quest.get("reward_gold", 0)),
				int(completed_quest.get("reward_xp",   0))]

		_modal_body.text = (
			"XP Earned: %d\nGold: +%d\n\nLoot added to stash:\n%s%s%s" % [
				total_xp, total_gold, item_str, quest_str, level_up_str]
		)
		_modal_btn.text = "Back to Map"
	else:
		_modal_title.text = "✗  DEFEAT"
		_modal_title.add_theme_color_override("font_color", Color(0.85, 0.20, 0.15))
		_modal_body.text = "Your party has fallen.\nAll players have been defeated."
		_modal_btn.text  = "Back to Map"
		# Still clear the active quest on defeat (no rewards)
		GameState.clear_active_dungeon_quest()

	_modal.visible = true

# ── Custom Spell Dialog (Full PHB Spell Builder) ─────────────────────────────

func _sb_calc_cost() -> int:
	# Teleport spells: cost is based on max distance (pre-paid)
	if _sb_is_teleport:
		return maxi(1, (_sb_tp_range + 1) / 2)
	var type_cost: int   = 1 if _sb_is_saving_throw else 0
	var sides_mod: int   = SB_DIE_SIDES_MOD[_sb_die_idx] if _sb_die_idx < SB_DIE_SIDES_MOD.size() else 0
	var dice_cost: int   = _sb_die_count * (1 + sides_mod)
	var dur_mult: int    = SB_DURATION_MULT[_sb_duration_idx] if _sb_duration_idx < SB_DURATION_MULT.size() else 1
	var effects: Array   = SB_DOMAIN_EFFECTS[_sb_domain] if _sb_domain < SB_DOMAIN_EFFECTS.size() else []
	var effect_base: int = int(effects[_sb_effect_idx][1]) if _sb_effect_idx < effects.size() else 1
	var base_effect: int = effect_base + dice_cost
	var base_with_dur: int = base_effect if _sb_duration_idx == 0 else base_effect * dur_mult
	var range_cost: int  = SB_RANGE_SP_COST[_sb_range_idx] if _sb_range_idx < SB_RANGE_SP_COST.size() else 0
	var target_cost: int = 0
	if _sb_targets > 1:
		for i in range(_sb_targets - 1):
			target_cost += int(pow(2.0, float(i + 1)))
	var harmful: int    = 0
	var beneficial: int = 0
	for cname in _sb_conditions:
		if cname in SB_CONDITIONS_HARMFUL: harmful += 1
		else: beneficial += 1
	var cond_cost: int   = (harmful * 3) - (beneficial * 2)
	var area_mult: int   = SB_AREA_MULT[_sb_area_idx] if _sb_area_idx < SB_AREA_MULT.size() else 1
	var base_sum: int    = type_cost + base_with_dur + range_cost + target_cost + cond_cost
	var total: int       = base_sum * area_mult
	if total <= 0 and (dur_mult > 1 or area_mult > 1):
		total = 1
	elif total < 0:
		total = 0
	return total

func _sb_update_preview() -> void:
	if not is_instance_valid(_sb_preview_lbl): return
	var cost: int = _sb_calc_cost()
	_sb_preview_lbl.text = "Total SP Cost: %d" % cost

	if is_instance_valid(_sb_breakdown_lbl):
		var effects: Array = SB_DOMAIN_EFFECTS[_sb_domain] if _sb_domain < SB_DOMAIN_EFFECTS.size() else []
		var effect_name: String = effects[_sb_effect_idx][0] if _sb_effect_idx < effects.size() else "Unknown"
		var effect_base: int = int(effects[_sb_effect_idx][1]) if _sb_effect_idx < effects.size() else 1
		var sides_mod: int = SB_DIE_SIDES_MOD[_sb_die_idx] if _sb_die_idx < SB_DIE_SIDES_MOD.size() else 0
		var dice_cost: int = _sb_die_count * (1 + sides_mod)
		var dur_mult: int  = SB_DURATION_MULT[_sb_duration_idx] if _sb_duration_idx < SB_DURATION_MULT.size() else 1
		var range_cost: int = SB_RANGE_SP_COST[_sb_range_idx] if _sb_range_idx < SB_RANGE_SP_COST.size() else 0
		var target_cost: int = 0
		if _sb_targets > 1:
			for i in range(_sb_targets - 1):
				target_cost += int(pow(2.0, float(i + 1)))
		var harmful: int = 0; var beneficial: int = 0
		for cname in _sb_conditions:
			if cname in SB_CONDITIONS_HARMFUL: harmful += 1
			else: beneficial += 1
		var cond_cost: int = (harmful * 3) - (beneficial * 2)
		var area_mult: int = SB_AREA_MULT[_sb_area_idx] if _sb_area_idx < SB_AREA_MULT.size() else 1

		var lines: PackedStringArray = []
		lines.append("Base Effect (%s): %d" % [effect_name, effect_base])
		if dice_cost > 0:
			lines.append("Dice (%dd%d): +%d" % [_sb_die_count, [4,6,8,10,12][_sb_die_idx], dice_cost])
		if dur_mult > 1:
			lines.append("Duration (x%d): applied" % dur_mult)
		if range_cost > 0:
			lines.append("Range (%s): +%d" % [SB_RANGE_LABELS[_sb_range_idx], range_cost])
		if target_cost > 0:
			lines.append("Multi-target (%d): +%d" % [_sb_targets, target_cost])
		if cond_cost != 0:
			lines.append("Conditions: %s%d" % ["+" if cond_cost > 0 else "", cond_cost])
		if _sb_is_saving_throw:
			lines.append("Saving throw: +1")
		if area_mult > 1:
			lines.append("Area (x%d): applied" % area_mult)
		if _sb_is_combustion:
			lines.append("Combustion: damage scales with SP spent")
		if _sb_is_teleport:
			lines.clear()
			lines.append("Teleport Distance: %d tiles (%dft)" % [_sb_tp_range, _sb_tp_range * 5])
			lines.append("Cost: (%d + 1) / 2 = %d SP (pre-paid)" % [_sb_tp_range, maxi(1, (_sb_tp_range + 1) / 2)])
		_sb_breakdown_lbl.text = "\n".join(lines)

	if is_instance_valid(_sb_desc_lbl):
		_sb_desc_lbl.text = _sb_gen_description()

func _sb_gen_description() -> String:
	var effects_arr: Array = SB_DOMAIN_EFFECTS[_sb_domain] if _sb_domain < SB_DOMAIN_EFFECTS.size() else []
	var effect_name: String = effects_arr[_sb_effect_idx][0] if _sb_effect_idx < effects_arr.size() else "Unknown"
	var domain_name: String = SB_DOMAIN_NAMES[_sb_domain] if _sb_domain < SB_DOMAIN_NAMES.size() else "Unknown"
	var target_desc: String = "a single target" if _sb_targets <= 1 else "up to %d targets" % _sb_targets
	var range_desc: String = "on yourself" if _sb_range_idx == 0 else "within %s" % SB_RANGE_LABELS[_sb_range_idx]
	var area_desc: String = "" if _sb_area_idx == 0 else " affecting a %s" % SB_AREA_LABELS[_sb_area_idx]
	var dur_desc: String = SB_DURATION_LABELS[_sb_duration_idx]
	var save_desc: String = ". Targets may roll a saving throw to resist." if _sb_is_saving_throw else "."

	if _sb_is_teleport:
		return "Teleport a target up to %d tiles (%dft). SP pre-paid at creation; costs only AP to cast." % [_sb_tp_range, _sb_tp_range * 5]

	if _sb_is_combustion:
		return "Using the %s domain, you cause a violent combustion targeting %s %s%s. Damage dice scale dynamically with total SP spent (half SP on the scaling table). Lasts %s%s" % [
			domain_name, target_desc, range_desc, area_desc, dur_desc, save_desc]

	var action_word: String = "heals for" if _sb_is_healing else "deals"
	var dice_desc: String = ""
	if _sb_die_count > 0:
		dice_desc = " %dd%d" % [_sb_die_count, [4,6,8,10,12][_sb_die_idx]]
	var type_desc: String = ""
	if not _sb_is_healing and _sb_die_count > 0:
		type_desc = " %s damage" % SB_DAMAGE_TYPES[_sb_damage_type]
	elif _sb_is_healing and _sb_die_count > 0:
		type_desc = " hit points"

	return "Using the %s domain, you weave a spell of %s that %s%s%s targeting %s %s%s. Lasts %s%s" % [
		domain_name, effect_name, action_word, dice_desc, type_desc,
		target_desc, range_desc, area_desc, dur_desc, save_desc]

func _build_custom_spell_dialog() -> void:
	_spell_overlay = ColorRect.new()
	(_spell_overlay as ColorRect).color = Color(0.0, 0.0, 0.0, 0.72)
	_spell_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spell_overlay.visible = false
	add_child(_spell_overlay)

	# Scrollable panel so the full builder fits on any screen
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.07, 0.12)
	panel_style.corner_radius_top_left = 8; panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8; panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -260.0
	panel.offset_right  =  260.0
	panel.offset_top    = -340.0
	panel.offset_bottom =  340.0
	_spell_overlay.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)

	_spell_inner = VBoxContainer.new()
	_spell_inner.add_theme_constant_override("separation", 6)
	_spell_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_spell_inner)

	_sb_populate_inner()

func _sb_populate_inner() -> void:
	# Remove all existing children immediately (not queue_free, so they're gone now)
	for c in _spell_inner.get_children():
		_spell_inner.remove_child(c)
		c.queue_free()
	var inner: VBoxContainer = _spell_inner
	_sb_preview_lbl = null
	_sb_breakdown_lbl = null
	_sb_desc_lbl = null

	# ── Title ──
	var title_lbl := Label.new()
	title_lbl.text = "✨ PHB Spell Builder"
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.70, 1.0))
	inner.add_child(title_lbl)
	inner.add_child(_hsep())

	# ── Spell Name ──
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Spell name..."
	name_edit.text = _sb_name
	name_edit.custom_minimum_size = Vector2(200, 36)
	name_edit.add_theme_font_size_override("font_size", 14)
	name_edit.text_changed.connect(func(t: String): _sb_name = t)
	inner.add_child(_spell_row("Name:", name_edit))

	# ── Domain ──
	var domain_opt := OptionButton.new()
	for dn in SB_DOMAIN_NAMES:
		domain_opt.add_item(dn)
	domain_opt.selected = _sb_domain
	domain_opt.item_selected.connect(func(i: int):
		_sb_domain = i
		_sb_effect_idx = 0
		_sb_populate_inner()
	)
	inner.add_child(_spell_row("Domain:", domain_opt))

	# ── Effect (per domain) ──
	var effect_opt := OptionButton.new()
	var effects_for_domain: Array = SB_DOMAIN_EFFECTS[_sb_domain] if _sb_domain < SB_DOMAIN_EFFECTS.size() else []
	for ef in effects_for_domain:
		effect_opt.add_item(ef[0])
	effect_opt.selected = mini(_sb_effect_idx, max(0, effects_for_domain.size() - 1))
	effect_opt.item_selected.connect(func(i: int):
		_sb_effect_idx = i
		_sb_update_preview()
	)
	inner.add_child(_spell_row("Effect:", effect_opt))

	# ── Duration ──
	var dur_opt := OptionButton.new()
	for dl in SB_DURATION_LABELS:
		dur_opt.add_item(dl)
	dur_opt.selected = _sb_duration_idx
	dur_opt.item_selected.connect(func(i: int):
		_sb_duration_idx = i
		_sb_update_preview()
	)
	inner.add_child(_spell_row("Duration:", dur_opt))

	# ── Range ──
	var range_opt := OptionButton.new()
	for rl in SB_RANGE_LABELS:
		range_opt.add_item(rl)
	range_opt.selected = _sb_range_idx
	range_opt.item_selected.connect(func(i: int):
		_sb_range_idx = i
		_sb_update_preview()
	)
	inner.add_child(_spell_row("Range:", range_opt))

	# ── Targets (slider 1-10) ──
	var tgt_lbl := Label.new()
	tgt_lbl.text = "Targets: %d" % _sb_targets
	tgt_lbl.add_theme_font_size_override("font_size", 13)
	tgt_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.75))
	inner.add_child(tgt_lbl)
	var tgt_slider := HSlider.new()
	tgt_slider.min_value = 1; tgt_slider.max_value = 10; tgt_slider.step = 1
	tgt_slider.value = _sb_targets
	tgt_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tgt_slider.value_changed.connect(func(v: float):
		_sb_targets = int(v)
		tgt_lbl.text = "Targets: %d" % _sb_targets
		_sb_update_preview()
	)
	inner.add_child(tgt_slider)

	# ── Area ──
	var area_opt := OptionButton.new()
	for al in SB_AREA_LABELS:
		area_opt.add_item(al)
	area_opt.selected = _sb_area_idx
	area_opt.item_selected.connect(func(i: int):
		_sb_area_idx = i
		_sb_update_preview()
	)
	inner.add_child(_spell_row("Area:", area_opt))

	inner.add_child(_hsep())

	# ── Dice Count (slider 0-10) ──
	var dice_lbl := Label.new()
	dice_lbl.text = "Dice Count: %d" % _sb_die_count
	dice_lbl.add_theme_font_size_override("font_size", 13)
	dice_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.75))
	inner.add_child(dice_lbl)
	var dice_slider := HSlider.new()
	dice_slider.min_value = 0; dice_slider.max_value = 10; dice_slider.step = 1
	dice_slider.value = _sb_die_count
	dice_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dice_slider.value_changed.connect(func(v: float):
		_sb_die_count = int(v)
		dice_lbl.text = "Dice Count: %d" % _sb_die_count
		_sb_update_preview()
	)
	inner.add_child(dice_slider)

	# ── Die Type (d4 d6 d8 d10 d12 buttons) ──
	var die_lbl := Label.new()
	die_lbl.text = "Die Type"
	die_lbl.add_theme_font_size_override("font_size", 13)
	die_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.75))
	inner.add_child(die_lbl)
	var die_row := HBoxContainer.new()
	die_row.add_theme_constant_override("separation", 4)
	var die_btns: Array = []
	for di in range(SB_DIE_LABELS.size()):
		var di_cap: int = di
		var col: Color = Color(0.55, 0.35, 0.85) if di == _sb_die_idx else Color(0.45, 0.45, 0.50)
		var dbtn := _colored_btn(SB_DIE_LABELS[di], col)
		dbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dbtn.custom_minimum_size = Vector2(0, 30)
		var btns_ref: Array = die_btns
		dbtn.pressed.connect(func():
			_sb_die_idx = di_cap
			for k in range(btns_ref.size()):
				var c2: Color = Color(0.55, 0.35, 0.85) if k == _sb_die_idx else Color(0.45, 0.45, 0.50)
				var sb2 := StyleBoxFlat.new()
				sb2.bg_color = c2
				sb2.corner_radius_top_left = 4; sb2.corner_radius_top_right = 4
				sb2.corner_radius_bottom_left = 4; sb2.corner_radius_bottom_right = 4
				btns_ref[k].add_theme_stylebox_override("normal", sb2)
			_sb_update_preview()
		)
		die_btns.append(dbtn)
		die_row.add_child(dbtn)
	inner.add_child(die_row)

	# ── Damage Type (all 13 PHB types) ──
	var dmg_opt := OptionButton.new()
	for dt in SB_DAMAGE_TYPES:
		dmg_opt.add_item(dt)
	dmg_opt.selected = _sb_damage_type
	dmg_opt.item_selected.connect(func(i: int):
		_sb_damage_type = i
		_sb_update_preview()
	)
	inner.add_child(_spell_row("Damage Type:", dmg_opt))

	inner.add_child(_hsep())

	# ── Flags row: Healing, Saving Throw, Teleport, Combustion ──
	var flag_row1 := HBoxContainer.new()
	flag_row1.add_theme_constant_override("separation", 14)
	var heal_chk := CheckBox.new(); heal_chk.text = "Healing"
	heal_chk.button_pressed = _sb_is_healing
	heal_chk.add_theme_font_size_override("font_size", 12)
	heal_chk.toggled.connect(func(b: bool): _sb_is_healing = b; _sb_update_preview())
	flag_row1.add_child(heal_chk)
	var save_chk := CheckBox.new(); save_chk.text = "Save (no atk)"
	save_chk.button_pressed = _sb_is_saving_throw
	save_chk.add_theme_font_size_override("font_size", 12)
	save_chk.toggled.connect(func(b: bool): _sb_is_saving_throw = b; _sb_update_preview())
	flag_row1.add_child(save_chk)
	inner.add_child(flag_row1)

	var flag_row2 := HBoxContainer.new()
	flag_row2.add_theme_constant_override("separation", 14)
	var tp_chk := CheckBox.new(); tp_chk.text = "Teleport"
	tp_chk.button_pressed = _sb_is_teleport
	tp_chk.add_theme_font_size_override("font_size", 12)
	tp_chk.toggled.connect(func(b: bool):
		_sb_is_teleport = b
		if _sb_tp_range_row != null: _sb_tp_range_row.visible = b
		_sb_update_preview()
	)
	flag_row2.add_child(tp_chk)

	# Teleport distance slider (visible only when teleport is checked)
	_sb_tp_range_row = HBoxContainer.new()
	_sb_tp_range_row.add_theme_constant_override("separation", 8)
	_sb_tp_range_row.visible = _sb_is_teleport
	var sb_tp_lbl := Label.new()
	sb_tp_lbl.text = "Teleport Distance (tiles):"
	sb_tp_lbl.add_theme_font_size_override("font_size", 12)
	_sb_tp_range_row.add_child(sb_tp_lbl)
	var sb_tp_val := Label.new()
	sb_tp_val.text = str(_sb_tp_range)
	sb_tp_val.add_theme_font_size_override("font_size", 13)
	sb_tp_val.add_theme_color_override("font_color", Color(0.40, 0.80, 1.0))
	sb_tp_val.custom_minimum_size = Vector2(30, 0)
	_sb_tp_range_row.add_child(sb_tp_val)
	var sb_tp_slider := HSlider.new()
	sb_tp_slider.min_value = 1; sb_tp_slider.max_value = 20; sb_tp_slider.step = 1
	sb_tp_slider.value = _sb_tp_range
	sb_tp_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sb_tp_slider.custom_minimum_size = Vector2(120, 0)
	sb_tp_slider.value_changed.connect(func(v: float):
		_sb_tp_range = int(v)
		sb_tp_val.text = str(_sb_tp_range)
		_sb_update_preview()
	)
	_sb_tp_range_row.add_child(sb_tp_slider)
	inner.add_child(_sb_tp_range_row)

	var comb_chk := CheckBox.new(); comb_chk.text = "Combustion (dynamic dmg)"
	comb_chk.button_pressed = _sb_is_combustion
	comb_chk.add_theme_font_size_override("font_size", 12)
	comb_chk.toggled.connect(func(b: bool): _sb_is_combustion = b; _sb_update_preview())
	flag_row2.add_child(comb_chk)
	inner.add_child(flag_row2)

	inner.add_child(_hsep())

	# ── Conditions (two columns: Beneficial | Harmful) ──
	var cond_title := Label.new()
	cond_title.text = "Conditions"
	cond_title.add_theme_font_size_override("font_size", 14)
	cond_title.add_theme_color_override("font_color", Color.WHITE)
	inner.add_child(cond_title)

	var cond_outer := HBoxContainer.new()
	cond_outer.add_theme_constant_override("separation", 12)
	inner.add_child(cond_outer)

	# Beneficial column
	var ben_col := VBoxContainer.new()
	ben_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ben_col.add_theme_constant_override("separation", 0)
	cond_outer.add_child(ben_col)
	var ben_hdr := Label.new()
	ben_hdr.text = "Beneficial (-2 SP each)"
	ben_hdr.add_theme_font_size_override("font_size", 11)
	ben_hdr.add_theme_color_override("font_color", Color(0.30, 0.69, 0.31))
	ben_col.add_child(ben_hdr)
	for cname in SB_CONDITIONS_BENEFICIAL:
		var cn_cap: String = cname
		var chk := CheckBox.new()
		chk.text = cname
		chk.button_pressed = cname in _sb_conditions
		chk.add_theme_font_size_override("font_size", 11)
		chk.toggled.connect(func(b: bool):
			if b:
				if cn_cap not in _sb_conditions: _sb_conditions.append(cn_cap)
			else:
				_sb_conditions.erase(cn_cap)
			_sb_update_preview()
		)
		ben_col.add_child(chk)

	# Harmful column
	var harm_col := VBoxContainer.new()
	harm_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	harm_col.add_theme_constant_override("separation", 0)
	cond_outer.add_child(harm_col)
	var harm_hdr := Label.new()
	harm_hdr.text = "Harmful (+3 SP each)"
	harm_hdr.add_theme_font_size_override("font_size", 11)
	harm_hdr.add_theme_color_override("font_color", Color(0.90, 0.40, 0.40))
	harm_col.add_child(harm_hdr)
	for cname in SB_CONDITIONS_HARMFUL:
		var cn_cap: String = cname
		var chk := CheckBox.new()
		chk.text = cname
		chk.button_pressed = cname in _sb_conditions
		chk.add_theme_font_size_override("font_size", 11)
		chk.toggled.connect(func(b: bool):
			if b:
				if cn_cap not in _sb_conditions: _sb_conditions.append(cn_cap)
			else:
				_sb_conditions.erase(cn_cap)
			_sb_update_preview()
		)
		harm_col.add_child(chk)

	inner.add_child(_hsep())

	# ── SP Cost Preview Card ──
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.14, 0.12, 0.22, 1.0)
	card_style.corner_radius_top_left = 8; card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8; card_style.corner_radius_bottom_right = 8
	card_style.content_margin_left = 14.0; card_style.content_margin_right = 14.0
	card_style.content_margin_top = 12.0; card_style.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", card_style)
	inner.add_child(card)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)
	card.add_child(card_vbox)

	_sb_preview_lbl = Label.new()
	_sb_preview_lbl.text = "Total SP Cost: --"
	_sb_preview_lbl.add_theme_font_size_override("font_size", 18)
	_sb_preview_lbl.add_theme_color_override("font_color", Color(0.74, 0.40, 1.0))
	card_vbox.add_child(_sb_preview_lbl)

	_sb_breakdown_lbl = Label.new()
	_sb_breakdown_lbl.text = ""
	_sb_breakdown_lbl.add_theme_font_size_override("font_size", 11)
	_sb_breakdown_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60))
	_sb_breakdown_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(_sb_breakdown_lbl)

	var desc_hdr := Label.new()
	desc_hdr.text = "Description:"
	desc_hdr.add_theme_font_size_override("font_size", 12)
	desc_hdr.add_theme_color_override("font_color", Color.WHITE)
	card_vbox.add_child(desc_hdr)

	_sb_desc_lbl = Label.new()
	_sb_desc_lbl.text = ""
	_sb_desc_lbl.add_theme_font_size_override("font_size", 11)
	_sb_desc_lbl.add_theme_color_override("font_color", Color(0.70, 0.75, 0.85))
	_sb_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(_sb_desc_lbl)

	_sb_update_preview()

	# ── Buttons ──
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	inner.add_child(btn_row)

	var btn_learn := _colored_btn("✨ Learn Spell", Color(0.22, 0.10, 0.35))
	btn_learn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_learn.pressed.connect(_on_learn_custom_spell)
	btn_row.add_child(btn_learn)

	var btn_cancel := Button.new()
	btn_cancel.text = "Cancel"
	btn_cancel.custom_minimum_size = Vector2(80, 34)
	btn_cancel.pressed.connect(func(): _spell_overlay.visible = false)
	btn_row.add_child(btn_cancel)

func _on_open_custom_spell() -> void:
	# Reset builder state for a fresh spell
	_sb_name = ""
	_sb_domain = 0
	_sb_effect_idx = 0
	_sb_duration_idx = 0
	_sb_range_idx = 1
	_sb_targets = 1
	_sb_area_idx = 0
	_sb_die_count = 1
	_sb_die_idx = 0
	_sb_damage_type = 3
	_sb_is_healing = false
	_sb_is_saving_throw = false
	_sb_is_teleport = false
	_sb_tp_range = 5
	_sb_is_combustion = false
	_sb_conditions.clear()
	_sb_populate_inner()
	_spell_overlay.visible = true

func _on_learn_custom_spell() -> void:
	var spell_name: String = _sb_name.strip_edges()
	if spell_name.is_empty():
		_add_log("[color=red]Spell name cannot be empty.[/color]")
		_spell_overlay.visible = false
		return

	var final_cost: int = _sb_calc_cost()
	var die_sides: int  = [4, 6, 8, 10, 12][_sb_die_idx]
	var dur_rounds: int = SB_DURATION_ROUNDS[_sb_duration_idx] if _sb_duration_idx < SB_DURATION_ROUNDS.size() else 0
	var cond_csv: String = ",".join(_sb_conditions)
	var desc: String = _sb_gen_description()

	_e.add_custom_spell(
		spell_name, _sb_domain, final_cost, desc,
		_sb_range_idx, (not _sb_is_saving_throw) and (not _sb_is_healing),
		_sb_die_count, die_sides, _sb_damage_type,
		_sb_is_healing, dur_rounds, _sb_targets,
		_sb_area_idx, cond_csv, _sb_is_teleport,
		_sb_is_combustion, -1, _sb_tp_range if _sb_is_teleport else 0
	)
	_add_log("[color=violet]✨ %s learned by all players! (SP Cost: %d)[/color]" % [spell_name, final_cost])
	_spell_overlay.visible = false
	_populate_action_columns()

# ── Terrain Selector Dialog ───────────────────────────────────────────────────
func _build_terrain_selector_dialog() -> void:
	_terrain_overlay = ColorRect.new()
	(_terrain_overlay as ColorRect).color = Color(0.0, 0.0, 0.0, 0.72)
	_terrain_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_terrain_overlay.visible = false
	add_child(_terrain_overlay)

	var panel := ColorRect.new()
	panel.color = Color(0.07, 0.09, 0.07)
	panel.custom_minimum_size = Vector2(520, 420)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -260.0
	panel.offset_right  =  260.0
	panel.offset_top    = -210.0
	panel.offset_bottom =  210.0
	_terrain_overlay.add_child(panel)

	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: m.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(m)
	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	m.add_child(root_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "⛰ Choose Terrain"
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 0.55))
	root_vbox.add_child(title_lbl)
	root_vbox.add_child(_hsep())

	# Two-column layout: regions on left, subregions on right
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	root_vbox.add_child(cols)

	# Region column
	var region_bg := ColorRect.new()
	region_bg.color = Color(0.06, 0.06, 0.08)
	region_bg.custom_minimum_size = Vector2(150, 280)
	cols.add_child(region_bg)
	var region_scroll := ScrollContainer.new()
	region_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	region_bg.add_child(region_scroll)
	_terrain_region_vbox = VBoxContainer.new()
	_terrain_region_vbox.add_theme_constant_override("separation", 2)
	region_scroll.add_child(_terrain_region_vbox)

	# Subregion column
	var sub_bg := ColorRect.new()
	sub_bg.color = Color(0.05, 0.07, 0.05)
	sub_bg.custom_minimum_size = Vector2(220, 280)
	cols.add_child(sub_bg)
	var sub_scroll := ScrollContainer.new()
	sub_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub_bg.add_child(sub_scroll)
	_terrain_sub_vbox = VBoxContainer.new()
	_terrain_sub_vbox.add_theme_constant_override("separation", 2)
	sub_scroll.add_child(_terrain_sub_vbox)

	# Swatch + confirm row
	var bottom_row := HBoxContainer.new()
	root_vbox.add_child(bottom_row)
	_terrain_swatch = ColorRect.new()
	_terrain_swatch.custom_minimum_size = Vector2(48, 48)
	_terrain_swatch.color = Color(0.28, 0.25, 0.22)
	bottom_row.add_child(_terrain_swatch)
	bottom_row.add_child(_spacer_h(12))

	var random_btn := _colored_btn("🎲 Random", Color(0.15, 0.15, 0.20))
	random_btn.pressed.connect(_on_terrain_random)
	bottom_row.add_child(random_btn)
	bottom_row.add_child(_spacer_h(8))

	var confirm_btn := _colored_btn("✓ Enter Terrain", Color(0.10, 0.28, 0.10))
	confirm_btn.pressed.connect(_on_terrain_confirm)
	bottom_row.add_child(confirm_btn)
	bottom_row.add_child(_spacer_h(8))

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): _terrain_overlay.visible = false)
	bottom_row.add_child(cancel_btn)

func _on_open_terrain_selector() -> void:
	_terrain_sel_region = ""
	_terrain_sel_name   = ""
	_terrain_sel_style  = 0
	_populate_terrain_regions()
	_terrain_sub_vbox.visible = false
	_terrain_overlay.visible  = true

func _populate_terrain_regions() -> void:
	for c in _terrain_region_vbox.get_children():
		c.queue_free()
	var regions: PackedStringArray = _e.get_terrain_regions()
	for reg in regions:
		var btn := Button.new()
		btn.text = reg
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_terrain_region_selected.bind(str(reg)))
		_terrain_region_vbox.add_child(btn)

func _on_terrain_region_selected(region: String) -> void:
	_terrain_sel_region = region
	for c in _terrain_sub_vbox.get_children():
		c.queue_free()
	var subs: Array = _e.get_terrain_subregions(region)
	_terrain_sub_vbox.visible = true
	for sub in subs:
		var sub_name: String = str(sub[0])
		var style_id: int    = int(sub[1])
		var btn := Button.new()
		btn.text = sub_name
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_terrain_subregion_selected.bind(sub_name, style_id))
		_terrain_sub_vbox.add_child(btn)

func _on_terrain_subregion_selected(sub_name: String, style_id: int) -> void:
	_terrain_sel_name  = sub_name
	_terrain_sel_style = style_id
	# Update swatch color from palette floor color
	var palette: Dictionary = _e.TERRAIN_PALETTES.get(style_id, _e.TERRAIN_PALETTES[0])
	var fc: Array = Array(palette.get("floor", [0.3, 0.3, 0.3]))
	_terrain_swatch.color = Color(float(fc[0]), float(fc[1]), float(fc[2]))

func _on_terrain_random() -> void:
	var regions: PackedStringArray = _e.get_terrain_regions()
	if regions.is_empty(): return
	var rand_region: String = str(regions[randi() % regions.size()])
	var subs: Array = _e.get_terrain_subregions(rand_region)
	if subs.is_empty(): return
	var rand_sub: Array = subs[randi() % subs.size()]
	_on_terrain_region_selected(rand_region)
	_on_terrain_subregion_selected(str(rand_sub[0]), int(rand_sub[1]))

func _on_terrain_confirm() -> void:
	if _terrain_sel_name.is_empty():
		_add_log("[color=red]Select a terrain first.[/color]")
		return
	_terrain_overlay.visible = false
	_add_log("[color=green]⛰ Entering %s… restarting dungeon.[/color]" % _terrain_sel_name)
	_e.restart_with_terrain(_terrain_sel_style, _terrain_sel_name)
	# Reload scene data — must refresh _map too since the dungeon was regenerated
	_map       = _e.get_dungeon_map()
	_load_terrain_palette()
	_update_biome_environment()
	_spawn_biome_particles()
	_entities  = _e.get_dungeon_entities()
	_fog       = _e.get_dungeon_fog()
	_elevation = _e.get_dungeon_elevation()
	_selected_id = ""
	_pending_action = {}
	_outcome = "ongoing"
	_phase_label.text = "YOUR TURN"
	_phase_label.add_theme_color_override("font_color", Color(0.30, 0.85, 0.30))
	_btn_next_unit.disabled = false
	_btn_end_phase.disabled = false
	# Select the first alive player entity
	for ent in _entities:
		if bool(ent["is_player"]) and not bool(ent["is_dead"]):
			_select_entity(str(ent["id"]))
			break
	_update_banner()
	_map_dirty = true
	_update_3d_view()
	_populate_action_columns()

# ── UI construction ───────────────────────────────────────────────────────────
func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_build_header())

	# Map fills all available space above the bottom bar
	var center = _build_center_panel()
	center.size_flags_stretch_ratio = 1.0
	root.add_child(center)

	# Mobile-style bottom bar (unit tabs + badges + action buttons)
	# Wrap in ScrollContainer so the bar never overflows the screen
	var bottom_scroll := ScrollContainer.new()
	bottom_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_scroll.size_flags_stretch_ratio = 1.2  # bottom bar gets slightly more space
	bottom_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var bottom_bar := _build_bottom_bar()
	bottom_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_scroll.add_child(bottom_bar)
	root.add_child(bottom_scroll)

	_move_popup = _build_move_popup()
	add_child(_move_popup)

	_loot_popup = _build_loot_popup()
	add_child(_loot_popup)

# ── Header ────────────────────────────────────────────────────────────────────
func _build_header() -> Control:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.08, 0.05)
	bg.custom_minimum_size = Vector2(0, 56)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + s, 8)
	bg.add_child(margin)

	var hbox := HBoxContainer.new()
	margin.add_child(hbox)

	var title := Label.new()
	title.text = "⛩  DUNGEON"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.72, 0.30))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

	_round_label = Label.new()
	_round_label.text = "Round 1"
	_round_label.add_theme_font_size_override("font_size", 16)
	_round_label.add_theme_color_override("font_color", Color(0.80, 0.80, 0.75))
	hbox.add_child(_round_label)

	hbox.add_child(_spacer_h(12))

	_phase_label = Label.new()
	_phase_label.text = "YOUR TURN"
	_phase_label.add_theme_font_size_override("font_size", 16)
	_phase_label.add_theme_color_override("font_color", Color(0.30, 0.85, 0.30))
	hbox.add_child(_phase_label)

	hbox.add_child(_spacer_h(12))

	_btn_stash = Button.new()
	_btn_stash.text = "🎒 Stash"
	_btn_stash.add_theme_font_size_override("font_size", 14)
	_btn_stash.pressed.connect(_on_open_stash)
	hbox.add_child(_btn_stash)

	hbox.add_child(_spacer_h(8))

	var btn_spell := Button.new()
	btn_spell.text = "✨ Learn Spell"
	btn_spell.add_theme_font_size_override("font_size", 14)
	btn_spell.pressed.connect(_on_open_custom_spell)
	hbox.add_child(btn_spell)

	hbox.add_child(_spacer_h(8))

	var btn_terrain := Button.new()
	btn_terrain.text = "⛰ Terrain"
	btn_terrain.add_theme_font_size_override("font_size", 14)
	btn_terrain.pressed.connect(_on_open_terrain_selector)
	hbox.add_child(btn_terrain)

	hbox.add_child(_spacer_h(8))

	_btn_back = Button.new()
	_btn_back.text = "← Back to Map"
	_btn_back.add_theme_font_size_override("font_size", 14)
	_btn_back.pressed.connect(_on_back)
	hbox.add_child(_btn_back)

	return bg

# ── Left panel — entity card ──────────────────────────────────────────────────
func _build_left_panel() -> Control:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.10, 0.13)
	bg.custom_minimum_size = Vector2(180, 0)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bg.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + s, 10)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	# Section label
	vbox.add_child(_section_label("SELECTED"))

	_lp_name = Label.new()
	_lp_name.text = "—"
	_lp_name.add_theme_font_size_override("font_size", 16)
	_lp_name.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75))
	_lp_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_lp_name)

	# HP bar
	var hp_row: Array = _bar_row("HP", Color(0.22, 0.72, 0.22))
	_lp_hp_bar = hp_row[0]
	_lp_hp_val = hp_row[1]
	vbox.add_child(hp_row[2])

	# AP bar
	var ap_row: Array = _bar_row("AP", C_AP_BAR)
	_lp_ap_bar = ap_row[0]
	_lp_ap_val = ap_row[1]
	vbox.add_child(ap_row[2])

	# SP bar
	var sp_row: Array = _bar_row("SP", C_SP_BAR)
	_lp_sp_bar = sp_row[0]
	_lp_sp_val = sp_row[1]
	vbox.add_child(sp_row[2])

	# Weapon label
	_lp_weapon = Label.new()
	_lp_weapon.add_theme_font_size_override("font_size", 12)
	_lp_weapon.add_theme_color_override("font_color", Color(0.75, 0.72, 0.60))
	_lp_weapon.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_lp_weapon)

	# Conditions
	_lp_conditions = Label.new()
	_lp_conditions.add_theme_font_size_override("font_size", 11)
	_lp_conditions.add_theme_color_override("font_color", Color(0.90, 0.55, 0.20))
	_lp_conditions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_lp_conditions)

	# Active matrices
	_lp_matrices = Label.new()
	_lp_matrices.add_theme_font_size_override("font_size", 11)
	_lp_matrices.add_theme_color_override("font_color", Color(0.70, 0.50, 1.00))
	_lp_matrices.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_lp_matrices)

	vbox.add_child(_hsep())

	# Roster
	vbox.add_child(_section_label("PARTY"))
	_lp_roster = VBoxContainer.new()
	_lp_roster.add_theme_constant_override("separation", 3)
	vbox.add_child(_lp_roster)

	return bg

# Returns [progress_bar, val_label, container]
func _bar_row(lbl_txt: String, bar_col: Color) -> Array:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 1)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 4)
	container.add_child(top_row)

	var lbl := Label.new()
	lbl.text = lbl_txt
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.55))
	lbl.custom_minimum_size = Vector2(20, 0)
	top_row.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.text = "–"
	val_lbl.add_theme_font_size_override("font_size", 10)
	val_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.80))
	top_row.add_child(val_lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 7)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	# Style the fill and background
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = bar_col
	bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(bar_col, 0.22)
	bar.add_theme_stylebox_override("background", bg_style)
	container.add_child(bar)

	return [bar, val_lbl, container]

# ── Center panel — 3D map viewport ───────────────────────────────────────────
func _build_center_panel() -> Control:
	# Outer container that fills the center slot
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04)
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg.size_flags_vertical   = Control.SIZE_EXPAND_FILL

	# SubViewportContainer — stretches to fill bg, passes input to viewport
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true    # Godot scales the viewport texture to fill the container
	svc.gui_input.connect(_on_grid_input)
	bg.add_child(svc)
	_grid_view = svc   # keep _grid_view pointing here for compat

	# SubViewport — hosts the 3D world (fixed internal resolution; stretched to container by svc)
	_viewport_3d = SubViewport.new()
	# Internal 3D resolution scales with quality. Lower = much cheaper to
	# render, especially on big crawl maps. 768×576 ≈ 56% of 1024×768 px.
	match _quality:
		"low":  _viewport_3d.size = Vector2i(768, 576)
		"high": _viewport_3d.size = Vector2i(1280, 960)
		_:      _viewport_3d.size = Vector2i(1024, 768)
	_viewport_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_3d.transparent_bg = false
	svc.add_child(_viewport_3d)

	# ── Build 3D world inside the viewport ────────────────────────────────────
	_world3d_root = Node3D.new()
	_world3d_root.name = "World3D"
	_viewport_3d.add_child(_world3d_root)

	# WorldEnvironment — ambient glow, fog, background (updated per-biome)
	_env_node = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.01, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.12, 0.08, 0.20)
	env.ambient_light_energy = 0.6
	env.glow_enabled         = true
	env.glow_intensity       = 0.6
	env.glow_bloom           = 0.15
	env.glow_blend_mode      = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.ssao_enabled         = true
	env.ssao_radius          = 0.8
	env.ssao_intensity       = 1.4
	env.fog_enabled          = true
	env.fog_light_color      = Color(0.04, 0.02, 0.08)
	env.fog_density          = 0.02
	env.fog_aerial_perspective = 0.3
	_env_node.environment = env
	_world3d_root.add_child(_env_node)

	# Camera — orbit rig driven by _cam_yaw / _cam_pitch / _cam_dist.
	# Scroll wheel = zoom  |  Right-drag = rotate
	_cam3d = Camera3D.new()
	_cam3d.name    = "DungeonCam"
	_cam3d.fov     = 60.0
	_cam3d.near    = 0.1
	_cam3d.far     = 500.0
	_cam3d.current = true
	_world3d_root.add_child(_cam3d)
	_update_camera_pos()   # position at default orbit (yaw 0, pitch 55°, dist 24)

	# Main directional light — cool top-down with slight warm angle
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_color = Color(0.85, 0.78, 0.95)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-65.0, 30.0, 0.0)
	_world3d_root.add_child(sun)

	# Ambient fill light from below/opposite angle
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_color = Color(0.30, 0.15, 0.40)
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(30.0, -150.0, 0.0)
	_world3d_root.add_child(fill)

	# Node3D roots for organised scene structure
	_tile_root    = Node3D.new(); _tile_root.name    = "Tiles";    _world3d_root.add_child(_tile_root)
	_entity_root  = Node3D.new(); _entity_root.name  = "Entities"; _world3d_root.add_child(_entity_root)
	_overlay_root = Node3D.new(); _overlay_root.name = "Overlays"; _world3d_root.add_child(_overlay_root)
	_torch_root   = Node3D.new(); _torch_root.name   = "Torches";  _world3d_root.add_child(_torch_root)
	_fog_root     = Node3D.new(); _fog_root.name     = "Fog";      _world3d_root.add_child(_fog_root)
	_particle_root = Node3D.new(); _particle_root.name = "Particles"; _world3d_root.add_child(_particle_root)
	_region_prop_root = Node3D.new(); _region_prop_root.name = "RegionProps"; _world3d_root.add_child(_region_prop_root)

	return bg

# ── Right panel — 3-column action menu ───────────────────────────────────────
func _build_right_panel() -> Control:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.11)
	bg.custom_minimum_size = Vector2(240, 0)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_vbox.add_theme_constant_override("separation", 0)
	bg.add_child(outer_vbox)

	# Action mode label (hidden until target selection)
	_action_mode_lbl = Label.new()
	_action_mode_lbl.text = ""
	_action_mode_lbl.add_theme_font_size_override("font_size", 12)
	_action_mode_lbl.add_theme_color_override("font_color", Color(1.0, 0.70, 0.20))
	_action_mode_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_mode_lbl.custom_minimum_size = Vector2(0, 24)
	outer_vbox.add_child(_action_mode_lbl)

	# 3-column header
	var col_header := HBoxContainer.new()
	col_header.add_theme_constant_override("separation", 0)
	col_header.custom_minimum_size = Vector2(0, 22)
	outer_vbox.add_child(col_header)

	for col_txt in ["⚔ WEAPONS", "✨ MAGIC", "◎ ABILITIES"]:
		var lbl := Label.new()
		lbl.text = col_txt
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.55))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.clip_text = true
		col_header.add_child(lbl)

	# 3-column body scroll
	var col_scroll := ScrollContainer.new()
	col_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	outer_vbox.add_child(col_scroll)

	var col_body := HBoxContainer.new()
	col_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_body.add_theme_constant_override("separation", 1)
	col_scroll.add_child(col_body)

	# Weapons column
	var wcol := _action_column()
	_col_weapons_vbox = wcol[0]
	col_body.add_child(wcol[1])

	# Magic column
	var mcol := _action_column()
	_col_magic_vbox = mcol[0]
	col_body.add_child(mcol[1])

	# Abilities column
	var acol := _action_column()
	_col_abil_vbox = acol[0]
	col_body.add_child(acol[1])

	# Divider
	outer_vbox.add_child(_hsep())

	# Next Unit / End Phase row
	var turn_row := HBoxContainer.new()
	turn_row.add_theme_constant_override("separation", 4)
	turn_row.custom_minimum_size = Vector2(0, 40)
	var turn_margin := MarginContainer.new()
	for s in ["left","right","top","bottom"]:
		turn_margin.add_theme_constant_override("margin_" + s, 4)
	turn_margin.add_child(turn_row)
	outer_vbox.add_child(turn_margin)

	_btn_next_unit = _colored_btn("⏩ Next Unit", Color(0.70, 0.60, 0.05))
	_btn_next_unit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_next_unit.pressed.connect(_on_next_unit)
	turn_row.add_child(_btn_next_unit)

	_btn_end_phase = _colored_btn("⏹ End Phase", Color(0.60, 0.12, 0.12))
	_btn_end_phase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_end_phase.pressed.connect(_on_end_phase)
	turn_row.add_child(_btn_end_phase)

	# Victory: "End Dungeon" button (hidden until all enemies are defeated)
	_btn_end_dungeon = _colored_btn("✦ End Dungeon - Claim Victory ✦", Color(0.75, 0.65, 0.05))
	_btn_end_dungeon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_end_dungeon.custom_minimum_size = Vector2(0, 44)
	_btn_end_dungeon.visible = false
	_btn_end_dungeon.pressed.connect(_on_end_dungeon_pressed)
	var end_dung_margin := MarginContainer.new()
	for s2 in ["left","right","top","bottom"]:
		end_dung_margin.add_theme_constant_override("margin_" + s2, 4)
	end_dung_margin.add_child(_btn_end_dungeon)
	outer_vbox.add_child(end_dung_margin)

	# Divider + battle log
	outer_vbox.add_child(_hsep())

	var log_margin := MarginContainer.new()
	log_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for s in ["left","right","top","bottom"]:
		log_margin.add_theme_constant_override("margin_" + s, 6)
	outer_vbox.add_child(log_margin)

	var log_vbox := VBoxContainer.new()
	log_vbox.add_theme_constant_override("separation", 4)
	log_margin.add_child(log_vbox)

	log_vbox.add_child(_section_label("BATTLE LOG"))

	_log_text = RichTextLabel.new()
	_log_text.bbcode_enabled = true
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_text.custom_minimum_size = Vector2(0, 80)
	_log_text.add_theme_font_size_override("normal_font_size", 11)
	_log_text.add_theme_color_override("default_color", Color(0.85, 0.85, 0.80))
	_log_text.scroll_following = true
	log_vbox.add_child(_log_text)

	return bg

# ── Bottom bar — mobile-style ─────────────────────────────────────────────────
# Returns a VBoxContainer directly so it auto-sizes to its children.
# Each row section owns its own ColorRect background.
func _build_bottom_bar() -> Control:
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 0)

	# ── Unit tab chips ────────────────────────────────────────────────────────
	var tab_bg := ColorRect.new()
	tab_bg.color = Color(0.08, 0.08, 0.12)
	tab_bg.custom_minimum_size = Vector2(0, 38)
	outer.add_child(tab_bg)

	var tab_scroll := ScrollContainer.new()
	tab_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tab_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_DISABLED
	tab_bg.add_child(tab_scroll)

	var tab_margin := MarginContainer.new()
	tab_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left","right","top","bottom"]:
		tab_margin.add_theme_constant_override("margin_" + s, 5)
	tab_scroll.add_child(tab_margin)

	_unit_tabs_hbox = HBoxContainer.new()
	_unit_tabs_hbox.add_theme_constant_override("separation", 5)
	tab_margin.add_child(_unit_tabs_hbox)

	# ── Stats badge row ───────────────────────────────────────────────────────
	var badge_bg := ColorRect.new()
	badge_bg.color = Color(0.09, 0.08, 0.13)
	badge_bg.custom_minimum_size = Vector2(0, 40)
	outer.add_child(badge_bg)

	var badge_margin := MarginContainer.new()
	badge_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left","right","top","bottom"]:
		badge_margin.add_theme_constant_override("margin_" + s, 5)
	badge_bg.add_child(badge_margin)

	var badge_hbox := HBoxContainer.new()
	badge_hbox.add_theme_constant_override("separation", 6)
	badge_margin.add_child(badge_hbox)

	_badge_name = Label.new()
	_badge_name.text = "—"
	_badge_name.add_theme_font_size_override("font_size", 14)
	_badge_name.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75))
	_badge_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_badge_name.clip_text = true
	badge_hbox.add_child(_badge_name)

	_badge_hp = _stat_chip("♥ –/–", Color(0.16, 0.52, 0.16))
	badge_hbox.add_child(_badge_hp)

	_badge_ap = _stat_chip("◈ –/–", Color(0.14, 0.44, 0.72))
	badge_hbox.add_child(_badge_ap)

	_badge_sp = _stat_chip("✦ –/–", Color(0.52, 0.22, 0.65))
	badge_hbox.add_child(_badge_sp)

	_badge_weapon = Label.new()
	_badge_weapon.add_theme_font_size_override("font_size", 11)
	_badge_weapon.add_theme_color_override("font_color", Color(0.72, 0.68, 0.52))
	_badge_weapon.clip_text = true
	badge_hbox.add_child(_badge_weapon)

	_badge_light = Label.new()
	_badge_light.add_theme_font_size_override("font_size", 11)
	_badge_light.add_theme_color_override("font_color", Color(0.90, 0.72, 0.20))
	_badge_light.clip_text = true
	badge_hbox.add_child(_badge_light)

	# ── Conditions / matrices row ─────────────────────────────────────────────
	var status_margin := MarginContainer.new()
	for s in ["left","right"]:
		status_margin.add_theme_constant_override("margin_" + s, 8)
	outer.add_child(status_margin)

	var status_hbox := HBoxContainer.new()
	status_hbox.add_theme_constant_override("separation", 8)
	status_margin.add_child(status_hbox)

	_badge_conditions = HBoxContainer.new()
	_badge_conditions.add_theme_constant_override("separation", 4)
	_badge_conditions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_hbox.add_child(_badge_conditions)

	_badge_matrices = Label.new()
	_badge_matrices.add_theme_font_size_override("font_size", 11)
	_badge_matrices.add_theme_color_override("font_color", Color(0.70, 0.50, 1.00))
	_badge_matrices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_badge_matrices.clip_text = true
	status_hbox.add_child(_badge_matrices)

	# ── Expandable action area ────────────────────────────────────────────────
	_actions_area = ColorRect.new()
	(_actions_area as ColorRect).color = Color(0.05, 0.05, 0.08)
	_actions_area.custom_minimum_size = Vector2(0, 160)
	_actions_area.visible = false
	outer.add_child(_actions_area)

	var act_scroll := ScrollContainer.new()
	act_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	act_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	act_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	_actions_area.add_child(act_scroll)

	var act_margin := MarginContainer.new()
	act_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left","right","top","bottom"]:
		act_margin.add_theme_constant_override("margin_" + s, 6)
	act_scroll.add_child(act_margin)

	var act_vbox := VBoxContainer.new()
	act_vbox.add_theme_constant_override("separation", 4)
	act_margin.add_child(act_vbox)

	# Weapons panel
	_weapons_panel = VBoxContainer.new()
	(_weapons_panel as VBoxContainer).add_theme_constant_override("separation", 3)
	_weapons_panel.visible = false
	act_vbox.add_child(_weapons_panel)
	(_weapons_panel as VBoxContainer).add_child(_section_label("⚔ WEAPONS"))
	_col_weapons_vbox = VBoxContainer.new()
	_col_weapons_vbox.add_theme_constant_override("separation", 3)
	(_weapons_panel as VBoxContainer).add_child(_col_weapons_vbox)

	# Cast panel
	_cast_panel = VBoxContainer.new()
	(_cast_panel as VBoxContainer).add_theme_constant_override("separation", 3)
	_cast_panel.visible = false
	act_vbox.add_child(_cast_panel)
	(_cast_panel as VBoxContainer).add_child(_section_label("✨ CAST"))
	_col_magic_vbox = VBoxContainer.new()
	_col_magic_vbox.add_theme_constant_override("separation", 3)
	(_cast_panel as VBoxContainer).add_child(_col_magic_vbox)

	# Abilities panel
	_abil_panel = VBoxContainer.new()
	(_abil_panel as VBoxContainer).add_theme_constant_override("separation", 3)
	_abil_panel.visible = false
	act_vbox.add_child(_abil_panel)
	(_abil_panel as VBoxContainer).add_child(_section_label("≡ ABILITIES"))
	_col_abil_vbox = VBoxContainer.new()
	_col_abil_vbox.add_theme_constant_override("separation", 3)
	(_abil_panel as VBoxContainer).add_child(_col_abil_vbox)

	# ── Action mode label ─────────────────────────────────────────────────────
	_action_mode_lbl = Label.new()
	_action_mode_lbl.text = ""
	_action_mode_lbl.add_theme_font_size_override("font_size", 12)
	_action_mode_lbl.add_theme_color_override("font_color", Color(1.0, 0.70, 0.20))
	_action_mode_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_mode_lbl.custom_minimum_size = Vector2(0, 22)
	outer.add_child(_action_mode_lbl)

	# ── Category toggle buttons row 1 ─────────────────────────────────────────
	var cat_margin := MarginContainer.new()
	for s in ["left","right","top","bottom"]:
		cat_margin.add_theme_constant_override("margin_" + s, 3)
	outer.add_child(cat_margin)

	var cat_row := HBoxContainer.new()
	cat_row.add_theme_constant_override("separation", 2)
	cat_row.custom_minimum_size = Vector2(0, 40)
	cat_margin.add_child(cat_row)

	_btn_weapons = _colored_btn("⚔ Weapons", Color(0.50, 0.18, 0.10))
	_btn_weapons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_weapons.pressed.connect(func(): _toggle_action_category("weapons"))
	cat_row.add_child(_btn_weapons)

	_btn_cast = _colored_btn("✨ Cast", Color(0.22, 0.12, 0.48))
	_btn_cast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_cast.pressed.connect(func(): _toggle_action_category("cast"))
	cat_row.add_child(_btn_cast)

	_btn_abilities = _colored_btn("≡ Abilities", Color(0.10, 0.32, 0.16))
	_btn_abilities.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_abilities.pressed.connect(func(): _toggle_action_category("abilities"))
	cat_row.add_child(_btn_abilities)

	# ── Utility buttons row 2 ─────────────────────────────────────────────────
	var util_margin := MarginContainer.new()
	for s in ["left","right","bottom"]:
		util_margin.add_theme_constant_override("margin_" + s, 3)
	outer.add_child(util_margin)

	var util_row := HBoxContainer.new()
	util_row.add_theme_constant_override("separation", 2)
	util_row.custom_minimum_size = Vector2(0, 40)
	util_margin.add_child(util_row)

	var btn_items := _colored_btn("📦 Items", Color(0.20, 0.36, 0.16))
	btn_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_items.pressed.connect(_on_open_stash)
	util_row.add_child(btn_items)

	var btn_equip := _colored_btn("⚔ Equip", Color(0.28, 0.22, 0.42))
	btn_equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_equip.pressed.connect(_on_open_equip_overlay)
	util_row.add_child(btn_equip)

	_btn_next_unit = _colored_btn("▶ Next", Color(0.48, 0.40, 0.05))
	_btn_next_unit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_next_unit.pressed.connect(_on_next_unit)
	util_row.add_child(_btn_next_unit)

	_btn_end_phase = _colored_btn("⏹ End Phase", Color(0.50, 0.10, 0.10))
	_btn_end_phase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_end_phase.pressed.connect(_on_end_phase)
	util_row.add_child(_btn_end_phase)

	# Victory: "End Dungeon" button (hidden until all enemies defeated)
	_btn_end_dungeon = _colored_btn("✦ End Dungeon - Claim Victory ✦", Color(0.75, 0.65, 0.05))
	_btn_end_dungeon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_end_dungeon.custom_minimum_size = Vector2(0, 44)
	_btn_end_dungeon.visible = false
	_btn_end_dungeon.pressed.connect(_on_end_dungeon_pressed)
	var end_dung_margin2 := MarginContainer.new()
	for s3 in ["left","right","top","bottom"]:
		end_dung_margin2.add_theme_constant_override("margin_" + s3, 4)
	end_dung_margin2.add_child(_btn_end_dungeon)
	outer.add_child(end_dung_margin2)

	# ── Battle log ────────────────────────────────────────────────────────────
	# Top accent line — gold strip to draw the eye
	var log_accent := ColorRect.new()
	log_accent.color = Color(0.75, 0.55, 0.15, 0.70)
	log_accent.custom_minimum_size = Vector2(0, 2)
	outer.add_child(log_accent)

	var log_bg := ColorRect.new()
	log_bg.color = Color(0.05, 0.04, 0.08)
	log_bg.custom_minimum_size = Vector2(0, 130)
	log_bg.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	outer.add_child(log_bg)

	var log_margin := MarginContainer.new()
	log_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left","right"]:
		log_margin.add_theme_constant_override("margin_" + s, 8)
	log_margin.add_theme_constant_override("margin_top", 4)
	log_margin.add_theme_constant_override("margin_bottom", 6)
	log_bg.add_child(log_margin)

	var log_inner := VBoxContainer.new()
	log_inner.add_theme_constant_override("separation", 2)
	log_margin.add_child(log_inner)

	var log_header := Label.new()
	log_header.text = "📜 BATTLE LOG"
	log_header.add_theme_font_size_override("font_size", 11)
	log_header.add_theme_color_override("font_color", Color(0.75, 0.60, 0.25))
	log_inner.add_child(log_header)

	_log_text = RichTextLabel.new()
	_log_text.bbcode_enabled = true
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_text.add_theme_font_size_override("normal_font_size", 13)
	_log_text.add_theme_color_override("default_color", Color(0.90, 0.88, 0.82))
	_log_text.scroll_following = true
	log_inner.add_child(_log_text)

	return outer

## Stat badge chip — colored background label
func _stat_chip(txt: String, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.custom_minimum_size = Vector2(68, 26)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = col
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	lbl.add_theme_stylebox_override("normal", style)
	return lbl

## Toggle which action category panel is shown in the expandable area.
func _toggle_action_category(cat: String) -> void:
	if _active_category == cat:
		_active_category = ""
	else:
		_active_category = cat
	_actions_area.visible      = (_active_category != "")
	_weapons_panel.visible     = (_active_category == "weapons")
	_cast_panel.visible        = (_active_category == "cast")
	_abil_panel.visible        = (_active_category == "abilities")
	var c_on  := Color(1.0, 1.0, 1.0, 1.0)
	var c_off := Color(0.72, 0.72, 0.72, 1.0)
	_btn_weapons.modulate   = c_on if _active_category == "weapons"   else c_off
	_btn_cast.modulate      = c_on if _active_category == "cast"      else c_off
	_btn_abilities.modulate = c_on if _active_category == "abilities" else c_off

# Returns [vbox, outer_container]
func _action_column() -> Array:
	var container := ColorRect.new()
	container.color = Color(0.10, 0.10, 0.13)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical   = Control.SIZE_EXPAND_FILL

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	container.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + s, 4)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	return [vbox, container]

# ── Move confirmation popup ───────────────────────────────────────────────────
func _build_move_popup() -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.z_index = 10
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var card := ColorRect.new()
	card.color = Color(0.08, 0.22, 0.12)
	card.custom_minimum_size = Vector2(260, 100)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.set_offsets_preset(Control.PRESET_CENTER)
	overlay.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + s, 16)
	card.add_child(margin)
	margin.add_child(vbox)

	_move_popup_lbl = Label.new()
	_move_popup_lbl.text = "Move here?"
	_move_popup_lbl.add_theme_font_size_override("font_size", 15)
	_move_popup_lbl.add_theme_color_override("font_color", Color(0.90, 0.95, 0.85))
	_move_popup_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_move_popup_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var btn_cancel := _colored_btn("✗ Cancel", Color(0.40, 0.12, 0.12))
	btn_cancel.custom_minimum_size = Vector2(90, 36)
	btn_cancel.pressed.connect(_on_move_cancel)
	btn_row.add_child(btn_cancel)

	var btn_confirm := _colored_btn("✓ Move (Enter)", Color(0.12, 0.48, 0.22))
	btn_confirm.custom_minimum_size = Vector2(90, 36)
	btn_confirm.pressed.connect(_on_move_confirm)
	btn_confirm.focus_mode = Control.FOCUS_ALL
	btn_row.add_child(btn_confirm)
	_move_confirm_btn = btn_confirm

	return overlay

# ── Loot popup ────────────────────────────────────────────────────────────────
func _build_loot_popup() -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.z_index = 10
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var card := ColorRect.new()
	card.color = Color(0.10, 0.05, 0.05)
	card.custom_minimum_size = Vector2(280, 140)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.set_offsets_preset(Control.PRESET_CENTER)
	overlay.add_child(card)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + s, 14)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_loot_title_lbl = Label.new()
	_loot_title_lbl.text = "⚔ Loot"
	_loot_title_lbl.add_theme_font_size_override("font_size", 15)
	_loot_title_lbl.add_theme_color_override("font_color", Color(0.90, 0.60, 0.20))
	_loot_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_loot_title_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 80)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_loot_items_vbox = VBoxContainer.new()
	_loot_items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loot_items_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_loot_items_vbox)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var btn_ok := _colored_btn("OK  [Enter]", Color(0.15, 0.45, 0.18))
	btn_ok.custom_minimum_size = Vector2(120, 34)
	btn_ok.pressed.connect(func(): _loot_popup.visible = false)
	btn_row.add_child(btn_ok)

	return overlay

func _open_loot_popup(entity_id: String, enemy_name: String) -> void:
	_loot_entity_id = entity_id

	for child in _loot_items_vbox.get_children():
		child.queue_free()

	var items: PackedStringArray = _e.get_dungeon_entity_loot(entity_id)
	if items.is_empty():
		# Already looted — don't show popup again
		return

	# Auto-loot immediately
	var active := GameState.get_active_handles()
	var ph: int = active[0] if not active.is_empty() else -1
	_e.loot_dungeon_entity(entity_id, ph)

	_loot_title_lbl.text = "✓  %s — Loot Collected!" % enemy_name
	for item in items:
		var lbl := Label.new()
		lbl.text = "• " + str(item)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		_loot_items_vbox.add_child(lbl)

	_loot_popup.visible = true
	_loot_popup.grab_focus()

func _on_loot_take_all() -> void:
	if _loot_entity_id.is_empty(): return
	var active := GameState.get_active_handles()
	var ph: int = active[0] if not active.is_empty() else -1
	var ok: bool = _e.loot_dungeon_entity(_loot_entity_id, ph)
	if ok:
		_loot_title_lbl.text = "✓ Loot added to stash!"
		for child in _loot_items_vbox.get_children():
			child.queue_free()
		var done_lbl := Label.new()
		done_lbl.text = "All items transferred to stash."
		done_lbl.add_theme_font_size_override("font_size", 12)
		done_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		_loot_items_vbox.add_child(done_lbl)
		_refresh()   # sync entity state so gold token reverts to gray immediately
	_loot_entity_id = ""

# ── 3D Update entry point ─────────────────────────────────────────────────────
## Called everywhere queue_redraw() was previously called.
func _update_3d_view() -> void:
	if _viewport_3d == null: return
	# When render-distance culling is on, retrigger a rebuild as the player
	# walks past chunk boundaries so the visible "live chunk" slides with
	# the party. Cheap check (Chebyshev compare, returns immediately when
	# culling is disabled).
	if _player_moved_past_chunk_step():
		_map_dirty = true
	if _map_dirty:
		_rebuild_3d_tiles()
		_rebuild_3d_torches()
		_rebuild_3d_ambience()
		# Region Map Style: layer outdoor props + daylight on top of the
		# classic render (palette already tuned via _apply_region_style_overrides).
		if _render_style == "region":
			_rebuild_region_style_props()
		elif _region_prop_root != null:
			# Clean up any leftover region props when returning to classic.
			for c in _region_prop_root.get_children():
				c.free()
		_map_dirty = false
	_update_3d_entities()
	_update_3d_overlays()
	_update_3d_fog()

# ── Material helpers ──────────────────────────────────────────────────────────
func _make_mat(col: Color, metallic: float = 0.0, roughness: float = 0.85,
			   emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color    = col
	m.metallic        = metallic
	m.roughness       = roughness
	# Auto-enable alpha transparency when colour has partial transparency
	if col.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission         = emission
		m.emission_energy_multiplier = emission_energy
	return m

func _make_mesh_inst(mesh: Mesh, mat: StandardMaterial3D,
					 px: float, py: float, pz: float, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	mi.position = Vector3(px, py, pz)
	parent.add_child(mi)
	return mi

# ── Tile mesh rebuild (full scene) ────────────────────────────────────────────
func _rebuild_3d_tiles() -> void:
	# Clear previous tiles (use free() not queue_free() to avoid
	# one-frame flicker when rebuilding immediately after clearing)
	for c in _tile_root.get_children():
		c.free()

	if _map.is_empty():
		# No map data yet — draw a plain placeholder grid so the 3D view
		# is not completely black while waiting for terrain selection.
		var ph_mat := StandardMaterial3D.new()
		ph_mat.albedo_color  = Color(0.12, 0.10, 0.18)
		ph_mat.roughness     = 0.9
		ph_mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
		var ph_mesh := BoxMesh.new(); ph_mesh.size = Vector3(0.96, 0.12, 0.96)
		for ty2 in range(MAP_SIZE):
			for tx2 in range(MAP_SIZE):
				var alt_mat := StandardMaterial3D.new()
				alt_mat.albedo_color = Color(0.15, 0.12, 0.22) if (tx2 + ty2) % 2 == 0 else Color(0.10, 0.08, 0.16)
				alt_mat.roughness = 0.9
				alt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				_make_mesh_inst(ph_mesh, alt_mat, float(tx2) + 0.5, 0.0, float(ty2) + 0.5, _tile_root)
		return

	var have_elev: bool = _elevation.size() == MAP_SIZE * MAP_SIZE

	# Deterministic RNG for decoration placement so rebuilds look stable
	var drng := RandomNumberGenerator.new()
	drng.seed = 1337

	# Pre-built mesh shapes (shared)
	var floor_mesh  := BoxMesh.new(); floor_mesh.size  = Vector3(0.98, 0.18, 0.98)
	var floor_mesh2 := BoxMesh.new(); floor_mesh2.size = Vector3(0.98, 0.18, 0.98)  # alt
	var wall_mesh   := BoxMesh.new(); wall_mesh.size   = Vector3(0.92, 1.50, 0.92)
	var obs_mesh    := BoxMesh.new(); obs_mesh.size    = Vector3(0.70, 0.65, 0.70)
	var crack_mesh  := BoxMesh.new(); crack_mesh.size  = Vector3(0.60, 0.02, 0.06)
	var rune_mesh   := BoxMesh.new(); rune_mesh.size   = Vector3(0.28, 0.02, 0.28)
	var pebble_mesh := BoxMesh.new(); pebble_mesh.size = Vector3(0.14, 0.10, 0.14)
	var brick_mesh  := BoxMesh.new(); brick_mesh.size  = Vector3(0.45, 0.42, 0.96)
	var brick2_mesh := BoxMesh.new(); brick2_mesh.size = Vector3(0.96, 0.42, 0.45)
	var pillar_cap_mesh := BoxMesh.new(); pillar_cap_mesh.size = Vector3(1.00, 0.10, 1.00)
	var ceil_beam_mesh := BoxMesh.new(); ceil_beam_mesh.size = Vector3(0.18, 0.22, 0.98)
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius    = 0.24
	barrel_mesh.bottom_radius = 0.26
	barrel_mesh.height        = 0.56
	var crate_mesh  := BoxMesh.new(); crate_mesh.size  = Vector3(0.54, 0.52, 0.54)

	for ty in range(MAP_SIZE):
		for tx in range(MAP_SIZE):
			# Render-distance culling — skip tiles far from any player on big
			# maps. _tile_in_render_radius returns true unconditionally when
			# culling is disabled (standard 25×25 dungeons).
			if not _tile_in_render_radius(tx, ty):
				continue
			var idx: int  = ty * MAP_SIZE + tx
			var tile: int = _map[idx]
			var cx: float = float(tx) + 0.5   # 3D world center X
			var cz: float = float(ty) + 0.5   # 3D world center Z (Y in tile space)

			var elev: int = 1
			if have_elev:
				elev = int(_elevation[idx])

			# Deterministic per-tile detail seed (drives decoration choices)
			var tile_seed: int = ((tx * 73856093) ^ (ty * 19349663)) & 0x7fffffff
			drng.seed = tile_seed

			match tile:
				0:
					# Void — nothing (background color shows through)
					pass
				1:
					# Floor — thin slab with inlay details
					var floor_y: float
					var floor_col: Color
					if elev == 0:   # pit
						floor_y   = -0.28
						floor_col = _c_floor.darkened(0.45)
					elif elev == 2:  # platform
						floor_y   = 0.38
						floor_col = _c_floor.lightened(0.25)
					else:
						floor_y   = 0.0
						floor_col = _c_floor if (tx + ty) % 2 == 0 else _c_floor_alt

					# Add slight per-tile color jitter so floor isn't uniform
					floor_col = floor_col.lerp(
						Color(floor_col.r + drng.randf_range(-0.04, 0.04),
							  floor_col.g + drng.randf_range(-0.04, 0.04),
							  floor_col.b + drng.randf_range(-0.04, 0.04)), 0.5)

					var roughness: float = 0.80 + drng.randf() * 0.08
					var fm: Mesh = floor_mesh if (tx + ty) % 2 == 0 else floor_mesh2
					var mat := _make_mat(floor_col, 0.02, roughness)
					_make_mesh_inst(fm, mat, cx, floor_y, cz, _tile_root)

					# Tile seam frame (darker outline at the tile edge, looks like paving stones)
					var seam_col: Color = floor_col.darkened(0.30)
					var seam_mat := _make_mat(seam_col, 0.0, 0.95)
					var seam_n := BoxMesh.new(); seam_n.size = Vector3(0.98, 0.02, 0.06)
					var seam_e := BoxMesh.new(); seam_e.size = Vector3(0.06, 0.02, 0.98)
					_make_mesh_inst(seam_n, seam_mat, cx, floor_y + 0.095, cz - 0.49, _tile_root)
					_make_mesh_inst(seam_e, seam_mat, cx + 0.49, floor_y + 0.095, cz, _tile_root)

					# Elevation edge step (carved accent trim)
					if have_elev and elev != 1:
						var edge_mesh := BoxMesh.new()
						edge_mesh.size = Vector3(0.98, 0.25, 0.98)
						var edge_mat := _make_mat(_c_accent.darkened(0.1), 0.25, 0.55,
							_c_accent.lerp(Color(0.8, 0.5, 0.15), 0.3), 0.20)
						_make_mesh_inst(edge_mesh, edge_mat, cx, floor_y - 0.18, cz, _tile_root)

					# Random floor decorations — cracks / runes / pebbles (~15% of tiles)
					var deco_roll: float = drng.randf()
					if deco_roll < 0.06:
						# Hairline crack
						var crack_mat := _make_mat(Color(0.05, 0.04, 0.03), 0.0, 1.0)
						var crack_angle: float = drng.randf() * TAU
						var crack_offx: float = drng.randf_range(-0.18, 0.18)
						var crack_offz: float = drng.randf_range(-0.18, 0.18)
						var crack := MeshInstance3D.new()
						crack.mesh = crack_mesh
						crack.set_surface_override_material(0, crack_mat)
						crack.position = Vector3(cx + crack_offx, floor_y + 0.099, cz + crack_offz)
						crack.rotation = Vector3(0.0, crack_angle, 0.0)
						_tile_root.add_child(crack)
					elif deco_roll < 0.09:
						# Subtle arcane rune (faintly glowing)
						var rune_col: Color = _c_accent.lerp(Color(0.55, 0.35, 0.85), 0.4)
						var rune_mat := _make_mat(rune_col, 0.2, 0.4, rune_col, 0.55)
						_make_mesh_inst(rune_mesh, rune_mat,
							cx, floor_y + 0.100, cz, _tile_root)
					elif deco_roll < 0.15:
						# Small pebble pile (1–3 stones)
						var peb_count: int = drng.randi_range(1, 3)
						for pi in range(peb_count):
							var peb_col: Color = _c_obstacle.darkened(drng.randf() * 0.4)
							var peb_mat := _make_mat(peb_col, 0.0, 0.95)
							_make_mesh_inst(pebble_mesh, peb_mat,
								cx + drng.randf_range(-0.30, 0.30),
								floor_y + 0.15,
								cz + drng.randf_range(-0.30, 0.30),
								_tile_root)

				2:
					# Wall — biome-aware style
					var base_wall_tint: Color = _c_wall.lerp(Color(0.08, 0.07, 0.10),
						0.3 + drng.randf() * 0.15)
					var wall_mat := _make_mat(base_wall_tint, 0.05, 0.88)
					var base_mat := _make_mat(_c_wall.darkened(0.35), 0.0, 0.95)
					var base_m := BoxMesh.new(); base_m.size = Vector3(1.0, 0.20, 1.0)
					_make_mesh_inst(base_m, base_mat, cx, 0.02, cz, _tile_root)
					_make_mesh_inst(wall_mesh, wall_mat, cx, 0.84, cz, _tile_root)

					# Wall detail based on biome wall_style
					match _biome_wall_style:
						"brick":
							var brick_mat_a := _make_mat(base_wall_tint.lightened(0.05), 0.05, 0.82)
							var brick_mat_b := _make_mat(base_wall_tint.darkened(0.10), 0.05, 0.95)
							var wlower_y: float = 0.44
							if (tx + ty) % 2 == 0:
								_make_mesh_inst(brick_mesh,  brick_mat_a, cx - 0.24, wlower_y, cz, _tile_root)
								_make_mesh_inst(brick_mesh,  brick_mat_b, cx + 0.24, wlower_y, cz, _tile_root)
							else:
								_make_mesh_inst(brick2_mesh, brick_mat_a, cx, wlower_y, cz - 0.24, _tile_root)
								_make_mesh_inst(brick2_mesh, brick_mat_b, cx, wlower_y, cz + 0.24, _tile_root)
							var wupper_y: float = 1.12
							if (tx + ty) % 2 == 0:
								_make_mesh_inst(brick2_mesh, brick_mat_b, cx, wupper_y, cz - 0.24, _tile_root)
								_make_mesh_inst(brick2_mesh, brick_mat_a, cx, wupper_y, cz + 0.24, _tile_root)
							else:
								_make_mesh_inst(brick_mesh,  brick_mat_b, cx - 0.24, wupper_y, cz, _tile_root)
								_make_mesh_inst(brick_mesh,  brick_mat_a, cx + 0.24, wupper_y, cz, _tile_root)
						"rock":
							# Jagged rock surface — irregular protrusions
							for rock_i in range(drng.randi_range(2, 4)):
								var rk_sz := Vector3(drng.randf_range(0.15, 0.35), drng.randf_range(0.20, 0.45), drng.randf_range(0.15, 0.35))
								var rk_m := BoxMesh.new(); rk_m.size = rk_sz
								var rk_col: Color = base_wall_tint.lerp(_c_obstacle, drng.randf() * 0.3)
								_make_mesh_inst(rk_m, _make_mat(rk_col, 0.0, 0.92),
									cx + drng.randf_range(-0.35, 0.35),
									0.35 + drng.randf() * 0.8,
									cz + drng.randf_range(-0.35, 0.35), _tile_root)
						"wood":
							# Wooden planks / bark texture — horizontal log slabs
							var plank_col: Color = Color(0.30, 0.20, 0.10).lerp(base_wall_tint, 0.3)
							for pi in range(3):
								var plank_m := BoxMesh.new()
								plank_m.size = Vector3(0.96, 0.28, 0.08) if pi % 2 == 0 else Vector3(0.08, 0.28, 0.96)
								var plank_mat := _make_mat(plank_col.lerp(Color(0.22, 0.14, 0.06), drng.randf() * 0.3), 0.0, 0.85)
								var py: float = 0.35 + float(pi) * 0.38
								var px_off: float = 0.46 if pi % 2 == 0 else 0.0
								var pz_off: float = 0.0 if pi % 2 == 0 else 0.46
								var side_pick: int = drng.randi_range(0, 1)
								if side_pick == 0: px_off = -px_off
								if side_pick == 1: pz_off = -pz_off
								_make_mesh_inst(plank_m, plank_mat, cx + px_off, py, cz + pz_off, _tile_root)
						"ice":
							# Icy facets — translucent crystal shards on wall face
							for ice_i in range(drng.randi_range(1, 3)):
								var ice_sz := Vector3(drng.randf_range(0.10, 0.25), drng.randf_range(0.30, 0.60), drng.randf_range(0.10, 0.25))
								var ice_m := BoxMesh.new(); ice_m.size = ice_sz
								var ice_col: Color = Color(0.60, 0.80, 0.95, 0.75)
								var ice_mat := _make_mat(ice_col, 0.85, 0.15, ice_col, 0.4)
								ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
								ice_mat.albedo_color.a = 0.7
								_make_mesh_inst(ice_m, ice_mat,
									cx + drng.randf_range(-0.30, 0.30),
									0.40 + drng.randf() * 0.7,
									cz + drng.randf_range(-0.30, 0.30), _tile_root)
						"coral":
							# Coral growths — rounded bumps on wall
							for cor_i in range(drng.randi_range(2, 5)):
								var cor_r: float = drng.randf_range(0.06, 0.16)
								var cor_mesh := SphereMesh.new()
								cor_mesh.radius = cor_r; cor_mesh.height = cor_r * 2.0
								var cor_col: Color = Color(
									drng.randf_range(0.7, 1.0),
									drng.randf_range(0.2, 0.5),
									drng.randf_range(0.3, 0.7))
								_make_mesh_inst(cor_mesh, _make_mat(cor_col, 0.1, 0.65),
									cx + drng.randf_range(-0.40, 0.40),
									0.35 + drng.randf() * 0.8,
									cz + drng.randf_range(-0.40, 0.40), _tile_root)
						"bone":
							# Bone / skull motifs — stacked femur-like cylinders
							for bone_i in range(drng.randi_range(2, 4)):
								var bone_m := CylinderMesh.new()
								bone_m.top_radius = drng.randf_range(0.04, 0.08)
								bone_m.bottom_radius = drng.randf_range(0.04, 0.08)
								bone_m.height = drng.randf_range(0.25, 0.50)
								var bone_col: Color = Color(0.82, 0.78, 0.68).darkened(drng.randf() * 0.2)
								var bone_inst := MeshInstance3D.new()
								bone_inst.mesh = bone_m
								bone_inst.set_surface_override_material(0, _make_mat(bone_col, 0.05, 0.80))
								bone_inst.position = Vector3(
									cx + drng.randf_range(-0.35, 0.35),
									0.35 + drng.randf() * 0.6,
									cz + drng.randf_range(-0.35, 0.35))
								bone_inst.rotation = Vector3(drng.randf_range(-0.5, 0.5), drng.randf() * TAU, drng.randf_range(-0.5, 0.5))
								_tile_root.add_child(bone_inst)
						"crystal":
							# Crystal shards jutting from wall
							for cry_i in range(drng.randi_range(1, 3)):
								var cry_m := CylinderMesh.new()
								cry_m.top_radius = 0.02
								cry_m.bottom_radius = drng.randf_range(0.06, 0.12)
								cry_m.height = drng.randf_range(0.25, 0.55)
								var cry_col: Color = _c_accent.lerp(Color(0.6, 0.4, 1.0), drng.randf() * 0.5)
								var cry_mat := _make_mat(cry_col, 0.80, 0.18, cry_col, 0.6)
								var cry_inst := MeshInstance3D.new()
								cry_inst.mesh = cry_m
								cry_inst.set_surface_override_material(0, cry_mat)
								cry_inst.position = Vector3(
									cx + drng.randf_range(-0.30, 0.30),
									0.40 + drng.randf() * 0.6,
									cz + drng.randf_range(-0.30, 0.30))
								cry_inst.rotation = Vector3(drng.randf_range(-0.6, 0.6), drng.randf() * TAU, drng.randf_range(-0.6, 0.6))
								_tile_root.add_child(cry_inst)
						"sand":
							# Sandstone layers — horizontal bands
							for sand_i in range(3):
								var sand_m := BoxMesh.new()
								sand_m.size = Vector3(0.96, 0.12, 0.96)
								var sand_col: Color = Color(0.55, 0.45, 0.30).lerp(Color(0.65, 0.52, 0.35), drng.randf() * 0.4)
								_make_mesh_inst(sand_m, _make_mat(sand_col, 0.0, 0.90),
									cx, 0.30 + float(sand_i) * 0.38, cz, _tile_root)
						"metal":
							# Riveted metal plates
							var plate_col: Color = Color(0.35, 0.32, 0.28).lerp(base_wall_tint, 0.3)
							for mtl_i in range(2):
								var plate_m := BoxMesh.new()
								plate_m.size = Vector3(0.92, 0.60, 0.06) if mtl_i == 0 else Vector3(0.06, 0.60, 0.92)
								var mtl_side: float = 0.46 if mtl_i == 0 else 0.0
								var mtl_side2: float = 0.0 if mtl_i == 0 else 0.46
								_make_mesh_inst(plate_m, _make_mat(plate_col, 0.75, 0.30),
									cx + mtl_side * (1 if (tx + ty) % 2 == 0 else -1),
									0.70,
									cz + mtl_side2 * (1 if (tx + ty) % 2 == 0 else -1), _tile_root)
							# Rivet dots
							for rv_i in range(drng.randi_range(2, 4)):
								var rv_m := SphereMesh.new(); rv_m.radius = 0.04; rv_m.height = 0.08
								_make_mesh_inst(rv_m, _make_mat(plate_col.lightened(0.2), 0.8, 0.25),
									cx + drng.randf_range(-0.38, 0.38),
									0.40 + drng.randf() * 0.6,
									cz + drng.randf_range(-0.38, 0.38), _tile_root)

					# Wall moss / dampness (biome-dependent accent)
					var moss_chance: float = 0.22
					var moss_col: Color = Color(0.18, 0.35, 0.14)
					match _biome_prop_set:
						"ice": moss_chance = 0.30; moss_col = Color(0.55, 0.70, 0.85)
						"swamp": moss_chance = 0.45; moss_col = Color(0.12, 0.30, 0.08)
						"coral", "aquatic": moss_chance = 0.40; moss_col = Color(0.10, 0.35, 0.30)
						"volcanic", "infernal": moss_chance = 0.15; moss_col = Color(0.45, 0.15, 0.05)
						"desert": moss_chance = 0.05
						"void": moss_chance = 0.10; moss_col = Color(0.20, 0.08, 0.35)
					if drng.randf() < moss_chance:
						var w_moss_mat := _make_mat(moss_col, 0.0, 1.0, moss_col, 0.12)
						var w_moss_mesh := BoxMesh.new()
						w_moss_mesh.size = Vector3(0.10, 0.55, 0.96)
						var w_side: int = drng.randi_range(0, 3)
						var w_mox: float = 0.0
						var w_moz: float = 0.0
						if w_side == 0: w_mox = -0.48
						elif w_side == 1: w_mox = 0.48
						elif w_side == 2: w_moz = -0.48; w_moss_mesh.size = Vector3(0.96, 0.55, 0.10)
						else: w_moz = 0.48; w_moss_mesh.size = Vector3(0.96, 0.55, 0.10)
						_make_mesh_inst(w_moss_mesh, w_moss_mat, cx + w_mox, 0.32, cz + w_moz, _tile_root)

					# Top cap
					var cap_col: Color = base_wall_tint.lightened(0.12)
					_make_mesh_inst(pillar_cap_mesh, _make_mat(cap_col, 0.10, 0.6),
						cx, 1.65, cz, _tile_root)
					var trim_m := BoxMesh.new(); trim_m.size = Vector3(1.02, 0.08, 1.02)
					var trim_col: Color = _c_accent.darkened(0.25)
					_make_mesh_inst(trim_m, _make_mat(trim_col, 0.18, 0.45,
						_c_accent.darkened(0.5), 0.10), cx, 1.58, cz, _tile_root)

				3:
					# Obstacle — biome-specific props
					var obs_base := BoxMesh.new(); obs_base.size = Vector3(0.98, 0.18, 0.98)
					_make_mesh_inst(obs_base, _make_mat(_c_floor, 0.0, 0.85),
						cx, 0.0, cz, _tile_root)
					_build_biome_obstacle(cx, cz, drng, tile_seed)

	# ── Biome-aware ceiling ──────────────────────────────────────────────────────
	_build_biome_ceiling(drng)

# ── Biome obstacle builder ────────────────────────────────────────────────────
func _build_biome_obstacle(cx: float, cz: float, drng: RandomNumberGenerator, tile_seed: int) -> void:
	var kind: int = tile_seed % 4
	match _biome_prop_set:
		"cave":
			# Stalagmites + rock chunks
			if kind < 2:
				var stag_m := CylinderMesh.new()
				stag_m.bottom_radius = drng.randf_range(0.14, 0.24)
				stag_m.top_radius = drng.randf_range(0.02, 0.06)
				stag_m.height = drng.randf_range(0.50, 0.90)
				var stag_col: Color = _c_obstacle.lerp(Color(0.25, 0.20, 0.15), drng.randf() * 0.3)
				_make_mesh_inst(stag_m, _make_mat(stag_col, 0.05, 0.85),
					cx, stag_m.height * 0.5 + 0.10, cz, _tile_root)
			else:
				var rock_m := BoxMesh.new()
				rock_m.size = Vector3(drng.randf_range(0.40, 0.65), drng.randf_range(0.35, 0.60), drng.randf_range(0.40, 0.65))
				var rock_col: Color = _c_obstacle.darkened(drng.randf() * 0.25)
				var rock_inst := MeshInstance3D.new()
				rock_inst.mesh = rock_m
				rock_inst.set_surface_override_material(0, _make_mat(rock_col, 0.0, 0.90))
				rock_inst.position = Vector3(cx, rock_m.size.y * 0.5 + 0.10, cz)
				rock_inst.rotation.y = drng.randf() * TAU
				_tile_root.add_child(rock_inst)
		"grassland":
			# Boulders + tall grass tufts
			if kind < 2:
				var boulder_m := SphereMesh.new()
				boulder_m.radius = drng.randf_range(0.20, 0.32)
				boulder_m.height = boulder_m.radius * 1.6
				var b_col: Color = Color(0.35, 0.30, 0.25).darkened(drng.randf() * 0.2)
				_make_mesh_inst(boulder_m, _make_mat(b_col, 0.0, 0.88),
					cx, boulder_m.radius + 0.10, cz, _tile_root)
			else:
				# Tall grass / bush cluster
				for gi in range(drng.randi_range(2, 4)):
					var grass_m := BoxMesh.new()
					grass_m.size = Vector3(0.06, drng.randf_range(0.30, 0.55), 0.06)
					var g_col: Color = Color(0.20, 0.45, 0.12).lerp(Color(0.30, 0.55, 0.15), drng.randf())
					var g_inst := MeshInstance3D.new()
					g_inst.mesh = grass_m
					g_inst.set_surface_override_material(0, _make_mat(g_col, 0.0, 0.90))
					g_inst.position = Vector3(cx + drng.randf_range(-0.25, 0.25), grass_m.size.y * 0.5 + 0.10, cz + drng.randf_range(-0.25, 0.25))
					g_inst.rotation.y = drng.randf() * TAU
					_tile_root.add_child(g_inst)
		"forest", "overgrown":
			# Trees (trunk + canopy sphere) or fallen logs
			if kind < 3:
				# Standing tree
				var trunk_m := CylinderMesh.new()
				trunk_m.bottom_radius = drng.randf_range(0.08, 0.14)
				trunk_m.top_radius = drng.randf_range(0.05, 0.09)
				trunk_m.height = drng.randf_range(0.70, 1.10)
				var trunk_col: Color = Color(0.28, 0.18, 0.08).darkened(drng.randf() * 0.15)
				_make_mesh_inst(trunk_m, _make_mat(trunk_col, 0.0, 0.88),
					cx, trunk_m.height * 0.5 + 0.10, cz, _tile_root)
				# Canopy
				var canopy_m := SphereMesh.new()
				canopy_m.radius = drng.randf_range(0.22, 0.38)
				canopy_m.height = canopy_m.radius * 1.5
				var canopy_col: Color = Color(0.12, 0.38, 0.08).lerp(Color(0.18, 0.50, 0.12), drng.randf())
				_make_mesh_inst(canopy_m, _make_mat(canopy_col, 0.0, 0.85),
					cx, trunk_m.height + 0.10 + canopy_m.radius * 0.4, cz, _tile_root)
			else:
				# Fallen log
				var log_m := CylinderMesh.new()
				log_m.top_radius = drng.randf_range(0.10, 0.16)
				log_m.bottom_radius = log_m.top_radius + 0.02
				log_m.height = drng.randf_range(0.55, 0.85)
				var log_col: Color = Color(0.22, 0.14, 0.06)
				var log_inst := MeshInstance3D.new()
				log_inst.mesh = log_m
				log_inst.set_surface_override_material(0, _make_mat(log_col, 0.0, 0.85))
				log_inst.position = Vector3(cx, 0.22, cz)
				log_inst.rotation.z = PI * 0.5
				log_inst.rotation.y = drng.randf() * TAU
				_tile_root.add_child(log_inst)
		"urban", "elven", "dwarven":
			# Rubble piles, broken columns, crates
			if kind == 0:
				# Broken column
				var col_m := CylinderMesh.new()
				col_m.top_radius = 0.22; col_m.bottom_radius = 0.26
				col_m.height = drng.randf_range(0.45, 0.80)
				var col_col: Color = _c_wall.lerp(Color(0.42, 0.38, 0.35), 0.4)
				_make_mesh_inst(col_m, _make_mat(col_col, 0.08, 0.72),
					cx, col_m.height * 0.5 + 0.10, cz, _tile_root)
			elif kind == 1:
				# Wooden crate
				var crt_m := BoxMesh.new(); crt_m.size = Vector3(0.50, 0.48, 0.50)
				var crt_col := Color(0.38, 0.24, 0.14)
				var crt_inst := MeshInstance3D.new()
				crt_inst.mesh = crt_m
				crt_inst.set_surface_override_material(0, _make_mat(crt_col, 0.0, 0.85))
				crt_inst.position = Vector3(cx, 0.34, cz)
				crt_inst.rotation.y = drng.randf_range(-0.4, 0.4)
				_tile_root.add_child(crt_inst)
				var band_m := BoxMesh.new(); band_m.size = Vector3(0.54, 0.05, 0.54)
				_make_mesh_inst(band_m, _make_mat(Color(0.28, 0.22, 0.18), 0.6, 0.35), cx, 0.14, cz, _tile_root)
			elif kind == 2:
				# Barrel
				var bar_m := CylinderMesh.new()
				bar_m.top_radius = 0.22; bar_m.bottom_radius = 0.24; bar_m.height = 0.52
				var bar_col := Color(0.32, 0.20, 0.12)
				var bar_inst := MeshInstance3D.new()
				bar_inst.mesh = bar_m
				bar_inst.set_surface_override_material(0, _make_mat(bar_col, 0.05, 0.75))
				bar_inst.position = Vector3(cx, 0.36, cz)
				bar_inst.rotation.y = drng.randf_range(-0.3, 0.3)
				_tile_root.add_child(bar_inst)
			else:
				# Rubble pile
				for rb_i in range(drng.randi_range(3, 6)):
					var rb_sz := Vector3(drng.randf_range(0.08, 0.18), drng.randf_range(0.06, 0.14), drng.randf_range(0.08, 0.18))
					var rb_m := BoxMesh.new(); rb_m.size = rb_sz
					var rb_col: Color = _c_wall.darkened(drng.randf() * 0.3)
					_make_mesh_inst(rb_m, _make_mat(rb_col, 0.05, 0.90),
						cx + drng.randf_range(-0.30, 0.30), rb_sz.y * 0.5 + 0.10,
						cz + drng.randf_range(-0.30, 0.30), _tile_root)
		"volcanic", "infernal":
			# Lava rocks, obsidian shards, ember vents
			if kind < 2:
				# Obsidian shard
				var shard_m := CylinderMesh.new()
				shard_m.top_radius = 0.02; shard_m.bottom_radius = drng.randf_range(0.10, 0.18)
				shard_m.height = drng.randf_range(0.40, 0.75)
				var shard_col: Color = Color(0.08, 0.06, 0.10)
				var shard_mat := _make_mat(shard_col, 0.70, 0.25)
				var shard_inst := MeshInstance3D.new()
				shard_inst.mesh = shard_m
				shard_inst.set_surface_override_material(0, shard_mat)
				shard_inst.position = Vector3(cx, shard_m.height * 0.5 + 0.10, cz)
				shard_inst.rotation = Vector3(drng.randf_range(-0.2, 0.2), drng.randf() * TAU, drng.randf_range(-0.2, 0.2))
				_tile_root.add_child(shard_inst)
			else:
				# Lava rock + ember glow
				var lava_m := BoxMesh.new()
				lava_m.size = Vector3(drng.randf_range(0.35, 0.55), drng.randf_range(0.25, 0.45), drng.randf_range(0.35, 0.55))
				var lava_col: Color = Color(0.15, 0.08, 0.04)
				_make_mesh_inst(lava_m, _make_mat(lava_col, 0.0, 0.90), cx, lava_m.size.y * 0.5 + 0.10, cz, _tile_root)
				# Glowing ember crack
				var ember_m := BoxMesh.new(); ember_m.size = Vector3(0.35, 0.03, 0.08)
				var ember_col: Color = Color(1.0, 0.35, 0.05)
				_make_mesh_inst(ember_m, _make_mat(ember_col, 0.2, 0.5, ember_col, 2.0),
					cx, lava_m.size.y + 0.12, cz, _tile_root)
		"aquatic", "coral":
			# Coral formations, seaweed, shells
			if kind < 2:
				# Coral branch cluster
				for ci in range(drng.randi_range(2, 4)):
					var c_m := CylinderMesh.new()
					c_m.bottom_radius = drng.randf_range(0.04, 0.10)
					c_m.top_radius = drng.randf_range(0.06, 0.14)
					c_m.height = drng.randf_range(0.25, 0.55)
					var c_col: Color = Color(drng.randf_range(0.6, 1.0), drng.randf_range(0.15, 0.5), drng.randf_range(0.2, 0.6))
					var c_inst := MeshInstance3D.new()
					c_inst.mesh = c_m
					c_inst.set_surface_override_material(0, _make_mat(c_col, 0.15, 0.60))
					c_inst.position = Vector3(cx + drng.randf_range(-0.20, 0.20), c_m.height * 0.5 + 0.10, cz + drng.randf_range(-0.20, 0.20))
					c_inst.rotation = Vector3(drng.randf_range(-0.3, 0.3), drng.randf() * TAU, drng.randf_range(-0.3, 0.3))
					_tile_root.add_child(c_inst)
			else:
				# Seaweed strands
				for sw_i in range(drng.randi_range(3, 6)):
					var sw_m := BoxMesh.new()
					sw_m.size = Vector3(0.04, drng.randf_range(0.35, 0.65), 0.04)
					var sw_col: Color = Color(0.08, 0.35, 0.15).lerp(Color(0.12, 0.45, 0.20), drng.randf())
					var sw_inst := MeshInstance3D.new()
					sw_inst.mesh = sw_m
					sw_inst.set_surface_override_material(0, _make_mat(sw_col, 0.0, 0.85))
					sw_inst.position = Vector3(cx + drng.randf_range(-0.28, 0.28), sw_m.size.y * 0.5 + 0.10, cz + drng.randf_range(-0.28, 0.28))
					sw_inst.rotation = Vector3(drng.randf_range(-0.15, 0.15), drng.randf() * TAU, drng.randf_range(-0.15, 0.15))
					_tile_root.add_child(sw_inst)
		"arcane", "void":
			# Floating rune stones, arcane obelisks
			if kind < 2:
				# Floating rune cube
				var rune_m := BoxMesh.new()
				rune_m.size = Vector3(0.28, 0.28, 0.28)
				var rune_col: Color = _c_accent.lerp(Color(0.6, 0.3, 1.0), 0.4)
				var rune_mat := _make_mat(rune_col, 0.6, 0.25, rune_col, 1.2)
				var rune_inst := MeshInstance3D.new()
				rune_inst.mesh = rune_m
				rune_inst.set_surface_override_material(0, rune_mat)
				rune_inst.position = Vector3(cx, 0.55 + drng.randf() * 0.3, cz)
				rune_inst.rotation = Vector3(0.45, drng.randf() * TAU, 0.45)
				_tile_root.add_child(rune_inst)
			else:
				# Obelisk
				var ob_m := CylinderMesh.new()
				ob_m.top_radius = 0.04; ob_m.bottom_radius = 0.14
				ob_m.height = drng.randf_range(0.55, 0.85)
				var ob_col: Color = Color(0.12, 0.08, 0.22)
				_make_mesh_inst(ob_m, _make_mat(ob_col, 0.4, 0.45, _c_accent, 0.5),
					cx, ob_m.height * 0.5 + 0.10, cz, _tile_root)
		"necro", "blood":
			# Tombstones, coffins, bone piles
			if kind == 0:
				# Tombstone slab
				var tomb_m := BoxMesh.new()
				tomb_m.size = Vector3(0.35, drng.randf_range(0.50, 0.75), 0.10)
				var tomb_col: Color = Color(0.30, 0.28, 0.25).darkened(drng.randf() * 0.2)
				var tomb_inst := MeshInstance3D.new()
				tomb_inst.mesh = tomb_m
				tomb_inst.set_surface_override_material(0, _make_mat(tomb_col, 0.05, 0.82))
				tomb_inst.position = Vector3(cx, tomb_m.size.y * 0.5 + 0.10, cz)
				tomb_inst.rotation.y = drng.randf_range(-0.2, 0.2)
				_tile_root.add_child(tomb_inst)
			elif kind == 1:
				# Coffin
				var cof_m := BoxMesh.new(); cof_m.size = Vector3(0.30, 0.22, 0.65)
				var cof_col: Color = Color(0.18, 0.12, 0.08)
				var cof_inst := MeshInstance3D.new()
				cof_inst.mesh = cof_m
				cof_inst.set_surface_override_material(0, _make_mat(cof_col, 0.0, 0.85))
				cof_inst.position = Vector3(cx, 0.21, cz)
				cof_inst.rotation.y = drng.randf_range(-0.3, 0.3)
				_tile_root.add_child(cof_inst)
			else:
				# Bone pile
				for bp_i in range(drng.randi_range(3, 6)):
					var bp_m := CylinderMesh.new()
					bp_m.top_radius = drng.randf_range(0.02, 0.05)
					bp_m.bottom_radius = bp_m.top_radius
					bp_m.height = drng.randf_range(0.12, 0.30)
					var bp_col: Color = Color(0.80, 0.75, 0.62).darkened(drng.randf() * 0.3)
					var bp_inst := MeshInstance3D.new()
					bp_inst.mesh = bp_m
					bp_inst.set_surface_override_material(0, _make_mat(bp_col, 0.05, 0.82))
					bp_inst.position = Vector3(cx + drng.randf_range(-0.28, 0.28), 0.15, cz + drng.randf_range(-0.28, 0.28))
					bp_inst.rotation = Vector3(drng.randf() * TAU, drng.randf() * TAU, drng.randf() * TAU)
					_tile_root.add_child(bp_inst)
		"ice":
			# Icicles, ice boulders, frozen pillars
			if kind < 2:
				# Ice stalagmite
				var ice_m := CylinderMesh.new()
				ice_m.bottom_radius = drng.randf_range(0.12, 0.22)
				ice_m.top_radius = drng.randf_range(0.02, 0.06)
				ice_m.height = drng.randf_range(0.45, 0.80)
				var ice_col: Color = Color(0.55, 0.72, 0.88, 0.80)
				var ice_mat := _make_mat(ice_col, 0.80, 0.18, Color(0.60, 0.80, 0.95), 0.3)
				ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				ice_mat.albedo_color.a = 0.75
				_make_mesh_inst(ice_m, ice_mat, cx, ice_m.height * 0.5 + 0.10, cz, _tile_root)
			else:
				# Frozen boulder
				var fb_m := SphereMesh.new()
				fb_m.radius = drng.randf_range(0.22, 0.35); fb_m.height = fb_m.radius * 1.8
				var fb_col: Color = Color(0.50, 0.62, 0.75)
				_make_mesh_inst(fb_m, _make_mat(fb_col, 0.60, 0.30),
					cx, fb_m.radius + 0.10, cz, _tile_root)
		"swamp":
			# Dead trees, mud mounds, lily pad stumps
			if kind < 2:
				# Dead tree stump
				var dt_m := CylinderMesh.new()
				dt_m.bottom_radius = drng.randf_range(0.10, 0.16)
				dt_m.top_radius = drng.randf_range(0.06, 0.12)
				dt_m.height = drng.randf_range(0.40, 0.70)
				var dt_col: Color = Color(0.15, 0.10, 0.06)
				_make_mesh_inst(dt_m, _make_mat(dt_col, 0.0, 0.90),
					cx, dt_m.height * 0.5 + 0.10, cz, _tile_root)
				# Fungus on stump
				var fg_m := SphereMesh.new(); fg_m.radius = 0.08; fg_m.height = 0.06
				var fg_col: Color = Color(0.45, 0.35, 0.15)
				_make_mesh_inst(fg_m, _make_mat(fg_col, 0.0, 0.85),
					cx + 0.12, dt_m.height * 0.3 + 0.10, cz, _tile_root)
			else:
				# Mud mound with bubbles
				var mud_m := SphereMesh.new()
				mud_m.radius = drng.randf_range(0.20, 0.30); mud_m.height = mud_m.radius * 0.8
				var mud_col: Color = Color(0.16, 0.14, 0.08)
				_make_mesh_inst(mud_m, _make_mat(mud_col, 0.0, 0.95),
					cx, mud_m.radius * 0.3 + 0.10, cz, _tile_root)
		"desert":
			# Sandstone pillars, pottery shards, palm stumps
			if kind < 2:
				# Sandstone pillar fragment
				var sp_m := CylinderMesh.new()
				sp_m.bottom_radius = drng.randf_range(0.14, 0.22)
				sp_m.top_radius = sp_m.bottom_radius - 0.02
				sp_m.height = drng.randf_range(0.40, 0.70)
				var sp_col: Color = Color(0.60, 0.48, 0.32).darkened(drng.randf() * 0.15)
				_make_mesh_inst(sp_m, _make_mat(sp_col, 0.0, 0.85),
					cx, sp_m.height * 0.5 + 0.10, cz, _tile_root)
			else:
				# Pottery / urn
				var urn_m := CylinderMesh.new()
				urn_m.bottom_radius = 0.10; urn_m.top_radius = 0.16; urn_m.height = 0.38
				var urn_col: Color = Color(0.55, 0.35, 0.18)
				_make_mesh_inst(urn_m, _make_mat(urn_col, 0.0, 0.80),
					cx, 0.29, cz, _tile_root)
		"mushroom":
			# Giant mushrooms
			var cap_radius: float = drng.randf_range(0.20, 0.38)
			var stem_h: float = drng.randf_range(0.30, 0.65)
			# Stem
			var stem_m := CylinderMesh.new()
			stem_m.bottom_radius = drng.randf_range(0.06, 0.10)
			stem_m.top_radius = drng.randf_range(0.04, 0.08)
			stem_m.height = stem_h
			var stem_col: Color = Color(0.75, 0.72, 0.65)
			_make_mesh_inst(stem_m, _make_mat(stem_col, 0.0, 0.85),
				cx, stem_h * 0.5 + 0.10, cz, _tile_root)
			# Cap
			var cap_m := SphereMesh.new()
			cap_m.radius = cap_radius; cap_m.height = cap_radius * 0.8
			var cap_col: Color = Color(
				drng.randf_range(0.5, 0.9),
				drng.randf_range(0.1, 0.4),
				drng.randf_range(0.4, 0.8))
			var cap_mat := _make_mat(cap_col, 0.1, 0.60, cap_col, 0.3)
			_make_mesh_inst(cap_m, cap_mat, cx, stem_h + 0.10, cz, _tile_root)
			# Spore glow dots on cap
			for sd_i in range(drng.randi_range(2, 5)):
				var dot_m := SphereMesh.new(); dot_m.radius = 0.03; dot_m.height = 0.06
				var dot_col: Color = cap_col.lightened(0.4)
				_make_mesh_inst(dot_m, _make_mat(dot_col, 0.0, 0.5, dot_col, 1.0),
					cx + drng.randf_range(-cap_radius * 0.6, cap_radius * 0.6),
					stem_h + 0.10 + drng.randf_range(-0.05, 0.08),
					cz + drng.randf_range(-cap_radius * 0.6, cap_radius * 0.6), _tile_root)
		"crystal":
			# Crystal clusters
			for cr_i in range(drng.randi_range(2, 4)):
				var cr_m := CylinderMesh.new()
				cr_m.top_radius = 0.02
				cr_m.bottom_radius = drng.randf_range(0.06, 0.14)
				cr_m.height = drng.randf_range(0.30, 0.70)
				var cr_col: Color = _c_accent.lerp(Color(drng.randf_range(0.3, 0.7), drng.randf_range(0.4, 0.8), 1.0), 0.5)
				var cr_mat := _make_mat(cr_col, 0.85, 0.15, cr_col, 0.8)
				var cr_inst := MeshInstance3D.new()
				cr_inst.mesh = cr_m
				cr_inst.set_surface_override_material(0, cr_mat)
				cr_inst.position = Vector3(
					cx + drng.randf_range(-0.22, 0.22),
					cr_m.height * 0.5 + 0.10,
					cz + drng.randf_range(-0.22, 0.22))
				cr_inst.rotation = Vector3(drng.randf_range(-0.4, 0.4), drng.randf() * TAU, drng.randf_range(-0.4, 0.4))
				_tile_root.add_child(cr_inst)
		"forge":
			# Gears, anvils, pipes
			if kind < 2:
				# Gear (torus)
				var gear_m := TorusMesh.new()
				gear_m.inner_radius = drng.randf_range(0.12, 0.20)
				gear_m.outer_radius = gear_m.inner_radius + drng.randf_range(0.06, 0.10)
				gear_m.rings = 6; gear_m.ring_segments = 12
				var gear_col: Color = Color(0.35, 0.30, 0.22)
				var gear_inst := MeshInstance3D.new()
				gear_inst.mesh = gear_m
				gear_inst.set_surface_override_material(0, _make_mat(gear_col, 0.75, 0.30))
				gear_inst.position = Vector3(cx, 0.35, cz)
				gear_inst.rotation.x = PI * 0.5
				_tile_root.add_child(gear_inst)
			else:
				# Anvil shape (box + wedge)
				var anvil_m := BoxMesh.new(); anvil_m.size = Vector3(0.40, 0.35, 0.28)
				var anvil_col: Color = Color(0.25, 0.22, 0.18)
				_make_mesh_inst(anvil_m, _make_mat(anvil_col, 0.80, 0.28),
					cx, 0.28, cz, _tile_root)
				var horn_m := BoxMesh.new(); horn_m.size = Vector3(0.15, 0.12, 0.40)
				_make_mesh_inst(horn_m, _make_mat(anvil_col.lightened(0.1), 0.75, 0.30),
					cx, 0.48, cz, _tile_root)
		"sewer":
			# Sludge puddles, grates, pipes
			if kind < 2:
				# Sewer pipe
				var pipe_m := CylinderMesh.new()
				pipe_m.top_radius = 0.18; pipe_m.bottom_radius = 0.18; pipe_m.height = 0.55
				var pipe_col: Color = Color(0.22, 0.20, 0.16)
				var pipe_inst := MeshInstance3D.new()
				pipe_inst.mesh = pipe_m
				pipe_inst.set_surface_override_material(0, _make_mat(pipe_col, 0.50, 0.45))
				pipe_inst.position = Vector3(cx, 0.22, cz)
				pipe_inst.rotation.z = PI * 0.5
				_tile_root.add_child(pipe_inst)
			else:
				# Sludge puddle (flat disc)
				var sludge_m := CylinderMesh.new()
				sludge_m.top_radius = drng.randf_range(0.25, 0.40)
				sludge_m.bottom_radius = sludge_m.top_radius
				sludge_m.height = 0.04
				var sludge_col: Color = Color(0.15, 0.18, 0.08, 0.85)
				var sludge_mat := _make_mat(sludge_col, 0.3, 0.50, Color(0.18, 0.22, 0.10), 0.2)
				_make_mesh_inst(sludge_m, sludge_mat, cx, 0.12, cz, _tile_root)
		"sky":
			# Cloud wisps, floating stones, pillars of light
			if kind < 2:
				# Floating stone
				var fs_m := BoxMesh.new()
				fs_m.size = Vector3(drng.randf_range(0.25, 0.45), drng.randf_range(0.15, 0.30), drng.randf_range(0.25, 0.45))
				var fs_col: Color = Color(0.70, 0.72, 0.78)
				var fs_inst := MeshInstance3D.new()
				fs_inst.mesh = fs_m
				fs_inst.set_surface_override_material(0, _make_mat(fs_col, 0.3, 0.55))
				fs_inst.position = Vector3(cx, 0.45 + drng.randf() * 0.3, cz)
				fs_inst.rotation = Vector3(drng.randf_range(-0.2, 0.2), drng.randf() * TAU, drng.randf_range(-0.2, 0.2))
				_tile_root.add_child(fs_inst)
			else:
				# Light pillar
				var lp_m := CylinderMesh.new()
				lp_m.top_radius = 0.05; lp_m.bottom_radius = 0.05; lp_m.height = 1.2
				var lp_col: Color = Color(0.85, 0.90, 1.0, 0.5)
				var lp_mat := _make_mat(lp_col, 0.0, 0.3, Color(0.80, 0.85, 1.0), 1.5)
				lp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				lp_mat.albedo_color.a = 0.4
				_make_mesh_inst(lp_m, lp_mat, cx, 0.70, cz, _tile_root)
		"manor":
			# Furniture — chairs, tables, bookshelves
			if kind == 0:
				# Armchair
				var seat_m := BoxMesh.new(); seat_m.size = Vector3(0.40, 0.08, 0.38)
				var back_m := BoxMesh.new(); back_m.size = Vector3(0.40, 0.35, 0.08)
				var furn_col: Color = Color(0.35, 0.15, 0.08)
				_make_mesh_inst(seat_m, _make_mat(furn_col, 0.0, 0.82), cx, 0.34, cz, _tile_root)
				_make_mesh_inst(back_m, _make_mat(furn_col.darkened(0.15), 0.0, 0.85), cx, 0.52, cz - 0.15, _tile_root)
			elif kind == 1:
				# Small table
				var top_m := BoxMesh.new(); top_m.size = Vector3(0.50, 0.06, 0.40)
				var leg_m := BoxMesh.new(); leg_m.size = Vector3(0.06, 0.35, 0.06)
				var tbl_col: Color = Color(0.30, 0.18, 0.08)
				_make_mesh_inst(top_m, _make_mat(tbl_col, 0.0, 0.80), cx, 0.48, cz, _tile_root)
				for lx in [-0.18, 0.18]:
					for lz in [-0.14, 0.14]:
						_make_mesh_inst(leg_m, _make_mat(tbl_col.darkened(0.1), 0.0, 0.85),
							cx + lx, 0.28, cz + lz, _tile_root)
			else:
				# Bookshelf
				var shelf_m := BoxMesh.new(); shelf_m.size = Vector3(0.50, 0.75, 0.18)
				var shelf_col: Color = Color(0.28, 0.16, 0.06)
				_make_mesh_inst(shelf_m, _make_mat(shelf_col, 0.0, 0.82), cx, 0.48, cz, _tile_root)
				# Books (colored spines)
				for bk_i in range(drng.randi_range(3, 6)):
					var bk_m := BoxMesh.new(); bk_m.size = Vector3(0.06, drng.randf_range(0.12, 0.22), 0.14)
					var bk_col: Color = Color(drng.randf(), drng.randf() * 0.5, drng.randf() * 0.5)
					_make_mesh_inst(bk_m, _make_mat(bk_col, 0.0, 0.85),
						cx + drng.randf_range(-0.18, 0.18),
						0.30 + drng.randf() * 0.30,
						cz + 0.02, _tile_root)
		_:
			# Generic fallback — rock chunk
			var obs_col: Color = _c_obstacle.lerp(Color(0.18, 0.14, 0.10), drng.randf() * 0.3)
			var obs_m := BoxMesh.new()
			obs_m.size = Vector3(0.55, 0.50, 0.55)
			_make_mesh_inst(obs_m, _make_mat(obs_col, 0.0, 0.90), cx, 0.35, cz, _tile_root)

# ── Biome ceiling builder ────────────────────────────────────────────────────
func _build_biome_ceiling(drng: RandomNumberGenerator) -> void:
	match _biome_ceiling:
		"beams":
			# Wooden crossbeams every 6 tiles
			var beam_mesh := BoxMesh.new(); beam_mesh.size = Vector3(0.18, 0.22, 0.98)
			var beam_mat := _make_mat(Color(0.22, 0.14, 0.08), 0.0, 0.85)
			for cx_col in range(2, MAP_SIZE - 2, 6):
				for cz_row in range(0, MAP_SIZE):
					var idx_c: int = cz_row * MAP_SIZE + cx_col
					if idx_c < 0 or idx_c >= _map.size(): continue
					if _map[idx_c] == 0: continue
					_make_mesh_inst(beam_mesh, beam_mat,
						float(cx_col) + 0.5, 2.05, float(cz_row) + 0.5, _tile_root)
		"stalactites":
			# Hanging stalactites from ceiling above floor tiles
			drng.seed = 7777
			for cy in range(0, MAP_SIZE, 3):
				for ccx in range(0, MAP_SIZE, 3):
					var stal_idx: int = cy * MAP_SIZE + ccx
					if stal_idx >= _map.size(): continue
					if _map[stal_idx] == 0: continue
					if drng.randf() > 0.55: continue
					var stal_m := CylinderMesh.new()
					stal_m.top_radius = drng.randf_range(0.02, 0.06)
					stal_m.bottom_radius = drng.randf_range(0.08, 0.16)
					stal_m.height = drng.randf_range(0.25, 0.65)
					var stal_col: Color = _c_wall.lightened(drng.randf() * 0.15)
					var stal_inst := MeshInstance3D.new()
					stal_inst.mesh = stal_m
					stal_inst.set_surface_override_material(0, _make_mat(stal_col, 0.1, 0.80))
					stal_inst.position = Vector3(
						float(ccx) + 0.5 + drng.randf_range(-0.25, 0.25),
						2.10 - stal_m.height * 0.5,
						float(cy) + 0.5 + drng.randf_range(-0.25, 0.25))
					stal_inst.rotation = Vector3(PI, 0, 0)
					_tile_root.add_child(stal_inst)
		"canopy":
			# Leaf clusters overhead
			drng.seed = 5555
			for cy in range(0, MAP_SIZE, 2):
				for ccx in range(0, MAP_SIZE, 2):
					var canopy_idx: int = cy * MAP_SIZE + ccx
					if canopy_idx >= _map.size(): continue
					if _map[canopy_idx] == 0: continue
					if drng.randf() > 0.40: continue
					var leaf_m := SphereMesh.new()
					leaf_m.radius = drng.randf_range(0.30, 0.60)
					leaf_m.height = leaf_m.radius * 0.6
					var leaf_col: Color = Color(0.10, 0.32, 0.06).lerp(Color(0.15, 0.42, 0.10), drng.randf())
					var leaf_mat := _make_mat(leaf_col, 0.0, 0.85)
					leaf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					leaf_mat.albedo_color.a = 0.70
					_make_mesh_inst(leaf_m, leaf_mat,
						float(ccx) + 0.5 + drng.randf_range(-0.30, 0.30),
						2.00 + drng.randf() * 0.35,
						float(cy) + 0.5 + drng.randf_range(-0.30, 0.30), _tile_root)
		"vaulted":
			# Stone arches across ceiling every 8 tiles
			var arch_mesh := BoxMesh.new(); arch_mesh.size = Vector3(0.22, 0.14, 0.98)
			var arch_col: Color = _c_wall.lightened(0.15)
			var arch_mat := _make_mat(arch_col, 0.10, 0.70)
			for cx_col in range(4, MAP_SIZE - 4, 8):
				for cz_row in range(0, MAP_SIZE):
					var vault_idx: int = cz_row * MAP_SIZE + cx_col
					if vault_idx >= _map.size(): continue
					if _map[vault_idx] == 0: continue
					_make_mesh_inst(arch_mesh, arch_mat,
						float(cx_col) + 0.5, 2.00, float(cz_row) + 0.5, _tile_root)
			# Cross arches
			var cross_mesh := BoxMesh.new(); cross_mesh.size = Vector3(0.98, 0.14, 0.22)
			for cz_row2 in range(4, MAP_SIZE - 4, 8):
				for cx_col2 in range(0, MAP_SIZE):
					var idx_c2: int = cz_row2 * MAP_SIZE + cx_col2
					if idx_c2 >= _map.size(): continue
					if _map[idx_c2] == 0: continue
					_make_mesh_inst(cross_mesh, arch_mat,
						float(cx_col2) + 0.5, 2.00, float(cz_row2) + 0.5, _tile_root)
		"open":
			# Open sky — no ceiling geometry; maybe a subtle sky gradient box
			pass
		"none":
			# No ceiling
			pass

# ── Torch / atmospheric lights ────────────────────────────────────────────────
func _rebuild_3d_torches() -> void:
	for c in _torch_root.get_children():
		c.queue_free()
	if _map.is_empty(): return

	# Prebuilt meshes for torch bracket + flame
	var bracket_mesh := BoxMesh.new(); bracket_mesh.size = Vector3(0.12, 0.28, 0.12)
	var sconce_mesh := CylinderMesh.new()
	sconce_mesh.top_radius    = 0.14
	sconce_mesh.bottom_radius = 0.08
	sconce_mesh.height        = 0.22
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.18
	flame_mesh.height = 0.48
	flame_mesh.radial_segments = 12
	flame_mesh.rings = 8

	var bracket_mat := _make_mat(Color(0.20, 0.16, 0.12), 0.6, 0.45)
	var sconce_mat  := _make_mat(Color(0.28, 0.22, 0.18), 0.65, 0.40)

	# Scatter torches near walls — every ~4 tiles, check for wall adjacency
	var rng := RandomNumberGenerator.new()
	rng.seed = 42   # deterministic placement
	for ty in range(1, MAP_SIZE - 1, 4):
		for tx in range(1, MAP_SIZE - 1, 4):
			# Cull torches outside the live render chunk on big maps. Each
			# torch ships a flame mesh + OmniLight (with shadows!) +
			# GPUParticles3D — leaving these active across a 50×50 map is
			# the main reason distant areas were lit on Low quality.
			if not _tile_in_render_radius(tx, ty):
				continue
			var idx: int = ty * MAP_SIZE + tx
			if _map[idx] != 1: continue
			# Check if adjacent to a wall — remember direction for mounting
			var near_wall: bool = false
			var wall_dir: Vector2 = Vector2.ZERO
			for nb in [[1,0],[-1,0],[0,1],[0,-1]]:
				var ni: int = (ty + nb[1]) * MAP_SIZE + (tx + nb[0])
				if ni >= 0 and ni < _map.size() and _map[ni] == 2:
					near_wall = true
					wall_dir = Vector2(nb[0], nb[1])
					break
			if not near_wall and rng.randf() > 0.35: continue

			var base_x: float = float(tx) + 0.5
			var base_z: float = float(ty) + 0.5
			var mount_x: float = base_x + wall_dir.x * 0.35
			var mount_z: float = base_z + wall_dir.y * 0.35

			# Iron bracket peg
			_make_mesh_inst(bracket_mesh, bracket_mat,
				mount_x, 1.15, mount_z, _torch_root)
			# Sconce / cup holding the flame
			_make_mesh_inst(sconce_mesh, sconce_mat,
				mount_x, 1.32, mount_z, _torch_root)

			# Flame mesh — color derived from biome light palette
			var flame_col := _biome_light_color.lerp(
				Color(1.0, 0.55 + rng.randf() * 0.2, 0.1 + rng.randf() * 0.15), 0.35)
			var flame_mat := StandardMaterial3D.new()
			flame_mat.albedo_color    = flame_col
			flame_mat.emission_enabled = true
			flame_mat.emission         = flame_col.lerp(Color(1.0, 0.9, 0.5), 0.35)
			flame_mat.emission_energy_multiplier = 4.0
			flame_mat.transparency     = BaseMaterial3D.TRANSPARENCY_ALPHA
			flame_mat.albedo_color.a   = 0.85
			flame_mat.shading_mode     = BaseMaterial3D.SHADING_MODE_UNSHADED
			_make_mesh_inst(flame_mesh, flame_mat,
				mount_x, 1.54, mount_z, _torch_root)

			# Point light — energy from biome palette
			var light := OmniLight3D.new()
			light.light_color  = flame_col
			light.light_energy   = _biome_light_energy * (0.7 + rng.randf() * 0.6)
			light.omni_range     = 6.0 + rng.randf() * 2.0
			light.shadow_enabled = true
			light.position = Vector3(mount_x, 1.55, mount_z)
			_torch_root.add_child(light)

			# Fire spark particles (GPU if available, else no-op)
			var spark_part := GPUParticles3D.new()
			var spark_mat_pm := ParticleProcessMaterial.new()
			spark_mat_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			spark_mat_pm.emission_sphere_radius = 0.08
			spark_mat_pm.direction = Vector3(0, 1, 0)
			spark_mat_pm.initial_velocity_min = 0.4
			spark_mat_pm.initial_velocity_max = 0.9
			spark_mat_pm.gravity = Vector3(0, 0.25, 0)
			spark_mat_pm.scale_min = 0.04
			spark_mat_pm.scale_max = 0.10
			spark_mat_pm.color = flame_col
			spark_part.process_material = spark_mat_pm
			spark_part.amount = 14
			spark_part.lifetime = 1.4
			spark_part.preprocess = 0.5
			var spark_visual_mesh := SphereMesh.new()
			spark_visual_mesh.radius = 0.04
			spark_visual_mesh.height = 0.08
			spark_visual_mesh.radial_segments = 6
			spark_visual_mesh.rings = 3
			var spark_mat_vis := StandardMaterial3D.new()
			spark_mat_vis.albedo_color    = flame_col.lerp(Color.WHITE, 0.3)
			spark_mat_vis.emission_enabled = true
			spark_mat_vis.emission         = flame_col
			spark_mat_vis.emission_energy_multiplier = 3.5
			spark_mat_vis.shading_mode     = BaseMaterial3D.SHADING_MODE_UNSHADED
			spark_visual_mesh.material = spark_mat_vis
			spark_part.draw_pass_1 = spark_visual_mesh
			spark_part.position = Vector3(mount_x, 1.55, mount_z)
			_torch_root.add_child(spark_part)

# ── Atmospheric ambience (dust, haze, ceiling light bands) ────────────────────
func _rebuild_3d_ambience() -> void:
	# The ambience tree hosts global particles/lights independent of tile build.
	# Clear previous children first
	if not is_instance_valid(_world3d_root): return

	# We store ambience as children of _torch_root tail to avoid adding another
	# root; but cleaner: reuse _overlay_root? Let's use _torch_root tail — they
	# both get cleared together only when _map_dirty triggers rebuild.
	# Use a dedicated Node3D if missing
	var ambience_root: Node3D = null
	for c in _world3d_root.get_children():
		if c.name == "AmbienceRoot":
			ambience_root = c
			break
	if ambience_root == null:
		ambience_root = Node3D.new()
		ambience_root.name = "AmbienceRoot"
		_world3d_root.add_child(ambience_root)
	else:
		for c in ambience_root.get_children():
			c.queue_free()

	if _map.is_empty(): return

	# Compute the ambience anchor: when culling is active we center particle
	# emission boxes on the average player position (so dust + fog hug the
	# camera instead of fogging the whole 50×50 map). Also shrink the box
	# extents to the render radius so we're emitting only across the live
	# chunk — dramatic particle-count reduction.
	var amb_center: Vector3 = Vector3(float(MAP_SIZE) * 0.5, 0.0, float(MAP_SIZE) * 0.5)
	var amb_extent: float = float(MAP_SIZE) * 0.5
	var amb_amount_mul: float = 1.0
	if _render_radius > 0:
		var anchors: Array = _current_player_anchors()
		if anchors.size() > 0:
			var sum_x: float = 0.0
			var sum_z: float = 0.0
			for a in anchors:
				sum_x += float(a.x)
				sum_z += float(a.y)
			amb_center = Vector3(sum_x / float(anchors.size()) + 0.5, 0.0,
				sum_z / float(anchors.size()) + 0.5)
		amb_extent = float(_render_radius)
		# Particles emit into a smaller box; cut amount proportionally so
		# density stays consistent and the GPU does less work.
		var area_ratio: float = (amb_extent * amb_extent) / (float(MAP_SIZE) * 0.5 * float(MAP_SIZE) * 0.5)
		amb_amount_mul = clampf(area_ratio, 0.15, 1.0)

	# ── Biome-colored dust / particle motes ──────────────────────────────────
	var dust_col: Color = _biome_fog_color.lightened(0.55)
	dust_col.a = 0.45
	var dust := GPUParticles3D.new()
	var dust_pm := ParticleProcessMaterial.new()
	dust_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dust_pm.emission_box_extents = Vector3(amb_extent, 1.2, amb_extent)
	dust_pm.direction = Vector3(0.5, 0.15, 0.4)
	dust_pm.initial_velocity_min = 0.12
	dust_pm.initial_velocity_max = 0.28
	dust_pm.gravity = Vector3(0, 0.02, 0)
	dust_pm.scale_min = 0.015
	dust_pm.scale_max = 0.045
	dust_pm.color = dust_col
	dust.process_material = dust_pm
	dust.amount = maxi(8, int((80 + 120 * _biome_fog_density) * amb_amount_mul))
	dust.lifetime = 7.0
	dust.preprocess = 4.0
	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = 0.02
	dust_mesh.height = 0.04
	dust_mesh.radial_segments = 4
	dust_mesh.rings = 2
	var dust_vis := StandardMaterial3D.new()
	dust_vis.albedo_color    = dust_col.lerp(Color.WHITE, 0.1)
	dust_vis.albedo_color.a  = 0.55
	dust_vis.transparency    = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_vis.emission_enabled = true
	dust_vis.emission         = _biome_fog_color.lightened(0.4)
	dust_vis.emission_energy_multiplier = 0.6
	dust_vis.shading_mode     = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mesh.material = dust_vis
	dust.draw_pass_1 = dust_mesh
	dust.position = Vector3(amb_center.x, 1.2, amb_center.z)
	ambience_root.add_child(dust)

	# ── Fog layer (ground-hugging haze using biome fog_color and density) ────
	if _biome_fog_density > 0.1:
		var fog_part := GPUParticles3D.new()
		var fog_pm := ParticleProcessMaterial.new()
		fog_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		fog_pm.emission_box_extents = Vector3(amb_extent, 0.3, amb_extent)
		fog_pm.direction = Vector3(0.3, 0.0, 0.2)
		fog_pm.initial_velocity_min = 0.05
		fog_pm.initial_velocity_max = 0.15
		fog_pm.gravity = Vector3(0, 0, 0)
		fog_pm.scale_min = 0.15
		fog_pm.scale_max = 0.40
		var fog_vis_col: Color = _biome_fog_color.lightened(0.25)
		fog_vis_col.a = _biome_fog_density * 0.6
		fog_pm.color = fog_vis_col
		fog_part.process_material = fog_pm
		fog_part.amount = maxi(6, int((60 * _biome_fog_density + 20) * amb_amount_mul))
		fog_part.lifetime = 12.0
		fog_part.preprocess = 8.0
		var fog_mesh := SphereMesh.new()
		fog_mesh.radius = 0.35; fog_mesh.height = 0.20
		fog_mesh.radial_segments = 6; fog_mesh.rings = 3
		var fog_mat := StandardMaterial3D.new()
		fog_mat.albedo_color = fog_vis_col
		fog_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fog_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fog_mesh.material = fog_mat
		fog_part.draw_pass_1 = fog_mesh
		fog_part.position = Vector3(amb_center.x, 0.35, amb_center.z)
		ambience_root.add_child(fog_part)

	# ── Biome-tinted fill light ──────────────────────────────────────────────
	var ambient := DirectionalLight3D.new()
	ambient.light_color  = _biome_light_color.lerp(Color(0.55, 0.45, 0.40), 0.4)
	ambient.light_energy = 0.25 + _biome_light_energy * 0.05
	ambient.rotation_degrees = Vector3(-60.0, 35.0, 0.0)
	ambient.shadow_enabled = false
	ambience_root.add_child(ambient)

	# ── Secondary rim light (biome-tinted instead of always blue) ────────────
	var rim := DirectionalLight3D.new()
	var rim_col: Color = _biome_light_color.lerp(Color(0.30, 0.45, 0.70), 0.6)
	rim.light_color  = rim_col
	rim.light_energy = 0.12 + _biome_light_energy * 0.02
	rim.rotation_degrees = Vector3(-80.0, 0.0, 0.0)
	rim.shadow_enabled = false
	ambience_root.add_child(rim)

# ── Entity tokens ─────────────────────────────────────────────────────────────
func _update_3d_entities() -> void:
	for c in _entity_root.get_children():
		c.free()
	if _entities.is_empty(): return

	# Region Map Style scales tokens up so they fill their tiles like
	# region-map NPCs do. Camera also pulled in (~2.4× closer), so this
	# keeps units' on-screen size proportional rather than shrinking.
	var unit_scale: float = 1.55 if _render_style == "region" else 1.0

	var cyl_mesh  := CylinderMesh.new()
	cyl_mesh.top_radius    = 0.30 * unit_scale
	cyl_mesh.bottom_radius = 0.32 * unit_scale
	cyl_mesh.height        = 0.85 * unit_scale

	var cyl_dead  := CylinderMesh.new()
	cyl_dead.top_radius    = 0.28 * unit_scale
	cyl_dead.bottom_radius = 0.28 * unit_scale
	cyl_dead.height        = 0.22 * unit_scale

	var hp_bar_mesh := BoxMesh.new()
	hp_bar_mesh.size = Vector3(0.72 * unit_scale, 0.06, 0.08)

	for ent in _entities:
		var is_player: bool = bool(ent["is_player"])
		var is_dead:   bool = bool(ent["is_dead"])
		var ex: int         = int(ent["x"])
		var ey: int         = int(ent["y"])

		# Fog visibility check for enemies
		if not is_player and not is_dead:
			if not bool(ent.get("fog_visible", true)): continue

		# Render-distance culling — drop entities outside the live chunk on
		# big crawl maps. Players themselves are always rendered (they ARE
		# the anchor). Inside _render_radius == 0 path, this is a no-op.
		if not is_player and not _tile_in_render_radius(ex, ey):
			continue

		# Chests render as a small gold box. Looted chests render dimmer
		# and lower (lid open). They short-circuit the normal entity path.
		if bool(ent.get("is_chest", false)):
			var chest_cx: float = float(ex) + 0.5
			var chest_cz: float = float(ey) + 0.5
			var looted: bool = bool(ent.get("looted", false))
			var chest_mesh := BoxMesh.new()
			chest_mesh.size = Vector3(0.55, 0.36 if not looted else 0.16, 0.42)
			var chest_col: Color = Color(0.78, 0.55, 0.18) if not looted else Color(0.45, 0.36, 0.18)
			var chest_emit: Color = Color(1.0, 0.78, 0.30) if not looted else Color(0.0, 0.0, 0.0)
			var chest_emit_str: float = 0.6 if not looted else 0.0
			var chest_mat := _make_mat(chest_col, 0.25, 0.50, chest_emit, chest_emit_str)
			_make_mesh_inst(chest_mesh, chest_mat,
				chest_cx, 0.18 if not looted else 0.08, chest_cz, _entity_root)
			# Chest lid: a thinner box on top so the silhouette reads as a chest.
			if not looted:
				var lid_mesh := BoxMesh.new()
				lid_mesh.size = Vector3(0.55, 0.10, 0.42)
				_make_mesh_inst(lid_mesh, _make_mat(Color(0.65, 0.42, 0.14), 0.30, 0.55),
					chest_cx, 0.41, chest_cz, _entity_root)
				# Glint light — only on Medium/High quality. Crawl maps can
				# have 5–8 chests; that's a lot of dynamic lights for Low.
				if _quality != "low":
					var glint := OmniLight3D.new()
					glint.light_color = Color(1.0, 0.85, 0.40)
					glint.light_energy = 0.6
					glint.omni_range = 2.5
					glint.position = Vector3(chest_cx, 0.6, chest_cz)
					_entity_root.add_child(glint)
			continue   # skip the rest of entity rendering for chests

		var cx: float = float(ex) + 0.5
		var cz: float = float(ey) + 0.5

		# Elevation Y offset
		var ez: int = int(ent.get("z", 1))
		var base_y: float = 0.0
		if ez == 0: base_y = -0.28
		elif ez == 2: base_y = 0.38

		# ── Token body ────────────────────────────────────────────────────────
		var body_col: Color
		var emit_col: Color = Color.BLACK
		var emit_str: float = 0.0
		var is_ally: bool = (not is_player) and bool(ent.get("is_friendly", false))
		if is_dead:
			var inv: Array = ent.get("inventory", []) as Array
			var is_lootable: bool = (not bool(ent.get("looted", true))) and inv.size() > 0
			body_col = Color(0.72, 0.52, 0.10) if is_lootable else Color(0.38, 0.38, 0.38)
		elif is_player:
			body_col = Color(0.20, 0.55, 0.92)
			emit_col = Color(0.30, 0.65, 1.00)
			emit_str = 0.4
		elif is_ally:
			body_col = Color(0.20, 0.78, 0.40)
			emit_col = Color(0.25, 0.90, 0.45)
			emit_str = 0.35
		else:
			body_col = Color(0.88, 0.22, 0.22)
			emit_col = Color(1.0, 0.30, 0.20)
			emit_str = 0.3

		# Region Map Style: soften the harsh primary tints so tokens blend
		# with the bright daylight palette instead of clashing with grass +
		# stone. Keeps the team-color contrast (player blue / ally green /
		# enemy red) but lower saturation + warmer mids.
		if _render_style == "region" and not is_dead:
			if is_player:
				body_col = Color(0.34, 0.58, 0.86)
				emit_col = Color(0.50, 0.74, 0.98)
				emit_str = 0.30
			elif is_ally:
				body_col = Color(0.40, 0.72, 0.46)
				emit_col = Color(0.50, 0.85, 0.55)
				emit_str = 0.28
			else:
				body_col = Color(0.78, 0.32, 0.30)
				emit_col = Color(0.95, 0.45, 0.35)
				emit_str = 0.22

		# ── 3D procedural character model ──────────────────────────────────
		# Team-coloured disc base sits under every entity. Scales up in
		# region mode to match the closer camera + bigger-feeling tiles.
		var disc := CylinderMesh.new()
		disc.top_radius    = 0.34 * unit_scale
		disc.bottom_radius = 0.36 * unit_scale
		disc.height        = 0.12
		_make_mesh_inst(disc, _make_mat(body_col, 0.4, 0.5, emit_col, emit_str * 0.6),
				cx, base_y + 0.06, cz, _entity_root)

		# ── Kaiju trunk footprint (Colossal 4×4 dome) ──────────────────────
		# Entities tagged `is_kaiju_trunk` with footprint_w/h carry the anchor
		# of a multi-tile footprint. Draw a big translucent dome centered on
		# the footprint so the Kaiju visibly occupies the full area (4×4 for
		# Colossal, 3×3 for Gargantuan, etc).
		if bool(ent.get("is_kaiju_trunk", false)):
			var fw: int = int(ent.get("footprint_w", 4))
			var fh: int = int(ent.get("footprint_h", 4))
			var ox: int = int(ent.get("footprint_origin_x", ex))
			var oy: int = int(ent.get("footprint_origin_y", ey))
			# Footprint center in tile-space (inclusive of edges).
			var fcx: float = float(ox) + float(fw) * 0.5
			var fcz: float = float(oy) + float(fh) * 0.5
			# Dome diameter = larger footprint edge (in tiles); height scales with it.
			var edge_tiles: float = float(maxi(fw, fh))
			var trunk_radius: float = edge_tiles * 0.42
			var trunk_mesh := CylinderMesh.new()
			trunk_mesh.top_radius    = trunk_radius * 0.8
			trunk_mesh.bottom_radius = trunk_radius
			trunk_mesh.height        = edge_tiles * 0.55
			var trunk_mat := _make_mat(body_col, 0.55, 0.35, emit_col, emit_str * 0.6)
			_make_mesh_inst(trunk_mesh, trunk_mat,
				fcx, base_y + trunk_mesh.height * 0.5, fcz, _entity_root)
			# Low ground-ring highlighting the full footprint square.
			var ring := BoxMesh.new()
			ring.size = Vector3(edge_tiles, 0.04, edge_tiles)
			var ring_mat := _make_mat(body_col, 0.30, 0.60, emit_col, emit_str * 0.8)
			_make_mesh_inst(ring, ring_mat, fcx, base_y + 0.02, fcz, _entity_root)

		if is_dead:
			# Dead units: flat slab token (no model)
			_make_mesh_inst(cyl_dead, _make_mat(body_col, 0.35, 0.55, emit_col, emit_str),
					cx, base_y + 0.11, cz, _entity_root)
		else:
			# Build 3D model: prefer Sprite3D lineage portraits, fall back to procedural
			var lineage_name: String = str(ent.get("lineage_name", ""))
			var weapon_name:  String = str(ent.get("equipped_weapon", "Unarmed"))
			var armor_name:   String = str(ent.get("equipped_armor",  "None"))
			var shield_name:  String = str(ent.get("equipped_shield", "None"))
			# Sprite billboard scale. Originally 0.45 — too small relative to
			# the cylinder fallback (height 0.85), so lineage units rendered
			# noticeably smaller than procedural enemies that fell back to
			# the cylinder. Bump to 0.85 so a lineage sprite reads at the
			# same visual height as the fallback. unit_scale (1.0 classic /
			# 1.55 region) still applies on top.
			var sprite_scale: float = 0.85 * unit_scale
			# Try Sprite3D billboard model first (unique lineage art)
			var model: Node3D = CharacterModelBuilder.build_sprite_model(
					lineage_name, weapon_name, armor_name, shield_name, sprite_scale, body_col)
			if model != null:
				model.position = Vector3(cx, base_y + 0.12, cz)
				_entity_root.add_child(model)
			else:
				# Fallback cylinder if both sprite and procedural model fail
				var mat := _make_mat(body_col, 0.35, 0.55, emit_col, emit_str)
				_make_mesh_inst(cyl_mesh, mat, cx, base_y + 0.425 * unit_scale, cz, _entity_root)

		# Selected glow ring
		if str(ent["id"]) == _selected_id:
			var ring_mesh := TorusMesh.new()
			ring_mesh.inner_radius = 0.33
			ring_mesh.outer_radius = 0.46
			ring_mesh.rings        = 16
			ring_mesh.ring_segments = 24
			var ring_mat := _make_mat(
				Color(1.0, 0.90, 0.10, 0.9), 0.8, 0.2,
				Color(1.0, 0.95, 0.20), 1.8
			)
			var ring := MeshInstance3D.new()
			ring.mesh = ring_mesh
			ring.set_surface_override_material(0, ring_mat)
			ring.position = Vector3(cx, base_y + 0.12, cz)
			_entity_root.add_child(ring)

		# Entity glow light (players glow blue, enemies red)
		if not is_dead:
			var glow := OmniLight3D.new()
			glow.light_color  = emit_col if emit_str > 0.0 else body_col
			glow.light_energy = 0.8 + (0.5 if str(ent["id"]) == _selected_id else 0.0)
			glow.omni_range   = 2.2
			glow.shadow_enabled = false
			glow.position = Vector3(cx, base_y + 0.9, cz)
			_entity_root.add_child(glow)

		# HP bar (floating slab above token)
		if not is_dead:
			var hp: int     = int(ent["hp"])
			var max_hp: int = maxi(1, int(ent["max_hp"]))
			var ratio: float = clamp(float(hp) / float(max_hp), 0.0, 1.0)
			# Background bar
			var bar_bg_m := BoxMesh.new(); bar_bg_m.size = Vector3(0.72, 0.06, 0.08)
			var bar_bg_mat := _make_mat(Color(0.55, 0.12, 0.12))
			_make_mesh_inst(bar_bg_m, bar_bg_mat, cx, base_y + 1.05, cz, _entity_root)
			# Fill bar (offset so it starts at left edge)
			if ratio > 0.01:
				var fill_w: float = 0.72 * ratio
				var bar_fill_m := BoxMesh.new(); bar_fill_m.size = Vector3(fill_w, 0.06, 0.09)
				var hp_col: Color
				if ratio > 0.6:   hp_col = Color(0.22, 0.72, 0.22)
				elif ratio > 0.3: hp_col = Color(0.80, 0.65, 0.10)
				else:             hp_col = Color(0.88, 0.18, 0.18)
				var bar_fill_mat := _make_mat(hp_col, 0.0, 0.6, hp_col, 0.25)
				var bar_x: float = cx - 0.36 + fill_w * 0.5
				_make_mesh_inst(bar_fill_m, bar_fill_mat, bar_x, base_y + 1.05, cz, _entity_root)

# ── Highlight overlays (move tiles, selection, target, area spell) ─────────
func _update_3d_overlays() -> void:
	for c in _overlay_root.get_children():
		c.free()

	var slab_h: float = 0.04
	var slab_y: float = 0.12   # float just above floor

	var hl_mesh := BoxMesh.new(); hl_mesh.size = Vector3(0.92, slab_h, 0.92)

	# Move highlights
	var move_mat := _make_mat(Color(0.15, 0.85, 0.20, 0.55), 0.0, 0.5,
		Color(0.20, 1.0, 0.30), 0.3)
	move_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for mv in _valid_moves:
		var mx: float = float(int(mv["x"])) + 0.5
		var mz: float = float(int(mv["y"])) + 0.5
		_make_mesh_inst(hl_mesh, move_mat, mx, slab_y, mz, _overlay_root)

	# Pending move highlight
	if not _pending_move.is_empty():
		var pmx: float = float(int(_pending_move["x"])) + 0.5
		var pmz: float = float(int(_pending_move["y"])) + 0.5
		var pend_mat := _make_mat(Color(0.15, 0.95, 0.95, 0.65), 0.0, 0.4,
			Color(0.30, 1.0, 1.0), 0.5)
		pend_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_make_mesh_inst(hl_mesh, pend_mat, pmx, slab_y, pmz, _overlay_root)

	# Target highlights for pending action
	if not _pending_action.is_empty():
		var tgt_mat := _make_mat(Color(0.92, 0.22, 0.10, 0.55), 0.0, 0.4,
			Color(1.0, 0.30, 0.10), 0.4)
		tgt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		for ent in _entities:
			if bool(ent["is_dead"]) or bool(ent["is_player"]): continue
			if not bool(ent.get("fog_visible", true)): continue
			var tx: float = float(int(ent["x"])) + 0.5
			var tz: float = float(int(ent["y"])) + 0.5
			_make_mesh_inst(hl_mesh, tgt_mat, tx, slab_y, tz, _overlay_root)

	# Area spell radius preview
	if _area_mode and _area_preview.x >= 0 and _area_preview.y >= 0:
		var area_mat := _make_mat(Color(0.70, 0.22, 0.95, 0.45), 0.0, 0.4,
			Color(0.85, 0.40, 1.0), 0.4)
		area_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var ax: int = _area_preview.x
		var ay: int = _area_preview.y
		var r: int  = _area_radius
		if _area_tp_origin.x >= 0 and r > 0:
			# Teleport range: show range circle around caster/subject origin
			var ox: int = _area_tp_origin.x
			var oy: int = _area_tp_origin.y
			var range_mat := _make_mat(Color(0.20, 0.55, 0.85, 0.25), 0.0, 0.2,
				Color(0.30, 0.65, 1.0), 0.2)
			range_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			for ary in range(oy - r, oy + r + 1):
				for arx in range(ox - r, ox + r + 1):
					if arx < 0 or arx >= MAP_SIZE or ary < 0 or ary >= MAP_SIZE: continue
					if maxi(abs(arx - ox), abs(ary - oy)) <= r:
						_make_mesh_inst(hl_mesh, range_mat,
							float(arx) + 0.5, slab_y, float(ary) + 0.5, _overlay_root)
			# Highlight the hovered destination tile brighter
			_make_mesh_inst(hl_mesh, area_mat,
				float(ax) + 0.5, slab_y, float(ay) + 0.5, _overlay_root)
		elif r == 0:
			_make_mesh_inst(hl_mesh, area_mat,
				float(ax) + 0.5, slab_y, float(ay) + 0.5, _overlay_root)
		else:
			for ary in range(ay - r, ay + r + 1):
				for arx in range(ax - r, ax + r + 1):
					if arx < 0 or arx >= MAP_SIZE or ary < 0 or ary >= MAP_SIZE: continue
					if maxi(abs(arx - ax), abs(ary - ay)) <= r:
						_make_mesh_inst(hl_mesh, area_mat,
							float(arx) + 0.5, slab_y, float(ary) + 0.5, _overlay_root)

# ── Fog of war overlay ────────────────────────────────────────────────────────
func _update_3d_fog() -> void:
	for c in _fog_root.get_children():
		c.free()
	if _fog.size() != MAP_SIZE * MAP_SIZE: return

	# Fog is rendered as flat horizontal planes sitting just above the floor tiles.
	# Using flat planes (not tall pillars) so the camera looking from an angle is
	# never blocked by fog geometry on adjacent tiles.
	var unseen_mesh    := BoxMesh.new(); unseen_mesh.size    = Vector3(1.0, 0.12, 1.0)
	var remembered_mesh := BoxMesh.new(); remembered_mesh.size = Vector3(1.0, 0.08, 1.0)

	# Nearly-opaque dark purple mat for unseen tiles
	var unseen_mat := StandardMaterial3D.new()
	unseen_mat.albedo_color  = Color(0.03, 0.01, 0.06, 0.96)
	unseen_mat.roughness     = 1.0
	unseen_mat.metallic      = 0.0
	unseen_mat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	unseen_mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED  # ignore lighting

	# Semi-transparent dark mat for remembered (seen before) tiles
	var rem_mat := StandardMaterial3D.new()
	rem_mat.albedo_color  = Color(0.0, 0.0, 0.02, 0.60)
	rem_mat.roughness     = 1.0
	rem_mat.metallic      = 0.0
	rem_mat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	rem_mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Y positions: sit atop the floor slab (floor is at Y=0, height 0.18, top edge = 0.09)
	var unseen_y: float    = 0.15   # just above floor surface
	var remembered_y: float = 0.14

	for ty in range(MAP_SIZE):
		for tx in range(MAP_SIZE):
			var idx: int = ty * MAP_SIZE + tx
			var fog: int = int(_fog[idx])
			if fog == 2: continue  # fully visible — no overlay
			var cx: float = float(tx) + 0.5
			var cz: float = float(ty) + 0.5

			var mi := MeshInstance3D.new()
			if fog == 0:
				mi.mesh = unseen_mesh
				mi.set_surface_override_material(0, unseen_mat)
				mi.position = Vector3(cx, unseen_y, cz)
			else:  # fog == 1  remembered
				mi.mesh = remembered_mesh
				mi.set_surface_override_material(0, rem_mat)
				mi.position = Vector3(cx, remembered_y, cz)
			_fog_root.add_child(mi)

# ── Inner class: GridView (stub — kept for compatibility, no 2D drawing) ─────
class _GridView extends Control:
	var dungeon_scene: Control
	func _draw() -> void:
		pass  # 3D rendering is handled via SubViewport, not 2D canvas

# ── _draw_grid: replaced by 3D renderer — kept as no-op for safety ────────────
func _draw_grid(_canvas: Control) -> void:
	pass   # 3D rendering now handled by _update_3d_view()

# ── 3D tile picker — converts screen pos to (tx, ty) via camera ray ──────────
## Returns tile coords as Vector2i(-1, -1) if the ray misses the floor plane.
func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	if _cam3d == null or _viewport_3d == null:
		return Vector2i(-1, -1)
	# Scale from SubViewportContainer space → SubViewport pixel space
	var container_size: Vector2 = _grid_view.size
	var vp_size: Vector2 = Vector2(_viewport_3d.size)
	var vp_pos: Vector2 = screen_pos
	if container_size.x > 0.0 and container_size.y > 0.0:
		vp_pos = screen_pos * (vp_size / container_size)
	# Project ray from camera through viewport pixel
	var ray_origin: Vector3 = _cam3d.project_ray_origin(vp_pos)
	var ray_dir:    Vector3 = _cam3d.project_ray_normal(vp_pos)
	# Intersect with the Y=0 floor plane: t = -origin.y / dir.y
	if abs(ray_dir.y) < 0.0001:
		return Vector2i(-1, -1)
	var t: float = -ray_origin.y / ray_dir.y
	if t < 0.0:
		return Vector2i(-1, -1)
	var hit: Vector3 = ray_origin + ray_dir * t
	var tile_x: int = int(hit.x)
	var tile_z: int = int(hit.z)
	if tile_x < 0 or tile_x >= MAP_SIZE or tile_z < 0 or tile_z >= MAP_SIZE:
		return Vector2i(-1, -1)
	return Vector2i(tile_x, tile_z)

# ── Input handling ────────────────────────────────────────────────────────────
func _on_grid_input(event: InputEvent) -> void:
	# ── Camera controls (scroll = zoom, right-drag = rotate) ──────────────────
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				# Region mode lets you zoom in much closer (matches explore's
				# 2.0 floor); classic mode keeps the original 6.0 floor.
				var min_dist: float = 2.0 if _render_style == "region" else 6.0
				_cam_dist = maxf(min_dist, _cam_dist - 2.0)
				_update_camera_pos()
				return
			MOUSE_BUTTON_WHEEL_DOWN:
				_cam_dist = minf(55.0, _cam_dist + 2.0)
				_update_camera_pos()
				return
			MOUSE_BUTTON_RIGHT:
				_cam_dragging  = event.pressed
				_cam_drag_last = event.position
				return

	if event is InputEventMouseMotion:
		# Right-drag: rotate camera orbit
		if _cam_dragging:
			var delta: Vector2 = event.position - _cam_drag_last
			_cam_yaw   -= delta.x * 0.45
			_cam_pitch  = clampf(_cam_pitch - delta.y * 0.35, 12.0, 88.0)
			_cam_drag_last = event.position
			_update_camera_pos()
			return
		# Area-mode hover preview
		var tile_coord2: Vector2i = _screen_to_tile(event.position)
		if _area_mode and tile_coord2.x >= 0:
			var new_preview := tile_coord2
			if new_preview != _area_preview:
				_area_preview = new_preview
				_update_3d_view()
		return
	# ── End camera controls ────────────────────────────────────────────────────

	if not (event is InputEventMouseButton): return
	var tile_coord: Vector2i = _screen_to_tile(event.position)
	var tx: int = tile_coord.x
	var ty: int = tile_coord.y

	if not event.pressed: return
	if event.button_index != MOUSE_BUTTON_LEFT: return
	if tile_coord.x < 0: return   # ray missed the floor plane

	# Area targeting mode: click to cast
	if _area_mode:
		var action: Dictionary = _area_action.duplicate()
		_cancel_pending_action()
		var result: Dictionary = _e.dungeon_perform_action(
			_selected_id, action, "", tx, ty)
		_handle_action_result(result)
		return

	# Resolve the entity under the click once, shared by both branches below.
	var clicked_ent: Dictionary = _entity_at(tx, ty)

	# Multi-target mode: collect targets, confirm when done
	if _multi_target_mode:
		if not clicked_ent.is_empty() and not bool(clicked_ent["is_dead"]):
			var is_friendly: bool = bool(clicked_ent.get("is_player", false)) or bool(clicked_ent.get("is_friendly", false))
			if _multi_target_friendly == is_friendly:
				var eid: String = str(clicked_ent["id"])
				if eid in _multi_target_list:
					# Already selected — remove it
					_multi_target_list.erase(eid)
					_add_log("[color=yellow]Removed %s from targets.[/color]" % str(clicked_ent.get("name", eid)))
				elif _multi_target_list.size() < _multi_target_max:
					_multi_target_list.append(eid)
					_add_log("[color=cyan]Added %s (%d/%d).[/color]" % [
						str(clicked_ent.get("name", eid)), _multi_target_list.size(), _multi_target_max])
				else:
					_add_log("[color=yellow]Max targets reached (%d). Click empty space or press Enter to confirm.[/color]" % _multi_target_max)
				var who: String = "allies" if _multi_target_friendly else "enemies"
				_action_mode_lbl.text = "Select up to %d %s (%d/%d). Click empty to confirm.  [ESC to cancel]" % [
					_multi_target_max, who, _multi_target_list.size(), _multi_target_max]
				_update_3d_view()
			else:
				_add_log("[color=yellow]Invalid target — click %s.[/color]" % ("an ally" if _multi_target_friendly else "an enemy"))
		else:
			# Clicked empty space or dead entity — confirm if we have targets
			if not _multi_target_list.is_empty():
				_confirm_multi_target()
			else:
				_cancel_pending_action()
		return

	# Single-target mode: click a valid target (enemy or ally depending on action)
	if not _pending_action.is_empty():
		if not clicked_ent.is_empty() and not bool(clicked_ent["is_dead"]):
			var want_friendly: bool = bool(_pending_action.get("_target_friendly", false))
			var is_friendly: bool = bool(clicked_ent.get("is_player", false)) or bool(clicked_ent.get("is_friendly", false))
			if want_friendly == is_friendly:
				_execute_action_on_target(str(clicked_ent["id"]))
			else:
				_add_log("[color=yellow]Invalid target — click %s.[/color]" % ("an ally" if want_friendly else "an enemy"))
		else:
			_cancel_pending_action()
		return

	# Normal click: select entity or move
	if not clicked_ent.is_empty() and bool(clicked_ent["is_dead"]) \
			and not bool(clicked_ent.get("is_player", false)):
		# Click dead enemy → show loot popup
		_open_loot_popup(str(clicked_ent.get("id", "")), str(clicked_ent.get("name", "Enemy")))
		return
	if not clicked_ent.is_empty() and not bool(clicked_ent["is_dead"]):
		_select_entity(str(clicked_ent["id"]))
		return

	for m in _valid_moves:
		if int(m["x"]) == tx and int(m["y"]) == ty:
			_pending_move = {"x": tx, "y": ty}
			_move_popup_lbl.text = "Move to (%d, %d)?\n[%d tile%s]" % [tx, ty, int(m.get("tile_cost", 1)), "s" if int(m.get("tile_cost", 1)) != 1 else ""]
			_move_popup.visible = true
			if _move_confirm_btn != null:
				_move_confirm_btn.grab_focus()
			_update_3d_view()
			return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Enter / Space confirms the move popup when it's visible
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			if _loot_popup != null and _loot_popup.visible:
				_loot_popup.visible = false
				get_viewport().set_input_as_handled()
				return
			if _move_popup != null and _move_popup.visible and not _pending_move.is_empty():
				_on_move_confirm()
				get_viewport().set_input_as_handled()
				return

		if event.keycode == KEY_ESCAPE:
			if not _pending_action.is_empty():
				_cancel_pending_action()
			elif not _pending_move.is_empty():
				_on_move_cancel()
			return

		# Don't pan camera while move popup is showing
		if _move_popup != null and _move_popup.visible:
			return

		# ── Camera pan with WASD / Arrow keys ────────────────────────────────
		var pan_speed: float = 1.5
		var yaw_r: float = deg_to_rad(_cam_yaw)
		# Forward/back are relative to camera yaw so W always moves "into" the screen
		var forward := Vector3(sin(yaw_r), 0.0, cos(yaw_r))
		var right_dir := Vector3(cos(yaw_r), 0.0, -sin(yaw_r))
		var panned: bool = false
		match event.keycode:
			KEY_W, KEY_UP:
				_cam_target_offset -= forward * pan_speed
				panned = true
			KEY_S, KEY_DOWN:
				_cam_target_offset += forward * pan_speed
				panned = true
			KEY_A, KEY_LEFT:
				_cam_target_offset -= right_dir * pan_speed
				panned = true
			KEY_D, KEY_RIGHT:
				_cam_target_offset += right_dir * pan_speed
				panned = true
			KEY_HOME:
				# Reset camera to map centre
				_cam_target_offset = Vector3.ZERO
				panned = true
		if panned:
			# Clamp pan so it stays roughly within the map bounds
			_cam_target_offset.x = clampf(_cam_target_offset.x, -MAP_SIZE * 0.5, MAP_SIZE * 0.5)
			_cam_target_offset.z = clampf(_cam_target_offset.z, -MAP_SIZE * 0.5, MAP_SIZE * 0.5)
			_update_camera_pos()
			get_viewport().set_input_as_handled()

# ── Move confirm/cancel ───────────────────────────────────────────────────────
func _on_move_confirm() -> void:
	_move_popup.visible = false
	if _pending_move.is_empty() or _selected_id == "": return
	var tx: int = int(_pending_move["x"])
	var ty: int = int(_pending_move["y"])
	var ent: Dictionary = _get_entity(_selected_id)
	var old_x: int = int(ent.get("x", -1))
	var old_y: int = int(ent.get("y", -1))
	_pending_move = {}
	var ok: bool = _e.move_dungeon_player(_selected_id, tx, ty)
	if ok:
		_add_log("→ Moved to (%d, %d)" % [tx, ty])
		# Handle grapple movement: move the grappler to our old position
		var has_grapple_half_speed: bool = bool(ent.get("grapple_half_speed", false))
		if has_grapple_half_speed and old_x >= 0 and old_y >= 0:
			# Find the entity grappling this unit and move them
			for other_ent in _entities:
				if str(other_ent.get("grappled_by", "")) == _selected_id:
					var other_id: String = str(other_ent.get("id", ""))
					_e.move_dungeon_player(other_id, old_x, old_y)
					_add_log("   [Grapple] Moved with %s" % str(other_ent.get("name", "Unknown")))
					break
		# Handle prone: deduct movement cost if first move while prone
		var has_prone: bool = "prone" in ent.get("conditions", [])
		if has_prone and old_x >= 0 and old_y >= 0:
			_add_log("   [Prone] Standing up costs half movement")
		_refresh()
		_select_entity(_selected_id)
		_check_victory_defeat()

func _on_move_cancel() -> void:
	_pending_move = {}
	_move_popup.visible = false
	_update_3d_view()

# ── Action column population ──────────────────────────────────────────────────
func _populate_action_columns() -> void:
	# Clear all three columns
	for child in _col_weapons_vbox.get_children():
		child.queue_free()
	for child in _col_magic_vbox.get_children():
		child.queue_free()
	for child in _col_abil_vbox.get_children():
		child.queue_free()

	var is_phase: bool = _e.is_dungeon_player_phase()
	if _selected_id == "" or not is_phase:
		return

	var ent: Dictionary = _get_entity(_selected_id)
	if ent.is_empty() or bool(ent["is_dead"]) or not bool(ent["is_player"]):
		return

	# Weapon actions
	var weapon_actions: Array = _e.get_available_weapon_actions(_selected_id)
	for action in weapon_actions:
		var btn: Button = _action_btn(action)
		_col_weapons_vbox.add_child(btn)

	# Magic column: active matrices first, then castable spells
	var matrix_actions: Array = _e.get_available_matrix_actions(_selected_id)
	var spell_actions: Array  = _e.get_available_spell_actions(_selected_id)

	if not matrix_actions.is_empty():
		var mtx_hdr := Label.new()
		mtx_hdr.text = "— active —"
		mtx_hdr.add_theme_font_size_override("font_size", 9)
		mtx_hdr.add_theme_color_override("font_color", Color(0.65, 0.50, 0.90))
		mtx_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_col_magic_vbox.add_child(mtx_hdr)
		for action in matrix_actions:
			var btn: Button = _matrix_action_btn(action)
			_col_magic_vbox.add_child(btn)

	if not spell_actions.is_empty():
		if not matrix_actions.is_empty():
			var sep_lbl := Label.new()
			sep_lbl.text = "— spells —"
			sep_lbl.add_theme_font_size_override("font_size", 9)
			sep_lbl.add_theme_color_override("font_color", Color(0.50, 0.50, 0.48))
			sep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_col_magic_vbox.add_child(sep_lbl)
		for action in spell_actions:
			var btn: Button = _action_btn(action)
			_col_magic_vbox.add_child(btn)

	if matrix_actions.is_empty() and spell_actions.is_empty():
		var lbl := Label.new()
		lbl.text = "—"
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.42))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_col_magic_vbox.add_child(lbl)

	# Craft Spell button — always available (matches mobile parity)
	var craft_btn := Button.new()
	craft_btn.text = "✦ Craft Spell"
	craft_btn.flat = true
	craft_btn.add_theme_font_size_override("font_size", 11)
	craft_btn.add_theme_color_override("font_color", Color(0.74, 0.40, 1.0))
	craft_btn.add_theme_color_override("font_hover_color", Color(0.85, 0.55, 1.0))
	craft_btn.pressed.connect(_open_spell_crafter)
	_col_magic_vbox.add_child(craft_btn)

	# Ability column: lineage traits first, then standard abilities
	var trait_actions: Array = _e.get_available_lineage_trait_actions(_selected_id)
	var abil_actions:  Array = _e.get_available_ability_actions(_selected_id)

	if not trait_actions.is_empty():
		var trait_hdr := Label.new()
		trait_hdr.text = "— traits —"
		trait_hdr.add_theme_font_size_override("font_size", 9)
		trait_hdr.add_theme_color_override("font_color", Color(0.70, 0.55, 0.25))
		trait_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_col_abil_vbox.add_child(trait_hdr)
		for action in trait_actions:
			_col_abil_vbox.add_child(_trait_action_btn(action))

	if not trait_actions.is_empty() and not abil_actions.is_empty():
		var sep := Label.new()
		sep.text = "— abilities —"
		sep.add_theme_font_size_override("font_size", 9)
		sep.add_theme_color_override("font_color", Color(0.50, 0.50, 0.48))
		sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_col_abil_vbox.add_child(sep)

	for action in abil_actions:
		_col_abil_vbox.add_child(_action_btn(action))

	# ── PHB Special Actions (Stabilize, Grapple, Shove, Break Free) ───────────
	var phb_sep := Label.new()
	phb_sep.text = "— combat —"
	phb_sep.add_theme_font_size_override("font_size", 9)
	phb_sep.add_theme_color_override("font_color", Color(0.50, 0.50, 0.48))
	phb_sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col_abil_vbox.add_child(phb_sep)

	# Stabilize button — visible if there's an adjacent dying ally
	var dying_ally_id: String = _find_adjacent_dying_ally(_selected_id)
	if dying_ally_id != "":
		var stab_btn := Button.new()
		stab_btn.text = "First Aid"
		stab_btn.custom_minimum_size = Vector2(0, 34)
		stab_btn.add_theme_font_size_override("font_size", 11)
		stab_btn.add_theme_color_override("font_color", Color(0.85, 0.70, 0.20))
		stab_btn.tooltip_text = "Stabilize an adjacent dying ally"
		var stab_style := StyleBoxFlat.new()
		stab_style.bg_color = Color(0.28, 0.24, 0.08)
		stab_style.border_width_left = 2
		stab_style.border_width_right = 2
		stab_style.border_width_top = 2
		stab_style.border_width_bottom = 2
		stab_style.border_color = Color(0.75, 0.58, 0.12)
		stab_style.set_corner_radius_all(3)
		stab_btn.add_theme_stylebox_override("normal", stab_style)
		var stab_hover: StyleBoxFlat = stab_style.duplicate()
		stab_hover.bg_color = stab_style.bg_color.lightened(0.18)
		stab_btn.add_theme_stylebox_override("hover", stab_hover)
		stab_btn.pressed.connect(func(): _e.dung_stabilize(_selected_id, dying_ally_id); _refresh(); _update_entity_card())
		_col_abil_vbox.add_child(stab_btn)

	# Break Free button — visible if grappled
	var has_grapple: bool = "grappled" in ent.get("conditions", [])
	if has_grapple:
		var break_btn := Button.new()
		break_btn.text = "Break Free"
		break_btn.custom_minimum_size = Vector2(0, 34)
		break_btn.add_theme_font_size_override("font_size", 11)
		break_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
		break_btn.tooltip_text = "Attempt to break free from grapple (Athletics check)"
		var break_style := StyleBoxFlat.new()
		break_style.bg_color = Color(0.45, 0.10, 0.10)
		break_style.border_width_left = 2
		break_style.border_width_right = 2
		break_style.border_width_top = 2
		break_style.border_width_bottom = 2
		break_style.border_color = Color(0.75, 0.20, 0.20)
		break_style.set_corner_radius_all(3)
		break_btn.add_theme_stylebox_override("normal", break_style)
		var break_hover: StyleBoxFlat = break_style.duplicate()
		break_hover.bg_color = break_style.bg_color.lightened(0.18)
		break_btn.add_theme_stylebox_override("hover", break_hover)
		break_btn.pressed.connect(func(): _e.break_grapple(_selected_id); _refresh(); _update_entity_card())
		_col_abil_vbox.add_child(break_btn)

	# Mount/Dismount — visible when player has a mount or is mounted
	var handle: int = int(ent.get("handle", -1))
	var mount_data: Dictionary = {} if handle < 0 else _e.get_mount_data(handle)
	var is_mounted: bool = bool(ent.get("is_mounted", false))
	var has_mount: bool = not mount_data.is_empty()

	if has_mount and not is_mounted:
		# Mount button: costs 2 AP
		var mount_btn := Button.new()
		mount_btn.text = "Mount\n2AP"
		mount_btn.custom_minimum_size = Vector2(0, 34)
		mount_btn.add_theme_font_size_override("font_size", 11)
		mount_btn.add_theme_color_override("font_color", Color(0.85, 0.70, 0.20))
		var mount_name: String = str(mount_data.get("mount_name", "Mount"))
		mount_btn.tooltip_text = "Mount your %s (2 AP)" % mount_name

		# Check if player can afford 2 AP
		var ap_left: int = int(ent.get("max_ap", 10)) - int(ent.get("ap_spent", 0))
		mount_btn.disabled = ap_left < 2

		var mount_style := StyleBoxFlat.new()
		mount_style.bg_color = Color(0.18, 0.28, 0.18)
		mount_style.border_width_left = 2
		mount_style.border_width_right = 2
		mount_style.border_width_top = 2
		mount_style.border_width_bottom = 2
		mount_style.border_color = Color(0.45, 0.75, 0.45)
		mount_style.set_corner_radius_all(3)
		mount_btn.add_theme_stylebox_override("normal", mount_style)
		var mount_hover: StyleBoxFlat = mount_style.duplicate()
		mount_hover.bg_color = mount_style.bg_color.lightened(0.18)
		mount_btn.add_theme_stylebox_override("hover", mount_hover)
		mount_btn.pressed.connect(func():
			ent["is_mounted"] = true
			if "ap_spent" in ent:
				ent["ap_spent"] = int(ent["ap_spent"]) + 2
			_refresh()
			_update_entity_card()
		)
		_col_abil_vbox.add_child(mount_btn)
	elif is_mounted:
		# Dismount button: costs 1 AP
		var dismount_btn := Button.new()
		dismount_btn.text = "Dismount\n1AP"
		dismount_btn.custom_minimum_size = Vector2(0, 34)
		dismount_btn.add_theme_font_size_override("font_size", 11)
		dismount_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
		dismount_btn.tooltip_text = "Dismount from your mount (1 AP)"

		# Check if player can afford 1 AP
		var ap_left: int = int(ent.get("max_ap", 10)) - int(ent.get("ap_spent", 0))
		dismount_btn.disabled = ap_left < 1

		var dismount_style := StyleBoxFlat.new()
		dismount_style.bg_color = Color(0.28, 0.18, 0.10)
		dismount_style.border_width_left = 2
		dismount_style.border_width_right = 2
		dismount_style.border_width_top = 2
		dismount_style.border_width_bottom = 2
		dismount_style.border_color = Color(0.75, 0.58, 0.12)
		dismount_style.set_corner_radius_all(3)
		dismount_btn.add_theme_stylebox_override("normal", dismount_style)
		var dismount_hover: StyleBoxFlat = dismount_style.duplicate()
		dismount_hover.bg_color = dismount_style.bg_color.lightened(0.18)
		dismount_btn.add_theme_stylebox_override("hover", dismount_hover)
		dismount_btn.pressed.connect(func():
			ent["is_mounted"] = false
			if "ap_spent" in ent:
				ent["ap_spent"] = int(ent["ap_spent"]) + 1
			_refresh()
			_update_entity_card()
		)
		_col_abil_vbox.add_child(dismount_btn)

	# Grapple & Shove — visible when adjacent to enemy
	var can_grapple_shove: bool = _has_adjacent_enemy(_selected_id)
	if can_grapple_shove:
		var grapple_btn := Button.new()
		grapple_btn.text = "Grapple"
		grapple_btn.custom_minimum_size = Vector2(0, 34)
		grapple_btn.add_theme_font_size_override("font_size", 11)
		grapple_btn.add_theme_color_override("font_color", Color(0.85, 0.70, 0.20))
		grapple_btn.tooltip_text = "Attempt to grapple an adjacent enemy"
		var grapple_style := StyleBoxFlat.new()
		grapple_style.bg_color = Color(0.28, 0.20, 0.06)
		grapple_style.border_width_left = 2
		grapple_style.border_width_right = 2
		grapple_style.border_width_top = 2
		grapple_style.border_width_bottom = 2
		grapple_style.border_color = Color(0.75, 0.58, 0.12)
		grapple_style.set_corner_radius_all(3)
		grapple_btn.add_theme_stylebox_override("normal", grapple_style)
		var grapple_hover: StyleBoxFlat = grapple_style.duplicate()
		grapple_hover.bg_color = grapple_style.bg_color.lightened(0.18)
		grapple_btn.add_theme_stylebox_override("hover", grapple_hover)
		grapple_btn.pressed.connect(func(): _e.dung_grapple(_selected_id); _refresh(); _update_entity_card())
		_col_abil_vbox.add_child(grapple_btn)

		var shove_btn := Button.new()
		shove_btn.text = "Shove"
		shove_btn.custom_minimum_size = Vector2(0, 34)
		shove_btn.add_theme_font_size_override("font_size", 11)
		shove_btn.add_theme_color_override("font_color", Color(0.85, 0.70, 0.20))
		shove_btn.tooltip_text = "Shove an adjacent enemy (Push or Prone)"
		var shove_style := StyleBoxFlat.new()
		shove_style.bg_color = Color(0.28, 0.20, 0.06)
		shove_style.border_width_left = 2
		shove_style.border_width_right = 2
		shove_style.border_width_top = 2
		shove_style.border_width_bottom = 2
		shove_style.border_color = Color(0.75, 0.58, 0.12)
		shove_style.set_corner_radius_all(3)
		shove_btn.add_theme_stylebox_override("normal", shove_style)
		var shove_hover: StyleBoxFlat = shove_style.duplicate()
		shove_hover.bg_color = shove_style.bg_color.lightened(0.18)
		shove_btn.add_theme_stylebox_override("hover", shove_hover)
		shove_btn.pressed.connect(func(): _show_shove_options(_selected_id))
		_col_abil_vbox.add_child(shove_btn)

func _action_btn(action: Dictionary) -> Button:
	var ap_cost: int = int(action.get("ap_cost", 0))
	var sp_cost: int = int(action.get("sp_cost", 0))
	var act_name: String = str(action.get("name", "?"))
	var is_attack: bool = bool(action.get("is_attack", false))

	var cost_str: String = ""
	if ap_cost > 0:
		cost_str += "%dAP" % ap_cost
	if sp_cost > 0:
		if cost_str != "": cost_str += " "
		cost_str += "%dSP" % sp_cost

	var btn := Button.new()
	btn.text = act_name + ("\n" + cost_str if cost_str != "" else "")
	btn.custom_minimum_size = Vector2(0, 38)
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.tooltip_text = str(action.get("description", ""))

	# Colour based on type
	var bg_col: Color
	if is_attack:
		bg_col = Color(0.55, 0.12, 0.12)
	else:
		bg_col = Color(0.18, 0.28, 0.45)

	# Check if entity can afford it
	var ent: Dictionary = _get_entity(_selected_id)
	var ap_left: int = 0
	var sp_left: int = 0
	if not ent.is_empty():
		ap_left = int(ent.get("max_ap", 10)) - int(ent.get("ap_spent", 0))
		sp_left = int(ent.get("sp", 0))   # current SP (decremented by engine on cast)
	var can_afford: bool = (ap_left >= ap_cost) and (sp_left >= sp_cost)
	btn.disabled = not can_afford

	var style := StyleBoxFlat.new()
	style.bg_color = bg_col
	style.corner_radius_top_left    = 3
	style.corner_radius_top_right   = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	btn.add_theme_stylebox_override("normal", style)

	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = bg_col.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_style)

	var dis_style: StyleBoxFlat = style.duplicate()
	dis_style.bg_color = bg_col.darkened(0.50)
	btn.add_theme_stylebox_override("disabled", dis_style)

	# Capture action dict by value for the closure
	var captured_action: Dictionary = action.duplicate()
	btn.pressed.connect(func(): _on_action_pressed(captured_action))

	return btn

## Styled button for matrix actions (End = dark red border, Resume = gold border).
func _matrix_action_btn(action: Dictionary) -> Button:
	var action_id: int = int(action.get("action_id", -1))
	var is_end: bool   = (action_id == 17)   # ACT_END_MTX

	var btn := Button.new()
	btn.text = str(action.get("name", "?"))
	btn.custom_minimum_size = Vector2(0, 34)
	btn.add_theme_font_size_override("font_size", 11)
	btn.tooltip_text = str(action.get("description", ""))

	var bg_col: Color = Color(0.45, 0.10, 0.10) if is_end else Color(0.30, 0.22, 0.50)
	btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40) if not is_end else Color(1.0, 0.55, 0.55))

	var style := StyleBoxFlat.new()
	style.bg_color = bg_col
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.80, 0.65, 0.20) if not is_end else Color(0.75, 0.20, 0.20)
	style.corner_radius_top_left     = 3
	style.corner_radius_top_right    = 3
	style.corner_radius_bottom_left  = 3
	style.corner_radius_bottom_right = 3
	btn.add_theme_stylebox_override("normal", style)
	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = bg_col.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_style)

	var captured_action: Dictionary = action.duplicate()
	btn.pressed.connect(func(): _on_action_pressed(captured_action))
	return btn

## Trait buttons: amber/gold theme, different from matrix (purple) buttons.
func _trait_action_btn(action: Dictionary) -> Button:
	var btn := Button.new()
	btn.text = str(action.get("name", "?"))
	btn.custom_minimum_size = Vector2(0, 34)
	btn.add_theme_font_size_override("font_size", 11)
	btn.tooltip_text = str(action.get("description", ""))
	btn.add_theme_color_override("font_color", Color(1.0, 0.90, 0.55))

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.28, 0.20, 0.06)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.75, 0.58, 0.12)
	style.corner_radius_top_left     = 3
	style.corner_radius_top_right    = 3
	style.corner_radius_bottom_left  = 3
	style.corner_radius_bottom_right = 3
	btn.add_theme_stylebox_override("normal", style)
	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = style.bg_color.lightened(0.18)
	btn.add_theme_stylebox_override("hover", hover_style)

	var captured: Dictionary = action.duplicate()
	btn.pressed.connect(func(): _on_action_pressed(captured))
	return btn

# ── Action execution ──────────────────────────────────────────────────────────
func _on_action_pressed(action: Dictionary) -> void:
	if _selected_id == "": return
	var is_attack: bool = bool(action.get("is_attack", false))
	var action_id: int  = int(action.get("action_id", -1))
	var area_type: int  = int(action.get("area_type", 0))
	var is_tp: bool     = bool(action.get("is_teleport", false))
	var range_idx: int  = int(action.get("range_idx", 0))

	# Area spells: enter area-targeting mode
	if area_type > 0:
		const AREA_RADII: Array = [0, 1, 3, 10]
		_area_mode    = true
		_area_action  = action.duplicate()
		_area_radius  = AREA_RADII[clampi(area_type, 0, 3)]
		_area_preview = Vector2i(-1, -1)
		if is_tp:
			# Area teleport: all units within radius of caster will be teleported to destination
			_action_mode_lbl.text = "Click a destination tile — all units within %d tiles teleport there (enemies roll to resist).  [ESC to cancel]" % _area_radius
		else:
			_action_mode_lbl.text = "Click a tile to place area (%d-tile radius)…  [ESC to cancel]" % _area_radius
		_update_3d_view()
		return

	# Teleport: self-range → click destination tile; other range → pick target first
	if is_tp:
		var tp_max: int = int(action.get("tp_range", 0))
		var range_hint: String = " (range: %d tiles)" % tp_max if tp_max > 0 else " (SP scales with distance)"
		if range_idx == 0:
			# Self teleport: go straight to tile selection
			var sel_ent: Dictionary = _get_entity(_selected_id)
			_area_mode    = true
			_area_action  = action.duplicate()
			_area_radius  = tp_max   # show range circle if pre-paid
			_area_preview = Vector2i(-1, -1)
			_area_tp_origin = Vector2i(int(sel_ent.get("x", -1)), int(sel_ent.get("y", -1))) if tp_max > 0 else Vector2i(-1, -1)
			_action_mode_lbl.text = "Click a floor tile to teleport to…%s  [ESC to cancel]" % range_hint
			_update_3d_view()
		else:
			# Teleport another unit: first pick the target, then destination
			_pending_action = action.duplicate()
			_pending_action["_target_friendly"] = true
			_pending_action["_teleport_pick_target"] = true
			_action_mode_lbl.text = "Click a unit to teleport…%s  [ESC to cancel]" % range_hint
			_update_3d_view()
		return

	# Shapeshift: open form selection dialog
	if action_id == 70:  # ACT_SHAPESHIFT
		_open_shapeshift_dialog(action)
		return

	# Summon / Construct spells: open builder dialog
	# Must be checked BEFORE the generic target-selection intercepts below
	if action_id == 10:  # ACT_CAST_SPELL
		var spell_nm: String = str(action.get("matrix_id", ""))
		var spell_db_entry: Dictionary = _e._SPELL_DB.get(spell_nm, {})
		if spell_nm == "Summon Creature" or spell_nm == "Animate Undead" or bool(spell_db_entry.get("summon", false)):
			_open_summon_builder_dialog(action)
			return
		if bool(spell_db_entry.get("construct", false)):
			_open_construct_builder_dialog(action)
			return

	# Multi-target spells (mt > 1, non-area): enter multi-target selection mode
	var max_targets: int = int(action.get("max_targets", 1))
	if action_id == 10 and max_targets > 1 and area_type == 0 and not is_tp:
		var _sp_nm: String = str(action.get("matrix_id", ""))
		var _sp_db: Dictionary = _e._SPELL_DB.get(_sp_nm, {})
		var friendly: bool = bool(_sp_db.get("heal", false)) or not is_attack
		_multi_target_mode = true
		_multi_target_action = action.duplicate()
		_multi_target_list = []
		_multi_target_max = max_targets
		_multi_target_friendly = friendly
		var who: String = "allies" if friendly else "enemies"
		_action_mode_lbl.text = "Select up to %d %s (0/%d selected). Click to add, click again to confirm.  [ESC to cancel]" % [max_targets, who, max_targets]
		_update_3d_view()
		return

	# Healing spells: always target allies, even if is_attack was set by mistake
	if action_id == 10 and range_idx > 0:  # ACT_CAST_SPELL with range
		var _sp_nm: String = str(action.get("matrix_id", ""))
		var _sp_db: Dictionary = _e._SPELL_DB.get(_sp_nm, {})
		if bool(_sp_db.get("heal", false)):
			_pending_action = action.duplicate()
			_pending_action["_target_friendly"] = true
			_action_mode_lbl.text = "Click an ally to target…  [ESC to cancel]"
			_update_3d_view()
			return

	# Single-target attack / grapple: enter target-selection mode (click enemy)
	if is_attack or action_id == 18:  # 18 = ACT_GRAPPLE
		_pending_action = action.duplicate()
		_pending_action["_target_friendly"] = false
		_action_mode_lbl.text = "Click an enemy to target…  [ESC to cancel]"
		_update_3d_view()
		return

	# Single-target non-attack spells with range > 0 (heals, buffs):
	# enter target-selection mode for a friendly unit
	if action_id == 10 and range_idx > 0:  # 10 = ACT_CAST_SPELL
		_pending_action = action.duplicate()
		_pending_action["_target_friendly"] = true
		_action_mode_lbl.text = "Click an ally to target…  [ESC to cancel]"
		_update_3d_view()
		return

	# Immediate actions (no target needed: self-range spells, dodge, rest, etc.)
	var result: Dictionary = _e.dungeon_perform_action(_selected_id, action, "", 0, 0)
	_handle_action_result(result)

func _execute_action_on_target(target_id: String) -> void:
	if _pending_action.is_empty() or _selected_id == "": return
	var action: Dictionary = _pending_action.duplicate()

	# Teleport two-step: target selected → now pick destination tile
	if bool(action.get("_teleport_pick_target", false)):
		_cancel_pending_action()
		action.erase("_teleport_pick_target")
		action.erase("_target_friendly")
		action["_teleport_target_id"] = target_id
		var tp_max: int = int(action.get("tp_range", 0))
		var tgt_ent: Dictionary = _get_entity(target_id)
		_area_mode    = true
		_area_action  = action.duplicate()
		_area_radius  = tp_max   # show range circle if pre-paid
		_area_preview = Vector2i(-1, -1)
		_area_tp_origin = Vector2i(int(tgt_ent.get("x", -1)), int(tgt_ent.get("y", -1))) if tp_max > 0 else Vector2i(-1, -1)
		var tgt_name: String = str(tgt_ent.get("name", "target"))
		var range_hint: String = " (range: %d tiles)" % tp_max if tp_max > 0 else ""
		_action_mode_lbl.text = "Click a floor tile to teleport %s to…%s  [ESC to cancel]" % [tgt_name, range_hint]
		_update_3d_view()
		return

	_cancel_pending_action()
	var result: Dictionary = _e.dungeon_perform_action(_selected_id, action, target_id, 0, 0)
	_handle_action_result(result)

func _confirm_multi_target() -> void:
	if _multi_target_list.is_empty() or _selected_id == "":
		_cancel_pending_action()
		return
	var action: Dictionary = _multi_target_action.duplicate()
	action["_target_list"] = _multi_target_list.duplicate()
	# For multi-target teleport, transition to tile selection
	if bool(action.get("is_teleport", false)):
		_multi_target_mode = false
		var sel_ent: Dictionary = _get_entity(_selected_id)
		var tp_max: int = int(action.get("tp_range", 0))
		_area_mode    = true
		_area_action  = action.duplicate()
		_area_radius  = tp_max
		_area_preview = Vector2i(-1, -1)
		_area_tp_origin = Vector2i(int(sel_ent.get("x", -1)), int(sel_ent.get("y", -1))) if tp_max > 0 else Vector2i(-1, -1)
		_action_mode_lbl.text = "Click a floor tile to teleport %d units to…  [ESC to cancel]" % _multi_target_list.size()
		_multi_target_action = {}
		_multi_target_list = []
		_update_3d_view()
		return
	# Non-teleport: execute immediately with target list
	_cancel_pending_action()
	var result: Dictionary = _e.dungeon_perform_action(_selected_id, action, "", 0, 0)
	_handle_action_result(result)

func _cancel_pending_action() -> void:
	_pending_action  = {}
	_area_mode       = false
	_area_action     = {}
	_area_radius     = 0
	_area_preview    = Vector2i(-1, -1)
	_area_tp_origin  = Vector2i(-1, -1)
	_multi_target_mode   = false
	_multi_target_action = {}
	_multi_target_list   = []
	_multi_target_max    = 1
	_action_mode_lbl.text = ""
	_update_3d_view()

func _handle_action_result(result: Dictionary) -> void:
	var log_msg: String = str(result.get("log", ""))
	if log_msg != "":
		_add_log(log_msg)
	_refresh()
	_select_entity(_selected_id)
	_check_victory_defeat()

# ── Turn management ───────────────────────────────────────────────────────────
func _on_next_unit() -> void:
	_cancel_pending_action()
	var next_id: String = _e.dungeon_end_individual_turn()
	if next_id == "":
		# All player units have acted — prompt to end phase
		_add_log("[color=#aaaaff]All units have acted. End Phase when ready.[/color]")
		_btn_next_unit.disabled = true
	else:
		_select_entity(next_id)
		# Check if the selected unit is dying and auto-run death save
		var ent: Dictionary = _get_entity(next_id)
		if not ent.is_empty() and bool(ent.get("is_dying", false)):
			_run_death_save_for_unit(next_id)

func _run_death_save_for_unit(unit_id: String) -> void:
	var result: Dictionary = _e._do_death_save(unit_id)
	if not result.is_empty():
		var msg: String = str(result.get("message", "Death save rolled"))
		_add_log("[color=#ff6666]" + msg + "[/color]")
		_refresh()
		_update_entity_card()

func _on_end_phase() -> void:
	_cancel_pending_action()
	_selected_id = ""
	_valid_moves = []
	_populate_action_columns()
	_add_log("[color=#aaaaff]— Enemy Phase —[/color]")
	_phase_label.text = "ENEMY TURN"
	_phase_label.add_theme_color_override("font_color", Color(0.90, 0.30, 0.30))
	_btn_next_unit.disabled = true
	_btn_end_phase.disabled = true

	var logs: Array = _e.dungeon_advance_enemy_phase()
	for l in logs:
		_add_log(l)

	_refresh()
	_check_victory_defeat()
	_phase_label.text = "YOUR TURN"
	_phase_label.add_theme_color_override("font_color", Color(0.30, 0.85, 0.30))
	_btn_next_unit.disabled = false
	_btn_end_phase.disabled = false
	_auto_select_first()
	_add_log("[color=#aaffaa]— Your Turn (Round %d) —[/color]" % _e.get_dungeon_round())

## Copy any injuries acquired during combat back to the character's persistent dict.
func _sync_dungeon_injuries() -> void:
	for ent in _entities:
		if not bool(ent.get("is_player", false)): continue
		var eid: String = str(ent.get("id", ""))
		# Entity id format: "player_<handle>" — parse out the handle int
		if not eid.begins_with("player_"): continue
		var handle_str: String = eid.substr(7)
		if not handle_str.is_valid_int(): continue
		var h: int = handle_str.to_int()
		var cd = _e.get_char_dict(h)
		if cd == null: continue
		var new_injuries: Array = ent.get("injuries", [])
		if new_injuries.is_empty(): continue
		# Merge (don't duplicate already-known injuries)
		var existing: Array = cd.get("injuries", [])
		for inj in new_injuries:
			if str(inj) not in existing:
				existing.append(str(inj))
		cd["injuries"] = existing

func _on_back() -> void:
	# ── Persist injuries from dungeon entities back to character dicts ─────────
	_sync_dungeon_injuries()
	var was_story_combat: bool = GameState.quest_state.get("story_combat_active", false)
	var combat_victory: bool = (_outcome == "victory")
	_e.end_dungeon()

	# Store story combat result so the world scene can process it when loaded
	if was_story_combat:
		GameState.quest_state["story_combat_active"] = false
		GameState.quest_state["story_combat_pending_result"] = combat_victory

	GameState.save_game()   # persist character HP, gold etc. earned in dungeon

	# Return via main shell's pop_screen if available (preserves nav bar),
	# otherwise fall back to direct scene change.
	# Walk up the tree to find the main shell (it has pop_screen method)
	var main: Node = get_parent()
	while main != null and not main.has_method("pop_screen"):
		main = main.get_parent()
	if main != null:
		if GameState.dungeon_source == "tab":
			GameState.current_tab = 1  # World tab in main shell
		main.pop_screen()
	else:
		# Fallback: direct scene change (no main shell)
		if GameState.dungeon_source == "tab":
			get_tree().change_scene_to_file("res://scenes/world/world.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/explore/explore.tscn")

func _notify_story_combat_result(main_node: Node, victory: bool) -> void:
	# The world scene is now the active child of main's content area.
	# Walk the tree to find any node with _on_story_combat_resolved.
	# NOTE: No await here — this runs deferred so world scene is already loaded,
	# and this dungeon node is queued for free so awaiting would cancel the coroutine.
	_find_and_call_story_handler(main_node, victory)

func _find_and_call_story_handler(node: Node, victory: bool) -> bool:
	if node.has_method("_on_story_combat_resolved"):
		node._on_story_combat_resolved(victory)
		return true
	for child in node.get_children():
		if _find_and_call_story_handler(child, victory):
			return true
	return false

# ── Selection & state ─────────────────────────────────────────────────────────
func _select_entity(id: String) -> void:
	_selected_id = id
	_valid_moves = []
	var ent: Dictionary = _get_entity(id)
	if not ent.is_empty() and bool(ent["is_player"]) and not bool(ent["is_dead"]) \
			and _e.is_dungeon_player_phase():
		_valid_moves = _e.get_valid_dungeon_moves(id)

	_update_entity_card()
	_populate_action_columns()
	_update_3d_view()

func _auto_select_first() -> void:
	for ent in _entities:
		if bool(ent["is_player"]) and not bool(ent["is_dead"]):
			_select_entity(str(ent["id"]))
			return

func _refresh() -> void:
	_entities  = _e.get_dungeon_entities()
	_fog       = _e.get_dungeon_fog()
	_elevation = _e.get_dungeon_elevation_map()
	_round_label.text = "Round %d" % _e.get_dungeon_round()
	_map_dirty = true   # elevation/terrain may have changed — rebuild tiles
	_update_3d_view()
	_update_entity_card()
	_update_roster()

func _update_entity_card() -> void:
	var ent: Dictionary = _get_entity(_selected_id)
	if ent.is_empty():
		_badge_name.text       = "—"
		_badge_hp.text         = "♥ –/–"
		_badge_ap.text         = "◈ –/–"
		_badge_sp.text         = "✦ –/–"
		_badge_weapon.text     = ""
		_badge_light.text      = ""
		for c in _badge_conditions.get_children(): c.queue_free()
		_badge_matrices.text   = ""
		return

	_badge_name.text = str(ent["name"])

	var hp: int     = int(ent["hp"])
	var max_hp: int = int(ent["max_hp"])
	var is_dying: bool = bool(ent.get("is_dying", false))
	var is_mounted: bool = bool(ent.get("is_mounted", false))
	var handle: int = int(ent.get("handle", -1))
	var mount_data: Dictionary = {} if handle < 0 else _e.get_mount_data(handle)

	if is_dying:
		_badge_hp.text = "[color=#ff4444]DYING[/color]"
		# Show death save tracker
		var saves: int = int(ent.get("death_saves", 0))
		var fails: int = int(ent.get("death_fails", 0))
		_badge_hp.text += "\nSaves: %d/3  Fails: %d/3" % [saves, fails]
	else:
		_badge_hp.text  = "♥ %d/%d" % [hp, max_hp]
		# Show mount HP if mounted
		if is_mounted and not mount_data.is_empty():
			var mount_hp: int = int(mount_data.get("mount_hp", 0))
			var mount_max_hp: int = int(mount_data.get("mount_max_hp", 0))
			var mount_name: String = str(mount_data.get("mount_name", "Mount"))
			_badge_hp.text += "\n🐎 %s: %d/%d" % [mount_name, mount_hp, mount_max_hp]
			# If mount HP reaches 0, auto-dismount
			if mount_hp <= 0:
				ent["is_mounted"] = false
				_badge_hp.text += " [AUTO-DISMOUNT]"

	var ap_spent: int = int(ent.get("ap_spent", 0))
	var max_ap: int   = int(ent.get("max_ap", 10))
	var ap_left: int  = max_ap - ap_spent
	_badge_ap.text    = "◈ %d/%d" % [ap_left, max_ap]

	var cur_sp: int   = int(ent.get("sp", 0))
	var max_sp: int   = int(ent.get("max_sp", 6))
	var ritual_res: int = _e.get_ritual_sp_committed(int(ent.get("handle", -1)))
	var eff_max_sp: int = maxi(0, max_sp - ritual_res)
	_badge_sp.text    = "✦ %d/%d" % [cur_sp, eff_max_sp]

	var weapon_name: String = str(ent.get("equipped_weapon", "Unarmed"))
	handle = int(ent.get("handle", -1))
	var wpn_dur: String = ""
	if handle >= 0 and _e._chars.has(handle) and weapon_name != "Unarmed" and weapon_name != "None":
		var c: Dictionary = _e._chars[handle]
		var whp: int = _e._get_equip_hp(c, "weapon")
		var wmhp: int = _e._get_equip_max_hp(c, "weapon")
		if wmhp > 0:
			wpn_dur = " [%d/%d]" % [maxi(0, whp), wmhp]
			if whp <= 0: wpn_dur += " BROKEN"
	_badge_weapon.text = "⚔ " + weapon_name + wpn_dur

	var light_name: String = str(ent.get("equipped_light", "None"))
	_badge_light.text = "" if light_name == "None" else "🔥 " + light_name

	# ── Condition chips ─────────────────────────────────────────────────────────
	for old_chip in _badge_conditions.get_children():
		old_chip.queue_free()
	var conds: Array = ent.get("conditions", [])
	const COND_BENEFICIAL: Array = ["dodging", "hidden", "flying", "hasted", "inspired", "shielded"]
	const COND_HARMFUL: Array    = ["bleeding", "stunned", "slowed", "restrained", "blinded",
									"prone", "paralyzed", "poisoned", "grappled", "burning",
									"frozen", "silenced", "cursed", "weakened", "frightened"]

	# Add DYING/DEAD chips if applicable
	if bool(ent.get("is_dead", false)):
		_add_condition_chip("DEAD", Color(0.55, 0.55, 0.55))
	elif bool(ent.get("is_dying", false)):
		_add_condition_chip("DYING", Color(0.85, 0.24, 0.20))

	for cname in conds:
		var cs: String = str(cname).to_lower()
		var chip_col: Color
		if cs in COND_BENEFICIAL:
			chip_col = Color(0.20, 0.68, 0.30)   # green
		elif cs in COND_HARMFUL:
			chip_col = Color(0.85, 0.24, 0.20)   # red
		else:
			chip_col = Color(0.60, 0.50, 0.15)   # amber/neutral
		_add_condition_chip(cs, chip_col)

	var mats: Array = ent.get("matrices", [])
	if mats.is_empty():
		_badge_matrices.text = ""
	else:
		var mat_parts: Array = []
		for m in mats:
			var m_name: String = str(m.get("name", "?"))
			var m_rnd: int     = int(m.get("rounds", 0))
			var sup: bool      = bool(m.get("suppressed", false))
			var short_name: String = m_name.left(10) + ("…" if m_name.length() > 10 else "")
			mat_parts.append("%s%s(%dr)" % ["⏸ " if sup else "✨ ", short_name, m_rnd])
		_badge_matrices.text = "  ".join(mat_parts)

func _add_condition_chip(text: String, color: Color) -> void:
	var chip_lbl := Label.new()
	chip_lbl.text = text
	chip_lbl.add_theme_font_size_override("font_size", 10)
	chip_lbl.add_theme_color_override("font_color", color)
	var chip_bg := StyleBoxFlat.new()
	chip_bg.bg_color    = Color(color, 0.18)
	chip_bg.border_color = Color(color, 0.55)
	chip_bg.set_border_width_all(1)
	chip_bg.set_corner_radius_all(4)
	chip_bg.content_margin_left   = 5
	chip_bg.content_margin_right  = 5
	chip_bg.content_margin_top    = 2
	chip_bg.content_margin_bottom = 2
	var chip_panel := PanelContainer.new()
	chip_panel.add_theme_stylebox_override("panel", chip_bg)
	chip_panel.add_child(chip_lbl)
	_badge_conditions.add_child(chip_panel)

func _set_bar(bar: ProgressBar, val_lbl: Label, current: int, maximum: int, txt: String) -> void:
	val_lbl.text = txt
	bar.max_value = float(maxi(1, maximum))
	bar.value = float(clamp(current, 0, maximum))

func _update_roster() -> void:
	for child in _unit_tabs_hbox.get_children():
		child.queue_free()

	for ent in _entities:
		if not bool(ent["is_player"]): continue
		var captured_id: String = str(ent["id"])
		var is_dead:     bool   = bool(ent["is_dead"])
		var is_dying:    bool   = bool(ent.get("is_dying", false))
		var is_selected: bool   = (captured_id == _selected_id)

		var chip := Button.new()
		chip.text = str(ent["name"]).left(8)
		chip.add_theme_font_size_override("font_size", 11)
		chip.custom_minimum_size = Vector2(68, 28)
		chip.pressed.connect(func(): _select_entity(captured_id))

		var style := StyleBoxFlat.new()
		if is_dead:
			style.bg_color = Color(0.22, 0.22, 0.26)
		elif is_dying:
			style.bg_color = Color(0.66, 0.22, 0.22)
		elif is_selected:
			style.bg_color = Color(0.22, 0.50, 0.82)
		else:
			style.bg_color = Color(0.16, 0.30, 0.50)
		style.set_corner_radius_all(4)
		chip.add_theme_stylebox_override("normal", style)
		chip.add_theme_color_override("font_color",
			Color(0.42, 0.42, 0.42) if is_dead else Color.WHITE)

		# HP micro-badge below name via tooltip
		var hp: int     = int(ent["hp"])
		var max_hp: int = int(ent["max_hp"])
		if is_dead:
			chip.tooltip_text = "DEAD"
		elif is_dying:
			var saves: int = int(ent.get("death_saves", 0))
			var fails: int = int(ent.get("death_fails", 0))
			chip.tooltip_text = "DYING - Saves: %d/3  Fails: %d/3" % [saves, fails]
		else:
			chip.tooltip_text = "HP %d/%d" % [hp, max_hp]

		_unit_tabs_hbox.add_child(chip)

# ── Victory / Defeat ──────────────────────────────────────────────────────────
func _check_victory_defeat() -> void:
	_check_outcome()   # delegate to the new engine-backed system

# ── PHB Combat Helpers ────────────────────────────────────────────────────────
func _find_adjacent_dying_ally(unit_id: String) -> String:
	var ent: Dictionary = _get_entity(unit_id)
	if ent.is_empty(): return ""
	var ux: int = int(ent.get("x", -1))
	var uy: int = int(ent.get("y", -1))
	if ux < 0 or uy < 0: return ""
	# Check all 4 adjacent tiles for dying allies
	var adjacent: Array = [[ux+1, uy], [ux-1, uy], [ux, uy+1], [ux, uy-1]]
	for adj in adjacent:
		var adj_ent: Dictionary = _entity_at(adj[0], adj[1])
		if not adj_ent.is_empty() and bool(adj_ent.get("is_dying", false)):
			return str(adj_ent.get("id", ""))
	return ""

func _has_adjacent_enemy(unit_id: String) -> bool:
	var ent: Dictionary = _get_entity(unit_id)
	if ent.is_empty(): return false
	var is_player: bool = bool(ent.get("is_player", false))
	var ux: int = int(ent.get("x", -1))
	var uy: int = int(ent.get("y", -1))
	if ux < 0 or uy < 0: return false
	# Check all 4 adjacent tiles for enemies/allies depending on unit type
	var adjacent: Array = [[ux+1, uy], [ux-1, uy], [ux, uy+1], [ux, uy-1]]
	for adj in adjacent:
		var adj_ent: Dictionary = _entity_at(adj[0], adj[1])
		if not adj_ent.is_empty() and not bool(adj_ent.get("is_dead", false)):
			var adj_is_player: bool = bool(adj_ent.get("is_player", false))
			if is_player and not adj_is_player: return true
			elif not is_player and adj_is_player: return true
	return false

func _show_shove_options(unit_id: String) -> void:
	# For now, just call the default shove (can be expanded to show push vs prone menu)
	_e.dung_shove(_selected_id)
	_refresh()
	_update_entity_card()

# ── Helpers ───────────────────────────────────────────────────────────────────
func _get_entity(id: String) -> Dictionary:
	for ent in _entities:
		if str(ent["id"]) == id: return ent
	return {}

func _entity_at(tx: int, ty: int) -> Dictionary:
	for ent in _entities:
		if int(ent["x"]) == tx and int(ent["y"]) == ty: return ent
	return {}

## Apply mounted speed override to entity's speed
func _apply_mounted_speed(ent: Dictionary) -> int:
	var is_mounted: bool = bool(ent.get("is_mounted", false))
	if not is_mounted:
		return int(ent.get("speed", 30))

	var handle: int = int(ent.get("handle", -1))
	if handle < 0:
		return int(ent.get("speed", 30))

	var mount_data: Dictionary = _e.get_mount_data(handle)
	if mount_data.is_empty():
		return int(ent.get("speed", 30))

	var mount_speed: int = int(mount_data.get("mount_speed", 0))
	return mount_speed if mount_speed > 0 else int(ent.get("speed", 30))

## Handle mount taking damage (50% chance instead of rider)
func _apply_mount_damage(ent: Dictionary, damage: int) -> int:
	var is_mounted: bool = bool(ent.get("is_mounted", false))
	if not is_mounted or randf() > 0.5:  # 50% chance mount takes damage
		return damage  # rider takes damage

	var handle: int = int(ent.get("handle", -1))
	if handle < 0:
		return damage

	var mount_data: Dictionary = _e.get_mount_data(handle)
	if mount_data.is_empty():
		return damage

	# Apply damage to mount instead
	var mount_hp: int = int(mount_data.get("mount_hp", 0))
	mount_hp = maxi(0, mount_hp - damage)
	mount_data["mount_hp"] = mount_hp
	_add_log("Mount takes %d damage! (%d/%d HP)" % [damage, mount_hp, mount_data.get("mount_max_hp", 0)])

	# If mount HP reaches 0, auto-dismount
	if mount_hp <= 0:
		ent["is_mounted"] = false
		_add_log("Mount is defeated! Rider is dismounted.")

	return 0  # rider takes no damage

## Get mounted combat AC bonus (saddle-dependent)
func _get_mounted_ac_bonus(ent: Dictionary) -> int:
	var is_mounted: bool = bool(ent.get("is_mounted", false))
	if not is_mounted:
		return 0

	var handle: int = int(ent.get("handle", -1))
	if handle < 0:
		return 0

	var mount_data: Dictionary = _e.get_mount_data(handle)
	if mount_data.is_empty():
		return 0

	var saddle: String = str(mount_data.get("saddle", "None"))
	if saddle == "Military Saddle":
		return 1  # Military saddle gives +1 AC
	return 0

func _add_log(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > 120:
		_log_lines = _log_lines.slice(_log_lines.size() - 120)
	_log_text.clear()
	for line in _log_lines:
		_log_text.append_text(line + "\n")

func _section_label(txt: String) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.58, 0.58, 0.53))
	return lbl

func _hsep() -> HSeparator:
	return HSeparator.new()

## Labeled row for dialog forms: fixed-width label + control widget
func _spell_row(label_text: String, widget: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(120, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)
	row.add_child(widget)
	return row

func _spacer_h(w: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(w, 0)
	return s

func _colored_btn(txt: String, col: Color) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 34)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = col
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	b.add_theme_stylebox_override("normal", style)
	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = col.lightened(0.15)
	b.add_theme_stylebox_override("hover", hover_style)
	var dis_style: StyleBoxFlat = style.duplicate()
	dis_style.bg_color = col.darkened(0.45)
	b.add_theme_stylebox_override("disabled", dis_style)
	return b

# ══════════════════════════════════════════════════════════════════════════════
# ── Dungeon Spell Crafter (mobile parity) ────────────────────────────────────
# ══════════════════════════════════════════════════════════════════════════════

func _sc_current_effect_name() -> String:
	var effects: Array = SC_DOMAIN_EFFECTS[_sc_domain] if _sc_domain < SC_DOMAIN_EFFECTS.size() else []
	if _sc_effect_idx >= effects.size(): return ""
	return effects[_sc_effect_idx][0]

func _sc_is_summon_effect() -> bool:
	return _sc_current_effect_name() == "Summon"

func _sc_is_construct_effect() -> bool:
	return _sc_current_effect_name() == "Create Construct"

func _sc_calc_cost() -> int:
	# Teleport spells: cost is based on max distance (pre-paid)
	if _sc_is_teleport:
		return maxi(1, (_sc_tp_range + 1) / 2)
	var effects: Array = SC_DOMAIN_EFFECTS[_sc_domain] if _sc_domain < SC_DOMAIN_EFFECTS.size() else []
	var base: int = int(effects[_sc_effect_idx][1]) if _sc_effect_idx < effects.size() else 1
	# Summon/Construct effects: base cost only — details add SP at cast time
	if _sc_is_summon_effect() or _sc_is_construct_effect():
		var dur_mult: int = SC_DURATION_MULT[_sc_duration_idx] if _sc_duration_idx < SC_DURATION_MULT.size() else 1
		var range_cost: int = SC_RANGE_SP[_sc_range_idx] if _sc_range_idx < SC_RANGE_SP.size() else 0
		var with_dur: int = base if _sc_duration_idx == 0 else base * dur_mult
		return maxi(1, with_dur + range_cost)
	var sides_mod: int = SC_DIE_SIDES_MOD[_sc_die_idx] if _sc_die_idx < SC_DIE_SIDES_MOD.size() else 0
	var dice_cost: int = _sc_die_count * (1 + sides_mod)
	var dur_mult: int  = SC_DURATION_MULT[_sc_duration_idx] if _sc_duration_idx < SC_DURATION_MULT.size() else 1
	var base_eff: int  = base + dice_cost
	var with_dur: int  = base_eff if _sc_duration_idx == 0 else base_eff * dur_mult
	var range_cost: int = SC_RANGE_SP[_sc_range_idx] if _sc_range_idx < SC_RANGE_SP.size() else 0
	var tgt_cost: int = 0
	if _sc_targets > 1:
		for i in range(_sc_targets - 1): tgt_cost += int(pow(2.0, float(i + 1)))
	var harmful: int = 0; var beneficial: int = 0
	for cn in _sc_conditions:
		if cn in SC_COND_HARMFUL: harmful += 1
		else: beneficial += 1
	var cond_cost: int = (harmful * 3) - (beneficial * 2)
	var type_cost: int = 1 if _sc_is_saving_throw else 0
	var area_mult: int = SC_AREA_MULT[_sc_area_idx] if _sc_area_idx < SC_AREA_MULT.size() else 1
	var total: int = (type_cost + with_dur + range_cost + tgt_cost + cond_cost) * area_mult
	return maxi(0, total)

func _sc_description() -> String:
	var effects: Array = SC_DOMAIN_EFFECTS[_sc_domain] if _sc_domain < SC_DOMAIN_EFFECTS.size() else []
	var eff_name: String = effects[_sc_effect_idx][0] if _sc_effect_idx < effects.size() else "Unknown"
	var dom: String = SC_DOMAIN_NAMES[_sc_domain]
	var tgt: String = "a single target" if _sc_targets <= 1 else "up to %d targets" % _sc_targets
	var rng: String = "on yourself" if _sc_range_idx == 0 else "within %s" % SC_RANGE_LABELS[_sc_range_idx]
	var area: String = "" if _sc_area_idx == 0 else " affecting a %s" % SC_AREA_LABELS[_sc_area_idx]
	var dur: String = SC_DURATION_LABELS[_sc_duration_idx]
	var save_d: String = ". Targets may save to resist." if _sc_is_saving_throw else "."
	if _sc_is_construct_effect():
		return "Using the %s domain, conjure an inanimate construct %s. Choose structure, weapon, armor, shield, or equipment set at cast time. Base cost %d SP. Can dismiss/recall and reform while active. Lasts %s." % [dom, rng, _sc_calc_cost(), dur]
	if _sc_is_summon_effect():
		return "Using the %s domain, conjure a summoned creature %s. Stats, feats, and abilities are chosen at cast time (1 SP per stat point, feat tier cost, ability AP+SP cost). Base cost %d SP. Lasts %s." % [dom, rng, _sc_calc_cost(), dur]
	if _sc_is_teleport:
		return "Teleport %s up to %d tiles (%dft). SP pre-paid; costs only AP to cast." % [
			("yourself" if _sc_range_idx == 0 else "a target %s" % rng), _sc_tp_range, _sc_tp_range * 5]
	var act: String = "heals for" if _sc_is_healing else "deals"
	var dice_d: String = " %dd%d" % [_sc_die_count, [4,6,8,10,12][_sc_die_idx]] if _sc_die_count > 0 else ""
	var type_d: String = ""
	if _sc_die_count > 0:
		type_d = " hit points" if _sc_is_healing else " %s damage" % SC_DAMAGE_TYPES[_sc_damage_type]
	return "Using the %s domain, you weave a spell of %s that %s%s%s targeting %s %s%s. Lasts %s%s" % [dom, eff_name, act, dice_d, type_d, tgt, rng, area, dur, save_d]

func _sc_update_preview() -> void:
	if is_instance_valid(_sc_cost_lbl):
		var cost_label: String = "Base SP Cost: %d" if (_sc_is_summon_effect() or _sc_is_construct_effect()) else "Total SP Cost: %d"
		_sc_cost_lbl.text = cost_label % _sc_calc_cost()
	if is_instance_valid(_sc_breakdown_lbl):
		var effects: Array = SC_DOMAIN_EFFECTS[_sc_domain] if _sc_domain < SC_DOMAIN_EFFECTS.size() else []
		var eff_name: String = effects[_sc_effect_idx][0] if _sc_effect_idx < effects.size() else "Unknown"
		var base: int = int(effects[_sc_effect_idx][1]) if _sc_effect_idx < effects.size() else 1
		if _sc_is_teleport:
			_sc_breakdown_lbl.text = "Teleport Distance: %d tiles (%dft)\nCost: (%d + 1) / 2 = %d SP (pre-paid)" % [
				_sc_tp_range, _sc_tp_range * 5, _sc_tp_range, maxi(1, (_sc_tp_range + 1) / 2)]
		elif _sc_is_summon_effect():
			_sc_breakdown_lbl.text = "Base Effect (%s): %d — additional SP for stats/feats/abilities at cast time" % [eff_name, base]
		elif _sc_is_construct_effect():
			_sc_breakdown_lbl.text = "Base Effect (%s): %d — construct size/equipment costs added at cast time" % [eff_name, base]
		else:
			_sc_breakdown_lbl.text = "Base Effect (%s): %d" % [eff_name, base]
	if is_instance_valid(_sc_desc_lbl):
		_sc_desc_lbl.text = _sc_description()

func _open_spell_crafter() -> void:
	if _sc_overlay != null and is_instance_valid(_sc_overlay):
		_sc_overlay.queue_free()
		_sc_overlay = null

	_sc_die_btns.clear()
	_sc_tp_range_row = null
	_sc_cost_lbl = null; _sc_breakdown_lbl = null; _sc_desc_lbl = null

	# Full-screen overlay
	_sc_overlay = Panel.new()
	_sc_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.05, 0.10, 0.96)
	_sc_overlay.add_theme_stylebox_override("panel", bg_style)
	add_child(_sc_overlay)

	var mgn = MarginContainer.new()
	for s in ["left","right","top","bottom"]: mgn.add_theme_constant_override("margin_" + s, 20)
	mgn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sc_overlay.add_child(mgn)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mgn.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Header with close
	var hdr = HBoxContainer.new()
	vbox.add_child(hdr)
	hdr.add_child(RimvaleUtils.label("Spell Crafter", 18, RimvaleColors.TEXT_WHITE))
	var spacer = Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(spacer)
	var close_btn = Button.new(); close_btn.text = "X"; close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", RimvaleColors.DANGER)
	close_btn.pressed.connect(func():
		if is_instance_valid(_sc_overlay): _sc_overlay.queue_free(); _sc_overlay = null
	)
	hdr.add_child(close_btn)

	# Spell name
	var name_edit = LineEdit.new()
	name_edit.placeholder_text = "Spell Name"
	name_edit.text = _sc_name
	name_edit.custom_minimum_size = Vector2(0, 36)
	name_edit.add_theme_font_size_override("font_size", 14)
	name_edit.text_changed.connect(func(t: String): _sc_name = t)
	vbox.add_child(name_edit)

	# Domain
	var dom_opt = OptionButton.new()
	for dn in SC_DOMAIN_NAMES: dom_opt.add_item(dn)
	dom_opt.selected = _sc_domain
	dom_opt.item_selected.connect(func(i: int): _sc_domain = i; _sc_effect_idx = 0; _rebuild_spell_crafter())
	vbox.add_child(_sc_row("Domain", dom_opt))

	# Effect
	var eff_opt = OptionButton.new()
	var effs: Array = SC_DOMAIN_EFFECTS[_sc_domain] if _sc_domain < SC_DOMAIN_EFFECTS.size() else []
	for ef in effs: eff_opt.add_item(ef[0])
	eff_opt.selected = mini(_sc_effect_idx, max(0, effs.size() - 1))
	eff_opt.item_selected.connect(func(i: int): _sc_effect_idx = i; _rebuild_spell_crafter())
	vbox.add_child(_sc_row("Effect", eff_opt))

	# ── Effect-specific info banner ──
	var is_summon: bool = _sc_is_summon_effect()
	var is_construct: bool = _sc_is_construct_effect()
	if is_construct:
		var construct_info := VBoxContainer.new()
		construct_info.add_theme_constant_override("separation", 4)
		vbox.add_child(construct_info)
		var ci_panel := PanelContainer.new()
		var ci_style := StyleBoxFlat.new()
		ci_style.bg_color = Color(0.12, 0.12, 0.20, 0.90)
		ci_style.corner_radius_top_left = 6; ci_style.corner_radius_top_right = 6
		ci_style.corner_radius_bottom_left = 6; ci_style.corner_radius_bottom_right = 6
		ci_style.content_margin_left = 10; ci_style.content_margin_right = 10
		ci_style.content_margin_top = 8; ci_style.content_margin_bottom = 8
		ci_panel.add_theme_stylebox_override("panel", ci_style)
		construct_info.add_child(ci_panel)
		var ci_vbox := VBoxContainer.new()
		ci_vbox.add_theme_constant_override("separation", 2)
		ci_panel.add_child(ci_vbox)
		ci_vbox.add_child(RimvaleUtils.label("Create Construct Effect", 14, Color(0.50, 0.70, 1.0)))
		var ci_note := RimvaleUtils.label(
			"This spell creates inanimate constructs. When cast, the Construct Builder opens to choose: "
			+ "structures (walls/cubes, 2 SP per 5x5x5, doubling with size), "
			+ "weapons (light 2 SP, martial 3 SP, heavy 4 SP), "
			+ "armor (light 2 SP, medium 3 SP, heavy 4 SP), "
			+ "shields (1-2 SP), and TRR clothing (+1 SP per rating). "
			+ "Equipment sets get -1 SP per item (up to -3). "
			+ "HP = 3x SP, AC = 10+SP (cap 20), DT = SP (cap 10). "
			+ "Can dismiss/recall from pocket dimension and reform if destroyed.",
			11, Color(0.60, 0.65, 0.75))
		ci_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ci_vbox.add_child(ci_note)
	if is_summon:
		var summon_info := VBoxContainer.new()
		summon_info.add_theme_constant_override("separation", 4)
		vbox.add_child(summon_info)
		var info_panel := PanelContainer.new()
		var info_style := StyleBoxFlat.new()
		info_style.bg_color = Color(0.12, 0.18, 0.12, 0.90)
		info_style.corner_radius_top_left = 6; info_style.corner_radius_top_right = 6
		info_style.corner_radius_bottom_left = 6; info_style.corner_radius_bottom_right = 6
		info_style.content_margin_left = 10; info_style.content_margin_right = 10
		info_style.content_margin_top = 8; info_style.content_margin_bottom = 8
		info_panel.add_theme_stylebox_override("panel", info_style)
		summon_info.add_child(info_panel)
		var info_vbox := VBoxContainer.new()
		info_vbox.add_theme_constant_override("separation", 2)
		info_panel.add_child(info_vbox)
		info_vbox.add_child(RimvaleUtils.label("Summon Effect", 14, Color(0.40, 0.90, 0.40)))
		var note_lbl := RimvaleUtils.label(
			"This spell creates a summoned creature. When cast, the Creature Builder opens to allocate stats, feats, and abilities. "
			+ "Each stat point costs 1 SP. Feats cost SP equal to their tier. Abilities cost their AP+SP from the monster table. "
			+ "Only the base spell cost, duration, and range are set here — creature details are chosen at cast time.",
			11, Color(0.65, 0.70, 0.60))
		note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_vbox.add_child(note_lbl)

	# Duration
	var dur_opt = OptionButton.new()
	for dl in SC_DURATION_LABELS: dur_opt.add_item(dl)
	dur_opt.selected = _sc_duration_idx
	dur_opt.item_selected.connect(func(i: int): _sc_duration_idx = i; _sc_update_preview())
	vbox.add_child(_sc_row("Duration", dur_opt))

	# Range
	var rng_opt = OptionButton.new()
	for rl in SC_RANGE_LABELS: rng_opt.add_item(rl)
	rng_opt.selected = _sc_range_idx
	rng_opt.item_selected.connect(func(i: int): _sc_range_idx = i; _sc_update_preview())
	vbox.add_child(_sc_row("Range", rng_opt))

	# ── Non-summon/construct fields: targets, area, dice, damage, flags, conditions ──
	if not is_summon and not is_construct:
		# Targets
		var tgt_lbl = RimvaleUtils.label("Targets: %d" % _sc_targets, 12, RimvaleColors.TEXT_GRAY)
		vbox.add_child(tgt_lbl)
		var tgt_sl = HSlider.new(); tgt_sl.min_value = 1; tgt_sl.max_value = 10; tgt_sl.step = 1; tgt_sl.value = _sc_targets
		tgt_sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tgt_sl.value_changed.connect(func(v: float): _sc_targets = int(v); tgt_lbl.text = "Targets: %d" % _sc_targets; _sc_update_preview())
		vbox.add_child(tgt_sl)

		# Area
		var area_opt = OptionButton.new()
		for al in SC_AREA_LABELS: area_opt.add_item(al)
		area_opt.selected = _sc_area_idx
		area_opt.item_selected.connect(func(i: int): _sc_area_idx = i; _sc_update_preview())
		vbox.add_child(_sc_row("Area", area_opt))

		# Dice Count
		var dc_lbl = RimvaleUtils.label("Dice Count: %d" % _sc_die_count, 12, RimvaleColors.TEXT_GRAY)
		vbox.add_child(dc_lbl)
		var dc_sl = HSlider.new(); dc_sl.min_value = 0; dc_sl.max_value = 10; dc_sl.step = 1; dc_sl.value = _sc_die_count
		dc_sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dc_sl.value_changed.connect(func(v: float): _sc_die_count = int(v); dc_lbl.text = "Dice Count: %d" % _sc_die_count; _sc_update_preview())
		vbox.add_child(dc_sl)

		# Die Type
		vbox.add_child(RimvaleUtils.label("Die Type", 12, RimvaleColors.TEXT_GRAY))
		var dt_row = HBoxContainer.new(); dt_row.add_theme_constant_override("separation", 6)
		for di in range(SC_DIE_LABELS.size()):
			var di_c: int = di
			var col: Color = RimvaleColors.ACCENT if di == _sc_die_idx else RimvaleColors.TEXT_GRAY
			var dbtn = RimvaleUtils.button(SC_DIE_LABELS[di], col, 30, 12)
			dbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			dbtn.pressed.connect(func():
				_sc_die_idx = di_c
				for k in range(_sc_die_btns.size()):
					_sc_die_btns[k].add_theme_color_override("font_color", RimvaleColors.ACCENT if k == _sc_die_idx else RimvaleColors.TEXT_GRAY)
				_sc_update_preview()
			)
			_sc_die_btns.append(dbtn); dt_row.add_child(dbtn)
		vbox.add_child(dt_row)

		# Damage Type
		var dmg_opt = OptionButton.new()
		for dt in SC_DAMAGE_TYPES: dmg_opt.add_item(dt)
		dmg_opt.selected = _sc_damage_type
		dmg_opt.item_selected.connect(func(i: int): _sc_damage_type = i; _sc_update_preview())
		vbox.add_child(_sc_row("Damage Type", dmg_opt))

		vbox.add_child(RimvaleUtils.separator())

		# Flags
		var fl_row = HBoxContainer.new(); fl_row.add_theme_constant_override("separation", 16)
		var h_chk = CheckBox.new(); h_chk.text = "Healing Spell"; h_chk.button_pressed = _sc_is_healing
		h_chk.add_theme_font_size_override("font_size", 12)
		h_chk.toggled.connect(func(b: bool): _sc_is_healing = b; _sc_update_preview())
		fl_row.add_child(h_chk)
		var sv_chk = CheckBox.new(); sv_chk.text = "No Attack Roll\n(Target saves)"; sv_chk.button_pressed = _sc_is_saving_throw
		sv_chk.add_theme_font_size_override("font_size", 12)
		sv_chk.toggled.connect(func(b: bool): _sc_is_saving_throw = b; _sc_update_preview())
		fl_row.add_child(sv_chk)
		vbox.add_child(fl_row)
		var tp_chk = CheckBox.new(); tp_chk.text = "Teleportation"; tp_chk.button_pressed = _sc_is_teleport
		tp_chk.add_theme_font_size_override("font_size", 12)
		tp_chk.toggled.connect(func(b: bool):
			_sc_is_teleport = b
			if _sc_tp_range_row != null: _sc_tp_range_row.visible = b
			_sc_update_preview()
		)
		vbox.add_child(tp_chk)

		# Teleport distance slider (visible only when teleport is checked)
		_sc_tp_range_row = HBoxContainer.new()
		_sc_tp_range_row.add_theme_constant_override("separation", 8)
		_sc_tp_range_row.visible = _sc_is_teleport
		var sc_tp_lbl = RimvaleUtils.label("Teleport Distance (tiles):", 12, RimvaleColors.TEXT_WHITE)
		_sc_tp_range_row.add_child(sc_tp_lbl)
		var sc_tp_val = RimvaleUtils.label(str(_sc_tp_range), 13, Color(0.40, 0.80, 1.0))
		sc_tp_val.custom_minimum_size = Vector2(30, 0)
		_sc_tp_range_row.add_child(sc_tp_val)
		var sc_tp_slider = HSlider.new()
		sc_tp_slider.min_value = 1; sc_tp_slider.max_value = 20; sc_tp_slider.step = 1
		sc_tp_slider.value = _sc_tp_range
		sc_tp_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc_tp_slider.custom_minimum_size = Vector2(120, 0)
		sc_tp_slider.value_changed.connect(func(v: float):
			_sc_tp_range = int(v)
			sc_tp_val.text = str(_sc_tp_range)
			_sc_update_preview()
		)
		_sc_tp_range_row.add_child(sc_tp_slider)
		vbox.add_child(_sc_tp_range_row)

		vbox.add_child(RimvaleUtils.separator())

		# Conditions
		vbox.add_child(RimvaleUtils.label("Conditions", 14, RimvaleColors.TEXT_WHITE))
		var cond_outer = HBoxContainer.new(); cond_outer.add_theme_constant_override("separation", 12)
		vbox.add_child(cond_outer)

		var ben_col = VBoxContainer.new(); ben_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ben_col.add_theme_constant_override("separation", 0); cond_outer.add_child(ben_col)
		ben_col.add_child(RimvaleUtils.label("Beneficial", 11, Color(0.30, 0.69, 0.31)))
		for cn in SC_COND_BENEFICIAL:
			var cn_c: String = cn
			var chk = CheckBox.new(); chk.text = cn; chk.button_pressed = cn in _sc_conditions
			chk.add_theme_font_size_override("font_size", 11)
			chk.toggled.connect(func(b: bool):
				if b:
					if cn_c not in _sc_conditions: _sc_conditions.append(cn_c)
				else: _sc_conditions.erase(cn_c)
				_sc_update_preview()
			)
			ben_col.add_child(chk)

		var harm_col = VBoxContainer.new(); harm_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		harm_col.add_theme_constant_override("separation", 0); cond_outer.add_child(harm_col)
		harm_col.add_child(RimvaleUtils.label("Harmful", 11, Color(0.90, 0.40, 0.40)))
		for cn in SC_COND_HARMFUL:
			var cn_c: String = cn
			var chk = CheckBox.new(); chk.text = cn; chk.button_pressed = cn in _sc_conditions
			chk.add_theme_font_size_override("font_size", 11)
			chk.toggled.connect(func(b: bool):
				if b:
					if cn_c not in _sc_conditions: _sc_conditions.append(cn_c)
				else: _sc_conditions.erase(cn_c)
				_sc_update_preview()
			)
			harm_col.add_child(chk)

	vbox.add_child(RimvaleUtils.spacer(6))

	# Preview card
	var card = PanelContainer.new(); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cs = StyleBoxFlat.new(); cs.bg_color = Color(0.14, 0.12, 0.22)
	cs.corner_radius_top_left = 8; cs.corner_radius_top_right = 8
	cs.corner_radius_bottom_left = 8; cs.corner_radius_bottom_right = 8
	cs.content_margin_left = 14; cs.content_margin_right = 14
	cs.content_margin_top = 12; cs.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", cs)
	vbox.add_child(card)

	var cv = VBoxContainer.new(); cv.add_theme_constant_override("separation", 4)
	card.add_child(cv)

	_sc_cost_lbl = RimvaleUtils.label("Total SP Cost: —", 18, Color(0.74, 0.40, 1.0))
	cv.add_child(_sc_cost_lbl)
	_sc_breakdown_lbl = RimvaleUtils.label("", 10, RimvaleColors.TEXT_DIM)
	cv.add_child(_sc_breakdown_lbl)
	cv.add_child(RimvaleUtils.label("Description:", 12, RimvaleColors.TEXT_WHITE))
	_sc_desc_lbl = RimvaleUtils.label("", 11, Color(0.70, 0.75, 0.85))
	_sc_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(_sc_desc_lbl)
	_sc_update_preview()

	cv.add_child(RimvaleUtils.spacer(6))

	# Register button
	var reg_btn = RimvaleUtils.button("Register Custom Spell", Color(0.35, 0.28, 0.65), 44, 14)
	reg_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reg_btn.pressed.connect(_sc_register_spell)
	cv.add_child(reg_btn)

func _rebuild_spell_crafter() -> void:
	if is_instance_valid(_sc_overlay):
		_sc_overlay.queue_free(); _sc_overlay = null
	_open_spell_crafter()

func _sc_register_spell() -> void:
	var sname: String = _sc_name.strip_edges()
	if sname.is_empty():
		_add_log("[color=red]Enter a spell name first.[/color]")
		return
	var cost: int = _sc_calc_cost()
	var is_summon: bool = _sc_is_summon_effect()
	var is_construct: bool = _sc_is_construct_effect()
	var is_special: bool = is_summon or is_construct
	var die_sides: int = 0 if is_special else [4,6,8,10,12][_sc_die_idx]
	var die_count: int = 0 if is_special else _sc_die_count
	var dur_rounds: int = SC_DURATION_ROUNDS[_sc_duration_idx]
	var cond_csv: String = "" if is_special else ",".join(_sc_conditions)
	var targets: int = 1 if is_special else _sc_targets
	var area: int = 0 if is_special else _sc_area_idx
	# Register spell and teach only the selected unit
	var sc_handle: int = -2
	if _selected_id != "":
		var ent = _get_entity(_selected_id)
		sc_handle = int(ent.get("handle", -2))
	var sc_tp_range_val: int = _sc_tp_range if _sc_is_teleport else 0
	_e.add_custom_spell(
		sname, _sc_domain, cost, _sc_description(),
		_sc_range_idx, (not _sc_is_saving_throw) and (not _sc_is_healing),
		die_count, die_sides, _sc_damage_type,
		_sc_is_healing, dur_rounds, targets,
		area, cond_csv, _sc_is_teleport,
		false, sc_handle, sc_tp_range_val, is_summon, is_construct
	)
	var display_cost: int = 0 if _sc_is_teleport else cost
	_add_log("[color=#bd66ff]%s registered and learned: %s (%d SP)[/color]" % [sname, _sc_description().left(60), display_cost])
	_sc_name = ""
	if is_instance_valid(_sc_overlay): _sc_overlay.queue_free(); _sc_overlay = null
	_populate_action_columns()

func _sc_row(label_text: String, ctrl: Control) -> HBoxContainer:
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 8)
	var lbl = RimvaleUtils.label(label_text, 12, RimvaleColors.TEXT_GRAY)
	lbl.custom_minimum_size = Vector2(100, 0)
	row.add_child(lbl)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ctrl)
	return row

# ── Shapeshift Form Selection Dialog ─────────────────────────────────────────

func _open_shapeshift_dialog(action: Dictionary) -> void:
	if _ss_overlay != null and is_instance_valid(_ss_overlay):
		_ss_overlay.queue_free(); _ss_overlay = null
	_ss_pending_action = action.duplicate()

	var ent: Dictionary = _get_entity(_selected_id)
	if ent.is_empty(): return
	var ch: int = int(ent.get("handle", -1))
	if ch < 0: return
	var char_data: Dictionary = _e._chars.get(ch, {})
	var ss_tier: int = int(char_data.get("feats", {}).get("Shapeshifter's Path", 0))
	var forms: PackedStringArray = _e._shapeshift_available_forms(ss_tier)
	var sp_avail: int = int(ent.get("sp", 0))
	var char_level: int = int(char_data.get("level", 1))

	# Full-screen overlay
	_ss_overlay = Panel.new()
	_ss_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.05, 0.10, 0.96)
	_ss_overlay.add_theme_stylebox_override("panel", bg_style)
	add_child(_ss_overlay)

	var mgn := MarginContainer.new()
	for s in ["left","right","top","bottom"]: mgn.add_theme_constant_override("margin_" + s, 20)
	mgn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ss_overlay.add_child(mgn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mgn.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Header
	var hdr := HBoxContainer.new()
	vbox.add_child(hdr)
	hdr.add_child(RimvaleUtils.label("Shapeshift — Choose Form", 18, RimvaleColors.TEXT_WHITE))
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(spacer)
	var close_btn := Button.new(); close_btn.text = "X"; close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", RimvaleColors.DANGER)
	close_btn.pressed.connect(func():
		if is_instance_valid(_ss_overlay): _ss_overlay.queue_free(); _ss_overlay = null
	)
	hdr.add_child(close_btn)

	# Tier info
	var tier_lbl := RimvaleUtils.label(
		"Tier %d — SP available: %d — Char level: %d" % [ss_tier, sp_avail, char_level],
		12, Color(0.65, 0.80, 0.65))
	vbox.add_child(tier_lbl)

	# SP investment slider
	var sp_row := HBoxContainer.new()
	sp_row.add_theme_constant_override("separation", 8)
	vbox.add_child(sp_row)
	sp_row.add_child(RimvaleUtils.label("Invest SP:", 12, RimvaleColors.TEXT_GRAY))
	var sp_slider := HSlider.new()
	sp_slider.min_value = 0
	sp_slider.max_value = mini(sp_avail, char_level)
	sp_slider.value = 0
	sp_slider.step = 1
	sp_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp_slider.custom_minimum_size = Vector2(120, 0)
	sp_row.add_child(sp_slider)
	var sp_val_lbl := RimvaleUtils.label("0", 12, Color(0.40, 0.85, 1.0))
	sp_row.add_child(sp_val_lbl)
	var sp_info_lbl := RimvaleUtils.label("Creature level: 0 (stats = 0, min 1 HP)", 11, Color(0.55, 0.55, 0.50))
	vbox.add_child(sp_info_lbl)

	sp_slider.value_changed.connect(func(val: float):
		sp_val_lbl.text = str(int(val))
		var cre_lvl: int = int(val)
		if cre_lvl == 0:
			sp_info_lbl.text = "Creature level: 0 (stats = 0, min 1 HP)"
		else:
			var ratio: float = float(cre_lvl) / float(maxi(1, char_level))
			sp_info_lbl.text = "Creature level: %d (%.0f%% of form stats)" % [cre_lvl, ratio * 100]
	)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)

	# Form list
	vbox.add_child(RimvaleUtils.label("Available Forms:", 14, RimvaleColors.TEXT_WHITE))

	for form_name in forms:
		var form: Dictionary = _e.ANIMAL_FORMS[form_name]
		var size_str: String = str(form["size"])
		var weapon_str: String = str(form["weapon"])
		var dice_arr: Array = form.get("dice", [1,6])
		var special_str: String = str(form.get("special", ""))

		var form_row := HBoxContainer.new()
		form_row.add_theme_constant_override("separation", 8)
		vbox.add_child(form_row)

		var select_btn := Button.new()
		select_btn.text = form_name
		select_btn.custom_minimum_size = Vector2(100, 32)
		select_btn.add_theme_font_size_override("font_size", 13)

		# Color code by size
		var btn_color: Color = Color(0.60, 0.80, 0.60)  # green = small/med
		if size_str == "Large": btn_color = Color(0.85, 0.70, 0.30)
		elif size_str == "Huge": btn_color = Color(0.90, 0.40, 0.40)
		select_btn.add_theme_color_override("font_color", btn_color)

		var captured_form: String = form_name
		var captured_slider: HSlider = sp_slider
		select_btn.pressed.connect(func():
			_confirm_shapeshift(captured_form, int(captured_slider.value))
		)
		form_row.add_child(select_btn)

		var stat_str: String = "%s | STR %d SPD %d VIT %d | %dd%d %s" % [
			size_str, form["str"], form["spd"], form["vit"],
			dice_arr[0], dice_arr[1], weapon_str]
		if special_str != "":
			stat_str += " [%s]" % special_str
		var info := RimvaleUtils.label(stat_str, 11, Color(0.55, 0.55, 0.50))
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		form_row.add_child(info)

func _confirm_shapeshift(form_name: String, sp_invest: int) -> void:
	if _ss_overlay != null and is_instance_valid(_ss_overlay):
		_ss_overlay.queue_free(); _ss_overlay = null

	# Inject form choice + SP into the pending action and execute
	var action: Dictionary = _ss_pending_action.duplicate()
	action["_shapeshift_form"] = form_name
	action["_shapeshift_sp"]   = sp_invest
	var result: Dictionary = _e.dungeon_perform_action(_selected_id, action, "", 0, 0)
	_handle_action_result(result)
	_ss_pending_action = {}

# ── Summon Creature Builder Dialog ───────────────────────────────────────────

func _open_summon_builder_dialog(action: Dictionary) -> void:
	if _sb_overlay != null and is_instance_valid(_sb_overlay):
		_sb_overlay.queue_free(); _sb_overlay = null
	_sb_pending_action = action.duplicate()
	_sb_stats = [0, 0, 0, 0, 0]
	_sb_feats = {}
	_sb_abilities = []
	_sb_name = "Construct"

	var ent: Dictionary = _get_entity(_selected_id)
	if ent.is_empty(): return
	var ch: int = int(ent.get("handle", -1))
	if ch < 0: return
	var char_data: Dictionary = _e._chars.get(ch, {})
	var sp_avail: int = int(ent.get("sp", 0))
	var caster_feats: Dictionary = char_data.get("feats", {})
	var caster_max_tier: int = 1
	for fn in caster_feats:
		caster_max_tier = maxi(caster_max_tier, int(caster_feats[fn]))
	var spell_nm: String = str(action.get("matrix_id", ""))
	var spell_entry: Dictionary = _e._SPELL_DB.get(spell_nm, {})
	var base_cost: int = int(spell_entry.get("sc", 2))
	if spell_nm == "Animate Undead" and base_cost < 3: base_cost = 3

	# Full-screen overlay
	_sb_overlay = Panel.new()
	_sb_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.05, 0.10, 0.96)
	_sb_overlay.add_theme_stylebox_override("panel", bg_style)
	add_child(_sb_overlay)

	var mgn := MarginContainer.new()
	for s in ["left","right","top","bottom"]: mgn.add_theme_constant_override("margin_" + s, 20)
	mgn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sb_overlay.add_child(mgn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mgn.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Header
	var hdr := HBoxContainer.new()
	vbox.add_child(hdr)
	var title_str: String = "Summon Creature Builder" if base_cost == 2 else "Animate Undead Builder"
	hdr.add_child(RimvaleUtils.label(title_str, 18, RimvaleColors.TEXT_WHITE))
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(spacer)
	var close_btn := Button.new(); close_btn.text = "X"; close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", RimvaleColors.DANGER)
	close_btn.pressed.connect(func():
		if is_instance_valid(_sb_overlay): _sb_overlay.queue_free(); _sb_overlay = null
	)
	hdr.add_child(close_btn)

	# SP available + cost display
	_sb_cost_lbl = RimvaleUtils.label(
		"SP available: %d | Base cost: %d | Total: %d" % [sp_avail, base_cost, base_cost],
		12, Color(0.65, 0.80, 0.65))
	vbox.add_child(_sb_cost_lbl)

	# Creature name
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Creature Name"
	name_edit.text = _sb_name
	name_edit.custom_minimum_size = Vector2(0, 30)
	name_edit.add_theme_font_size_override("font_size", 13)
	name_edit.text_changed.connect(func(t: String): _sb_name = t)
	vbox.add_child(name_edit)

	# ── Stats (all start at 0, 1 SP per point) ──
	vbox.add_child(RimvaleUtils.label("Stats (1 SP per point, all start at 0):", 14, RimvaleColors.TEXT_WHITE))
	var stat_names: Array = ["STR", "SPD", "INT", "VIT", "DIV"]
	var stat_lbls: Array = []
	for i in range(5):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vbox.add_child(row)
		row.add_child(RimvaleUtils.label(stat_names[i] + ":", 12, RimvaleColors.TEXT_GRAY))
		var val_lbl := RimvaleUtils.label("0", 13, Color(0.40, 0.85, 1.0))
		val_lbl.custom_minimum_size = Vector2(30, 0)
		stat_lbls.append(val_lbl)
		var minus_btn := Button.new(); minus_btn.text = "-"; minus_btn.flat = true
		minus_btn.custom_minimum_size = Vector2(28, 28)
		minus_btn.add_theme_font_size_override("font_size", 14)
		var plus_btn := Button.new(); plus_btn.text = "+"; plus_btn.flat = true
		plus_btn.custom_minimum_size = Vector2(28, 28)
		plus_btn.add_theme_font_size_override("font_size", 14)
		var ci: int = i
		var captured_lbl: Label = val_lbl
		var captured_sp: int = sp_avail
		var captured_base: int = base_cost
		minus_btn.pressed.connect(func():
			if _sb_stats[ci] > 0:
				_sb_stats[ci] -= 1
				captured_lbl.text = str(_sb_stats[ci])
				_sb_update_cost(captured_sp, captured_base)
		)
		plus_btn.pressed.connect(func():
			_sb_stats[ci] += 1
			captured_lbl.text = str(_sb_stats[ci])
			_sb_update_cost(captured_sp, captured_base)
		)
		row.add_child(minus_btn)
		row.add_child(val_lbl)
		row.add_child(plus_btn)

	# ── Separator ──
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# ── Abilities from monster table ──
	vbox.add_child(RimvaleUtils.label("Abilities (cost = AP + SP of ability):", 14, RimvaleColors.TEXT_WHITE))
	var catalog: Array = _e.get_summon_ability_catalog()
	for ab in catalog:
		if int(ab.get("_tier", 1)) > caster_max_tier: continue
		var ab_name: String = str(ab.get("name", "?"))
		var ab_cost: int = int(ab.get("_sp_cost", 1))
		var ab_tier: int = int(ab.get("_tier", 1))
		var dice: Array = ab.get("dice", [1,6])
		var ab_row := HBoxContainer.new()
		ab_row.add_theme_constant_override("separation", 6)
		vbox.add_child(ab_row)
		var ab_check := CheckBox.new()
		ab_check.text = "%s (T%d, %d SP) — %dd%d" % [ab_name, ab_tier, ab_cost, int(dice[0]), int(dice[1])]
		ab_check.add_theme_font_size_override("font_size", 11)
		var captured_ab: String = ab_name
		var cap_sp: int = sp_avail
		var cap_base: int = base_cost
		ab_check.toggled.connect(func(on: bool):
			if on and captured_ab not in _sb_abilities:
				_sb_abilities.append(captured_ab)
			elif not on and captured_ab in _sb_abilities:
				_sb_abilities.erase(captured_ab)
			_sb_update_cost(cap_sp, cap_base)
		)
		ab_row.add_child(ab_check)

	# ── Separator ──
	vbox.add_child(HSeparator.new())

	# ── Summon button ──
	var summon_btn := Button.new()
	summon_btn.text = "✦ SUMMON"
	summon_btn.custom_minimum_size = Vector2(0, 40)
	summon_btn.add_theme_font_size_override("font_size", 16)
	summon_btn.add_theme_color_override("font_color", Color(0.30, 1.0, 0.40))
	summon_btn.pressed.connect(_confirm_summon_build)
	vbox.add_child(summon_btn)

func _sb_update_cost(sp_avail: int, base_cost: int) -> void:
	var stat_total: int = 0
	for st in _sb_stats: stat_total += st
	var ability_cost: int = 0
	for ab_name in _sb_abilities:
		ability_cost += _e._summon_ability_sp_cost(ab_name)
	var total: int = base_cost + stat_total + ability_cost
	var color: Color = Color(0.65, 0.80, 0.65) if total <= sp_avail else Color(1.0, 0.40, 0.30)
	if _sb_cost_lbl != null and is_instance_valid(_sb_cost_lbl):
		_sb_cost_lbl.text = "SP available: %d | Base: %d + Stats: %d + Abilities: %d = Total: %d SP" % [
			sp_avail, base_cost, stat_total, ability_cost, total]
		_sb_cost_lbl.add_theme_color_override("font_color", color)

func _confirm_summon_build() -> void:
	if _sb_overlay != null and is_instance_valid(_sb_overlay):
		_sb_overlay.queue_free(); _sb_overlay = null

	var action: Dictionary = _sb_pending_action.duplicate()
	action["_summon_build"] = {
		"stats": _sb_stats.duplicate(),
		"feats": _sb_feats.duplicate(),
		"abilities": _sb_abilities.duplicate(),
		"creature_name": _sb_name,
	}
	var result: Dictionary = _e.dungeon_perform_action(_selected_id, action, "", 0, 0)
	_handle_action_result(result)
	_sb_pending_action = {}

# ── Create Construct Builder Dialog ──────────────────────────────────────────

## Construct cost constants
const CB_WEAPON_LABELS: PackedStringArray = ["None", "Light Weapon (2 SP)", "Martial Weapon (3 SP)", "Heavy Weapon (4 SP)"]
const CB_WEAPON_COSTS: PackedInt32Array   = [0, 2, 3, 4]
const CB_WEAPON_NAMES: PackedStringArray  = ["", "Construct Light Weapon", "Construct Martial Weapon", "Construct Heavy Weapon"]
const CB_ARMOR_LABELS: PackedStringArray  = ["None", "Light Armor (2 SP)", "Medium Armor (3 SP)", "Heavy Armor (4 SP)"]
const CB_ARMOR_COSTS: PackedInt32Array    = [0, 2, 3, 4]
const CB_ARMOR_NAMES: PackedStringArray   = ["", "Construct Light Armor", "Construct Medium Armor", "Construct Heavy Armor"]
const CB_SHIELD_LABELS: PackedStringArray = ["None", "Shield (1 SP)", "Tower Shield (2 SP)"]
const CB_SHIELD_COSTS: PackedInt32Array   = [0, 1, 2]
const CB_SHIELD_NAMES: PackedStringArray  = ["", "Construct Shield", "Construct Tower Shield"]

func _cb_calc_cost(base_cost: int) -> Dictionary:
	if _cb_mode == 1:  # Structure
		var struct_sp: int = int(pow(2.0, float(_cb_struct_tier)))  # tier1=2, tier2=4, tier3=8, tier4=16
		return {"total": base_cost + struct_sp, "struct": struct_sp, "equip": 0, "trr": 0, "discount": 0, "item_count": 0}
	# Equipment mode
	var w_cost: int = CB_WEAPON_COSTS[_cb_weapon_idx]
	var a_cost: int = CB_ARMOR_COSTS[_cb_armor_idx]
	var s_cost: int = CB_SHIELD_COSTS[_cb_shield_idx]
	var trr_cost: int = _cb_trr
	var equip_raw: int = w_cost + a_cost + s_cost + trr_cost
	# Count items in set (weapons, armor, shields — TRR doesn't count as separate item)
	var item_count: int = 0
	if _cb_weapon_idx > 0: item_count += 1
	if _cb_armor_idx > 0: item_count += 1
	if _cb_shield_idx > 0: item_count += 1
	# Set discount: -1 per item, up to -3 (only if multiple items)
	var discount: int = 0
	if item_count >= 2: discount = mini(item_count, 3)
	var equip_final: int = maxi(1, equip_raw - discount)
	return {"total": base_cost + equip_final, "struct": 0, "equip": equip_raw, "trr": trr_cost, "discount": discount, "item_count": item_count}

func _open_construct_builder_dialog(action: Dictionary) -> void:
	if _cb_overlay != null and is_instance_valid(_cb_overlay):
		_cb_overlay.queue_free(); _cb_overlay = null
	_cb_pending_action = action.duplicate()
	_cb_mode = 0; _cb_weapon_idx = 0; _cb_armor_idx = 0
	_cb_shield_idx = 0; _cb_trr = 0; _cb_struct_tier = 1

	var ent: Dictionary = _get_entity(_selected_id)
	if ent.is_empty(): return
	var sp_avail: int = int(ent.get("sp", 0))
	var spell_nm: String = str(action.get("matrix_id", ""))
	var spell_entry: Dictionary = _e._SPELL_DB.get(spell_nm, {})
	var base_cost: int = int(spell_entry.get("sc", 2))

	# Full-screen overlay
	_cb_overlay = Panel.new()
	_cb_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.05, 0.10, 0.96)
	_cb_overlay.add_theme_stylebox_override("panel", bg_style)
	add_child(_cb_overlay)

	var mgn := MarginContainer.new()
	for s in ["left","right","top","bottom"]: mgn.add_theme_constant_override("margin_" + s, 20)
	mgn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cb_overlay.add_child(mgn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mgn.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Header
	var hdr := HBoxContainer.new()
	vbox.add_child(hdr)
	hdr.add_child(RimvaleUtils.label("Create Construct", 18, RimvaleColors.TEXT_WHITE))
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(spacer)
	var close_btn := Button.new(); close_btn.text = "X"; close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", RimvaleColors.DANGER)
	close_btn.pressed.connect(func():
		if is_instance_valid(_cb_overlay): _cb_overlay.queue_free(); _cb_overlay = null
	)
	hdr.add_child(close_btn)

	# SP + cost display
	_cb_cost_lbl = RimvaleUtils.label("", 12, Color(0.65, 0.80, 0.65))
	vbox.add_child(_cb_cost_lbl)

	# Stats preview (HP / AC / DT)
	_cb_stats_lbl = RimvaleUtils.label("", 11, Color(0.55, 0.70, 0.85))
	vbox.add_child(_cb_stats_lbl)

	vbox.add_child(HSeparator.new())

	# ── Mode selector: Equipment vs Structure ──
	vbox.add_child(RimvaleUtils.label("Construct Type", 14, RimvaleColors.TEXT_WHITE))
	var mode_opt := OptionButton.new()
	mode_opt.add_item("Equipment Set (weapons, armor, shields, clothing)")
	mode_opt.add_item("Structure (walls, barriers, platforms)")
	mode_opt.selected = _cb_mode
	mode_opt.add_theme_font_size_override("font_size", 12)
	var cap_sp: int = sp_avail
	var cap_base: int = base_cost
	mode_opt.item_selected.connect(func(i: int): _cb_mode = i; _rebuild_construct_builder())
	vbox.add_child(mode_opt)

	vbox.add_child(HSeparator.new())

	if _cb_mode == 0:
		# ── Equipment mode ──
		vbox.add_child(RimvaleUtils.label("Equipment", 14, Color(0.50, 0.70, 1.0)))

		# Weapon
		var w_opt := OptionButton.new()
		for wl in CB_WEAPON_LABELS: w_opt.add_item(wl)
		w_opt.selected = _cb_weapon_idx
		w_opt.add_theme_font_size_override("font_size", 12)
		w_opt.item_selected.connect(func(i: int): _cb_weapon_idx = i; _cb_update_cost(cap_sp, cap_base))
		vbox.add_child(_cb_row("Weapon", w_opt))

		# Armor
		var a_opt := OptionButton.new()
		for al in CB_ARMOR_LABELS: a_opt.add_item(al)
		a_opt.selected = _cb_armor_idx
		a_opt.add_theme_font_size_override("font_size", 12)
		a_opt.item_selected.connect(func(i: int): _cb_armor_idx = i; _cb_update_cost(cap_sp, cap_base))
		vbox.add_child(_cb_row("Armor", a_opt))

		# Shield
		var s_opt := OptionButton.new()
		for sl in CB_SHIELD_LABELS: s_opt.add_item(sl)
		s_opt.selected = _cb_shield_idx
		s_opt.add_theme_font_size_override("font_size", 12)
		s_opt.item_selected.connect(func(i: int): _cb_shield_idx = i; _cb_update_cost(cap_sp, cap_base))
		vbox.add_child(_cb_row("Shield", s_opt))

		vbox.add_child(HSeparator.new())

		# TRR clothing
		vbox.add_child(RimvaleUtils.label("TRR Clothing / Armor Coating (1 SP per rating)", 12, Color(0.55, 0.70, 0.60)))
		var trr_lbl := RimvaleUtils.label("TRR: +%d" % _cb_trr, 13, Color(0.40, 0.85, 1.0))
		var trr_row := HBoxContainer.new()
		trr_row.add_theme_constant_override("separation", 6)
		vbox.add_child(trr_row)
		var trr_minus := Button.new(); trr_minus.text = "-"; trr_minus.flat = true
		trr_minus.custom_minimum_size = Vector2(28, 28)
		trr_minus.add_theme_font_size_override("font_size", 14)
		var trr_plus := Button.new(); trr_plus.text = "+"; trr_plus.flat = true
		trr_plus.custom_minimum_size = Vector2(28, 28)
		trr_plus.add_theme_font_size_override("font_size", 14)
		var cap_trr_lbl: Label = trr_lbl
		trr_minus.pressed.connect(func():
			if _cb_trr > 0: _cb_trr -= 1; cap_trr_lbl.text = "TRR: +%d" % _cb_trr; _cb_update_cost(cap_sp, cap_base))
		trr_plus.pressed.connect(func():
			_cb_trr += 1; cap_trr_lbl.text = "TRR: +%d" % _cb_trr; _cb_update_cost(cap_sp, cap_base))
		trr_row.add_child(trr_minus)
		trr_row.add_child(trr_lbl)
		trr_row.add_child(trr_plus)

		# Set discount info
		vbox.add_child(RimvaleUtils.label("Set Discount: -1 SP per item in set (up to -3)", 10, Color(0.50, 0.55, 0.45)))

	else:
		# ── Structure mode ──
		vbox.add_child(RimvaleUtils.label("Structure Size", 14, Color(0.50, 0.70, 1.0)))

		var tier_labels: Array = [
			"5x5x5 ft (1 tile) — 2 SP",
			"10x10x10 ft (2 tiles) — 4 SP",
			"15x15x15 ft (3 tiles) — 8 SP",
			"20x20x20 ft (4 tiles) — 16 SP",
			"25x25x25 ft (5 tiles) — 32 SP",
		]
		var tier_opt := OptionButton.new()
		for tl in tier_labels: tier_opt.add_item(tl)
		tier_opt.selected = _cb_struct_tier - 1
		tier_opt.add_theme_font_size_override("font_size", 12)
		tier_opt.item_selected.connect(func(i: int): _cb_struct_tier = i + 1; _cb_update_cost(cap_sp, cap_base))
		vbox.add_child(tier_opt)

		vbox.add_child(RimvaleUtils.label(
			"Not all sides must be max length. Shape it however you want within the size limit. "
			+ "The construct is semi-transparent with a glowing outline. It can be attacked and destroyed.",
			10, Color(0.50, 0.55, 0.45)))

	vbox.add_child(HSeparator.new())

	# ── Create button ──
	var create_btn := Button.new()
	create_btn.text = "CREATE CONSTRUCT"
	create_btn.custom_minimum_size = Vector2(0, 40)
	create_btn.add_theme_font_size_override("font_size", 16)
	create_btn.add_theme_color_override("font_color", Color(0.40, 0.70, 1.0))
	create_btn.pressed.connect(_confirm_construct_build)
	vbox.add_child(create_btn)

	_cb_update_cost(sp_avail, base_cost)

func _cb_row(label_text: String, ctrl: Control) -> HBoxContainer:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8)
	var lbl := RimvaleUtils.label(label_text, 12, RimvaleColors.TEXT_GRAY)
	lbl.custom_minimum_size = Vector2(80, 0)
	row.add_child(lbl)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ctrl)
	return row

func _cb_update_cost(sp_avail: int, base_cost: int) -> void:
	var info: Dictionary = _cb_calc_cost(base_cost)
	var total: int = int(info["total"])
	var color: Color = Color(0.65, 0.80, 0.65) if total <= sp_avail else Color(1.0, 0.40, 0.30)
	if _cb_cost_lbl != null and is_instance_valid(_cb_cost_lbl):
		if _cb_mode == 0:
			var disc_str: String = ""
			if int(info["discount"]) > 0: disc_str = " - Set Discount: %d" % int(info["discount"])
			_cb_cost_lbl.text = "SP available: %d | Equipment: %d + TRR: %d%s = Total: %d SP" % [
				sp_avail, int(info["equip"]) - int(info["trr"]), int(info["trr"]), disc_str, total]
		else:
			_cb_cost_lbl.text = "SP available: %d | Structure: %d = Total: %d SP" % [sp_avail, int(info["struct"]), total]
		_cb_cost_lbl.add_theme_color_override("font_color", color)
	if _cb_stats_lbl != null and is_instance_valid(_cb_stats_lbl):
		var construct_sp: int = total - base_cost
		var hp: int = construct_sp * 3
		var ac: int = 10 + mini(construct_sp, 10)
		var dt: int = mini(construct_sp, 10)
		_cb_stats_lbl.text = "Construct Stats — HP: %d | AC: %d | Damage Threshold: %d" % [hp, ac, dt]

func _rebuild_construct_builder() -> void:
	if is_instance_valid(_cb_overlay):
		_cb_overlay.queue_free(); _cb_overlay = null
	_open_construct_builder_dialog(_cb_pending_action)

func _confirm_construct_build() -> void:
	if _cb_overlay != null and is_instance_valid(_cb_overlay):
		_cb_overlay.queue_free(); _cb_overlay = null

	var build: Dictionary = {
		"mode": "equipment" if _cb_mode == 0 else "structure",
	}
	if _cb_mode == 0:
		build["weapon_idx"] = _cb_weapon_idx
		build["armor_idx"] = _cb_armor_idx
		build["shield_idx"] = _cb_shield_idx
		build["trr"] = _cb_trr
	else:
		build["struct_tier"] = _cb_struct_tier

	var action: Dictionary = _cb_pending_action.duplicate()
	action["_construct_build"] = build
	var result: Dictionary = _e.dungeon_perform_action(_selected_id, action, "", 0, 0)
	_handle_action_result(result)
	_cb_pending_action = {}
