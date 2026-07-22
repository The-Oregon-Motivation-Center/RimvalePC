extends Node
## CardSystem — hotseat card-battler built on Rimvale's tabletop rules.
##
## Two players build decks of character / equipment / feat / spell cards,
## then battle on a 6-slot board. Win by reducing the enemy player's HP to 0.
##
## Rules kept faithful to the PHB (see rimvale_fallback_engine.gd):
##   HP = 3 + 3*level + VIT      AP = 3 + STR       SP = 3 + level + DIV
##   Feat budget = 6 + 4*(level-1) points; a feat card costs its tier.
##   Spell budget = max SP; equipped spell cards' SP costs must fit inside it.
##   Attacks: d20 + stat vs AC, nat-20 crits double dice.
##   XP curve: 10 at L1, doubling per level, capped at 1000.
##
## Player-facing economy (Card Mode specific):
##   Energy ramps 1→ENERGY_CAP per round. Playing a card = 1 energy.
##   Equipping any card onto a character = 1 energy.
##   Character actions spend the CHARACTER's AP, not player energy.

signal card_event(kind: String, data: Dictionary)

# ══════════════════════════════════════════════════════════════════════════
#  Tuning constants
# ══════════════════════════════════════════════════════════════════════════

const MAX_SLOTS := 6            # board slots per player
const PLAYER_HP := 40           # each player's own HP pool
const ENERGY_CAP := 5           # energy ramp: round 1 = 1 … round 5+ = 5
const HAND_START := 9           # opening hand — the turn-1 free draw tops it to the limit
const HAND_MAX := 10            # hard hand limit — over it, discards are forced
const DECK_SIZE := 60           # cards a deck must contain
const MIN_CHARACTERS := 6       # a legal deck needs at least this many characters
## Action costs escalate with fatigue: a character's FIRST action each
## round costs 1 AP, the second 2 AP, the third 3 AP, and so on. Attacks
## and spell casts share the same per-round counter (card["acts"]).
const XP_PER_ACTION := 5        # XP a character earns per attack/cast
const LEVEL_CAP := 20           # PHB level cap
const STAT_CAP := 10            # per-stat ceiling; overflow becomes HP
const DR_CAP := 6               # flat damage-reduction ceiling across all sources
const PLAYER_BASE_AC := 10      # attacking a player: d20 vs 10 + their living characters

# ══════════════════════════════════════════════════════════════════════════
#  Card data tables (curated from the engine's registries — see research
#  notes: _ITEM_REGISTRY, _FEAT_REGISTRY, _SPELL_DB in rimvale_fallback_engine.gd)
# ══════════════════════════════════════════════════════════════════════════

## Weapons: dice parsed from _ITEM_REGISTRY. finesse=true → SPD to hit/damage.
const CARD_WEAPONS := {
	"Dagger":       {"dc": 1, "ds": 4,  "finesse": true,  "dt": "piercing"},
	"Shortsword":   {"dc": 1, "ds": 6,  "finesse": true,  "dt": "piercing"},
	"Mace":         {"dc": 1, "ds": 6,  "finesse": false, "dt": "bludgeoning"},
	"Spear":        {"dc": 1, "ds": 6,  "finesse": false, "dt": "piercing"},
	"Rapier":       {"dc": 1, "ds": 8,  "finesse": true,  "dt": "piercing"},
	"Longsword":    {"dc": 1, "ds": 8,  "finesse": false, "dt": "slashing"},
	"Battleaxe":    {"dc": 1, "ds": 8,  "finesse": false, "dt": "slashing"},
	"Warhammer":    {"dc": 1, "ds": 8,  "finesse": false, "dt": "bludgeoning"},
	"Katana":       {"dc": 1, "ds": 8,  "finesse": false, "dt": "slashing"},
	"Longbow":      {"dc": 1, "ds": 8,  "finesse": true,  "dt": "piercing", "ranged": true},
	"Pike":         {"dc": 1, "ds": 10, "finesse": false, "dt": "piercing"},
	"Heavy Crossbow": {"dc": 1, "ds": 10, "finesse": true, "dt": "piercing", "ranged": true},
	"Greataxe":     {"dc": 1, "ds": 12, "finesse": false, "dt": "slashing"},
	"Greatsword":   {"dc": 2, "ds": 6,  "finesse": false, "dt": "slashing"},
	"Maul":         {"dc": 2, "ds": 6,  "finesse": false, "dt": "bludgeoning"},
	"Glaive":       {"dc": 2, "ds": 6,  "finesse": false, "dt": "slashing"},
}

## Armor: base AC + how much SPD applies (_armor_ac_with_speed rules).
## spd_cap -1 = full SPD (light), 2 = medium cap, 0 = heavy (none).
const CARD_ARMOR := {
	"Leather":         {"ac": 11, "spd_cap": -1},
	"Studded Leather": {"ac": 12, "spd_cap": -1},
	"Hide":            {"ac": 12, "spd_cap": 2},
	"Chain Shirt":     {"ac": 13, "spd_cap": 2},
	"Scale Mail":      {"ac": 14, "spd_cap": 2},
	"Breastplate":     {"ac": 14, "spd_cap": 2},
	"Half Plate":      {"ac": 15, "spd_cap": 2},
	"Chain Mail":      {"ac": 16, "spd_cap": 0},
	"Splint":          {"ac": 17, "spd_cap": 0},
	"Plate":           {"ac": 18, "spd_cap": 0},
}

const CARD_SHIELDS := {
	"Standard Shield": {"ac": 2},
	"Tower Shield":    {"ac": 3},
}

## Feat cards, ported from the engine's _FEAT_REGISTRY (the PHB feat trees).
## Each feat keeps its REAL tier sequence — Iron Vitality is 1/3/5, there is
## no tier 2 — and its real ceiling. `seq` is the upgrade ladder; `tiers`
## holds each rung's complete effect (higher tiers restate, not stack).
## A card's feat-point cost is its current tier, per the PHB.
##
## Tabletop concepts with no card analogue (reactions, opportunity attacks,
## once-per-long-rest, proficiencies, saving throws) are translated to the
## nearest card mechanic; every such call is noted inline.
const CARD_FEATS := {
	"Iron Vitality": {"seq": [1, 3, 5], "tiers": {
		1: {"desc": "HP is 2×VIT + 3×level + 3.", "fx": {"hp_vit_mult": 2}},
		3: {"desc": "HP is 2×VIT + 3×level + 3. Healing you receive is increased by your VIT.",
			"fx": {"hp_vit_mult": 2, "heal_vit": 1}},
		5: {"desc": "HP is 3×VIT + 3×level + 3. Once per match, damage that would drop you to 0 leaves you at 1 HP.",
			"fx": {"hp_vit_mult": 3, "heal_vit": 1, "cheat_death": 1}}}},
	"Martial Focus": {"seq": [1, 3, 5], "tiers": {
		1: {"desc": "AP is 2×STR + 3.", "fx": {"ap_str_mult": 2}},
		3: {"desc": "AP is 2×STR + 3, plus bonus AP equal to your STR.",
			"fx": {"ap_str_mult": 2, "ap_stat_bonus": 1}},
		5: {"desc": "AP is 3×STR + 3, plus bonus AP equal to your STR.",
			"fx": {"ap_str_mult": 3, "ap_stat_bonus": 1}}}},
	"Arcane Wellspring": {"seq": [1, 3, 5], "tiers": {
		1: {"desc": "SP is 2×DIV + level + 3.", "fx": {"sp_div_mult": 2}},
		3: {"desc": "SP is 2×DIV + level + 3. Your spells hit harder (+1 spell power).",
			"fx": {"sp_div_mult": 2, "spell_power": 1}},
		5: {"desc": "SP is 3×DIV + level + 3, +2 spell power. Each spell may be cast twice per round.",
			"fx": {"sp_div_mult": 3, "spell_power": 2, "spell_recast": 1}}}},
	"Unyielding Defender": {"seq": [1, 2, 3], "tiers": {
		1: {"desc": "+1 AC.", "fx": {"ac_bonus": 1}},
		2: {"desc": "+1 AC, and +2 more while below a third of your HP.",
			"fx": {"ac_bonus": 1, "low_hp_ac": 2}},
		3: {"desc": "+1 AC, +2 more while bloodied, and immunity to stun and fright.",
			"fx": {"ac_bonus": 1, "low_hp_ac": 2, "cond_immune": ["stunned", "frightened"]}}}},
	"Precise Tactician": {"seq": [1, 2, 3, 4, 5], "tiers": {
		1: {"desc": "Critical hits on 19–20.", "fx": {"crit_at": 19}},
		2: {"desc": "Critical hits on 18–20. Crits grant 2 AP.", "fx": {"crit_at": 18, "crit_ap": 2}},
		3: {"desc": "Critical hits on 17–20. Crits grant 2 AP and stun the target.",
			"fx": {"crit_at": 17, "crit_ap": 2, "crit_stun": 1}},
		4: {"desc": "Critical hits on 16–20. Crits grant 2 AP and stun the target.",
			"fx": {"crit_at": 16, "crit_ap": 2, "crit_stun": 1}},
		5: {"desc": "Critical hits on 15–20. A crit refunds its action entirely — strike again.",
			"fx": {"crit_at": 15, "crit_ap": 2, "crit_stun": 1, "free_on_crit": 1}}}},
	"Titanic Damage": {"seq": [1, 2, 3], "tiers": {
		1: {"desc": "Add your attacking stat to damage a second time.", "fx": {"dmg_stat_mult": 2}},
		2: {"desc": "Add your attacking stat twice more. A kill refunds the action — attack again.",
			"fx": {"dmg_stat_mult": 3, "free_on_kill": 1}},
		3: {"desc": "Add your attacking stat twice more, +3 damage, and a kill refunds the action.",
			"fx": {"dmg_stat_mult": 3, "dmg_bonus": 3, "free_on_kill": 1}}}},
	"Swift Striker": {"seq": [1, 2, 3], "tiers": {
		1: {"desc": "+1 to attack rolls with any weapon.", "fx": {"hit_bonus": 1}},
		2: {"desc": "+1 to attack rolls; add your attacking stat to damage a second time.",
			"fx": {"hit_bonus": 1, "dmg_stat_mult": 2}},
		3: {"desc": "+2 to attack rolls, doubled stat damage, and a kill refunds the action.",
			"fx": {"hit_bonus": 2, "dmg_stat_mult": 2, "free_on_kill": 1}}}},
	"Evasive Ward": {"seq": [1, 2, 3], "tiers": {
		1: {"desc": "+1 AC while in light or no armor.", "fx": {"ac_light_bonus": 1}},
		2: {"desc": "+1 AC in light armor; immune to being slowed.",
			"fx": {"ac_light_bonus": 1, "cond_immune": ["slowed"]}},
		3: {"desc": "In light or no armor, add your SPD to AC a second time. Immune to slow.",
			"fx": {"ac_light_bonus": 1, "ac_light_spd": 1, "cond_immune": ["slowed"]}}}},
	"Rest & Recovery": {"seq": [1, 2, 3, 4], "tiers": {
		1: {"desc": "+2 AP each round.", "fx": {"ap_bonus": 2}},
		2: {"desc": "+2 AP each round; immune to fright.",
			"fx": {"ap_bonus": 2, "cond_immune": ["frightened"]}},
		3: {"desc": "+2 AP each round, heal 1d4 at the start of your turn, immune to fright.",
			"fx": {"ap_bonus": 2, "regen": 1, "cond_immune": ["frightened"]}},
		4: {"desc": "+3 AP each round, heal 1d4 per turn, immune to fright and stun.",
			"fx": {"ap_bonus": 3, "regen": 1, "cond_immune": ["frightened", "stunned"]}}}},
	"Fury's Call": {"seq": [1, 2, 3, 4, 5], "tiers": {
		1: {"desc": "Your hits enrage — the target is frightened.", "fx": {"inflict_on_hit": "frightened"}},
		2: {"desc": "Hits frighten. Incoming damage is reduced by 1.",
			"fx": {"inflict_on_hit": "frightened", "dr": 1}},
		3: {"desc": "Hits frighten, damage reduced by 1, +2 damage while below half HP.",
			"fx": {"inflict_on_hit": "frightened", "dr": 1, "rage_dmg": 2}},
		4: {"desc": "Hits frighten, damage reduced by 2, +3 damage while bloodied.",
			"fx": {"inflict_on_hit": "frightened", "dr": 2, "rage_dmg": 3}},
		5: {"desc": "Hits frighten, damage reduced by 2, +5 damage while bloodied.",
			"fx": {"inflict_on_hit": "frightened", "dr": 2, "rage_dmg": 5}}}},
	"Duelist's Path": {"seq": [1, 2, 3], "tiers": {
		1: {"desc": "Parry: melee attackers take 2 damage.", "fx": {"thorns": 2}},
		2: {"desc": "Parry for 3, and +1 to your own attack rolls.", "fx": {"thorns": 3, "hit_bonus": 1}},
		3: {"desc": "Parry for 4, +1 to attacks, +1 AC.",
			"fx": {"thorns": 4, "hit_bonus": 1, "ac_bonus": 1}}}},
	"Iron Fist": {"seq": [1, 2, 3], "tiers": {
		1: {"desc": "Unarmed strikes deal 1d6.", "fx": {"unarmed_die": 6}},
		2: {"desc": "Unarmed strikes deal 1d8 and slow the target.",
			"fx": {"unarmed_die": 8, "inflict_on_hit": "slowed"}},
		3: {"desc": "Unarmed strikes deal 1d10, slow the target, and add your stat twice.",
			"fx": {"unarmed_die": 10, "inflict_on_hit": "slowed", "dmg_stat_mult": 2}}}},
	# ── Phase 1 additions ────────────────────────────────────────────────
	"Safeguard": {"seq": [1, 2, 3, 4, 5], "tiers": {
		1: {"desc": "Ward 1: shrug off an incoming condition on d20+1 vs 12.", "fx": {"cond_ward": 1}},
		2: {"desc": "Ward 3 against incoming conditions.", "fx": {"cond_ward": 3}},
		3: {"desc": "Ward 5 against incoming conditions.", "fx": {"cond_ward": 5}},
		4: {"desc": "Ward 7 against incoming conditions.", "fx": {"cond_ward": 7}},
		5: {"desc": "Ward 9, and shrugging a condition restores HP equal to your level.",
			"fx": {"cond_ward": 9, "ward_heal": 1}}}},
	"Crimson Edge": {"seq": [2, 3, 5], "tiers": {
		2: {"desc": "Slashing weapons roll at least a d6.", "fx": {"weapon_die_by_type": {"slashing": 6}}},
		3: {"desc": "Slashing weapons roll at least a d8.", "fx": {"weapon_die_by_type": {"slashing": 8}}},
		5: {"desc": "Slashing weapons roll at least a d10.", "fx": {"weapon_die_by_type": {"slashing": 10}}}}},
	"Iron Hammer": {"seq": [2, 3, 5], "tiers": {
		2: {"desc": "Bludgeoning weapons roll at least a d8.", "fx": {"weapon_die_by_type": {"bludgeoning": 8}}},
		3: {"desc": "Bludgeoning weapons roll at least a d10, and hits slow the target.",
			"fx": {"weapon_die_by_type": {"bludgeoning": 10}, "inflict_on_hit": "slowed"}},
		5: {"desc": "Bludgeoning weapons roll at least a d12, and hits slow the target.",
			"fx": {"weapon_die_by_type": {"bludgeoning": 12}, "inflict_on_hit": "slowed"}}}},
	"Iron Thorn": {"seq": [2, 3, 5], "tiers": {
		2: {"desc": "Piercing weapons roll at least a d6.", "fx": {"weapon_die_by_type": {"piercing": 6}}},
		3: {"desc": "Piercing weapons roll at least a d8; hits strip 1 AC until the target's turn.",
			"fx": {"weapon_die_by_type": {"piercing": 8}, "ac_debuff_on_hit": 1}},
		5: {"desc": "Piercing weapons roll at least a d10; hits strip 2 AC until the target's turn.",
			"fx": {"weapon_die_by_type": {"piercing": 10}, "ac_debuff_on_hit": 2}}}},
	"Martial Prowess": {"seq": [1, 2, 3], "tiers": {
		1: {"desc": "+2 to attack rolls.", "fx": {"hit_bonus": 2}},
		2: {"desc": "+3 to attack rolls.", "fx": {"hit_bonus": 3}},
		3: {"desc": "+3 to attack rolls; a miss still grazes for your attacking stat.",
			"fx": {"hit_bonus": 3, "graze": 1}}}},
	"Weapon Mastery": {"seq": [1, 2, 3], "tiers": {
		1: {"desc": "+1 to attack rolls with any weapon.", "fx": {"hit_bonus": 1}},
		2: {"desc": "+1 to attack rolls; reroll damage dice that come up 1.",
			"fx": {"hit_bonus": 1, "reroll_ones": 1}},
		3: {"desc": "+2 to attack rolls, reroll 1s, and crit on 19–20.",
			"fx": {"hit_bonus": 2, "reroll_ones": 1, "crit_at": 19}}}},
	"Titanic Bastion": {"seq": [1, 2, 3, 5], "tiers": {
		1: {"desc": "+1 AC in heavy armor.", "fx": {"ac_heavy_bonus": 1}},
		2: {"desc": "In heavy armor, add your STR to AC.", "fx": {"ac_heavy_bonus": 1, "ac_heavy_str": 1}},
		3: {"desc": "In heavy armor, add STR to AC and reduce all damage by 2.",
			"fx": {"ac_heavy_bonus": 1, "ac_heavy_str": 1, "dr": 2}},
		5: {"desc": "In heavy armor, add STR to AC and reduce all damage by 4.",
			"fx": {"ac_heavy_bonus": 1, "ac_heavy_str": 1, "dr": 4}}}},
	"Balanced Bulwark": {"seq": [1, 3, 5], "tiers": {
		1: {"desc": "+1 AC in medium armor.", "fx": {"ac_medium_bonus": 1}},
		3: {"desc": "In medium armor, add your full STR or SPD to AC (no cap).",
			"fx": {"ac_medium_bonus": 1, "ac_medium_stat": 1}},
		5: {"desc": "Medium armor uses your full STR or SPD, and attackers who miss you are counterattacked.",
			"fx": {"ac_medium_bonus": 1, "ac_medium_stat": 1, "counter_on_miss": 1}}}},
	"Unarmored Master": {"seq": [1, 2, 4], "tiers": {
		1: {"desc": "Unarmored AC is 10 + 2×SPD.", "fx": {"ac_unarmored_spd_mult": 2}},
		2: {"desc": "Unarmored AC is 10 + 2×SPD; reduce incoming damage by 1d4 per point of SPD.",
			"fx": {"ac_unarmored_spd_mult": 2, "dr_spd": 1}},
		4: {"desc": "Unarmored AC is 10 + 2×SPD, SPD-scaled damage reduction, and 3 flat damage reduction.",
			"fx": {"ac_unarmored_spd_mult": 2, "dr_spd": 1, "dr": 3}}}},
	# ── Phase 2 additions ────────────────────────────────────────────────
	"Elemental Ward": {"seq": [1, 2, 3, 4], "tiers": {
		1: {"desc": "Halve incoming fire, cold, lightning and arcane damage.",
			"fx": {"resist_elemental": 1}},
		2: {"desc": "Halve elemental damage; +1 AC.", "fx": {"resist_elemental": 1, "ac_bonus": 1}},
		3: {"desc": "Halve elemental damage, +1 AC, and heal 1d4 at the start of your turn.",
			"fx": {"resist_elemental": 1, "ac_bonus": 1, "regen": 1}},
		4: {"desc": "IMMUNE to fire, cold, lightning and arcane damage. +1 AC, regeneration.",
			"fx": {"immune_elemental": 1, "ac_bonus": 1, "regen": 1}}}},
	"Turn the Blade": {"seq": [1, 2, 3], "tiers": {
		1: {"desc": "When an attack misses you, set your guard (+3 AC until your next turn).",
			"fx": {"ac_on_evade": 1}},
		2: {"desc": "Evading also seizes the tempo: +1 AP.", "fx": {"ac_on_evade": 1, "ap_on_evade": 1}},
		3: {"desc": "Evading grants guard, +1 AP, and a free counterattack.",
			"fx": {"ac_on_evade": 1, "ap_on_evade": 1, "counter_on_miss": 1}}}},
	"Deflective Stance": {"seq": [1, 2, 3, 4], "tiers": {
		1: {"desc": "When an attack misses you, set your guard (+3 AC until your next turn).",
			"fx": {"ac_on_evade": 1}},
		2: {"desc": "Evading sets your guard and counterattacks the attacker.",
			"fx": {"ac_on_evade": 1, "counter_on_miss": 1}},
		3: {"desc": "Guard, counterattack, and reduce all incoming damage by your SPD.",
			"fx": {"ac_on_evade": 1, "counter_on_miss": 1, "dr_stat": 1}},
		4: {"desc": "Guard, counterattack, SPD damage reduction, and +1 AC.",
			"fx": {"ac_on_evade": 1, "counter_on_miss": 1, "dr_stat": 1, "ac_bonus": 1}}}},
	"Warp": {"seq": [2, 3, 4], "tiers": {
		2: {"desc": "Your hits warp armor — the target loses 1 AC until its next turn (stacks).",
			"fx": {"ac_debuff_on_hit": 1}},
		3: {"desc": "Hits strip 1 AC (stacking) and you attack at +1.",
			"fx": {"ac_debuff_on_hit": 1, "hit_bonus": 1}},
		4: {"desc": "Hits strip 2 AC (stacking), +1 to attack, and +3 damage against warped armor.",
			"fx": {"ac_debuff_on_hit": 2, "hit_bonus": 1, "dmg_bonus": 3}}}},
	"Grasp of the Titan": {"seq": [1, 2, 3], "tiers": {
		1: {"desc": "Your hits grapple — the target is restrained (−3 AC, cannot attack).",
			"fx": {"inflict_on_hit": "restrained"}},
		2: {"desc": "Hits restrain, and your crushing grip adds +2 damage.",
			"fx": {"inflict_on_hit": "restrained", "dmg_bonus": 2}},
		3: {"desc": "Hits restrain, +4 damage, and your grip strips 1 AC as well.",
			"fx": {"inflict_on_hit": "restrained", "dmg_bonus": 4, "ac_debuff_on_hit": 1}}}},
	"Assassin's Execution": {"seq": [1, 2, 3], "tiers": {
		1: {"desc": "Even a miss grazes for your attacking stat.", "fx": {"graze": 1}},
		2: {"desc": "Grazing misses, and any hit finishes a target left at 5 HP or less.",
			"fx": {"graze": 1, "execute_hp": 5}},
		3: {"desc": "Grazing misses, executions below 8 HP, and +1 to attack rolls.",
			"fx": {"graze": 1, "execute_hp": 8, "hit_bonus": 1}}}},
	# ── Phase 3 additions ────────────────────────────────────────────────
	"Wall of the Battered": {"seq": [1, 2, 3, 4, 5], "tiers": {
		1: {"desc": "Attacks against your allies suffer −2 to hit.", "fx": {"ward_ally": 2}},
		2: {"desc": "Allies attacked at −2; once per round you take a blow meant for an ally.",
			"fx": {"ward_ally": 2, "protect_ally": 1}},
		3: {"desc": "Allies attacked at −2, you intercept one blow per round, and the whole line gains +1 AC.",
			"fx": {"ward_ally": 2, "protect_ally": 1, "team_ac": 1}},
		4: {"desc": "As tier 3, plus you reduce all damage you take by 2.",
			"fx": {"ward_ally": 2, "protect_ally": 1, "team_ac": 1, "dr": 2}},
		5: {"desc": "Allies attacked at −3, you intercept a blow each round, the line gains +2 AC, and you reduce damage by 3.",
			"fx": {"ward_ally": 3, "protect_ally": 1, "team_ac": 2, "dr": 3}}}},
	"Tower Shield": {"seq": [1, 2, 3], "tiers": {
		1: {"desc": "Your shield grants +1 additional AC.", "fx": {"shield_bonus": 1}},
		2: {"desc": "Shield grants +1 more AC; once per round you take a blow meant for an ally.",
			"fx": {"shield_bonus": 1, "protect_ally": 1}},
		3: {"desc": "Shield grants +2 more AC, you intercept a blow each round, and allies are attacked at −2.",
			"fx": {"shield_bonus": 2, "protect_ally": 1, "ward_ally": 2}}}},
	"Magic Expertise": {"seq": [1, 2, 3], "tiers": {
		1: {"desc": "+1 to spell attack rolls and +1 to spell damage and healing.",
			"fx": {"spell_hit_bonus": 1, "spell_power": 1}},
		2: {"desc": "+2 to spell attacks, +2 to spell damage and healing.",
			"fx": {"spell_hit_bonus": 2, "spell_power": 2}},
		3: {"desc": "+2 to spell attacks, +3 to spell damage and healing.",
			"fx": {"spell_hit_bonus": 2, "spell_power": 3}}}},
	"Spell Shaper": {"seq": [1, 2, 3], "tiers": {
		1: {"desc": "+2 to spell attack rolls.", "fx": {"spell_hit_bonus": 2}},
		2: {"desc": "+3 to spell attacks, and one missed spell per round may be rerolled.",
			"fx": {"spell_hit_bonus": 3, "spell_reroll": 1}},
		3: {"desc": "+3 to spell attacks, a reroll each round, and your first spell each round cannot be resisted.",
			"fx": {"spell_hit_bonus": 3, "spell_reroll": 1, "spell_pierce": 1}}}},
	"Effect Shaper": {"seq": [1, 2, 3], "tiers": {
		1: {"desc": "Conditions you inflict are harder to shrug off (−2 to their ward).",
			"fx": {"cond_potency": 2}},
		2: {"desc": "−4 to ward against your conditions, and they last a turn longer.",
			"fx": {"cond_potency": 4, "cond_extend": 1}},
		3: {"desc": "−6 to ward, conditions last a turn longer, and your hits also slow.",
			"fx": {"cond_potency": 6, "cond_extend": 1, "inflict_on_hit": "slowed"}}}},
	# ── Phase 4 additions ────────────────────────────────────────────────
	"Twin Fang": {"seq": [1, 2, 3, 4, 5], "tiers": {
		1: {"desc": "Dual-wield: a second weapon equips to your off-hand and strikes alongside the first (costs 1 extra AP). Both hitting adds 1d4.",
			"fx": {"dual_wield": 1, "dual_bonus": 4}},
		2: {"desc": "Dual-wielding costs no extra AP. Both hitting adds 1d4.",
			"fx": {"dual_wield": 1, "dual_free": 1, "dual_bonus": 4}},
		3: {"desc": "Free dual-wielding, both-hit bonus 1d6, and +1 AC.",
			"fx": {"dual_wield": 1, "dual_free": 1, "dual_bonus": 6, "ac_bonus": 1}},
		4: {"desc": "Free dual-wielding, 1d6 flourish, +1 AC, and both blades landing knocks the target prone (restrained).",
			"fx": {"dual_wield": 1, "dual_free": 1, "dual_bonus": 6, "ac_bonus": 1,
				"inflict_on_hit": "restrained"}},
		5: {"desc": "Free dual-wielding, 1d8 flourish, +1 AC, restraining hits, and a kill refunds the action.",
			"fx": {"dual_wield": 1, "dual_free": 1, "dual_bonus": 8, "ac_bonus": 1,
				"inflict_on_hit": "restrained", "free_on_kill": 1}}}},
	"Improvised Weapon Mastery": {"seq": [1, 2, 3, 4, 5], "tiers": {
		1: {"desc": "Improvised fighting: unarmed and off-hand strikes deal 1d6.",
			"fx": {"unarmed_die": 6}},
		2: {"desc": "Improvised strikes deal 1d6 and grant +1 AC.",
			"fx": {"unarmed_die": 6, "ac_bonus": 1}},
		3: {"desc": "Improvised strikes deal 1d10, +1 AC, and crits hit harder (+2 damage).",
			"fx": {"unarmed_die": 10, "ac_bonus": 1, "dmg_bonus": 2}},
		4: {"desc": "1d10 strikes, +1 AC, +2 damage, and you may fight with two weapons.",
			"fx": {"unarmed_die": 10, "ac_bonus": 1, "dmg_bonus": 2,
				"dual_wield": 1, "dual_free": 1, "dual_bonus": 4}},
		5: {"desc": "1d10 strikes, +1 AC, +2 damage, free dual-wielding with a 1d6 flourish, and your hits disarm (slow).",
			"fx": {"unarmed_die": 10, "ac_bonus": 1, "dmg_bonus": 2,
				"dual_wield": 1, "dual_free": 1, "dual_bonus": 6,
				"inflict_on_hit": "slowed"}}}},
	"Linebreaker's Aim": {"seq": [1, 2, 3], "tiers": {
		1: {"desc": "+2 to attack rolls with ranged weapons.", "fx": {"ranged_hit_bonus": 2}},
		2: {"desc": "+3 to ranged attacks and +2 ranged damage.",
			"fx": {"ranged_hit_bonus": 3, "ranged_dmg_bonus": 2}},
		3: {"desc": "+4 to ranged attacks, +3 ranged damage, and your shots ignore the protection allies give one another.",
			"fx": {"ranged_hit_bonus": 4, "ranged_dmg_bonus": 3, "ignore_ward": 1}}}},
	"Grasp of the Forgotten": {"seq": [1, 2, 3], "tiers": {
		1: {"desc": "When this character enters play, a Spectral Hand (AC 10, HP = level) joins an empty slot.",
			"fx": {"summon_token": 1, "token_ac": 10, "token_hp_mult": 1}},
		2: {"desc": "Two Spectral Hands (AC 10, HP = level) join you on arrival.",
			"fx": {"summon_token": 2, "token_ac": 10, "token_hp_mult": 1}},
		3: {"desc": "A Spectral Servant (AC 13, HP = 2× level) joins you on arrival.",
			"fx": {"summon_token": 1, "token_ac": 13, "token_hp_mult": 2, "token_strong": 1}}}},
}

