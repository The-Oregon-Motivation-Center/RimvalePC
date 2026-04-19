## game_state.gd
## Global game state — autoloaded as "GameState".
## Mirrors the mobile app's player state, team, collection, and economy.

extends Node

# ── Player / Summoner ─────────────────────────────────────────────────────────
var player_name: String = "Agent"
var player_level: int = 1
var player_xp: int = 0
var player_xp_required: int = 1000
var player_rank: String = "Recruit"

# ── Economy ───────────────────────────────────────────────────────────────────
var gold: int = 500
var tokens: int = 5
var remnant_fragments: int = 0

const TOKENS_PER_RF_TRADE: int = 100   # 100 RF → 10 tokens
const RF_TO_TOKENS_RATE: int = 10

# ── Team ──────────────────────────────────────────────────────────────────────
const ACTIVE_TEAM_SIZE: int = 5

## Active strike team — array of int handles (or -1 for empty slot)
var active_team: Array = [-1, -1, -1, -1, -1]

## Full character collection — all owned character handles
var collection: Array = []

## Handles currently busy with crafting / foraging tasks
var busy_handles: Array = []

# ── Director ──────────────────────────────────────────────────────────────────
var director_message: String = "Welcome back, Agent. Your units await orders."

# ── Navigation ────────────────────────────────────────────────────────────────
var current_tab: int = 0   # 0=Units 1=World 2=Shop 3=Codex 4=Profile

# ── Crafting / Foraging ───────────────────────────────────────────────────────
class CraftingTask:
	var character_handle: int = -1
	var character_name: String = ""
	var item_type: String = ""
	var end_time: float = 0.0  # OS.get_unix_time() + duration

class ForageTask:
	var character_handle: int = -1
	var character_name: String = ""
	var forage_type: String = ""  # Hunting / Fishing / Mining / Gathering
	var end_time: float = 0.0
	var gold_reward: int = 0

var crafting_tasks: Array = []
var forage_tasks: Array = []

# ── Rituals ───────────────────────────────────────────────────────────────────
## In-progress ritual tasks (not yet successfully cast, awaiting check)
var ritual_tasks: Array = []
## Active rituals (cast successfully, ready to use in dungeon)
var active_rituals: Array = []

# ── Story ─────────────────────────────────────────────────────────────────────
## IDs of completed story/training missions
var story_completed_missions: Array = []
## Badge names earned (matches STORY_SECTIONS badge_name field)
var story_earned_badges: Array = []

# ── Overworld ────────────────────────────────────────────────────────────────
## Currently-selected major region on the Rimvale map (id from OVERWORLD_REGIONS).
var current_region: String = "plains"
## Currently-focused sub-region (name from _LINEAGE_REGIONS), or "" for region-view.
var current_subregion: String = ""
## Major region ids the party has visited at least once.
var visited_regions: Array = []
## Sub-region names the party has visited at least once.
var visited_subregions: Array = []
## IDs of ACF locations that have been cleared (for tracking progress).
var cleared_acf_locations: Array = []

# ── Base Building ─────────────────────────────────────────────────────────────
## Base tier (1-5). Determines max facilities and defender cap.
var base_tier: int = 1
## Base stats
var base_supplies: int = 50
var base_defense: int  = 10
var base_morale: int   = 10
var base_acreage: int  = 2
## Array of facility type indices that have been built (indices into FACILITY_DEFS).
var base_facilities: Array = [0]   # Command Center always built at start

## Tier → max facilities allowed, max defenders
const BASE_TIER_CAPS: Array = [
	{"max_fac": 2,  "max_def": 4},     # Tier 1
	{"max_fac": 4,  "max_def": 10},    # Tier 2
	{"max_fac": 6,  "max_def": 20},    # Tier 3
	{"max_fac": 8,  "max_def": 40},    # Tier 4
	{"max_fac": 10, "max_def": 100},   # Tier 5
]

## Facility definitions: name, icon, description, gold_cost, rf_cost, required_tier, prereqs, bonuses
const FACILITY_DEFS: Array = [
	{"name":"Command Center",     "icon":"🏛", "desc":"Coordinates field operations. Unlocks squad deployment and mission board refresh.",
	 "gold":0,   "rf":0,  "tier":1, "prereqs":[], "bonus":"deploy_squads"},
	{"name":"Workshop",           "icon":"🔧", "desc":"Crafting and gear repair. +2 to crafting checks, halves repair costs.",
	 "gold":400, "rf":2,  "tier":1, "prereqs":[], "bonus":"craft_boost"},
	{"name":"Arcane Library",     "icon":"📚", "desc":"Research spells and rituals. +2 to Arcane and Learnedness checks.",
	 "gold":300, "rf":0,  "tier":1, "prereqs":[], "bonus":"arcane_boost"},
	{"name":"Barracks",           "icon":"🛡", "desc":"Houses defenders for base protection. Capacity based on tier.",
	 "gold":350, "rf":1,  "tier":1, "prereqs":[], "bonus":"defenders"},
	{"name":"Healing Garden",     "icon":"🌿", "desc":"Grows herbs and food. Produces reagents over time.",
	 "gold":250, "rf":0,  "tier":1, "prereqs":[], "bonus":"herb_production"},
	{"name":"Armory",             "icon":"⚙",  "desc":"Weapons and armor storage. Defenders gain +2 AC.",
	 "gold":400, "rf":2,  "tier":1, "prereqs":[], "bonus":"defender_ac"},
	{"name":"Alchemy Lab",       "icon":"⚗",  "desc":"Brew potions and crafting reagents. Unlocks advanced recipes.",
	 "gold":500, "rf":3,  "tier":1, "prereqs":[], "bonus":"alchemy"},
	{"name":"Naval Yard",         "icon":"⚓", "desc":"Build aquatic vehicles and muster naval units.",
	 "gold":600, "rf":4,  "tier":2, "prereqs":[0], "bonus":"naval"},
	{"name":"Healing Ward",       "icon":"✚",  "desc":"Post-encounter HP regen and status removal for all party members.",
	 "gold":450, "rf":2,  "tier":2, "prereqs":[4], "bonus":"hp_regen"},
	{"name":"Siege Workshop",     "icon":"💣", "desc":"Access to siege weapons. +2 to breaching checks.",
	 "gold":700, "rf":5,  "tier":3, "prereqs":[1,5], "bonus":"siege"},
	{"name":"Resonance Chamber",  "icon":"💠", "desc":"Amplifies magical affinities. Reduces ritual cast time by 20%.",
	 "gold":800, "rf":4,  "tier":2, "prereqs":[2,6], "bonus":"ritual_boost"},
]

