## militia_system.gd
## Canonical Militia Formation rules + MP-budget point system, matching the
## Militia Formation spec. Militias are semi-organized cohorts built on a
## Militia Point (MP) economy: 100 gold = 5 MP baseline, with modifiers from
## faction support, regional stability, and player investment.
##
## Single source of truth for:
##   - 15 Militia TYPES (role bonuses)  — Step 1
##   - Stat allocation math (3 pts/MP, max 8 MP, max 24 pts, >5 costs ×2) — Step 2
##   - 3 sizes + custom expansion — Step 3
##   - 4 Equipment TIERS — Step 4
##   - 17 Militia TRAITS (pick 1; +5 MP for each extra, tagged dangerous/restricted) — Step 5
##   - 4 Commander ROLES (1 MP each, stackable on one unit; +10 HP +2 AC) — Step 6
##   - Morale formula — Step 7
##   - Vehicles, Special Training, Elite Status, Unique Assets — Step 8
class_name MilitiaSystem
extends RefCounted

# ══════════════════════════════════════════════════════════════════════════════
# MP BUDGET
# ══════════════════════════════════════════════════════════════════════════════
const GOLD_PER_MP_WITHOUT_BASE: int = 100  # 100 g → 5 MP (→ 20 g/MP)
const MP_PER_100_GOLD: int = 5
const FACTION_SUPPORT_BONUS_MP: int = 5
const REGIONAL_INSTABILITY_PENALTY_MP: int = -5
const PLAYER_GOLD_PER_MP: int = 50   # +1 MP per 50 g
const PLAYER_SP_PER_MP: int = 1      # +1 MP per 1 SP donated

## Compute the MP a militia will have given its inputs.
## For combat encounters use `encounter_mp(level)` instead.
static func compute_mp(starting_gold: int,
		built_from_base: bool = false,
		faction_backed: bool = false,
		region_in_chaos: bool = false,
		player_gold: int = 0,
		player_sp: int = 0) -> int:
	var mp: int = 0
	if not built_from_base:
		# 100 g per 5 MP — the 100g cost is bypassed by having a base.
		mp += (starting_gold / GOLD_PER_MP_WITHOUT_BASE) * MP_PER_100_GOLD
	else:
		# Base-built militia: no gold cost, MP allocated directly by the base tier
		# (caller should pass starting_gold as the already-MP-converted number / or 0).
		mp += starting_gold
	if faction_backed:    mp += FACTION_SUPPORT_BONUS_MP
	if region_in_chaos:   mp += REGIONAL_INSTABILITY_PENALTY_MP
	mp += player_gold / PLAYER_GOLD_PER_MP
	mp += player_sp / PLAYER_SP_PER_MP
	return maxi(0, mp)

## Encounter-scaled MP for a party-vs-militia combat challenge.
## Spec: 5 MP per 2 levels of encounter (L6 encounter → 15 MP).
static func encounter_mp(encounter_level: int) -> int:
	return (encounter_level / 2) * 5

# ══════════════════════════════════════════════════════════════════════════════
# STAT ALLOCATION (Step 2)
# 3 points per MP. Max 8 MP spent on stats → 24 points total.
# All stats start at 0. Raising a stat above 5 costs 2 points per point.
# ══════════════════════════════════════════════════════════════════════════════
const STAT_POINTS_PER_MP: int = 3
const MAX_STAT_MP: int = 8
const MAX_STAT_POINTS: int = 24   # = STAT_POINTS_PER_MP × MAX_STAT_MP
const STAT_SOFT_CAP: int = 5      # above this, 2 points per point

## Cost (in stat-pool points) to raise one stat from 0 to `target`.
static func cost_for_stat(target: int) -> int:
	var under: int = mini(target, STAT_SOFT_CAP)
	var over: int  = maxi(0, target - STAT_SOFT_CAP)
	return under + (over * 2)

