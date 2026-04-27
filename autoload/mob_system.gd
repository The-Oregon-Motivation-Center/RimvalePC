## mob_system.gd
## Canonical Mob (Chaotic Mob Formation) rules data + formulas, matching the
## Mob Formation spec. Mobs are loose-cohesion groups of one (or occasionally
## two) creature types (animals, villagers, or monsters) that fight as a
## single unit under shared morale, instincts, and improvised equipment.
##
## Single source of truth for:
##   - Size categories + cohesion distance (wander too far → splits off as solo)
##   - Stat-point budget by level (L1=6 … L20=25)
##   - Shared stat formulas: HP = 3×Level + VIT (per member if split solo),
##                            AP = 10 + STR,
##                            SP = 5 + Level + DIV
##     Mob's HP POOL uses 1:1 rule (each member = 1 HP of pool).
##   - Instinct table (1d6), Frenzied Tactics (1d4)
##   - 12 Emergent Traits, 10 Mob Leaders
##   - Attack/trap/thrown damage scaling by member count
##   - Example mobs (Arcanite Rabble, Nightborne Shadow, Venari Tide, etc.)
class_name MobSystem
extends RefCounted

# ══════════════════════════════════════════════════════════════════════════════
# MOOD STATES ("Mob Type")
# ══════════════════════════════════════════════════════════════════════════════
const MOODS: Array = [
	"Enraged",       "Terrified",    "Jubilant",   "Desperate",
	"Opportunistic", "Frenzied",     "Panicked",   "Zealous",
]

# ══════════════════════════════════════════════════════════════════════════════
# STAT-POINT BUDGET BY LEVEL (L1=6 … L20=25)
# ══════════════════════════════════════════════════════════════════════════════
## Stat points available at each level. Formula: 5 + level. Capped at L20.
## All stats start at 0; points are distributed across STR/SPD/VIT/INT/DIV.
## Raising a stat above 5 costs 1 point per point (flat).
static func stat_points_for(level: int) -> int:
	return 5 + clampi(level, 1, 20)

# ══════════════════════════════════════════════════════════════════════════════
# SIZE CATEGORIES
# ══════════════════════════════════════════════════════════════════════════════
## Entries ordered small → huge. `max_cohesion_ft` is how far any two members
## may be before the stragglers revert to solo creatures. `move_adjust_ft` is
## applied to the 30 ft humanoid base before momentum/trait bonuses.
const SIZES: Array = [
	{"name": "Small",  "min_members":   5, "max_members":  20, "max_cohesion_ft": 20, "move_adjust_ft": +5},
	{"name": "Medium", "min_members":  21, "max_members":  50, "max_cohesion_ft": 40, "move_adjust_ft":  0},
	{"name": "Large",  "min_members":  51, "max_members": 100, "max_cohesion_ft": 60, "move_adjust_ft": -5},
	# Spec uses "Huge" for the 100+ examples (Titan's Vanguard, The Chosen).
	{"name": "Huge",   "min_members": 101, "max_members": 200, "max_cohesion_ft": 60, "move_adjust_ft": -5},
]

static func size_for_member_count(count: int) -> Dictionary:
	for s in SIZES:
		if count >= int(s["min_members"]) and count <= int(s["max_members"]):
			return s
	# Fall back to Huge for massive mobs, Small if under spec floor.
	if count > 200:  return SIZES[3]
	return SIZES[0]

# ══════════════════════════════════════════════════════════════════════════════
# INSTINCT TABLE (rolled when morale check fails)
# ══════════════════════════════════════════════════════════════════════════════
const INSTINCT_TABLE: Array = [
	{"roll": 1, "name": "Frenzy",  "effect": "All attacks +2, AC -2 this round."},
	{"roll": 2, "name": "Scatter", "effect": "Half the mob flees or hides."},
	{"roll": 3, "name": "Rally",   "effect": "Regain morale + 1d6 HP."},
	{"roll": 4, "name": "Grab",    "effect": "Attempt to restrain or grapple a target."},
	{"roll": 5, "name": "Loot",    "effect": "Mob focuses on grabbing valuables or supplies."},
	{"roll": 6, "name": "Chant",   "effect": "Noise disrupts spellcasting/concentration nearby."},
]