func get_base_max_facilities() -> int:
	var idx: int = clampi(base_tier - 1, 0, BASE_TIER_CAPS.size() - 1)
	return int(BASE_TIER_CAPS[idx]["max_fac"])

func get_base_max_defenders() -> int:
	var idx: int = clampi(base_tier - 1, 0, BASE_TIER_CAPS.size() - 1)
	return int(BASE_TIER_CAPS[idx]["max_def"])

func get_base_defense_mod() -> int:
	if base_acreage <= 2:   return 2
	elif base_acreage <= 5: return 1
	elif base_acreage <= 10: return 0
	elif base_acreage <= 20: return -1
	else: return -2

func can_build_facility(fac_idx: int) -> Dictionary:
	if fac_idx in base_facilities:
		return {"ok": false, "reason": "Already built"}
	if base_facilities.size() >= get_base_max_facilities():
		return {"ok": false, "reason": "Max facilities reached (Tier %d)" % base_tier}
	var fac: Dictionary = FACILITY_DEFS[fac_idx]
	if int(fac["tier"]) > base_tier:
		return {"ok": false, "reason": "Requires Base Tier %d" % int(fac["tier"])}
	for pre in fac["prereqs"]:
		if int(pre) not in base_facilities:
			var pre_name: String = FACILITY_DEFS[int(pre)]["name"]
			return {"ok": false, "reason": "Requires %s" % pre_name}
	if gold < int(fac["gold"]):
		return {"ok": false, "reason": "Need %dg (have %dg)" % [int(fac["gold"]), gold]}
	if remnant_fragments < int(fac["rf"]):
		return {"ok": false, "reason": "Need %d RF (have %d)" % [int(fac["rf"]), remnant_fragments]}
	return {"ok": true, "reason": ""}

func build_facility(fac_idx: int) -> bool:
	var check: Dictionary = can_build_facility(fac_idx)
	if not bool(check["ok"]):
		return false
	var fac: Dictionary = FACILITY_DEFS[fac_idx]
	gold -= int(fac["gold"])
	remnant_fragments -= int(fac["rf"])
	base_facilities.append(fac_idx)
	save_game()
	return true

func upgrade_base_tier() -> bool:
	if base_tier >= 5:
		return false
	var cost_gold: int = 500 * base_tier
	var cost_rf: int   = 3 * base_tier
	if gold < cost_gold or remnant_fragments < cost_rf:
		return false
	gold -= cost_gold
	remnant_fragments -= cost_rf
	base_tier += 1
	save_game()
	return true

func has_facility(bonus_name: String) -> bool:
	for fi in base_facilities:
		if str(FACILITY_DEFS[int(fi)]["bonus"]) == bonus_name:
			return true
	return false

# ── Ally Recruitment ──────────────────────────────────────────────────────────
## Recruited allies the player can summon into dungeons.
## Each entry: {"type":"militia"|"mob"|"kaiju", "def_idx":int, "name":String, "level":int, ...}
var recruited_allies: Array = []