## Feats cost: 3 feats per 1 MP.
const FEATS_PER_MP: int = 3

# ══════════════════════════════════════════════════════════════════════════════
# SIZE & COMPOSITION (Step 3)
# ══════════════════════════════════════════════════════════════════════════════
const SIZES: Array = [
	{"id": "small_squad",  "name": "Small Squad",  "members":  5, "mp_cost": 0, "desc": "Agile, stealthy, high-HP units."},
	{"id": "medium_unit",  "name": "Medium Unit",  "members": 10, "mp_cost": 3, "desc": "Balanced, moderate-HP units."},
	{"id": "large_force",  "name": "Large Force",  "members": 20, "mp_cost": 6, "desc": "Lower HP per head, slower, harder to coordinate."},
]
## Extra members beyond the chosen size tier: 1 MP each.
const MP_PER_EXTRA_MEMBER: int = 1

# ══════════════════════════════════════════════════════════════════════════════
# MILITIA TYPES (Step 1 — 15 roles)
# ══════════════════════════════════════════════════════════════════════════════
const TYPES: Array = [
	{"id":"guard",              "name":"Guard Militia",              "desc":"Defensive, focused on protecting settlements. +3 to AC.",
		"modifiers":{"ac": 3}},
	{"id":"raid",               "name":"Raid Militia",               "desc":"Offensive skirmishers. +2 to attack and damage.",
		"modifiers":{"atk": 2, "dmg": 2}},
	{"id":"recon",              "name":"Recon Militia",              "desc":"Stealthy scouts. +2 to tracking and stealth checks.",
		"modifiers":{"tracking": 2, "stealth": 2}},
	{"id":"sacred",             "name":"Sacred Militia",             "desc":"Temple / relic guards. Healing costs -2 SP (min 1).",
		"modifiers":{"heal_sp_discount": 2}},
	{"id":"arcane",              "name":"Arcane Militia",             "desc":"Magic-focused. Can cast rituals.",
		"modifiers":{"can_cast_rituals": true}},
	{"id":"hunter",             "name":"Hunter Militia",             "desc":"Trappers and beast-slayers. +2 attack vs. Large+ creatures, +5 to tracking creatures.",
		"modifiers":{"atk_vs_large": 2, "tracking_creatures": 5}},
	{"id":"merchant_guard",     "name":"Merchant Guard Militia",     "desc":"Protect caravans and trade routes. Ranged ambushes against them have disadvantage. +3 to recognize threats.",
		"modifiers":{"ambushers_disadv": true, "recognize_threats": 3}},
	{"id":"engineer",           "name":"Engineer Militia",           "desc":"Builders and sappers. Deploy simple barricades (half cover) once per combat.",
		"modifiers":{"barricade_per_combat": 1}},
	{"id":"nomad",              "name":"Nomad Militia",              "desc":"Mounted or highly mobile warriors. +10 ft movement; ignore difficult terrain.",
		"modifiers":{"move_ft": 10, "ignore_difficult_terrain": true}},
	{"id":"seafaring",          "name":"Seafaring Militia",          "desc":"Dockside / naval fighters. Advantage on water, boarding, or naval combat.",
		"modifiers":{"naval_advantage": true}},
	{"id":"crusader",           "name":"Crusader Militia",           "desc":"Zealots sworn to a cause. When bloodied, +2 attack and damage until routed or slain.",
		"modifiers":{"bloodied_atk": 2, "bloodied_dmg": 2}},
	{"id":"shadow",             "name":"Shadow Militia",             "desc":"Thieves, assassins, underworld fighters. Advantage on ambushes; crits on 18-20.",
		"modifiers":{"ambush_advantage": true, "crit_range": 18}},
	{"id":"arcane_reclaimer",   "name":"Arcane Reclaimer Militia",   "desc":"Anti-magic specialists. +2 to Arcane checks; once per combat dispel (DC 15).",
		"modifiers":{"arcane_check": 2, "dispel_per_combat": 1, "dispel_dc": 15}},
	{"id":"storm",              "name":"Storm Militia",              "desc":"Drawn from wild-weather regions. Resistance to lightning and thunder.",
		"modifiers":{"resist": ["lightning", "thunder"]}},
	{"id":"iron_legionnaire",   "name":"Iron Legionnaire Militia",   "desc":"Professional heavy infantry. +1 AC and +1d4 damage in formation.",
		"modifiers":{"formation_ac": 1, "formation_dmg_dice": "1d4"}},
]