## Spell cards: sc = SP requirement (equip budget), dice + behaviour from
## _SPELL_DB. kind: damage / heal / buff / debuff. area>0 hits every enemy
## (or heals every ally) on the target's side.
const CARD_SPELLS := {
	"Littlest Healing":    {"sc": 2, "kind": "heal",   "dc": 2, "ds": 4, "atk": false, "area": 0, "conds": [], "desc": "Restore 2d4 HP to a friendly character."},
	"Healing Touch":       {"sc": 6, "kind": "heal",   "dc": 2, "ds": 8, "atk": false, "area": 0, "conds": [], "desc": "Restore 2d8 HP to a friendly character."},
	"Aura of Restoration": {"sc": 6, "kind": "heal",   "dc": 1, "ds": 6, "atk": false, "area": 1, "conds": [], "desc": "Heal ALL friendly characters for 1d6."},
	"Fireburst":           {"sc": 2, "kind": "damage", "dc": 1, "ds": 6, "atk": true,  "area": 1, "conds": [], "dt": "fire", "desc": "1d6 fire damage to ALL enemy characters."},
	"Searing Ray":         {"sc": 7, "kind": "damage", "dc": 2, "ds": 8, "atk": true,  "area": 0, "conds": [], "dt": "fire", "desc": "2d8 fire damage to one target."},
	"Lightning Bolt":      {"sc": 5, "kind": "damage", "dc": 3, "ds": 4, "atk": true,  "area": 0, "conds": [], "dt": "lightning", "desc": "3d4 lightning damage to one target."},
	"Frost Lance":         {"sc": 4, "kind": "damage", "dc": 2, "ds": 6, "atk": true,  "area": 0, "conds": ["slowed"], "dt": "cold", "desc": "2d6 cold damage; the target is slowed."},
	"Bless: Dodging":      {"sc": 2, "kind": "buff",   "dc": 0, "ds": 0, "atk": false, "area": 0, "conds": ["dodging"], "desc": "An ally gains +3 AC until your next turn."},
	"Arcane Force Field":  {"sc": 4, "kind": "buff",   "dc": 0, "ds": 0, "atk": false, "area": 0, "conds": ["shielded"], "desc": "An ally gains +2 AC for 2 rounds."},
	"Curse: Bleeding":     {"sc": 3, "kind": "debuff", "dc": 0, "ds": 0, "atk": true,  "area": 0, "conds": ["bleeding"], "desc": "Target bleeds for 1d4 each round."},
	"Curse: Stunned":      {"sc": 6, "kind": "debuff", "dc": 0, "ds": 0, "atk": true,  "area": 0, "conds": ["stunned"], "desc": "Target loses its actions next round."},
	"Curse: Frightened":   {"sc": 3, "kind": "debuff", "dc": 0, "ds": 0, "atk": true,  "area": 0, "conds": ["frightened"], "desc": "Target takes -2 to attack rolls."},
}

## Condition mechanics (durations in the owner's turns).
##   dodging: +3 AC   shielded: +2 AC   bleeding: 1d4/turn
##   stunned: no actions   slowed: -2 AC   frightened: -2 to hit
const COND_DURATION := {
	"dodging": 1, "shielded": 2, "bleeding": 3,
	"stunned": 1, "slowed": 2, "frightened": 2,
	"restrained": 1,      # grappled: −3 AC and unable to attack (may still cast)
}

## Damage types treated as "elemental" by wards and resistances.
const ELEMENTAL_TYPES := ["fire", "cold", "lightning", "arcane"]

# ══════════════════════════════════════════════════════════════════════════
#  Lineage traits — every character card carries its lineage's features as
#  REAL card effects. Hand-mapped entries below are grounded in the trait
#  text from the engine's _LINEAGE_DETAILS; every other lineage derives
#  traits from its name via TRAIT_KEYWORDS, so all 164 lineages work.
#
#  fx vocabulary (executed by the engine — see _merged_feat_fx and the
#  combat paths): hp_bonus, ap_bonus, sp_bonus, sp_per_level, ac_bonus,
#  hit_bonus, dmg_bonus, rage_dmg, crit_at, dr (damage reduction),
#  thorns, lifesteal, spell_power, regen, xp_bonus, heal_on_kill,
#  cheat_death, cond_immune (Array), inflict_on_hit (condition String).
# ══════════════════════════════════════════════════════════════════════════

const LINEAGE_TRAIT_OVERRIDES := {
	"Elf": [["Innate Magic", "+1 SP per level.", {"sp_per_level": 1}],
		["Keen Senses", "+1 to attack rolls.", {"hit_bonus": 1}]],
	"Watchling": [["Broadcast Eye", "+1 to attack rolls.", {"hit_bonus": 1}],
		["Static Surge", "+1 AP (overclocked actions).", {"ap_bonus": 1}]],
	"Regal Human": [["Versatile", "+2 XP per action.", {"xp_bonus": 2}],
		["Resilient Spirit", "Once per match, survives lethal damage at 1 HP.", {"cheat_death": 1}]],
	"Bouncian": [["Keen Hearing", "+1 to attack rolls.", {"hit_bonus": 1}],
		["Bounding Escape", "+1 AC.", {"ac_bonus": 1}]],
	"Ironhide": [["Iron Hide", "Reduces all incoming damage by 2.", {"dr": 2}]],
	"Goldscale": [["Gilded Scales", "+1 AC and reduces damage by 1.", {"ac_bonus": 1, "dr": 1}]],
	"Vulpin": [["Cunning Predator", "+1 to attack rolls, +1 XP per action.", {"hit_bonus": 1, "xp_bonus": 1}]],
	"Felinar": [["Nine Lives", "Once per match, survives lethal damage at 1 HP.", {"cheat_death": 1}]],
	"Canidar": [["Pack Tactics", "+1 to attack rolls and +1 damage.", {"hit_bonus": 1, "dmg_bonus": 1}]],
	"Cervin": [["Fleet Hooves", "+1 AP and +1 AC.", {"ap_bonus": 1, "ac_bonus": 1}]],
	"Quillari": [["Quill Volley", "Melee attackers take 2 damage.", {"thorns": 2}]],
	"Verdant": [["Regrowth", "Heals 1d4 at the start of your turn.", {"regen": 1}]],
	"Bramblekin": [["Thorned Body", "Melee attackers take 2 damage.", {"thorns": 2}]],
	"Thornwrought Human": [["Thornwrought", "Attackers take 1; damage reduced by 1.", {"thorns": 1, "dr": 1}]],
	"Myconid": [["Spore Body", "Immune to bleeding and frightened.", {"cond_immune": ["bleeding", "frightened"]}]],
	"Hearthkin": [["Hearthwarmth", "+2 HP and heals 1d4 each turn.", {"hp_bonus": 2, "regen": 1}]],
	"Fae-Touched Human": [["Fae Luck", "Crits on 19–20.", {"crit_at": 19}]],
	"Twilightkin": [["Dusk Veil", "+1 AC.", {"ac_bonus": 1}]],
	"Panoplian": [["Living Panoply", "+2 AC.", {"ac_bonus": 2}]],
	"Gilded Human": [["Gilded Fortune", "+2 XP per action.", {"xp_bonus": 2}]],
	"Arcanite Human": [["Arcane Blood", "+3 SP for spell budget.", {"sp_bonus": 3}]],
	"Voxilite": [["Resonant Mind", "+1 to spell damage and healing.", {"spell_power": 1}]],
	"Archivist": [["Deep Lore", "+2 XP per action, +1 SP.", {"xp_bonus": 2, "sp_bonus": 1}]],
	"Skysworn": [["Skyborne", "+1 AC and +1 to attack rolls.", {"ac_bonus": 1, "hit_bonus": 1}]],
	"Zephyrkin": [["Winddancer", "+1 AC and +1 AP.", {"ac_bonus": 1, "ap_bonus": 1}]],
	"Zephyrite": [["Storm Heart", "+1 damage and +1 AP.", {"dmg_bonus": 1, "ap_bonus": 1}]],
	"Cloudling": [["Cloudsoft", "+1 AC and reduces damage by 1.", {"ac_bonus": 1, "dr": 1}]],
	"Nimbari": [["Stormcaller", "+2 to spell damage and healing.", {"spell_power": 2}]],
	"Galesworn Human": [["Galestride", "+2 AP.", {"ap_bonus": 2}]],
	"Luminar Human": [["Lighttouched", "+1 to spell damage and healing.", {"spell_power": 1}]],
	"Lightbound": [["Radiant Soul", "+1 spell power; immune to frightened.", {"spell_power": 1, "cond_immune": ["frightened"]}]],
	"Auroran": [["Aurora Veil", "+1 AC and +2 SP.", {"ac_bonus": 1, "sp_bonus": 2}]],
	"Lanternborn": [["Guiding Light", "+1 spell power, +1 XP per action.", {"spell_power": 1, "xp_bonus": 1}]],
	"Candlites": [["Wax and Wick", "Heals 1d4 at the start of your turn.", {"regen": 1}]],
	"Glimmerfolk": [["Inner Gleam", "+2 SP and +1 AC.", {"sp_bonus": 2, "ac_bonus": 1}]],
	"Sparkforged Human": [["Volatile Core", "+1 spell power; attackers take 1.", {"spell_power": 1, "thorns": 1}]],
	"Runeborn Human": [["Living Runes", "+1 spell power and +2 SP.", {"spell_power": 1, "sp_bonus": 2}]],
	"Frostborn": [["Frozen Blood", "Damage reduced by 1; immune to slowed.", {"dr": 1, "cond_immune": ["slowed"]}],
		["Chilling Touch", "Weapon hits slow the target.", {"inflict_on_hit": "slowed"}]],
	"Glaceari": [["Glacial Patience", "Reduces all incoming damage by 2.", {"dr": 2}]],
	"Dustborn": [["Sandshield", "Damage reduced by 1; immune to bleeding.", {"dr": 1, "cond_immune": ["bleeding"]}]],
	"Jackal Human": [["Scavenger's Instinct", "+1 to hit; heals 3 on kills.", {"hit_bonus": 1, "heal_on_kill": 3}]],
	"Pangol": [["Layered Plates", "Reduces all incoming damage by 2.", {"dr": 2}]],
	"Venari": [["Hunter's Mark", "+1 to attack rolls and +1 damage.", {"hit_bonus": 1, "dmg_bonus": 1}]],
	"Graveleaps": [["Gravebound Leap", "+1 AC and +1 to attack rolls.", {"ac_bonus": 1, "hit_bonus": 1}]],
	"Aetherian": [["Phasing Form", "+2 AC.", {"ac_bonus": 2}]],
	"Lost": [["Temporal Echo", "+1 AC; once per match survives lethal damage.", {"ac_bonus": 1, "cheat_death": 1}]],
	"Moonkin": [["Moonlit Grace", "+1 AC and +1 spell power.", {"ac_bonus": 1, "spell_power": 1}]],
	"Mistborn Human": [["Veiled in Mist", "+2 AC.", {"ac_bonus": 2}]],
	"Grimshell": [["Hollow Armor", "Damage reduced by 2; immune to frightened.", {"dr": 2, "cond_immune": ["frightened"]}]],
	"Obsidian": [["Volcanic Glass", "Damage reduced by 2; attackers take 1.", {"dr": 2, "thorns": 1}]],
	"Ashenborn": [["Cursed Flame", "+1 damage, +2 more below half HP.", {"dmg_bonus": 1, "rage_dmg": 2}]],
	"Ashrot Human": [["Burned Wraith", "Damage reduced by 1; immune to bleeding.", {"dr": 1, "cond_immune": ["bleeding"]}]],
	"Blood Spawn": [["Bloodforged", "Weapon hits heal for half the damage.", {"lifesteal": 1}]],
	"Crimson Veil": [["Vampiric Allure", "Lifesteal on hits; +1 AC.", {"lifesteal": 1, "ac_bonus": 1}]],
	"Carrionari": [["Carrion Feast", "Weapon hits heal for half the damage.", {"lifesteal": 1}]],
	"Corrupted Wyrmblood": [["Wyrm Curse", "+1 damage; hits frighten the target.", {"dmg_bonus": 1, "inflict_on_hit": "frightened"}]],
	"Rotborn Herald": [["Plaguebearer", "Hits cause bleeding; immune to bleeding.", {"inflict_on_hit": "bleeding", "cond_immune": ["bleeding"]}]],
	"Scourling Human": [["Infernal Brand", "+1 damage, +2 more below half HP.", {"dmg_bonus": 1, "rage_dmg": 2}]],
	"Disjointed Hounds": [["Impossible Angles", "+1 AC; hits frighten the target.", {"ac_bonus": 1, "inflict_on_hit": "frightened"}]],
	"Driftwood Woken": [["Waterlogged Timber", "Damage reduced by 1; heals 1d4 each turn.", {"dr": 1, "regen": 1}]],
}