## Ally category: Militia, Mob, or Kaiju
## Militia definitions — 15 types from Mobile C++ Militia.h
const MILITIA_TYPES: Array = [
	{"name":"Guard",           "desc":"Shield specialists. +3 AC, hold-ground experts.",                   "ac_bonus":3, "dmg_bonus":0, "trait":"ShieldWall"},
	{"name":"Raid",            "desc":"Offensive skirmishers. +2 attack and damage.",                      "ac_bonus":0, "dmg_bonus":2, "trait":"AmbushTactics"},
	{"name":"Recon",           "desc":"Scouts. +2 tracking and stealth checks.",                           "ac_bonus":0, "dmg_bonus":0, "trait":"GuerillaFighters"},
	{"name":"Sacred",          "desc":"Holy warriors. Healing costs -2 SP (min 1).",                       "ac_bonus":0, "dmg_bonus":0, "trait":"DivineZeal"},
	{"name":"Arcane",          "desc":"Mage militia. Can cast rituals in combat.",                          "ac_bonus":0, "dmg_bonus":0, "trait":"ArcaneDisruption"},
	{"name":"Hunter",          "desc":"Monster slayers. +2 attack vs Large+ creatures.",                   "ac_bonus":0, "dmg_bonus":0, "trait":"RelentlessPursuit"},
	{"name":"Merchant Guard",  "desc":"Caravan protectors. Resist ranged ambushes.",                       "ac_bonus":1, "dmg_bonus":0, "trait":"IronDiscipline"},
	{"name":"Engineer",        "desc":"Combat builders. Deploy barricades once per combat.",                "ac_bonus":0, "dmg_bonus":0, "trait":"SiegeBreakers"},
	{"name":"Nomad",           "desc":"Desert wanderers. +10ft movement, ignore difficult terrain.",       "ac_bonus":0, "dmg_bonus":0, "trait":"Skirmishers"},
	{"name":"Seafaring",       "desc":"Naval marines. Advantage on water and boarding checks.",             "ac_bonus":0, "dmg_bonus":0, "trait":"IronDiscipline"},
	{"name":"Crusader",        "desc":"Zealous fighters. When bloodied: +2 attack and damage.",            "ac_bonus":0, "dmg_bonus":0, "trait":"BloodOath"},
	{"name":"Shadow",          "desc":"Covert operatives. Advantage on ambushes; crit on 18-20.",          "ac_bonus":0, "dmg_bonus":0, "trait":"AmbushTactics"},
	{"name":"Arcane Reclaimer","desc":"Anti-magic specialists. +2 Arcane; can dispel (DC 15).",            "ac_bonus":0, "dmg_bonus":0, "trait":"ArcaneDisruption"},
	{"name":"Storm",           "desc":"Lightning-hardened troops. Resist lightning and thunder.",           "ac_bonus":0, "dmg_bonus":0, "trait":"BattleChant"},
	{"name":"Iron Legionnaire","desc":"Heavy infantry. +1 AC and +1d4 damage in formation.",               "ac_bonus":1, "dmg_bonus":1, "trait":"ShieldWall"},
]

## Equipment tiers for militia
const MILITIA_EQUIP_TIERS: Array = [
	{"name":"Improvised",  "ac":14, "dmg_bonus":0, "gold":50},
	{"name":"Standard",    "ac":16, "dmg_bonus":2, "gold":150},
	{"name":"Elite",       "ac":18, "dmg_bonus":5, "gold":400},
	{"name":"Advanced",    "ac":20, "dmg_bonus":8, "gold":800},
]

## Mob definitions — 6 moods × variety
const MOB_MOODS: Array = ["Enraged", "Terrified", "Jubilant", "Desperate", "Opportunistic", "Frenzied"]
const MOB_TRAITS: Array = [
	{"name":"Firestarters", "desc":"Can ignite objects as group action."},
	{"name":"Swarm",        "desc":"Move through obstacles as difficult terrain."},
	{"name":"Opportunists", "desc":"Loot and steal with +2 bonus."},
	{"name":"Unstoppable",  "desc":"Ignore the first failed morale check."},
	{"name":"Quick Learners","desc":"+1 attack after each miss (max +1/round)."},
	{"name":"Mob Healers",  "desc":"Heal 1d4 HP every round."},
	{"name":"Shadowed",     "desc":"Advantage on stealth at night."},
	{"name":"Ironhide",     "desc":"Resist non-magical bludgeoning."},
	{"name":"Cacophony",    "desc":"Enemies have disadvantage on perception in 300ft."},
	{"name":"Rallying Cry", "desc":"Once per encounter: +2 checks for allies in 30ft."},
	{"name":"Nimble Feet",  "desc":"Movement speed +10ft."},
	{"name":"Keen Senses",  "desc":"Advantage on perception vs hidden threats."},
]

const MOB_LEADERS: Array = [
	{"name":"None",      "desc":"No leader."},
	{"name":"Firebrand", "desc":"Once per encounter: +2 attack for one round."},
	{"name":"Coward",    "desc":"+2 morale when fleeing, -2 attacks."},
	{"name":"Trickster", "desc":"Once per encounter: bypass barriers."},
	{"name":"Brute",     "desc":"+1 dmg per 5 members for one round, -2 AC."},
	{"name":"Prophet",   "desc":"Immune to fear effects."},
	{"name":"Scavenger", "desc":"Loot twice as fast."},
	{"name":"Whisperer", "desc":"Near-silence, advantage stealth."},
	{"name":"Bulwark",   "desc":"+3 AC, -10ft movement in formation."},
	{"name":"Madman",    "desc":"Act twice, roll instinct at turn end."},
	{"name":"Shadow",    "desc":"Can hide or disperse instantly."},
]

## Kaiju available for recruitment (matched to DD_KAIJUS in world.gd)
const KAIJU_RECRUITS: Array = [
	{"name":"Pyroclast",         "title":"the Living Volcano",      "level":12, "hp":200, "ac":22, "gold":2000, "rf":10},
	{"name":"Grondar",           "title":"the Mountain King",       "level":13, "hp":220, "ac":23, "gold":2500, "rf":12},
	{"name":"Thal'Zuur",         "title":"the Drowned One",         "level":14, "hp":240, "ac":24, "gold":3000, "rf":15},
	{"name":"Ny'Zorrak",         "title":"the Starborn Maw",        "level":15, "hp":280, "ac":25, "gold":4000, "rf":20},
	{"name":"Mirecoast Sleeper", "title":"the Tidemaker Colossus",  "level":14, "hp":250, "ac":24, "gold":3200, "rf":16},
	{"name":"Aegis Ultima",      "title":"the Arcane Sentinel",     "level":13, "hp":210, "ac":23, "gold":2800, "rf":14},
]