# ══════════════════════════════════════════════════════════════════════════════
# EQUIPMENT TIERS (Step 4)
# ══════════════════════════════════════════════════════════════════════════════
const EQUIPMENT_TIERS: Array = [
	{"tier": 1, "name":"Improvised",  "ac": 14, "mp_cost": 0,
		"melee_dice":"1d6", "ranged_dice":"1d6", "dmg_bonus": 0,
		"desc":"Clubs, slings, leather armor."},
	{"tier": 2, "name":"Standard",    "ac": 16, "mp_cost": 2,
		"melee_dice":"1d8", "ranged_dice":"1d8", "dmg_bonus": 2,
		"desc":"Swords, bows, chainmail."},
	{"tier": 3, "name":"Elite",       "ac": 18, "mp_cost": 4,
		"melee_dice":"1d10", "ranged_dice":"1d10", "dmg_bonus": 5,
		"desc":"Polearms, crossbows, plate armor."},
	{"tier": 4, "name":"Advanced Tech", "ac": 20, "mp_cost": 5,
		"melee_dice":"1d12", "ranged_dice":"1d12", "dmg_bonus": 8,
		"desc":"Arcane batons, arcane rifles, arcane shields — restricted to Metropolitan and Land of Tomorrow.",
		"restricted": true, "requires_trait": "advanced_tech"},
]

# ══════════════════════════════════════════════════════════════════════════════
# MILITIA TRAITS (Step 5 — 17 options; first is free, each extra costs +5 MP)
# ══════════════════════════════════════════════════════════════════════════════
const MP_PER_EXTRA_TRAIT: int = 5
const TRAITS: Array = [
	{"id":"shield_wall",        "name":"Shield Wall",        "desc":"+2 AC when adjacent to allies."},
	{"id":"volley_fire",        "name":"Volley Fire",        "desc":"Ranged attacks hit multiple targets in a line."},
	{"id":"divine_zeal",        "name":"Divine Zeal",        "desc":"+1d4 radiant damage vs. undead or cursed."},
	{"id":"arcane_disruption",  "name":"Arcane Disruption",  "desc":"Can suppress magic in a 10 ft radius for 1 round."},
	{"id":"ambush_tactics",     "name":"Ambush Tactics",     "desc":"Advantage on initiative and first attack."},
	{"id":"battle_chant",       "name":"Battle Chant",       "desc":"Allies within 30 ft gain +1 to morale-based saves."},
	{"id":"siege_breakers",     "name":"Siege Breakers",     "desc":"+1d8 damage vs. fortifications, walls, constructs."},
	{"id":"skirmishers",        "name":"Skirmishers",        "desc":"+10 ft movement; can disengage as a free action once per round."},
	{"id":"relentless_pursuit", "name":"Relentless Pursuit", "desc":"Fleeing enemies provoke opportunity attacks even when disengaging."},
	{"id":"beastmasters",       "name":"Beastmasters",       "desc":"Unit includes trained animals (hounds, dire wolves, giant insects). +1d6 damage on melee swarms."},
	{"id":"iron_discipline",    "name":"Iron Discipline",    "desc":"Immune to fear. Morale checks with advantage."},
	{"id":"guerilla_fighters",  "name":"Guerilla Fighters",  "desc":"No disadvantage in difficult terrain; hide in natural cover as a bonus action."},
	{"id":"alchemical_support", "name":"Alchemical Support", "desc":"Firebombs / toxins. Once per battle: 1d6 fire or poison in a 10 ft radius."},
	{"id":"banner_of_unity",    "name":"Banner of Unity",    "desc":"While standard-bearer lives, allies within 60 ft reroll 1 failed save per combat."},
	{"id":"blood_oath",         "name":"Blood Oath",         "desc":"Failing morale does not cause fleeing. No dispersing. No surrender. Battle to the death."},
	{"id":"void_touched_frenzy","name":"Void-Touched Frenzy","desc":"+5 MP. +1d6 damage per attack, but morale auto-breaks at 50% losses — they attack FRIEND AND FOE when it breaks.",
		"mp_extra_cost": 5, "dangerous": true},
	{"id":"advanced_tech",      "name":"Advanced Tech",      "desc":"+5 MP. Arcane weapons + vehicles. Restricted to Metropolitan and the Land of Tomorrow; outside those regions triples militia cost and requires alliance.",
		"mp_extra_cost": 5, "restricted": true},
]

