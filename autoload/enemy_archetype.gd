## enemy_archetype.gd
##
## Per-archetype stat / skill / feat distributions used by the combat
## simulation when spawning humanoid enemies. Tables match the PHB
## examples the designer provided. For levels between the tabled break
## points (e.g. Lv 7), values are linearly interpolated.
##
## Archetypes: "Mage", "Rogue", "Fighter", "Monk".
##
## Public API:
##   stats_for(archetype, level)     -> Array[5]: [STR, SPD, INT, VIT, DIV]
##   skills_for(archetype, level)    -> Dictionary[skill_name -> ranks]
##   feats_for(archetype, level)     -> Dictionary[feat_name -> tier]
##   pick_random_archetype(rng)      -> String
##   total_stat_points_for_level(level) -> int

extends Node

# ── Stat distribution (PHB Tables, points per stat per archetype) ─────
# Indexed by [archetype][level_tier] = [STR, SPD, INT, VIT, DIV].
# Level tiers: 1, 5, 10, 15, 20.
const STAT_TABLE: Dictionary = {
	"Mage":    {  1: [0, 1, 2, 1, 2],  5: [0, 1, 3, 2, 4],
				 10: [0, 2, 3, 3, 7], 15: [0, 2, 5, 3, 10],
				 20: [0, 2, 6, 4, 10] },
	"Rogue":   {  1: [1, 2, 1, 1, 1],  5: [1, 3, 2, 2, 2],
				 10: [2, 4, 3, 3, 3], 15: [2, 5, 3, 3, 2],
				 20: [2, 6, 4, 4, 4] },
	"Fighter": {  1: [2, 1, 0, 2, 1],  5: [3, 2, 0, 3, 2],
				 10: [4, 3, 1, 4, 3], 15: [5, 4, 1, 5, 5],
				 20: [6, 5, 2, 6, 6] },
	"Monk":    {  1: [1, 2, 1, 1, 1],  5: [2, 3, 2, 2, 1],
				 10: [3, 4, 2, 3, 3], 15: [3, 5, 3, 4, 5],
				 20: [4, 6, 4, 5, 6] },
}