## Recruit a militia squad. Returns true on success.
func recruit_militia(type_idx: int, equip_tier: int, member_count: int, custom_name: String = "") -> bool:
	if type_idx < 0 or type_idx >= MILITIA_TYPES.size(): return false
	if equip_tier < 0 or equip_tier >= MILITIA_EQUIP_TIERS.size(): return false
	member_count = clampi(member_count, 3, 20)
	var cost_per: int = 25 + MILITIA_EQUIP_TIERS[equip_tier]["gold"]
	var total_gold: int = cost_per * member_count / 5
	if gold < total_gold: return false
	gold -= total_gold
	var mtype: Dictionary = MILITIA_TYPES[type_idx]
	var tier: Dictionary  = MILITIA_EQUIP_TIERS[equip_tier]
	var level: int = 1 + equip_tier * 2
	var hp: int = 10 * level + member_count * 3
	var display_name: String = custom_name if custom_name != "" else "%s Militia" % mtype["name"]
	recruited_allies.append({
		"type": "militia", "def_idx": type_idx, "equip_tier": equip_tier,
		"name": display_name, "level": level, "members": member_count,
		"hp": hp, "max_hp": hp,
		"ac": int(tier["ac"]) + int(mtype["ac_bonus"]),
		"dmg_bonus": int(tier["dmg_bonus"]) + int(mtype["dmg_bonus"]),
		"speed": 5, "trait": mtype["trait"],
	})
	save_game()
	return true

## Recruit a mob. Returns true on success.
func recruit_mob(member_count: int, trait_idx: int, leader_idx: int, custom_name: String = "") -> bool:
	member_count = clampi(member_count, 5, 50)
	if trait_idx < 0 or trait_idx >= MOB_TRAITS.size(): return false
	if leader_idx < 0 or leader_idx >= MOB_LEADERS.size(): return false
	var cost: int = member_count * 10
	if gold < cost: return false
	gold -= cost
	var hp_per: int = 3
	var total_hp: int = member_count * hp_per
	var display_name: String = custom_name if custom_name != "" else "%s Mob" % MOB_TRAITS[trait_idx]["name"]
	recruited_allies.append({
		"type": "mob", "def_idx": trait_idx, "leader_idx": leader_idx,
		"name": display_name, "level": maxi(1, member_count / 5),
		"members": member_count, "hp": total_hp, "max_hp": total_hp,
		"ac": 12, "dmg_bonus": 0, "speed": 5,
		"trait": MOB_TRAITS[trait_idx]["name"],
		"leader": MOB_LEADERS[leader_idx]["name"],
	})
	save_game()
	return true

## Recruit a kaiju. Requires Barracks facility. Returns true on success.
func recruit_kaiju(kaiju_idx: int) -> bool:
	if kaiju_idx < 0 or kaiju_idx >= KAIJU_RECRUITS.size(): return false
	if not has_facility("defenders"): return false  # Requires Barracks
	var k: Dictionary = KAIJU_RECRUITS[kaiju_idx]
	if gold < int(k["gold"]) or remnant_fragments < int(k["rf"]): return false
	gold -= int(k["gold"])
	remnant_fragments -= int(k["rf"])
	recruited_allies.append({
		"type": "kaiju", "def_idx": kaiju_idx,
		"name": "%s, %s" % [k["name"], k["title"]],
		"level": int(k["level"]),
		"hp": int(k["hp"]), "max_hp": int(k["hp"]),
		"ac": int(k["ac"]), "dmg_bonus": 10, "speed": 3,
		"members": 1, "trait": "Kaiju",
	})
	save_game()
	return true

## Dismiss an ally by index.
func dismiss_ally(idx: int) -> void:
	if idx >= 0 and idx < recruited_allies.size():
		recruited_allies.remove_at(idx)
		save_game()

# ── Quest / Dungeon tracking ──────────────────────────────────────────────────
## Quest state: tracks active and completed contracts/quests linked to dungeon
var quest_state: Dictionary = {
	"active_dungeon_quest": {},       # quest dict currently deployed to dungeon
	"completed_quest_ids": [],        # IDs of all completed dungeon quests
}

# ── Daily login ───────────────────────────────────────────────────────────────
var last_login_date: String = ""         # ISO date "YYYY-MM-DD"

# ── Rest tracking ─────────────────────────────────────────────────────────────
var short_rests_used: int = 0
const MAX_SHORT_RESTS: int = 3

# ── Player stash (shared item storage) ───────────────────────────────────────
var stash: Array = []   # Array of item name Strings

func add_to_stash(item_name: String) -> void:
	if item_name not in stash:
		stash.append(item_name)

func remove_from_stash(item_name: String) -> void:
	stash.erase(item_name)

# ── Overworld helpers ────────────────────────────────────────────────────────
func travel_to_region(region_id: String) -> void:
	current_region = region_id
	current_subregion = ""
	if region_id != "" and region_id not in visited_regions:
		visited_regions.append(region_id)
	save_game()

func travel_to_subregion(subregion_name: String) -> void:
	current_subregion = subregion_name
	if subregion_name != "" and subregion_name not in visited_subregions:
		visited_subregions.append(subregion_name)
	save_game()

func mark_acf_cleared(location_id: String) -> void:
	if location_id not in cleared_acf_locations:
		cleared_acf_locations.append(location_id)
		save_game()

