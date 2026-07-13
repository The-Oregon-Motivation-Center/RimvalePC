extends Node
## BattleSystem — rules engine for "Battle Mode", a REAL-TIME strategy
## skirmish layer (Command & Conquer flavour) built directly on top of the
## existing dungeon-crawl engine. The sim runs at a fixed 10 Hz inside
## _process; the renderer listens to `sim_event` and drains
## battle_log_extra.
##
## Concept:
##   * Up to 10 teams, each with a Command Post (base), fight on a 50×50
##     crawl map until only one team has living entities.
##   * Bases produce units from a region-flavoured catalog; production is
##     paid for with "supply", earned per round from bases and from units
##     mining resource nodes.
##   * Team 0 is always the human player. All other teams are AI-driven
##     inside advance_battle_phase().
##
## This autoload only mutates engine state through the GDScript fallback
## engine (RimvaleAPI.engine). It reaches into the engine's private members
## deliberately: _e.get_dungeon_entities() returns a DEEP COPY, so every
## mutation here goes through the live `_dungeon_entities` array instead.

## Real-time simulation event stream for the battle renderer. Kinds:
##   "attack"    {attacker, target, text}
##   "spell"     {caster, spell, target, text}
##   "death"     {id, name, team}
##   "spawn"     {id, name, team}
##   "structure" {team, kind}
##   "income"    {team, amount}
##   "elim"      {team}
##   "over"      {winner}          (winner == -1 → draw)
signal sim_event(kind: String, data: Dictionary)

# ──────────────────────────────────────────────────────────────────────────
# Constants
# ──────────────────────────────────────────────────────────────────────────

## Scene the setup UI should switch to once start_battle() has run.
const BATTLE_SCENE := "res://scenes/battle/battle_rts.tscn"

## Fixed real-time simulation tick (seconds) — the sim steps at 10 Hz.
const SIM_TICK := 0.1

## Seconds between income ticks / condition ticks / per-team AI thinks.
const INCOME_PERIOD := 5.0
const CONDITION_PERIOD := 3.0
const AI_THINK_PERIOD := 2.0

## Sudden death: warning at 12 minutes of battle time, forced result at 15
## (team with the most total unit HP wins).
const SUDDEN_DEATH_WARN_TIME := 720.0
const SUDDEN_DEATH_TIME := 900.0

## Production queue length cap per team.
const MAX_QUEUE := 5

## Curated combat-spell whitelist — every name verified against the
## engine's _SPELL_DB. SP cost doubles as the cast cooldown in SECONDS.
const BATTLE_SPELLS := [
	"Littlest Healing", "Healing Touch", "Healing Light", "Chain Mend",
	"Aura of Restoration", "Health Regeneration",
	"Frost Lance", "Searing Ray", "Fireburst", "Lightning Bolt",
	"Chain Lightning", "Littlest Combustion", "Fireball",
	"Arcane Force Field", "Stoneskin", "Bless: Dodging", "Bless: Resistant",
	"Curse: Bleed", "Curse: Slowed", "Curse: Stunned", "Curse: Frightened",
	"Curse: Vulnerable", "Mind Control",
]

## Supply every team starts with.
const START_SUPPLY := 100

## Supply earned per living base per round.
const BASE_INCOME := 10

## Supply earned per unit standing on / adjacent (Chebyshev <= 1) to an
## unlooted resource node, per round.
const MINE_INCOME := 15

## Seconds until a depleted resource node refills.
const REPLENISH_TIME := 180.0

## How far (Manhattan) AI units can "see" when hunting targets.
const SIGHT_RANGE := 18

## Cap on how many distinct lineages feed the unit catalog per battle.
const MAX_LINEAGE_UNITS := 8

## Command Post baseline stats.
const BASE_HP := 120
const BASE_AC := 14