## Name-fragment fallbacks — first two matches become the lineage's traits.
## Ordered specific → generic; "human"/"elf" close the list as catch-alls.
const TRAIT_KEYWORDS := [
	["frost,glace,boreal,winter,snow,chill", "Frozen Blood", "Damage reduced by 1; immune to slowed.", {"dr": 1, "cond_immune": ["slowed"]}],
	["blood,vampir,crimson,sanguin", "Lifedrinker", "Weapon hits heal for half the damage.", {"lifesteal": 1}],
	["iron,stone,crag,granite,shell,hide,plate,scale,obsidian,lith,ferr,beetle", "Stoneskin", "Reduces all incoming damage by 1.", {"dr": 1}],
	["shadow,dusk,gloam,gloom,umbra,night,dark,sable,skulk,mist", "Shadowmeld", "+1 AC.", {"ac_bonus": 1}],
	["flame,ember,ash,cinder,pyre,scorch,burn,kindle,volcan", "Emberheart", "+1 damage on weapon attacks.", {"dmg_bonus": 1}],
	["sky,wind,gale,zephyr,cloud,wing,storm,duck", "Windborne", "+1 AC.", {"ac_bonus": 1}],
	["light,lumin,auror,candle,lantern,dawn,sol,seraph,myrrh", "Radiant Soul", "+1 to spell damage and healing.", {"spell_power": 1}],
	["void,abyss,whisper,hollow,wraith,null,nihil,parallax", "Voidtouched", "Weapon hits frighten the target.", {"inflict_on_hit": "frightened"}],
	["rot,plague,bile,blight,carrion,grave,crypt,bone,tomb,grav,filth,dreg", "Plaguebearer", "Weapon hits cause bleeding.", {"inflict_on_hit": "bleeding"}],
	["gear,vox,chrono,spark,forge,construct,mech,brass,husk,drone,rust", "Construct Frame", "Immune to bleeding; damage reduced by 1.", {"cond_immune": ["bleeding"], "dr": 1}],
	["fae,fey,dream,moon,star,astral,aether,greml,grob,imp", "Fae Luck", "Crits on 19–20.", {"crit_at": 19}],
	["thorn,bramble,quill,spike,barb", "Thorned Body", "Melee attackers take 1 damage.", {"thorns": 1}],
	["drak,wyrm,serpent,saur,viper,hydra,hatch", "Draconic Blood", "+1 damage on weapon attacks.", {"dmg_bonus": 1}],
	["echo,pulse,threnody,reson,converge,prism,choir,song", "Resonant Mind", "+1 to spell damage and healing.", {"spell_power": 1}],
	["hag,hex,witch,crone,marion,curse", "Hexweaver", "+1 to spell damage and healing.", {"spell_power": 1}],
	["glass,porcel,shard,mirror", "Shardskin", "Melee attackers take 1 damage.", {"thorns": 1}],
	["root,moss,verdan,leaf,vine,bloom,life,kettle", "Regrowth", "Heals 1d4 at the start of your turn.", {"regen": 1}],
	["bog,mire,fen,marsh,ooze,sludge,tide,fathom,trench,brine,snare,choke", "Slick Form", "+1 AC; immune to bleeding.", {"ac_bonus": 1, "cond_immune": ["bleeding"]}],
	["book,lore,scribe,bespoke,tinker", "Bookish", "+2 XP per action.", {"xp_bonus": 2}],
	["brain,gullet,flen,wretch,ghoul,eater,mime", "Unsettling", "Weapon hits frighten the target.", {"inflict_on_hit": "frightened"}],
	["hunt,jackal,wolf,fang,claw,felin,canid,corv,predator,ursa,taur,simian", "Predator Instinct", "+1 to attack rolls.", {"hit_bonus": 1}],
	["elf,elv", "Innate Magic", "+1 SP per level.", {"sp_per_level": 1}],
	["human", "Versatile", "+1 XP per action.", {"xp_bonus": 1}],
]

var _trait_cache: Dictionary = {}   # lineage -> Array of trait dicts

## The working traits for a lineage: hand-mapped first, name-derived
## otherwise, "Hardy" (+2 HP) as the universal floor.
## ALWAYS returns a deep copy — cards mutate their own trait list (Whetstone
## and friends append to it), and sharing the cached Array would leak those
## permanent buffs to every other card of the same lineage.
func get_lineage_traits(lineage: String) -> Array:
	if _trait_cache.has(lineage):
		return (_trait_cache[lineage] as Array).duplicate(true)
	var out: Array = []
	if LINEAGE_TRAIT_OVERRIDES.has(lineage):
		for t in LINEAGE_TRAIT_OVERRIDES[lineage]:
			out.append({"name": str(t[0]), "desc": str(t[1]), "fx": (t[2] as Dictionary).duplicate(true)})
	else:
		var low: String = lineage.to_lower()
		for row in TRAIT_KEYWORDS:
			if out.size() >= 2:
				break
			for frag in str(row[0]).split(","):
				if low.contains(frag):
					out.append({"name": str(row[1]), "desc": str(row[2]), "fx": (row[3] as Dictionary).duplicate(true)})
					break
	if out.is_empty():
		out.append({"name": "Hardy", "desc": "+2 HP.", "fx": {"hp_bonus": 2}})
	_trait_cache[lineage] = out
	return out.duplicate(true)

## Fantasy given-names for generated character cards.
const CHAR_NAMES := [
	# Classic given names
	"Aldric", "Brenna", "Caspian", "Doreth", "Elowen", "Fenwick", "Garrick",
	"Halia", "Isolde", "Joren", "Kestrel", "Lysandra", "Maelis", "Nyra",
	"Orin", "Perrin", "Quill", "Ravena", "Soren", "Talia", "Ulric", "Vesper",
	"Wren", "Xanthe", "Yorick", "Zephyra",
	"Alden", "Bryn", "Cassia", "Dorian", "Edra", "Faelan", "Gwyneth",
	"Hadrian", "Imara", "Jarek", "Kaelith", "Lorcan", "Mireya", "Nolwen",
	"Ondrel", "Pyria", "Quenna", "Rhogar", "Selvis", "Thessa", "Ulyra",
	"Varen", "Wyla", "Xerath", "Ysolde", "Zarek",
	"Aurelis", "Bastion", "Corvane", "Delwyn", "Esryn", "Fyodra", "Gaelen",
	"Hesper", "Ilvara", "Jessamin", "Kaldrin", "Liraen", "Morvath", "Neris",
	"Oswin", "Phaedra", "Rowan", "Sablen", "Torvald", "Ulmira", "Veyra",
	# Elemental / evocative epithet-names
	"Bramble", "Cinder", "Dusk", "Ember", "Frost", "Gale", "Hollow", "Iris",
	"Juniper", "Krag", "Lantern", "Marrow", "Nettle", "Onyx", "Pyre",
	"Quarry", "Rime", "Slate", "Thistle", "Umbra", "Vellum", "Willow",
	"Ashen", "Bellow", "Cairn", "Drift", "Everdusk", "Flint", "Glimmer",
	"Harrow", "Ingot", "Jetsam", "Kindle", "Loam", "Mistral", "Nocturne",
	"Ochre", "Prism", "Quiver", "Ridge", "Solace", "Tinder", "Verdigris",
	"Wisp", "Yarrow", "Zenith",
]

# ══════════════════════════════════════════════════════════════════════════
#  Match state
# ══════════════════════════════════════════════════════════════════════════

var match_active: bool = false
var round_num: int = 0
var num_players: int = 2        # 2–4 seats this match
var turn: int = 0               # active seat (0 .. num_players-1)
var winner: int = -1            # -1 until decided
var match_log: Array = []       # strings for the UI log panel

## players[i] = {
##   name: String, hp: int, max_hp: int, energy: int, region: String,
##   deck: Array (card dicts, face down), hand: Array, slots: Array (6, null or character card),
##   graveyard: Array }
var players: Array = []

var _next_card_id: int = 1
var _rng := RandomNumberGenerator.new()

# ── AI opponents (any seat except 0 may be an AI — set via start_match) ──
const AI_ACTION_DELAY := 0.8      # seconds between visible AI actions
var ai_enabled: bool = false      # true when at least one seat is an AI
var ai_seats: Dictionary = {}     # seat index -> true for AI-controlled seats
var _ai_running: bool = false

## Difficulty knobs. "hard" is the full brain; easier tiers make worse
## choices rather than cheating in reverse (no stat handicaps):
##   random_play    chance to play a random character instead of the best
##   random_target  chance to attack a random enemy instead of kill-securing
##   equip_skip     chance per energy step to not bother gearing up
##   cast_chance    chance per action that spells are even considered
##   heal_below     ally HP ratio that triggers healing (lower = reacts late)
##   dig            pays energy for extra draws when out of plays
##   lethal_face    checks for lethal direct damage on the enemy player
##   stop_chance    chance a character just stops acting with AP left
##   smart_discard  discards by value; otherwise randomly
const AI_DIFFICULTY := {
	"easy": {
		"random_play": 1.0, "random_target": 1.0, "equip_skip": 0.5,
		"cast_chance": 0.4, "heal_below": 0.30, "dig": false,
		"lethal_face": false, "stop_chance": 0.4, "smart_discard": false,
	},
	"medium": {
		"random_play": 0.4, "random_target": 0.4, "equip_skip": 0.0,
		"cast_chance": 1.0, "heal_below": 0.45, "dig": false,
		"lethal_face": false, "stop_chance": 0.2, "smart_discard": true,
	},
	"hard": {
		"random_play": 0.0, "random_target": 0.0, "equip_skip": 0.0,
		"cast_chance": 1.0, "heal_below": 0.65, "dig": true,
		"lethal_face": true, "stop_chance": 0.0, "smart_discard": true,
	},
}
var ai_difficulty: String = "hard"

func _ai_cfg() -> Dictionary:
	return AI_DIFFICULTY.get(ai_difficulty, AI_DIFFICULTY["hard"])

# ── Gauntlet mode (endless AI challengers; seat 0 is the lone human) ─────
var spectator: bool = false        # every seat is an AI — the player watches

# ── Conquest campaign: one battle per region, deck carried between them ──
var conquest: bool = false         # a conquest run is under way
var conquest_index: int = 0        # how many regions have been conquered
var conquest_order: Array = []     # region ids, in the order they're fought
var conquest_deck: Array = []      # the player's persistent deck (survives battles)
var conquest_seats: int = 2        # 2 = 1v1, 3 = 1v1v1, 4 = 1v1v1v1
var conquest_name: String = "Player 1"
var gauntlet: bool = false
var gauntlet_kills: int = 0        # enemies defeated this run
var gauntlet_wave: int = 0         # replacements spawned (drives scaling)
var respawn_due: Dictionary = {}   # seat -> round_num when a new AI arrives

# ══════════════════════════════════════════════════════════════════════════
#  Region + pool generation (deck-building phase)
# ══════════════════════════════════════════════════════════════════════════

## Regions for deck building — the 10 Conquest regions, each pooling the
## lineages native to its lore subregions.
func get_regions() -> Array:
	var out: Array = []
	for rid in BattleSystem.REGION_CONFIG:
		var cfg: Dictionary = BattleSystem.REGION_CONFIG[rid]
		out.append({
			"id": str(rid),
			"name": str(cfg.get("name", rid)),
			"lineages": _region_lineages(str(rid)),
		})
	return out

## All lineages native to a Conquest region (union of its subregions).
func _region_lineages(region_id: String) -> Array:
	var cfg: Dictionary = BattleSystem.REGION_CONFIG.get(region_id, {})
	var subs: Array = cfg.get("subregions", [])
	var found: Array = []
	var e = RimvaleAPI.engine
	if e != null and e.has_method("get_lineages_for_region"):
		for sub in subs:
			for lin in e.get_lineages_for_region(str(sub)):
				if not found.has(lin):
					found.append(lin)
	if found.is_empty():
		found = ["Regal Human", "Elf", "Vulpin", "Ironhide"]   # safe fallback
	return found

## Generate a card pool for one player from a region. The player then picks
## DECK_SIZE cards from this pool (plus any custom spell cards they build).
func generate_pool(region_id: String, rng_seed: int = -1) -> Array:
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	var pool: Array = []
	var lineages: Array = _region_lineages(region_id)
	var region_name: String = str(BattleSystem.REGION_CONFIG.get(region_id, {}).get("name", region_id))
	# A ~72-card pool for a 60-card deck — enough slack to fine-tune the
	# build. 21 characters, 12 weapons, 7 armor, 4 shields, 12 feats,
	# 16 spells (feats/spells can repeat once the unique lists run out).
	for i in range(21):
		var lin: String = str(lineages[_rng.randi() % lineages.size()])
		pool.append(_make_character_card(lin, region_name))
	var wnames: Array = CARD_WEAPONS.keys()
	for i in range(12):
		pool.append(_make_equipment_card("weapon", str(wnames[_rng.randi() % wnames.size()])))
	var anames: Array = CARD_ARMOR.keys()
	for i in range(7):
		pool.append(_make_equipment_card("armor", str(anames[_rng.randi() % anames.size()])))
	var snames: Array = CARD_SHIELDS.keys()
	for i in range(4):
		pool.append(_make_equipment_card("shield", str(snames[_rng.randi() % snames.size()])))
	var fnames: Array = CARD_FEATS.keys()
	fnames.shuffle()
	for i in range(12):
		pool.append(_make_feat_card(str(fnames[i % fnames.size()])))
	var spnames: Array = CARD_SPELLS.keys()
	spnames.shuffle()
	for i in range(16):
		pool.append(_make_spell_card(str(spnames[i % spnames.size()])))
	return pool

func _make_character_card(lineage: String, region: String) -> Dictionary:
	# 6 stat points sprinkled across [STR, SPD, INT, VIT, DIV] (PHB start).
	var stats: Array = [0, 0, 0, 0, 0]
	for i in range(6):
		stats[_rng.randi() % 5] += 1
	var card: Dictionary = {
		"id": _new_id(), "ctype": "character",
		"name": str(CHAR_NAMES[_rng.randi() % CHAR_NAMES.size()]),
		"lineage": lineage, "region": region,
		"level": 1, "xp": 0, "xp_req": 10,
		"stats": stats,           # [STR, SPD, INT, VIT, DIV]
		"weapon": null, "offhand": null, "armor": null, "shield": null,
		"feats": [], "spells": [],
		"traits": get_lineage_traits(lineage),   # working lineage features
		"conds": {},              # condition -> turns left
		"spell_used": {},         # spell name -> true (this round)
		"acts": 0,                # actions taken this round (drives AP costs)
		"stat_mode": "manual",    # "manual" banks level points for the player; "auto" spends them
		"stat_pts": 0,            # banked attribute points awaiting assignment
		"kills": 0,
	}
	_recalc_character(card, true)
	return card

const GEAR_MAX_PLUS := 3        # enchantment ceiling: +1, +2, +3

func _make_equipment_card(slot: String, item_name: String) -> Dictionary:
	var card: Dictionary = {
		"id": _new_id(), "ctype": "equipment", "slot": slot, "name": item_name,
		"plus": 0,     # duplicates of the same item forge it up to GEAR_MAX_PLUS
	}
	match slot:
		"weapon":
			var w: Dictionary = CARD_WEAPONS[item_name]
			card["dc"] = int(w["dc"]); card["ds"] = int(w["ds"])
			card["finesse"] = bool(w["finesse"]); card["dt"] = str(w["dt"])
			card["ranged"] = bool(w.get("ranged", false))
			card["desc"] = "%dd%d %s damage.%s%s" % [card["dc"], card["ds"], card["dt"],
				" Finesse (uses SPD)." if card["finesse"] else "",
				" Ranged." if card["ranged"] else ""]
		"armor":
			var a: Dictionary = CARD_ARMOR[item_name]
			card["ac"] = int(a["ac"]); card["spd_cap"] = int(a["spd_cap"])
			var w_class: String = "Light" if int(a["spd_cap"]) < 0 else ("Medium" if int(a["spd_cap"]) > 0 else "Heavy")
			card["desc"] = "AC %d. %s armor." % [card["ac"], w_class]
		"shield":
			var s: Dictionary = CARD_SHIELDS[item_name]
			card["ac"] = int(s["ac"])
			card["desc"] = "+%d AC." % card["ac"]
	return card

func _make_feat_card(feat_name: String) -> Dictionary:
	var f: Dictionary = CARD_FEATS[feat_name]
	var first: int = int((f["seq"] as Array)[0])
	var t: Dictionary = (f["tiers"] as Dictionary)[first]
	return {
		"id": _new_id(), "ctype": "feat", "name": feat_name,
		"tier": first, "fx": (t["fx"] as Dictionary).duplicate(true),
		"desc": "T%d — %s (costs %d feat pts)" % [first, str(t["desc"]), first],
	}

## The tier a feat steps up to from `tier`, or -1 when it is already maxed.
func next_feat_tier(feat_name: String, tier: int) -> int:
	if not CARD_FEATS.has(feat_name):
		return -1
	var seq: Array = CARD_FEATS[feat_name]["seq"]
	var i: int = seq.find(tier)
	if i < 0 or i + 1 >= seq.size():
		return -1
	return int(seq[i + 1])

func _make_spell_card(spell_name: String) -> Dictionary:
	var s: Dictionary = CARD_SPELLS[spell_name]
	return {
		"id": _new_id(), "ctype": "spell", "name": spell_name,
		"sc": int(s["sc"]), "kind": str(s["kind"]),
		"dc": int(s["dc"]), "ds": int(s["ds"]), "atk": bool(s["atk"]),
		"area": int(s["area"]), "conds": s.get("conds", []).duplicate(),
		"dt": str(s.get("dt", "")), "custom": false,
		"desc": "%s (needs %d SP)" % [str(s["desc"]), int(s["sc"])],
	}

## Custom spell card builder. SP cost derives from power so the equip budget
## stays meaningful. Returns the card, or {} with an "err" key on bad input.
func make_custom_spell_card(spell_name: String, kind: String, dc: int, ds: int,
		area: int, conds: Array) -> Dictionary:
	if spell_name.strip_edges() == "":
		return {"err": "Enter a spell name."}
	if spell_name.length() > 24:
		return {"err": "Name too long (max 24 chars)."}
	if kind not in ["damage", "heal", "buff", "debuff"]:
		return {"err": "Invalid spell kind."}
	dc = clampi(dc, 1, 4)
	ds = clampi(ds, 4, 12)
	area = clampi(area, 0, 1)
	for c in conds:
		if not COND_DURATION.has(str(c)):
			return {"err": "Unknown condition: %s" % str(c)}
	var sc: int = custom_spell_sp(kind, dc, ds, area, conds.size())
	var desc: String = ""
	match kind:
		"damage": desc = "%dd%d damage%s." % [dc, ds, " to ALL enemies" if area > 0 else ""]
		"heal":   desc = "Restore %dd%d HP%s." % [dc, ds, " to ALL allies" if area > 0 else ""]
		"buff":   desc = "Grant %s to an ally." % ", ".join(PackedStringArray(conds))
		"debuff": desc = "Inflict %s on an enemy." % ", ".join(PackedStringArray(conds))
	if not conds.is_empty() and (kind == "damage" or kind == "heal"):
		desc += " Applies %s." % ", ".join(PackedStringArray(conds))
	return {
		"id": _new_id(), "ctype": "spell", "name": spell_name.strip_edges(),
		"sc": sc, "kind": kind, "dc": dc, "ds": ds,
		"atk": kind == "damage" or kind == "debuff",
		"area": area, "conds": conds.duplicate(), "dt": "arcane", "custom": true,
		"desc": "✦ %s (needs %d SP)" % [desc, sc],
	}

## SP requirement for a custom spell (preview for the builder UI).
func custom_spell_sp(kind: String, dc: int, ds: int, area: int, num_conds: int) -> int:
	var sc: int = int(ceil(float(clampi(dc, 1, 4) * clampi(ds, 4, 12)) / 4.0))
	if kind == "buff" or kind == "debuff":
		sc = 1
	sc += clampi(area, 0, 1) * 2 + num_conds * 2
	return maxi(1, sc)

func _new_id() -> String:
	_next_card_id += 1
	return "card_%d" % _next_card_id

# ══════════════════════════════════════════════════════════════════════════
#  Character math (PHB formulas + feat card effects)
# ══════════════════════════════════════════════════════════════════════════

## Recompute a character card's derived pools from stats/level/gear/feats.
## full_restore=true sets hp/ap to max (creation & level-up growth heals).
func _recalc_character(card: Dictionary, full_restore: bool = false) -> void:
	var stats: Array = card["stats"]
	var lv: int = int(card["level"])
	var fx: Dictionary = _merged_feat_fx(card)
	var vit_m: int = int(fx.get("hp_vit_mult", 1))
	var str_m: int = int(fx.get("ap_str_mult", 1))
	var div_m: int = int(fx.get("sp_div_mult", 1))
	# PHB: HP = 3 + 3*level + VIT; AP = 3 + STR; SP = 3 + level + DIV —
	# plus flat/per-level bonuses from lineage traits and feat cards
	# (Elf's Innate Magic is the sp_per_level trait, no special case).
	var new_max_hp: int = maxi(1, 3 + 3 * lv + vit_m * int(stats[3])
		+ int(fx.get("hp_bonus", 0)) + int(card.get("bonus_hp", 0)))
	# ap_stat_bonus (Martial Focus T3+) grants bonus AP equal to STR.
	var new_max_ap: int = maxi(1, 3 + str_m * int(stats[0]) + int(fx.get("ap_bonus", 0))
		+ int(fx.get("ap_stat_bonus", 0)) * int(stats[0]))
	var new_max_sp: int = maxi(1, 3 + lv + div_m * int(stats[4])
		+ int(fx.get("sp_bonus", 0)) + int(fx.get("sp_per_level", 0)) * lv)
	var old_max_hp: int = int(card.get("max_hp", new_max_hp))
	card["max_hp"] = new_max_hp
	card["max_ap"] = new_max_ap
	card["max_sp"] = new_max_sp
	if full_restore:
		card["hp"] = new_max_hp
		card["ap"] = new_max_ap
	else:
		# Growth heals by the delta; damage carries over.
		card["hp"] = clampi(int(card.get("hp", new_max_hp)) + maxi(0, new_max_hp - old_max_hp), 1, new_max_hp)
		card["ap"] = mini(int(card.get("ap", 0)), new_max_ap)
	card["ac"] = _compute_card_ac(card, fx)