func is_acf_cleared(location_id: String) -> bool:
	return location_id in cleared_acf_locations

# ── Selected hero (for level-up / inventory screens) ─────────────────────────
var selected_hero_handle: int = -1

# ── ─────────────────────────────────────────────────────────────────────────
# Team helpers
# ── ─────────────────────────────────────────────────────────────────────────

const SAVE_PATH: String = "user://rimvale_save.json"

## Whether the game state has been initialised (by title screen or fallback).
var _game_loaded: bool = false

func _ready() -> void:
	# No longer auto-loads here — the title screen calls load_game() or
	# start_new_game() explicitly.  As a safety net, _ensure_init() is called
	# the first time any gameplay scene queries the state.
	pass

## Called by the title screen when the player chooses "Continue".
## Returns true if the save loaded successfully.
func continue_game() -> bool:
	var ok := load_game()
	_game_loaded = true
	if not ok:
		_ensure_starter_units()
	return ok

## Called by the title screen when the player chooses "New Game".
func start_new_game() -> void:
	wipe_all()
	_game_loaded = true

## Safety net: if a gameplay scene runs before the title screen has set up
## the state (e.g. in-editor testing), auto-load just like before.
func ensure_init() -> void:
	if _game_loaded:
		return
	if FileAccess.file_exists(SAVE_PATH):
		load_game()
	else:
		_ensure_starter_units()
	_game_loaded = true

## Reset the loaded flag so the title screen can re-init on return.
func reset_loaded_flag() -> void:
	_game_loaded = false

## No default starter units — the game begins with the 10-token selection.
## Called deferred from _ready and also at the end of wipe_all.
func _ensure_starter_units() -> void:
	pass

func add_to_collection(handle: int) -> void:
	if handle not in collection:
		collection.append(handle)

func remove_from_collection(handle: int) -> void:
	collection.erase(handle)
	# Also remove from active team
	for i in range(ACTIVE_TEAM_SIZE):
		if active_team[i] == handle:
			active_team[i] = -1

func set_team_slot(slot: int, handle: int) -> void:
	if slot >= 0 and slot < ACTIVE_TEAM_SIZE:
		active_team[slot] = handle

func clear_team_slot(slot: int) -> void:
	if slot >= 0 and slot < ACTIVE_TEAM_SIZE:
		active_team[slot] = -1

func get_active_handles() -> Array:
	var result: Array = []
	for h in active_team:
		if h != -1:
			result.append(h)
	return result

func is_in_active_team(handle: int) -> bool:
	return handle in active_team

func is_busy(handle: int) -> bool:
	return handle in busy_handles

func set_busy(handle: int, busy: bool) -> void:
	if busy and handle not in busy_handles:
		busy_handles.append(handle)
	elif not busy:
		busy_handles.erase(handle)

func collection_has_any() -> bool:
	return collection.size() > 0

# ── Economy helpers ──────────────────────────────────────────────────────────

func can_trade_rf_for_tokens() -> bool:
	return remnant_fragments >= TOKENS_PER_RF_TRADE

func trade_rf_for_tokens() -> bool:
	if not can_trade_rf_for_tokens():
		return false
	remnant_fragments -= TOKENS_PER_RF_TRADE
	tokens += RF_TO_TOKENS_RATE
	return true

func spend_tokens(amount: int) -> bool:
	if tokens < amount:
		return false
	tokens -= amount
	return true

func earn_gold(amount: int) -> void:
	gold += amount

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	return true

# ── XP / Level-up ────────────────────────────────────────────────────────────

## XP required to reach the given level (from current level).
## Matches Rimvale Mobile thresholds: 1000 × level.
func _xp_for_level(lv: int) -> int:
	return lv * 1000

## Check if accumulated XP triggers a level-up. Returns true if the player leveled up.
## PHB: each level grants 1 stat point + 3 skill points to every active character.
func check_level_up() -> bool:
	var leveled: bool = false
	while player_xp >= player_xp_required:
		player_xp      -= player_xp_required
		player_level   += 1
		player_xp_required = _xp_for_level(player_level)
		player_rank     = _rank_for_level(player_level)
		leveled          = true
		# Grant level-up points to all active characters (PHB: 1 stat + 3 skill pts)
		var e = RimvaleAPI.engine
		for handle in active_team:
			e.level_up_character(int(handle))
	return leveled

## Map player level → rank title (mirrors Rimvale Mobile)
func _rank_for_level(lv: int) -> String:
	if lv >= 20: return "Grandmaster"
	if lv >= 16: return "Master"
	if lv >= 12: return "Elite"
	if lv >= 9:  return "Veteran"
	if lv >= 7:  return "Operative"
	if lv >= 5:  return "Specialist"
	if lv >= 3:  return "Agent"
	return "Recruit"

# ── Quest helpers ─────────────────────────────────────────────────────────────

## Set a quest as the active dungeon deployment.
func deploy_quest_to_dungeon(quest: Dictionary) -> void:
	quest_state["active_dungeon_quest"] = quest.duplicate()

## Clear the active quest (called after victory or returning without quest).
func clear_active_dungeon_quest() -> void:
	quest_state["active_dungeon_quest"] = {}