# ══════════════════════════════════════════════════════════════════════════════
# FRENZIED TACTICS (rolled each round while under half HP)
# ══════════════════════════════════════════════════════════════════════════════
const FRENZIED_TACTICS: Array = [
	{"roll": 1, "name": "Focused Assault",  "effect": "All attacks target one enemy."},
	{"roll": 2, "name": "Wild Swing",       "effect": "Attacks split among all nearby targets."},
	{"roll": 3, "name": "Defensive Huddle", "effect": "AC +2, damage rolls -2."},
	{"roll": 4, "name": "Mob Madness",      "effect": "Randomly target friend or foe."},
]

# ══════════════════════════════════════════════════════════════════════════════
# EMERGENT TRAITS (1d12 / pick 1)
# ══════════════════════════════════════════════════════════════════════════════
const TRAITS: Array = [
	{"roll":  1, "name": "Firestarters", "desc": "Can ignite objects as a group action."},
	{"roll":  2, "name": "Swarm",        "desc": "Move through obstacles as if difficult terrain."},
	{"roll":  3, "name": "Opportunists", "desc": "+2 to loot or steal actions."},
	{"roll":  4, "name": "Unstoppable",  "desc": "Ignore the first failed morale check."},
	{"roll":  5, "name": "Quick Learners","desc": "+1 to attack for the rest of the encounter after each failed attack (max +1 / round)."},
	{"roll":  6, "name": "Mob Healers",  "desc": "Heal 1d4 every round as a basic action."},
	{"roll":  7, "name": "Shadowed",     "desc": "Advantage on stealth checks at night."},
	{"roll":  8, "name": "Ironhide",     "desc": "Resistance to non-magical bludgeoning."},
	{"roll":  9, "name": "Cacophony",    "desc": "Constant distracting noise: enemies have disadvantage on perception + ranged attacks within 300 ft."},
	{"roll": 10, "name": "Rallying Cry", "desc": "Once per encounter: allies within 30 ft gain +2 to checks for 1 minute."},
	{"roll": 11, "name": "Nimble Feet",  "desc": "Movement speed +10 ft."},
	{"roll": 12, "name": "Keen Senses",  "desc": "Advantage on perception checks to spot hidden threats."},
]

# ══════════════════════════════════════════════════════════════════════════════
# MOB LEADERS (1d10 / optional)
# ══════════════════════════════════════════════════════════════════════════════
const LEADERS: Array = [
	{"roll":  1, "name": "Firebrand", "effect": "Once per encounter, the mob gains +2 to attack rolls for one round."},
	{"roll":  2, "name": "Coward",    "effect": "+2 to morale checks to flee, but -2 to attack rolls."},
	{"roll":  3, "name": "Trickster", "effect": "Once per encounter, ignore difficult terrain or bypass a barrier."},
	{"roll":  4, "name": "Brute",     "effect": "Attacks deal +1 damage per 5 members for one round, but -2 AC."},
	{"roll":  5, "name": "Prophet",   "effect": "Immune to fear effects (zealotry)."},
	{"roll":  6, "name": "Scavenger", "effect": "Loot/scavenge twice as fast, gaining extra resources or improvised weapons."},
	{"roll":  7, "name": "Whisperer", "effect": "Near-silence, advantage on sneak checks. -2 AC while sneaking."},
	{"roll":  8, "name": "Bulwark",   "effect": "+3 AC, -10 ft movement while in formation."},
	{"roll":  9, "name": "Madman",    "effect": "Acts twice in one round, but must roll on Instinct Table at turn end."},
	{"roll": 10, "name": "Shadow",    "effect": "Can hide or disperse instantly, avoiding pursuit or detection."},
]

# ══════════════════════════════════════════════════════════════════════════════
# CORE FORMULAS
# ══════════════════════════════════════════════════════════════════════════════

## Per-member solo HP when the member splits out (3 × Level + VIT).
static func member_solo_hp(level: int, vit: int) -> int:
	return 3 * level + vit

## Mob AP = 10 + STR.
static func compute_ap(str_score: int) -> int:
	return 10 + str_score