## Per-region battle configuration:
##   name          → display name shown in the setup UI / encounter title
##   terrain_style → engine terrain style int (0..7), picked thematically
##   subregions    → SUBREGION display names whose lineages seed the catalog
##                   (get_lineages_for_region is keyed by subregion name)
const REGION_CONFIG := {
	"plains": {
		"name": "The Plains",
		"terrain_style": 1,
		"subregions": ["The Plains", "Forest of SubEden", "Kingdom of Qunorum", "Wilds of Endero"],
	},
	"peaks": {
		"name": "Peaks of Isolation",
		"terrain_style": 0,
		"subregions": ["Peaks of Isolation", "Pharaoh's Den", "The Darkness", "Argent Hall"],
	},
	"shadows": {
		"name": "Shadows Beneath",
		"terrain_style": 7,
		"subregions": ["Shadows Beneath", "Corrupted Marshes", "Crypt at End of Valley", "Spindle York's Schism"],
	},
	"glass": {
		"name": "Glass Passage",
		"terrain_style": 6,
		"subregions": ["Glass Passage", "Sacral Separation", "Infernal Machine"],
	},
	"isles": {
		"name": "The Isles",
		"terrain_style": 5,
		"subregions": ["Gloamfen Hollow", "The Isles", "Depths of Denorim", "Moroboros"],
	},
	"metro": {
		"name": "Metropolitan",
		"terrain_style": 3,
		"subregions": ["Metropolitan", "Upper Forty", "Lower Forty"],
	},
	"astral": {
		"name": "Astral Tear",
		"terrain_style": 6,
		"subregions": ["Astral Tear", "L.I.T.O.", "West End Gullet", "Cradling Depths"],
	},
	"terminus": {
		"name": "Terminus Volarus",
		"terrain_style": 7,
		"subregions": ["Terminus Volarus", "City of Eternal Light", "Land of Tomorrow", "Hallowed Sacrament"],
	},
	"titans": {
		"name": "Titan's Lament",
		"terrain_style": 4,
		"subregions": ["Titan's Lament", "Vulcan Valley", "Mortal Arena"],
	},
	"sublimini": {
		"name": "Sublimini Dominus",
		"terrain_style": 7,
		"subregions": ["Sublimini Dominus", "Beating Heart of The Void"],
	},
}

## Fixed (non-lineage) catalog rows: [key, label, cost, tier]
const FIXED_CATALOG := [
	["mob",       "Mob Rabble",         15,  "Mob"],
	["militia",   "Militia Squad (3)",  45,  "Militia"],
	["engineer",  "Engineer",           60,  "Support"],
	["monster",   "Monster",            60,  "Monster"],
	["adversary", "Adversary Champion", 80,  "Adversary"],
	["apex",      "Apex Monster",       250, "Apex"],
	["kaiju",     "KAIJU",              600, "Kaiju"],
]

## Vehicle catalog rows: [key, label, cost] — unlocked by a War Factory.
## Keys route to VehicleData.get_stats() via _build_vehicle_unit.
const VEHICLE_CATALOG := [
	["vehicle:Arcane Motorcycle", "Ram Cycle",  90],
	["vehicle:Arcane Quad",       "Scout Quad", 120],
	["vehicle:Arcane Rover",      "Rover APC",  180],
	["vehicle:Arcane Juggernaut", "Juggernaut", 400],
	["vehicle:Arcane Copter",     "Gunship",    160],
]

## Buildable structures: kind → {cost, hp, label}.
const STRUCTURE_KINDS := {
	"barracks":     {"cost": 100, "hp": 80,  "label": "Barracks"},
	"war_factory":  {"cost": 150, "hp": 100, "label": "War Factory"},
	"command_post": {"cost": 150, "hp": 120, "label": "Command Post"},
	"spire":        {"cost": 120, "hp": 90,  "label": "Arcane Spire"},
	"turret":       {"cost": 80,  "hp": 70,  "label": "Guard Turret"},
	"wall":         {"cost": 15,  "hp": 80,  "label": "Wall"},
}

## Hand-placed wall segments per team.
const MAX_WALLS := 24

## AI team personalities (rolled per battle; flavor + behavior):
##   rusher  — fast cheap waves;  turtler — slow waves, loves turrets;
##   boomer  — greedy economy, then expensive armies.
const AI_PERSONAS := ["rusher", "turtler", "boomer"]

## Guard Turrets per team (defense shouldn't replace an army).
const MAX_TURRETS := 4

## Superweapon strike: per-team cooldown, area dice damage (6d10, radius 2).
const STRIKE_CD := 90.0
const STRIKE_RADIUS := 2

## Kills needed for veterancy ranks ★ / ★★ (+25 HP, +1 to-hit each).
const VET_KILLS_1 := 3
const VET_KILLS_2 := 7

## The mind-control spell name (Yuri rules: thrall serves while you live).
const MC_SPELL := "Mind Control"

## Neutral "team" for wild monsters / derelict structures: out of range of
## every real team slot, so everything treats it as hostile, and all the
## per-team bookkeeping (team_alive, supply, elimination) safely skips it.
const NEUTRAL_TEAM := 99

## Wild kaiju event: spawn time (s), and the supply bounty for the kill.
const KAIJU_EVENT_TIME := 480.0
const KAIJU_BOUNTY := 300