# ── Skill distribution (PHB Tables) ───────────────────────────────────
const SKILL_TABLE: Dictionary = {
	"Mage": {
		1:  {"Arcane":3,"Crafting":1,"Creature Handling":0,"Cunning":0,"Exertion":0,"Insight":1,"Learnedness":2,"Medical":1,"Nimble":1,"Perception":1,"Sneak":0,"Speechcraft":1,"Survival":1},
		5:  {"Arcane":5,"Crafting":2,"Creature Handling":0,"Cunning":1,"Exertion":1,"Insight":2,"Learnedness":3,"Medical":2,"Nimble":1,"Perception":2,"Sneak":1,"Speechcraft":2,"Survival":2},
		10: {"Arcane":8,"Crafting":3,"Creature Handling":2,"Cunning":1,"Exertion":2,"Insight":3,"Learnedness":4,"Medical":2,"Nimble":2,"Perception":3,"Sneak":1,"Speechcraft":3,"Survival":2},
		15: {"Arcane":10,"Crafting":4,"Creature Handling":1,"Cunning":4,"Exertion":2,"Insight":3,"Learnedness":5,"Medical":3,"Nimble":3,"Perception":5,"Sneak":2,"Speechcraft":5,"Survival":2},
		20: {"Arcane":10,"Crafting":5,"Creature Handling":5,"Cunning":5,"Exertion":5,"Insight":5,"Learnedness":6,"Medical":3,"Nimble":5,"Perception":4,"Sneak":2,"Speechcraft":5,"Survival":3},
	},
	"Rogue": {
		1:  {"Arcane":1,"Crafting":1,"Creature Handling":1,"Cunning":2,"Exertion":1,"Insight":1,"Learnedness":1,"Medical":0,"Nimble":2,"Perception":1,"Sneak":2,"Speechcraft":1,"Survival":1},
		5:  {"Arcane":1,"Crafting":2,"Creature Handling":1,"Cunning":3,"Exertion":2,"Insight":2,"Learnedness":1,"Medical":1,"Nimble":3,"Perception":3,"Sneak":3,"Speechcraft":2,"Survival":2},
		10: {"Arcane":2,"Crafting":3,"Creature Handling":2,"Cunning":4,"Exertion":3,"Insight":3,"Learnedness":2,"Medical":1,"Nimble":4,"Perception":4,"Sneak":4,"Speechcraft":3,"Survival":4},
		15: {"Arcane":5,"Crafting":5,"Creature Handling":2,"Cunning":5,"Exertion":3,"Insight":5,"Learnedness":5,"Medical":2,"Nimble":5,"Perception":5,"Sneak":5,"Speechcraft":4,"Survival":3},
		20: {"Arcane":3,"Crafting":5,"Creature Handling":2,"Cunning":7,"Exertion":4,"Insight":4,"Learnedness":3,"Medical":2,"Nimble":15,"Perception":7,"Sneak":9,"Speechcraft":5,"Survival":3},
	},
	"Fighter": {
		1:  {"Arcane":0,"Crafting":2,"Creature Handling":1,"Cunning":1,"Exertion":2,"Insight":1,"Learnedness":0,"Medical":1,"Nimble":1,"Perception":1,"Sneak":0,"Speechcraft":1,"Survival":1},
		5:  {"Arcane":0,"Crafting":3,"Creature Handling":2,"Cunning":1,"Exertion":3,"Insight":2,"Learnedness":1,"Medical":2,"Nimble":2,"Perception":2,"Sneak":1,"Speechcraft":2,"Survival":3},
		10: {"Arcane":1,"Crafting":4,"Creature Handling":2,"Cunning":4,"Exertion":5,"Insight":2,"Learnedness":1,"Medical":2,"Nimble":3,"Perception":5,"Sneak":3,"Speechcraft":2,"Survival":5},
		15: {"Arcane":1,"Crafting":6,"Creature Handling":3,"Cunning":2,"Exertion":10,"Insight":2,"Learnedness":2,"Medical":3,"Nimble":5,"Perception":4,"Sneak":2,"Speechcraft":3,"Survival":5},
		20: {"Arcane":4,"Crafting":9,"Creature Handling":3,"Cunning":2,"Exertion":15,"Insight":3,"Learnedness":2,"Medical":3,"Nimble":4,"Perception":5,"Sneak":2,"Speechcraft":4,"Survival":13},
	},
	"Monk": {
		1:  {"Arcane":1,"Crafting":2,"Creature Handling":1,"Cunning":1,"Exertion":2,"Insight":1,"Learnedness":1,"Medical":1,"Nimble":2,"Perception":1,"Sneak":1,"Speechcraft":1,"Survival":1},
		5:  {"Arcane":2,"Crafting":3,"Creature Handling":1,"Cunning":2,"Exertion":3,"Insight":2,"Learnedness":2,"Medical":2,"Nimble":3,"Perception":2,"Sneak":2,"Speechcraft":2,"Survival":2},
		10: {"Arcane":3,"Crafting":4,"Creature Handling":2,"Cunning":2,"Exertion":4,"Insight":3,"Learnedness":2,"Medical":2,"Nimble":5,"Perception":5,"Sneak":3,"Speechcraft":2,"Survival":2},
		15: {"Arcane":4,"Crafting":5,"Creature Handling":2,"Cunning":3,"Exertion":5,"Insight":5,"Learnedness":3,"Medical":5,"Nimble":5,"Perception":4,"Sneak":5,"Speechcraft":3,"Survival":5},
		20: {"Arcane":5,"Crafting":5,"Creature Handling":5,"Cunning":5,"Exertion":6,"Insight":6,"Learnedness":4,"Medical":5,"Nimble":6,"Perception":5,"Sneak":5,"Speechcraft":5,"Survival":5},
	},
}

# ── Feat lists per archetype (PHB class examples) ────────────────────
# An enemy of level L unlocks the first ceil(L / 3) feats from this list.
# Tier of each feat scales with level too: 1 tier per ~5 levels.
const FEAT_LISTS: Dictionary = {
	# Tank/protector — Divine Champion analog
	"Fighter": [
		"Iron Vitality", "Titanic Damage", "Turn the Blade",
		"Weapon Master", "Grasp of the Titan", "Martial Prowess",
		"Unyielding Defender", "Crimson Edge", "Iron Hammer",
		"Defensive Stance", "Safeguard", "Tower Shield",
	],
	# Spellcaster — Arcane Weaver analog
	"Mage": [
		"Arcane Wellspring", "Spell Shaper", "Magic Damage Expertise",
		"Effect Shaper", "Arcane Seal", "Mind Over Challenge",
		"Elemental Ward", "Create Demiplane", "Spark Leech",
	],
	# Sneaky striker — Shadowblade analog
	"Rogue": [
		"Swift Striker", "Precise Tactician", "Twin Fang",
		"Assassin's Execution", "Linebreaker's Aim", "Duelist's Path",
		"Stealth and Subterfuge", "Echoed Step", "Mirrorsteel Glint",
	],
	# Mobile martial — Swiftblade/monk analog
	"Monk": [
		"Iron Fist", "Martial Focus", "Swift Striker",
		"Unarmored Master", "Duelist's Path", "Temporal Touch",
		"Agile Explorer", "Improvised Weapon Mastery", "Fury's Call",
	],
}