## AC per the engine's _armor_ac_with_speed: light = full SPD, medium = SPD
## capped at 2, heavy = none, unarmored = 10 + SPD. Shields add flat AC.
func _compute_card_ac(card: Dictionary, fx: Dictionary) -> int:
	var spd: int = int(card["stats"][1])
	var ac: int
	var light_or_none: bool = true
	var armor = card.get("armor")
	if armor == null:
		# Unarmored Master: AC is 10 + N×SPD.
		ac = 10 + spd * maxi(1, int(fx.get("ac_unarmored_spd_mult", 1)))
	else:
		var spd_cap: int = int(armor.get("spd_cap", 0))
		light_or_none = spd_cap < 0
		if spd_cap < 0:
			ac = int(armor["ac"]) + spd
		elif spd_cap > 0:
			# Balanced Bulwark T3+: medium armor uses full STR or SPD.
			if int(fx.get("ac_medium_stat", 0)) > 0:
				ac = int(armor["ac"]) + maxi(int(stats_of(card)[0]), spd)
			else:
				ac = int(armor["ac"]) + mini(spd, spd_cap)
			ac += int(fx.get("ac_medium_bonus", 0))
		else:
			ac = int(armor["ac"]) + int(fx.get("ac_heavy_bonus", 0))
			# Titanic Bastion T2+: heavy armor adds STR.
			ac += int(fx.get("ac_heavy_str", 0)) * int(stats_of(card)[0])
		ac += int(armor.get("plus", 0))        # enchanted plate
	var shield = card.get("shield")
	if shield != null:
		ac += int(shield["ac"]) + int(fx.get("shield_bonus", 0)) + int(shield.get("plus", 0))
	ac += int(fx.get("ac_bonus", 0))
	if light_or_none:
		ac += int(fx.get("ac_light_bonus", 0))
		# Evasive Ward T3: count SPD toward AC a second time.
		ac += int(fx.get("ac_light_spd", 0)) * spd
	# Unyielding Defender T2+: extra AC while bloodied (below a third).
	if int(fx.get("low_hp_ac", 0)) > 0 \
			and int(card.get("hp", 1)) * 3 <= int(card.get("max_hp", 1)):
		ac += int(fx["low_hp_ac"])
	# Iron Thorn's punctures strip AC until the victim's next turn.
	ac -= int(card.get("ac_penalty", 0))
	ac += int(card.get("bonus_ac", 0))   # debug editor / future permanent AC
	return maxi(1, ac)

## The card's attribute array (kept as a helper so AC math reads cleanly).
func stats_of(card: Dictionary) -> Array:
	return card.get("stats", [0, 0, 0, 0, 0])

## Merge equipped feat cards' AND lineage traits' effect dicts.
## Numeric values sum; crit_at takes the best (lowest); *_mult takes max;
## cond_immune unions; inflict_on_hit keeps the first.
func _merged_feat_fx(card: Dictionary) -> Dictionary:
	var fx: Dictionary = {}
	var sources: Array = []
	for fc in card.get("feats", []):
		sources.append(fc.get("fx", {}))
	for tr in card.get("traits", []):
		sources.append(tr.get("fx", {}))
	for src in sources:
		for k in src:
			if k == "cond_immune":
				var merged: Array = fx.get(k, [])
				for cond in src[k]:
					if not merged.has(cond):
						merged.append(cond)
				fx[k] = merged
				continue
			if k == "inflict_on_hit":
				if not fx.has(k):
					fx[k] = str(src[k])
				continue
			if k == "weapon_die_by_type":
				# Dictionary-valued: {damage type -> minimum die}. Merge per
				# type keeping the largest die. Must be handled BEFORE the
				# int() cast below, which would flatten it to 0 and silently
				# disable Crimson Edge / Iron Hammer / Iron Thorn.
				var dies: Dictionary = fx.get(k, {})
				for dt_key in src[k]:
					dies[dt_key] = maxi(int(dies.get(dt_key, 0)), int(src[k][dt_key]))
				fx[k] = dies
				continue
			var v: int = int(src[k])
			if k == "crit_at":
				fx[k] = mini(int(fx.get(k, 20)), v)      # lower threshold = better
			elif k.ends_with("_mult"):
				fx[k] = maxi(int(fx.get(k, 0)), v) if fx.has(k) else v
			else:
				fx[k] = int(fx.get(k, 0)) + v
	return fx

## Feat-point budget (PHB): 6 at level 1, +4 per level after.
func feat_budget(card: Dictionary) -> int:
	return 6 + (int(card["level"]) - 1) * 4

func feat_points_used(card: Dictionary) -> int:
	var used: int = 0
	for fc in card.get("feats", []):
		used += int(fc["tier"])
	return used

func spell_sp_used(card: Dictionary) -> int:
	var used: int = 0
	for sp in card.get("spells", []):
		used += int(sp["sc"])
	return used

## To-hit modifier for the card's weapon attacks (surfaced in the UI):
## STR — or SPD for finesse weapons — plus trait/feat bonuses, −2 frightened.
func attack_mod(card: Dictionary) -> int:
	var fx: Dictionary = _merged_feat_fx(card)
	var weapon = card.get("weapon")
	var finesse: bool = weapon != null and bool(weapon.get("finesse", false))
	var mod: int = int(card["stats"][1]) if finesse else int(card["stats"][0])
	mod += int(fx.get("hit_bonus", 0))
	if weapon != null:
		mod += int(weapon.get("plus", 0))   # enchanted weapons aim truer
		if bool(weapon.get("ranged", false)):
			mod += int(fx.get("ranged_hit_bonus", 0))
	if (card.get("conds", {}) as Dictionary).has("frightened"):
		mod -= 2
	return mod

## True when `spell_name` has been cast as many times this round as the
## card is allowed (once, or twice with Arcane Wellspring T5).
func spell_exhausted(card: Dictionary, spell_name: String) -> bool:
	var allowed: int = 1 + int(_merged_feat_fx(card).get("spell_recast", 0))
	return int((card.get("spell_used", {}) as Dictionary).get(spell_name, 0)) >= allowed

## To-hit modifier for the card's attack spells: DIV guides spell aim, plus
## Magic Expertise / Spell Shaper's focus.
func spell_mod(card: Dictionary) -> int:
	return int(card["stats"][4]) + int(_merged_feat_fx(card).get("spell_hit_bonus", 0))

## AP price of this card's NEXT action this round: 1 for the first,
## +1 for each action already taken (attacks and casts share the count).
func action_cost(card: Dictionary) -> int:
	return 1 + int(card.get("acts", 0))

## True while the character can still afford another action this turn.
func can_act(card: Dictionary) -> bool:
	return int(card.get("ap", 0)) >= action_cost(card)

# ══════════════════════════════════════════════════════════════════════════
#  Match lifecycle
# ══════════════════════════════════════════════════════════════════════════

## Begin a match. `configs` is an Array of 2–4 player configs, each a
## Dictionary: {name: String, region: String, deck: Array, ai: bool}.
## Seat order = array order; seat 0 plays first (and should be human).
func start_match(configs: Array, ai_diff: String = "hard", gauntlet_mode: bool = false) -> String:
	if configs.size() < 2 or configs.size() > 4:
		return "2 to 4 players required."
	for cfg_v in configs:
		var chars: int = 0
		for c in (cfg_v as Dictionary).get("deck", []):
			if str(c.get("ctype", "")) == "character":
				chars += 1
		if chars < MIN_CHARACTERS:
			return "Each deck needs at least %d character cards." % MIN_CHARACTERS
	_rng.randomize()
	players = []
	num_players = configs.size()
	ai_seats = {}
	for seat in range(configs.size()):
		var cfg: Dictionary = configs[seat]
		if bool(cfg.get("ai", false)):
			ai_seats[seat] = true
		var deck: Array = (cfg.get("deck", []) as Array).duplicate()
		deck.shuffle()
		var hand: Array = []
		for i in range(mini(HAND_START, deck.size())):
			hand.append(deck.pop_back())
		var slots: Array = []
		slots.resize(MAX_SLOTS)   # all null
		players.append({
			"name": str(cfg.get("name", "Player %d" % (seat + 1))),
			"region": str(cfg.get("region", "")),
			"hp": PLAYER_HP, "max_hp": PLAYER_HP, "energy": 0,
			"deck": deck, "hand": hand, "slots": slots, "graveyard": [],
		})
	match_active = true
	round_num = 0
	turn = 0
	winner = -1
	match_log = []
	ai_enabled = not ai_seats.is_empty()
	ai_difficulty = ai_diff if AI_DIFFICULTY.has(ai_diff) else "hard"
	_ai_running = false
	# Spectator: every seat is an AI, so nobody is waiting on input.
	spectator = ai_seats.size() >= num_players
	gauntlet = gauntlet_mode and ai_enabled
	gauntlet_kills = 0
	gauntlet_wave = 0
	respawn_due = {}
	if gauntlet:
		_log("🌊 GAUNTLET RUN — hold the line. Fallen enemies are replaced in 2 rounds.")
	_begin_round()
	_begin_turn()
	return ""

func end_match() -> void:
	match_active = false
	ai_enabled = false
	ai_seats = {}
	_ai_running = false
	spectator = false
	gauntlet = false
	gauntlet_kills = 0
	gauntlet_wave = 0
	respawn_due = {}
	players = []
	match_log = []

## True when `seat` is controlled by the computer.
func is_ai_seat(seat: int) -> bool:
	return ai_seats.has(seat)

## True while an AI is (or should be) playing out its visible turn.
func is_ai_turn() -> bool:
	return match_active and is_ai_seat(turn) and winner < 0

## Living opponents of `seat`, in turn order after them.
func living_opponents(seat: int) -> Array:
	var out: Array = []
	for i in range(1, num_players):
		var o: int = (seat + i) % num_players
		if int(players[o]["hp"]) > 0:
			out.append(o)
	return out

func _begin_round() -> void:
	round_num += 1
	_process_respawns()   # gauntlet challengers arrive before energy is dealt
	var energy: int = mini(round_num, ENERGY_CAP)
	for p in players:
		p["energy"] = energy
	_log("— Round %d — each player gains %d energy." % [round_num, energy])
	card_event.emit("round", {"round": round_num, "energy": energy})

## Gauntlet: spawn replacement challengers whose arrival round has come.
## Each gets a fresh region deck, pre-leveled by the wave count, full HP.
func _process_respawns() -> void:
	if not gauntlet:
		return
	for seat_v in respawn_due.keys():
		var seat: int = int(seat_v)
		if round_num < int(respawn_due[seat_v]):
			continue
		respawn_due.erase(seat_v)
		gauntlet_wave += 1
		# The gauntlet sharpens: difficulty climbs at waves 4 and 8.
		if gauntlet_wave == 4 and ai_difficulty == "easy":
			ai_difficulty = "medium"
			_log("🌊 The gauntlet sharpens — enemies fight harder now.")
		elif gauntlet_wave == 8 and ai_difficulty != "hard":
			ai_difficulty = "hard"
			_log("🌊 The gauntlet sharpens — enemies fight harder now.")
		var rids: Array = []
		for r in get_regions():
			rids.append(str(r["id"]))
		var rid: String = str(rids[_rng.randi() % rids.size()]) if not rids.is_empty() else ""
		var deck: Array = build_ai_deck(rid)
		_gauntlet_scale_deck(deck)
		deck.shuffle()
		var hand: Array = []
		for i in range(mini(HAND_START, deck.size())):
			hand.append(deck.pop_back())
		var slots: Array = []
		slots.resize(MAX_SLOTS)
		var cname: String = "🤖 Challenger %d (%s)" % [
			num_players - 1 + gauntlet_wave, ai_difficulty.capitalize()]
		players[seat] = {
			"name": cname, "region": rid,
			"hp": PLAYER_HP, "max_hp": PLAYER_HP, "energy": 0,
			"deck": deck, "hand": hand, "slots": slots, "graveyard": [],
		}
		_log("⚔ A new challenger enters the gauntlet: %s!" % cname)
		card_event.emit("respawn", {"player": seat, "name": cname})

## Pre-level replacement decks so later waves hit harder: +1 character
## level per two waves, capped at +5 (stat point goes to the best stat,
## mirroring normal level-ups).
func _gauntlet_scale_deck(deck: Array) -> void:
	var bonus: int = mini(5, gauntlet_wave / 2)
	if bonus <= 0:
		return
	for card in deck:
		if str(card.get("ctype", "")) != "character":
			continue
		for i in range(bonus):
			card["level"] = int(card["level"]) + 1
			card["xp_req"] = _xp_required(int(card["level"]))
			_grant_stat_point(card)
		_recalc_character(card, true)

## Start-of-turn upkeep for the active player: draw, refresh AP, tick
## conditions, feat regen.
func _begin_turn() -> void:
	var p: Dictionary = players[turn]
	# Free draw at every turn start ("1 free card each round"). Opening
	# hands are already full, so this usually forces a discard choice —
	# spend cards or lose the surplus.
	_draw_card(turn)
	for slot in range(MAX_SLOTS):
		var c = p["slots"][slot]
		if c == null:
			continue
		var fx: Dictionary = _merged_feat_fx(c)
		# Conditions tick down on the owner's turn; stunned drains all AP.
		var conds: Dictionary = c["conds"]
		if conds.has("bleeding"):
			var bleed: int = _roll(1, 4)
			_log("🩸 %s bleeds for %d (1d4)." % [str(c["name"]), bleed])
			_damage_character(turn, slot, bleed, "bleeding")
			if winner >= 0:
				return
		c = p["slots"][slot]
		if c == null:
			continue          # bled out
		c["ap"] = 0 if conds.has("stunned") else int(c["max_ap"])
		if conds.has("slowed") or conds.has("restrained"):
			c["ap"] = maxi(1, int(c["ap"]) / 2)
		for cond in conds.keys():
			conds[cond] = int(conds[cond]) - 1
			if int(conds[cond]) <= 0:
				conds.erase(cond)
		c["spell_used"] = {}
		c["acts"] = 0            # fatigue resets — next action costs 1 AP again
		c["ac_penalty"] = 0      # punctured guard recovers
		c["protect_used"] = false        # guardians can intercept again
		c["spell_reroll_used"] = false   # Spell Shaper refocuses
		c["spell_pierce_used"] = false
		# Regeneration (Rest & Recovery feat / lineage traits): 1d4/turn.
		if fx.has("regen") and int(c["hp"]) < int(c["max_hp"]):
			var h: int = _roll(1, 4)
			c["hp"] = mini(int(c["max_hp"]), int(c["hp"]) + h)
			_log("  ⟡ %s regenerates %d (1d4)." % [str(c["name"]), h])
			card_event.emit("heal", {"player": turn, "slot": slot, "amount": h, "source": "regen"})
		_recalc_character(c)   # conditions may have changed AC inputs
	card_event.emit("turn", {"player": turn, "name": str(p["name"])})
	# The AI plays its own turn — deferred so the UI paints first, then the
	# enemy's moves roll out live with delays between each action.
	if is_ai_turn():
		call_deferred("_run_ai_turn")

func _draw_card(player: int) -> void:
	var p: Dictionary = players[player]
	if (p["deck"] as Array).is_empty():
		_log("%s's deck is empty — no draw." % str(p["name"]))
		return
	var card: Dictionary = p["deck"].pop_back()
	p["hand"].append(card)
	if (p["hand"] as Array).size() > HAND_MAX:
		_log("%s is over %d cards — must discard!" % [str(p["name"]), HAND_MAX])
	card_event.emit("draw", {"player": player})

## True while `player` holds more than HAND_MAX cards (discards required
## before any other action, including ending the turn).
func hand_over_limit(player: int) -> bool:
	if player < 0 or player >= players.size():
		return false
	return (players[player]["hand"] as Array).size() > HAND_MAX

## Discard a card from hand to the graveyard. Free — and REQUIRED while
## the hand is over HAND_MAX (every other action is locked until legal).
func discard_card(player: int, hand_idx: int) -> String:
	var err: String = _check_turn(player, true)
	if err != "":
		return err
	var p: Dictionary = players[player]
	if hand_idx < 0 or hand_idx >= (p["hand"] as Array).size():
		return "Invalid card."
	var card: Dictionary = p["hand"][hand_idx]
	p["hand"].remove_at(hand_idx)
	p["graveyard"].append(card)
	_log("%s discards %s." % [str(p["name"]), str(card["name"])])
	card_event.emit("discard", {"player": player, "card": card})
	return ""

# ══════════════════════════════════════════════════════════════════════════
#  Banishment — permanently remove a card from the match (it does NOT go to
#  the discard pile and can never return) in exchange for one powerful boon.
#  The card itself is the whole price, so these are free of energy.
# ══════════════════════════════════════════════════════════════════════════

## Boon catalog. needs: "" | "slot" (a character in play) | "graveyard".
const BANISH_BOONS := {
	"second_wind": {"glyph": "⚡", "name": "Second Wind", "needs": "slot",
		"desc": "A character refills AP and resets fatigue — it can take all its actions again this round."},
	"renewal": {"glyph": "💚", "name": "Renewal", "needs": "slot",
		"desc": "Heal a character in play to full HP."},
	"reclaim": {"glyph": "♻", "name": "Reclaim", "needs": "graveyard",
		"desc": "Take any one card from your discard pile back into hand."},
	"foresight": {"glyph": "🔮", "name": "Foresight", "needs": "",
		"desc": "Draw two cards from your deck."},
	"ward": {"glyph": "✨", "name": "Cleansing Ward", "needs": "slot",
		"desc": "Strip every condition from a character and shield it (+2 AC)."},
	"surge": {"glyph": "⚡", "name": "Power Surge", "needs": "",
		"desc": "Regain 2 energy this round."},
	"ascension": {"glyph": "⭐", "name": "Ascension", "needs": "slot",
		"desc": "A character gains +1 level — or absorbs 10 HP if already at the cap."},
	"fortify": {"glyph": "🛡", "name": "Fortify", "needs": "slot",
		"desc": "Permanently grant a character +5 max HP, healed immediately."},
	"whetstone": {"glyph": "🗡", "name": "Whetstone", "needs": "slot",
		"desc": "Permanently grant a character +1 to attack rolls and +1 damage."},
	"aegis": {"glyph": "🔰", "name": "Aegis", "needs": "slot",
		"desc": "Permanently grant a character +1 AC."},
}

## Banish the hand card at `hand_idx` to claim `boon`. Slot-targeted boons
## use `slot`; Reclaim uses `gy_idx` (index into the player's graveyard).
func banish_card(player: int, hand_idx: int, boon: String,
		slot: int = -1, gy_idx: int = -1) -> String:
	var err: String = _check_turn(player)
	if err != "":
		return err
	if not BANISH_BOONS.has(boon):
		return "Unknown boon."
	var p: Dictionary = players[player]
	if hand_idx < 0 or hand_idx >= (p["hand"] as Array).size():
		return "Invalid card."
	var needs: String = str(BANISH_BOONS[boon]["needs"])
	var c = null
	if needs == "slot":
		c = p["slots"][slot] if slot >= 0 and slot < MAX_SLOTS else null
		if c == null:
			return "Pick one of your characters in play."
	var gcard: Dictionary = {}
	if needs == "graveyard":
		if gy_idx < 0 or gy_idx >= (p["graveyard"] as Array).size():
			return "Pick a card from your discard pile."
		if (p["hand"] as Array).size() >= HAND_MAX:
			return "Hand is full — discard first."
		gcard = p["graveyard"][gy_idx]
	if boon == "foresight" and (p["deck"] as Array).is_empty():
		return "Deck is empty."
	# Pay the price: the card leaves the match entirely.
	var cost_card: Dictionary = p["hand"][hand_idx]
	p["hand"].remove_at(hand_idx)
	p["exiled"] = int(p.get("exiled", 0)) + 1
	var bname: String = str(BANISH_BOONS[boon]["name"])
	_log("✦ %s banishes %s forever — %s!" % [str(p["name"]), str(cost_card["name"]), bname])
	match boon:
		"second_wind":
			c["ap"] = int(c["max_ap"])
			c["acts"] = 0
			c["spell_used"] = {}
			_log("  ⚡ %s is ready to act again." % str(c["name"]))
		"renewal":
			c["hp"] = int(c["max_hp"])
			_log("  💚 %s is restored to %d HP." % [str(c["name"]), int(c["max_hp"])])
			card_event.emit("heal", {"player": player, "slot": slot,
				"amount": int(c["max_hp"]), "source": "Renewal"})
		"reclaim":
			p["graveyard"].remove_at(gy_idx)
			p["hand"].append(gcard)
			_log("  ♻ %s returns from the discard pile." % str(gcard["name"]))
		"foresight":
			for i in range(2):
				_draw_card(player)
			_log("  🔮 Two cards drawn.")
		"ward":
			(c["conds"] as Dictionary).clear()
			c["conds"]["shielded"] = int(COND_DURATION.get("shielded", 2))
			_recalc_character(c)
			_log("  ✨ %s is cleansed and shielded." % str(c["name"]))
		"surge":
			p["energy"] = int(p["energy"]) + 2
			_log("  ⚡ 2 energy restored (now %d)." % int(p["energy"]))
		"ascension":
			if int(c["level"]) >= LEVEL_CAP:
				c["bonus_hp"] = int(c.get("bonus_hp", 0)) + 10
				_recalc_character(c)
				_log("  ⭐ %s is capped — absorbs 10 HP instead." % str(c["name"]))
			else:
				c["level"] = int(c["level"]) + 1
				c["xp_req"] = _xp_required(int(c["level"]))
				_grant_stat_point(c)
				_recalc_character(c)
				_log("  ⭐ %s ascends to level %d!" % [str(c["name"]), int(c["level"])])
			card_event.emit("level_up", {"player": player, "slot": slot, "card": c})
		"fortify":
			c["bonus_hp"] = int(c.get("bonus_hp", 0)) + 5
			_recalc_character(c)   # growth heals by the same 5
			_log("  🛡 %s is fortified — max HP now %d." % [str(c["name"]), int(c["max_hp"])])
		"whetstone":
			# Permanent buffs ride the trait list, so they merge into fx and
			# survive death, stowing, and recalculation like any lineage gift.
			(c["traits"] as Array).append({"name": "Whetstoned",
				"desc": "+1 to attack rolls and +1 damage.",
				"fx": {"hit_bonus": 1, "dmg_bonus": 1}})
			_recalc_character(c)
			_log("  🗡 %s's edge is honed — +1 to hit, +1 damage." % str(c["name"]))
		"aegis":
			(c["traits"] as Array).append({"name": "Aegis",
				"desc": "+1 AC.", "fx": {"ac_bonus": 1}})
			_recalc_character(c)
			_log("  🔰 %s is warded — AC now %d." % [str(c["name"]), int(c["ac"])])
	card_event.emit("banish", {"player": player, "boon": boon, "name": bname})
	return ""