## Supply crates: spawn cadence range (s) and cap on crates alive at once.
const CRATE_MIN_PERIOD := 45.0
const CRATE_MAX_PERIOD := 80.0
const MAX_CRATES := 3

## Derelict tech buildings (engineer-capturable, passive perks).
const TECH_LABELS := {
	"tech_shrine": "Derelict Shrine",     # heals owner's units nearby
	"tech_watch":  "Old Watchtower",      # huge sight radius (fog)
	"tech_mint":   "Abandoned Mint",      # +8⛃ per income tick
}

## Region personality: each battlefield has its own hazard.
##   blizzard — periodic storm pulse: units in the zone are `slowed`
##   lava     — vents erupt for 3d10 area damage (any team)
##   rift     — two 🌀 tiles; step beside one, emerge at the other
##   spores   — drifting clouds inflict `fever` (attack disadvantage)
##   gloom    — creeping darkness pulses `frightened` on a random spot
const REGION_EFFECTS := {
	"peaks":     "blizzard",
	"titans":    "lava",
	"astral":    "rift",
	"sublimini": "rift",
	"isles":     "spores",
	"shadows":   "gloom",
	# plains / glass / metro / terminus stay vanilla — clean baselines.
}

## Armory weapon ladder (keyword-parsed damage: 1d4+1 → 1d8+2 → 2d6+2).
const WEAPON_TIERS := ["Rusty Dagger", "Longsword", "Greatsword"]

## Armory armor ladder: [name, ac] per tier.
const ARMOR_TIERS := [["Leather", 11], ["Chain Mail", 16], ["Plate", 18]]

## Sudden-death round cap: past this, the biggest army wins.
const MAX_ROUNDS := 60

## Battle-field size in tiles. Larger than the shared story-crawl map (50) for
## more maneuvering room. Applied per battle by resizing the engine's map arrays
## right after the crawl boot — the story crawl's MAP_SIZE_CRAWL is untouched.
const BATTLE_MAP_SIZE := 75

## One fixed color per team slot (player team 0 is always blue).
const TEAM_COLORS := [
	Color(0.20, 0.55, 0.95), Color(0.90, 0.25, 0.20), Color(0.25, 0.80, 0.30),
	Color(0.95, 0.85, 0.25), Color(0.95, 0.55, 0.15), Color(0.65, 0.30, 0.85),
	Color(0.25, 0.85, 0.85), Color(0.90, 0.40, 0.75), Color(0.60, 0.80, 0.20),
	Color(0.90, 0.90, 0.90),
]

# ──────────────────────────────────────────────────────────────────────────
# Battle state
# ──────────────────────────────────────────────────────────────────────────

var active: bool = false             # true while a battle is running
var region_id: String = ""           # key into REGION_CONFIG
var num_teams: int = 4               # 2..10
var unit_level: int = 3              # baseline production level
var supply: Array = []               # supply[team] -> int
var team_alive: Array = []           # bool per team
var player_team: int = 0             # human team index (always 0)
var round_num: int = 1               # mirrors _e._dungeon_round
var battle_log_extra: Array = []     # extra log lines the scene can drain
var squads: Dictionary = {}          # squad id (1..4) -> Array of unit ids

## ── Real-time clock state ────────────────────────────────────────────────
var paused: bool = false             # renderer pause toggle
var time_scale: float = 1.0          # renderer sets 1.0 or 2.0
var finished: bool = false           # sim stopped; active stays true for UI
var winner: int = -1                 # winning team once finished (-1 draw)
var sandbox: bool = false            # post-victory free play: sim runs on,
                                     # outcome checks stay silenced

## Fog of war (renderer-side shroud; set by the battle setup screen).
var fog_enabled: bool = true

## Region-personality state (see REGION_EFFECTS).
var region_effect: String = ""       # active hazard type this battle
var rift_a: Vector2i = Vector2i(-1, -1)   # 🌀 teleport pair (rift regions)
var rift_b: Vector2i = Vector2i(-1, -1)
var _region_fx_timer: float = 30.0   # seconds until the next hazard pulse

## Living-map state: wild kaiju event + supply crates.
var _kaiju_spawned: bool = false
var _crate_timer: float = 60.0
var _crates: Array = []              # live crate entity ids

## Battle statistics (score screen). Arrays are per-team.
var _team_kills: Array = []
var _supply_mined: Array = []
var _units_built: Array = []
var _units_lost: Array = []
var _captures: Array = []
var _biggest_blast: Dictionary = {}  # {dmg, spell, team}
var _mvp: Dictionary = {}            # {name, kills, team}
var _last_heroes: Array = []         # for Rematch