# ══════════════════════════════════════════════════════════════════════════════
# COMMANDER ROLES (Step 6 — 1 MP each; stack on one unit for +1 MP per extra)
# A commander unit gains +10 HP and +2 AC.
# ══════════════════════════════════════════════════════════════════════════════
const COMMANDER_HP_BONUS: int = 10
const COMMANDER_AC_BONUS: int = 2
const MP_PER_COMMANDER_ROLE: int = 1
const COMMANDER_ROLES: Array = [
	{"id":"veteran",   "name":"Veteran",   "desc":"+1 to all attack rolls."},
	{"id":"tactician", "name":"Tactician", "desc":"+1 to all skill checks."},
	{"id":"priest",    "name":"Priest",    "desc":"+1d4 healing per round to one ally."},
	{"id":"mage",      "name":"Mage",      "desc":"Casting spells costs 3 SP less (min 1)."},
]

# ══════════════════════════════════════════════════════════════════════════════
# MORALE (Step 7)
# ══════════════════════════════════════════════════════════════════════════════
## Compute militia morale from its components.
## Base: equipment-tier bonus + VIT + recent victories − casualties
##       − 2 (below 2/3 HP), − 5 (below 1/3 HP), + 1 per MP invested in morale.
static func compute_morale(equipment_tier: int, vit: int, victories: int,
		casualties: int, current_hp: int, max_hp: int,
		mp_morale_investment: int = 0) -> int:
	var morale: int = 0
	morale += equipment_tier
	morale += vit
	morale += victories
	morale -= casualties
	if max_hp > 0:
		var hp_frac: float = float(current_hp) / float(max_hp)
		if hp_frac < (1.0 / 3.0):
			morale -= 5
		elif hp_frac < (2.0 / 3.0):
			morale -= 2
	morale += mp_morale_investment
	return maxi(0, morale)

## Damage-threshold check: threshold = morale score.
## DC = 10 + (damage beyond the threshold) vs 1d20 + morale_score.
## On a fail, morale is reduced by 1.
static func morale_damage_dc(damage_above_threshold: int) -> int:
	return 10 + damage_above_threshold

# ══════════════════════════════════════════════════════════════════════════════
# HP / AP / SP FORMULAS (Step 2)
# ══════════════════════════════════════════════════════════════════════════════
static func compute_hp(level: int, vit: int) -> int:
	return 10 * level + vit

static func compute_ap(str_score: int) -> int:
	return 10 + str_score

static func compute_sp(level: int, div: int) -> int:
	return 3 + level + div

# ══════════════════════════════════════════════════════════════════════════════
# OPTIONAL UPGRADES (Step 8)
# ══════════════════════════════════════════════════════════════════════════════
const VEHICLE_MP_COST: int = 5
const SIEGE_VEHICLE_MP_COST: int = 10
const SPECIAL_TRAINING_MP_COST: int = 3
const ELITE_STATUS_MP_COST: int = 5
const ELITE_HP_BONUS: int = 10
const ELITE_AC_BONUS: int = 1
const ELITE_ATK_BONUS: int = 1
const ELITE_DMG_BONUS: int = 1