## Mob SP = 5 + Level + DIV.
static func compute_sp(level: int, div: int) -> int:
	return 5 + level + div

## Mob HP POOL (1:1 rule): one HP per member.
static func mob_hp_pool(member_count: int) -> int:
	return member_count

## Base morale (spec: always starts at 10; some high-level examples show 11-15).
## Scaling: round up from 10 at higher levels via progression table.
static func base_morale(level: int) -> int:
	if level >= 20: return 15
	if level >= 18: return 14
	if level >= 16: return 13
	if level >= 12: return 12
	if level >= 10: return 11
	return 10

## Morale check DC when the mob loses 25% HP: DC 10 + damage taken that tick.
static func morale_check_dc(damage_taken: int) -> int:
	return 10 + damage_taken

## Quarter-HP threshold that triggers the morale check.
static func morale_check_trigger(max_hp: int) -> int:
	return int(ceil(float(max_hp) * 0.25))

## Movement: 30 ft base (medium humanoid) + size adjust. +10 if moving straight
## (caller applies Momentum Swell as a toggle). Nimble Feet trait adds +10.
static func base_move_ft(size_adjust_ft: int = 0, has_nimble_feet: bool = false) -> int:
	var base: int = 30 + size_adjust_ft
	if has_nimble_feet:
		base += 10
	return base

## Momentum Swell: +10 ft this round, -2 AC until next turn.
static func momentum_swell(current_move_ft: int) -> Dictionary:
	return {"move_ft": current_move_ft + 10, "ac_mod": -2, "duration_rounds": 1}

## Splintering: if split by a barrier, each fragment moves at half speed
## until regrouping.
static func splintered_move_ft(current_move_ft: int) -> int:
	return current_move_ft / 2

## Frenzied check: mob is frenzied below half HP.
static func is_frenzied(current_hp: int, max_hp: int) -> bool:
	if max_hp <= 0: return false
	return current_hp * 2 <= max_hp

## Frenzy damage bonus: +1 per 5 members while frenzied.
static func frenzy_damage_bonus(member_count: int, is_frenzied_flag: bool = true) -> int:
	if not is_frenzied_flag:
		return 0
	return member_count / 5

## Improvised weapon attack: (members/2)d4 per attack — also equals (HP/2)d4
## because of the 1:1 rule.
static func improvised_attack_dice(member_count: int) -> Dictionary:
	return {"count": maxi(1, member_count / 2), "sides": 4}

## Thrown objects: 1d4 per 10 members, range 20/60 ft.
static func thrown_attack_dice(member_count: int) -> Dictionary:
	return {"count": maxi(1, member_count / 10), "sides": 4, "range_ft": 20, "long_range_ft": 60}

## Improvised trap damage: 1d4 per 10 members, DC 10 + INT (SPD save).
static func trap_dice(member_count: int, intellect: int) -> Dictionary:
	return {"count": maxi(1, member_count / 10), "sides": 4, "save_dc": 10 + intellect}

## Noise & distraction radius.
const NOISE_DISTRACTION_FT: int = 300

## Environmental Mayhem: once per encounter, bypass a single obstacle via the
## environment (overturn cart, break fence, etc.). SPD save DC 10 + STR or:
##   1: Immobilized (SPD=0 for rest of their turn)
##   2: Hazardous Passage (1d4 per 5 ft of movement)
##   3: Blocked or Swept (can't move through / swept along)
##   4: Knocked Prone (spend half movement to stand)
static func environmental_mayhem_save_dc(str_score: int) -> int:
	return 10 + str_score

const ENVIRONMENTAL_MAYHEM_FAIL_TABLE: Array = [
	{"roll": 1, "name": "Immobilized",       "effect": "Speed 0 for rest of turn."},
	{"roll": 2, "name": "Hazardous Passage", "effect": "1d4 damage per 5 ft of movement through/over mob."},
	{"roll": 3, "name": "Blocked or Swept",  "effect": "Cannot move through — stuck outside; or swept with the mob if mob moves through."},
	{"roll": 4, "name": "Knocked Prone",     "effect": "Prone — half movement to stand. Disadvantage on attacks + DEX until next turn."},
]