## AI difficulty (set by battle setup):
##   easy   — lazy foes: guard home turf, no offensives, slow production
##   medium — periodic raiding parties, never the whole army
##   hard   — focused full-army waves aimed at the weakest team
var difficulty: String = "medium"
var _wave_timers: Array = []         # per-team seconds until next offensive
var _strike_cd: Array = []           # per-team superweapon cooldown (s)
var _ai_personas: Array = []         # per-team persona string ("" = player)
var _persona_revealed: Array = []    # taunted at least once

## Map resource abundance (set by battle setup):
##   low    — 1 home node/team, 2 center; lean veins
##   medium — 2 home, 4 center (classic)
##   high   — 3 home, 6 center; rich veins
##   insane — 4 home, 8 center + 8 wild nodes; the map drips supply
var resources: String = "medium"

## Node counts + vein reserves per abundance setting.
const RESOURCE_CFG := {
	"low":    {"home": 1, "center": 2, "wild": 0, "amt_lo": 160, "amt_hi": 240},
	"medium": {"home": 2, "center": 4, "wild": 0, "amt_lo": 240, "amt_hi": 360},
	"high":   {"home": 3, "center": 6, "wild": 0, "amt_lo": 300, "amt_hi": 450},
	"insane": {"home": 4, "center": 8, "wild": 8, "amt_lo": 500, "amt_hi": 800},
}

## The active abundance row.
func _res_cfg() -> Dictionary:
	return RESOURCE_CFG.get(resources, RESOURCE_CFG["medium"])

var _region_lineages: Array = []     # lineage names available this battle
var _unit_counter: int = 0           # monotonic counter for unique unit ids
var _last_income: Array = []         # supply earned last income tick, per team
var _sudden_death_warned: bool = false  # 12-minute warning fired once
var _eng = null                      # cached engine reference
var _warned_no_engine: bool = false  # so the guard warning fires only once

var _battle_time: float = 0.0        # simulated seconds since start_battle
var _sim_accum: float = 0.0          # _process time accumulator

## ── Per-step lookup structures (rebuilt each 0.1 s sim step) ─────────────
## These turn the per-unit O(n) scans (find-by-id, who's-on-this-tile) into
## O(1) lookups so 150+ units stay cheap: O(n) once per step, not O(n²).
var _ent_index: Dictionary = {}      # id → live entity Dictionary
var _occ: Dictionary = {}            # tile key (y*ms+x) → occupant id
var _occ_ms: int = 50                # MAP_SIZE snapshot used for _occ keys
var _paths_this_step: int = 0        # A* calls spent this sim step
const PATH_BUDGET := 8               # max pathfinds per step (≈80/s)

## Hard ceiling on one team's living mobile units. Keeps 10-team battles
## inside the renderer/sim envelope (and armies readable).
const MAX_TEAM_UNITS := 40

## Story heroes that may join the player team (bonus units: exempt from the
## army cap and never producible).
const MAX_HEROES := 3

## Corpses linger this long before being removed from the entity roster
## (long enough for the renderer's death fade; keeps scans from dragging).
const CORPSE_TIME := 10.0
var _income_timer: float = INCOME_PERIOD
var _cond_timer: float = CONDITION_PERIOD
var _ai_next_think: Array = []       # per-team battle_time of next AI think
var _build_queue: Array = []         # per-team Array of {key,name,t_left,total}
var _rally: Array = []               # per-team rally point (Vector2i)

# ──────────────────────────────────────────────────────────────────────────
# Engine access
# ──────────────────────────────────────────────────────────────────────────

## Lazily resolve the GDScript fallback engine and verify we can reach its
## internals. Returns null (after a one-shot warning) when running against
## an engine build that hides its members (e.g. the compiled C++ engine),
## so every public function degrades safely instead of crashing.
func _engine():
	if _eng == null:
		_eng = RimvaleAPI.engine
	if _eng == null or not ("_dungeon_entities" in _eng):
		if not _warned_no_engine:
			push_warning("BattleSystem: engine internals unavailable — Battle Mode disabled.")
			_warned_no_engine = true
		return null
	return _eng

# ──────────────────────────────────────────────────────────────────────────
# Real-time clock
# ──────────────────────────────────────────────────────────────────────────

## Fixed-step driver: accumulate scaled frame time and run the sim at a
## steady 10 Hz. The accumulator is capped so a long frame (window drag,
## debugger pause) can't spiral into a catch-up death loop.
func _process(delta: float) -> void:
	if not active or paused or finished:
		return
	_sim_accum += delta * time_scale
	if _sim_accum > 0.5:
		_sim_accum = 0.5
	while _sim_accum >= SIM_TICK:
		_sim_accum -= SIM_TICK
		_sim_step(SIM_TICK)
		if finished or not active:
			break

