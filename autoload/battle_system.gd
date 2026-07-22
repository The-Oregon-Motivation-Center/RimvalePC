extends Node
## BattleSystem — rules engine for "Battle Mode", a REAL-TIME strategy
## skirmish layer (Command & Conquer flavour) built directly on top of the
## existing dungeon-crawl engine. The sim runs at a fixed 10 Hz inside
## _process; the renderer listens to `sim_event` and drains
## battle_log_extra.
##
## Concept:
##   * Up to 10 teams, each with a Command Post (base), fight on a 150×150
##     battlefield until only one team has living entities.
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
const CONDITION_PERIOD := 5.0
const AI_THINK_PERIOD := 3.0

## Sudden death is DISABLED — the only victory condition is total
## elimination (all other teams wiped out). These constants are retained
## but unused so nothing that references them breaks.
const SUDDEN_DEATH_WARN_TIME := -1.0
const SUDDEN_DEATH_TIME := -1.0

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

## Battle-unit sprite art. Every builder stamps `ent["sprite"]` with a path
## the renderer can raw-load, so no unit ever falls back to the procedural
## placeholder figure. All paths are verified against assets/ on disk.
##
## Militia config row name → characters_3d file. The display names have no
## militia_<snake>.png of their own, so the mapping is thematic.
const MILITIA_SPRITES := {
	"Ironroot Guard":    "res://assets/characters_3d/militia_guard.png",
	"Emberveil Recon":   "res://assets/characters_3d/militia_recon.png",
	"Crimson Crusaders": "res://assets/characters_3d/militia_crusader.png",
	"Shadow Blades":     "res://assets/characters_3d/militia_shadow.png",
	"Bone Wardens":      "res://assets/characters_3d/militia_raid.png",
	"Void Warband":      "res://assets/characters_3d/militia_arcane.png",
	"Storm Riders":      "res://assets/characters_3d/militia_storm.png",
	"Sacred Vigil":      "res://assets/characters_3d/militia_sacred.png",
}
const MILITIA_SPRITE_FALLBACK := "res://assets/characters_3d/militia_guard.png"

## Mob Rabble is a motley crowd — each unit draws a random look from the
## dedicated mob_* art set.
const MOB_SPRITES := [
	"res://assets/characters_3d/mob_arcane_militia.png",
	"res://assets/characters_3d/mob_arcanite_rabble.png",
	"res://assets/characters_3d/mob_beast_swarm.png",
	"res://assets/characters_3d/mob_emberkin_street.png",
	"res://assets/characters_3d/mob_groblodyte_scavenger.png",
	"res://assets/characters_3d/mob_ironclad_militia.png",
	"res://assets/characters_3d/mob_nightborne_shadow.png",
	"res://assets/characters_3d/mob_nightborne_shadow_host.png",
	"res://assets/characters_3d/mob_sacred_zealots.png",
	"res://assets/characters_3d/mob_the_chosen.png",
	"res://assets/characters_3d/mob_titans_vanguard.png",
	"res://assets/characters_3d/mob_venari_tide.png",
	"res://assets/characters_3d/mob_venari_tide_guard.png",
]

## Fixed art for the remaining catalog kinds, plus name-lookup fallbacks for
## Apex / Kaiju rows whose portrait file might be missing.
const ENGINEER_SPRITE := "res://assets/characters_3d/militia_engineer.png"
const MONSTER_SPRITE := "res://assets/characters_3d/war_hound.png"
const CHAMPION_SPRITE_FALLBACK := "res://assets/characters_3d/captain.png"
const APEX_SPRITE_FALLBACK := "res://assets/characters_3d/chaos_creature.png"
const KAIJU_SPRITE_FALLBACK := "res://assets/characters_3d/corrupted_wyrmblood.png"

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
const TURRET_BASE_CAP := 4   # turret limit = base + one per barracks built

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

## Round cap (unused — elimination is the only victory condition).
const MAX_ROUNDS := 999

## Battle-field size presets — Small / Medium / Large.
const BATTLE_MAP_SMALL  := 75
const BATTLE_MAP_MEDIUM := 150
const BATTLE_MAP_LARGE  := 300

## Active battle-field size in tiles. Set from the setup screen before
## start_battle() runs. Defaults to Medium (150).
var battle_map_size: int = BATTLE_MAP_MEDIUM

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
var spectator: bool = false          # true = every team is AI; the player only watches
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

## Custom spells created by the player this battle. Each entry is a Dictionary:
##   name: String, kind: "damage"|"heal"|"buff"|"debuff",
##   dc: int (dice count), ds: int (dice sides), area: int (radius 1-4),
##   conds: Array[String] (conditions for buff/debuff kinds),
##   cost: int (supply cost to create), desc: String (auto-generated)
## These are always-on auras — equipped units radiate the effect continuously.
var custom_spells: Array = []

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
var _aura_timer: float = 3.0         # custom aura pulse interval
const AURA_PERIOD := 3.0

## ── Per-step lookup structures (rebuilt each 0.1 s sim step) ─────────────
## These turn the per-unit O(n) scans (find-by-id, who's-on-this-tile) into
## O(1) lookups so 150+ units stay cheap: O(n) once per step, not O(n²).
var _ent_index: Dictionary = {}      # id → live entity Dictionary
var _occ: Dictionary = {}            # tile key (y*ms+x) → occupant id
var _occ_ms: int = 50                # MAP_SIZE snapshot used for _occ keys
var _paths_this_step: int = 0        # A* calls spent this sim step
var _path_budget: int = 8            # scaled at battle start for large maps

## Spatial hash: cell_key → Array[entity dict]. Cell size = 10 tiles,
## so a 150×150 map has 15×15 = 225 cells. _nearest_enemy_of queries
## only check cells within SIGHT_RANGE instead of ALL entities.
var _spatial: Dictionary = {}
const CELL_SIZE: int = 10

## Per-team living entity lists, rebuilt each sim step alongside _ent_index.
## Index: team number → Array of living entity dicts for that team.
var _team_ents: Array = []           # [team] → Array[entity dict]

## Per-team structure cache: team → { kind_string → count }.
## Also caches the base entity: team → entity or null.
var _team_structs: Dictionary = {}   # team → { kind → count }
var _team_bases: Dictionary = {}     # team → entity or null

## Hard ceiling on one team's living mobile units. The player always gets
## the full 100-unit cap; AI teams are capped by difficulty so easy
## opponents don't flood the map.
const MAX_TEAM_UNITS := 100

## AI army caps per difficulty — smaller armies make lower difficulties
## feel more forgiving without dumbing down the AI logic itself.
const AI_ARMY_CAP := {"easy": 25, "medium": 50, "hard": 100}

## Story heroes that may join the player team (bonus units: exempt from the
## army cap and never producible).
const MAX_HEROES := 3