# ══════════════════════════════════════════════════════════════════════════
#  Debug tools — gated behind GameState.debug_mode by the UI. These bypass
#  energy, turn order and legality on purpose; they exist for testing.
# ══════════════════════════════════════════════════════════════════════════

## The debug spawner's card tree, two levels deep so the panel stays small:
##   [{label, groups: [{label, cards: [{label, ctype, key}]}]}]
func debug_card_tree() -> Array:
	var tree: Array = []

	# 🧙 Characters — grouped by region.
	var char_groups: Array = []
	for r in get_regions():
		var cards: Array = []
		for lin in r["lineages"]:
			cards.append({"label": str(lin), "ctype": "character", "key": str(lin)})
		if not cards.is_empty():
			char_groups.append({"label": str(r["name"]), "cards": cards})
	tree.append({"label": "🧙 Characters", "groups": char_groups})

	# ⚔ Weapons — grouped by damage type.
	var by_dt: Dictionary = {}
	for w in CARD_WEAPONS:
		var dt: String = str(CARD_WEAPONS[w].get("dt", "other")).capitalize()
		if bool(CARD_WEAPONS[w].get("ranged", false)):
			dt = "Ranged"
		if not by_dt.has(dt):
			by_dt[dt] = []
		by_dt[dt].append({"label": "%s (%dd%d)" % [str(w),
			int(CARD_WEAPONS[w]["dc"]), int(CARD_WEAPONS[w]["ds"])],
			"ctype": "weapon", "key": str(w)})
	var w_groups: Array = []
	for dt_key in by_dt:
		w_groups.append({"label": str(dt_key), "cards": by_dt[dt_key]})
	tree.append({"label": "⚔ Weapons", "groups": w_groups})

	# 🛡 Armor — grouped by weight class, shields on their own.
	var light: Array = []
	var medium: Array = []
	var heavy: Array = []
	for a in CARD_ARMOR:
		var cap: int = int(CARD_ARMOR[a].get("spd_cap", 0))
		var row: Dictionary = {"label": "%s (AC %d)" % [str(a), int(CARD_ARMOR[a]["ac"])],
			"ctype": "armor", "key": str(a)}
		if cap < 0:
			light.append(row)
		elif cap > 0:
			medium.append(row)
		else:
			heavy.append(row)
	var shields: Array = []
	for s in CARD_SHIELDS:
		shields.append({"label": "%s (+%d AC)" % [str(s), int(CARD_SHIELDS[s]["ac"])],
			"ctype": "shield", "key": str(s)})
	tree.append({"label": "🛡 Armor", "groups": [
		{"label": "Light", "cards": light},
		{"label": "Medium", "cards": medium},
		{"label": "Heavy", "cards": heavy},
		{"label": "Shields", "cards": shields},
	]})

	# ★ Feats — grouped by their PHB category.
	var cats: Dictionary = _debug_feat_categories()
	var f_groups: Array = []
	for cat_name in cats:
		var fcards: Array = []
		for f in cats[cat_name]:
			var seq: Array = CARD_FEATS[f]["seq"]
			fcards.append({"label": "%s (T%s)" % [str(f), str(seq[0])],
				"ctype": "feat", "key": str(f)})
		if not fcards.is_empty():
			f_groups.append({"label": str(cat_name), "cards": fcards})
	tree.append({"label": "★ Feats", "groups": f_groups})

	# ✦ Spells — grouped by what they do.
	var by_kind: Dictionary = {}
	for sp in CARD_SPELLS:
		var k: String = str(CARD_SPELLS[sp].get("kind", "other")).capitalize()
		if not by_kind.has(k):
			by_kind[k] = []
		by_kind[k].append({"label": "%s (%d SP)" % [str(sp), int(CARD_SPELLS[sp]["sc"])],
			"ctype": "spell", "key": str(sp)})
	var s_groups: Array = []
	for k_key in by_kind:
		s_groups.append({"label": str(k_key), "cards": by_kind[k_key]})
	tree.append({"label": "✦ Spells", "groups": s_groups})

	return tree

## Feat name → PHB category, read from the engine's registry when it is
## reachable so the grouping can never drift from the source of truth.
func _debug_feat_categories() -> Dictionary:
	var label_for: Dictionary = {
		"Stat feats": "Stat", "Weapons and Combat feats": "Weapons & Combat",
		"Armor feats": "Armor", "Magic feats": "Magic",
	}
	var out: Dictionary = {"Stat": [], "Weapons & Combat": [], "Armor": [], "Magic": [], "Other": []}
	var e = RimvaleAPI.engine
	var reg = null
	if e != null and e.has_method("_ensure_feat_registry"):
		e._ensure_feat_registry()
		reg = e._FEAT_REGISTRY
	for f in CARD_FEATS:
		var bucket: String = "Other"
		if reg != null and reg.has(f):
			bucket = str(label_for.get(str(reg[f].get("cat", "")), "Other"))
		out[bucket].append(str(f))
	for k in out.keys():
		if (out[k] as Array).is_empty():
			out.erase(k)
	return out

## Conjure a card straight into `player`'s hand. `ctype` is one of
## character / weapon / armor / shield / feat / spell; `key` is its name
## (for characters, the lineage). Returns "" or an error.
func debug_give_card(player: int, ctype: String, key: String) -> String:
	if not match_active:
		return "No active match."
	if player < 0 or player >= num_players:
		return "Bad player."
	var p: Dictionary = players[player]
	var card: Dictionary = {}
	match ctype:
		"character":
			card = _make_character_card(key, "debug")
		"weapon", "armor", "shield":
			if not (CARD_WEAPONS.has(key) or CARD_ARMOR.has(key) or CARD_SHIELDS.has(key)):
				return "Unknown item: %s" % key
			card = _make_equipment_card(ctype, key)
		"feat":
			if not CARD_FEATS.has(key):
				return "Unknown feat: %s" % key
			card = _make_feat_card(key)
		"spell":
			if not CARD_SPELLS.has(key):
				return "Unknown spell: %s" % key
			card = _make_spell_card(key)
		_:
			return "Unknown card type: %s" % ctype
	p["hand"].append(card)
	_log("🐞 DEBUG: %s conjures %s into hand." % [str(p["name"]), str(card["name"])])
	card_event.emit("draw", {"player": player})
	return ""

## Editable fields for the debug character editor: [key, label].
const DEBUG_FIELDS := [
	["str", "STR"], ["spd", "SPD"], ["int", "INT"], ["vit", "VIT"], ["div", "DIV"],
	["level", "Level"], ["xp", "XP"], ["stat_pts", "Stat pts"],
	["hp", "HP now"], ["bonus_hp", "Max HP +"], ["ap", "AP now"], ["bonus_ac", "AC +"],
]

## Current value of a debug-editable field on a character card.
func debug_field_value(card: Dictionary, field: String) -> int:
	match field:
		"str": return int(card["stats"][0])
		"spd": return int(card["stats"][1])
		"int": return int(card["stats"][2])
		"vit": return int(card["stats"][3])
		"div": return int(card["stats"][4])
		"level": return int(card.get("level", 1))
		"xp": return int(card.get("xp", 0))
		"stat_pts": return int(card.get("stat_pts", 0))
		"hp": return int(card.get("hp", 0))
		"bonus_hp": return int(card.get("bonus_hp", 0))
		"ap": return int(card.get("ap", 0))
		"bonus_ac": return int(card.get("bonus_ac", 0))
	return 0

## Nudge one field on a character in play. Bypasses every rule on purpose;
## pools are recalculated afterwards so derived stats stay coherent.
func debug_adjust(player: int, slot: int, field: String, delta: int) -> String:
	if not match_active:
		return "No active match."
	if player < 0 or player >= num_players:
		return "Bad player."
	var c = players[player]["slots"][slot] if slot >= 0 and slot < MAX_SLOTS else null
	if c == null:
		return "No character in that slot."
	match field:
		"str", "spd", "int", "vit", "div":
			var idx: int = ["str", "spd", "int", "vit", "div"].find(field)
			c["stats"][idx] = clampi(int(c["stats"][idx]) + delta, 0, 99)
		"level":
			var lv: int = clampi(int(c.get("level", 1)) + delta, 1, LEVEL_CAP)
			c["level"] = lv
			c["xp_req"] = _xp_required(lv)
		"xp":
			c["xp"] = maxi(0, int(c.get("xp", 0)) + delta)
			# Let the normal curve consume it, granting levels and points.
			while int(c["xp"]) >= int(c["xp_req"]) and int(c["level"]) < LEVEL_CAP:
				c["xp"] = int(c["xp"]) - int(c["xp_req"])
				c["level"] = int(c["level"]) + 1
				c["xp_req"] = _xp_required(int(c["level"]))
				_grant_stat_point(c)
		"stat_pts":
			c["stat_pts"] = maxi(0, int(c.get("stat_pts", 0)) + delta)
		"bonus_hp":
			c["bonus_hp"] = maxi(0, int(c.get("bonus_hp", 0)) + delta)
		"bonus_ac":
			c["bonus_ac"] = int(c.get("bonus_ac", 0)) + delta
		"hp":
			c["hp"] = clampi(int(c.get("hp", 1)) + delta, 1, int(c.get("max_hp", 1)))
		"ap":
			c["ap"] = clampi(int(c.get("ap", 0)) + delta, 0, int(c.get("max_ap", 1)))
		_:
			return "Unknown field: %s" % field
	_recalc_character(c)
	_log("🐞 DEBUG: %s's %s → %d." % [str(c["name"]), field, debug_field_value(c, field)])
	return ""

## Max a character out: level cap, every stat at the cap, full pools.
func debug_max_character(player: int, slot: int) -> String:
	if not match_active:
		return "No active match."
	var c = players[player]["slots"][slot] if slot >= 0 and slot < MAX_SLOTS else null
	if c == null:
		return "No character in that slot."
	c["level"] = LEVEL_CAP
	c["xp"] = 0
	c["xp_req"] = _xp_required(LEVEL_CAP)
	for i in range(5):
		c["stats"][i] = STAT_CAP
	c["conds"] = {}
	_recalc_character(c, true)
	_log("🐞 DEBUG: %s is maxed out (Lv%d, all stats %d)." % [
		str(c["name"]), LEVEL_CAP, STAT_CAP])
	return ""

## Refill a player's energy to this round's allowance (or an explicit amount).
func debug_refill_energy(player: int, amount: int = -1) -> String:
	if not match_active:
		return "No active match."
	if player < 0 or player >= num_players:
		return "Bad player."
	var give: int = amount if amount >= 0 else mini(round_num, ENERGY_CAP)
	players[player]["energy"] = give
	_log("🐞 DEBUG: %s's energy set to %d." % [str(players[player]["name"]), give])
	card_event.emit("round", {"round": round_num, "energy": give})
	return ""

## Send the character in `slot` straight to its owner's discard pile,
## restored to full — no damage, no death triggers.
func debug_discard_slot(player: int, slot: int) -> String:
	if not match_active:
		return "No active match."
	if player < 0 or player >= num_players:
		return "Bad player."
	var c = players[player]["slots"][slot] if slot >= 0 and slot < MAX_SLOTS else null
	if c == null:
		return "No character in that slot."
	players[player]["slots"][slot] = null
	if bool(c.get("is_token", false)):
		_log("🐞 DEBUG: %s dissipates." % str(c["name"]))
	else:
		_restore_card(c)
		players[player]["graveyard"].append(c)
		_log("🐞 DEBUG: %s is sent to the discard pile." % str(c["name"]))
	card_event.emit("discard", {"player": player, "card": c})
	return ""

## Send a card from hand to the discard pile (any type), free and off-turn.
func debug_discard_hand(player: int, hand_idx: int) -> String:
	if not match_active:
		return "No active match."
	var p: Dictionary = players[player] if player >= 0 and player < num_players else {}
	if p.is_empty() or hand_idx < 0 or hand_idx >= (p["hand"] as Array).size():
		return "Invalid card."
	var card: Dictionary = p["hand"][hand_idx]
	p["hand"].remove_at(hand_idx)
	p["graveyard"].append(card)
	_log("🐞 DEBUG: %s discarded from hand." % str(card["name"]))
	card_event.emit("discard", {"player": player, "card": card})
	return ""

# ══════════════════════════════════════════════════════════════════════════
#  Conquest — fight one battle in every region. The deck persists and grows:
#  cards keep the levels, gear and feats they earned, and each victory adds
#  spoils drawn from the region just taken. A single defeat ends the run.
# ══════════════════════════════════════════════════════════════════════════

const CONQUEST_REWARDS := 3        # cards granted after each region falls

## Begin a run. `deck` is the player's starting 40; `seats` is 2, 3 or 4.
func start_conquest(player_name: String, deck: Array, seats: int,
		ai_diff: String = "medium") -> String:
	var ids: Array = []
	for r in get_regions():
		ids.append(str(r["id"]))
	if ids.is_empty():
		return "No regions available."
	ids.shuffle()
	conquest = true
	conquest_index = 0
	conquest_order = ids
	conquest_deck = deck.duplicate()
	conquest_seats = clampi(seats, 2, 4)
	conquest_name = player_name
	ai_difficulty = ai_diff if AI_DIFFICULTY.has(ai_diff) else "medium"
	return start_conquest_battle()

## Launch the battle for the current region using the persistent deck.
func start_conquest_battle() -> String:
	if conquest_index >= conquest_order.size():
		return "The conquest is already complete."
	var region_id: String = str(conquest_order[conquest_index])
	var configs: Array = [{
		"name": conquest_name, "region": region_id,
		"deck": conquest_deck.duplicate(), "ai": false,
	}]
	# Defenders are drawn from the region being invaded, so each battle has
	# the flavour of the place — and they get tougher as the run goes on.
	for i in range(1, conquest_seats):
		var d: Array = build_ai_deck(region_id)
		_conquest_scale_deck(d)
		configs.append({
			"name": "🛡 %s Defender %d" % [conquest_region_name(), i],
			"region": region_id, "deck": d, "ai": true,
		})
	var err: String = start_match(configs, ai_difficulty, false)
	if err != "":
		return err
	conquest = true          # start_match cleared the flag; this run continues
	_log("🗺 CONQUEST — battle %d of %d: %s." % [
		conquest_index + 1, conquest_order.size(), conquest_region_name()])
	return ""

## Pre-level defender decks by how far the run has progressed.
func _conquest_scale_deck(deck: Array) -> void:
	var bonus: int = mini(6, conquest_index)
	if bonus <= 0:
		return
	for card in deck:
		if str(card.get("ctype", "")) != "character":
			continue
		for i in range(bonus):
			card["level"] = int(card["level"]) + 1
			card["xp_req"] = _xp_required(int(card["level"]))
			_grant_stat_point(card)
		_recalc_character(card, true)

## Display name of the region currently under attack.
func conquest_region_name() -> String:
	if conquest_index >= conquest_order.size():
		return ""
	for r in get_regions():
		if str(r["id"]) == str(conquest_order[conquest_index]):
			return str(r["name"])
	return str(conquest_order[conquest_index])

## Called by the UI once a conquest battle ends. Returns a summary:
##   {won, complete, regions_taken, total, rewards: Array}
func conquest_resolve() -> Dictionary:
	var won: bool = winner == 0
	var out: Dictionary = {
		"won": won, "complete": false, "rewards": [],
		"regions_taken": conquest_index, "total": conquest_order.size(),
		"region": conquest_region_name(),
	}
	if not won:
		conquest = false
		return out
	# Carry the survivors — and the fallen — forward, keeping the progress
	# every card earned this battle.
	var kept: Array = []
	if players.size() > 0:
		var p: Dictionary = players[0]
		for s in range(MAX_SLOTS):
			if p["slots"][s] != null and not bool(p["slots"][s].get("is_token", false)):
				_restore_card(p["slots"][s])
				kept.append(p["slots"][s])
		for c in p["hand"]:
			kept.append(c)
		for c in p["deck"]:
			kept.append(c)
		for c in p["graveyard"]:
			kept.append(c)
	# Spoils of the region just taken.
	var spoils: Array = []
	var pool: Array = generate_pool(str(conquest_order[conquest_index]))
	pool.shuffle()
	for i in range(mini(CONQUEST_REWARDS, pool.size())):
		spoils.append(pool[i])
		kept.append(pool[i])
	out["rewards"] = spoils
	conquest_deck = kept
	conquest_index += 1
	out["regions_taken"] = conquest_index
	out["complete"] = conquest_index >= conquest_order.size()
	if out["complete"]:
		conquest = false
	return out

## Abandon a conquest run.
func end_conquest() -> void:
	conquest = false
	conquest_index = 0
	conquest_order = []
	conquest_deck = []

## Bow out of a gauntlet run and bank the score. The runner walks away
## undefeated — the tally of enemies defeated is their result.
func end_gauntlet_run(player: int) -> String:
	if not gauntlet:
		return "Not a gauntlet run."
	if winner >= 0:
		return "The run is already over."
	if player < 0 or player >= num_players:
		return "Bad player."
	winner = player
	_log("🌊 %s walks away undefeated — %d enemies defeated over %d rounds." % [
		str(players[player]["name"]), gauntlet_kills, round_num])
	card_event.emit("victory", {"winner": player, "name": str(players[player]["name"]),
		"gauntlet": true, "banked": true, "kills": gauntlet_kills,
		"rounds": round_num, "runner": str(players[player]["name"])})
	return ""

## Sacrifice a character card from hand: a chosen character in play gains
## +1 level on the spot (stat point to its best stat, pools regrow, growth
## heals). Costs 1 energy; the offering goes to the graveyard.
func sacrifice_character(player: int, hand_idx: int, slot: int) -> String:
	var err: String = _check_turn(player)
	if err != "":
		return err
	var p: Dictionary = players[player]
	if hand_idx < 0 or hand_idx >= (p["hand"] as Array).size():
		return "Invalid card."
	var offering: Dictionary = p["hand"][hand_idx]
	if str(offering["ctype"]) != "character":
		return "Only character cards can be sacrificed."
	var c = p["slots"][slot] if slot >= 0 and slot < MAX_SLOTS else null
	if c == null:
		return "Pick a character in play to empower."
	if int(p["energy"]) < 1:
		return "Not enough energy."
	p["energy"] = int(p["energy"]) - 1
	p["hand"].remove_at(hand_idx)
	p["graveyard"].append(offering)
	if int(c["level"]) >= LEVEL_CAP:
		# Level-capped veterans can't grow further, so they devour the
		# offering's vitality instead — its max HP becomes permanent HP.
		var absorbed: int = int(offering.get("max_hp", 0))
		c["bonus_hp"] = int(c.get("bonus_hp", 0)) + absorbed
		_recalc_character(c)   # growth heals by the same amount
		_log("⚰ %s is devoured — %s absorbs %d HP!" % [
			str(offering["name"]), str(c["name"]), absorbed])
		card_event.emit("level_up", {"player": player, "slot": slot, "card": c})
		return ""
	c["level"] = int(c["level"]) + 1
	c["xp_req"] = _xp_required(int(c["level"]))
	_grant_stat_point(c)
	_recalc_character(c)
	_log("⚰ %s is sacrificed — %s surges to level %d!" % [
		str(offering["name"]), str(c["name"]), int(c["level"])])
	card_event.emit("level_up", {"player": player, "slot": slot, "card": c})
	return ""

## Step an equipped feat up its real PHB ladder (1→3→5, 1→2→3, …). The new
## tier's effect REPLACES the old one wholesale, exactly as the tabletop
## feat restates its benefits. Returns the new tier, or 0 if already maxed.
func _upgrade_feat(existing: Dictionary) -> int:
	var fname: String = str(existing["name"])
	var nt: int = next_feat_tier(fname, int(existing.get("tier", 1)))
	if nt < 0:
		return 0
	var t: Dictionary = (CARD_FEATS[fname]["tiers"] as Dictionary)[nt]
	existing["tier"] = nt
	existing["fx"] = (t["fx"] as Dictionary).duplicate(true)
	existing["desc"] = "T%d — %s (costs %d feat pts)" % [nt, str(t["desc"]), nt]
	return nt