## Seconds of simulated battle time elapsed since start_battle.
func get_battle_time() -> float:
	return _battle_time

# ──────────────────────────────────────────────────────────────────────────
# Setup-UI helpers
# ──────────────────────────────────────────────────────────────────────────

## All region ids the setup UI can offer.
func get_region_ids() -> Array:
	return REGION_CONFIG.keys()

## Display name for a region id (falls back to the raw id).
func get_region_display(rid) -> String:
	var key: String = str(rid)
	if REGION_CONFIG.has(key):
		return str(REGION_CONFIG[key]["name"])
	return key

## True while the player still owns a living Command Post.
func player_has_base() -> bool:
	return _find_team_base(player_team) != null

## Fixed display color for a team slot (clamped, so any int is safe).
func get_team_color(team: int) -> Color:
	return TEAM_COLORS[clampi(team, 0, TEAM_COLORS.size() - 1)]

# ──────────────────────────────────────────────────────────────────────────
# Unit catalog
# ──────────────────────────────────────────────────────────────────────────

## Production options for a team: one entry per region lineage plus the
## fixed roster, plus vehicles once the team owns a War Factory. Every
## entry is {key, label, cost, tier}.
func get_unit_catalog(team: int) -> Array:
	var cat: Array = []
	# Region-flavoured lineage troops (gathered at start_battle).
	for lin in _region_lineages:
		cat.append({
			"key":   "lineage:%s" % str(lin),
			"label": str(lin),
			"cost":  30,
			"tier":  "Lineage",
		})
	# Fixed roster shared by every region.
	for row in FIXED_CATALOG:
		cat.append({
			"key":   str(row[0]),
			"label": str(row[1]),
			"cost":  int(row[2]),
			"tier":  str(row[3]),
		})
	# War Factory unlocks the vehicle pool for this team only.
	if _team_has_structure(team, "war_factory"):
		for row in VEHICLE_CATALOG:
			cat.append({
				"key":   str(row[0]),
				"label": str(row[1]),
				"cost":  int(row[2]),
				"tier":  "Vehicle",
			})
	return cat

# ──────────────────────────────────────────────────────────────────────────
# Battle lifecycle
# ──────────────────────────────────────────────────────────────────────────