## Corpses linger this long before being removed from the entity roster
## (long enough for the renderer's death fade; keeps scans from dragging).
const CORPSE_TIME := 5.0
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
		p_heroes: Array = [], p_spectator: bool = false) -> void:
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
	spectator = p_spectator
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
	custom_spells = []
	_aura_timer = AURA_PERIOD
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
		_ai_personas.append("" if (i == player_team and not spectator)
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
	e.MAP_SIZE = battle_map_size
	# Scale path budget down on very large maps — each A* is heavier.
	_path_budget = 8 if battle_map_size <= 75 else (6 if battle_map_size <= 150 else 4)
	var _mcells: int = battle_map_size * battle_map_size
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
		# Fresh recruits walk from their factory door to the rally point,
		# fanning out around it so the muster never becomes a traffic jam.
		if rally.x >= 0 and (absi(rally.x - pos.x) > 2 or absi(rally.y - pos.y) > 2):
			var rp: Vector2i = _nearest_floor(
				rally.x + randi_range(-3, 3), rally.y + randi_range(-3, 3), 4)
			u["order_dest_x"] = rp.x
			u["order_dest_y"] = rp.y
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
	var cd: Dictionary = (e._chars[handle] as Dictionary).duplicate(true)
	var u: Dictionary = _new_entity("✦ %s" % str(cd.get("name", "Hero")),
			str(cd.get("lineage", "Enemy")))
	u["is_hero"] = true
	u["sprite"] = _sprite_path_for(str(cd.get("lineage", "")))
	u["handle"] = -1        # SAFETY: never link back to the story character
	u["hero_down"] = false
	u["kills"] = 0
	# Durable but not silly: story HP ×3 at battle scale, floor of 80.
	_set_hp(u, maxi(80, int(cd.get("max_hp", 20)) * 3))
	u["ac"] = maxi(13, int(cd.get("ac", 10)))
	var spd: int = int(cd.get("speed", 0))
	u["speed"] = spd if spd > 0 else 30
	u["atk_interval"] = 1.3
	u["hit_bonus_buff"] = clampi(int(cd.get("level", 1)), 2, 10)
	var wpn: String = str(cd.get("weapon", "None"))
	u["equipped_weapon"] = wpn if not wpn.is_empty() and wpn != "None" else "Longsword"
	var arm: String = str(cd.get("armor", "None"))
	if not arm.is_empty() and arm != "None":
		u["equipped_armor"] = arm
	var shd: String = str(cd.get("shield", "None"))
	if not shd.is_empty() and shd != "None":
		u["equipped_shield"] = shd
	var st_v = cd.get("stats", [])
	if st_v is Array and (st_v as Array).size() >= 5:
		u["stats"] = [int(st_v[0]), int(st_v[1]), int(st_v[2]),
				int(st_v[3]), int(st_v[4])]
	u["spells"] = _hero_spell_loadout(cd)
	return u

## Battle spell loadout from a hero's KNOWN spells (read off the sheet
## COPY): up to 3 names that exist in the spell DB, with one heal and the
## damage spells picked first. Falls back to a classic duo when nothing
## usable is known.
func _hero_spell_loadout(cd: Dictionary) -> Array:
	var out: Array = []
	var e = _engine()
	if e != null:
		e._ensure_spell_db()
		var heals: Array = []
		var damage: Array = []
		var others: Array = []
		for n_v in cd.get("spells", []):
			var n: String = str(n_v)
			if not e._SPELL_DB.has(n):
				continue
			match _spell_kind(e._SPELL_DB[n]):
				"heal":
					heals.append(n)
				"damage":
					damage.append(n)
				_:
					others.append(n)
		var ordered: Array = []
		if not heals.is_empty():
			ordered.append(heals.pop_front())   # always bring one heal
		ordered.append_array(damage)
		ordered.append_array(heals)
		ordered.append_array(others)
		for n in ordered:
			if out.size() >= 3:
				break
			out.append({"name": str(n), "cd_left": 0.0})
	if out.is_empty():
		out = [{"name": "Frost Lance", "cd_left": 0.0},
				{"name": "Healing Touch", "cd_left": 0.0}]
	return out

## Spawn up to MAX_HEROES story heroes beside the player's Command Post.
## Heroes are bonus units: exempt from the army cap and never producible.
## Unreadable handles are skipped silently (graceful degradation).
func _spawn_heroes(handles: Array) -> void:
	if handles.is_empty():
		return
	var e = _engine()
	if e == null:
		return
	var base = _find_team_base(player_team)
	if base == null:
		return
	var n: int = 0
	for h_v in handles:
		if n >= MAX_HEROES:
			break
		var u: Dictionary = _build_hero_unit(int(h_v))
		if u.is_empty():
			continue
		n += 1
		var pos: Vector2i = _nearest_floor(int(base["x"]), int(base["y"]), 6)
		u["x"] = pos.x
		u["y"] = pos.y
		u["id"] = "hero_%d" % n
		_apply_team_flags(u, player_team)
		e._dungeon_entities.append(u)
		# u["name"] already carries the "✦ " hero prefix.
		battle_log_extra.append("%s takes the field!" % str(u["name"]))
		sim_event.emit("spawn", {
			"id": str(u["id"]), "name": str(u["name"]), "team": player_team})

# ──────────────────────────────────────────────────────────────────────────
# Production queues (real-time)
# ──────────────────────────────────────────────────────────────────────────

## Enqueue a unit for timed production at a specific structure (`sid`) —
## or at the team's Command Post when sid is "". EVERY production
## structure (Command Post / Barracks / War Factory) runs its OWN queue,
## so extra buildings mean parallel production — real C&C economics.
## Cost is deducted IMMEDIATELY; the unit spawns at its factory's door and
## walks to the team rally point. Returns "" or an error string.
func queue_production(team: int, key: String, sid: String = "") -> String:
	var e = _engine()
	if e == null:
		return "Engine unavailable."
	if not active or finished:
		return "No battle running."
	if team < 0 or team >= num_teams:
		return "Bad team."
	var producer = _find_producer(team, sid)
	if producer == null:
		return "No production structure."
	# get_unit_catalog already gates vehicles behind a War Factory.
	var entry: Dictionary = _catalog_entry(team, key)
	if entry.is_empty():
		return "Unknown unit."
	var cost: int = _catalog_cost(team, entry)
	if int(supply[team]) < cost:
		return "Need %d supply." % cost
	var q: Array = producer.get("build_q", [])
	if q.size() >= MAX_QUEUE:
		return "This structure's queue is full."
	# Army cap: player always gets MAX_TEAM_UNITS (100); AI teams are
	# capped by difficulty so easier foes field smaller armies.
	var cap: int = MAX_TEAM_UNITS if team == player_team \
			else int(AI_ARMY_CAP.get(difficulty, 50))
	if _mobile_count(team) + _queued_count(team) >= cap:
		return "Army at max size (%d)." % cap
	supply[team] = int(supply[team]) - cost
	var bt: float = _unit_build_time(key, int(entry.get("cost", 0)))
	q.append({"key": key, "name": str(entry["label"]), "t_left": bt, "total": bt})
	producer["build_q"] = q
	return ""

## Resolve which structure produces: an explicit living team-owned
## production structure by id, or the Command Post as the default.
func _find_producer(team: int, sid: String):
	var e = _engine()
	if e == null:
		return null
	if sid != "":
		var s = e._dung_find(sid)
		if s == null or bool(s.get("is_dead", false)):
			return null
		if int(s.get("battle_team", -1)) != team:
			return null
		var k: String = str(s.get("structure_kind", ""))
		if bool(s.get("is_battle_base", false)) or k == "barracks" or k == "war_factory":
			return s
		return null
	return _find_team_base(team)

## Units waiting in ALL of the team's structure queues.
func _queued_count(team: int) -> int:
	var e = _engine()
	if e == null:
		return 0
	var n: int = 0
	for ent in e._dungeon_entities:
		if bool(ent.get("is_dead", false)):
			continue
		if int(ent.get("battle_team", -1)) != team:
			continue
		n += (ent.get("build_q", []) as Array).size()
	return n

## Build time in seconds per catalog key kind.
func _unit_build_time(key: String, cost: int) -> float:
	if key.begins_with("vehicle:"):
		return 10.0 + float(cost) / 40.0
	if key.begins_with("lineage:"):
		return 6.0
	match key:
		"mob":
			return 3.0
		"engineer":
			return 5.0
		"militia":
			return 4.0
		"monster":
			return 9.0
		"adversary":
			return 12.0
		"apex":
			return 20.0
		"kaiju":
			return 30.0
	return 6.0

## UI copy of a team's production queue: [{key, name, t_left, total}].
func get_build_queue(team: int, sid: String = "") -> Array:
	var producer = _find_producer(team, sid)
	if producer == null:
		return []
	var out: Array = []
	for item in producer.get("build_q", []):
		out.append({
			"key":    str(item["key"]),
			"name":   str(item["name"]),
			"t_left": float(item["t_left"]),
			"total":  float(item["total"]),
		})
	return out

## Move a team's rally point (new units spawn on the nearest floor there).
func set_rally(team: int, x: int, y: int) -> void:
	if team < 0 or team >= _rally.size():
		return
	_rally[team] = Vector2i(x, y)

func get_rally(team: int) -> Vector2i:
	if team < 0 or team >= _rally.size():
		return Vector2i.ZERO
	return _rally[team]

## Tick the front item of EVERY production structure's own queue. Finished
## units spawn at their factory's door and walk to the team rally point.
## A destroyed structure takes its queue (and the supply spent) with it.
func _tick_queues(dt: float) -> void:
	var e = _engine()
	if e == null:
		return
	for ent in e._dungeon_entities:
		if bool(ent.get("is_dead", false)):
			continue
		var q: Array = ent.get("build_q", [])
		if q.is_empty():
			continue
		var t: int = int(ent.get("battle_team", -1))
		if t < 0 or t >= num_teams:
			continue
		var item: Dictionary = q[0]
		item["t_left"] = float(item["t_left"]) - dt
		if float(item["t_left"]) > 0.0:
			continue
		q.pop_front()
		var door: Vector2i = Vector2i(int(ent.get("x", 0)), int(ent.get("y", 0)))
		_spawn_units_now(t, str(item["key"]), door, get_rally(t))

## Route a catalog key to the correct unit builder. Returns an Array of
## entity dicts (position / id / team flags are filled in by produce_unit).
func _build_units(key: String) -> Array:
	if key.begins_with("lineage:"):
		return [_build_lineage_unit(key.substr(8))]
	if key.begins_with("vehicle:"):
		return [_build_vehicle_unit(key.substr(8))]
	match key:
		"mob":
			return [_build_mob_unit()]
		"engineer":
			return [_build_engineer_unit()]
		"militia":
			# One purchase → a squad of three weak soldiers.
			var squad: Array = []
			for i in range(3):
				squad.append(_build_militia_unit())
			return squad
		"monster":
			return [_build_monster_unit()]
		"adversary":
			return [_build_adversary_unit()]
		"apex":
			return [_build_apex_unit()]
		"kaiju":
			return [_build_kaiju_unit()]
	return []

## Support specialist: no real weapon, but touching an enemy STRUCTURE
## captures it for your team (the engineer is consumed — C&C rules).
func _build_engineer_unit() -> Dictionary:
	var u: Dictionary = _new_entity("Engineer", "Human")
	_set_hp(u, 16)
	u["ac"] = 10
	u["speed"] = 30
	u["equipped_weapon"] = "None"
	u["is_engineer"] = true
	u["atk_interval"] = 1.5
	u["sprite"] = ENGINEER_SPRITE
	return u

## Standard lineage trooper: a random adversary archetype wearing the
## region lineage's sprite. Weapon follows the archetype's fighting style.
func _build_lineage_unit(lin: String) -> Dictionary:
	# Lineage troops are built from a random GMG NPC class (Divine Champion,
	# Shadowblade, ...) — stats/skills follow the class's archetype tables.
	var cls_names: Array = EnemyArchetype.class_names()
	var cls: String = str(cls_names[randi() % cls_names.size()])
	var u: Dictionary = _new_entity("%s %s" % [lin, cls], lin)
	_apply_unit_class(u, cls)
	u["sprite"] = _sprite_path_for(lin)
	return u

## (Re)build a battle unit's combat profile from a GMG class at unit_level.
## Used at production AND by set_unit_class for live reassignment — keeps
## current HP fraction so reclassing mid-battle isn't a free heal.
func _apply_unit_class(u: Dictionary, cls: String) -> void:
	var st: Array = EnemyArchetype.class_stats_for(cls, unit_level)
	var arch: String = EnemyArchetype.class_archetype(cls)
	var hp_frac: float = 1.0
	if int(u.get("max_hp", 0)) > 0:
		hp_frac = clampf(float(int(u["hp"])) / float(int(u["max_hp"])), 0.05, 1.0)
	u["npc_class"] = cls
	u["stats"] = st
	u["max_hp"] = 12 + unit_level * 4 + int(st[3]) * 2
	u["hp"] = maxi(1, int(float(u["max_hp"]) * hp_frac))
	u["ac"] = 12 + int(float(unit_level) / 3.0)
	u["ap"] = 10
	u["max_ap"] = 10
	u["speed"] = mini(5 + int(float(int(st[1])) / 3.0), 8)
	u["equipped_weapon"] = _weapon_for_archetype(arch)
	# STR modifier feeds the engine's live to-hit bonus field.
	u["hit_bonus_buff"] = maxi(0, int(st[0]) - 2)
	u["atk_interval"] = 1.5

## Live class reassignment for a player battle unit (Armory). Rebuilds the
## unit's profile at its current HP fraction; effect is immediate.
func set_unit_class(unit_id: String, cls: String) -> String:
	var e = _engine()
	if e == null: return "Engine unavailable."
	if not EnemyArchetype.CLASS_DEFS.has(cls): return "Unknown class."
	var ent = e._dung_find(unit_id)
	if ent == null: return "Unit not found."
	if int(ent.get("battle_team", -1)) != player_team: return "Not your unit."
	if bool(ent.get("is_battle_base", false)) or bool(ent.get("is_battle_structure", false)) \
			or bool(ent.get("is_vehicle", false)):
		return "Only infantry can take a class."
	# Class training happens in the Barracks (Command Post does NOT count).
	if not _team_has_structure(player_team, "barracks"):
		return "Requires a Barracks."
	# Preserve the lineage prefix in the display name.
	var lin: String = str(ent.get("lineage_name", ""))
	ent["name"] = "%s %s" % [lin, cls] if lin != "" else cls
	_apply_unit_class(ent, cls)
	return ""

## Cheap cannon fodder.
func _build_mob_unit() -> Dictionary:
	var u: Dictionary = _new_entity("Rabble", "Enemy")
	_set_hp(u, 6 + unit_level * 2)
	u["ac"] = 9 + int(float(unit_level) / 2.0)
	u["speed"] = 4
	u["equipped_weapon"] = "Rusty Dagger"
	u["atk_interval"] = 1.4
	u["sprite"] = str(MOB_SPRITES[randi() % MOB_SPRITES.size()])
	return u

## One soldier of a militia squad — gear borrowed from a random engine
## militia config row: [name, size, level, ac, weapon, ability].
func _build_militia_unit() -> Dictionary:
	var e = _engine()
	var row: Array = e.MILITIA_STATS[randi() % e.MILITIA_STATS.size()]
	var u: Dictionary = _new_entity(str(row[0]), "Militia")
	_set_hp(u, 6 + unit_level * 3)
	u["ac"] = int(row[3])
	u["speed"] = 5
	u["equipped_weapon"] = str(row[4])
	u["atk_interval"] = 1.4
	u["sprite"] = str(MILITIA_SPRITES.get(str(row[0]), MILITIA_SPRITE_FALLBACK))
	return u

## Mid-tier bruiser beast.
func _build_monster_unit() -> Dictionary:
	var u: Dictionary = _new_entity("Warbeast", "Monster")
	_set_hp(u, 20 + unit_level * 6)
	u["ac"] = 13
	u["ap"] = 10
	u["max_ap"] = 10
	u["speed"] = 5
	u["equipped_weapon"] = "Claws"
	u["hit_bonus_buff"] = 2
	u["atk_interval"] = 1.8
	u["sprite"] = MONSTER_SPRITE
	return u

## Elite champion: a lineage trooper rolled three levels above baseline
## with a 50% HP bonus. Wears a random region lineage sprite when one is
## available so champions blend into the region's armies.
func _build_adversary_unit() -> Dictionary:
	var arch: String = EnemyArchetype.pick_random_archetype()
	var st: Array = EnemyArchetype.stats_for(arch, unit_level + 3)
	var lin: String = "Enemy"
	if not _region_lineages.is_empty():
		lin = str(_region_lineages[randi() % _region_lineages.size()])
	var u: Dictionary = _new_entity("Champion %s" % arch, lin)
	u["stats"] = st
	var hp: int = 12 + (unit_level + 3) * 4 + int(st[3]) * 2
	_set_hp(u, hp + int(float(hp) * 0.5))
	u["ac"] = 12 + int(float(unit_level + 3) / 3.0)
	u["ap"] = 10
	u["max_ap"] = 10
	u["speed"] = mini(5 + int(float(int(st[1])) / 3.0), 8)
	u["equipped_weapon"] = _weapon_for_archetype(arch)
	# STR modifier feeds the engine's live to-hit bonus field.
	u["hit_bonus_buff"] = maxi(0, int(st[0]) - 2)
	u["atk_interval"] = 1.6
	var champ_art: String = _sprite_path_for(lin)
	u["sprite"] = champ_art if champ_art != "" else CHAMPION_SPRITE_FALLBACK
	return u

## Superweapon tier 1: a named Apex boss pulled straight from the engine's
## stat table. Row shape: [name, title, hp, ac, ap, sp, speed, lv, weapon].
func _build_apex_unit() -> Dictionary:
	var e = _engine()
	var r: Array = e.APEX_STATS[randi() % e.APEX_STATS.size()]
	var u: Dictionary = _new_entity("%s %s" % [str(r[0]), str(r[1])], "Apex")
	_set_hp(u, int(r[2]))
	u["ac"] = int(r[3])
	u["ap"] = int(r[4])
	u["max_ap"] = int(r[4])
	u["sp"] = int(r[5])
	u["max_sp"] = int(r[5])
	u["speed"] = int(r[6])
	# "Great" prefix upgrades the keyword-parsed damage to 2d6+2.
	u["equipped_weapon"] = "Great %s" % str(r[8])
	u["hit_bonus_buff"] = 6
	u["is_boss"] = true
	u["atk_interval"] = 2.2
	# Apex portraits are keyed by the boss's short name ("Varnok"), not the
	# full "name + title" display string.
	var apex_art: String = _sprite_path_for(str(r[0]))
	u["sprite"] = apex_art if apex_art != "" else APEX_SPRITE_FALLBACK
	return u

## Superweapon tier 2: a kaiju as a SINGLE entity (no 4-part hit zones —
## Battle Mode keeps combat uniform). Row shape:
## [name, hp, ac, ap, speed, lv, weapon, desc].
func _build_kaiju_unit() -> Dictionary:
	var e = _engine()
	var r: Array = e.KAIJU_STATS[randi() % e.KAIJU_STATS.size()]
	var u: Dictionary = _new_entity(str(r[0]), "Apex")
	_set_hp(u, int(r[1]))
	u["ac"] = int(r[2])
	u["ap"] = int(r[3])
	u["max_ap"] = int(r[3])
	u["speed"] = int(r[4])
	u["equipped_weapon"] = "Great Kaiju Maul"
	u["hit_bonus_buff"] = 10
	u["is_boss"] = true
	# Integer size drives everything big about a kaiju: the renderer's 2.4×
	# visual scale, the multi-tile body footprint in _occ, and melee reach
	# against its body edge.
	u["size"] = 3
	u["atk_interval"] = 2.8
	# KAIJU_STATS names match characters_3d portraits (pyroclast.png, …).
	var kaiju_art: String = _sprite_path_for(str(r[0]))
	u["sprite"] = kaiju_art if kaiju_art != "" else KAIJU_SPRITE_FALLBACK
	return u

## War-machine tier: stats from the overworld vehicle table, weapons chosen
## so the engine's keyword damage parser lands the right dice.
func _build_vehicle_unit(vname: String) -> Dictionary:
	var stats: Dictionary = VehicleData.get_stats(vname)
	var u: Dictionary = _new_entity(vname, vname)
	_set_hp(u, int(stats.get("hp", 40)))
	u["speed"] = clampi(int(float(int(stats.get("speed_paved", 40))) / 10.0), 3, 8)
	u["ac"] = 16 if vname == "Arcane Juggernaut" else 13
	u["ap"] = 10
	u["max_ap"] = 10
	var weapon: String = "Warhammer"
	match vname:
		"Arcane Motorcycle":
			weapon = "War Axe"
		"Arcane Quad":
			weapon = "Longbow"
		"Arcane Rover":
			weapon = "Warhammer"
		"Arcane Juggernaut":
			weapon = "Great Cannon Ram"
		"Arcane Copter":
			weapon = "Longbow"
			u["is_flying"] = true
	u["equipped_weapon"] = weapon
	u["is_vehicle"] = true
	u["hit_bonus_buff"] = 4
	u["lineage_name"] = vname  # the scene renders vehicles specially
	# vehicles_3d/vehicle_<snake>.png exists for every catalog vehicle.
	u["sprite"] = "res://assets/vehicles_3d/vehicle_%s.png" \
			% vname.to_lower().replace(" ", "_").replace("-", "_").replace("'", "")
	if vname == "Arcane Juggernaut":
		u["size"] = 2   # the one obviously-huge war machine
	# Swing rate scales with cost: cheap raiders ~1.5 s, Juggernaut 2.4 s.
	var vcost: int = 150
	for row in VEHICLE_CATALOG:
		if str(row[0]) == "vehicle:%s" % vname:
			vcost = int(row[2])
			break
	u["atk_interval"] = clampf(1.2 + float(vcost) / 333.0, 1.2, 2.4)
	return u

## Archetypes fight with signature weapons.
func _weapon_for_archetype(arch: String) -> String:
	match arch:
		"Fighter":
			return "Longsword"
		"Rogue":
			return "Shortbow"
		"Monk":
			return "Quarterstaff"
		"Mage":
			return "Dagger"
	return "Dagger"

## Resolve a display / lineage name to sprite art that EXISTS on disk, using
## the RimvaleUtils.get_sprite_portrait path convention: snake_case the name,
## try assets/characters_3d/<key>.png, then assets/characters/<key>.png.
## Checks both the resource system and the raw filesystem (import metadata
## can be missing in exported saves). Returns "" when neither file exists so
## callers can pick their own themed fallback.
func _sprite_path_for(disp_name: String) -> String:
	if disp_name.strip_edges() == "":
		return ""
	var key: String = disp_name.to_lower().replace(" ", "_") \
			.replace("-", "_").replace("'", "")
	for base in ["res://assets/characters_3d/", "res://assets/characters/"]:
		var path: String = base + key + ".png"
		if ResourceLoader.exists(path):
			return path
		if FileAccess.file_exists(ProjectSettings.globalize_path(path)):
			return path
	return ""

# ──────────────────────────────────────────────────────────────────────────
# Phase advancement (AI + economy + round bookkeeping)
# ──────────────────────────────────────────────────────────────────────────

## Run everything that happens between player rounds: AI unit turns, AI
## production, income for all teams, per-round resets, and elimination
## checks. Replaces the engine's dungeon_advance_enemy_phase in battle
## mode. Returns the combat log lines produced this phase.
func advance_battle_phase() -> Array:
	# REAL-TIME CONVERSION: battles no longer advance in phases — the 10 Hz
	# sim in _process/_sim_step owns AI, economy and outcome now. Kept only
	# because legacy callers may still reference it; it is a no-op.
	if active:
		return []
	var logs: Array = []
	var e = _engine()
	if e == null or not active:
		return logs
	e._dungeon_is_player_phase = false

	# ── Miner assignment ─────────────────────────────────────────────────
	# Keep up to two units per AI team dedicated to their home mines.
	_assign_ai_miners()

	# ── AI unit turns ────────────────────────────────────────────────────
	# Every living non-player-team combatant hunts the nearest hostile.
	# (Production appends to the array only AFTER this loop, so iterating
	# the live array directly is safe.)
	for ent in e._dungeon_entities:
		if bool(ent.get("is_dead", false)):
			continue
		if bool(ent.get("is_chest", false)):
			continue  # resource nodes never act
		if not ent.has("battle_team"):
			continue  # not a battle entity
		if int(ent["battle_team"]) == player_team:
			continue  # player units act during the player phase

		# Conditions tick (poison, burning, etc.); stunned units lose the turn.
		e._dung_tick_conditions(ent)
		if "stunned" in ent.get("conditions", []):
			continue

		# Acquire the nearest entity on any OTHER team within sight.
		var target = _nearest_enemy_of(ent)
		if target == null:
			# Nothing hostile in sight: designated miners head for their
			# node, everyone else marches on the nearest enemy base.
			if int(ent.get("speed", 0)) <= 0:
				continue
			var nid: String = str(ent.get("miner_node_id", ""))
			if nid != "":
				var node = e._dung_find(nid)
				if node != null and not bool(node.get("looted", false)):
					if _chebyshev(ent, node) > 1:
						e._enemy_move_toward(ent, node, int(ent["speed"]))
					continue
			var foe_base = _nearest_enemy_base_of(ent)
			if foe_base != null:
				e._enemy_move_toward(ent, foe_base, int(ent["speed"]))
			continue

		var dist: int = _manhattan(ent, target)

		# Bases (speed 0) cannot chase, but they defend against adjacent foes.
		if int(ent.get("speed", 0)) <= 0:
			if dist <= 1:
				_ai_attack_burst(ent, target, logs)
			continue

		# Close the gap, then swing if in melee reach.
		if dist > 1:
			e._enemy_move_toward(ent, target, int(ent["speed"]))
			dist = _manhattan(ent, target)
		if dist <= 1:
			_ai_attack_burst(ent, target, logs)

	# ── AI production ────────────────────────────────────────────────────
	# Each surviving AI team with a base considers structures, then buys up
	# to two units: usually (60%) the most expensive thing it can afford,
	# otherwise the cheapest — a crude "save up vs. flood" mix.
	for t in range(num_teams):
		if t == player_team and not spectator:
			continue
		if not bool(team_alive[t]):
			continue
		if _find_team_base(t) == null:
			continue
		if not _team_has_structure(t, "barracks") and int(supply[t]) > 220 \
				and randf() < 0.3:
			build_structure(t, "barracks")
		if not _team_has_structure(t, "war_factory") and int(supply[t]) > 320 \
				and randf() < 0.3:
			build_structure(t, "war_factory")
		for i in range(2):
			var pick: String = _ai_pick_production(t)
			if pick != "":
				produce_unit(t, pick)

	# ── Income for ALL teams (player included) ───────────────────────────
	_apply_income()

	# ── Round bookkeeping ────────────────────────────────────────────────
	e._dungeon_round = int(e._dungeon_round) + 1
	round_num = int(e._dungeon_round)
	e._dungeon_is_player_phase = true
	_rebuild_player_queue()
	for ent in e._dungeon_entities:
		if bool(ent.get("is_dead", false)):
			continue
		if bool(ent.get("is_chest", false)):
			continue
		# Fresh action economy for the new round.
		ent["ap_spent"] = 0
		ent["move_used"] = 0
		ent["actions_taken"] = 0
		# AI conditions ticked during their turns above — tick the player
		# team here so their DoTs/durations also advance once per round.
		if int(ent.get("battle_team", -1)) == player_team:
			e._dung_tick_conditions(ent)

	# ── Standing player orders ───────────────────────────────────────────
	# Move / attack orders persist across rounds: units with an order keep
	# executing it at the start of every new player phase automatically.
	for ent in e._dungeon_entities:
		if bool(ent.get("is_dead", false)) or bool(ent.get("is_chest", false)):
			continue
		if int(ent.get("battle_team", -1)) != player_team:
			continue
		if str(ent.get("order_target", "")) != "" \
				or int(ent.get("order_dest_x", -1)) >= 0:
			_execute_unit_order(ent)
	e._update_fog()

	# ── Team elimination check ───────────────────────────────────────────
	# A team lives while ANY of its non-chest entities is alive (base or
	# troops). Announce transitions exactly once.
	for t in range(num_teams):
		if not bool(team_alive[t]):
			continue
		if not _team_has_living(t):
			team_alive[t] = false
			var line: String = "💀 Team %d has been eliminated!" % t
			logs.append(line)
			battle_log_extra.append(line)

	return logs

## Resolve one attack via the engine and handle the aftermath.
func _do_battle_attack(atk: Dictionary, tgt: Dictionary, logs: Array) -> void:
	var e = _engine()
	if e == null:
		return
	var weapon: String = str(atk.get("equipped_weapon", "None"))
	var result: Dictionary = e._dung_do_attack(atk, tgt, weapon, weapon == "None")
	var line: String = str(result.get("log", ""))
	if line != "":
		logs.append(line)
	if bool(result.get("target_dead", false)):
		tgt["is_dead"] = true
		# Dead AI units drop lingering conditions so nothing keeps ticking.
		if int(tgt.get("battle_team", -1)) != player_team:
			tgt["conditions"] = []

## Multi-attack for the AI step: swing max_ap/4 times (min 1) so heavies
## like Apex / Kaiju / vehicles hit like superweapons. Stops early when the
## target dies unless another enemy stands adjacent to soak the rest.
func _ai_attack_burst(ent: Dictionary, first_target, logs: Array) -> void:
	var e = _engine()
	if e == null:
		return
	var swings: int = maxi(1, int(float(int(ent.get("max_ap", 10))) / 4.0))
	var target = first_target
	for i in range(swings):
		# (Re-)acquire a living adjacent victim.
		if target == null or bool(target.get("is_dead", false)):
			target = _adjacent_enemy_of(ent)
		if target == null or bool(target.get("is_dead", false)):
			return
		if _chebyshev(ent, target) > 1:
			return
		_do_battle_attack(ent, target, logs)

## Designate up to two non-base units per AI team as miners for unlooted
## nodes near their base (Manhattan <= 12). Designations are stored on the
## entity as `miner_node_id` and cleared once the node is looted or gone.
func _assign_ai_miners() -> void:
	var e = _engine()
	if e == null:
		return
	# Active mining spots, collected once.
	var nodes: Array = []
	for ent in e._dungeon_entities:
		if bool(ent.get("is_resource_node", false)) \
				and not bool(ent.get("looted", false)) \
				and not bool(ent.get("is_dead", false)):
			nodes.append(ent)
	for t in range(num_teams):
		if t == player_team and not spectator:
			continue
		# The team's living mobile troops (bases/structures never mine).
		var units: Array = []
		if t >= 0 and t < _team_ents.size():
			for ent in _team_ents[t]:
				if bool(ent.get("is_battle_base", false)) \
						or bool(ent.get("is_battle_structure", false)):
					continue
				units.append(ent)
		# Drop stale designations (node looted or removed).
		var designated: int = 0
		for u in units:
			var nid: String = str(u.get("miner_node_id", ""))
			if nid == "":
				continue
			var node = _ent_index.get(nid)
			if node == null or bool(node.get("looted", false)) \
					or bool(node.get("is_dead", false)):
				u["miner_node_id"] = ""
			else:
				designated += 1
		var base = _find_team_base(t)
		if base == null:
			continue
		# Home mines: unlooted nodes within reach of the base.
		var near_nodes: Array = []
		for node in nodes:
			if _manhattan(base, node) <= 12:
				near_nodes.append(node)
		# Top up to two miners, each pairing the closest free unit to a node.
		var ni: int = 0
		while designated < 2 and ni < near_nodes.size():
			var node: Dictionary = near_nodes[ni]
			ni += 1
			var best = null
			var best_d: int = 999999
			for u in units:
				if str(u.get("miner_node_id", "")) != "":
					continue
				var d: int = _manhattan(u, node)
				if d < best_d:
					best_d = d
					best = u
			if best == null:
				break
			best["miner_node_id"] = str(node["id"])
			designated += 1

## First team production structure whose personal queue has room (base
## first — entities are stored in creation order).
func _ai_open_producer(t: int, cap: int):
	var e = _engine()
	if e == null:
		return null
	for ent in e._dungeon_entities:
		if bool(ent.get("is_dead", false)):
			continue
		if int(ent.get("battle_team", -1)) != t:
			continue
		var k: String = str(ent.get("structure_kind", ""))
		if not (bool(ent.get("is_battle_base", false)) or k == "barracks" or k == "war_factory"):
			continue
		if (ent.get("build_q", []) as Array).size() < mini(cap, MAX_QUEUE):
			return ent
	return null

## Pick what an AI team should build: 60% of the time the priciest entry
## it can afford, otherwise the cheapest. Returns "" if nothing fits.
func _ai_pick_production(team: int) -> String:
	var affordable: Array = []
	for c in get_unit_catalog(team):
		if int(c["cost"]) <= int(supply[team]):
			affordable.append(c)
	if affordable.is_empty():
		return ""
	var best: Dictionary = affordable[0]
	var cheapest: Dictionary = affordable[0]
	for c in affordable:
		if int(c["cost"]) > int(best["cost"]):
			best = c
		if int(c["cost"]) < int(cheapest["cost"]):
			cheapest = c
	# Personas shop differently: rushers flood cheap, boomers buy the best.
	match _persona_of(team):
		"rusher":
			return str(cheapest["key"])
		"boomer":
			return str(best["key"])
	if difficulty == "hard":
		return str(best["key"])   # hard AI always fields its best
	return str(best["key"]) if randf() < 0.6 else str(cheapest["key"])

## The team's rolled personality ("" for the player / unrolled).
func _persona_of(t: int) -> String:
	if t < 0 or t >= _ai_personas.size():
		return ""
	return str(_ai_personas[t])

## First taunt reveals the persona; later ones fire occasionally.
func _persona_taunt(t: int) -> void:
	var p: String = _persona_of(t)
	if p == "":
		return
	var first: bool = t < _persona_revealed.size() and not bool(_persona_revealed[t])
	if not first and randf() > 0.3:
		return
	if t < _persona_revealed.size():
		_persona_revealed[t] = true
	var taunts := {
		"rusher":  ["'Still building? Cute.'", "'Speed IS strategy.'",
			"'Knock knock.'"],
		"turtler": ["'My walls will outlive you.'", "'Come and get me.'",
			"'Patience wins wars.'"],
		"boomer":  ["'My economy could buy yours twice.'",
			"'Quality over quantity.'", "'This army paid for itself.'"],
	}
	var pool: Array = taunts.get(p, [])
	if pool.is_empty():
		return
	battle_log_extra.append("💬 %s (%s): %s" % [
		_team_label(t), p.capitalize(), str(pool[randi() % pool.size()])])

## How far AI units notice enemies on their own, by difficulty.
func _ai_sight() -> int:
	if difficulty == "easy":
		return 6
	if difficulty == "hard":
		return SIGHT_RANGE
	return 12

## Grant every team its per-round income: BASE_INCOME per living Command
## Post, plus MINE_INCOME per node it controls. Each node pays exactly ONE
## team per round (the nearest adjacent unit claims it) and holds a finite
## `amount` of supply — once drained it flips to a looted "Depleted Node".
func _apply_income() -> void:
	var e = _engine()
	if e == null:
		return
	_last_income = []
	for t in range(num_teams):
		_last_income.append(0)
	# Replenish pass: depleted veins refill 3 minutes after exhaustion.
	for node in e._dungeon_entities:
		if not bool(node.get("is_resource_node", false)):
			continue
		if not bool(node.get("looted", false)):
			continue
		if _battle_time >= float(node.get("replenish_at", 1.0e12)):
			node["looted"] = false
			node["amount"] = randi_range(int(_res_cfg()["amt_lo"]), int(_res_cfg()["amt_hi"]))
			node["name"] = "Resource Node"
			node.erase("replenish_at")
			battle_log_extra.append("✨ A resource node has replenished!")
	# Bases pay their flat stipend.
	for ent in e._dungeon_entities:
		if bool(ent.get("is_dead", false)):
			continue
		if not bool(ent.get("is_battle_base", false)):
			continue
		var bt: int = int(ent.get("battle_team", -1))
		if bt >= 0 and bt < num_teams:
			_last_income[bt] = int(_last_income[bt]) + BASE_INCOME
	# Nodes pay every unit mining them (adjacent, mobile), up to 2 miners
	# per node per tick — more miners on a vein means faster supply.
	for node in e._dungeon_entities:
		if not bool(node.get("is_resource_node", false)):
			continue
		if bool(node.get("looted", false)) or bool(node.get("is_dead", false)):
			continue
		var payouts: int = 0
		for ent in e._dungeon_entities:
			if payouts >= 2:
				break
			if bool(ent.get("is_dead", false)) or bool(ent.get("is_chest", false)):
				continue
			if not ent.has("battle_team"):
				continue
			if int(ent.get("speed", 0)) <= 0:
				continue   # buildings don't mine
			if _chebyshev(ent, node) > 1:
				continue
			var mt: int = int(ent["battle_team"])
			if mt >= 0 and mt < num_teams:
				_last_income[mt] = int(_last_income[mt]) + MINE_INCOME
				if mt < _supply_mined.size():
					_supply_mined[mt] = int(_supply_mined[mt]) + MINE_INCOME
				payouts += 1
		if payouts == 0:
			continue
		# Finite reserves: debit the vein per payout. Depleted veins refill
		# after REPLENISH_TIME (see the replenish pass above).
		node["amount"] = int(node.get("amount", 300)) - MINE_INCOME * payouts
		if int(node["amount"]) <= 0:
			node["looted"] = true
			node["name"] = "Depleted Node"
			node["replenish_at"] = _battle_time + REPLENISH_TIME
			battle_log_extra.append(
				"⛏ A resource node has been exhausted! (refills in %d min)" % [
					int(REPLENISH_TIME / 60.0)])
	# Tech-building perks: the Old Mint pays its owner, the Derelict
	# Shrine pulses healing over the owner's nearby wounded units.
	for tb in e._dungeon_entities:
		if bool(tb.get("is_dead", false)):
			continue
		var tk: String = str(tb.get("structure_kind", ""))
		if not tk.begins_with("tech_"):
			continue
		var tt: int = int(tb.get("battle_team", -1))
		if tt < 0 or tt >= num_teams:
			continue   # still derelict — no owner, no perk
		if tk == "tech_mint":
			_last_income[tt] = int(_last_income[tt]) + 8
		elif tk == "tech_shrine":
			for u in e._dungeon_entities:
				if bool(u.get("is_dead", false)) or bool(u.get("is_chest", false)):
					continue
				if int(u.get("battle_team", -1)) != tt:
					continue
				if int(u.get("speed", 0)) <= 0:
					continue
				if _chebyshev(u, tb) > 5:
					continue
				if int(u.get("hp", 0)) < int(u.get("max_hp", 0)):
					u["hp"] = mini(int(u["max_hp"]), int(u["hp"]) + 4)
	for t in range(num_teams):
		supply[t] = int(supply[t]) + int(_last_income[t])

## Supply the team earned during the most recent income tick.
func get_last_income(team: int) -> int:
	if team < 0 or team >= _last_income.size():
		return 0
	return int(_last_income[team])

## How many of the team's units currently sit adjacent to an unlooted node.
func get_miner_count(team: int) -> int:
	var e = _engine()
	if e == null:
		return 0
	var nodes: Array = []
	for ent in e._dungeon_entities:
		if bool(ent.get("is_resource_node", false)) \
				and not bool(ent.get("looted", false)) \
				and not bool(ent.get("is_dead", false)):
			nodes.append(ent)
	var n: int = 0
	for ent in e._dungeon_entities:
		if bool(ent.get("is_dead", false)) or bool(ent.get("is_chest", false)):
			continue
		if int(ent.get("battle_team", -1)) != team:
			continue
		if int(ent.get("speed", 0)) <= 0:
			continue   # buildings never count as miners
		for node in nodes:
			if _chebyshev(ent, node) <= 1:
				n += 1
				break
	return n

# ──────────────────────────────────────────────────────────────────────────
# Real-time simulation core
# ──────────────────────────────────────────────────────────────────────────

## One fixed 10 Hz simulation step: unit brains, production queues, income,
## condition ticks, staggered AI thinks, sudden death.
func _sim_step(dt: float) -> void:
	var e = _engine()
	if e == null or finished:
		return
	_battle_time += dt

	# ── O(n) once per step: id index + tile occupancy + spatial hash ─────
	_paths_this_step = 0
	_occ_ms = int(e.MAP_SIZE)
	_ent_index.clear()
	_occ.clear()
	_spatial.clear()
	_team_ents.clear()
	_team_ents.resize(num_teams)
	for _ti in range(num_teams):
		_team_ents[_ti] = []
	_team_structs.clear()
	_team_bases.clear()
	for it_v in e._dungeon_entities:
		var it: Dictionary = it_v
		if bool(it.get("is_dead", false)):
			continue
		var id_str: String = str(it.get("id", ""))
		var ix: int = int(it.get("x", 0))
		var iy: int = int(it.get("y", 0))
		_ent_index[id_str] = it
		_occ[iy * _occ_ms + ix] = id_str
		# Large units (kaiju, hulking vehicles) claim their whole body — every
		# tile within Chebyshev radius (size-1) — so other units path around
		# the body instead of walking through it. Real occupants keep their
		# claim (footprint never overwrites an already-taken tile), and the
		# mover's own movement code treats own-id tiles as free.
		var esz: int = int(it.get("size", 1))
		if esz > 1:
			var rad: int = esz - 1
			for foy in range(-rad, rad + 1):
				for fox in range(-rad, rad + 1):
					if fox == 0 and foy == 0:
						continue
					var fcx: int = ix + fox
					var fcy: int = iy + foy
					if fcx < 0 or fcy < 0 or fcx >= _occ_ms or fcy >= _occ_ms:
						continue
					var fkey: int = fcy * _occ_ms + fcx
					if not _occ.has(fkey):
						_occ[fkey] = id_str
		if bool(it.get("is_chest", false)):
			continue
		# Spatial hash cell.
		var cell_key: int = (iy / CELL_SIZE) * 1000 + (ix / CELL_SIZE)
		if not _spatial.has(cell_key):
			_spatial[cell_key] = [it]
		else:
			_spatial[cell_key].append(it)
		# Per-team lists.
		if not it.has("battle_team"):
			continue
		var bt: int = int(it.get("battle_team", -1))
		if bt >= 0 and bt < num_teams:
			_team_ents[bt].append(it)
			if bool(it.get("is_battle_base", false)):
				_team_bases[bt] = it
			if bool(it.get("is_battle_structure", false)):
				var sk: String = str(it.get("structure_kind", ""))
				if not _team_structs.has(bt):
					_team_structs[bt] = {}
				var ts: Dictionary = _team_structs[bt]
				ts[sk] = int(ts.get(sk, 0)) + 1
	e._rebuild_occ_grid()

	# ── Per-entity brains ────────────────────────────────────────────────
	# Snapshot the size: spawns append to the end and act next tick.
	var ents: Array = e._dungeon_entities
	var n: int = ents.size()
	for i in range(n):
		if finished:
			return
		var ent: Dictionary = ents[i]
		if bool(ent.get("is_dead", false)) or bool(ent.get("is_chest", false)):
			continue
		if not ent.has("battle_team"):
			continue
		_sim_unit_step(ent, dt)

	# ── Production queues ────────────────────────────────────────────────
	_tick_queues(dt)

	# ── Superweapon strike cooldowns ─────────────────────────────────────
	for si in range(_strike_cd.size()):
		_strike_cd[si] = maxf(0.0, float(_strike_cd[si]) - dt)

	# ── Region hazard pulses ─────────────────────────────────────────────
	if region_effect != "" and region_effect != "rift":
		_region_fx_timer -= dt
		if _region_fx_timer <= 0.0:
			_region_fx_timer = randf_range(30.0, 55.0)
			_region_hazard_pulse()

	# ── Living map: wild kaiju event + supply crate drops ────────────────
	if not _kaiju_spawned and not sandbox and _battle_time >= KAIJU_EVENT_TIME:
		_kaiju_spawned = true
		_spawn_wild_kaiju()
	_crate_timer -= dt
	if _crate_timer <= 0.0:
		_crate_timer = randf_range(CRATE_MIN_PERIOD, CRATE_MAX_PERIOD)
		_spawn_crate()

	# ── Income (every 5 s) ───────────────────────────────────────────────
	_income_timer -= dt
	if _income_timer <= 0.0:
		_income_timer += INCOME_PERIOD
		_prune_corpses()
		_assign_ai_miners()
		_apply_income()
		for t in range(num_teams):
			sim_event.emit("income", {"team": t, "amount": get_last_income(t)})

	# ── Conditions (every 3 s — keeps DoT balance close to per-round) ────
	_cond_timer -= dt
	if _cond_timer <= 0.0:
		_cond_timer += CONDITION_PERIOD
		_tick_all_conditions()

	# ── Custom aura spells (pulse every 3 s) ─────────────────────────────
	_aura_timer -= dt
	if _aura_timer <= 0.0:
		_aura_timer += AURA_PERIOD
		_tick_auras()

	# ── AI thinks (every 2 s per team, staggered) ────────────────────────
	for t in range(num_teams):
		if finished:
			return
		if (t == player_team and not spectator) or t >= _ai_next_think.size():
			continue
		if not bool(team_alive[t]):
			continue
		if _battle_time >= float(_ai_next_think[t]):
			_ai_next_think[t] = _battle_time + AI_THINK_PERIOD
			_ai_think(t)

	# ── Victory: elimination only — no time limit or sudden death. ───────
	# The battle ends when _check_team_elim() finds <= 1 team alive.

## Brain for one living battle entity: cooldowns, target resolution, one
## attack per swing, pathing movement, spell autocast.
func _sim_unit_step(ent: Dictionary, dt: float) -> void:
	var e = _engine()
	if e == null:
		return
	# Cooldowns always tick down.
	ent["move_cd"] = maxf(0.0, float(ent.get("move_cd", 0.0)) - dt)
	ent["attack_cd"] = maxf(0.0, float(ent.get("attack_cd", 0.0)) - dt)
	ent["repath_cd"] = maxf(0.0, float(ent.get("repath_cd", 0.0)) - dt)
	ent["scan_cd"] = maxf(0.0, float(ent.get("scan_cd", 0.0)) - dt)
	for sp in ent.get("spells", []):
		sp["cd_left"] = maxf(0.0, float(sp.get("cd_left", 0.0)) - dt)
	if "stunned" in ent.get("conditions", []):
		return

	var team: int = int(ent.get("battle_team", -1))
	var is_structure: bool = int(ent.get("speed", 0)) <= 0

	# ── Target resolution ────────────────────────────────────────────────
	var tgt = null
	var tid: String = str(ent.get("order_target", ""))
	if tid != "":
		tgt = _rt_find(tid)
		# Clear orders on dead targets AND on targets that joined our side
		# (mind control / engineer capture can flip a target mid-order).
		if tgt == null or bool(tgt.get("is_dead", false)) \
				or int(tgt.get("battle_team", -2)) == team:
			ent["order_target"] = ""
			tgt = null
	if tgt == null:
		# Cached auto-acquired target first (O(1)); full scans only run on
		# the ~0.5 s scan timer, so 150 idle units don't rescan every tick.
		var atid: String = str(ent.get("auto_tgt", ""))
		if atid != "":
			var cached = _ent_index.get(atid)
			if cached != null and not bool(cached.get("is_dead", false)) \
					and int(cached.get("battle_team", -2)) != team \
					and _chebyshev(ent, cached) <= SIGHT_RANGE + 4:
				tgt = cached
			else:
				ent["auto_tgt"] = ""
		if tgt == null and float(ent.get("scan_cd", 0.0)) <= 0.0 \
				and not bool(ent.get("is_engineer", false)):
			ent["scan_cd"] = 0.4 + randf() * 0.2
			if is_structure:
				if str(ent.get("structure_kind", "")) == "turret":
					# Guard Turrets watch a 6-tile perimeter.
					tgt = _nearest_enemy_of(ent, 6)
				else:
					# Other structures only return fire on adjacent foes.
					tgt = _adjacent_enemy_of(ent)
			elif bool(ent.get("aggro", false)) or str(ent.get("stance", "")) == "patrol":
				# Attack-movers and patrols auto-acquire at full sight range.
				tgt = _nearest_enemy_of(ent)
			elif team != player_team:
				# AI vigilance scales with difficulty — easy AI is near-sighted.
				tgt = _nearest_enemy_of(ent, _ai_sight())
			else:
				# Idle player units hold position but defend themselves.
				tgt = _adjacent_enemy_of(ent)
			if tgt != null:
				ent["auto_tgt"] = str(tgt.get("id", ""))

	# ── Attack / chase ───────────────────────────────────────────────────
	if tgt != null:
		var mode: String = str(ent.get("atk_mode", "auto"))
		var rng: int = _attack_range(ent)
		var magic_only: bool = false
		if mode == "magic":
			# Casters hold at spell range instead of charging into melee.
			var srng: int = _offensive_spell_range(ent)
			if srng > 0:
				rng = srng
				magic_only = true
		var d: int = _chebyshev(ent, tgt)
		# Large targets are hit at their body EDGE: a unit standing beside a
		# kaiju's multi-tile footprint is in melee reach of the body even
		# though the kaiju's center tile is (size-1) tiles further away.
		d -= maxi(0, int(tgt.get("size", 1)) - 1)
		if d <= rng:
			# Engineers CAPTURE enemy structures on contact (consumed).
			if bool(ent.get("is_engineer", false)) and d <= 1 \
					and (bool(tgt.get("is_battle_structure", false))
						or bool(tgt.get("is_battle_base", false))):
				_capture_structure(ent, tgt)
				return
			# ONE attack per swing — C&C style, no burst multi-attacks.
			# Magic-only units keep the blade sheathed; autocast below does
			# the fighting on the spells' own cooldowns.
			if not magic_only and float(ent.get("attack_cd", 0.0)) <= 0.0:
				_rt_attack(ent, tgt)
		elif not is_structure:
			if not _guard_blocks_chase(ent, tgt):
				_rt_move_toward(ent, int(tgt["x"]), int(tgt["y"]), tgt)
	elif not is_structure:
		# ── Standing move order / miner park ─────────────────────────────
		var dx: int = int(ent.get("order_dest_x", -1))
		var dy: int = int(ent.get("order_dest_y", -1))
		if dx >= 0 and dy >= 0:
			if int(ent["x"]) == dx and int(ent["y"]) == dy:
				ent["order_dest_x"] = -1
				ent["order_dest_y"] = -1
				ent["aggro"] = false
				ent["path"] = []
			elif maxi(absi(int(ent["x"]) - dx), absi(int(ent["y"]) - dy)) <= 3:
				# Group arrival settling: within 3 tiles of the marker a
				# unit gets 3 more tile-moves, then parks where it is —
				# no endless fidgeting for spots its own group filled.
				var dest_tag: String = "%d,%d" % [dx, dy]
				var pos_tag: String = "%d,%d" % [int(ent["x"]), int(ent["y"])]
				if str(ent.get("settle_for", "")) != dest_tag:
					ent["settle_for"] = dest_tag     # new order — re-arm
					ent["settle_pos"] = pos_tag
					ent["settle_steps"] = 3
				elif str(ent.get("settle_pos", "")) != pos_tag:
					ent["settle_pos"] = pos_tag      # moved a tile in the zone
					ent["settle_steps"] = int(ent.get("settle_steps", 3)) - 1
				if int(ent.get("settle_steps", 3)) <= 0:
					ent["order_dest_x"] = -1         # close enough — stand down
					ent["order_dest_y"] = -1
					ent["aggro"] = false
					ent["path"] = []
				else:
					_rt_move_toward(ent, dx, dy, null)
			else:
				_rt_move_toward(ent, dx, dy, null)
		elif str(ent.get("stance", "")) == "patrol":
			# Patrol loop: walk leg A ↔ leg B, engaging what crosses the route.
			var leg: int = int(ent.get("patrol_leg", 1))
			var lx: int = int(ent.get("patrol_bx", ent["x"])) if leg == 1 \
				else int(ent.get("patrol_ax", ent["x"]))
			var ly: int = int(ent.get("patrol_by", ent["y"])) if leg == 1 \
				else int(ent.get("patrol_ay", ent["y"]))
			if maxi(absi(int(ent["x"]) - lx), absi(int(ent["y"]) - ly)) <= 1:
				ent["patrol_leg"] = 0 if leg == 1 else 1
			else:
				_rt_move_toward(ent, lx, ly, null)
		elif str(ent.get("stance", "")) == "guard":
			# Off-duty guard: drift back to the post.
			var gx2: int = int(ent.get("guard_x", ent["x"]))
			var gy2: int = int(ent.get("guard_y", ent["y"]))
			if maxi(absi(int(ent["x"]) - gx2), absi(int(ent["y"]) - gy2)) > 1:
				_rt_move_toward(ent, gx2, gy2, null)
		elif str(ent.get("miner_node_id", "")) != "":
			# Mining duty (ANY team, player included): close to within 1 tile
			# of the node and hold; re-approach whenever bumped away.
			var node = _rt_find(str(ent["miner_node_id"]))
			if node == null or bool(node.get("is_dead", false)):
				ent["miner_node_id"] = ""
			elif bool(node.get("looted", false)):
				# Vein spent — harvester logic: relocate to the nearest live
				# vein on the map. If every vein is dry, wait here (this one
				# refills in 3 minutes) and resume automatically.
				ent["mine_scan_cd"] = float(ent.get("mine_scan_cd", 0.0)) - dt
				if float(ent["mine_scan_cd"]) <= 0.0:
					ent["mine_scan_cd"] = 1.0 + randf() * 0.5
					var alt = _nearest_live_node(ent)
					if alt != null:
						ent["miner_node_id"] = str(alt["id"])
						ent["path"] = []
						if team == player_team:
							battle_log_extra.append(
								"⛏ %s moves to a fresh vein." % str(ent.get("name", "?")))
			elif _chebyshev(ent, node) > 1:
				_rt_move_toward(ent, int(node["x"]), int(node["y"]), node)

	# ── Spell autocast (throttled: target search is the expensive part) ──
	if not is_structure and not (ent.get("spells", []) as Array).is_empty():
		ent["spell_scan_cd"] = maxf(0.0, float(ent.get("spell_scan_cd", 0.0)) - dt)
		if float(ent["spell_scan_cd"]) <= 0.0:
			ent["spell_scan_cd"] = 0.4
			_rt_autocast(ent, tgt)
			# Heal-seeking: if no enemy target is in range and the unit has a
			# heal spell, drift toward the most wounded nearby ally so the heal
			# can fire on the next scan tick.
			if tgt == null and str(ent.get("order_target", "")) == "":
				for sp in ent.get("spells", []):
					var sn: String = str(sp.get("name", ""))
					if not e._SPELL_DB.has(sn):
						continue
					var sd: Dictionary = e._SPELL_DB[sn]
					if _spell_kind(sd) == "heal":
						var patient = _most_wounded_ally(ent, 12)
						if patient != null and patient != ent:
							_rt_move_toward(ent, int(patient["x"]), int(patient["y"]), patient)
						break

## Set a movement STANCE for a selection:
##   "off"    — normal behavior (chase what you fight)
##   "guard"  — hold this position; fight what comes close, never chase
##              beyond ~6 tiles of the post, walk back when it's over
##   "patrol" — loop between the unit's current spot and (px, py),
##              auto-engaging anything sighted on the route
func set_stance(ids: Array, stance: String, px: int = -1, py: int = -1) -> int:
	if stance not in ["off", "guard", "patrol"]:
		return 0
	var e = _engine()
	if e == null:
		return 0
	var n: int = 0
	for uid_v in ids:
		var ent = e._dung_find(str(uid_v))
		if ent == null or bool(ent.get("is_dead", false)):
			continue
		if int(ent.get("battle_team", -1)) != player_team:
			continue
		if int(ent.get("speed", 0)) <= 0:
			continue
		match stance:
			"off":
				ent["stance"] = ""
			"guard":
				ent["stance"] = "guard"
				ent["guard_x"] = int(ent.get("x", 0))
				ent["guard_y"] = int(ent.get("y", 0))
			"patrol":
				if px < 0 or py < 0:
					continue
				ent["stance"] = "patrol"
				ent["patrol_ax"] = int(ent.get("x", 0))
				ent["patrol_ay"] = int(ent.get("y", 0))
				ent["patrol_bx"] = px
				ent["patrol_by"] = py
				ent["patrol_leg"] = 1
		ent["order_target"] = ""
		ent["order_dest_x"] = -1
		ent["order_dest_y"] = -1
		ent["miner_node_id"] = ""
		ent["auto_tgt"] = ""
		ent["aggro"] = false
		ent["path"] = []
		n += 1
	return n

## Guard-stance leash: refuse to chase targets far from the post, and walk
## home once the unit has strayed. Returns true when the chase is blocked.
func _guard_blocks_chase(ent: Dictionary, tgt: Dictionary) -> bool:
	if str(ent.get("stance", "")) != "guard":
		return false
	var gx: int = int(ent.get("guard_x", int(ent.get("x", 0))))
	var gy: int = int(ent.get("guard_y", int(ent.get("y", 0))))
	if maxi(absi(int(tgt.get("x", 0)) - gx), absi(int(tgt.get("y", 0)) - gy)) <= 6:
		return false   # close enough to the post — fight it
	ent["auto_tgt"] = ""
	if maxi(absi(int(ent.get("x", 0)) - gx), absi(int(ent.get("y", 0)) - gy)) > 1:
		_rt_move_toward(ent, gx, gy, null)
	return true

## Set how a selection fights: "auto" (weapons + spells), "weapons"
## (offensive spells sheathed; heals/buffs still cast) or "magic" (weapon
## sheathed while any offensive spell is equipped; holds at spell range).
## Returns how many units accepted the mode.
func set_attack_mode(ids: Array, mode: String) -> int:
	if mode not in ["auto", "weapons", "magic"]:
		return 0
	var e = _engine()
	if e == null:
		return 0
	var n: int = 0
	for uid_v in ids:
		var ent = e._dung_find(str(uid_v))
		if ent == null or bool(ent.get("is_dead", false)):
			continue
		if int(ent.get("battle_team", -1)) != player_team:
			continue
		if int(ent.get("speed", 0)) <= 0:
			continue
		ent["atk_mode"] = mode
		ent["path"] = []   # re-evaluate approach range next tick
		n += 1
	return n

## Battle-only spell tuning. Ranges and cooldowns are HALVED versus the story
## RPG — a Battle-Mode balance choice — WITHOUT touching the shared _SPELL_DB
## (story combat keeps the original rt / sc values). Every place the battle sim
## reads a spell's range or sets its cooldown routes through these.
const BATTLE_SPELL_RANGE_MUL := 0.5
const BATTLE_SPELL_CD_MUL := 0.5
## Battle Mode casters pay in BLOOD, not SP: a spell costs its SP ÷ 10 in HP
## (rounded up, minimum 1) and then sits on its cooldown timer. Story mode's
## SP economy is untouched.
const BATTLE_SPELL_HP_DIV := 10.0

## HP a battle unit pays to cast `s` — SP ÷ 10, rounded up, floored at 1.
func battle_spell_hp_cost(s: Dictionary) -> int:
	return maxi(1, int(ceil(float(int(s.get("sc", 1))) / BATTLE_SPELL_HP_DIV)))

## Halved casting range for a spell dict, in tiles. Floors at 1 for any spell
## that reaches (rt >= 1) so a short-range spell never collapses to range 0;
## the original code already clamped rt into [1, 20] the same way.
func _battle_spell_range(s: Dictionary) -> int:
	var raw: int = clampi(int(s.get("rt", 1)), 1, 20)
	return maxi(1, int(floor(float(raw) * BATTLE_SPELL_RANGE_MUL)))

## Longest range among the unit's equipped OFFENSIVE spells (damage/curse),
## or 0 when it has none (magic mode then falls back to the weapon).
func _offensive_spell_range(ent: Dictionary) -> int:
	var spells: Array = ent.get("spells", [])
	if spells.is_empty():
		return 0
	var e = _engine()
	if e == null:
		return 0
	e._ensure_spell_db()
	var best: int = 0
	for sp in spells:
		var n: String = str(sp.get("name", ""))
		if not e._SPELL_DB.has(n):
			continue
		var s: Dictionary = e._SPELL_DB[n]
		if not bool(s.get("atk", false)):
			continue
		best = maxi(best, _battle_spell_range(s))
	return best

## Attack reach in tiles: bows shoot 6, everything else is melee (Chebyshev 1).
func _attack_range(ent: Dictionary) -> int:
	if str(ent.get("equipped_weapon", "")).to_lower().contains("bow"):
		return 6
	return 1

## One real-time swing: full engine hit/damage math, then cooldown, event,
## and death bookkeeping.
func _rt_attack(ent: Dictionary, tgt: Dictionary) -> void:
	var e = _engine()
	if e == null:
		return
	var weapon: String = str(ent.get("equipped_weapon", "Unarmed"))
	var is_unarmed: bool = weapon == "" or weapon == "None" or weapon == "Unarmed"
	var result: Dictionary = e._dung_do_attack(ent, tgt, weapon, is_unarmed)
	ent["attack_cd"] = maxf(0.2, float(ent.get("atk_interval", 1.5)))
	var line: String = str(result.get("log", ""))
	if line != "":
		battle_log_extra.append(line)
	# Debug: name the attacker, victim and distance on every swing, so a
	# "who is hitting me?" moment always has an answer in the log.
	if bool(GameState.debug_mode):
		battle_log_extra.append("🐞 %s → %s at distance %d (weapon range %d)" % [
			str(ent.get("name", "?")), str(tgt.get("name", "?")),
			_chebyshev(ent, tgt), _attack_range(ent)])
	sim_event.emit("attack", {
		"attacker": str(ent.get("id", "")),
		"target":   str(tgt.get("id", "")),
		"text":     line,
	})
	if bool(result.get("target_dead", false)) or int(tgt.get("hp", 1)) <= 0:
		_rt_handle_death(tgt)
		_award_kill(ent)
		_award_bounty(int(ent.get("battle_team", -1)), tgt)

## Kill-count veterancy: ★ at VET_KILLS_1, ★★ at VET_KILLS_2. Each rank is
## +25 max HP (healed by the same amount) and +1 to-hit — earned, unlike the
## Barracks' paid veteran upgrade, which stacks with it.
func _award_kill(ent: Dictionary) -> void:
	if bool(ent.get("is_dead", false)):
		return
	var k: int = int(ent.get("kills", 0)) + 1
	ent["kills"] = k
	# Score bookkeeping: team kill tally + MVP (most personal kills).
	var kt: int = int(ent.get("battle_team", -1))
	if kt >= 0 and kt < _team_kills.size():
		_team_kills[kt] = int(_team_kills[kt]) + 1
	if k > int(_mvp.get("kills", 0)):
		_mvp = {"name": str(ent.get("name", "?")), "kills": k, "team": kt}
	var want: int = 0
	if k >= VET_KILLS_2:
		want = 2
	elif k >= VET_KILLS_1:
		want = 1
	if want <= int(ent.get("vet_rank", 0)):
		return
	ent["vet_rank"] = want
	ent["max_hp"] = int(ent.get("max_hp", 10)) + 25
	ent["hp"] = int(ent.get("hp", 1)) + 25
	ent["hit_bonus_buff"] = int(ent.get("hit_bonus_buff", 0)) + 1
	var base_name: String = str(ent.get("name", "")) \
		.trim_suffix(" ★★").trim_suffix(" ★")
	var stars: String = "★" if want == 1 else "★★"
	ent["name"] = "%s %s" % [base_name, stars]
	battle_log_extra.append("🎖 %s earns %s veterancy! (+25 HP, +1 to-hit)" % [
		base_name, stars])
	sim_event.emit("promote", {"id": str(ent.get("id", "")), "rank": want})

## Engineer takeover: the structure joins the engineer's team wholesale;
## the engineer is consumed. Capturing a Command Post steals PRODUCTION.
func _capture_structure(eng: Dictionary, s: Dictionary) -> void:
	var t: int = int(eng.get("battle_team", -1))
	var old: int = int(s.get("battle_team", -1))
	if t < 0 or old == t:
		return
	var kind: String = str(s.get("structure_kind", ""))
	var label: String = str(STRUCTURE_KINDS.get(kind, {}).get(
		"label", s.get("tech_label", "Structure")))
	_apply_team_flags(s, t)
	s["name"] = "T%d %s" % [t, label]
	s["order_target"] = ""
	s["auto_tgt"] = ""
	if t < _captures.size():
		_captures[t] = int(_captures[t]) + 1
	if old == NEUTRAL_TEAM:
		var perks := {"tech_shrine": "its healing aura mends your nearby troops",
			"tech_watch": "its height grants enormous sight",
			"tech_mint": "it pays +8⛃ every income tick"}
		battle_log_extra.append("🏚 %s claims the %s — %s!" % [
			_team_label(t), label, str(perks.get(kind, "an old power stirs"))])
	else:
		battle_log_extra.append("🔧 %s CAPTURES a %s from %s!" % [
			_team_label(t), label, _team_label(old)])
	sim_event.emit("capture", {"id": str(s.get("id", "")), "team": t, "from": old})
	# The engineer is spent in the takeover (standard C&C rules).
	eng["hp"] = 0
	eng["death_announced"] = true   # suppress the "destroyed!" line
	_rt_handle_death(eng)
	eng["is_dead"] = true
	eng["death_time"] = _battle_time
	# Losing your last base to a wrench is as fatal as losing it to a sword.
	_check_team_elim(old)

## ── Mind control (Yuri rules) ────────────────────────────────────────────
## A controlled unit fights for the caster's team while the caster lives.
## One thrall per controller — a new grab releases the old one.
func _mc_convert(caster: Dictionary, tgt: Dictionary) -> bool:
	if bool(tgt.get("is_boss", false)) or bool(tgt.get("is_battle_structure", false)) \
			or bool(tgt.get("is_battle_base", false)) \
			or bool(tgt.get("is_resource_node", false)):
		return false
	var t: int = int(caster.get("battle_team", -1))
	if t < 0 or int(tgt.get("battle_team", -1)) == t:
		return false
	_mc_release(str(caster.get("id", "")))
	tgt["mc_by"] = str(caster.get("id", ""))
	tgt["mc_orig_team"] = int(tgt.get("battle_team", -1))
	_apply_team_flags(tgt, t)
	tgt["order_target"] = ""
	tgt["order_dest_x"] = -1
	tgt["order_dest_y"] = -1
	tgt["aggro"] = false
	tgt["auto_tgt"] = ""
	tgt["miner_node_id"] = ""
	tgt["path"] = []
	battle_log_extra.append("🧠 %s seizes the mind of %s!" % [
		str(caster.get("name", "?")), str(tgt.get("name", "?"))])
	sim_event.emit("mind_control", {"id": str(tgt.get("id", "")), "team": t})
	return true

## Release every thrall bound to this controller (called when the controller
## dies or grabs a new mind).
func _mc_release(caster_id: String) -> void:
	if caster_id == "":
		return
	var e = _engine()
	if e == null:
		return
	for ent in e._dungeon_entities:
		if str(ent.get("mc_by", "")) != caster_id:
			continue
		ent["mc_by"] = ""
		if bool(ent.get("is_dead", false)):
			continue
		_apply_team_flags(ent, int(ent.get("mc_orig_team", 0)))
		ent["order_target"] = ""
		ent["order_dest_x"] = -1
		ent["order_dest_y"] = -1
		ent["aggro"] = false
		ent["auto_tgt"] = ""
		ent["path"] = []
		battle_log_extra.append(
			"🧠 %s shakes off the mind control!" % str(ent.get("name", "?")))

## Step one tile along a cached path toward (tx, ty). Re-paths when the
## cache is empty, stale (goal moved), blocked, or repath_cd expired.
func _rt_move_toward(ent: Dictionary, tx: int, ty: int, tgt_ent) -> void:
	var e = _engine()
	if e == null:
		return
	if float(ent.get("move_cd", 0.0)) > 0.0:
		return
	var path: Array = ent.get("path", [])
	# Oscillation escape armed (see _rt_note_step): skip the greedy shortcut
	# and let the A* block below plot a real route around the obstacle.
	var force_repath: bool = bool(ent.get("force_repath", false))
	# ── Greedy crowd movement: try the sides toward the goal, ordered by
	# progress. Blocked by a UNIT → wait a beat (crowds compress; NEVER run
	# A* for a traffic jam — with 150+ units that's what causes freezes).
	# Blocked by TERRAIN on every useful side → fall through to real A*.
	if path.is_empty() and not force_repath:
		var ex: int = int(ent["x"])
		var ey: int = int(ent["y"])
		var sx: int = signi(tx - ex)
		var sy: int = signi(ty - ey)
		var dirs: Array = []
		if absi(tx - ex) >= absi(ty - ey):
			if sx != 0: dirs.append(Vector2i(sx, 0))
			if sy != 0: dirs.append(Vector2i(0, sy))
			else: dirs.append(Vector2i(0, 1) if randf() < 0.5 else Vector2i(0, -1))
		else:
			if sy != 0: dirs.append(Vector2i(0, sy))
			if sx != 0: dirs.append(Vector2i(sx, 0))
			else: dirs.append(Vector2i(1, 0) if randf() < 0.5 else Vector2i(-1, 0))
		var unit_blocked: bool = false
		for d_v in dirs:
			var d: Vector2i = d_v
			var nx: int = ex + d.x
			var ny: int = ey + d.y
			if e._dung_tile(nx, ny) != 1:
				continue   # terrain on this side — try the other
			var side_occ: String = str(_occ.get(ny * _occ_ms + nx, ""))
			if side_occ != "" and side_occ != str(ent.get("id", "")):
				unit_blocked = true
				continue   # someone's standing there — try the other side
			_rt_step(ent, nx, ny)
			_rt_note_step(ent)
			return
		if unit_blocked:
			# Traffic jam: shuffle again in a quarter second.
			ent["move_cd"] = 0.25
			return
	var want: Vector2i = Vector2i(tx, ty)
	var goal: Vector2i = Vector2i(int(ent.get("path_gx", -9)), int(ent.get("path_gy", -9)))
	var blocked: bool = false
	if not path.is_empty():
		var peek: Vector2i = path[0]
		if e._dung_tile(peek.x, peek.y) != 1:
			blocked = true
		else:
			var blk_id: String = str(_occ.get(peek.y * _occ_ms + peek.x, ""))
			if blk_id != "" and blk_id != str(ent.get("id", "")) \
					and (tgt_ent == null
					or blk_id != str(tgt_ent.get("id", ""))):
				blocked = true
	if path.is_empty() or blocked or goal != want \
			or float(ent.get("repath_cd", 0.0)) <= 0.0:
		if float(ent.get("repath_cd", 0.0)) > 0.0 and path.is_empty() \
				and not force_repath:
			return   # failure backoff active — don't re-flood the pathfinder
		if _paths_this_step >= _path_budget:
			ent["move_cd"] = 0.2   # budget spent — spread demand out
			return
		_paths_this_step += 1
		path = _rt_pathfind(ent, tx, ty)
		ent["path"] = path
		ent["path_gx"] = tx
		ent["path_gy"] = ty
		# Success → re-path in 2 s. Failure (unreachable/enclosed) → back off
		# 1.5-2.5 s so a jammed army can't flood full-map BFS every tick.
		ent["repath_cd"] = 2.0 if not path.is_empty() else (1.5 + randf())
		# Oscillation escape spent: a real A* ran. On success the cached path
		# is followed until consumed/invalid (greedy only runs when it's
		# empty); on failure greedy resumes and the watchdog may re-arm.
		ent["force_repath"] = false
	if path.is_empty():
		return
	var step: Vector2i = path[0]
	# Final gate: only walk onto clear floor (the fresh path may still lead
	# through a tile someone stepped onto this tick). Tiles claimed by the
	# mover's OWN body footprint count as free.
	if not _tile_free_for(ent, step.x, step.y):
		return
	path.pop_front()
	_rt_step(ent, step.x, step.y)
	_rt_note_step(ent)

## Two-tile ping-pong watchdog, fed after every committed step. The greedy
## shortcut in _rt_move_toward can bounce a unit A→B→A forever beside an
## obstacle (the sidestep succeeds, then the goal pulls it straight back)
## without ever reaching the A* block. Remember the last two distinct tiles
## ("x,y" strings); landing back on the tile-before-last counts as one
## bounce. More than 5 bounces → drop the cache and arm force_repath so the
## next move tick skips the greedy shortcut and plots a REAL route around
## the obstacle. Cost per step: one small string + a few dict slots.
func _rt_note_step(ent: Dictionary) -> void:
	var here: String = "%d,%d" % [int(ent["x"]), int(ent["y"])]
	if here == str(ent.get("osc_b", "")):
		ent["osc_n"] = int(ent.get("osc_n", 0)) + 1
		if int(ent["osc_n"]) > 5:
			ent["osc_n"] = 0
			ent["path"] = []
			ent["force_repath"] = true
	else:
		ent["osc_n"] = 0
	ent["osc_b"] = str(ent.get("osc_a", ""))
	ent["osc_a"] = here

## Remove battle corpses older than CORPSE_TIME from the roster. Without
## this every scan and render pass drags a growing graveyard behind it all
## battle long. The renderer fades vanished ids gracefully.
func _prune_corpses() -> void:
	var e = _engine()
	if e == null:
		return
	var ents: Array = e._dungeon_entities
	for i in range(ents.size() - 1, -1, -1):
		var ent: Dictionary = ents[i]
		if not bool(ent.get("is_dead", false)):
			continue
		if not ent.has("battle_team"):
			continue
		if bool(ent.get("is_resource_node", false)):
			continue
		if not ent.has("death_time"):
			ent["death_time"] = _battle_time   # legacy corpse — stamp, prune later
			continue
		if _battle_time - float(ent["death_time"]) >= CORPSE_TIME:
			ents.remove_at(i)

## How many living mobile units a team fields (for the army cap).
func _mobile_count(team: int) -> int:
	var e = _engine()
	if e == null:
		return 0
	var n: int = 0
	for ent in e._dungeon_entities:
		if bool(ent.get("is_dead", false)) or bool(ent.get("is_chest", false)):
			continue
		if int(ent.get("battle_team", -1)) != team:
			continue
		if int(ent.get("speed", 0)) <= 0:
			continue
		# Story heroes are bonus units — they never eat into the army cap.
		if bool(ent.get("is_hero", false)):
			continue
		n += 1
	return n

## Walkable floor with nobody standing on it (this sim step)?
func _tile_free(x: int, y: int) -> bool:
	var e = _engine()
	if e == null:
		return false
	if e._dung_tile(x, y) != 1:
		return false
	return not _occ.has(y * _occ_ms + x)

## Like _tile_free, but tiles claimed by the mover's OWN id (a large unit's
## body footprint spans several _occ tiles) count as free — otherwise a
## kaiju would jam against its own body every step.
func _tile_free_for(ent: Dictionary, x: int, y: int) -> bool:
	var e = _engine()
	if e == null:
		return false
	if e._dung_tile(x, y) != 1:
		return false
	var occ_id: String = str(_occ.get(y * _occ_ms + x, ""))
	return occ_id == "" or occ_id == str(ent.get("id", ""))

## Commit a one-tile step: keep the occupancy map live + set move cooldown.
func _rt_step(ent: Dictionary, nx: int, ny: int) -> void:
	var okey: int = int(ent.get("y", 0)) * _occ_ms + int(ent.get("x", 0))
	if str(_occ.get(okey, "")) == str(ent.get("id", "")):
		_occ.erase(okey)
	_occ[ny * _occ_ms + nx] = str(ent.get("id", ""))
	ent["x"] = nx
	ent["y"] = ny
	var tps: float = clampf(float(int(ent.get("speed", 0))) / 10.0, 1.0, 4.0)
	ent["move_cd"] = 1.0 / tps
	# ── Supply crates: step beside one to crack it open ──────────────────
	if not _crates.is_empty():
		for cid_v in _crates.duplicate():
			var crate = _ent_index.get(str(cid_v))
			if crate == null or bool(crate.get("is_dead", false)):
				_crates.erase(cid_v)
				continue
			if maxi(absi(nx - int(crate.get("x", 0))), absi(ny - int(crate.get("y", 0)))) <= 1:
				_crates.erase(cid_v)
				_collect_crate(ent, crate)
	# ── Astral rifts: step beside one 🌀, emerge beside its twin ─────────
	if region_effect == "rift" and rift_a.x >= 0 \
			and _battle_time >= float(ent.get("rift_cd", 0.0)):
		var near_a: bool = maxi(absi(nx - rift_a.x), absi(ny - rift_a.y)) <= 1
		var near_b: bool = maxi(absi(nx - rift_b.x), absi(ny - rift_b.y)) <= 1
		if near_a or near_b:
			var dest: Vector2i = rift_b if near_a else rift_a
			var spot: Vector2i = _free_tile_near(dest, 3)
			if spot.x >= 0:
				ent["rift_cd"] = _battle_time + 8.0   # no ping-pong loops
				_occ.erase(ny * _occ_ms + nx)
				_occ[spot.y * _occ_ms + spot.x] = str(ent.get("id", ""))
				ent["x"] = spot.x
				ent["y"] = spot.y
				ent["path"] = []
				battle_log_extra.append(
					"🌀 %s slips through the rift!" % str(ent.get("name", "?")))
				sim_event.emit("region_fx", {
					"type": "rift_jump", "x": spot.x, "y": spot.y, "caught": 1})

## Nearest FREE floor tile within `r` of `c` (occupancy-aware), or (-1,-1).
func _free_tile_near(c: Vector2i, r: int) -> Vector2i:
	for ring in range(0, r + 1):
		for oy in range(-ring, ring + 1):
			for ox in range(-ring, ring + 1):
				if maxi(absi(ox), absi(oy)) != ring:
					continue
				if _tile_free(c.x + ox, c.y + oy):
					return Vector2i(c.x + ox, c.y + oy)
	return Vector2i(-1, -1)

## O(1) live-entity lookup via the per-step index; falls back to the engine
## scan only for ids spawned mid-step (rare).
func _rt_find(id: String):
	var r = _ent_index.get(id)
	if r != null and not bool(r.get("is_dead", false)):
		return r
	var e = _engine()
	if e == null:
		return null
	return e._dung_find(id)

## BFS path via the engine (Array of Vector2i, start excluded). When the
## destination tile itself is blocked/occupied (e.g. it IS the target),
## path to the closest reachable adjacent tile instead.
func _rt_pathfind(ent: Dictionary, tx: int, ty: int) -> Array:
	var e = _engine()
	if e == null:
		return []
	var fx: int = int(ent["x"])
	var fy: int = int(ent["y"])
	var p: Array = e._crawl_pathfind(fx, fy, tx, ty)
	if not p.is_empty():
		return p
	# Goal blocked/occupied (e.g. it IS the target): take the FIRST reachable
	# adjacent tile — all candidates differ by ≤2 tiles, and stopping early
	# saves up to 7 extra A* runs per blocked goal.
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var q: Array = e._crawl_pathfind(fx, fy, tx + dx, ty + dy)
			if not q.is_empty():
				return q
	return []

# ──────────────────────────────────────────────────────────────────────────
# Real-time deaths / outcome
# ──────────────────────────────────────────────────────────────────────────

## Death bookkeeping for a battle entity whose HP hit 0: force is_dead
## (battle units never roll death saves), emit "death", scrub squads, and
## run the team-elimination → winner cascade. Safe to call repeatedly.
func _rt_handle_death(ent) -> void:
	if ent == null:
		return
	if int(ent.get("hp", 1)) > 0 and not bool(ent.get("is_dead", false)):
		return
	# HERO FALL, NOT DEATH: a story hero survives their FIRST defeat —
	# wounded, restored to a quarter HP, and pulled back to the base.
	# The second fall (hero_down already set) dies like any other unit.
	# Zero story impact either way: heroes are read-only battle copies.
	if bool(ent.get("is_hero", false)) and not bool(ent.get("hero_down", false)) \
			and not bool(ent.get("is_dead", false)):
		_hero_fall(ent)
		return
	ent["is_dead"] = true
	ent["is_dying"] = false
	ent["hp"] = 0
	ent["conditions"] = []
	ent["death_time"] = _battle_time   # corpse pruned after CORPSE_TIME
	if bool(ent.get("death_announced", false)):
		return
	ent["death_announced"] = true
	var team: int = int(ent.get("battle_team", -1))
	var uid: String = str(ent.get("id", ""))
	# Corpses don't block tiles or resolve as targets this step.
	_ent_index.erase(uid)
	var okey: int = int(ent.get("y", 0)) * _occ_ms + int(ent.get("x", 0))
	if str(_occ.get(okey, "")) == uid:
		_occ.erase(okey)
	sim_event.emit("death", {
		"id": uid, "name": str(ent.get("name", "")), "team": team})
	battle_log_extra.append("💀 %s is destroyed!" % str(ent.get("name", "")))
	for sid in squads:
		(squads[sid] as Array).erase(uid)
	# Score bookkeeping: mobile losses per team.
	if team >= 0 and team < _units_lost.size() and int(ent.get("speed", 0)) > 0:
		_units_lost[team] = int(_units_lost[team]) + 1
	# Mind-controllers release their thralls when they die (Yuri rules).
	_mc_release(uid)
	_check_team_elim(team)

## First defeat of a story hero: wound + retreat instead of death. The hero
## comes back at a quarter of max HP with orders cleared, teleported beside
## the player's Command Post when one still stands (occupancy grid kept
## consistent: old tile released, new tile claimed). Only ever fires once
## per battle — _rt_handle_death checks hero_down before calling this.
func _hero_fall(ent: Dictionary) -> void:
	ent["hero_down"] = true
	ent["is_dead"] = false
	ent["is_dying"] = false
	ent["hp"] = maxi(1, int(float(ent.get("max_hp", 80)) / 4.0))
	ent["conditions"] = []
	ent["path"] = []
	ent["order_dest_x"] = -1
	ent["order_dest_y"] = -1
	ent["order_target"] = ""
	ent["attack_cd"] = 1.0
	var uid: String = str(ent.get("id", ""))
	var base = _find_team_base(player_team)
	if base != null:
		var spot: Vector2i = _free_tile_near(
				Vector2i(int(base["x"]), int(base["y"])), 6)
		if spot.x < 0:
			spot = _nearest_floor(int(base["x"]), int(base["y"]), 6)
		# Occupancy bookkeeping: release the old tile, claim the new one.
		var okey: int = int(ent.get("y", 0)) * _occ_ms + int(ent.get("x", 0))
		if str(_occ.get(okey, "")) == uid:
			_occ.erase(okey)
		_occ[spot.y * _occ_ms + spot.x] = uid
		ent["x"] = spot.x
		ent["y"] = spot.y
	# The entity name already carries the "✦ " hero prefix.
	battle_log_extra.append(
		"%s is wounded and falls back!" % str(ent.get("name", "")))

## Team elimination: a team lives while ANY non-chest entity survives.
## Called on deaths AND on structure captures (losing your last base to an
## Engineer is just as fatal as losing it to a Greatsword).
func _check_team_elim(team: int) -> void:
	if team < 0 or team >= team_alive.size():
		return
	if not bool(team_alive[team]) or _team_has_living(team):
		return
	team_alive[team] = false
	sim_event.emit("elim", {"team": team})
	battle_log_extra.append("💀 Team %d has been eliminated!" % team)
	if teams_alive_count() <= 1:
		var w: int = -1
		for t in range(num_teams):
			if bool(team_alive[t]):
				w = t
				break
		_finish_battle(w)

## Everything the score screen needs, in one read-only bundle.
func get_battle_stats() -> Dictionary:
	return {
		"kills":    _team_kills.duplicate(),
		"mined":    _supply_mined.duplicate(),
		"built":    _units_built.duplicate(),
		"lost":     _units_lost.duplicate(),
		"captures": _captures.duplicate(),
		"blast":    _biggest_blast.duplicate(),
		"mvp":      _mvp.duplicate(),
		"time":     _battle_time,
	}

## Restart with the exact same loadout (the outcome modal's Rematch).
## The renderer reloads its scene right after calling this.
func rematch() -> void:
	start_battle(region_id, num_teams, unit_level, difficulty, resources,
		_last_heroes)

## Resume the sim after the outcome modal ("Watch field"): free play.
## Orders, mining, production, spells and strikes all keep working; the
## battle can't "end" a second time.
func resume_sandbox() -> void:
	if not active:
		return
	finished = false
	sandbox = true
	battle_log_extra.append("🏖 Free play — the field is yours.")

# ──────────────────────────────────────────────────────────────────────────
# DEBUG API — playtest cheats. Only ever called from the renderer's debug
# panel, which is itself gated on GameState.debug_mode. Every method no-ops
# safely when no battle is active, so leaving these callable is harmless.
# ──────────────────────────────────────────────────────────────────────────

## Grant supply to a team (debug economy button: +100 / +1000 / +10000).
func debug_add_supply(team: int, amount: int) -> void:
	if not active or team < 0 or team >= supply.size():
		return
	supply[team] = int(supply[team]) + amount
	battle_log_extra.append("🐞 DEBUG +%d⛃ → Team %d" % [amount, team + 1])

## Instantly end the battle with the player as the winner.
func debug_player_win() -> void:
	if not active:
		return
	battle_log_extra.append("🐞 DEBUG: instant victory.")
	_finish_battle(player_team)

## Force the wild-kaiju event to fire right now (living-map balance testing).
func debug_spawn_kaiju() -> void:
	if not active:
		return
	_kaiju_spawned = true
	_spawn_wild_kaiju()
	battle_log_extra.append("🐞 DEBUG: wild kaiju summoned.")

## Make a team's Arcane Strike ready immediately.
## Erect any structure for free, ignoring supply, caps and prerequisites.
## Placed next to the team's base like a normal build; falls back to any
## living unit as the anchor when the base is gone.
func debug_spawn_structure(team: int, kind: String) -> String:
	if not active or finished:
		return "No battle running."
	if not STRUCTURE_KINDS.has(kind):
		return "Unknown structure: %s" % kind
	var e = _engine()
	if e == null:
		return "Engine unavailable."
	if team < 0 or team >= num_teams:
		return "Bad team."
	var anchor = _find_team_base(team)
	if anchor == null:
		for ent in e._dungeon_entities:
			if bool(ent.get("is_dead", false)) or bool(ent.get("is_chest", false)):
				continue
			if int(ent.get("battle_team", -1)) == team:
				anchor = ent
				break
	if anchor == null:
		return "Team has nothing to build beside."
	var pos: Vector2i = _structure_spot(anchor)
	e._dungeon_entities.append(_make_structure(team, pos.x, pos.y, kind))
	battle_log_extra.append("🐞 DEBUG: Team %d conjures a %s." % [
		team, str(STRUCTURE_KINDS[kind]["label"])])
	sim_event.emit("structure", {"team": team, "kind": kind})
	return ""

## Place a structure at an exact tile for free — the debug twin of
## build_structure_at(). Supply, caps and prerequisites are skipped, but the
## tile must still be buildable so nothing ends up inside terrain.
func debug_spawn_structure_at(team: int, kind: String, x: int, y: int) -> String:
	if not active or finished:
		return "No battle running."
	if not STRUCTURE_KINDS.has(kind):
		return "Unknown structure: %s" % kind
	var e = _engine()
	if e == null:
		return "Engine unavailable."
	if team < 0 or team >= num_teams:
		return "Bad team."
	if e._dung_tile(x, y) != 1:
		return "Can't build there."
	if e._dung_entity_at(x, y) != null:
		return "That tile is occupied."
	e._dungeon_entities.append(_make_structure(team, x, y, kind))
	battle_log_extra.append("🐞 DEBUG: Team %d conjures a %s at (%d, %d)." % [
		team, str(STRUCTURE_KINDS[kind]["label"]), x, y])
	sim_event.emit("structure", {"team": team, "kind": kind})
	return ""

func debug_charge_strike(team: int) -> void:
	if not active or team < 0 or team >= _strike_cd.size():
		return
	_strike_cd[team] = 0.0
	battle_log_extra.append("🐞 DEBUG: Team %d strike charged." % (team + 1))

## Kill every enemy MOBILE unit (any team that isn't the player's, plus wild
## neutrals), leaving all structures and bases standing so the player can mop
## up the buildings. Targets are collected first, then killed, so we never
## mutate the entity list mid-iteration.
func debug_eliminate_enemy_units() -> void:
	if not active:
		return
	var e = _engine()
	if e == null:
		return
	var targets: Array = []
	for ent_v in e._dungeon_entities:
		var ent: Dictionary = ent_v
		if bool(ent.get("is_dead", false)):
			continue
		if int(ent.get("battle_team", -1)) == player_team:
			continue
		if bool(ent.get("is_battle_structure", false)) or bool(ent.get("is_battle_base", false)):
			continue
		if int(ent.get("speed", 0)) <= 0:
			continue   # immobile = structure / resource node — leave it
		targets.append(ent)
	for ent_v in targets:
		var ent: Dictionary = ent_v
		ent["hp"] = 0
		_rt_handle_death(ent)
	battle_log_extra.append("🐞 DEBUG: eliminated %d enemy unit%s." % [
		targets.size(), "" if targets.size() == 1 else "s"])

## Toggle the "invulnerable" condition on a list of unit IDs.
## Returns true if it turned invincibility ON, false if OFF.
func debug_toggle_invincible(ids: Array) -> bool:
	if not active:
		return false
	var e = _engine()
	if e == null:
		return false
	var turning_on: bool = false
	# Decide direction: if ANY selected unit is NOT invulnerable, turn all ON.
	for uid in ids:
		var ent = _ent_index.get(str(uid))
		if ent == null:
			continue
		if not e._dung_has_condition(ent, "invulnerable"):
			turning_on = true
			break
	for uid in ids:
		var ent = _ent_index.get(str(uid))
		if ent == null or bool(ent.get("is_dead", false)):
			continue
		if turning_on:
			e._dung_add_condition(ent, "invulnerable")
			# Also heal to full so invincible units aren't limping around.
			ent["hp"] = int(ent.get("max_hp", ent.get("hp", 1)))
		else:
			e._dung_remove_condition(ent, "invulnerable")
	return turning_on

## Create a custom always-on aura spell. Requires an Arcane Spire and
## enough supply. Returns "" on success or an error message string.
func create_custom_spell(spell_name: String, kind: String, dc: int, ds: int,
		area: int, conds: Array, team: int) -> String:
	if not active:
		return "No active battle."
	if spell_name.strip_edges() == "":
		return "Enter a spell name."
	if spell_name.length() > 24:
		return "Name too long (max 24 chars)."
	# Check for duplicate names.
	for cs in custom_spells:
		if str(cs["name"]) == spell_name:
			return "A spell with that name already exists."
	if not _team_has_structure(team, "spire"):
		return "Requires an Arcane Spire."
	if kind not in ["damage", "heal", "buff", "debuff"]:
		return "Invalid spell kind."
	dc = clampi(dc, 1, 4)
	ds = clampi(ds, 4, 12)
	area = clampi(area, 1, 4)
	# Calculate supply cost: base + dice power + area + conditions.
	var cost: int = 50 + dc * 20 + (ds - 4) * 5 + area * 30 + conds.size() * 40
	if int(supply[team]) < cost:
		return "Need %d supply (have %d)." % [cost, int(supply[team])]
	supply[team] = int(supply[team]) - cost
	# Build the description.
	var desc: String = ""
	match kind:
		"damage":
			desc = "Aura: %dd%d damage to enemies within %d tiles." % [dc, ds, area]
		"heal":
			desc = "Aura: %dd%d healing to allies within %d tiles." % [dc, ds, area]
		"buff":
			desc = "Aura: grants %s to allies within %d tiles." % [", ".join(PackedStringArray(conds)), area]
		"debuff":
			desc = "Aura: inflicts %s on enemies within %d tiles." % [", ".join(PackedStringArray(conds)), area]
	var spell: Dictionary = {
		"name": spell_name, "kind": kind, "dc": dc, "ds": ds,
		"area": area, "conds": conds.duplicate(), "cost": cost,
		"desc": desc, "is_custom_aura": true,
	}
	custom_spells.append(spell)
	battle_log_extra.append("✦ Custom spell created: %s — %s" % [spell_name, desc])
	return ""

## Supply cost preview for a custom spell (UI calls this before creating).
func custom_spell_cost(dc: int, ds: int, area: int, num_conds: int) -> int:
	return 50 + clampi(dc, 1, 4) * 20 + (clampi(ds, 4, 12) - 4) * 5 + clampi(area, 1, 4) * 30 + num_conds * 40

## Stop the sim and declare a winner (-1 = draw). `active` stays true so
## the renderer can keep showing the field behind its outcome modal.
func _finish_battle(w: int) -> void:
	if finished or sandbox:
		return
	finished = true
	winner = w
	if w == player_team:
		battle_log_extra.append("🏆 VICTORY — your team holds the field!")
	elif w >= 0:
		battle_log_extra.append("🏳 DEFEAT — Team %d holds the field." % w)
	else:
		battle_log_extra.append("🏳 The battle ends in a draw.")
	sim_event.emit("over", {"winner": w})

## 15-minute timeout: the team with the most total living unit HP wins.
func _sudden_death() -> void:
	var e = _engine()
	if e == null:
		return
	var best_t: int = -1
	var best_hp: int = -1
	for t in range(num_teams):
		if not bool(team_alive[t]):
			continue
		var total: int = 0
		for ent in e._dungeon_entities:
			if bool(ent.get("is_dead", false)) or bool(ent.get("is_chest", false)):
				continue
			if int(ent.get("battle_team", -1)) != t:
				continue
			total += int(ent.get("hp", 0))
		if total > best_hp:
			best_hp = total
			best_t = t
	battle_log_extra.append("⏰ 15:00 — SUDDEN DEATH! The strongest army takes the day.")
	_finish_battle(best_t)

## Run the engine's condition tick (DoTs, stun clears, speed effects) on
## every living battle entity, surface its stashed log lines, count down
## RTS spell-condition TTLs, and reap anything that dropped to 0 HP.
func _tick_all_conditions() -> void:
	var e = _engine()
	if e == null:
		return
	for ent in e._dungeon_entities:
		if bool(ent.get("is_dead", false)) or bool(ent.get("is_chest", false)):
			continue
		if not ent.has("battle_team"):
			continue
		# Damage-over-time is the ONE damage source with no attacker on the
		# field, so it must announce itself — otherwise a unit bleeding out
		# alone looks like it's being shot by nobody.
		var hp_before: int = int(ent.get("hp", 0))
		e._dung_tick_conditions(ent)
		var dot: int = hp_before - int(ent.get("hp", 0))
		if dot > 0:
			var why: Array = []
			for c in ent.get("conditions", []):
				why.append(str(c))
			sim_event.emit("dot", {
				"id": str(ent.get("id", "")),
				"x": int(ent.get("x", 0)), "y": int(ent.get("y", 0)),
				"amount": dot,
				"conds": ", ".join(PackedStringArray(why)),
			})
			battle_log_extra.append("🩸 %s loses %d HP to %s." % [
				str(ent.get("name", "?")), dot,
				", ".join(PackedStringArray(why)) if not why.is_empty() else "lingering wounds"])
		# Surface DoT log lines the engine stashed on the entity.
		if ent.has("tick_logs"):
			for line in ent["tick_logs"]:
				battle_log_extra.append(str(line))
			ent["tick_logs"] = []
		# RTS spell conditions expire after their (capped) duration.
		if ent.has("battle_cond_ttl"):
			var ttl: Dictionary = ent["battle_cond_ttl"]
			for c in ttl.keys():
				ttl[c] = int(ttl[c]) - 1
				if int(ttl[c]) <= 0:
					e._dung_remove_condition(ent, str(c))
					ttl.erase(c)
					# Speed-sapping curses restore the stored base speed.
					if (c == "slowed" or c == "restrained") and ent.has("base_speed"):
						ent["speed"] = int(ent["base_speed"])
		if int(ent.get("hp", 1)) <= 0:
			_rt_handle_death(ent)
		if finished:
			return

# ──────────────────────────────────────────────────────────────────────────
# Real-time AI
# ──────────────────────────────────────────────────────────────────────────

## One AI team's 2-second think: build order (barracks → war_factory →
## spire), production queueing, spell loadouts, and offense — all scaled by
## the battle difficulty (easy = lazy, medium = raids, hard = army waves).
func _ai_think(t: int) -> void:
	var e = _engine()
	if e == null:
		return
	# Per-difficulty economy pacing.
	var skip_prod: float
	var struct_roll: float
	var queue_cap: int
	var b_at: int; var wf_at: int; var sp_at: int
	match difficulty:
		"easy":
			skip_prod = 0.5;  struct_roll = 0.3; queue_cap = 1
			b_at = 180; wf_at = 280; sp_at = 220
		"hard":
			skip_prod = 0.0;  struct_roll = 0.7; queue_cap = 3
			b_at = 140; wf_at = 220; sp_at = 170
		_:
			skip_prod = 0.0;  struct_roll = 0.5; queue_cap = 2
			b_at = 180; wf_at = 280; sp_at = 220
	var base = _find_team_base(t)
	if base != null:
		# Structure build order, gated on a comfortable supply buffer.
		if not _team_has_structure(t, "barracks"):
			if int(supply[t]) > b_at and randf() < struct_roll:
				build_structure(t, "barracks")
		elif not _team_has_structure(t, "war_factory"):
			if int(supply[t]) > wf_at and randf() < struct_roll:
				build_structure(t, "war_factory")
		elif not _team_has_structure(t, "spire"):
			if int(supply[t]) > sp_at and randf() < struct_roll:
				build_structure(t, "spire")
		elif (difficulty == "hard" or _persona_of(t) == "turtler") \
				and _structure_count(t, "turret") < (4 if _persona_of(t) == "turtler" else 2):
			# Hard AI hardens its base; turtlers ALWAYS build turrets, max.
			if int(supply[t]) > 200 and randf() < maxf(struct_roll, 0.5 if _persona_of(t) == "turtler" else 0.0):
				build_structure(t, "turret")
		elif difficulty == "hard" and _structure_count(t, "barracks") < 2:
			# Rich hard AI doubles up on Barracks for a second build queue.
			if int(supply[t]) > 320 and randf() < struct_roll:
				build_structure(t, "barracks")
		# Keep production lines warm — one queue slot per structure, so the
		# AI rotates across base / barracks / factory (lazy teams skip beats).
		if randf() >= skip_prod:
			var prod = _ai_open_producer(t, queue_cap)
			if prod != null:
				var pick: String = _ai_pick_production(t)
				if pick != "":
					queue_production(t, pick, str(prod.get("id", "")))
	# Spire owners occasionally teach a spell-less unit some magic.
	var spell_roll: float = 0.5 if difficulty == "hard" else 0.3
	if _team_has_structure(t, "spire") and randf() < spell_roll:
		_ai_grant_spells(t)
	# Hard AI fires its superweapon at the weakest enemy's base.
	if difficulty == "hard" and strike_ready_in(t) <= 0.0:
		var sb = _ai_pick_target_base(t, true)
		if sb != null:
			call_strike(t, int(sb.get("x", 0)), int(sb.get("y", 0)))
	# Offense per difficulty.
	_ai_offense(t)

## Difficulty-driven offense, run each AI think:
##   easy   — never attacks; strays are leashed back to guard the base
##   medium — every ~45-75 s sends a small raiding party (≤ a third of the
##            army, max 5) at a random enemy — never the full force
##   hard   — every ~50-80 s sends EVERY free combat unit as one wave at the
##            weakest surviving enemy team
func _ai_offense(t: int) -> void:
	if difficulty == "easy":
		_ai_guard_home(t)
		return
	if t >= _wave_timers.size():
		return
	_wave_timers[t] = float(_wave_timers[t]) - AI_THINK_PERIOD
	if float(_wave_timers[t]) > 0.0:
		if difficulty == "medium":
			_ai_guard_home(t)   # off-duty raiders drift home between raids
		return
	# Persona pacing: rushers wave fast, turtlers late, boomers in between.
	var pmul: float = 1.0
	match _persona_of(t):
		"rusher":
			pmul = 0.6
		"turtler":
			pmul = 1.6
		"boomer":
			pmul = 1.2
	if difficulty == "medium":
		_wave_timers[t] = randf_range(45.0, 75.0) * pmul
		_ai_send_raid(t)
	else:
		_wave_timers[t] = randf_range(50.0, 80.0) * pmul
		_ai_send_full_army(t)

## Free (idle, non-mining) units that wandered far from home walk back and
## hold near the base. Auto-acquire still lets them punish nearby intruders.
func _ai_guard_home(t: int) -> void:
	var e = _engine()
	if e == null:
		return
	var base = _find_team_base(t)
	if base == null:
		return
	var garrison: Array = _ai_free_units(t)
	var gi: int = -1
	for ent in garrison:
		gi += 1
		if _chebyshev(ent, base) <= 8:
			continue
		# Fan the garrison around the base rather than stacking on it.
		var spot: Vector2i = _ai_spread_spot(base, gi, garrison.size())
		ent["order_dest_x"] = spot.x
		ent["order_dest_y"] = spot.y
		ent["aggro"] = false
		ent["path"] = []

## A destination tile for unit `idx` of `total` attacking `target`, spread
## around it in a ring instead of every unit walking onto the same tile.
## Without this a 40-unit wave converges on one square and jams itself into
## a blob where most of the army can't reach anything to fight.
func _ai_spread_spot(target: Dictionary, idx: int, total: int) -> Vector2i:
	var tx: int = int(target.get("x", 0))
	var ty: int = int(target.get("y", 0))
	if total <= 1:
		return _nearest_floor(tx, ty, 6)
	# Ring grows with the army so big waves form a wide arc, and every third
	# unit steps out to a second rank so they don't form a single-file wall.
	var ring: int = 3 + int(sqrt(float(total)))
	if idx % 3 == 2:
		ring += 2
	var ang: float = TAU * float(idx) / float(maxi(1, total))
	var rx: int = tx + int(round(cos(ang) * float(ring)))
	var ry: int = ty + int(round(sin(ang) * float(ring)))
	return _nearest_floor(rx, ry, 5)

## Medium offense: a handful of troops attack-move at one enemy base.
func _ai_send_raid(t: int) -> void:
	var troops: Array = _ai_free_units(t)
	if troops.size() < 2:
		return   # too small an army to split — keep growing
	troops.shuffle()
	var raid_size: int = clampi(troops.size() / 3, 2, 5)
	var target = _ai_pick_target_base(t, false)
	if target == null:
		return
	for i in range(raid_size):
		var ent: Dictionary = troops[i]
		if bool(ent.get("is_engineer", false)):
			# Engineers march at the base itself to steal it.
			ent["order_target"] = str(target.get("id", ""))
			ent["order_dest_x"] = -1
			ent["order_dest_y"] = -1
		else:
			var rspot: Vector2i = _ai_spread_spot(target, i, raid_size)
			ent["order_dest_x"] = rspot.x
			ent["order_dest_y"] = rspot.y
			ent["aggro"] = true
		ent["path"] = []
	battle_log_extra.append("⚔ %s sends a raiding party! (%d units)" % [
		_team_label(t), raid_size])
	_persona_taunt(t)
	sim_event.emit("raid", {"team": t, "size": raid_size})

## Hard offense: the whole free army rolls out against the weakest team.
func _ai_send_full_army(t: int) -> void:
	var target = _ai_pick_target_base(t, true)
	if target == null:
		return
	var troops: Array = _ai_free_units(t)
	# Keep up to 2 designated miners home; everyone else marches.
	var sent: int = 0
	for ent_v in troops:
		var ent: Dictionary = ent_v
		if bool(ent.get("is_engineer", false)):
			ent["order_target"] = str(target.get("id", ""))
			ent["order_dest_x"] = -1
			ent["order_dest_y"] = -1
		else:
			# Each unit takes its own place in the encircling arc.
			var spot: Vector2i = _ai_spread_spot(target, sent, troops.size())
			ent["order_dest_x"] = spot.x
			ent["order_dest_y"] = spot.y
			ent["aggro"] = true
		ent["path"] = []
		sent += 1
	if sent < 2:
		return
	var vt: int = int(target.get("battle_team", -1))
	if vt == player_team:
		battle_log_extra.append(
			"🚨 %s is massing a full army against YOU! (%d units)" % [
				_team_label(t), sent])
	else:
		battle_log_extra.append("⚔ %s marches a full army on %s!" % [
			_team_label(t), _team_label(vt)])
	_persona_taunt(t)
	sim_event.emit("raid", {"team": t, "size": sent})

## Living, mobile, unengaged units with no standing order and no mining
## duty. Units already marching somewhere (order_dest set) are NOT free —
## otherwise guard-home would recall raiders mid-raid.
func _ai_free_units(t: int) -> Array:
	var e = _engine()
	if e == null:
		return []
	var out: Array = []
	for ent in e._dungeon_entities:
		if bool(ent.get("is_dead", false)) or bool(ent.get("is_chest", false)):
			continue
		if int(ent.get("battle_team", -1)) != t:
			continue
		if int(ent.get("speed", 0)) <= 0:
			continue
		if str(ent.get("order_target", "")) != "":
			continue
		if int(ent.get("order_dest_x", -1)) >= 0:
			continue
		if str(ent.get("miner_node_id", "")) != "":
			continue
		out.append(ent)
	return out

## An enemy base to attack. weakest=true scores every surviving enemy team
## by remaining forces (unit HP + 150 per structure) and picks the lowest;
## otherwise a random surviving enemy's base.
func _ai_pick_target_base(t: int, weakest: bool):
	var e = _engine()
	if e == null:
		return null
	var candidates: Array = []   # [team, base, score]
	for vt in range(num_teams):
		if vt == t or not bool(team_alive[vt]):
			continue
		var vbase = _find_team_base(vt)
		if vbase == null:
			continue
		var score: int = 0
		for ent in e._dungeon_entities:
			if bool(ent.get("is_dead", false)):
				continue
			if int(ent.get("battle_team", -1)) != vt:
				continue
			if bool(ent.get("is_battle_base", false)) \
					or bool(ent.get("is_battle_structure", false)):
				score += 150
			else:
				score += int(ent.get("hp", 0))
		candidates.append([vt, vbase, score])
	if candidates.is_empty():
		return null
	if not weakest:
		return candidates[randi() % candidates.size()][1]
	var best: Array = candidates[0]
	for c in candidates:
		if int(c[2]) < int(best[2]):
			best = c
	return best[1]

## "Team 3" but color-flavored for logs.
func _team_label(t: int) -> String:
	return "Team %d" % (t + 1)

# ──────────────────────────────────────────────────────────────────────────
# Living map: wild kaiju, supply crates, tech ruins
# ──────────────────────────────────────────────────────────────────────────

## The 8-minute event: a neutral kaiju rises mid-map and attacks EVERYONE.
## Whoever lands the kill collects KAIJU_BOUNTY supply.
func _spawn_wild_kaiju() -> void:
	var e = _engine()
	if e == null:
		return
	var ms: int = int(e.MAP_SIZE)
	var spot: Vector2i = _free_tile_near(Vector2i(ms / 2, ms / 2), 8)
	if spot.x < 0:
		spot = _nearest_floor(ms / 2, ms / 2, 8)
	var u: Dictionary = _build_kaiju_unit()
	u["name"] = "WILD %s" % str(u.get("name", "Kaiju"))
	_unit_counter += 1
	u["id"] = "wild_kaiju_%d" % _unit_counter
	u["x"] = spot.x
	u["y"] = spot.y
	u["battle_team"] = NEUTRAL_TEAM
	u["is_player"] = false
	u["is_friendly"] = false
	u["is_wild_kaiju"] = true
	u["aggro"] = true   # full-sight auto-acquire: it hunts on its own
	e._dungeon_entities.append(u)
	battle_log_extra.append(
		"🚨 A %s RISES at the center of the map! Bounty for the kill: %d⛃" % [
			str(u["name"]), KAIJU_BOUNTY])
	sim_event.emit("kaiju", {"x": spot.x, "y": spot.y, "name": str(u["name"])})

## Supply bounty for slaying the wild kaiju.
func _award_bounty(killer_team: int, tgt) -> void:
	if tgt == null or not bool(tgt.get("is_wild_kaiju", false)):
		return
	if killer_team < 0 or killer_team >= num_teams:
		return
	supply[killer_team] = int(supply[killer_team]) + KAIJU_BOUNTY
	battle_log_extra.append("🏆 %s SLAYS the wild kaiju — +%d⛃ bounty!" % [
		_team_label(killer_team), KAIJU_BOUNTY])
	sim_event.emit("income", {"team": killer_team, "amount": KAIJU_BOUNTY})

## Drop a supply crate on a random free tile (capped at MAX_CRATES alive).
func _spawn_crate() -> void:
	var e = _engine()
	if e == null or _crates.size() >= MAX_CRATES:
		return
	var ms: int = int(e.MAP_SIZE)
	var spot: Vector2i = _free_tile_near(
		Vector2i(randi_range(4, ms - 5), randi_range(4, ms - 5)), 4)
	if spot.x < 0:
		return
	_unit_counter += 1
	var c: Dictionary = _new_entity("Supply Crate", "Chest")
	c["id"] = "crate_%d" % _unit_counter
	c["x"] = spot.x
	c["y"] = spot.y
	_set_hp(c, 1)
	c["speed"] = 0
	c["is_chest"] = true    # combat/AI scans ignore it
	c["is_crate"] = true
	c.erase("battle_team")  # belongs to nobody
	e._dungeon_entities.append(c)
	_crates.append(str(c["id"]))
	battle_log_extra.append("📦 A supply crate has dropped somewhere on the field.")
	sim_event.emit("crate_drop", {"x": spot.x, "y": spot.y})

## Crack a crate open: random reward for the collector's team.
func _collect_crate(u: Dictionary, crate: Dictionary) -> void:
	crate["is_dead"] = true
	crate["death_time"] = _battle_time
	var ckey: int = int(crate.get("y", 0)) * _occ_ms + int(crate.get("x", 0))
	if str(_occ.get(ckey, "")) == str(crate.get("id", "")):
		_occ.erase(ckey)
	_ent_index.erase(str(crate.get("id", "")))
	var t: int = int(u.get("battle_team", -1))
	var reward: String
	var roll: float = randf()
	if roll < 0.4 and t >= 0 and t < num_teams:
		var amt: int = randi_range(40, 100)
		supply[t] = int(supply[t]) + amt
		reward = "+%d⛃ supply" % amt
	elif roll < 0.65:
		u["max_hp"] = int(u.get("max_hp", 10)) + 25
		u["hp"] = int(u["max_hp"])
		reward = "%s fully restored (+25 max HP)" % str(u.get("name", "?"))
	elif roll < 0.85 and t >= 0 and t < num_teams:
		_spawn_units_now(t, "militia", Vector2i(int(crate["x"]), int(crate["y"])))
		reward = "a militia squad joins!"
	else:
		u["speed"] = int(u.get("speed", 25)) + 8
		u["path"] = []
		reward = "%s surges with speed ⚡" % str(u.get("name", "?"))
	battle_log_extra.append("📦 %s cracks open a crate — %s" % [
		_team_label(t) if t >= 0 and t < num_teams else "A wanderer", reward])
	sim_event.emit("crate", {
		"x": int(crate["x"]), "y": int(crate["y"]), "team": t, "reward": reward})

## Derelict neutral structure an Engineer can claim for a passive perk.
func _make_tech_building(kind: String, x: int, y: int) -> Dictionary:
	var s: Dictionary = _new_entity(str(TECH_LABELS.get(kind, "Ruin")), "Construct")
	_unit_counter += 1
	s["id"] = "tech_%s_%d" % [kind, _unit_counter]
	s["x"] = x
	s["y"] = y
	_set_hp(s, 60)
	s["ac"] = 12
	s["speed"] = 0
	s["equipped_weapon"] = "None"
	s["is_battle_structure"] = true
	s["structure_kind"] = kind
	s["tech_label"] = str(TECH_LABELS.get(kind, "Ruin"))
	s["battle_team"] = NEUTRAL_TEAM
	s["is_player"] = false
	s["is_friendly"] = false
	return s

# ──────────────────────────────────────────────────────────────────────────
# Region hazards
# ──────────────────────────────────────────────────────────────────────────

## One hazard pulse at a random spot on the field. Hits ANY team — the
## battlefield itself is a combatant in these regions.
func _region_hazard_pulse() -> void:
	var e = _engine()
	if e == null:
		return
	var ms: int = int(e.MAP_SIZE)
	var c: Vector2i = _nearest_floor(randi_range(5, ms - 6), randi_range(5, ms - 6), 4)
	var caught: int = 0
	match region_effect:
		"blizzard":
			for ent in e._dungeon_entities:
				if not _hazard_can_hit(ent, c, 6):
					continue
				_apply_spell_conds(ent, {"conds": ["slowed"], "dur": 4})
				caught += 1
			battle_log_extra.append(
				"🌨 A blizzard howls across the field! (%d slowed)" % caught)
		"lava":
			for ent in e._dungeon_entities:
				if not _hazard_can_hit(ent, c, 1):
					continue
				var dmg: int = _roll_battle_dice(3, 10)
				e._dung_reduce_hp(ent, dmg)
				caught += 1
				if int(ent.get("hp", 1)) <= 0:
					_rt_handle_death(ent)
				if finished:
					break
			battle_log_extra.append(
				"🌋 A lava vent ERUPTS! (%d scorched)" % caught)
		"spores":
			for ent in e._dungeon_entities:
				if not _hazard_can_hit(ent, c, 3):
					continue
				_apply_spell_conds(ent, {"conds": ["fever"], "dur": 5})
				caught += 1
			battle_log_extra.append(
				"🍄 A spore cloud drifts through! (%d fevered)" % caught)
		"gloom":
			for ent in e._dungeon_entities:
				if not _hazard_can_hit(ent, c, 4):
					continue
				_apply_spell_conds(ent, {"conds": ["frightened"], "dur": 4})
				caught += 1
			battle_log_extra.append(
				"🌑 The gloom presses in! (%d frightened)" % caught)
	sim_event.emit("region_fx", {
		"type": region_effect, "x": c.x, "y": c.y, "caught": caught})

## Living mobile combatant within `r` of the hazard center?
func _hazard_can_hit(ent: Dictionary, c: Vector2i, r: int) -> bool:
	if bool(ent.get("is_dead", false)) or bool(ent.get("is_chest", false)):
		return false
	if not ent.has("battle_team"):
		return false
	if int(ent.get("speed", 0)) <= 0:
		return false   # structures shrug off weather
	return maxi(absi(int(ent.get("x", 0)) - c.x), absi(int(ent.get("y", 0)) - c.y)) <= r

# ──────────────────────────────────────────────────────────────────────────
# Superweapon strike
# ──────────────────────────────────────────────────────────────────────────

## Seconds until the team's arcane strike is ready (0 = ready now).
func strike_ready_in(team: int) -> float:
	if team < 0 or team >= _strike_cd.size():
		return 9999.0
	return float(_strike_cd[team])

## Call down an area strike at (x, y): 6d10 to EVERYTHING within
## STRIKE_RADIUS — friend or foe, so aim carefully. Needs a living Command
## Post and a charged cooldown. Returns "" or an error string.
func call_strike(team: int, x: int, y: int) -> String:
	var e = _engine()
	if e == null:
		return "Engine unavailable."
	if not active or finished:
		return "No battle running."
	if team < 0 or team >= _strike_cd.size():
		return "Bad team."
	if _find_team_base(team) == null:
		return "Requires a Command Post."
	if float(_strike_cd[team]) > 0.0:
		return "Strike ready in %ds." % int(ceil(float(_strike_cd[team])))
	_strike_cd[team] = STRIKE_CD
	var hits: int = 0
	for ent in e._dungeon_entities:
		if bool(ent.get("is_dead", false)) or bool(ent.get("is_chest", false)):
			continue
		if not ent.has("battle_team"):
			continue
		if maxi(absi(int(ent.get("x", 0)) - x), absi(int(ent.get("y", 0)) - y)) > STRIKE_RADIUS:
			continue
		var dmg: int = 0
		for _i in range(6):
			dmg += randi_range(1, 10)
		e._dung_reduce_hp(ent, dmg)
		hits += 1
		if int(ent.get("hp", 1)) <= 0:
			_rt_handle_death(ent)
			_award_bounty(team, ent)
		if finished:
			break
	battle_log_extra.append(
		"☄ %s calls down an ARCANE STRIKE! (%d caught in the blast)" % [
			_team_label(team), hits])
	sim_event.emit("strike", {"team": team, "x": x, "y": y})
	return ""

## Give one spell-less AI unit 1-2 random catalog spells (requires the
## team's spire, which set_unit_spells re-checks).
func _ai_grant_spells(t: int) -> void:
	var e = _engine()
	if e == null:
		return
	var cat: Array = get_battle_spell_catalog()
	if cat.is_empty():
		return
	for ent in e._dungeon_entities:
		if bool(ent.get("is_dead", false)) or bool(ent.get("is_chest", false)):
			continue
		if int(ent.get("battle_team", -1)) != t:
			continue
		if bool(ent.get("is_battle_base", false)) or bool(ent.get("is_battle_structure", false)):
			continue
		if not (ent.get("spells", []) as Array).is_empty():
			continue
		var names: Array = []
		var count: int = 1 + (randi() % 2)
		for i in range(count):
			var pick: String = str(cat[randi() % cat.size()]["name"])
			if not names.has(pick):
				names.append(pick)
		set_unit_spells(str(ent["id"]), names)
		return

# ──────────────────────────────────────────────────────────────────────────
# Battle spells (SP cost = cooldown in seconds)
# ──────────────────────────────────────────────────────────────────────────

## The equippable spell catalog for the UI: [{name, cost_s, desc, kind}].
func get_battle_spell_catalog() -> Array:
	var e = _engine()
	if e == null:
		return []
	e._ensure_spell_db()
	var out: Array = []
	for n in BATTLE_SPELLS:
		if not e._SPELL_DB.has(n):
			continue
		var s: Dictionary = e._SPELL_DB[n]
		out.append({
			"name":   str(n),
			"cost_s": int(s["sc"]),
			"desc":   str(s.get("desc", "")),
			"kind":   _spell_kind(s),
			"hp_cost": battle_spell_hp_cost(s),
			"cd":     maxf(0.5, float(int(s["sc"])) * BATTLE_SPELL_CD_MUL),
		})
	# Custom aura spells (created this battle via the Arcane Spire).
	for cs in custom_spells:
		out.append({
			"name": str(cs["name"]),
			"cost_s": 0,   # auras have no SP cost — they're always-on
			"desc": str(cs["desc"]),
			"kind": str(cs["kind"]),
			"is_custom_aura": true,
		})
	return out

## Classify a spell DB entry for the UI / autocast brain.
func _spell_kind(s: Dictionary) -> String:
	if bool(s.get("heal", false)):
		return "heal"
	if bool(s.get("atk", false)) and int(s.get("ds", 0)) > 0:
		return "damage"
	if bool(s.get("atk", false)):
		return "curse"
	return "buff"

## Equip up to 2 battle spells on a unit. Requires the unit's team to own
## a living Arcane Spire. Returns "" or an error string.
func set_unit_spells(unit_id: String, names: Array) -> String:
	var e = _engine()
	if e == null:
		return "Engine unavailable."
	var ent = e._dung_find(unit_id)
	if ent == null or bool(ent.get("is_dead", false)):
		return "Unit not found."
	var team: int = int(ent.get("battle_team", -1))
	if team < 0:
		return "Not a battle unit."
	if bool(ent.get("is_battle_base", false)) or bool(ent.get("is_battle_structure", false)) \
			or bool(ent.get("is_chest", false)):
		return "Structures cannot learn spells."
	if not _team_has_structure(team, "spire"):
		return "Requires an Arcane Spire."
	if names.size() > 2:
		return "Max 2 spells."
	var loadout: Array = []
	for n_v in names:
		var n: String = str(n_v)
		var is_custom: bool = false
		for cs in custom_spells:
			if str(cs["name"]) == n:
				is_custom = true
				break
		if not is_custom and not BATTLE_SPELLS.has(n):
			return "Unknown battle spell: %s" % n
		loadout.append({"name": n, "cd_left": 0.0})
	ent["spells"] = loadout
	return ""

## UI copy of a unit's spell loadout: [{name, cd_left, cost_s}].
func get_unit_spells(unit_id) -> Array:
	var e = _engine()
	if e == null:
		return []
	var ent = e._dung_find(str(unit_id))
	if ent == null:
		return []
	e._ensure_spell_db()
	var out: Array = []
	for sp in ent.get("spells", []):
		var n: String = str(sp.get("name", ""))
		var cost: int = 0
		if e._SPELL_DB.has(n):
			cost = int(e._SPELL_DB[n]["sc"])
		out.append({"name": n, "cd_left": float(sp.get("cd_left", 0.0)), "cost_s": cost})
	return out

## Autocast: fire the first off-cooldown spell that has a sensible target.
## At most one cast per unit per tick.
func _rt_autocast(ent: Dictionary, cur_tgt) -> void:
	var spells: Array = ent.get("spells", [])
	if spells.is_empty():
		return
	var e = _engine()
	if e == null:
		return
	e._ensure_spell_db()
	var weapons_only: bool = str(ent.get("atk_mode", "auto")) == "weapons"
	for sp in spells:
		if float(sp.get("cd_left", 0.0)) > 0.0:
			continue
		var n: String = str(sp.get("name", ""))
		if not e._SPELL_DB.has(n):
			continue
		var s: Dictionary = e._SPELL_DB[n]
		# Weapons-only mode sheathes OFFENSIVE magic; heals/buffs still fire.
		if weapons_only and bool(s.get("atk", false)):
			continue
		# Casting is paid for in HP. A unit will never bleed itself out to
		# cast, so it needs strictly more HP than the spell costs.
		var hp_cost: int = battle_spell_hp_cost(s)
		if int(ent.get("hp", 0)) <= hp_cost:
			continue
		if _try_cast_battle_spell(ent, n, s, cur_tgt):
			ent["hp"] = int(ent["hp"]) - hp_cost
			sim_event.emit("blood_cast", {
				"caster": str(ent.get("id", "")), "spell": n, "hp": hp_cost,
				"x": int(ent.get("x", 0)), "y": int(ent.get("y", 0))})
			# SP cost is the base cooldown in seconds (4 SP → 4 s, 29 SP → 29 s),
			# HALVED for Battle Mode (BATTLE_SPELL_CD_MUL); floored at 0.5 s so a
			# 1-SP spell still has a real cooldown. Story SP cost is untouched.
			sp["cd_left"] = maxf(0.5, float(int(s["sc"])) * BATTLE_SPELL_CD_MUL)
			return

## Resolve one battle-spell cast directly (battle units have no character
## handles, so story-mode cast paths are bypassed). Returns true when the
## spell actually fired (false = no valid target, keep it off cooldown).
func _try_cast_battle_spell(caster: Dictionary, spell_name: String, s: Dictionary, cur_tgt) -> bool:
	var e = _engine()
	if e == null:
		return false
	var kind: String = _spell_kind(s)
	var rng: int = _battle_spell_range(s)   # battle-only halved range
	# Healing spells need enough reach to actually find wounded allies on
	# a large RTS battlefield — the halved touch range of 1 tile makes
	# them almost useless. Floor at 5 so healers can tend nearby friendlies.
	if kind == "heal":
		rng = maxi(rng, 5)
	# Mind Control resolves as a team conversion, not a curse.
	if spell_name == MC_SPELL:
		var mc_t = cur_tgt
		if mc_t == null or _chebyshev(caster, mc_t) > rng:
			mc_t = _nearest_enemy_of(caster, rng)
		if mc_t == null:
			return false
		return _mc_convert(caster, mc_t)
	var area: int = clampi(int(s.get("area", 0)), 0, 4)
	var mt: int = maxi(1, int(s.get("mt", 1)))
	var text: String = ""
	var tgt = null
	match kind:
		"heal":
			if area > 0:
				# Burst heal (Aura of Restoration): every wounded ally
				# within `area` tiles of the caster, up to mt.
				var patients: Array = _wounded_allies_within(caster, maxi(area, rng if int(s.get("rt", 0)) > 0 else area), mt)
				if patients.is_empty():
					return false
				var healed: int = 0
				for p_v in patients:
					var pat: Dictionary = p_v
					var h: int = _roll_battle_dice(int(s.get("dc", 0)), int(s.get("ds", 0)))
					pat["hp"] = mini(int(pat["max_hp"]), int(pat["hp"]) + h)
					healed += h
				tgt = patients[0]
				text = "✨ %s casts %s — %d all%s healed (+%d HP total)." % [
					str(caster.get("name", "")), spell_name, patients.size(),
					"y" if patients.size() == 1 else "ies", healed]
			elif mt > 1:
				# Chain heal (Chain Mend): the mt most wounded allies in range.
				var patients: Array = _wounded_allies_within(caster, rng, mt)
				if patients.is_empty():
					return false
				var healed: int = 0
				for p_v in patients:
					var pat: Dictionary = p_v
					var h: int = _roll_battle_dice(int(s.get("dc", 0)), int(s.get("ds", 0)))
					pat["hp"] = mini(int(pat["max_hp"]), int(pat["hp"]) + h)
					healed += h
				tgt = patients[0]
				text = "✨ %s casts %s — %d allies mended (+%d HP total)." % [
					str(caster.get("name", "")), spell_name, patients.size(), healed]
			else:
				if int(s.get("rt", 0)) == 0:
					# Range 0 = self only.
					if int(caster.get("hp", 0)) < int(caster.get("max_hp", 0)):
						tgt = caster
				else:
					tgt = _most_wounded_ally(caster, rng)
				if tgt == null:
					return false
				var total: int = _roll_battle_dice(int(s.get("dc", 0)), int(s.get("ds", 0)))
				tgt["hp"] = mini(int(tgt["max_hp"]), int(tgt["hp"]) + total)
				text = "✨ %s casts %s on %s (+%d HP)." % [
					str(caster.get("name", "")), spell_name, str(tgt.get("name", "")), total]
		"damage", "curse":
			tgt = null
			if cur_tgt != null and not bool(cur_tgt.get("is_dead", false)) \
					and _chebyshev(caster, cur_tgt) <= rng:
				tgt = cur_tgt
			if tgt == null:
				tgt = _nearest_enemy_in_range(caster, rng)
			if tgt == null:
				return false
			# ── Victim list ──────────────────────────────────────────────
			# area > 0 → BLAST centered on the primary target: everything
			#            within `area` tiles is hit, FRIEND OR FOE (real
			#            C&C fireballs don't check ID cards), capped at mt.
			# mt > 1   → CHAIN: arcs to the mt nearest enemies in range.
			# else     → single target.
			var victims: Array = [tgt]
			if area > 0:
				victims = _entities_within(tgt, area, mt)
			elif mt > 1:
				victims = _enemies_within(caster, rng, mt, tgt)
			var conds: Array = s.get("conds", [])
			var fx: String = ""
			if not conds.is_empty():
				fx = " [%s]" % ", ".join(PackedStringArray(conds))
			var total_dmg: int = 0
			for v_v in victims:
				var vic: Dictionary = v_v
				var dmg: int = _roll_battle_dice(int(s.get("dc", 0)), int(s.get("ds", 0)))
				if dmg > 0:
					e._dung_reduce_hp(vic, dmg)
					total_dmg += dmg
				_apply_spell_conds(vic, s)
				if int(vic.get("hp", 1)) <= 0:
					_rt_handle_death(vic)
					_award_kill(caster)   # spell kills count toward veterancy
					_award_bounty(int(caster.get("battle_team", -1)), vic)
				if finished:
					break
			if victims.size() > 1:
				text = "🔥 %s casts %s — %d caught for %d total damage%s!" % [
					str(caster.get("name", "")), spell_name, victims.size(),
					total_dmg, fx]
				if total_dmg > int(_biggest_blast.get("dmg", 0)):
					_biggest_blast = {"dmg": total_dmg, "spell": spell_name,
						"team": int(caster.get("battle_team", -1))}
			else:
				text = "🔮 %s casts %s at %s (%d damage)%s." % [
					str(caster.get("name", "")), spell_name,
					str(tgt.get("name", "")), total_dmg, fx]
		"buff":
			var conds: Array = s.get("conds", [])
			if conds.is_empty():
				return false
			tgt = caster
			# Don't burn the cooldown re-applying an active buff.
			if e._dung_has_condition(tgt, str(conds[0])):
				return false
			_apply_spell_conds(tgt, s)
			text = "🛡 %s casts %s [%s]." % [
				str(caster.get("name", "")), spell_name,
				", ".join(PackedStringArray(conds))]
		_:
			return false
	battle_log_extra.append(text)
	# Debug: prove how far every cast actually reached. If a spell ever
	# fires beyond its range this line is the evidence.
	if bool(GameState.debug_mode) and tgt != null:
		var cast_d: int = _chebyshev(caster, tgt)
		battle_log_extra.append("🐞 %s cast %s at distance %d (range %d, rt %d)%s" % [
			str(caster.get("name", "?")), spell_name, cast_d, rng,
			int(s.get("rt", 0)), "  ⚠ OUT OF RANGE" if cast_d > rng else ""])
	sim_event.emit("spell", {
		"caster": str(caster.get("id", "")),
		"spell":  spell_name,
		"target": str(tgt.get("id", "")) if tgt != null else "",
		"x": int(tgt.get("x", -1)) if tgt != null else -1,
		"y": int(tgt.get("y", -1)) if tgt != null else -1,
		"aoe": area,
		"kind_hint": kind,
		"dt": str(s.get("dt", "")),   # damage type → element color in the UI
		"text":   text,
	})
	return true

## Append the spell's condition strings to the target (the engine stores
## conditions as PLAIN STRING names in ent["conditions"]) and stamp an RTS
## time-to-live so curses don't stick forever (dur capped at 10 ticks).
func _apply_spell_conds(tgt: Dictionary, s: Dictionary) -> void:
	var e = _engine()
	if e == null:
		return
	var conds: Array = s.get("conds", [])
	if conds.is_empty():
		return
	if not tgt.has("base_speed"):
		tgt["base_speed"] = int(tgt.get("speed", 4))
	var dur: int = clampi(int(s.get("dur", 1)), 1, 10)
	var ttl: Dictionary = tgt.get("battle_cond_ttl", {})
	for c_v in conds:
		var c: String = str(c_v)
		e._dung_add_condition(tgt, c)
		ttl[c] = dur
	tgt["battle_cond_ttl"] = ttl

## Roll `dc` dice of `ds` sides (one randi_range per die).
func _roll_battle_dice(dc: int, ds: int) -> int:
	if dc <= 0 or ds <= 0:
		return 0
	var total: int = 0
	for i in range(dc):
		total += randi_range(1, ds)
	return total

## Most-wounded living friendly within Chebyshev `rng` (caster included);
## null when nobody in range is missing HP.
func _most_wounded_ally(caster: Dictionary, rng: int):
	var e = _engine()
	if e == null:
		return null
	var team: int = int(caster.get("battle_team", -1))
	var best = null
	var best_missing: int = 0
	for other in e._dungeon_entities:
		if bool(other.get("is_dead", false)) or bool(other.get("is_chest", false)):
			continue
		if int(other.get("battle_team", -1)) != team:
			continue
		if _chebyshev(caster, other) > rng:
			continue
		var missing: int = int(other.get("max_hp", 0)) - int(other.get("hp", 0))
		if missing > best_missing:
			best_missing = missing
			best = other
	return best

## Every living combatant (ANY team — blast spells are indiscriminate)
## within `r` tiles of `center`, capped at `cap`, center entity first.
func _entities_within(center: Dictionary, r: int, cap: int) -> Array:
	var e = _engine()
	if e == null:
		return []
	var out: Array = [center]
	for other in e._dungeon_entities:
		if out.size() >= cap:
			break
		if bool(other.get("is_dead", false)) or bool(other.get("is_chest", false)):
			continue
		if not other.has("battle_team"):
			continue
		if str(other.get("id", "")) == str(center.get("id", "")):
			continue
		if _chebyshev(center, other) <= r:
			out.append(other)
	return out

## Up to `cap` living enemies of `ent` within `rng`, primary first.
func _enemies_within(ent: Dictionary, rng: int, cap: int, primary) -> Array:
	var e = _engine()
	if e == null:
		return []
	var team: int = int(ent.get("battle_team", -1))
	var out: Array = []
	if primary != null:
		out.append(primary)
	for other in e._dungeon_entities:
		if out.size() >= cap:
			break
		if bool(other.get("is_dead", false)) or bool(other.get("is_chest", false)):
			continue
		if not other.has("battle_team"):
			continue
		if int(other["battle_team"]) == team:
			continue
		if primary != null and str(other.get("id", "")) == str(primary.get("id", "")):
			continue
		if _chebyshev(ent, other) <= rng:
			out.append(other)
	return out

## Up to `cap` WOUNDED allies within `r` tiles, most damaged first.
func _wounded_allies_within(caster: Dictionary, r: int, cap: int) -> Array:
	var e = _engine()
	if e == null:
		return []
	var team: int = int(caster.get("battle_team", -1))
	var hurt: Array = []   # [missing_hp, ent]
	for other in e._dungeon_entities:
		if bool(other.get("is_dead", false)) or bool(other.get("is_chest", false)):
			continue
		if int(other.get("battle_team", -1)) != team:
			continue
		if _chebyshev(caster, other) > r:
			continue
		var missing: int = int(other.get("max_hp", 0)) - int(other.get("hp", 0))
		if missing > 0:
			hurt.append([missing, other])
	hurt.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	var out: Array = []
	for h in hurt:
		if out.size() >= cap:
			break
		out.append(h[1])
	return out

## All living same-team entities within Chebyshev distance r, capped at cap.
func _allies_within(center: Dictionary, r: int, cap: int = 10) -> Array:
	var team: int = int(center.get("battle_team", -1))
	var cx: int = int(center.get("x", 0))
	var cy: int = int(center.get("y", 0))
	var result: Array = []
	# Use spatial hash for efficiency.
	var cr: int = (r / CELL_SIZE) + 1
	var cx0: int = (cx / CELL_SIZE) - cr
	var cy0: int = (cy / CELL_SIZE) - cr
	var cx1: int = (cx / CELL_SIZE) + cr
	var cy1: int = (cy / CELL_SIZE) + cr
	for sy in range(cy0, cy1 + 1):
		for sx in range(cx0, cx1 + 1):
			var cell: Array = _spatial.get(sy * 1000 + sx, [])
			for other in cell:
				if int(other.get("battle_team", -1)) != team:
					continue
				if absi(int(other["x"]) - cx) <= r and absi(int(other["y"]) - cy) <= r:
					result.append(other)
					if result.size() >= cap:
						return result
	return result

## Pulse all equipped custom aura spells. Called every AURA_PERIOD seconds.
## Each aura-equipped unit radiates its effect to nearby entities.
func _tick_auras() -> void:
	if custom_spells.is_empty():
		return
	var e = _engine()
	if e == null:
		return
	# Build a quick lookup of custom spell data by name.
	var cs_map: Dictionary = {}
	for cs in custom_spells:
		cs_map[str(cs["name"])] = cs
	# Iterate living entities with spells.
	for ent_v in e._dungeon_entities:
		var ent: Dictionary = ent_v
		if bool(ent.get("is_dead", false)):
			continue
		if not ent.has("battle_team"):
			continue
		var team: int = int(ent.get("battle_team", -1))
		for sp in ent.get("spells", []):
			var sn: String = str(sp.get("name", ""))
			if not cs_map.has(sn):
				continue
			var cs: Dictionary = cs_map[sn]
			var kind: String = str(cs["kind"])
			var area: int = int(cs["area"])
			var dc: int = int(cs["dc"])
			var ds: int = int(cs["ds"])
			var conds: Array = cs.get("conds", [])
			match kind:
				"damage":
					# Damage all enemies within radius.
					var victims: Array = _enemies_within(ent, area, 20, null)
					for vic in victims:
						var dmg: int = _roll_battle_dice(dc, ds)
						e._dung_reduce_hp(vic, dmg)
						if int(vic.get("hp", 1)) <= 0:
							_rt_handle_death(vic)
							_award_kill(ent)
							_award_bounty(team, vic)
						if finished:
							return
					if not victims.is_empty():
						sim_event.emit("spell", {
							"caster": str(ent.get("id", "")),
							"spell": sn, "target": str(victims[0].get("id", "")),
							"x": int(ent.get("x", 0)), "y": int(ent.get("y", 0)),
							"aoe": area, "kind_hint": "damage",
							"dt": "", "text": ""})
				"heal":
					# Heal all allies within radius.
					var patients: Array = _wounded_allies_within(ent, area, 20)
					var total_h: int = 0
					for pat in patients:
						var h: int = _roll_battle_dice(dc, ds)
						pat["hp"] = mini(int(pat["max_hp"]), int(pat["hp"]) + h)
						total_h += h
					if not patients.is_empty():
						sim_event.emit("spell", {
							"caster": str(ent.get("id", "")),
							"spell": sn, "target": str(patients[0].get("id", "")),
							"x": int(ent.get("x", 0)), "y": int(ent.get("y", 0)),
							"aoe": area, "kind_hint": "heal",
							"dt": "", "text": ""})
				"buff":
					# Apply conditions to all allies within radius.
					var allies: Array = _allies_within(ent, area, 20)
					for ally in allies:
						for cond in conds:
							e._dung_add_condition(ally, str(cond))
					if not allies.is_empty():
						sim_event.emit("spell", {
							"caster": str(ent.get("id", "")),
							"spell": sn, "target": str(allies[0].get("id", "")),
							"x": int(ent.get("x", 0)), "y": int(ent.get("y", 0)),
							"aoe": area, "kind_hint": "buff",
							"dt": "", "text": ""})
				"debuff":
					# Apply conditions to all enemies within radius.
					var victims: Array = _enemies_within(ent, area, 20, null)
					for vic in victims:
						for cond in conds:
							e._dung_add_condition(vic, str(cond))
					if not victims.is_empty():
						sim_event.emit("spell", {
							"caster": str(ent.get("id", "")),
							"spell": sn, "target": str(victims[0].get("id", "")),
							"x": int(ent.get("x", 0)), "y": int(ent.get("y", 0)),
							"aoe": area, "kind_hint": "curse",
							"dt": "", "text": ""})

## Nearest unlooted resource node anywhere on the map, or null. Used by
## miners relocating off a spent vein (throttled to ~1 Hz per miner).
func _nearest_live_node(ent: Dictionary):
	var e = _engine()
	if e == null:
		return null
	var best = null
	var best_d: int = 999999
	for other in e._dungeon_entities:
		if not bool(other.get("is_resource_node", false)):
			continue
		if bool(other.get("looted", false)) or bool(other.get("is_dead", false)):
			continue
		var d: int = _chebyshev(ent, other)
		if d < best_d:
			best_d = d
			best = other
	return best

## Nearest living enemy within Chebyshev `rng`, or null.
func _nearest_enemy_in_range(ent: Dictionary, rng: int):
	var e = _engine()
	if e == null:
		return null
	var team: int = int(ent.get("battle_team", -1))
	var best = null
	var best_d: int = rng + 1
	for other in e._dungeon_entities:
		if bool(other.get("is_dead", false)) or bool(other.get("is_chest", false)):
			continue
		if not other.has("battle_team"):
			continue
		if int(other["battle_team"]) == team:
			continue
		var d: int = _chebyshev(ent, other)
		if d < best_d:
			best_d = d
			best = other
	return best

# ──────────────────────────────────────────────────────────────────────────
# Outcome / state queries
# ──────────────────────────────────────────────────────────────────────────

## "defeat" if the player team is dead, "victory" if it is the sole
## survivor, otherwise "ongoing". Past MAX_ROUNDS sudden death kicks in:
## the player wins iff no other team fields a bigger living army.
func check_battle_outcome() -> String:
	if not active or team_alive.size() <= player_team:
		return "ongoing"
	# Real-time sim already decided the battle.
	if finished:
		if winner == player_team:
			return "victory"
		return "defeat"
	if not bool(team_alive[player_team]):
		return "defeat"
	if teams_alive_count() == 1:
		return "victory"
	if round_num > MAX_ROUNDS:
		var mine: int = _living_count(player_team)
		for t in range(num_teams):
			if t == player_team:
				continue
			if _living_count(t) > mine:
				return "defeat"
		return "victory"
	return "ongoing"

## Living non-chest entities fielded by a team.
func _living_count(team: int) -> int:
	var e = _engine()
	if e == null:
		return 0
	var n: int = 0
	for ent in e._dungeon_entities:
		if bool(ent.get("is_dead", false)) or bool(ent.get("is_chest", false)):
			continue
		if int(ent.get("battle_team", -1)) == team:
			n += 1
	return n

## Current supply for a team (0 for out-of-range indices).
func get_supply(team: int) -> int:
	if team < 0 or team >= supply.size():
		return 0
	return int(supply[team])

## How many teams are still standing.
func teams_alive_count() -> int:
	var n: int = 0
	for alive in team_alive:
		if bool(alive):
			n += 1
	return n

# ──────────────────────────────────────────────────────────────────────────
# Structures
# ──────────────────────────────────────────────────────────────────────────

## Erect a structure for `team`. Returns "" on success or an error string.
##   barracks     — infantry trains 20% cheaper
##   war_factory  — unlocks the vehicle catalog
##   command_post — REBUILDS production after base loss (any living unit
##                  can anchor the new post)
func build_structure(team: int, kind: String) -> String:
	var e = _engine()
	if e == null:
		return "Engine unavailable."
	if not STRUCTURE_KINDS.has(kind):
		return "Unknown structure."
	if kind == "wall":
		return "Walls are placed by hand (🧱 button)."
	if team < 0 or team >= supply.size():
		return "Bad team."
	var cost: int = int(STRUCTURE_KINDS[kind]["cost"])
	if int(supply[team]) < cost:
		return "Need %d supply." % cost
	if kind == "turret":
		# Guard-tower cap grows with the war economy: 4 + one per barracks.
		var turret_cap: int = TURRET_BASE_CAP + _structure_count(team, "barracks")
		if _structure_count(team, "turret") >= turret_cap:
			return "Turret limit reached (%d) — build more barracks to raise it." % turret_cap
	# Pick the anchor the structure rises next to.
	var anchor = _find_team_base(team)
	if kind == "command_post":
		if anchor != null:
			return "Base already standing."
		# Rebuild is only possible while the team still has boots on the
		# ground — any living unit anchors the new post.
		for ent in e._dungeon_entities:
			if bool(ent.get("is_dead", false)) or bool(ent.get("is_chest", false)):
				continue
			if int(ent.get("battle_team", -1)) == team:
				anchor = ent
				break
		if anchor == null:
			return "Team has no survivors."
	elif anchor == null:
		return "No base."
	var pos: Vector2i = _structure_spot(anchor)
	e._dungeon_entities.append(_make_structure(team, pos.x, pos.y, kind))
	supply[team] = int(supply[team]) - cost
	battle_log_extra.append("🏗 Team %d erects a %s." % [team, str(STRUCTURE_KINDS[kind]["label"])])
	sim_event.emit("structure", {"team": team, "kind": kind})
	return ""

## Player-placed structure: validates tile + cost, then erects the building
## at (x, y). Called from the RTS UI after the player clicks a tile.
## AI teams still use build_structure() which auto-places.
func build_structure_at(team: int, kind: String, x: int, y: int) -> String:
	var e = _engine()
	if e == null:
		return "Engine unavailable."
	if not STRUCTURE_KINDS.has(kind):
		return "Unknown structure."
	if kind == "wall":
		return place_wall(team, x, y)
	if not active or finished:
		return "No battle running."
	if team < 0 or team >= supply.size():
		return "Bad team."
	var cost: int = int(STRUCTURE_KINDS[kind]["cost"])
	if int(supply[team]) < cost:
		return "Need %d supply." % cost
	if kind == "turret":
		# Guard-tower cap grows with the war economy: 4 + one per barracks.
		var turret_cap: int = TURRET_BASE_CAP + _structure_count(team, "barracks")
		if _structure_count(team, "turret") >= turret_cap:
			return "Turret limit reached (%d) — build more barracks to raise it." % turret_cap
	if kind == "command_post":
		var base = _find_team_base(team)
		if base != null:
			return "Base already standing."
		# Must have at least one living unit to anchor rebuild.
		var has_living: bool = false
		for ent in e._dungeon_entities:
			if bool(ent.get("is_dead", false)) or bool(ent.get("is_chest", false)):
				continue
			if int(ent.get("battle_team", -1)) == team:
				has_living = true
				break
		if not has_living:
			return "Team has no survivors."
	elif _find_team_base(team) == null:
		return "No base."
	# Tile validity (same rules as wall placement).
	if e._dung_tile(x, y) != 1:
		return "Can't build there."
	if e._dung_entity_at(x, y) != null:
		return "That tile is occupied."
	e._dungeon_entities.append(_make_structure(team, x, y, kind))
	supply[team] = int(supply[team]) - cost
	battle_log_extra.append("🏗 Team %d erects a %s." % [team, str(STRUCTURE_KINDS[kind]["label"])])
	sim_event.emit("structure", {"team": team, "kind": kind})
	return ""

## Hand-placed wall segment: pick the tile yourself (unlike build_structure
## which auto-places). Walls block movement via the occupancy map.
func place_wall(team: int, x: int, y: int) -> String:
	var e = _engine()
	if e == null:
		return "Engine unavailable."
	if not active or finished:
		return "No battle running."
	if team < 0 or team >= supply.size():
		return "Bad team."
	var cost: int = int(STRUCTURE_KINDS["wall"]["cost"])
	if int(supply[team]) < cost:
		return "Need %d supply." % cost
	if _structure_count(team, "wall") >= MAX_WALLS:
		return "Wall limit reached (%d)." % MAX_WALLS
	if e._dung_tile(x, y) != 1:
		return "Can't build there."
	if e._dung_entity_at(x, y) != null:
		return "That tile is occupied."
	e._dungeon_entities.append(_make_structure(team, x, y, "wall"))
	supply[team] = int(supply[team]) - cost
	return ""

## Battle structure entity: immobile, unarmed, team-owned. A command_post
## additionally carries is_battle_base so production works again.
func _make_structure(team: int, x: int, y: int, kind: String) -> Dictionary:
	var cfg: Dictionary = STRUCTURE_KINDS[kind]
	# Duplicates are welcome (each runs its own production queue) — number
	# them so "Barracks #2" is tellable from the first on the field.
	var nth: int = _structure_count(team, kind) + 1
	var disp: String = "T%d %s" % [team, str(cfg["label"])]
	if nth > 1:
		disp += " #%d" % nth
	var s: Dictionary = _new_entity(disp, "Construct")
	_unit_counter += 1
	s["id"] = "bt%d_%s_%d" % [team, kind, _unit_counter]
	s["x"] = x
	s["y"] = y
	_set_hp(s, int(cfg["hp"]))
	s["ac"] = BASE_AC
	s["speed"] = 0
	s["equipped_weapon"] = "None"
	s["is_battle_structure"] = true
	s["structure_kind"] = kind
	if kind == "command_post":
		s["is_battle_base"] = true
	elif kind == "turret":
		# Guard Turret: ranged auto-defense ("bow" keyword → 6-tile range).
		s["equipped_weapon"] = "Guard Bow"
		s["hit_bonus_buff"] = 3
		s["atk_interval"] = 1.2
	_apply_team_flags(s, team)
	return s

## A breathing-room build spot: a free floor tile 3-8 tiles from the
## anchor that keeps Chebyshev ≥ 3 from every other living structure, so
## bases read as proper compounds instead of a welded blob. Falls back to
## the old cramped spiral only when the whole neighborhood is full.
func _structure_spot(anchor) -> Vector2i:
	var e = _engine()
	var ax: int = int(anchor["x"])
	var ay: int = int(anchor["y"])
	if e == null:
		return Vector2i(ax, ay)
	var ms: int = int(e.MAP_SIZE)
	for r in range(3, 9):
		var cands: Array = []
		for oy in range(-r, r + 1):
			for ox in range(-r, r + 1):
				if maxi(absi(ox), absi(oy)) != r:
					continue   # ring cells only
				var nx: int = ax + ox
				var ny: int = ay + oy
				if nx < 2 or ny < 2 or nx >= ms - 2 or ny >= ms - 2:
					continue
				if e._dung_tile(nx, ny) != 1:
					continue
				if e._dung_entity_at(nx, ny) != null:
					continue
				if _near_structure(nx, ny, 2):
					continue   # keep ≥3 tiles from every structure
				cands.append(Vector2i(nx, ny))
		if not cands.is_empty():
			return cands[randi() % cands.size()]
	return _nearest_floor(ax, ay, 6)

## Any living structure (any team) within `min_d` tiles of (x, y)?
func _near_structure(x: int, y: int, min_d: int) -> bool:
	var e = _engine()
	if e == null:
		return false
	for ent in e._dungeon_entities:
		if bool(ent.get("is_dead", false)):
			continue
		if not (bool(ent.get("is_battle_structure", false))
				or bool(ent.get("is_battle_base", false))):
			continue
		if maxi(absi(int(ent.get("x", 0)) - x), absi(int(ent.get("y", 0)) - y)) <= min_d:
			return true
	return false

## How many living structures of `kind` the team owns.
func _structure_count(team: int, kind: String) -> int:
	var ts: Dictionary = _team_structs.get(team, {})
	return int(ts.get(kind, 0))

## True while the team owns a living structure of the given kind.
func _team_has_structure(team: int, kind: String) -> bool:
	var ts: Dictionary = _team_structs.get(team, {})
	return int(ts.get(kind, 0)) > 0

# ──────────────────────────────────────────────────────────────────────────
# Armory (player-only unit upgrades)
# ──────────────────────────────────────────────────────────────────────────

## Upgrade a player unit. `kind` is "weapon", "armor" or "veteran".
## Returns "" on success or a human-readable error string.
func upgrade_unit(unit_id: String, kind: String) -> String:
	var e = _engine()
	if e == null:
		return "Engine unavailable."
	var ent = e._dung_find(unit_id)
	if ent == null or bool(ent.get("is_dead", false)):
		return "Unit not found."
	if int(ent.get("battle_team", -1)) != player_team:
		return "Not your unit."
	# Upgrades need an armory to happen in — a living Barracks (the
	# Command Post does NOT count).
	if not _team_has_structure(player_team, "barracks"):
		return "Requires a Barracks."
	var is_machine: bool = bool(ent.get("is_vehicle", false)) \
			or bool(ent.get("is_battle_structure", false)) \
			or bool(ent.get("is_battle_base", false))
	match kind:
		"weapon":
			if is_machine:
				return "Cannot refit machines."
			# Unknown weapons count as tier 0 — the first upgrade replaces them.
			var idx: int = WEAPON_TIERS.find(str(ent.get("equipped_weapon", "")))
			if idx < 0:
				idx = 0
			if idx >= WEAPON_TIERS.size() - 1:
				return "Weapon already maxed."
			var cost: int = 20 if idx == 0 else 40
			if int(supply[player_team]) < cost:
				return "Need %d supply." % cost
			ent["equipped_weapon"] = str(WEAPON_TIERS[idx + 1])
			supply[player_team] = int(supply[player_team]) - cost
			return ""
		"armor":
			if is_machine:
				return "Cannot refit machines."
			# Current tier = highest tier whose AC fits under the unit's AC.
			var idx: int = -1
			var cur_ac: int = int(ent.get("ac", 10))
			for i in range(ARMOR_TIERS.size()):
				if int(ARMOR_TIERS[i][1]) <= cur_ac:
					idx = i
			if idx < 0:
				idx = 0
			if idx >= ARMOR_TIERS.size() - 1:
				return "Armor already maxed."
			var cost: int = 20 if idx == 0 else 40
			if int(supply[player_team]) < cost:
				return "Need %d supply." % cost
			# Armor is NOT live in the engine — set BOTH fields.
			ent["equipped_armor"] = str(ARMOR_TIERS[idx + 1][0])
			ent["ac"] = int(ARMOR_TIERS[idx + 1][1])
			supply[player_team] = int(supply[player_team]) - cost
			return ""
		"veteran":
			if str(ent.get("name", "")).ends_with(" ★"):
				return "Already a veteran."
			var cost: int = 40
			if int(supply[player_team]) < cost:
				return "Need %d supply." % cost
			ent["max_hp"] = int(ent.get("max_hp", 10)) + 25
			ent["hp"] = int(ent.get("hp", 10)) + 25
			ent["name"] = "%s ★" % str(ent.get("name", ""))
			supply[player_team] = int(supply[player_team]) - cost
			return ""
	return "Unknown upgrade."

# ──────────────────────────────────────────────────────────────────────────
# Orders (persistent move / attack commands)
# ──────────────────────────────────────────────────────────────────────────

## Send a unit toward a tile. The real-time sim marches it there tile by
## tile until it arrives or receives a new order. Plain move = NOT aggro.
func issue_move_order(unit_id: String, tx: int, ty: int) -> void:
	var e = _engine()
	if e == null:
		return
	var ent = e._dung_find(unit_id)
	if ent == null or bool(ent.get("is_dead", false)):
		return
	ent["order_dest_x"] = tx
	ent["order_dest_y"] = ty
	ent["order_target"] = ""
	ent["aggro"] = false
	ent["miner_node_id"] = ""   # a fresh move order ends mining duty
	ent["stance"] = ""          # ...and any standing stance
	ent["auto_tgt"] = ""
	ent["path"] = []

## Send a unit after an enemy. The sim chases and attacks in real time
## until the target dies or vanishes.
func issue_attack_order(unit_id: String, target_id: String) -> void:
	var e = _engine()
	if e == null:
		return
	var ent = e._dung_find(unit_id)
	if ent == null or bool(ent.get("is_dead", false)):
		return
	ent["order_target"] = target_id
	ent["order_dest_x"] = -1
	ent["order_dest_y"] = -1
	ent["miner_node_id"] = ""
	ent["stance"] = ""
	ent["auto_tgt"] = ""
	ent["path"] = []

## Wipe any standing order from a unit.
func clear_orders(unit_id) -> void:
	var e = _engine()
	if e == null:
		return
	var ent = e._dung_find(str(unit_id))
	if ent == null:
		return
	ent["order_target"] = ""
	ent["order_dest_x"] = -1
	ent["order_dest_y"] = -1
	ent["aggro"] = false
	ent["miner_node_id"] = ""
	ent["auto_tgt"] = ""

## Put a unit on mining duty at a node: it walks to a free adjacent tile
## and STAYS there, re-approaching whenever it gets bumped. Mining duty
## persists until the node depletes or the unit gets a new order.
func issue_mine_order(unit_id: String, node_id: String) -> String:
	var e = _engine()
	if e == null:
		return "Engine unavailable."
	var ent = e._dung_find(unit_id)
	var node = e._dung_find(node_id)
	if ent == null or bool(ent.get("is_dead", false)):
		return "No such unit."
	if node == null or not bool(node.get("is_resource_node", false)):
		return "No such node."
	# Depleted nodes are still valid duty — veins refill after 3 minutes
	# and parked miners resume automatically.
	if int(ent.get("speed", 0)) <= 0:
		return "Structures cannot mine."
	ent["miner_node_id"] = node_id
	ent["order_target"] = ""
	ent["order_dest_x"] = -1
	ent["order_dest_y"] = -1
	ent["aggro"] = false
	ent["stance"] = ""
	ent["auto_tgt"] = ""
	ent["path"] = []
	return ""

## Mining duty for a whole selection — each unit gets its own adjacent slot
## (the sim spreads them; extra miners hover nearby as relief workers).
func order_group_mine(ids: Array, node_id: String) -> int:
	var n: int = 0
	for uid_v in ids:
		if issue_mine_order(str(uid_v), node_id) == "":
			n += 1
	return n

## MINING MODE (⛏ button): each selected unit finds its own nearest live
## vein and gets to work — no need to hunt for a node to right-click.
func order_group_mine_auto(ids: Array) -> int:
	var e = _engine()
	if e == null:
		return 0
	var n: int = 0
	for uid_v in ids:
		var ent = e._dung_find(str(uid_v))
		if ent == null or bool(ent.get("is_dead", false)):
			continue
		var node = _nearest_live_node(ent)
		if node == null:
			continue
		if issue_mine_order(str(uid_v), str(node.get("id", ""))) == "":
			n += 1
	return n

## ATTACK-MOVE for a hand-picked selection: group-march to (tx, ty) in a
## loose 3×3 spread while auto-engaging anything sighted on the way.
## Returns how many units received the order.
func set_aggro_move(ids: Array, tx: int, ty: int) -> int:
	var e = _engine()
	if e == null:
		return 0
	var n: int = 0
	var idx: int = 0
	for uid_v in ids:
		var uid: String = str(uid_v)
		var ent = e._dung_find(uid)
		if ent == null or bool(ent.get("is_dead", false)):
			continue
		if int(ent.get("battle_team", -1)) != player_team:
			continue
		var ox: int = idx % 3 - 1
		var oy: int = int(float(idx) / 3.0) % 3 - 1
		var pos: Vector2i = _nearest_floor(tx + ox, ty + oy, 4)
		issue_move_order(uid, pos.x, pos.y)
		ent["aggro"] = true
		idx += 1
		n += 1
	return n

## Run one leg of a unit's standing order: chase-and-strike for attack
## orders, march-until-arrived for move orders. Safe on entities without
## order fields (they simply do nothing).
func _execute_unit_order(ent) -> void:
	var e = _engine()
	if e == null or ent == null:
		return
	if bool(ent.get("is_dead", false)):
		return
	var tid: String = str(ent.get("order_target", ""))
	if tid != "":
		var target = e._dung_find(tid)
		if target == null or bool(target.get("is_dead", false)):
			ent["order_target"] = ""
			return
		if _chebyshev(ent, target) > 1 and int(ent.get("speed", 0)) > 0:
			e._enemy_move_toward(ent, target, int(ent["speed"]))
		if _chebyshev(ent, target) <= 1:
			var logs: Array = []
			_do_battle_attack(ent, target, logs)
			for line in logs:
				battle_log_extra.append(line)
		return
	var dx: int = int(ent.get("order_dest_x", -1))
	var dy: int = int(ent.get("order_dest_y", -1))
	if dx < 0 or dy < 0:
		return
	if int(ent.get("speed", 0)) > 0:
		e._enemy_move_toward(ent, {"x": dx, "y": dy}, int(ent["speed"]))
	if absi(int(ent["x"]) - dx) + absi(int(ent["y"]) - dy) == 0:
		ent["order_dest_x"] = -1
		ent["order_dest_y"] = -1

# ──────────────────────────────────────────────────────────────────────────
# Squads (control groups)
# ──────────────────────────────────────────────────────────────────────────

## Bind a set of unit ids to squad slot `sid` (1..4).
func assign_squad(sid: int, ids: Array) -> void:
	var arr: Array = []
	for uid in ids:
		arr.append(str(uid))
	squads[sid] = arr

## Living members of a squad (also prunes dead/missing ids in place).
func squad_members(sid: int) -> Array:
	var e = _engine()
	if e == null or not squads.has(sid):
		return []
	var out: Array = []
	for uid in squads[sid]:
		var ent = e._dung_find(str(uid))
		if ent != null and not bool(ent.get("is_dead", false)):
			out.append(str(uid))
	squads[sid] = out
	return out

## Which squad a unit belongs to (0 when unassigned).
func squad_of(unit_id: String) -> int:
	for sid in squads:
		if (squads[sid] as Array).has(unit_id):
			return int(sid)
	return 0

## March the whole squad toward (tx, ty) in a loose 3×3 formation.
## Returns how many members received an order.
func squad_move(sid: int, tx: int, ty: int) -> int:
	var n: int = 0
	var idx: int = 0
	for uid in squad_members(sid):
		# Spread members over a 3×3 grid around the click, snapped to floor.
		var ox: int = idx % 3 - 1
		var oy: int = int(float(idx) / 3.0) % 3 - 1
		var pos: Vector2i = _nearest_floor(tx + ox, ty + oy, 4)
		issue_move_order(str(uid), pos.x, pos.y)
		idx += 1
		n += 1
	return n

## Focus-fire: every squad member gets an attack order on the target.
## Returns how many members received an order.
func squad_attack(sid: int, target_id: String) -> int:
	var n: int = 0
	for uid in squad_members(sid):
		issue_attack_order(str(uid), target_id)
		n += 1
	return n

## Ad-hoc GROUP orders — any hand-picked selection of unit ids gets the same
## action (shift-click multi-select in the scene). Same formation spread as
## squads, but no squad slot needed.
func order_group_move(ids: Array, tx: int, ty: int) -> int:
	var e = _engine()
	if e == null: return 0
	var n: int = 0
	var idx: int = 0
	for uid_v in ids:
		var uid: String = str(uid_v)
		var ent = e._dung_find(uid)
		if ent == null or bool(ent.get("is_dead", false)): continue
		if int(ent.get("battle_team", -1)) != player_team: continue
		var ox: int = idx % 3 - 1
		var oy: int = int(float(idx) / 3.0) % 3 - 1
		var pos: Vector2i = _nearest_floor(tx + ox, ty + oy, 4)
		issue_move_order(uid, pos.x, pos.y)
		idx += 1
		n += 1
	return n

func order_group_attack(ids: Array, target_id: String) -> int:
	var e = _engine()
	if e == null: return 0
	var n: int = 0
	for uid_v in ids:
		var uid: String = str(uid_v)
		var ent = e._dung_find(uid)
		if ent == null or bool(ent.get("is_dead", false)): continue
		if int(ent.get("battle_team", -1)) != player_team: continue
		issue_attack_order(uid, target_id)
		n += 1
	return n

# ──────────────────────────────────────────────────────────────────────────
# Entity construction helpers
# ──────────────────────────────────────────────────────────────────────────

## Minimum-viable battle entity matching the engine's dungeon dict shape.
## Callers overwrite hp/ac/speed/weapon and produce_unit fills id/x/y/team.
func _new_entity(disp_name: String, lin: String) -> Dictionary:
	return {
		"id":     "",           # set by produce_unit / spawner
		"name":   disp_name,
		"handle": -1,           # no roster character behind battle units
		"lineage_name": lin,    # drives the sprite/portrait choice
		"x": 0, "y": 0, "z": 1,
		"is_player":   false,
		"is_friendly": false,
		"is_dead":     false,
		"is_flying":   false,
		"hp": 10, "max_hp": 10,
		"ap": 10, "max_ap": 10,
		"sp": 0,  "max_sp": 0,
		"ac": 10,
		"speed": 5,
		"size": 1,              # tiles of body radius +1; kaiju = 3, big vehicles = 2
		"ap_spent": 0,
		"actions_taken": 0,
		"move_used": 0,
		"hit_bonus_buff": 0,
		"hit_penalty": 0,
		"equipped_weapon": "Unarmed",
		"equipped_armor":  "None",
		"equipped_shield": "None",
		"equipped_light":  "None",
		"conditions": [],
		"abilities":  [],
		"ability_cooldowns": {},
		"stats": [unit_level, unit_level, unit_level, unit_level, unit_level],
		"inventory": [],
		"looted": false,
		"morale": 99,           # battle units never rout
		"order_dest_x": -1,     # standing move order (-1 = none)
		"order_dest_y": -1,
		"order_target": "",     # standing attack order ("" = none)
		# ── Real-time simulation fields ──
		"move_cd": 0.0,         # seconds until the next tile step
		"attack_cd": 0.0,       # seconds until the next swing
		"atk_interval": 1.5,    # seconds between swings (per builder)
		"path": [],             # cached _crawl_pathfind result (Vector2i)
		"repath_cd": 0.0,       # seconds until a forced re-path
		"osc_a": "",            # anti-ping-pong: last tile stepped onto ("x,y")
		"osc_b": "",            # anti-ping-pong: the tile before that
		"osc_n": 0,             # consecutive there-and-back bounces
		"force_repath": false,  # >5 bounces → skip greedy, demand real A*
		"aggro": false,         # attack-move: auto-acquire while marching
		"spells": [],           # [{name, cd_left}] battle spell loadout
		"atk_mode": "auto",     # "auto" | "weapons" | "magic" (player choice)
	}

## The team's Command Post: an immobile structure that produces units and
## can only defend itself against adjacent attackers.
func _make_base(team: int, x: int, y: int) -> Dictionary:
	var b: Dictionary = _new_entity("T%d Command Post" % team, "Construct")
	_unit_counter += 1
	b["id"] = "bt%d_base_%d" % [team, _unit_counter]
	b["x"] = x
	b["y"] = y
	_set_hp(b, BASE_HP)
	b["ac"] = BASE_AC
	b["speed"] = 0              # structures never move
	b["equipped_weapon"] = "None"
	b["is_battle_base"] = true  # marks production / income sources
	_apply_team_flags(b, team)
	return b

## Neutral resource node. Reuses the CHEST shape so the dungeon scene
## renders it and combat/outcome checks ignore it, plus a custom flag so
## the economy can find it.
func _spawn_resource_node(x: int, y: int) -> void:
	var e = _engine()
	if e == null:
		return
	var pos: Vector2i = _nearest_floor(x, y, 6)
	_unit_counter += 1
	e._dungeon_entities.append({
		"id":     "bt_node_%d" % _unit_counter,
		"name":   "Resource Node",
		"handle": -1,
		"lineage_name": "Chest",
		"x": pos.x, "y": pos.y, "z": 1,
		"is_player":   false,
		"is_friendly": false,
		"is_dead":     false,
		"is_flying":   false,
		"hp": 1, "max_hp": 1,
		"ap": 0, "max_ap": 0,
		"sp": 0, "max_sp": 0,
		"ac": 10,
		"speed": 0,
		"ap_spent": 0,
		"actions_taken": 0,
		"move_used": 0,
		"hit_bonus_buff": 0,
		"hit_penalty": 0,
		"equipped_weapon": "None",
		"equipped_armor":  "None",
		"equipped_shield": "None",
		"equipped_light":  "None",
		"conditions": [],
		"abilities":  [],
		"ability_cooldowns": {},
		"stats": [0, 0, 0, 0, 0],
		"inventory": [],
		"looted": false,
		"morale": 99,
		"is_chest": true,           # renders like a chest, ignored by combat
		"is_resource_node": true,   # economy marker
		# Finite supply reserve — vein size follows the abundance setting.
		"amount": randi_range(int(_res_cfg()["amt_lo"]), int(_res_cfg()["amt_hi"])),
	})

## Stamp ownership onto a battle entity. Only the player's team is
## controllable / friendly; every other team is hostile to everyone.
func _apply_team_flags(ent: Dictionary, team: int) -> void:
	ent["battle_team"] = team
	ent["is_player"] = team == player_team
	ent["is_friendly"] = team == player_team

## Set hp and max_hp together.
func _set_hp(ent: Dictionary, hp: int) -> void:
	ent["hp"] = hp
	ent["max_hp"] = hp

## Catalog keys become id fragments: "lineage:High Elf" → "lineage_high_elf".
func _sanitize_key(key: String) -> String:
	return key.replace(":", "_").replace(" ", "_").replace("'", "").to_lower()

# ──────────────────────────────────────────────────────────────────────────
# Query helpers
# ──────────────────────────────────────────────────────────────────────────

## The team's living Command Post (live dict) or null.
func _find_team_base(team: int):
	var b = _team_bases.get(team)
	if b != null and bool(b.get("is_dead", false)):
		return null
	return b

## True while the team owns ANY living non-chest entity.
func _team_has_living(team: int) -> bool:
	if team < 0 or team >= _team_ents.size():
		return false
	for ent in _team_ents[team]:
		if not bool(ent.get("is_dead", false)):
			return true
	return false

## Nearest living entity on a DIFFERENT team within SIGHT_RANGE (Manhattan),
## or null when nothing hostile is visible.
func _nearest_enemy_of(ent: Dictionary, max_d: int = SIGHT_RANGE):
	var my_team: int = int(ent.get("battle_team", -1))
	var ex: int = int(ent.get("x", 0))
	var ey: int = int(ent.get("y", 0))
	var best = null
	var best_d: int = max_d + 1
	# Query only spatial hash cells within max_d range.
	var cr: int = (max_d / CELL_SIZE) + 1
	var cx0: int = (ex / CELL_SIZE) - cr
	var cy0: int = (ey / CELL_SIZE) - cr
	var cx1: int = (ex / CELL_SIZE) + cr
	var cy1: int = (ey / CELL_SIZE) + cr
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			var cell: Array = _spatial.get(cy * 1000 + cx, [])
			for other in cell:
				if int(other.get("battle_team", -1)) == my_team:
					continue
				var d: int = absi(int(other["x"]) - ex) + absi(int(other["y"]) - ey)
				if d < best_d:
					best_d = d
					best = other
	return best

## Nearest living enemy Command Post anywhere on the map (no sight limit —
## this is the AI's long-range march target), or null.
func _nearest_enemy_base_of(ent: Dictionary):
	var my_team: int = int(ent.get("battle_team", -1))
	var best = null
	var best_d: int = 999999
	for bt in _team_bases.keys():
		if int(bt) == my_team:
			continue
		var other = _team_bases[bt]
		if other == null or bool(other.get("is_dead", false)):
			continue
		var d: int = _manhattan(ent, other)
		if d < best_d:
			best_d = d
			best = other
	return best

## A living enemy standing adjacent (Chebyshev <= 1), or null.
func _adjacent_enemy_of(ent: Dictionary):
	# O(8) via the per-step occupancy map — this runs for every idle unit
	# and structure, so it must never walk the whole entity list.
	var my_team: int = int(ent.get("battle_team", -1))
	var ex: int = int(ent.get("x", 0))
	var ey: int = int(ent.get("y", 0))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var oid: String = str(_occ.get((ey + dy) * _occ_ms + (ex + dx), ""))
			if oid == "":
				continue
			var other = _ent_index.get(oid)
			if other == null or bool(other.get("is_dead", false)) \
					or bool(other.get("is_chest", false)):
				continue
			if not other.has("battle_team"):
				continue
			if int(other["battle_team"]) == my_team:
				continue
			return other
	return null

## Rebuild the engine's player queue from the player team's living units
## so the dungeon scene's turn cycling works unchanged in battle mode.
func _rebuild_player_queue() -> void:
	var e = _engine()
	if e == null:
		return
	e._dungeon_player_queue = []
	for ent in e._dungeon_entities:
		if bool(ent.get("is_dead", false)) or bool(ent.get("is_chest", false)):
			continue
		if int(ent.get("battle_team", -1)) != player_team:
			continue
		e._dungeon_player_queue.append(str(ent["id"]))

## Manhattan distance between two entity dicts.
func _manhattan(a: Dictionary, b: Dictionary) -> int:
	return absi(int(a["x"]) - int(b["x"])) + absi(int(a["y"]) - int(b["y"]))

## Chebyshev (king-move) distance between two entity dicts.
func _chebyshev(a: Dictionary, b: Dictionary) -> int:
	return maxi(absi(int(a["x"]) - int(b["x"])), absi(int(a["y"]) - int(b["y"])))

# ──────────────────────────────────────────────────────────────────────────
# Map helpers
# ──────────────────────────────────────────────────────────────────────────

## Guarantee every team can reach the fight: carve a central plaza, a 3×3
## pad under each team position, and a 3-tile-wide L-shaped lane from each
## pad to the center. Runs BEFORE bases are placed, so no team ever starts
## stranded inside solid rock.
func _carve_battle_lanes(team_positions: Array) -> void:
	var e = _engine()
	if e == null:
		return
	var ms: int = int(e.MAP_SIZE)
	var c: int = int(float(ms) / 2.0)
	# Central plaza: 10×10 block of floor around the map middle.
	for y in range(c - 5, c + 5):
		for x in range(c - 5, c + 5):
			_carve_floor(x, y)
	for pos in team_positions:
		var p: Vector2i = pos
		# 3×3 landing pad under the team's start position.
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				_carve_floor(p.x + dx, p.y + dy)
		# L-lane leg 1: horizontal run at p.y (3 rows) from p.x to center x.
		for x in range(mini(p.x, c), maxi(p.x, c) + 1):
			for dy in range(-1, 2):
				_carve_floor(x, p.y + dy)
		# L-lane leg 2: vertical run at center x (3 cols) from p.y to center y.
		for y in range(mini(p.y, c), maxi(p.y, c) + 1):
			for dx in range(-1, 2):
				_carve_floor(c + dx, y)

## Set one tile to floor, clamped inside the map's border walls.
func _carve_floor(x: int, y: int) -> void:
	var e = _engine()
	if e == null:
		return
	var ms: int = int(e.MAP_SIZE)
	if x < 1 or y < 1 or x > ms - 2 or y > ms - 2:
		return
	e._dungeon_map[y * ms + x] = 1  # TILE_FLOOR

## Nearest walkable, unoccupied floor tile to (cx, cy), searched in
## expanding square rings (spiral). If none exists within max_r, FORCE a
## 3×3 floor patch at the center — base/spawn placement must never fail.
func _nearest_floor(cx: int, cy: int, max_r: int = 6) -> Vector2i:
	var e = _engine()
	if e == null:
		return Vector2i(cx, cy)
	var ms: int = int(e.MAP_SIZE)
	# Keep the anchor inside the map's border walls.
	cx = clampi(cx, 1, ms - 2)
	cy = clampi(cy, 1, ms - 2)
	for r in range(0, max_r + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				# Only inspect the ring border — inner tiles were already
				# covered by smaller radii.
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var tx: int = cx + dx
				var ty: int = cy + dy
				if tx < 1 or ty < 1 or tx > ms - 2 or ty > ms - 2:
					continue
				# TILE_FLOOR == 1 and nobody standing there.
				if e._dung_tile(tx, ty) == 1 and not e._dung_occupied(tx, ty):
					return Vector2i(tx, ty)
	# No floor nearby (solid rock pocket) — carve a 3×3 clearing so the
	# caller always gets a usable tile.
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var px: int = clampi(cx + dx, 1, ms - 2)
			var py: int = clampi(cy + dy, 1, ms - 2)
			e._dungeon_map[py * ms + px] = 1
	return Vector2i(cx, cy)

## Rewrite the generated cave layout into an OPEN region-style battlefield:
## walkable field bordered by walls, with scattered obstacle clusters
## (rocks/groves) for cover and chokepoints — the explore-outskirts look.
## Runs inside start_battle's seeded section, so each region's field layout
## is deterministic. Lane/plaza carving afterwards guarantees connectivity.
func _open_battlefield() -> void:
	var e = _engine()
	if e == null:
		return
	var ms: int = int(e.MAP_SIZE)
	# 1. Open field: border walls, everything else floor.
	for y in range(ms):
		for x in range(ms):
			var border: bool = (x == 0 or y == 0 or x == ms - 1 or y == ms - 1)
			e._dungeon_map[y * ms + x] = 2 if border else 1   # 2=WALL, 1=FLOOR
	# 2. Scattered obstacle clusters — count and exclusion zone scale with
	#    map area so bigger battlefields stay proportionally covered.
	var center: int = ms / 2
	var num_blobs: int = maxi(14, int(float(ms * ms) / 400.0))   # ~14 at 75, ~56 at 150
	var plaza_r: int   = maxi(6, ms / 12)                         # ~6 at 75, ~12 at 150
	for _c in range(num_blobs):
		var bx: int = randi_range(3, ms - 4)
		var by: int = randi_range(3, ms - 4)
		if absi(bx - center) < plaza_r and absi(by - center) < plaza_r:
			continue   # leave the midfield open
		var blob: int = randi_range(2, 6)
		var px: int = bx
		var py: int = by
		for _b in range(blob):
			e._dungeon_map[py * ms + px] = 3   # 3=OBSTACLE (rocks/grove)
			px = clampi(px + randi_range(-1, 1), 2, ms - 3)
			py = clampi(py + randi_range(-1, 1), 2, ms - 3)