const VEHICLES: Array = [
	{"id":"cavalry",  "name":"Cavalry",           "mp": 5,  "desc":"Movement speed doubled; charge attacks +1d6 damage."},
	{"id":"chariots", "name":"Chariots / Wagons", "mp": 5,  "desc":"Half cover from the vehicle; +1d4 ranged damage from mounted platforms."},
	{"id":"ships",    "name":"Ships / Barges",    "mp": 5,  "desc":"Advantage on waterborne combat, boarding, river/coastal movement."},
	{"id":"siege",    "name":"Siege Vehicles",    "mp": 10, "desc":"Catapults, ballistae, arcane vehicles (Metro/Tomorrow). Siege-scale damage to fortifications/monsters.",
		"restricted": true},
]

const SPECIAL_TRAININGS: Array = [
	{"id":"siege",        "name":"Siege Training",        "desc":"+1d8 damage to fortifications and constructs."},
	{"id":"naval",        "name":"Naval Training",        "desc":"No penalties in water/ship combat; advantage on boarding."},
	{"id":"arcane",       "name":"Arcane Training",       "desc":"Advantage on saves vs. magical effects; assist allied spellcasters (-1 SP min 1)."},
	{"id":"elemental",    "name":"Elemental Conditioning","desc":"Resistance to a specific damage type (fire, cold, lightning, etc.)."},
	{"id":"monster_hunt", "name":"Monster Hunting",       "desc":"+2 attack, +1d6 damage vs. beasts/monstrosities."},
	{"id":"urban",        "name":"Urban Warfare",         "desc":"Advantage on stealth/perception in cities; ignore half cover from barricades."},
]

const UNIQUE_ASSETS: Array = [
	{"id":"divine_blessing",   "name":"Divine Blessing",   "mp": 5,  "desc":"Once per combat, ignore all damage from one attack or spell."},
	{"id":"faction_prototype", "name":"Faction Prototype", "mp": 10, "desc":"An experimental weapon, vehicle, or arcane engine unique to a faction."},
]

# ══════════════════════════════════════════════════════════════════════════════
# MP COST COMPUTATION
# ══════════════════════════════════════════════════════════════════════════════
## Compute total MP cost of a militia build. Useful for validating a build
## against the MP budget before committing to it.
static func compute_build_cost(
		stats_mp_spent: int,            # how many MP on stats (up to MAX_STAT_MP)
		size_idx: int,                  # index into SIZES
		extra_members: int,             # extra members over the size tier
		equipment_tier_idx: int,        # index into EQUIPMENT_TIERS (1-indexed via `tier`)
		trait_count: int,               # total trait slots (first free, extras 5 MP each)
		commander_roles_count: int,     # number of commander roles
		vehicles: Array,                # ["cavalry", "chariots", …]
		special_trainings_count: int,   # each 3 MP
		elite_units: int,               # each 5 MP
		unique_assets: Array,           # ["divine_blessing", …]
		feats_count: int,               # 3 per 1 MP
		morale_investment_mp: int = 0
) -> int:
	var cost: int = 0
	cost += mini(stats_mp_spent, MAX_STAT_MP)
	if size_idx >= 0 and size_idx < SIZES.size():
		cost += int(SIZES[size_idx]["mp_cost"])
	cost += maxi(0, extra_members) * MP_PER_EXTRA_MEMBER
	if equipment_tier_idx >= 0 and equipment_tier_idx < EQUIPMENT_TIERS.size():
		cost += int(EQUIPMENT_TIERS[equipment_tier_idx]["mp_cost"])
	# First trait is free; extras cost 5 MP each + per-trait mp_extra_cost tags.
	if trait_count > 1:
		cost += (trait_count - 1) * MP_PER_EXTRA_TRAIT
	cost += commander_roles_count * MP_PER_COMMANDER_ROLE
	for v_id in vehicles:
		for v in VEHICLES:
			if str(v["id"]) == str(v_id):
				cost += int(v["mp"])
				break
	cost += special_trainings_count * SPECIAL_TRAINING_MP_COST
	cost += elite_units * ELITE_STATUS_MP_COST
	for a_id in unique_assets:
		for a in UNIQUE_ASSETS:
			if str(a["id"]) == str(a_id):
				cost += int(a["mp"])
				break
	# Feats: 3 per 1 MP. Round up so 4 feats = 2 MP.
	if feats_count > 0:
		cost += int(ceil(float(feats_count) / float(FEATS_PER_MP)))
	cost += morale_investment_mp
	return cost