## Boot a battle: build the map, place bases / starter armies / resource
## nodes, and hand control to the player phase.
func start_battle(p_region_id: String, p_num_teams: int, p_unit_level: int = 3,
		p_difficulty: String = "medium", p_resources: String = "medium",
		p_heroes: Array = []) -> void:
	var e = _engine()
	if e == null:
		return

	# 1. Core state. Team 0 is always the human player.
	region_id = p_region_id if REGION_CONFIG.has(p_region_id) else "plains"
	num_teams = clampi(p_num_teams, 2, 10)
	unit_level = maxi(1, p_unit_level)
	difficulty = p_difficulty if p_difficulty in ["easy", "medium", "hard"] else "medium"
	resources = p_resources if RESOURCE_CFG.has(p_resources) else "medium"
	player_team = 0
	round_num = 1
	battle_log_extra = []
	_unit_counter = 0
	_last_income = []
	_sudden_death_warned = false
	squads = {}
	# Real-time clock state.
	paused = false
	time_scale = 1.0
	finished = false
	winner = -1
	sandbox = false
	_battle_time = 0.0
	_sim_accum = 0.0
	_income_timer = INCOME_PERIOD
	_cond_timer = CONDITION_PERIOD
	_build_queue = []
	_rally = []
	_ai_next_think = []
	_wave_timers = []
	_strike_cd = []
	for i in range(num_teams):
		_build_queue.append([])
		_rally.append(Vector2i.ZERO)
		# Staggered AI thinks so ten teams never think on the same tick.
		_ai_next_think.append(1.0 + float(i) * 0.23)
		# First offensive: medium raids after ~45-75 s, hard pushes sooner.
		_wave_timers.append(randf_range(30.0, 60.0) if difficulty == "hard"
				else randf_range(45.0, 75.0))
		# First superweapon strike charges in 60 s, then every STRIKE_CD.
		_strike_cd.append(60.0)
	# Every AI team rolls a personality (player slot stays blank).
	_ai_personas = []
	_persona_revealed = []
	for i in range(num_teams):
		_ai_personas.append("" if i == player_team
				else str(AI_PERSONAS[randi() % AI_PERSONAS.size()]))
		_persona_revealed.append(false)
	var cfg: Dictionary = REGION_CONFIG[region_id]

	# 2. Deterministic map per region — same region id, same battlefield.
	seed(hash(region_id) & 0x7fffffff)

	# 3. Spin up a 50×50 crawl map with no player handles (safe: the engine
	#    tolerates an empty roster and still generates terrain + spawns).
	e.start_dungeon_crawl([], unit_level, int(cfg["terrain_style"]))

	# 4. The crawl spawned stock hostiles and chests — Battle Mode replaces
	#    the entire entity roster, so wipe everything.
	e._dungeon_entities.clear()

	# 4a. GROW THE FIELD: the crawl boot sized the map to MAP_SIZE_CRAWL (50).
	#     Battles want more room, so bump MAP_SIZE to BATTLE_MAP_SIZE and resize
	#     the three map-indexed arrays BEFORE _open_battlefield rewrites terrain.
	#     Only this live battle is affected — MAP_SIZE_CRAWL (the story crawl
	#     size) is a const and is never touched, and every dungeon entry resets
	#     MAP_SIZE for itself.
	e.MAP_SIZE = BATTLE_MAP_SIZE
	var _mcells: int = BATTLE_MAP_SIZE * BATTLE_MAP_SIZE
	e._dungeon_map.resize(_mcells)
	e._dungeon_map.fill(1)              # 1 = FLOOR; _open_battlefield rewrites all
	e._dungeon_elevation.resize(_mcells)
	e._dungeon_elevation.fill(1)        # battles are flat — uniform elevation
	e._dungeon_fog.resize(_mcells)
	e._dungeon_fog.fill(0)

	# 4b. REGION-STYLE BATTLEFIELD: overwrite the cave layout with open
	#     region terrain — mostly walkable field with scattered rock/grove
	#     obstacle clusters, like the explore-map outskirts. Battles are
	#     fought under open sky, not in dungeon corridors.
	_open_battlefield()

	# 5. Rebrand the encounter and reset the round counter.
	e._dungeon_encounter_name = "Battle for %s" % str(cfg["name"])
	e._dungeon_round = 1

	# Gather the region's lineage pool from all its subregions (deduped,
	# capped) — this seeds the "Lineage" tier of the unit catalog.
	_region_lineages = []
	for sub in cfg["subregions"]:
		for lin in e.get_lineages_for_region(str(sub)):
			if not _region_lineages.has(str(lin)):
				_region_lineages.append(str(lin))
	if _region_lineages.size() > MAX_LINEAGE_UNITS:
		_region_lineages.resize(MAX_LINEAGE_UNITS)

	# 9a. Economy arrays must exist before produce_unit runs (starter units
	#     are free, but keeping state coherent avoids surprises).
	supply = []
	team_alive = []
	for i in range(num_teams):
		supply.append(START_SUPPLY)
		team_alive.append(true)

	# 6-7. Team start positions: evenly spaced on a circle so every team
	#      begins equidistant from the center resource cluster. Positions
	#      are computed FIRST (raw ring math, no floor-snapping), then
	#      battle lanes are carved so every team provably connects to the
	#      central plaza, and only THEN are bases snapped and placed.
	var ms: int = int(e.MAP_SIZE)
	var center: float = float(ms) / 2.0
	var radius: float = float(ms) * 0.38
	var team_positions: Array = []
	for t in range(num_teams):
		var ang: float = TAU * float(t) / float(num_teams)
		var bx: int = clampi(int(round(center + cos(ang) * radius)), 3, ms - 4)
		var by: int = clampi(int(round(center + sin(ang) * radius)), 3, ms - 4)
		team_positions.append(Vector2i(bx, by))
	_carve_battle_lanes(team_positions)
	for t in range(num_teams):
		var ring: Vector2i = team_positions[t]
		# Snap onto walkable ground (force-carves floor if the ring landed
		# inside solid rock — a base must ALWAYS place).
		var pos: Vector2i = _nearest_floor(ring.x, ring.y, 6)
		e._dungeon_entities.append(_make_base(t, pos.x, pos.y))
		# Default rally point: right beside the base.
		_rally[t] = pos

		# Three free starter troops around the base (region lineage when
		# available, otherwise plain rabble).
		for j in range(3):
			var starter_key: String = "mob"
			if not _region_lineages.is_empty():
				starter_key = "lineage:%s" % str(_region_lineages[randi() % _region_lineages.size()])
			produce_unit(t, starter_key, true)

		# Home mine: resource nodes 3-5 tiles out from the base. Count is
		# set by the abundance setting (low 1 … insane 4). Offsets are
		# picked on a Manhattan ring, then snapped to the nearest floor.
		for j in range(int(_res_cfg()["home"])):
			var d: int = randi_range(3, 5)
			var ox: int = randi_range(-d, d)
			var oy: int = (d - absi(ox)) * (1 if randi() % 2 == 0 else -1)
			_spawn_resource_node(pos.x + ox, pos.y + oy)

	# 7b. STORY HEROES: up to MAX_HEROES roster characters join the player
	#     team as read-only battle copies (handle stays -1, so nothing that
	#     happens on this field can ever touch a story character).
	_spawn_heroes(p_heroes)

	# Contested center cluster: extra nodes near the map middle give teams
	# a reason to fight over the midfield (count per abundance setting).
	var ci: int = int(center)
	for j in range(int(_res_cfg()["center"])):
		_spawn_resource_node(ci + randi_range(-3, 3), ci + randi_range(-3, 3))

	# Insane abundance: wild veins scattered across the whole field.
	var ms_r: int = int(e.MAP_SIZE)
	for j in range(int(_res_cfg()["wild"])):
		_spawn_resource_node(randi_range(4, ms_r - 5), randi_range(4, ms_r - 5))

	# 9b. Battle is live; restore non-deterministic RNG for actual combat.
	active = true
	randomize()

	# 10. Player phase setup: queue every player-team unit and reveal fog.
	_rebuild_player_queue()
	e._dungeon_is_player_phase = true
	e._update_fog()

	# Battle statistics (score screen) + remember the loadout for Rematch.
	_team_kills = []
	_supply_mined = []
	_units_built = []
	_units_lost = []
	_captures = []
	for i in range(num_teams):
		_team_kills.append(0)
		_supply_mined.append(0)
		_units_built.append(0)
		_units_lost.append(0)
		_captures.append(0)
	_biggest_blast = {}
	_mvp = {}
	_last_heroes = p_heroes.duplicate()

	# Living map: reset the kaiju event + crates, seed derelict tech ruins.
	_kaiju_spawned = false
	_crate_timer = randf_range(CRATE_MIN_PERIOD, CRATE_MAX_PERIOD)
	_crates = []
	var tech_pool: Array = TECH_LABELS.keys()
	tech_pool.shuffle()
	for ti in range(2):
		var tk: String = str(tech_pool[ti])
		var tp: Vector2i = _nearest_floor(
			randi_range(int(ms_r / 3.0), int(ms_r * 2.0 / 3.0)),
			randi_range(int(ms_r / 3.0), int(ms_r * 2.0 / 3.0)), 6)
		e._dungeon_entities.append(_make_tech_building(tk, tp.x, tp.y))
	battle_log_extra.append(
		"🏚 Derelict structures dot the field — send an Engineer to claim them.")

	# Region personality: arm this battlefield's hazard.
	region_effect = str(REGION_EFFECTS.get(region_id, ""))
	rift_a = Vector2i(-1, -1)
	rift_b = Vector2i(-1, -1)
	_region_fx_timer = randf_range(25.0, 45.0)
	if region_effect == "rift":
		var ms_fx: int = int(e.MAP_SIZE)
		rift_a = _nearest_floor(int(ms_fx / 3.0), int(ms_fx / 3.0), 6)
		rift_b = _nearest_floor(int(ms_fx * 2.0 / 3.0), int(ms_fx * 2.0 / 3.0), 6)
		battle_log_extra.append("🌀 Astral rifts shimmer on the field — step close to travel.")
	elif region_effect != "":
		var fx_names := {"blizzard": "🌨 Blizzards haunt these peaks.",
			"lava": "🌋 The ground here erupts without warning.",
			"spores": "🍄 Spore clouds drift across the isles.",
			"gloom": "🌑 Something in the dark feeds on courage."}
		battle_log_extra.append(str(fx_names.get(region_effect, "")))

	# Diagnostic: report spawn results so the battle log shows exactly what
	# start_battle produced (drained by the dungeon scene on first build).
	battle_log_extra.append(
		"[color=#88ccff][Battle] start_battle done: %d entities, %d teams, %d lineages, queue %d[/color]" % [
			e._dungeon_entities.size(), num_teams, _region_lineages.size(),
			e._dungeon_player_queue.size()])