# Total stat-point budget per level. Linear: 6 at L1, 25 at L20.
# Derived from PHB: L1=6, L5=10, L10=15, L15=20, L20=25.
const STAT_POINTS_BY_LEVEL: Dictionary = {
	1: 6, 5: 10, 10: 15, 15: 20, 20: 25,
}

const _ARCHETYPES: Array = ["Mage", "Rogue", "Fighter", "Monk"]
const _TIERS: Array = [1, 5, 10, 15, 20]

func pick_random_archetype(rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		return _ARCHETYPES[randi() % _ARCHETYPES.size()]
	return _ARCHETYPES[rng.randi() % _ARCHETYPES.size()]

## Find the two adjacent table tiers that bracket `level` and return
## (lower_tier, upper_tier, lerp_t in [0,1]).
func _bracket_for(level: int) -> Array:
	var lv: int = clampi(level, 1, 20)
	for i in range(_TIERS.size() - 1):
		var lo: int = _TIERS[i]
		var hi: int = _TIERS[i + 1]
		if lv >= lo and lv <= hi:
			var t: float = float(lv - lo) / float(hi - lo)
			return [lo, hi, t]
	return [_TIERS[-1], _TIERS[-1], 0.0]

func total_stat_points_for_level(level: int) -> int:
	var b: Array = _bracket_for(level)
	var lo: int = STAT_POINTS_BY_LEVEL[b[0]]
	var hi: int = STAT_POINTS_BY_LEVEL[b[1]]
	return int(round(lerp(float(lo), float(hi), float(b[2]))))

## Stats array [STR, SPD, INT, VIT, DIV] for an archetype at the given
## level, interpolated between tabled tiers. Rounds to ints.
func stats_for(archetype: String, level: int) -> Array:
	var arc: String = archetype if STAT_TABLE.has(archetype) else "Fighter"
	var b: Array = _bracket_for(level)
	var lo: Array = STAT_TABLE[arc][b[0]]
	var hi: Array = STAT_TABLE[arc][b[1]]
	var t: float = float(b[2])
	var out: Array = []
	for i in range(5):
		out.append(int(round(lerp(float(lo[i]), float(hi[i]), t))))
	return out

## Skill ranks map for an archetype at level. Interpolated.
func skills_for(archetype: String, level: int) -> Dictionary:
	var arc: String = archetype if SKILL_TABLE.has(archetype) else "Fighter"
	var b: Array = _bracket_for(level)
	var lo: Dictionary = SKILL_TABLE[arc][b[0]]
	var hi: Dictionary = SKILL_TABLE[arc][b[1]]
	var t: float = float(b[2])
	var out: Dictionary = {}
	for k in lo.keys():
		var lo_v: int = int(lo.get(k, 0))
		var hi_v: int = int(hi.get(k, 0))
		out[str(k)] = int(round(lerp(float(lo_v), float(hi_v), t)))
	return out

## Feats map {feat_name: tier} for an archetype at the given level.
## Number unlocked = clamp(ceil(level / 3), 1, list_size).
## Tier of each feat = clamp(1 + level / 4, 1, 5) (cap at T5).
func feats_for(archetype: String, level: int) -> Dictionary:
	var arc: String = archetype if FEAT_LISTS.has(archetype) else "Fighter"
	var feats: Array = FEAT_LISTS[arc]
	var unlock_count: int = clampi(int(ceil(float(level) / 3.0)), 1, feats.size())
	var feat_tier: int = clampi(1 + level / 4, 1, 5)
	var out: Dictionary = {}
	for i in range(unlock_count):
		out[str(feats[i])] = feat_tier
	return out