## Why `card` cannot be equipped onto `target`, or "" when it can. Shared by
## equip_card and the UI's target highlighting so they never disagree.
func equip_error(card: Dictionary, target: Dictionary, prefer_slot: String = "") -> String:
	match str(card.get("ctype", "")):
		"equipment":
			# Re-equipping the SAME item forges it up a plus instead of
			# replacing it; a different item swaps in as normal.
			var worn = target.get(_equip_slot_for(card, target, prefer_slot))
			if worn != null and str(worn.get("name", "")) == str(card.get("name", "")) \
					and int(worn.get("plus", 0)) >= GEAR_MAX_PLUS:
				return "%s's %s is already +%d." % [
					str(target["name"]), str(card["name"]), GEAR_MAX_PLUS]
			return ""
		"feat":
			# A duplicate steps the feat up its real tier ladder; the cost is
			# the difference between the new tier and the old.
			for fc in target.get("feats", []):
				if str(fc["name"]) == str(card["name"]):
					var cur: int = int(fc.get("tier", 1))
					var nxt: int = next_feat_tier(str(card["name"]), cur)
					if nxt < 0:
						return "%s's %s is already at its highest tier (%d)." % [
							str(target["name"]), str(card["name"]), cur]
					if feat_points_used(target) + (nxt - cur) > feat_budget(target):
						return "%s needs %d more feat point(s) to reach tier %d (%d/%d used)." % [
							str(target["name"]), nxt - cur, nxt,
							feat_points_used(target), feat_budget(target)]
					return ""
			if feat_points_used(target) + int(card["tier"]) > feat_budget(target):
				return "%s lacks feat points (%d/%d used). Level up to earn more." % [
					str(target["name"]), feat_points_used(target), feat_budget(target)]
			return ""
		"spell":
			if spell_sp_used(target) + int(card["sc"]) > int(target["max_sp"]):
				return "%s lacks SP for that spell (%d/%d used)." % [
					str(target["name"]), spell_sp_used(target), int(target["max_sp"])]
			for sp in target.get("spells", []):
				if str(sp["name"]) == str(card["name"]):
					return "%s already knows that spell." % str(target["name"])
			return ""
	return "Characters go to empty slots — use Play instead."

## Convenience wrapper for UI highlighting.
func can_equip(card: Dictionary, target) -> bool:
	return target != null and equip_error(card, target) == ""

## Which gear slot a card actually lands in. A second, DIFFERENT weapon goes
## to the off-hand when the character can dual-wield (Twin Fang / Improvised
## Weapon Mastery); duplicates always forge the main hand instead.
## `prefer` ("weapon" / "offhand") lets the player choose the hand explicitly —
## that's how you replace a specific weapon while dual-wielding, and how a
## character ends up holding two separately-enchanted copies of the same
## weapon (a Longsword +2 in one hand and a Longsword +1 in the other).
## With no preference the old auto-routing applies.
func _equip_slot_for(card: Dictionary, target: Dictionary, prefer: String = "") -> String:
	var eslot: String = str(card.get("slot", ""))
	if eslot != "weapon":
		return eslot
	var can_dual: bool = int(_merged_feat_fx(target).get("dual_wield", 0)) > 0
	if prefer == "offhand" and can_dual:
		return "offhand"
	if prefer == "weapon":
		return "weapon"
	var main = target.get("weapon")
	if main == null:
		return "weapon"
	if str(main.get("name", "")) == str(card.get("name", "")):
		return "weapon"                      # same item → forge it up
	if can_dual and target.get("offhand") == null:
		return "offhand"
	return "weapon"                          # no dual-wield → straight swap

## True when the player should be asked which hand a weapon goes into:
## the character can dual-wield and already holds something.
func weapon_needs_hand_choice(card: Dictionary, target) -> bool:
	if target == null or str(card.get("ctype", "")) != "equipment":
		return false
	if str(card.get("slot", "")) != "weapon":
		return false
	if int(_merged_feat_fx(target).get("dual_wield", 0)) <= 0:
		return false
	return target.get("weapon") != null or target.get("offhand") != null

## What equipping `card` into `hand` would do, for the chooser's labels:
## "" when the hand is unusable, else "Equip" / "Replace X" / "Forge X → +N".
func weapon_hand_action(card: Dictionary, target: Dictionary, hand: String) -> String:
	var worn = target.get(hand)
	if worn == null:
		return "Equip"
	if str(worn.get("name", "")) == str(card.get("name", "")):
		if int(worn.get("plus", 0)) >= GEAR_MAX_PLUS:
			return ""                        # already maxed — nothing to gain
		return "Forge → +%d" % (int(worn.get("plus", 0)) + 1)
	return "Replace %s" % card_title(worn)

## Withdraw a character from the board back into your hand for 1 energy.
## They return rested (full HP, conditions cleared) and keep their levels,
## gear imprints, feats and spells — but suffer summoning sickness when
## replayed. A tactical retreat for a card about to die.
func stow_character(player: int, slot: int) -> String:
	var err: String = _check_turn(player)
	if err != "":
		return err
	var p: Dictionary = players[player]
	var c = p["slots"][slot] if slot >= 0 and slot < MAX_SLOTS else null
	if c == null:
		return "No character in that slot."
	if bool(c.get("is_token", false)):
		return "Summoned creatures cannot be taken into hand."
	if int(p["energy"]) < 1:
		return "Not enough energy."
	if (p["hand"] as Array).size() >= HAND_MAX:
		return "Hand is full — discard first."
	p["energy"] = int(p["energy"]) - 1
	p["slots"][slot] = null
	_restore_card(c)          # rested and ready for redeployment
	p["hand"].append(c)
	_log("↩ %s withdraws %s back into hand." % [str(p["name"]), str(c["name"])])
	card_event.emit("stow", {"player": player, "slot": slot, "card": c})
	return ""

## Pay 1 energy to refill a character's AP to max. The round's fatigue is
## NOT reset — the next action still costs what the escalation demands, so
## refreshing extends a card's turn without trivializing action costs.
func refresh_ap(player: int, slot: int) -> String:
	var err: String = _check_turn(player)
	if err != "":
		return err
	var p: Dictionary = players[player]
	var c = p["slots"][slot] if slot >= 0 and slot < MAX_SLOTS else null
	if c == null:
		return "No character in that slot."
	if int(p["energy"]) < 1:
		return "Not enough energy."
	if int(c["ap"]) >= int(c["max_ap"]):
		return "%s already has full AP." % str(c["name"])
	p["energy"] = int(p["energy"]) - 1
	c["ap"] = int(c["max_ap"])
	_log("⚡ %s pays 1 energy — %s's AP refills to %d." % [
		str(p["name"]), str(c["name"]), int(c["max_ap"])])
	card_event.emit("refresh", {"player": player, "slot": slot})
	return ""

## Pay 1 energy to draw one extra card. Repeatable while energy lasts.
## Drawing at a full hand is allowed (cycle: draw, then discard down).
func draw_extra(player: int) -> String:
	var err: String = _check_turn(player)
	if err != "":
		return err
	var p: Dictionary = players[player]
	if int(p["energy"]) < 1:
		return "Not enough energy."
	if (p["deck"] as Array).is_empty():
		return "Deck is empty."
	p["energy"] = int(p["energy"]) - 1
	_log("%s pays 1⚡ for an extra draw." % str(p["name"]))
	_draw_card(player)
	return ""

## End the active player's turn. Play passes to the next LIVING seat; a
## new round begins whenever the rotation wraps past seat 0.
func end_turn(player: int) -> String:
	var err: String = _check_turn(player)
	if err != "":
		return err
	var prev: int = turn
	for i in range(1, num_players + 1):
		var nxt: int = (prev + i) % num_players
		if int(players[nxt]["hp"]) > 0:
			if nxt <= prev:
				_begin_round()
			turn = nxt
			break
	_begin_turn()
	return ""

# ══════════════════════════════════════════════════════════════════════════
#  Player actions
# ══════════════════════════════════════════════════════════════════════════

func _check_turn(player: int, allow_oversized: bool = false) -> String:
	if not match_active:
		return "No active match."
	if winner >= 0:
		return "The match is over."
	if player != turn:
		return "Not your turn."
	if not allow_oversized and hand_over_limit(player):
		return "Hand over %d — discard down first." % HAND_MAX
	return ""

## Play a character card from hand into an empty slot. Costs 1 energy.
func play_character(player: int, hand_idx: int, slot: int) -> String:
	var err: String = _check_turn(player)
	if err != "":
		return err
	var p: Dictionary = players[player]
	if hand_idx < 0 or hand_idx >= (p["hand"] as Array).size():
		return "Invalid card."
	var card: Dictionary = p["hand"][hand_idx]
	if str(card["ctype"]) != "character":
		return "That is not a character card."
	if slot < 0 or slot >= MAX_SLOTS or p["slots"][slot] != null:
		return "Pick an empty slot."
	if int(p["energy"]) < 1:
		return "Not enough energy."
	p["energy"] = int(p["energy"]) - 1
	p["hand"].remove_at(hand_idx)
	p["slots"][slot] = card
	card["ap"] = int(card["max_ap"])   # fresh cards may cast right away…
	card["acts"] = 0
	card["played_round"] = round_num   # …but attacks unlock next round
	_summon_tokens(player, card)       # Grasp of the Forgotten's escorts
	_log("%s plays %s the %s." % [str(p["name"]), str(card["name"]), str(card["lineage"])])
	card_event.emit("play", {"player": player, "slot": slot, "card": card})
	return ""

## Equip an equipment / feat / spell card from hand onto a character in
## play. Costs 1 energy. Replaced equipment goes to the graveyard.
func equip_card(player: int, hand_idx: int, slot: int, prefer_slot: String = "") -> String:
	var err: String = _check_turn(player)
	if err != "":
		return err
	var p: Dictionary = players[player]
	if hand_idx < 0 or hand_idx >= (p["hand"] as Array).size():
		return "Invalid card."
	var card: Dictionary = p["hand"][hand_idx]
	var target = p["slots"][slot] if slot >= 0 and slot < MAX_SLOTS else null
	if target == null:
		return "Pick a character in play."
	if int(p["energy"]) < 1:
		return "Not enough energy."
	var reason: String = equip_error(card, target, prefer_slot)
	if reason != "":
		return reason
	# The physical card is spent: a COPY of its data rides the character
	# (so the effect persists) while the card itself hits the discard pile.
	var imprint: Dictionary = card.duplicate(true)
	var upgraded_to: int = 0
	var forged_plus: int = -1
	match str(card["ctype"]):
		"equipment":
			var eslot: String = _equip_slot_for(card, target, prefer_slot)
			var worn = target.get(eslot)
			if worn != null and str(worn.get("name", "")) == str(card["name"]):
				worn["plus"] = int(worn.get("plus", 0)) + 1   # forge it up
				forged_plus = int(worn["plus"])
			else:
				target[eslot] = imprint   # replaced gear simply falls away
		"feat":
			for fc in target["feats"]:
				if str(fc["name"]) == str(card["name"]):
					upgraded_to = _upgrade_feat(fc)
					break
			if upgraded_to == 0:
				target["feats"].append(imprint)
		"spell":
			target["spells"].append(imprint)
	p["energy"] = int(p["energy"]) - 1
	p["hand"].remove_at(hand_idx)
	p["graveyard"].append(card)
	_recalc_character(target)
	if forged_plus > 0:
		_log("🔨 %s forges %s's %s to +%d!" % [
			str(p["name"]), str(target["name"]), str(card["name"]), forged_plus])
	elif upgraded_to > 0:
		_log("%s bumps %s's %s up to tier %d!" % [
			str(p["name"]), str(target["name"]), str(card["name"]), upgraded_to])
	else:
		_log("%s equips %s onto %s — the card goes to the discard pile." % [
			str(p["name"]), str(card["name"]), str(target["name"])])
	card_event.emit("equip", {"player": player, "slot": slot, "card": card})
	return ""

## Attack with the character in `slot`. target_slot -1 attacks the enemy
## player directly (their AC = 10 + their living characters). Costs the
## card's escalating action_cost (1 AP first action, 2 the next, …).
func attack(player: int, slot: int, target_player: int, target_slot: int,
		is_counter: bool = false) -> String:
	var err: String = _check_turn(player)
	if err != "":
		return err
	if target_player == player:
		return "Cannot attack your own side."
	if target_player < 0 or target_player >= num_players \
			or int(players[target_player]["hp"]) <= 0:
		return "That player is already out of the fight."
	var p: Dictionary = players[player]
	var atk_card = p["slots"][slot] if slot >= 0 and slot < MAX_SLOTS else null
	if atk_card == null:
		return "No character in that slot."
	var atk_cost: int = action_cost(atk_card)
	# Twin Fang T1 charges an extra AP to fight with two weapons; later
	# tiers waive it (dual_free).
	if atk_card.get("offhand") != null \
			and int(_merged_feat_fx(atk_card).get("dual_free", 0)) == 0:
		atk_cost += 1
	if int(atk_card["ap"]) < atk_cost:
		return "%s needs %d AP for their next action." % [str(atk_card["name"]), atk_cost]
	if target_slot < 0 and int(p["energy"]) < 1:
		return "Attacking a player directly costs 1 energy."
	if int(atk_card.get("played_round", -1)) == round_num:
		return "%s just arrived — attacks unlock next round." % str(atk_card["name"])
	if (atk_card["conds"] as Dictionary).has("restrained"):
		return "%s is restrained and cannot attack — but may still cast." % str(atk_card["name"])
	var tp: Dictionary = players[target_player]
	var fx: Dictionary = _merged_feat_fx(atk_card)
	# ── Resolve the to-hit roll ──────────────────────────────────────────
	var weapon = atk_card.get("weapon")
	var finesse: bool = weapon != null and bool(weapon.get("finesse", false))
	var stat_bonus: int = int(atk_card["stats"][1]) if finesse else int(atk_card["stats"][0])
	var gear_plus: int = int(weapon.get("plus", 0)) if weapon != null else 0
	var is_ranged: bool = weapon != null and bool(weapon.get("ranged", false))
	var hit_bonus: int = stat_bonus + int(fx.get("hit_bonus", 0)) + gear_plus
	if is_ranged:
		hit_bonus += int(fx.get("ranged_hit_bonus", 0))   # Linebreaker's Aim
	if (atk_card["conds"] as Dictionary).has("frightened"):
		hit_bonus -= 2
	var target_ac: int
	var tgt_card = null
	if target_slot < 0:
		target_ac = player_ac(target_player)
	else:
		tgt_card = tp["slots"][target_slot] if target_slot < MAX_SLOTS else null
		if tgt_card == null:
			return "No character in the target slot."
		target_ac = int(tgt_card["ac"])
		if (tgt_card["conds"] as Dictionary).has("dodging"):
			target_ac += 3
		if (tgt_card["conds"] as Dictionary).has("shielded"):
			target_ac += 2
		if (tgt_card["conds"] as Dictionary).has("slowed"):
			target_ac -= 2
		if (tgt_card["conds"] as Dictionary).has("restrained"):
			target_ac -= 3
		# Bulwark auras: a shield-bearer stiffens the whole line and makes
		# attacks on their comrades harder to land.
		target_ac += _team_aura(target_player, "team_ac")
		# Linebreaker's Aim T3 shoots clean through the shield wall.
		if int(fx.get("ignore_ward", 0)) == 0:
			hit_bonus -= _team_aura(target_player, "ward_ally")
	var tgt_name: String = str(tp["name"]) if target_slot < 0 else str(tgt_card["name"])
	# Recompute after the ally-ward penalty so the log shows the true math.
	var raw: int = _roll(1, 20)
	var crit_at: int = int(fx.get("crit_at", 20))
	var is_crit: bool = raw >= crit_at
	var total: int = raw + hit_bonus
	atk_card["ap"] = int(atk_card["ap"]) - atk_cost
	atk_card["acts"] = int(atk_card.get("acts", 0)) + 1
	if target_slot < 0:
		p["energy"] = int(p["energy"]) - 1   # face attacks tax the player too
	_award_xp(player, slot, atk_card)
	if winner >= 0:
		return ""    # level-up log ordering safety; winner can't be set here, but stay safe
	if total < target_ac and not is_crit:
		_log("%s attacks %s — 🎲 %d%+d = %d vs AC %d: MISS." % [
			str(atk_card["name"]), tgt_name, raw, hit_bonus, total, target_ac])
		card_event.emit("attack", {"player": player, "slot": slot, "target_player": target_player,
			"target_slot": target_slot, "hit": false, "roll": raw, "total": total, "ac": target_ac})
		# Martial Prowess T3 — a miss still grazes for the attacking stat.
		if int(fx.get("graze", 0)) > 0 and target_slot >= 0 and tgt_card != null \
				and stat_bonus > 0:
			_log("  ⟡ Glancing blow — %s takes %d." % [str(tgt_card["name"]), stat_bonus])
			_damage_character(target_player, target_slot, stat_bonus, "graze")
		# Evading a blow rewards the defender (Turn the Blade / Deflective
		# Stance): a brief AC edge, and at higher tiers a free counter.
		if target_slot >= 0 and tgt_card != null and tp["slots"][target_slot] != null:
			var dfx: Dictionary = _merged_feat_fx(tgt_card)
			if int(dfx.get("ac_on_evade", 0)) > 0:
				tgt_card["conds"]["dodging"] = int(COND_DURATION.get("dodging", 1))
				_log("  ⟡ %s slips the blow and sets their guard." % str(tgt_card["name"]))
			if int(dfx.get("ap_on_evade", 0)) > 0:
				tgt_card["ap"] = mini(int(tgt_card["max_ap"]),
					int(tgt_card["ap"]) + int(dfx["ap_on_evade"]))
				_log("    …and seizes the tempo (+%d AP)." % int(dfx["ap_on_evade"]))
			# `is_counter` stops counters from triggering further counters.
			if not is_counter and int(dfx.get("counter_on_miss", 0)) > 0:
				_counterattack(target_player, target_slot, player, slot)
		return ""
	# ── Damage (dice tracked so the log can show the full roll) ──────────
	var d_n: int
	var d_s: int
	if weapon != null:
		d_n = int(weapon["dc"]) * (2 if is_crit else 1)
		d_s = int(weapon["ds"])
		# Crimson Edge / Iron Hammer / Iron Thorn floor their damage type's die.
		var by_type: Dictionary = fx.get("weapon_die_by_type", {})
		if by_type.has(str(weapon.get("dt", ""))):
			d_s = maxi(d_s, int(by_type[str(weapon["dt"])]))
	else:
		d_n = 2 if is_crit else 1        # unarmed 1d4, or Iron Fist's die
		d_s = maxi(4, int(fx.get("unarmed_die", 4)))
	var rolled: int = _roll_reroll_ones(d_n, d_s) if int(fx.get("reroll_ones", 0)) > 0 \
		else _roll(d_n, d_s)
	# dmg_stat_mult (Titanic Damage / Swift Striker) counts the attacking
	# stat extra times, per the PHB's "add 2× stat to damage".
	var dmg: int = rolled + stat_bonus * maxi(1, int(fx.get("dmg_stat_mult", 1)))
	dmg += int(fx.get("dmg_bonus", 0)) + gear_plus
	if is_ranged:
		dmg += int(fx.get("ranged_dmg_bonus", 0))
	if fx.has("rage_dmg") and int(atk_card["hp"]) * 2 < int(atk_card["max_hp"]):
		dmg += int(fx.get("rage_dmg", 0))
	dmg = maxi(1, dmg)
	var crit_txt: String = " CRITICAL!" if is_crit else ""
	var roll_txt: String = "🎲 %d%+d = %d vs AC %d" % [raw, hit_bonus, total, target_ac]
	var dice_txt: String = "%dd%d%+d" % [d_n, d_s, dmg - rolled]
	# ── Riders that affect the ATTACKER only ─────────────────────────────
	# These need no target card, so they fire whether the blow landed on a
	# character or on the enemy player. (Target-dependent riders — crit_stun,
	# ac_debuff_on_hit, inflict_on_hit, thorns, execute — stay below.)
	if is_crit and int(fx.get("crit_ap", 0)) > 0:
		atk_card["ap"] = mini(int(atk_card["max_ap"]),
			int(atk_card["ap"]) + int(fx["crit_ap"]))
		_log("  ★ Precise strike — %s gains %d AP." % [
			str(atk_card["name"]), int(fx["crit_ap"])])
	if is_crit and int(fx.get("free_on_crit", 0)) > 0:
		atk_card["ap"] = mini(int(atk_card["max_ap"]), int(atk_card["ap"]) + atk_cost)
		atk_card["acts"] = maxi(0, int(atk_card["acts"]) - 1)
		_log("  ★ The crit costs nothing — %s may strike again." % str(atk_card["name"]))
	if int(fx.get("lifesteal", 0)) > 0 and dmg > 0:
		var drink: int = maxi(1, dmg / 2)
		atk_card["hp"] = mini(int(atk_card["max_hp"]), int(atk_card["hp"]) + drink)
		_log("  ⟡ %s drinks deep — heals %d." % [str(atk_card["name"]), drink])
	if target_slot < 0:
		tp["hp"] = int(tp["hp"]) - dmg
		tp["last_hit_by"] = player   # credits gauntlet kill spoils
		_log("%s strikes %s directly — %s: %d damage (%s)!%s" % [
			str(atk_card["name"]), str(tp["name"]), roll_txt, dmg, dice_txt, crit_txt])
		card_event.emit("attack", {"player": player, "slot": slot, "target_player": target_player,
			"target_slot": -1, "hit": true, "crit": is_crit, "damage": dmg, "roll": raw})
		_check_win()
		# Dual-wielders press the attack with their off-hand here too.
		if not is_counter and atk_card.get("offhand") != null and winner < 0:
			if _offhand_strike(player, slot, target_player, -1):
				var face_flourish: int = int(fx.get("dual_bonus", 0))
				if face_flourish > 0 and winner < 0:
					var fx_extra: int = _roll(1, face_flourish)
					_log("  🗡 Both blades bite — %d extra damage!" % fx_extra)
					tp["hp"] = int(tp["hp"]) - fx_extra
					_check_win()
	else:
		_log("%s hits %s — %s: %d damage (%s)!%s" % [
			str(atk_card["name"]), str(tgt_card["name"]), roll_txt, dmg, dice_txt, crit_txt])
		card_event.emit("attack", {"player": player, "slot": slot, "target_player": target_player,
			"target_slot": target_slot, "hit": true, "crit": is_crit, "damage": dmg, "roll": raw})
		var tgt_fx: Dictionary = _merged_feat_fx(tgt_card)
		# Assassin's Execution: a wounded target below the threshold is
		# finished outright rather than merely damaged.
		var exec_hp: int = int(fx.get("execute_hp", 0))
		if exec_hp > 0 and int(tgt_card["hp"]) <= exec_hp + dmg \
				and int(tgt_card["hp"]) - dmg > 0:
			dmg = int(tgt_card["hp"])
			_log("  ☠ Execution — %s is finished outright!" % str(tgt_card["name"]))
		if is_crit:
			# crit_ap / free_on_crit already applied above (they need no target).
			if int(fx.get("crit_stun", 0)) > 0 and _apply_condition(tgt_card, "stunned", fx):
				_log("  ★ %s is stunned by the blow!" % str(tgt_card["name"]))
		# Wall of the Battered / Tower Shield: a guardian steps into the blow.
		var hit_slot: int = target_slot
		var guard: int = _find_protector(target_player, target_slot)
		if guard >= 0:
			var g = tp["slots"][guard]
			g["protect_used"] = true
			hit_slot = guard
			_log("  🛡 %s throws themselves in front of %s!" % [
				str(g["name"]), str(tgt_card["name"])])
			tgt_card = g
			tgt_fx = _merged_feat_fx(g)
		_damage_character(target_player, hit_slot, dmg, str(atk_card["name"]),
			str(weapon.get("dt", "")) if weapon != null else "")
		var killed: bool = tp["slots"][hit_slot] == null
		if killed:
			atk_card["kills"] = int(atk_card.get("kills", 0)) + 1
			# free_on_kill (Titanic Damage T2+ / Swift Striker T3).
			if int(fx.get("free_on_kill", 0)) > 0:
				atk_card["ap"] = mini(int(atk_card["max_ap"]), int(atk_card["ap"]) + atk_cost)
				atk_card["acts"] = maxi(0, int(atk_card["acts"]) - 1)
				_log("  ⚔ The kill refunds the action — %s attacks again." % str(atk_card["name"]))
		# ── Lineage-trait riders (lifesteal applied above) ───────────────
		if killed and int(fx.get("heal_on_kill", 0)) > 0:
			var feast: int = int(fx["heal_on_kill"])
			atk_card["hp"] = mini(int(atk_card["max_hp"]), int(atk_card["hp"]) + feast)
			_log("  ⟡ %s feasts on the kill — heals %d." % [str(atk_card["name"]), feast])
		if not killed and fx.has("inflict_on_hit"):
			var hcond: String = str(fx["inflict_on_hit"])
			if _apply_condition(tgt_card, hcond, fx):
				_log("  ⟡ %s is %s!" % [str(tgt_card["name"]), hcond])
		# Iron Thorn: punctures strip AC until the victim's next turn.
		if not killed and int(fx.get("ac_debuff_on_hit", 0)) > 0:
			tgt_card["ac_penalty"] = int(tgt_card.get("ac_penalty", 0)) + int(fx["ac_debuff_on_hit"])
			_recalc_character(tgt_card)
			_log("  ⟡ %s's guard is broken — AC %d." % [str(tgt_card["name"]), int(tgt_card["ac"])])
		if int(tgt_fx.get("thorns", 0)) > 0:
			var sting: int = int(tgt_fx["thorns"])
			_log("  ⟡ %s's thorns sting %s for %d." % [str(tgt_card["name"]), str(atk_card["name"]), sting])
			_damage_character(player, slot, sting, "thorns")
		# ── Dual-wield follow-up (Twin Fang / Improvised Weapon Mastery) ──
		if not is_counter and atk_card.get("offhand") != null \
				and tp["slots"][hit_slot] != null:
			if _offhand_strike(player, slot, target_player, hit_slot):
				# Both weapons landed — the signature dual-wield flourish.
				var flourish: int = int(fx.get("dual_bonus", 0))
				if flourish > 0 and tp["slots"][hit_slot] != null:
					var extra: int = _roll(1, flourish)
					_log("  🗡 Both blades bite — %d extra damage!" % extra)
					_damage_character(target_player, hit_slot, extra, "twin strike")
	return ""