## Shut the battle down. The scene handles UI transitions; this stops the
## battle layer, the underlying dungeon simulation, and restores the map
## size so the next regular crawl starts from a clean slate.
func end_battle() -> void:
	active = false
	paused = false
	time_scale = 1.0
	finished = false
	winner = -1
	sandbox = false
	region_effect = ""
	rift_a = Vector2i(-1, -1)
	rift_b = Vector2i(-1, -1)
	_battle_time = 0.0
	_sim_accum = 0.0
	_income_timer = INCOME_PERIOD
	_cond_timer = CONDITION_PERIOD
	_ai_next_think = []
	_build_queue = []
	_rally = []
	_wave_timers = []
	_strike_cd = []
	squads.clear()
	var e = _engine()
	if e != null:
		e._dungeon_active = false
		e._crawl_active = false
		e.MAP_SIZE = e.MAP_SIZE_STANDARD
		e._dungeon_entities.clear()

# ──────────────────────────────────────────────────────────────────────────
# Production
# ──────────────────────────────────────────────────────────────────────────

## Produce a unit for `team` from catalog entry `key` INSTANTLY. Returns
## "" on success or a human-readable error string. `free` skips the supply
## cost (used for starter armies). Interactive production should go through
## queue_production instead — this stays for starters and legacy callers.
func produce_unit(team: int, key: String, free: bool = false) -> String:
	var e = _engine()
	if e == null:
		return "Engine unavailable."

	# Production requires a living Command Post.
	var base = _find_team_base(team)
	if base == null:
		return "No base."

	var entry: Dictionary = _catalog_entry(team, key)
	if entry.is_empty():
		return "Unknown unit."
	var cost: int = _catalog_cost(team, entry)
	if not free and int(supply[team]) < cost:
		return "Need %d supply." % cost

	var err: String = _spawn_units_now(team, key, Vector2i(int(base["x"]), int(base["y"])))
	if err != "":
		return err

	# Deduct the cost only after successful placement.
	if not free:
		supply[team] = int(supply[team]) - cost
	return ""