# ══════════════════════════════════════════════════════════════════════════════
# EXAMPLE MOBS (from spec)
# ══════════════════════════════════════════════════════════════════════════════
const EXAMPLE_MOBS: Array = [
	# 0
	{
		"id":          "arcanite_rabble",
		"name":        "Arcanite Rabble",
		"mood":        "Jubilant",
		"members":     18,
		"level":       2,
		"stats":       {"str": 2, "spd": 2, "int": 1, "vit": 1, "div": 1},
		"trait_idx":   0,   # Firestarters
		"leader_idx":  2,   # Trickster (1-indexed in table but 0-indexed here? use name match)
		"leader_name": "Trickster",
		"equipment":   "Scrap gadgets, improvised clubs",
		"desc":        "Celebrating a magical festival with sparks and song, the Rabble turns dangerous at the first wrong word.",
	},
	# 1
	{
		"id":          "nightborne_shadow",
		"name":        "Nightborne Shadow Mob",
		"mood":        "Terrified",
		"members":     8,
		"level":       1,
		"stats":       {"str": 1, "spd": 2, "int": 1, "vit": 1, "div": 1},
		"trait_idx":   6,   # Shadowed
		"leader_name": "Whisperer",
		"equipment":   "Stones, makeshift shields",
		"special":     "Veilstep: teleport up to 20 ft in dim light for 3 AP.",
		"desc":        "A small band of panicked locals fleeing a radiant threat, slipping between shadows.",
	},
	# 2
	{
		"id":          "venari_tide",
		"name":        "Venari Tide Mob",
		"mood":        "Desperate",
		"members":     40,
		"level":       3,
		"stats":       {"str": 2, "spd": 2, "int": 1, "vit": 2, "div": 1},
		"trait_idx":   3,   # Unstoppable
		"leader_name": "Bulwark",
		"equipment":   "Spears, nets, driftwood clubs",
		"special":     "Pack Instinct: advantage on attacks if an ally is within 5 ft of target.",
		"desc":        "Coastal defenders holding the tide-line against invaders with spear and net.",
	},
	# 3
	{
		"id":          "groblodyte_scavenger",
		"name":        "Groblodyte Scavenger Mob",
		"mood":        "Opportunistic",
		"members":     20,
		"level":       2,
		"stats":       {"str": 1, "spd": 2, "int": 2, "vit": 1, "div": 1},
		"trait_idx":   2,   # Opportunists
		"leader_name": "Scavenger",
		"equipment":   "Tinker tools, scrap weapons",
		"desc":        "Raiders who prefer a full cart to a fair fight — clever, quick, never quiet.",
	},
	# 4
	{
		"id":          "beast_swarm",
		"name":        "Beast Swarm (Weasels & Voles)",
		"mood":        "Frenzied",
		"members":     50,
		"level":       1,
		"stats":       {"str": 1, "spd": 2, "int": 1, "vit": 1, "div": 1},
		"trait_idx":   1,   # Swarm
		"leader_name": "Brute",
		"equipment":   "Teeth, claws, improvised burrows",
		"special":     "Can burrow and reappear up to 30 ft away for 3 AP.",
		"desc":        "Cornered beasts boil over walls and through cellar floors, all teeth and hunger.",
	},
	# 5: Level 4
	{
		"id":          "emberkin_street",
		"name":        "Emberkin Street Mob",
		"mood":        "Enraged",
		"members":     20,
		"level":       4,
		"stats":       {"str": 2, "spd": 2, "int": 2, "vit": 2, "div": 1},
		"trait_idx":   0,   # Firestarters (spec: "Firestarter — can ignite objects as group action")
		"leader_name": "The Spark",   # custom leader (Firebrand-like)
		"equipment":   "Torches, slings",
		"desc":        "Fire-breathed slum-dwellers with a grudge and a matchbook.",
	},
	# 6: Level 5
	{
		"id":          "ironclad_militia_mob",
		"name":        "Ironclad Militia",
		"mood":        "Zealous",
		"members":     25,
		"level":       5,
		"stats":       {"str": 3, "spd": 2, "int": 2, "vit": 2, "div": 1},
		"trait_idx":   -1,  # custom: Shield Wall (+2 AC in formation)
		"custom_trait":{"name":"Shield Wall","desc":"+2 AC when in formation."},
		"leader_name": "Captain",
		"equipment":   "Shields, spears",
		"desc":        "A disciplined mob-army teetering between militia and zealot brigade.",
	},
	# 7: Level 8
	{
		"id":          "nightborne_shadow_host",
		"name":        "Nightborne Shadow Host",
		"mood":        "Opportunistic",
		"members":     40,
		"level":       8,
		"stats":       {"str": 3, "spd": 3, "int": 3, "vit": 2, "div": 2},
		"trait_idx":   6,   # Shadowed
		"leader_name": "Whisperer",
		"equipment":   "Short swords, cloaks",
		"special":     "Can Veilstep for 3 AP.",
		"desc":        "A veteran shadow crew. Strikes at dusk, vanishes by moonrise.",
	},
	# 8: Level 10
	{
		"id":          "venari_tide_guard",
		"name":        "Venari Tide Guard",
		"mood":        "Desperate",
		"members":     50,
		"level":       10,
		"stats":       {"str": 4, "spd": 3, "int": 3, "vit": 3, "div": 2},
		"trait_idx":   3,   # Unstoppable
		"leader_name": "Bulwark",
		"equipment":   "Spears, nets",
		"desc":        "Elite coastal defenders — older, colder, harder to break than the tide mob.",
	},
	# 9: Level 12
	{
		"id":          "arcane_militia",
		"name":        "Arcane Militia",
		"mood":        "Zealous",
		"members":     60,
		"level":       12,
		"stats":       {"str": 4, "spd": 4, "int": 4, "vit": 3, "div": 2},
		"trait_idx":   -1,
		"custom_trait":{"name":"Arcane Disruption","desc":"Can dispel magic as a group action."},
		"leader_name": "The Mage",
		"equipment":   "Ritual staves, shields",
		"desc":        "Robed battle-casters channeling synchronized ritual-magic in a pitched line.",
	},
	# 10: Level 16
	{
		"id":          "sacred_zealots",
		"name":        "Sacred Zealots",
		"mood":        "Zealous",
		"members":     80,
		"level":       16,
		"stats":       {"str": 5, "spd": 5, "int": 4, "vit": 4, "div": 3},
		"trait_idx":   -1,
		"custom_trait":{"name":"Divine Zeal","desc":"Can heal allies as a group action."},
		"leader_name": "The Priest",
		"equipment":   "Blessed maces, shields",
		"desc":        "A hymn-chanting war-congregation, zeal-blind and divinely insulated from fear.",
	},
	# 11: Level 18
	{
		"id":          "titans_vanguard",
		"name":        "Titan's Vanguard",
		"mood":        "Zealous",
		"members":     100,
		"level":       18,
		"stats":       {"str": 6, "spd": 5, "int": 5, "vit": 4, "div": 3},
		"trait_idx":   -1,
		"custom_trait":{"name":"Iron Sentinel","desc":"Resistance to non-magical damage."},
		"leader_name": "The Warlord",
		"equipment":   "Heavy polearms, tower shields",
		"desc":        "A marching wall of plate and polearm, drilled to endure and break armies.",
	},
	# 12: Level 20
	{
		"id":          "the_chosen",
		"name":        "The Chosen",
		"mood":        "Zealous",
		"members":     120,
		"level":       20,
		"stats":       {"str": 7, "spd": 6, "int": 5, "vit": 4, "div": 3},
		"trait_idx":   -1,
		"custom_trait":{"name":"Aegis of the Shattered Gods","desc":"Absorb one spell once per long rest."},
		"leader_name": "The Hierophant",
		"equipment":   "Divine relics, enchanted blades",
		"desc":        "The apex mob. Prophecy incarnate, walking in armies of a hundred and twenty.",
	},
]