# ══════════════════════════════════════════════════════════════════════════════
# EXAMPLE MILITIAS (from spec)
# ══════════════════════════════════════════════════════════════════════════════
const EXAMPLES: Array = [
	{
		"id":           "ironroot_guard",
		"name":         "Ironroot Guard Militia",
		"background":   "A defensive force of dwarves and humans, dedicated to protecting their mountain settlement.",
		"mp_budget":    25,   # 20 base + 5 faction
		"type":         "guard",
		"stats":        {"str": 5, "spd": 5, "int": 5, "vit": 5, "div": 2},  # 22 pts, 2 left over
		"level":        1,
		"size_idx":     1,    # Medium Unit (10 members, 3 MP)
		"equipment":    2,    # Tier 2 Standard (2 MP)
		"traits":       ["shield_wall"],  # first free
		"commanders":   ["veteran"],
		"notes":        "10 defenders, AC 19 (16 base + 3 Guard), 60 HP shared, 10 AP, 15 SP, swords/bows, +1 atk, +2 dmg, Shield Wall, Morale 8.",
	},
	{
		"id":           "emberveil_recon",
		"name":         "Emberveil Recon Militia",
		"background":   "A swift, stealthy band of elves and halflings, specializing in scouting and ambushes.",
		"mp_budget":    17,   # 20 base + 2 player - 5 instability
		"type":         "recon",
		"stats":        {"str": 3, "spd": 6, "int": 5, "vit": 5, "div": 2},  # 22 pts with over-5 cost on SPD
		"level":        1,
		"size_idx":     0,    # Small Squad (5 members, 0 MP)
		"equipment":    1,    # Tier 1 Improvised (0 MP)
		"traits":       ["ambush_tactics"],
		"commanders":   ["tactician"],
		"notes":        "5 scouts, AC 14, 30 HP shared, 6 AP, 5 SP, clubs/slings, Ambush Tactics, Morale 4.",
	},
]

# ══════════════════════════════════════════════════════════════════════════════
# QUERY HELPERS
# ══════════════════════════════════════════════════════════════════════════════
static func get_type(idx: int) -> Dictionary:
	if idx < 0 or idx >= TYPES.size(): return {}
	return TYPES[idx]

static func get_type_by_id(id: String) -> Dictionary:
	for t in TYPES:
		if str(t["id"]) == id: return t
	return {}

static func get_trait(idx: int) -> Dictionary:
	if idx < 0 or idx >= TRAITS.size(): return {}
	return TRAITS[idx]

static func get_equipment(idx: int) -> Dictionary:
	if idx < 0 or idx >= EQUIPMENT_TIERS.size(): return {}
	return EQUIPMENT_TIERS[idx]

static func get_commander(idx: int) -> Dictionary:
	if idx < 0 or idx >= COMMANDER_ROLES.size(): return {}
	return COMMANDER_ROLES[idx]

static func get_example(idx: int) -> Dictionary:
	if idx < 0 or idx >= EXAMPLES.size(): return {}
	return EXAMPLES[idx]