## Complete the active dungeon quest: award rewards, record completion, save.
## Returns the quest dict that was completed (empty if none was active).
func complete_dungeon_quest(bonus_gold: int, bonus_xp: int) -> Dictionary:
	var q: Dictionary = quest_state["active_dungeon_quest"]
	if q.is_empty():
		# No linked quest — still award the dungeon-drop rewards
		earn_gold(bonus_gold)
		player_xp += bonus_xp
		check_level_up()
		save_game()
		return {}
	# Award quest rewards on top of dungeon drops
	var total_gold: int = bonus_gold + int(q.get("reward_gold", 0))
	var total_xp:   int = bonus_xp   + int(q.get("reward_xp",   0))
	earn_gold(total_gold)
	player_xp += total_xp
	check_level_up()
	var qid: String = str(q.get("id", q.get("title", "")))
	if qid != "" and qid not in quest_state["completed_quest_ids"]:
		quest_state["completed_quest_ids"].append(qid)
	var completed: Dictionary = q.duplicate()
	quest_state["active_dungeon_quest"] = {}
	save_game()
	return completed

# ── Daily login bonus ─────────────────────────────────────────────────────────

## Call once at startup. Returns true if the daily bonus was awarded today.
func check_daily_login() -> bool:
	var today: String = Time.get_date_string_from_system()
	if last_login_date == today:
		return false
	last_login_date = today
	tokens += 10
	save_game()
	return true

# ── Rest helpers ──────────────────────────────────────────────────────────────

func can_short_rest() -> bool:
	return short_rests_used < MAX_SHORT_RESTS

func do_short_rest() -> bool:
	if not can_short_rest():
		return false
	short_rests_used += 1
	var e = RimvaleAPI.engine
	var active = get_active_handles()
	if active.size() > 0:
		e.rest_party(active)
	return true

func do_long_rest() -> void:
	short_rests_used = 0
	var e = RimvaleAPI.engine
	for h in collection:
		e.long_rest(h)

# ── Wipe ─────────────────────────────────────────────────────────────────────

func wipe_all() -> void:
	var e = RimvaleAPI.engine
	for h in collection:
		e.destroy_character(h)
	collection.clear()
	active_team = [-1, -1, -1, -1, -1]
	busy_handles.clear()
	crafting_tasks.clear()
	forage_tasks.clear()
	ritual_tasks.clear()
	active_rituals.clear()
	story_completed_missions.clear()
	story_earned_badges.clear()
	current_region = "plains"
	current_subregion = ""
	visited_regions.clear()
	visited_subregions.clear()
	cleared_acf_locations.clear()
	base_tier = 1
	base_supplies = 50
	base_defense = 10
	base_morale = 10
	base_acreage = 2
	base_facilities = [0]
	recruited_allies = []
	quest_state = {"active_dungeon_quest": {}, "completed_quest_ids": []}
	gold = 500
	tokens = 5
	remnant_fragments = 0
	player_level = 1
	player_xp = 0
	player_xp_required = 1000
	player_rank = "Recruit"
	short_rests_used = 0
	stash.clear()
	selected_hero_handle = -1
	last_login_date = ""
	# Delete save so wipe is permanent
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	call_deferred("_ensure_starter_units")

# ── Save / Load ───────────────────────────────────────────────────────────────