# ══════════════════════════════════════════════════════════════════════════════
# RESOLVE / GENERATE HELPERS
# ══════════════════════════════════════════════════════════════════════════════

static func get_example(idx: int) -> Dictionary:
	if idx < 0 or idx >= EXAMPLE_MOBS.size():
		return {}
	return EXAMPLE_MOBS[idx]

## Resolve an example into a full live-stat block using the spec formulas.
static func resolve_example(idx: int) -> Dictionary:
	var d: Dictionary = get_example(idx)
	if d.is_empty():
		return {}
	return _to_live(d)

## Generate a procedural mob at a level with member count + stat distribution.
## If stats are omitted, defaults are sensible for STR/SPD/VIT mob roles.
static func generate_procedural(level: int, member_count: int,
		str_score: int = -1, spd: int = -1, intel: int = -1,
		vit: int = -1, div: int = -1, mood: String = "Enraged") -> Dictionary:
	var pts: int = stat_points_for(level)
	if str_score < 0: str_score = pts / 4
	if spd < 0:       spd       = pts / 4
	if vit < 0:       vit       = pts / 4
	if intel < 0:     intel     = maxi(1, pts / 8)
	if div < 0:       div       = maxi(1, pts / 8)
	return _to_live({
		"id":      "procedural_mob_%d" % level,
		"name":    "Level %d %s Mob" % [level, mood],
		"mood":    mood,
		"members": member_count,
		"level":   level,
		"stats":   {"str": str_score, "spd": spd, "int": intel, "vit": vit, "div": div},
	})