## The off-hand follow-up of a dual-wielding attack. Rolls its own to-hit
## against the same victim; returns true if it connected.
## `tgt_slot` < 0 strikes the enemy PLAYER directly, mirroring the main hand.
func _offhand_strike(atk_player: int, atk_slot: int, tgt_player: int, tgt_slot: int) -> bool:
	var a = players[atk_player]["slots"][atk_slot]
	if a == null:
		return false
	var t = players[tgt_player]["slots"][tgt_slot] if tgt_slot >= 0 else null
	if tgt_slot >= 0 and t == null:
		return false
	var off = a.get("offhand")
	if off == null:
		return false
	var afx: Dictionary = _merged_feat_fx(a)
	var finesse: bool = bool(off.get("finesse", false))
	var stat_b: int = int(a["stats"][1]) if finesse else int(a["stats"][0])
	var plus: int = int(off.get("plus", 0))
	var raw: int = _roll(1, 20)
	var total: int = raw + stat_b + int(afx.get("hit_bonus", 0)) + plus
	var ac: int = player_ac(tgt_player) if tgt_slot < 0 \
		else int(t["ac"]) + _team_aura(tgt_player, "team_ac")
	if total < ac and raw < 20:
		_log("  🗡 Off-hand %s — 🎲 %d vs AC %d: miss." % [str(off["name"]), total, ac])
		return false
	var dmg: int = maxi(1, _roll(int(off["dc"]), int(off["ds"]))
		+ stat_b * maxi(1, int(afx.get("dmg_stat_mult", 1)))
		+ int(afx.get("dmg_bonus", 0)) + plus)
	_log("  🗡 Off-hand %s — 🎲 %d vs AC %d: %d damage!" % [
		str(off["name"]), total, ac, dmg])
	if tgt_slot < 0:
		players[tgt_player]["hp"] = int(players[tgt_player]["hp"]) - dmg
		players[tgt_player]["last_hit_by"] = atk_player
		_check_win()
	else:
		_damage_character(tgt_player, tgt_slot, dmg, str(a["name"]), str(off.get("dt", "")))
	return true

## A free retaliatory swing: no turn check, no AP or energy cost, and it can
## never trigger another counter. Used by Balanced Bulwark T5.
func _counterattack(def_player: int, def_slot: int, atk_player: int, atk_slot: int) -> void:
	var d = players[def_player]["slots"][def_slot]
	var a = players[atk_player]["slots"][atk_slot]
	if d == null or a == null:
		return
	var dfx: Dictionary = _merged_feat_fx(d)
	var weapon = d.get("weapon")
	var finesse: bool = weapon != null and bool(weapon.get("finesse", false))
	var stat_b: int = int(d["stats"][1]) if finesse else int(d["stats"][0])
	var plus: int = int(weapon.get("plus", 0)) if weapon != null else 0
	var raw: int = _roll(1, 20)
	var total: int = raw + stat_b + int(dfx.get("hit_bonus", 0)) + plus
	var ac: int = int(a["ac"])
	if total < ac and raw < 20:
		_log("  ⚔ %s counterattacks — 🎲 %d vs AC %d: miss." % [str(d["name"]), total, ac])
		return
	var dn: int = int(weapon["dc"]) if weapon != null else 1
	var ds: int = int(weapon["ds"]) if weapon != null else maxi(4, int(dfx.get("unarmed_die", 4)))
	var dmg: int = maxi(1, _roll(dn, ds) + stat_b + int(dfx.get("dmg_bonus", 0)) + plus)
	_log("  ⚔ %s counterattacks — 🎲 %d vs AC %d: %d damage!" % [
		str(d["name"]), total, ac, dmg])
	_damage_character(atk_player, atk_slot, dmg, "counterattack")

## Cast an equipped spell. spell_idx indexes the caster's spells array.
## Each spell fires once per round; costs the escalating action_cost.
func cast_spell(player: int, slot: int, spell_idx: int, target_player: int, target_slot: int) -> String:
	var err: String = _check_turn(player)
	if err != "":
		return err
	var p: Dictionary = players[player]
	var caster = p["slots"][slot] if slot >= 0 and slot < MAX_SLOTS else null
	if caster == null:
		return "No character in that slot."
	if spell_idx < 0 or spell_idx >= (caster["spells"] as Array).size():
		return "Invalid spell."
	var sp: Dictionary = caster["spells"][spell_idx]
	var sname: String = str(sp["name"])
	# Arcane Wellspring T5 lets each spell be cast twice per round.
	var recasts: int = 1 + int(_merged_feat_fx(caster).get("spell_recast", 0))
	if int((caster["spell_used"] as Dictionary).get(sname, 0)) >= recasts:
		return "%s already cast this round." % sname
	var cast_cost: int = action_cost(caster)
	if int(caster["ap"]) < cast_cost:
		return "%s needs %d AP for their next action." % [str(caster["name"]), cast_cost]
	var kind: String = str(sp["kind"])
	var friendly: bool = kind == "heal" or kind == "buff"
	if friendly and target_player != player:
		return "That spell targets your own characters."
	if not friendly and target_player == player:
		return "That spell targets enemies."
	if target_player < 0 or target_player >= num_players \
			or int(players[target_player]["hp"]) <= 0:
		return "That player is already out of the fight."
	var tp: Dictionary = players[target_player]
	# Collect targets: area spells hit the whole side, others need one slot.
	var target_slots: Array = []
	if int(sp["area"]) > 0:
		for i in range(MAX_SLOTS):
			if tp["slots"][i] != null:
				target_slots.append(i)
		if target_slots.is_empty():
			return "No valid targets."
	else:
		var tc = tp["slots"][target_slot] if target_slot >= 0 and target_slot < MAX_SLOTS else null
		if tc == null:
			return "Pick a target character."
		target_slots = [target_slot]
	caster["ap"] = int(caster["ap"]) - cast_cost
	caster["acts"] = int(caster.get("acts", 0)) + 1
	caster["spell_used"][sname] = int((caster["spell_used"] as Dictionary).get(sname, 0)) + 1
	var cfx: Dictionary = _merged_feat_fx(caster)
	var spower: int = int(cfx.get("spell_power", 0))
	_award_xp(player, slot, caster)
	_log("%s casts %s!" % [str(caster["name"]), sname])
	card_event.emit("cast", {"player": player, "slot": slot, "spell": sname,
		"kind": kind, "target_player": target_player, "targets": target_slots.duplicate()})
	for ts in target_slots:
		var tc = tp["slots"][ts]
		if tc == null:
			continue
		match kind:
			"heal":
				var h: int = _roll(int(sp["dc"]), int(sp["ds"])) + spower
				# Iron Vitality T3+: healing RECEIVED is increased by VIT.
				var tfx2: Dictionary = _merged_feat_fx(tc)
				if int(tfx2.get("heal_vit", 0)) > 0:
					h += int(tc["stats"][3]) * int(tfx2["heal_vit"])
				tc["hp"] = mini(int(tc["max_hp"]), int(tc["hp"]) + h)
				_log("  %s is healed for %d (%dd%d)." % [
					str(tc["name"]), h, int(sp["dc"]), int(sp["ds"])])
				card_event.emit("heal", {"player": target_player, "slot": ts, "amount": h, "source": sname})
			"damage":
				var dmg: int = _roll(int(sp["dc"]), int(sp["ds"])) + spower
				var roll_note: String = ""
				if bool(sp["atk"]):
					var sm: int = spell_mod(caster)   # DIV + Magic Expertise etc.
					var raw: int = _roll(1, 20)
					var total: int = raw + sm
					# Spell Shaper T2+: one missed spell per round may be rerolled.
					if total < int(tc["ac"]) and raw < 20 \
							and int(cfx.get("spell_reroll", 0)) > 0 \
							and not bool(caster.get("spell_reroll_used", false)):
						caster["spell_reroll_used"] = true
						raw = _roll(1, 20)
						total = raw + sm
						_log("  ↻ %s reshapes the spell — rerolled." % str(caster["name"]))
					# Spell Shaper T3: the first spell each round cannot be resisted.
					var pierced: bool = int(cfx.get("spell_pierce", 0)) > 0 \
						and not bool(caster.get("spell_pierce_used", false))
					if total < int(tc["ac"]) and raw < 20 and not pierced:
						_log("  🎲 %d%+d = %d vs %s's AC %d — resisted!" % [
							raw, sm, total, str(tc["name"]), int(tc["ac"])])
						continue
					if pierced and total < int(tc["ac"]) and raw < 20:
						caster["spell_pierce_used"] = true
						_log("  ✦ The spell pierces %s's defenses regardless." % str(tc["name"]))
					roll_note = "🎲 %d%+d = %d vs AC %d — " % [raw, sm, total, int(tc["ac"])]
				_apply_spell_conds(tc, sp, cfx)
				_log("  %s%s takes %d (%dd%d)." % [
					roll_note, str(tc["name"]), dmg, int(sp["dc"]), int(sp["ds"])])
				_damage_character(target_player, ts, dmg, sname, str(sp.get("dt", "")))
			"buff":
				_apply_spell_conds(tc, sp)
				_recalc_character(tc)
				_log("  %s gains %s." % [str(tc["name"]), ", ".join(PackedStringArray(sp["conds"]))])
			"debuff":
				var curse_note: String = ""
				if bool(sp["atk"]):
					var raw2: int = _roll(1, 20)
					var total2: int = raw2 + int(caster["stats"][4])
					if total2 < int(tc["ac"]) and raw2 < 20:
						_log("  🎲 %d%+d = %d vs %s's AC %d — the curse is resisted!" % [
							raw2, int(caster["stats"][4]), total2, str(tc["name"]), int(tc["ac"])])
						continue
					curse_note = "🎲 %d%+d = %d vs AC %d — " % [
						raw2, int(caster["stats"][4]), total2, int(tc["ac"])]
				_apply_spell_conds(tc, sp)
				_log("  %s%s suffers %s." % [
					curse_note, str(tc["name"]), ", ".join(PackedStringArray(sp["conds"]))])
		if winner >= 0:
			return ""
	return ""

func _apply_spell_conds(tc: Dictionary, sp: Dictionary, src_fx: Dictionary = {}) -> void:
	for c in sp.get("conds", []):
		_apply_condition(tc, str(c), src_fx)

## Land a condition on a card unless it is immune (lineage/feat) or shrugs it
## off with Safeguard's ward (d20 + ward vs 12). `src_fx` is the INFLICTER's
## merged fx — Effect Shaper's potency weakens the ward, and its cond_extend
## makes what lands stick around longer. Returns true if it stuck.
func _apply_condition(tc: Dictionary, cond: String, src_fx: Dictionary = {}) -> bool:
	var fx: Dictionary = _merged_feat_fx(tc)
	if (fx.get("cond_immune", []) as Array).has(cond):
		_log("  ⟡ %s is immune to %s." % [str(tc["name"]), cond])
		return false
	var ward: int = int(fx.get("cond_ward", 0)) - int(src_fx.get("cond_potency", 0))
	if ward > 0:
		var roll: int = _roll(1, 20)
		if roll + ward >= 12:
			_log("  🛡 %s wards off %s (🎲 %d+%d)." % [str(tc["name"]), cond, roll, ward])
			if int(fx.get("ward_heal", 0)) > 0:
				var h: int = int(tc.get("level", 1))
				tc["hp"] = mini(int(tc["max_hp"]), int(tc["hp"]) + h)
				_log("    …and recovers %d HP." % h)
			return false
	tc["conds"][cond] = int(COND_DURATION.get(cond, 2)) + int(src_fx.get("cond_extend", 0))
	return true

## Strongest value of `key` among a player's characters in play. Team auras
## (Wall of the Battered's +AC, its ward against attacks on allies) take the
## best source rather than summing, so stacking protectors can't run away.
func _team_aura(player: int, key: String) -> int:
	var best: int = 0
	for c in players[player]["slots"]:
		if c != null:
			best = maxi(best, int(_merged_feat_fx(c).get(key, 0)))
	return best

## A living character on `player`'s side who can throw themselves in front of
## the card in `slot` this round, or -1. Never the target themselves.
func _find_protector(player: int, slot: int) -> int:
	for i in range(MAX_SLOTS):
		if i == slot:
			continue
		var c = players[player]["slots"][i]
		if c == null or bool(c.get("protect_used", false)):
			continue
		if int(_merged_feat_fx(c).get("protect_ally", 0)) > 0:
			return i
	return -1

# ══════════════════════════════════════════════════════════════════════════
#  Damage, XP, death, victory
# ══════════════════════════════════════════════════════════════════════════

func _damage_character(player: int, slot: int, dmg: int, source: String,
		dt: String = "") -> void:
	var p: Dictionary = players[player]
	var c = p["slots"][slot]
	if c == null:
		return
	var tfx: Dictionary = _merged_feat_fx(c)
	# ── Elemental wards: immunity zeroes it, resistance halves it ────────
	if dt != "" and ELEMENTAL_TYPES.has(dt):
		if int(tfx.get("immune_elemental", 0)) > 0:
			_log("  ⟡ %s is immune to %s damage!" % [str(c["name"]), dt])
			return
		if int(tfx.get("resist_elemental", 0)) > 0:
			dmg = maxi(1, dmg / 2)
			_log("  ⟡ %s resists the %s — halved to %d." % [str(c["name"]), dt, dmg])
	# Damage reduction (Stoneskin / Iron Hide / Titanic Bastion / …).
	# Capped so stacked sources can never make a card untouchable.
	var red: int = mini(DR_CAP, int(tfx.get("dr", 0)))
	# Unarmored Master: additionally soak 1d4 per point of SPD.
	if int(tfx.get("dr_spd", 0)) > 0:
		red += _roll(int(c["stats"][1]), 4)
	# Deflective Stance T3: shrug off damage equal to your SPD.
	if int(tfx.get("dr_stat", 0)) > 0:
		red += int(c["stats"][1]) * int(tfx["dr_stat"])
	if red > 0 and dmg > 0:
		var soaked: int = mini(red, dmg)
		dmg -= soaked
		if dmg <= 0:
			_log("  ⟡ %s's hide shrugs off the %s entirely!" % [str(c["name"]), source])
			return
	c["hp"] = int(c["hp"]) - dmg
	# Cheat-death traits (Nine Lives / Resilient Spirit): once per match.
	if int(c["hp"]) <= 0 and int(tfx.get("cheat_death", 0)) > 0 \
			and not bool(c.get("cheat_death_used", false)):
		c["cheat_death_used"] = true
		c["hp"] = 1
		_log("  ⟡ %s cheats death and stands at 1 HP!" % str(c["name"]))
		card_event.emit("damage", {"player": player, "slot": slot, "amount": dmg, "source": source})
		return
	card_event.emit("damage", {"player": player, "slot": slot, "amount": dmg, "source": source})
	if int(c["hp"]) <= 0:
		p["slots"][slot] = null
		if bool(c.get("is_token", false)):
			# Summoned things dissipate — never a card to reclaim.
			_log("💨 %s dissipates." % str(c["name"]))
			card_event.emit("death", {"player": player, "slot": slot, "card": c})
			return
		_restore_card(c)   # graveyard cards heal — they may cycle back into play
		p["graveyard"].append(c)
		_log("💀 %s falls!" % str(c["name"]))
		card_event.emit("death", {"player": player, "slot": slot, "card": c})

## Attribute names, indexed like the stats array [STR, SPD, INT, VIT, DIV].
const STAT_NAMES := ["STR", "SPD", "INT", "VIT", "DIV"]

## Award one stat point. Cards set to "manual" bank it for the player to
## place on their turn; "auto" cards spend it immediately on their strongest
## stat under STAT_CAP. When every stat is maxed the point has nowhere to go,
## so the card gains +10 permanent HP instead.
func _grant_stat_point(card: Dictionary) -> void:
	if str(card.get("stat_mode", "auto")) == "manual" and not _stats_all_capped(card):
		card["stat_pts"] = int(card.get("stat_pts", 0)) + 1
		return
	var stats: Array = card["stats"]
	var best: int = -1
	for i in range(5):
		if int(stats[i]) >= STAT_CAP:
			continue
		if best < 0 or int(stats[i]) > int(stats[best]):
			best = i
	if best >= 0:
		stats[best] = int(stats[best]) + 1
	else:
		card["bonus_hp"] = int(card.get("bonus_hp", 0)) + 10

## True when every attribute sits at STAT_CAP (further points become HP).
func _stats_all_capped(card: Dictionary) -> bool:
	for v in card["stats"]:
		if int(v) < STAT_CAP:
			return false
	return true

## Switch a character between automatic and manual attribute assignment.
## Flipping to auto immediately spends any points already banked.
func set_stat_mode(player: int, slot: int, mode: String) -> String:
	var err: String = _check_turn(player)
	if err != "":
		return err
	if mode not in ["auto", "manual"]:
		return "Invalid mode."
	var c = players[player]["slots"][slot] if slot >= 0 and slot < MAX_SLOTS else null
	if c == null:
		return "No character in that slot."
	c["stat_mode"] = mode
	if mode == "auto":
		var banked: int = int(c.get("stat_pts", 0))
		c["stat_pts"] = 0
		for i in range(banked):
			_grant_stat_point(c)   # mode is auto now, so these place instantly
		if banked > 0:
			_recalc_character(c)
			_log("%s auto-assigns %d banked point(s)." % [str(c["name"]), banked])
	return ""