## Serialise the full game state to disk. Returns true on success.
func save_game() -> bool:
	var e = RimvaleAPI.engine

	# Serialise every character in the collection
	var chars_data: Array = []
	for h in collection:
		var cd = e.get_char_dict(h)
		if cd == null:
			continue
		var entry: Dictionary = {
			"name":          e.get_character_name(h),
			"lineage":       e.get_character_lineage_name(h),
			"age":           int(cd.get("age",       25)),
			"level":         int(cd.get("level",      1)),
			"xp":            int(cd.get("xp",         0)),
			"xp_req":        int(cd.get("xp_req",   100)),
			"hp":            int(cd.get("hp",        20)),
			"max_hp":        int(cd.get("max_hp",    20)),
			"ac":            int(cd.get("ac",        12)),
			"speed":         int(cd.get("speed",      6)),
			"ap":            int(cd.get("ap",        10)),
			"max_ap":        int(cd.get("max_ap",    10)),
			"sp":            int(cd.get("sp",         6)),
			"max_sp":        int(cd.get("max_sp",     6)),
			"weapon":        str(cd.get("weapon",  "None")),
			"armor":         str(cd.get("armor",   "None")),
			"shield":        str(cd.get("shield",  "None")),
			"light":         str(cd.get("light",   "None")),
			"alignment":     str(cd.get("alignment", "Unity")),
			"domain":        str(cd.get("domain",  "Physical")),
			"societal_role": str(cd.get("societal_role", "")),
			"feat_pts":      int(cd.get("feat_pts",   0)),
			"skill_pts":     int(cd.get("skill_pts",  0)),
			"stat_pts":      int(cd.get("stat_pts",   0)),
			"stats":         Array(cd.get("stats",    [1,1,1,1,1])),
			"skills":        Array(cd.get("skills",   [])),
			"feats":         cd.get("feats",          {}).duplicate(),
			"spells":        Array(cd.get("spells",   [])),
			"injuries":      Array(cd.get("injuries", [])),
			"items":         Array(cd.get("items",    [])),
			"favored_skills":Array(cd.get("favored_skills", [])),
		}
		chars_data.append(entry)

	# Map active_team handles → collection indices (stable across sessions)
	var team_indices: Array = []
	for h in active_team:
		team_indices.append(collection.find(h))   # -1 if empty/not found

	# Serialise crafting tasks (dicts, safe for JSON)
	var craft_data: Array = []
	for t in crafting_tasks:
		craft_data.append({
			"character_handle": int(t.get("character_handle", -1)),
			"character_name":   str(t.get("character_name", "")),
			"item_type":        str(t.get("item_type", "")),
			"end_time":         float(t.get("end_time", 0.0)),
		})

	# Serialise forage tasks
	var forage_data: Array = []
	for t in forage_tasks:
		forage_data.append({
			"character_handle": int(t.get("character_handle", -1)),
			"character_name":   str(t.get("character_name", "")),
			"forage_type":      str(t.get("forage_type", "")),
			"end_time":         float(t.get("end_time", 0.0)),
			"gold_reward":      int(t.get("gold_reward", 0)),
		})

	# Serialise ritual tasks + active rituals
	var ritual_task_data: Array = []
	for t in ritual_tasks:
		ritual_task_data.append({
			"id":             str(t.get("id", "")),
			"spell_name":     str(t.get("spell_name", "")),
			"spell_desc":     str(t.get("spell_desc", "")),
			"caster_handle":  int(t.get("caster_handle", -1)),
			"caster_name":    str(t.get("caster_name", "")),
			"sp_committed":   int(t.get("sp_committed", 1)),
		})
	var active_ritual_data: Array = []
	for r in active_rituals:
		active_ritual_data.append({
			"id":            str(r.get("id", "")),
			"spell_name":    str(r.get("spell_name", "")),
			"spell_desc":    str(r.get("spell_desc", "")),
			"caster_handle": int(r.get("caster_handle", -1)),
			"caster_name":   str(r.get("caster_name", "")),
			"sp_committed":  int(r.get("sp_committed", 1)),
		})

	var data: Dictionary = {
		"version":                   4,
		"player_name":               player_name,
		"player_level":              player_level,
		"player_xp":                 player_xp,
		"player_xp_required":        player_xp_required,
		"player_rank":               player_rank,
		"gold":                      gold,
		"tokens":                    tokens,
		"remnant_fragments":         remnant_fragments,
		"short_rests_used":          short_rests_used,
		"director_message":          director_message,
		"story_completed_missions":  story_completed_missions,
		"story_earned_badges":       story_earned_badges,
		"current_region":            current_region,
		"current_subregion":         current_subregion,
		"visited_regions":           visited_regions,
		"visited_subregions":        visited_subregions,
		"cleared_acf_locations":     cleared_acf_locations,
		"base_tier":                 base_tier,
		"base_supplies":             base_supplies,
		"base_defense":              base_defense,
		"base_morale":               base_morale,
		"base_acreage":              base_acreage,
		"base_facilities":           base_facilities,
		"recruited_allies":          recruited_allies,
		"stash":                     stash,
		"team_indices":              team_indices,
		"characters":                chars_data,
		"crafting_tasks":            craft_data,
		"forage_tasks":              forage_data,
		"ritual_tasks":              ritual_task_data,
		"active_rituals":            active_ritual_data,
		"completed_quest_ids":       quest_state.get("completed_quest_ids", []),
		"last_login_date":           last_login_date,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("GameState: failed to open save file for writing")
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

## Load game state from disk. Returns true on success.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("GameState: save file JSON parse error")
		return false

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return false

	var e = RimvaleAPI.engine

	# Destroy any existing engine characters
	for h in collection:
		e.destroy_character(h)
	collection.clear()
	active_team = [-1, -1, -1, -1, -1]
	busy_handles.clear()
	crafting_tasks.clear()
	forage_tasks.clear()
	ritual_tasks.clear()
	active_rituals.clear()

	# Restore economy + player data
	player_name         = str(data.get("player_name",    "Agent"))
	player_level        = int(data.get("player_level",   1))
	player_xp           = int(data.get("player_xp",      0))
	player_xp_required  = int(data.get("player_xp_required", 1000))
	player_rank         = str(data.get("player_rank",    "Recruit"))
	gold                = int(data.get("gold",            500))
	tokens              = int(data.get("tokens",          5))
	remnant_fragments   = int(data.get("remnant_fragments", 0))
	short_rests_used    = int(data.get("short_rests_used",  0))
	director_message    = str(data.get("director_message",  "Welcome back, Agent."))
	story_completed_missions = Array(data.get("story_completed_missions", []))
	story_earned_badges      = Array(data.get("story_earned_badges",      []))
	current_region           = str(data.get("current_region", "plains"))
	current_subregion        = str(data.get("current_subregion", ""))
	visited_regions          = Array(data.get("visited_regions", []))
	visited_subregions       = Array(data.get("visited_subregions", []))
	cleared_acf_locations    = Array(data.get("cleared_acf_locations", []))
	base_tier                = int(data.get("base_tier", 1))
	base_supplies            = int(data.get("base_supplies", 50))
	base_defense             = int(data.get("base_defense", 10))
	base_morale              = int(data.get("base_morale", 10))
	base_acreage             = int(data.get("base_acreage", 2))
	base_facilities          = Array(data.get("base_facilities", [0]))
	recruited_allies         = Array(data.get("recruited_allies", []))
	stash                    = Array(data.get("stash",                    []))
	last_login_date          = str(data.get("last_login_date", ""))

	# Restore quest state
	quest_state = {
		"active_dungeon_quest": {},
		"completed_quest_ids":  Array(data.get("completed_quest_ids", [])),
	}

	# Restore crafting tasks
	crafting_tasks.clear()
	for t in Array(data.get("crafting_tasks", [])):
		crafting_tasks.append({
			"character_handle": int(t.get("character_handle", -1)),
			"character_name":   str(t.get("character_name", "")),
			"item_type":        str(t.get("item_type", "")),
			"end_time":         float(t.get("end_time", 0.0)),
		})
		set_busy(int(t.get("character_handle", -1)), true)

	# Restore forage tasks
	forage_tasks.clear()
	for t in Array(data.get("forage_tasks", [])):
		forage_tasks.append({
			"character_handle": int(t.get("character_handle", -1)),
			"character_name":   str(t.get("character_name", "")),
			"forage_type":      str(t.get("forage_type", "")),
			"end_time":         float(t.get("end_time", 0.0)),
			"gold_reward":      int(t.get("gold_reward", 0)),
		})
		set_busy(int(t.get("character_handle", -1)), true)

	# Restore ritual tasks + active rituals
	ritual_tasks.clear()
	for t in Array(data.get("ritual_tasks", [])):
		ritual_tasks.append({
			"id":            str(t.get("id", "")),
			"spell_name":    str(t.get("spell_name", "")),
			"spell_desc":    str(t.get("spell_desc", "")),
			"caster_handle": int(t.get("caster_handle", -1)),
			"caster_name":   str(t.get("caster_name", "")),
			"sp_committed":  int(t.get("sp_committed", 1)),
		})
	active_rituals.clear()
	for r in Array(data.get("active_rituals", [])):
		active_rituals.append({
			"id":            str(r.get("id", "")),
			"spell_name":    str(r.get("spell_name", "")),
			"spell_desc":    str(r.get("spell_desc", "")),
			"caster_handle": int(r.get("caster_handle", -1)),
			"caster_name":   str(r.get("caster_name", "")),
			"sp_committed":  int(r.get("sp_committed", 1)),
		})

	# Recreate characters in the engine
	var chars_data: Array = Array(data.get("characters", []))
	var handle_list: Array = []
	for cd in chars_data:
		var cname:   String = str(cd.get("name",    "Unknown"))
		var lineage: String = str(cd.get("lineage", "Human"))
		var age:     int    = int(cd.get("age",     25))
		var h: int = e.create_character(cname, lineage, age)
		var char_dict = e.get_char_dict(h)
		if char_dict != null:
			char_dict["level"]         = int(cd.get("level",      1))
			char_dict["xp"]            = int(cd.get("xp",         0))
			char_dict["xp_req"]        = int(cd.get("xp_req",   100))
			char_dict["hp"]            = int(cd.get("hp",        20))
			char_dict["max_hp"]        = int(cd.get("max_hp",    20))
			char_dict["ac"]            = int(cd.get("ac",        12))
			char_dict["speed"]         = int(cd.get("speed",      6))
			char_dict["ap"]            = int(cd.get("ap",        10))
			char_dict["max_ap"]        = int(cd.get("max_ap",    10))
			char_dict["sp"]            = int(cd.get("sp",         6))
			char_dict["max_sp"]        = int(cd.get("max_sp",     6))
			char_dict["alignment"]     = str(cd.get("alignment", "Unity"))
			char_dict["domain"]        = str(cd.get("domain",    "Physical"))
			char_dict["societal_role"] = str(cd.get("societal_role", ""))
			char_dict["feat_pts"]      = int(cd.get("feat_pts",   0))
			char_dict["skill_pts"]     = int(cd.get("skill_pts",  0))
			char_dict["stat_pts"]      = int(cd.get("stat_pts",   0))
			var saved_stats: Array = Array(cd.get("stats", []))
			if saved_stats.size() == 5:
				char_dict["stats"] = saved_stats
			var saved_skills: Array = Array(cd.get("skills", []))
			if saved_skills.size() == 14:
				char_dict["skills"] = saved_skills
			var saved_feats = cd.get("feats", {})
			if typeof(saved_feats) == TYPE_DICTIONARY:
				char_dict["feats"] = saved_feats.duplicate()
			var saved_spells: Array = Array(cd.get("spells", []))
			char_dict["spells"] = saved_spells
			var saved_injuries: Array = Array(cd.get("injuries", []))
			char_dict["injuries"] = saved_injuries
			var saved_items: Array = Array(cd.get("items", []))
			char_dict["items"] = saved_items
			var saved_fav: Array = Array(cd.get("favored_skills", []))
			char_dict["favored_skills"] = saved_fav
		# Restore equipped items via equip_item so weapon/armor AC calculations apply
		var weapon: String = str(cd.get("weapon", ""))
		var armor:  String = str(cd.get("armor",  ""))
		var shield: String = str(cd.get("shield", ""))
		var light_:  String = str(cd.get("light", ""))
		if weapon != "" and weapon != "null" and weapon != "None": e.equip_item(h, weapon)
		if armor  != "" and armor  != "null" and armor  != "None": e.equip_item(h, armor)
		if shield != "" and shield != "null" and shield != "None": e.equip_item(h, shield)
		if light_ != "" and light_ != "null" and light_ != "None": e.equip_item(h, light_)
		add_to_collection(h)
		handle_list.append(h)

	# Restore team slots from saved collection indices
	var team_indices: Array = Array(data.get("team_indices", []))
	for i in range(mini(ACTIVE_TEAM_SIZE, team_indices.size())):
		var ci: int = int(team_indices[i])
		if ci >= 0 and ci < handle_list.size():
			active_team[i] = handle_list[ci]

	return true