## Internal: convert an example/procedural dict → full live stat block.
static func _to_live(d: Dictionary) -> Dictionary:
	var s: Dictionary = d["stats"]
	var lvl: int  = int(d["level"])
	var mem: int  = int(d["members"])
	var size_def: Dictionary = size_for_member_count(mem)

	var ap_val: int = compute_ap(int(s["str"]))
	var sp_val: int = compute_sp(lvl, int(s["div"]))
	var member_hp: int = member_solo_hp(lvl, int(s["vit"]))
	var pool_hp: int = mob_hp_pool(mem)
	var morale: int  = base_morale(lvl)

	var trait_def: Dictionary = {}
	if d.has("custom_trait"):
		trait_def = d["custom_trait"]
	elif int(d.get("trait_idx", -1)) >= 0:
		trait_def = TRAITS[int(d["trait_idx"])]

	var leader_name: String = str(d.get("leader_name", ""))
	var leader_def: Dictionary = {}
	for l in LEADERS:
		if str(l["name"]) == leader_name:
			leader_def = l
			break

	var base_move: int = base_move_ft(int(size_def["move_adjust_ft"]),
		trait_def.get("name", "") == "Nimble Feet")

	var attack_dice: Dictionary = improvised_attack_dice(mem)

	return {
		"id":              d.get("id", ""),
		"name":            d.get("name", "Mob"),
		"mood":            d.get("mood", "Enraged"),
		"level":           lvl,
		"members":         mem,
		"stats":           s,
		"str":             int(s["str"]),
		"spd":             int(s["spd"]),
		"int":             int(s["int"]),
		"vit":             int(s["vit"]),
		"div":             int(s["div"]),
		"size":            size_def["name"],
		"max_cohesion_ft": int(size_def["max_cohesion_ft"]),
		"hp":              pool_hp,
		"max_hp":          pool_hp,
		"solo_hp_per_member": member_hp,  # what each member becomes if split
		"ap":              ap_val,
		"max_ap":          ap_val,
		"sp":              sp_val,
		"max_sp":          sp_val,
		"morale":          morale,
		"morale_trigger_hp": morale_check_trigger(pool_hp),
		"base_move_ft":    base_move,
		"momentum_move_ft": base_move + 10,
		"momentum_ac_mod": -2,
		"splintered_move_ft": base_move / 2,
		"attack_dice":     attack_dice,          # e.g. {count:10, sides:4}
		"thrown_dice":     thrown_attack_dice(mem),
		"trap_dice":       trap_dice(mem, int(s["int"])),
		"noise_ft":        NOISE_DISTRACTION_FT,
		"env_mayhem_dc":   environmental_mayhem_save_dc(int(s["str"])),
		"trait":           trait_def,
		"leader":          leader_def,
		"equipment":       d.get("equipment", ""),
		"special":         d.get("special", ""),
		"desc":            d.get("desc", ""),
		"feats":           d.get("feats", []),
	}