## Catalog entry for a key ({} when the team can't build it).
func _catalog_entry(team: int, key: String) -> Dictionary:
	for c in get_unit_catalog(team):
		if str(c["key"]) == key:
			return c
	return {}

## Effective cost of a catalog entry for a team. Barracks discount:
## infantry (mobs, militia, lineage troops) train 20% cheaper while the
## team owns a Barracks.
func _catalog_cost(team: int, entry: Dictionary) -> int:
	var key: String = str(entry.get("key", ""))
	var cost: int = int(entry.get("cost", 0))
	var is_infantry: bool = key == "mob" or key == "militia" or key.begins_with("lineage:")
	if is_infantry and _team_has_structure(team, "barracks"):
		cost = int(round(float(cost) * 0.8))
	return cost

## Build + place + register the unit(s) for a catalog key around `around`
## (base or rally point). No cost handling here — callers pay. Emits one
## "spawn" event per unit. Returns "" or an error string.
func _spawn_units_now(team: int, key: String, around: Vector2i,
		rally: Vector2i = Vector2i(-1, -1)) -> String:
	var e = _engine()
	if e == null:
		return "Engine unavailable."
	# Build the entity dict(s) — militia squads yield three units.
	var units: Array = _build_units(key)
	if units.is_empty():
		return "Unknown unit."
	# Place each unit on the nearest free floor tile around the anchor
	# (spiral search), tag it with team flags, and register it.
	for u in units:
		var pos: Vector2i = _nearest_floor(around.x, around.y, 6)
		u["x"] = pos.x
		u["y"] = pos.y
		_unit_counter += 1
		u["id"] = "bt%d_%s_%d" % [team, _sanitize_key(key), _unit_counter]
		_apply_team_flags(u, team)
		e._dungeon_entities.append(u)
		# Fresh recruits walk from their factory door to the rally point.
		if rally.x >= 0 and (absi(rally.x - pos.x) > 2 or absi(rally.y - pos.y) > 2):
			u["order_dest_x"] = rally.x
			u["order_dest_y"] = rally.y
		if team >= 0 and team < _units_built.size():
			_units_built[team] = int(_units_built[team]) + 1
		sim_event.emit("spawn", {
			"id": str(u["id"]), "name": str(u["name"]), "team": team})
	return ""

# ──────────────────────────────────────────────────────────────────────────
# Story heroes (read-only battle copies of roster characters)
# ──────────────────────────────────────────────────────────────────────────

## Build a battle entity from a STORY-MODE character — strictly READ-ONLY.
## The sheet is deep-duplicated before any field is touched, and the battle
## copy carries handle = -1, so nothing that happens in battle (damage,
## death, kills) can ever write back to the roster character. Returns {}
## when the handle can't be read.
func _build_hero_unit(handle: int) -> Dictionary:
	var e = _engine()
	if e == null or not e._chars.has(handle):
		return {}
	# Deep copy: every read below touches the COPY, never the roster dict.
	var cd: Dictionary = (e._chars[handle] as Dictionary).duplicate(