## Spend one banked attribute point on `stat_idx` (0 STR … 4 DIV).
func assign_stat_point(player: int, slot: int, stat_idx: int) -> String:
	var err: String = _check_turn(player)
	if err != "":
		return err
	var c = players[player]["slots"][slot] if slot >= 0 and slot < MAX_SLOTS else null
	if c == null:
		return "No character in that slot."
	if int(c.get("stat_pts", 0)) <= 0:
		return "%s has no attribute points to spend." % str(c["name"])
	if stat_idx < 0 or stat_idx > 4:
		return "Invalid attribute."
	if int(c["stats"][stat_idx]) >= STAT_CAP:
		return "%s is already at the cap of %d." % [str(STAT_NAMES[stat_idx]), STAT_CAP]
	c["stat_pts"] = int(c["stat_pts"]) - 1
	c["stats"][stat_idx] = int(c["stats"][stat_idx]) + 1
	_recalc_character(c)
	_log("%s puts a point into %s (now %d)." % [
		str(c["name"]), str(STAT_NAMES[stat_idx]), int(c["stats"][stat_idx])])
	card_event.emit("stat_spent", {"player": player, "slot": slot})
	return ""

## Grasp of the Forgotten: a summoner entering play brings spectral escorts
## into empty slots. Tokens fight and die like characters but never enter a
## deck, hand or graveyard — when they fall they simply dissipate.
func _summon_tokens(player: int, summoner: Dictionary) -> void:
	var fx: Dictionary = _merged_feat_fx(summoner)
	var count: int = int(fx.get("summon_token", 0))
	if count <= 0:
		return
	var lv: int = int(summoner.get("level", 1))
	var hp: int = maxi(1, lv * maxi(1, int(fx.get("token_hp_mult", 1))))
	var strong: bool = int(fx.get("token_strong", 0)) > 0
	for i in range(count):
		var free_slot: int = -1
		for s in range(MAX_SLOTS):
			if players[player]["slots"][s] == null:
				free_slot = s
				break
		if free_slot < 0:
			return
		var tok: Dictionary = {
			"id": _new_id(), "ctype": "character", "is_token": true,
			"name": "Spectral Servant" if strong else "Spectral Hand",
			"lineage": "Aetherian", "region": "",
			"level": lv, "xp": 0, "xp_req": 9999,
			"stats": [2 if strong else 1, 2, 0, 1, 0],
			"weapon": null, "offhand": null, "armor": null, "shield": null,
			"feats": [], "spells": [], "traits": [],
			"conds": {}, "spell_used": {}, "acts": 0,
			"stat_mode": "auto", "stat_pts": 0, "kills": 0,
			"hp": hp, "max_hp": hp,
			"ap": 3, "max_ap": 3, "sp": 0, "max_sp": 0,
			"ac": int(fx.get("token_ac", 10)),
			"played_round": round_num,
		}
		players[player]["slots"][free_slot] = tok
		_log("  ✋ %s calls forth a %s." % [str(summoner["name"]), str(tok["name"])])
		card_event.emit("play", {"player": player, "slot": free_slot, "card": tok})

## Reset a fallen character card to a fresh state. Cards that cycle back
## through the graveyard (gauntlet reclaims, future resurrection effects)
## must return at full HP with a clean slate, not below zero.
func _restore_card(c: Dictionary) -> void:
	if str(c.get("ctype", "")) != "character":
		return
	c["conds"] = {}
	c["spell_used"] = {}
	c["acts"] = 0
	c["cheat_death_used"] = false
	c.erase("played_round")
	_recalc_character(c, true)   # hp/ap back to max

## XP per action; level up on the PHB curve (10, 20, 40 … cap 1000).
func _award_xp(player: int, slot: int, card: Dictionary) -> void:
	if int(card["level"]) >= LEVEL_CAP:
		return
	# Scholarly lineages (Versatile / Deep Lore / …) learn faster.
	card["xp"] = int(card["xp"]) + XP_PER_ACTION \
		+ int(_merged_feat_fx(card).get("xp_bonus", 0))
	while int(card["xp"]) >= int(card["xp_req"]) and int(card["level"]) < LEVEL_CAP:
		card["xp"] = int(card["xp"]) - int(card["xp_req"])
		card["level"] = int(card["level"]) + 1
		card["xp_req"] = _xp_required(int(card["level"]))
		# PHB grants +1 stat point per level — auto-assigned to the card's
		# strongest stat under the cap (overflow becomes bonus HP).
		_grant_stat_point(card)
		_recalc_character(card)   # growth heals by the HP delta
		_log("⭐ %s reaches level %d!" % [str(card["name"]), int(card["level"])])
		card_event.emit("level_up", {"player": player, "slot": slot, "card": card})

func _xp_required(level: int) -> int:
	var shift: int = mini(maxi(1, level) - 1, 30)
	return mini(1000, 10 * (1 << shift))

## AC for direct attacks at a player: 10 + 2 per character card in play.
## Board presence is the player's armor — every defender counts double.
func player_ac(seat_idx: int) -> int:
	return PLAYER_BASE_AC + 2 * _living_characters(seat_idx)

func _living_characters(player: int) -> int:
	var n: int = 0
	for c in players[player]["slots"]:
		if c != null:
			n += 1
	return n

func _check_win() -> void:
	if winner >= 0:
		return
	# Eliminate any player who just fell: their army leaves the field.
	for i in range(num_players):
		var p: Dictionary = players[i]
		if int(p["hp"]) <= 0 and not bool(p.get("eliminated", false)):
			p["eliminated"] = true
			for s in range(MAX_SLOTS):
				if p["slots"][s] != null:
					_restore_card(p["slots"][s])
					p["graveyard"].append(p["slots"][s])
					p["slots"][s] = null
			_log("☠ %s is defeated — their army leaves the field!" % str(p["name"]))
			card_event.emit("eliminated", {"player": i, "name": str(p["name"])})
			# Gauntlet: defeated AIs are a score, not a win — a fresh
			# challenger takes their seat in two rounds.
			if gauntlet and is_ai_seat(i):
				gauntlet_kills += 1
				respawn_due[i] = round_num + 2
				_log("🏆 Enemy defeated (%d total)! A new challenger arrives in 2 rounds." % gauntlet_kills)
				# Spoils of war: whoever landed the killing blow shuffles up
				# to 10 cards from their own graveyard back into their DECK,
				# replenishing what they'll draw as the run grinds on.
				var killer: int = clampi(int(p.get("last_hit_by", 0)), 0, num_players - 1)
				var kp: Dictionary = players[killer]
				if int(kp["hp"]) > 0:
					var got: int = 0
					while got < 10 and not (kp["graveyard"] as Array).is_empty():
						kp["deck"].append(kp["graveyard"].pop_back())
						got += 1
					if got > 0:
						(kp["deck"] as Array).shuffle()
						_log("🎁 %s shuffles %d card(s) from the graveyard back into their deck!" % [
							str(kp["name"]), got])
	if gauntlet:
		# The run only ends when the human falls; empty-field lulls while
		# every challenger seat waits on a respawn are a breather, not a win.
		if int(players[0]["hp"]) <= 0:
			winner = 1 if num_players > 1 else 0
			for i in range(1, num_players):
				if int(players[i]["hp"]) > 0:
					winner = i
					break
			_log("🌊 The gauntlet claims %s — %d enemies defeated over %d rounds." % [
				str(players[0]["name"]), gauntlet_kills, round_num])
			card_event.emit("victory", {"winner": winner, "name": str(players[winner]["name"]),
				"gauntlet": true, "kills": gauntlet_kills, "rounds": round_num,
				"runner": str(players[0]["name"])})
		return
	# Last player standing takes the match.
	var alive: Array = []
	for i in range(num_players):
		if int(players[i]["hp"]) > 0:
			alive.append(i)
	if alive.size() == 1:
		winner = int(alive[0])
		_log("🏆 %s wins the match!" % str(players[winner]["name"]))
		card_event.emit("victory", {"winner": winner, "name": str(players[winner]["name"])})

func _roll(dice: int, sides: int) -> int:
	var total: int = 0
	for i in range(maxi(0, dice)):
		total += _rng.randi_range(1, maxi(1, sides))
	return total

## Damage roll that rerolls any die showing a 1 (Weapon Mastery T2+).
func _roll_reroll_ones(dice: int, sides: int) -> int:
	var total: int = 0
	for i in range(maxi(0, dice)):
		var r: int = _rng.randi_range(1, maxi(1, sides))
		if r == 1:
			r = _rng.randi_range(1, maxi(1, sides))
		total += r
	return total

func _log(text: String) -> void:
	match_log.append(text)
	if match_log.size() > 120:
		match_log = match_log.slice(match_log.size() - 120)

# ══════════════════════════════════════════════════════════════════════════
#  AI opponents — any AI seat plays through the same public API as a human,
#  real delays between actions so the enemy turn is watchable live. Every
#  move emits the usual card_event signals, so the board updates as it acts.
# ══════════════════════════════════════════════════════════════════════════

## Build a legal 20-card deck for the AI from a fresh region pool.
func build_ai_deck(region_id: String) -> Array:
	var pool: Array = generate_pool(region_id)
	var deck: Array = []
	var want: Dictionary = {"character": 21, "weapon": 12, "armor": 7,
		"shield": 4, "spell": 8, "feat": 8}
	for c in pool:
		var key: String = str(c["ctype"])
		if key == "equipment":
			key = str(c["slot"])
		if int(want.get(key, 0)) > 0:
			want[key] = int(want[key]) - 1
			deck.append(c)
	# Pool composition guarantees a full deck, but top up defensively.
	for c in pool:
		if deck.size() >= DECK_SIZE:
			break
		if not deck.has(c):
			deck.append(c)
	# The AI has nobody to hand-place attribute points, so its cards always
	# spend them automatically (players default to manual).
	for c in deck:
		if str(c.get("ctype", "")) == "character":
			c["stat_mode"] = "auto"
	return deck

## Guard for the async driver: still this seat's live AI turn?
func _ai_active(seat: int) -> bool:
	return match_active and winner < 0 and turn == seat and is_ai_seat(seat)

## Async driver for one AI seat's whole turn. Triggered from _begin_turn.
func _run_ai_turn() -> void:
	if _ai_running or not is_ai_turn():
		return
	var seat: int = turn
	_ai_running = true
	var guard: int = 0
	await get_tree().create_timer(AI_ACTION_DELAY).timeout
	# ── Phase 0: over the hand limit? Shed the least valuable cards ──────
	while _ai_active(seat) and hand_over_limit(seat) and guard < 12:
		guard += 1
		_ai_discard_one(seat)
		await get_tree().create_timer(AI_ACTION_DELAY * 0.6).timeout
	# ── Phase 1: spend energy on plays and equips ────────────────────────
	while _ai_active(seat) and int(players[seat]["energy"]) > 0 and guard < 24:
		guard += 1
		if not _ai_spend_energy(seat):
			break
		await get_tree().create_timer(AI_ACTION_DELAY).timeout
	# ── Phase 2: every character acts until its AP runs dry ──────────────
	for slot in range(MAX_SLOTS):
		while _ai_active(seat) and guard < 70:
			guard += 1
			var c = players[seat]["slots"][slot]
			if c == null or not can_act(c):
				break
			if not _ai_character_act(seat, slot):
				break
			await get_tree().create_timer(AI_ACTION_DELAY).timeout
			# Easier AIs sometimes lose interest with AP still in the tank.
			if _rng.randf() < float(_ai_cfg().get("stop_chance", 0.0)):
				break
	_ai_running = false
	if _ai_active(seat):
		await get_tree().create_timer(0.5).timeout
		# end_turn is gated on a legal hand — force any stragglers out.
		var guard2: int = 0
		while _ai_active(seat) and hand_over_limit(seat) and guard2 < 12:
			guard2 += 1
			_ai_discard_one(seat)
		if _ai_active(seat):
			end_turn(seat)

## One energy-spending move for an AI seat. False when nothing remains.
func _ai_spend_energy(seat: int) -> bool:
	var p: Dictionary = players[seat]
	var hand: Array = p["hand"]
	# 1) Play the beefiest character in hand into the first empty slot.
	var empty: int = -1
	for i in range(MAX_SLOTS):
		if p["slots"][i] == null:
			empty = i
			break
	if empty >= 0:
		var char_idx: Array = []
		for i in range(hand.size()):
			if str((hand[i] as Dictionary)["ctype"]) == "character":
				char_idx.append(i)
		if not char_idx.is_empty():
			# Easier AIs grab a random character instead of the beefiest.
			if _rng.randf() < float(_ai_cfg().get("random_play", 0.0)):
				return play_character(seat,
					int(char_idx[_rng.randi() % char_idx.size()]), empty) == ""
			var best: int = int(char_idx[0])
			var best_score: int = -1
			for i in char_idx:
				var c: Dictionary = hand[i]
				var score: int = int(c["max_hp"]) + int(c["max_ap"]) + int(c["ac"])
				if score > best_score:
					best_score = score
					best = int(i)
			return play_character(seat, best, empty) == ""
	# 2) Equip the first useful card onto a board character (easier AIs
	#    sometimes can't be bothered to gear up).
	var skip_equips: bool = _rng.randf() < float(_ai_cfg().get("equip_skip", 0.0))
	for i in range(hand.size()):
		if skip_equips:
			break
		var card: Dictionary = hand[i]
		var ctype: String = str(card["ctype"])
		if ctype == "character":
			continue
		for slot in range(MAX_SLOTS):
			var t = p["slots"][slot]
			if t == null:
				continue
			match ctype:
				"equipment":
					# Only fill EMPTY slots — never burn energy re-equipping.
					if t[str(card["slot"])] == null and equip_card(seat, i, slot) == "":
						return true
				"feat":
					if feat_points_used(t) + int(card["tier"]) <= feat_budget(t) \
							and equip_card(seat, i, slot) == "":
						return true
				"spell":
					if spell_sp_used(t) + int(card["sc"]) <= int(t["max_sp"]) \
							and equip_card(seat, i, slot) == "":
						return true
	# 2b) Hard AIs re-energize a spent character (same trick players have).
	if bool(_ai_cfg().get("dig", true)):
		for slot in range(MAX_SLOTS):
			var t = p["slots"][slot]
			if t != null and not can_act(t) and int(t["ap"]) < int(t["max_ap"]):
				if refresh_ap(seat, slot) == "":
					return true
	# 3) Nothing playable — pay 1 energy to dig for a fresh card (hard only).
	if bool(_ai_cfg().get("dig", true)) \
			and not (p["deck"] as Array).is_empty() and (p["hand"] as Array).size() < HAND_MAX:
		return draw_extra(seat) == ""
	return false

## Discard the AI's least valuable hand card. Characters are hoarded;
## low-impact gear and spells go first.
func _ai_discard_one(seat: int) -> void:
	var hand: Array = players[seat]["hand"]
	if hand.is_empty():
		return
	# Easier AIs toss cards at random.
	if not bool(_ai_cfg().get("smart_discard", true)):
		discard_card(seat, _rng.randi() % hand.size())
		return
	var worst: int = 0
	var worst_score: int = 999999
	for i in range(hand.size()):
		var c: Dictionary = hand[i]
		var score: int
		match str(c["ctype"]):
			"character":
				score = 50 + int(c["max_hp"]) + int(c["max_ap"]) + int(c["ac"])
			"equipment":
				score = 10 + int(c.get("dc", 0)) * int(c.get("ds", 0)) + int(c.get("ac", 0)) * 3
			"feat":
				score = 12 + int(c.get("tier", 1)) * 3
			_:
				score = 12 + int(c.get("sc", 1))
		if score < worst_score:
			worst_score = score
			worst = i
	discard_card(seat, worst)

## One action for the AI character in `slot`. Returns false when done.
func _ai_character_act(seat: int, slot: int) -> bool:
	var p: Dictionary = players[seat]
	var c = p["slots"][slot]
	if c == null:
		return false
	# Pick which living opponent to menace this action: hard AIs finish
	# the weakest player; easier tiers (and 1v1) take whoever.
	var opps: Array = living_opponents(seat)
	if opps.is_empty():
		return false
	var human: int
	if opps.size() == 1 or _rng.randf() < float(_ai_cfg().get("random_target", 0.0)):
		human = int(opps[_rng.randi() % opps.size()])
	else:
		human = int(opps[0])
		for o in opps:
			if int(players[o]["hp"]) < int(players[human]["hp"]):
				human = int(o)
	# Easier AIs often forget they can cast at all this action.
	var casts_ok: bool = _rng.randf() < float(_ai_cfg().get("cast_chance", 1.0))
	# ── 1) Heal the most wounded ally (self included) below threshold ────
	for si in range((c["spells"] as Array).size()):
		if not casts_ok:
			break
		var sp: Dictionary = c["spells"][si]
		if str(sp["kind"]) != "heal" or spell_exhausted(c, str(sp["name"])):
			continue
		if not can_act(c):
			break
		if int(sp["area"]) > 0:
			# Area heal: worth it when two or more allies are wounded.
			var wounded: int = 0
			for i in range(MAX_SLOTS):
				var a = p["slots"][i]
				if a != null and int(a["hp"]) < int(a["max_hp"]):
					wounded += 1
			if wounded >= 2:
				return cast_spell(seat, slot, si, seat, -1) == ""
			continue
		var worst: int = -1
		var worst_ratio: float = float(_ai_cfg().get("heal_below", 0.65))
		for i in range(MAX_SLOTS):
			var ally = p["slots"][i]
			if ally == null:
				continue
			var ratio: float = float(int(ally["hp"])) / maxf(1.0, float(int(ally["max_hp"])))
			if ratio < worst_ratio:
				worst_ratio = ratio
				worst = i
		if worst >= 0:
			return cast_spell(seat, slot, si, seat, worst) == ""
	# ── 2) Offensive spell at the best enemy target ──────────────────────
	var enemy_slots: Array = []
	for i in range(MAX_SLOTS):
		if players[human]["slots"][i] != null:
			enemy_slots.append(i)
	for si in range((c["spells"] as Array).size()):
		if not casts_ok:
			break
		var sp: Dictionary = c["spells"][si]
		var kind: String = str(sp["kind"])
		if kind != "damage" and kind != "debuff":
			continue
		if spell_exhausted(c, str(sp["name"])):
			continue
		if not can_act(c) or enemy_slots.is_empty():
			break
		if int(sp["area"]) > 0 and enemy_slots.size() >= 2:
			return cast_spell(seat, slot, si, human, -1) == ""
		var tgt: int = int(enemy_slots[0])
		var tgt_hp: int = 999
		for i in enemy_slots:
			var e = players[human]["slots"][i]
			if int(e["hp"]) < tgt_hp:
				tgt_hp = int(e["hp"])
				tgt = int(i)
		if int(sp["area"]) > 0:
			return cast_spell(seat, slot, si, human, -1) == ""
		return cast_spell(seat, slot, si, human, tgt) == ""
	# ── 3) Weapon attack: finish kills, else the squishiest, else face ───
	if not can_act(c):
		return false
	if int(c.get("played_round", -1)) == round_num:
		return false          # summoning sickness — attacks unlock next round
	var avg_dmg: int = 2 + int(c["stats"][0])            # unarmed baseline
	var weapon = c.get("weapon")
	if weapon != null:
		avg_dmg = int(weapon["dc"]) * (int(weapon["ds"]) + 1) / 2
		avg_dmg += int(c["stats"][1]) if bool(weapon.get("finesse", false)) else int(c["stats"][0])
	if enemy_slots.is_empty() \
			or (bool(_ai_cfg().get("lethal_face", true)) and int(players[human]["hp"]) <= avg_dmg):
		if int(players[seat]["energy"]) < 1:
			return false          # face attacks cost 1 energy — can't afford
		return attack(seat, slot, human, -1) == ""
	# Easier AIs swing at whoever — no kill-securing instincts.
	if _rng.randf() < float(_ai_cfg().get("random_target", 0.0)):
		return attack(seat, slot, human,
			int(enemy_slots[_rng.randi() % enemy_slots.size()])) == ""
	var pick: int = int(enemy_slots[0])
	var pick_hp: int = 999
	for i in enemy_slots:
		var e = players[human]["slots"][i]
		if int(e["hp"]) <= avg_dmg:
			pick = int(i)      # likely kill — take it
			break
		if int(e["hp"]) < pick_hp:
			pick_hp = int(e["hp"])
			pick = int(i)
	return attack(seat, slot, human, pick) == ""

# ══════════════════════════════════════════════════════════════════════════
#  UI helpers
# ══════════════════════════════════════════════════════════════════════════

## One-line summary for card list rows.
func card_summary(card: Dictionary) -> String:
	match str(card["ctype"]):
		"character":
			var s: Array = card["stats"]
			return "Lv%d %s — HP %d  AP %d  SP %d  AC %d  (S%d P%d I%d V%d D%d)" % [
				int(card["level"]), str(card["lineage"]), int(card["max_hp"]),
				int(card["max_ap"]), int(card["max_sp"]), int(card["ac"]),
				int(s[0]), int(s[1]), int(s[2]), int(s[3]), int(s[4])]
		"equipment":
			var plus_txt: String = ""
			if int(card.get("plus", 0)) > 0:
				plus_txt = " (+%d to hit and damage)" % int(card["plus"]) \
					if str(card.get("slot", "")) == "weapon" \
					else " (+%d AC)" % int(card["plus"])
			return "%s — %s%s" % [str(card["slot"]).capitalize(),
				str(card.get("desc", "")), plus_txt]
		"feat":
			return str(card.get("desc", ""))
		"spell":
			return str(card.get("desc", ""))
	return ""

## Display name for a card — gear shows its enchantment ("Longsword +2").
func card_title(card: Dictionary) -> String:
	var n: String = str(card.get("name", "?"))
	if int(card.get("plus", 0)) > 0:
		n += " +%d" % int(card["plus"])
	return n

## Emoji glyph for a card type (board + hand rendering).
func card_glyph(card: Dictionary) -> String:
	match str(card["ctype"]):
		"character": return "🧙"
		"equipment":
			match str(card["slot"]):
				"weapon": return "⚔"
				"armor":  return "🛡"
				"shield": return "🛡"
			return "🎒"
		"feat":  return "★"
		"spell": return "✦"
	return "🂠"
