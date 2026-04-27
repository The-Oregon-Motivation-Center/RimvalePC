## kaiju_system.gd
## Canonical Kaiju Creator data + formulas, matching the game's Kaiju Creator
## spec. This is the single source of truth for Kaiju stats, abilities,
## resistances, and the scaling rules unique to Kaiju. All other code that
## references Kaiju (GameState.KAIJU_RECRUITS, world.gd::DD_KAIJUS, the C++
## Dungeon.h::kaiju_defs) should read from or stay consistent with this file.
##
## Core rules from the spec:
##   HP = 10 × Level + VIT               (feats may override — see Iron Vitality)
##   AP = 10 + Level + STR
##   SP = 10 + Level + DIV
##   Threat Points = Level               (abilities + feats cost 1 TP each)
##   Damage Threshold = Level            (ignore damage below this; only excess hits HP)
##   Legendary Resistance = VIT / short rest
##   Movement = 40 ft per SPD point       (2× normal)
##   Area attacks double in radius every 5 levels (5 → 10 → 20 → 40 → 80 ft)
##   Multi-target single attack: +1 target per 5 levels, each within 15 ft
##   Collateral: Kaiju ignore damage thresholds vs. structures (buildings, ships)
##   Stats may exceed 10; raising a stat above 5 costs 1 point per point
##   Footprint: Small/Medium = 1 tile; each tier above doubles (Large 2, Huge 4,
##              Gargantuan 8, Colossal 16). Kaiju default to Colossal (4×4).
class_name KaijuSystem
extends RefCounted

const _CreatureSize = preload("res://autoload/creature_size.gd")

# ══════════════════════════════════════════════════════════════════════════════
# CANONICAL KAIJU DEFINITIONS
# ══════════════════════════════════════════════════════════════════════════════
## Each entry matches a stat block from the Kaiju Creator spec exactly.
## Fields:
##   id              snake_case stable identifier
##   name            display name
##   title           flavorful subtitle ("the Living Volcano")
##   theme           "Volcanic Titan", "Primal Simian", etc.
##   origin          one-line origin description
##   region          canonical region map(s) this Kaiju haunts
##   level           integer level (spec recommends 10+)
##   stats           STR/SPD/INT/VIT/DIV dict
##   ac              armor class
##   hp              computed HP (use `compute_hp(def)` for the formula-correct value)
##   threshold       damage threshold (= level by default; override if feat says so)
##   immunities      Array[String] — damage types + conditions fully ignored
##   resistances     Array[String] — damage types halved
##   conditional     Array[Dictionary] — { type:String, condition:String, effect:"resist"|"immune" }
##   abilities       Array[Dictionary] — { name, ap, sp, desc }
##   feats           Array[Dictionary] — { name, tier, desc } (each costs 1 TP)
##   size            "Colossal"
##   height_ft       approx height, always ≥ 50
##   recruit_cost    { gold:int, rf:int } — what it takes to recruit
##   description     long-form flavor
const KAIJU_DEFS: Array = [
	# ──────────────────────────────────────────────────────────────────────────
	# 0: Pyroclast, the Living Volcano
	# ──────────────────────────────────────────────────────────────────────────
	{
		"id": "pyroclast",
		"name": "Pyroclast",
		"title": "the Living Volcano",
		"theme": "Volcanic Titan",
		"origin": "Born from Rimvale's deepest magma chamber, awakened by resonant eruptions.",
		"region": "Vulcan Valley",
		"level": 12,
		"stats": {"str": 8, "spd": 3, "int": 2, "vit": 8, "div": 5},
		"ac": 13,
		"hp": 136,  # 10*12 + (VIT*2, boosted by Iron Vitality Tier 1)
		"threshold": 12,
		"immunities": ["fire", "burn"],
		"resistances": ["thunder", "non-magical physical", "ranged", "cold", "acid"],
		"conditional": [],
		"abilities": [
			{"name": "Magma Breath", "ap_cost": 1, "sp_cost": 0,
				"desc": "Xd6 fire damage to a target within 30 ft (X = AP spent). 10 ft cube; +10 ft per 5 AP."},
			{"name": "Molten Hide", "ap_cost": 0, "sp_cost": 0,
				"desc": "Passive. Melee attackers take 1d6 fire damage on hit."},
			{"name": "Earthquake", "ap_cost": 0, "sp_cost": 0,
				"desc": "While moving, creatures within 30 ft must SPD save (DC 10+STR) or fall prone. Every 5 ft = new save."},
			{"name": "Regeneration", "ap_cost": 0, "sp_cost": 0,
				"desc": "Passive. Regenerates 2d6 HP at start of turn."},
			{"name": "Legendary Resistance", "ap_cost": 0, "sp_cost": 0,
				"desc": "Auto-succeed on a save, VIT (8) times per short rest."},
			{"name": "Leap", "ap_cost": 3, "sp_cost": 0,
				"desc": "Jump up to 100 ft. Creatures within 30 ft on landing save (DC 10+STR) or fall prone + 3d6 damage."},
			{"name": "Enhanced Explosive Mix", "ap_cost": 0, "sp_cost": 4,
				"desc": "30 ft radius: 6d6 fire + 3d6 thunder, reroll 1s. DIV scales radius further."},
			{"name": "Amphibious", "ap_cost": 1, "sp_cost": 0,
				"desc": "Max AP -2 while active. Breathe underwater."},
		],
		"feats": [
			{"name": "Iron Vitality Tier 1", "tier": 1,
				"desc": "HP becomes (2 × VIT) + (3 × Level) + 3. Once per encounter at ≤½ HP, gain bonus HP = VIT."},
			{"name": "Iron Vitality Tier 3", "tier": 3,
				"desc": "When healed from any source, increase the amount by VIT. Once per long rest: saving against condition → regain HP = Level."},
			{"name": "Precise Tactician I", "tier": 1,
				"desc": "Crit on 19–20. Once per encounter, reroll a failed attack (must use new result)."},
			{"name": "Precise Tactician II", "tier": 2,
				"desc": "Crit on 18–20. On crit, gain 2 AP immediately."},
		],
		"size": "Colossal",
		"height_ft": 60,
		"recruit_cost": {"gold": 2000, "rf": 10},
		"description":
"A titanic, reptilian beast whose jagged, obsidian scales glow with molten veins. Pyroclast rises from the earth's crust trailing plumes of ash and fire, its thunderous footsteps shaking the land. When enraged, it unleashes torrents of magma from maw and spiked tail, incinerating everything in its path. Drawn to sources of energy and conflict, it often appears during volcanic eruptions or great battles. Its roar echoes like an earthquake, and its presence signals devastation and rebirth — where Pyroclast walks, the world is remade in fire.",
	},

	# ──────────────────────────────────────────────────────────────────────────
	# 1: Grondar, the Mountain King
	# ──────────────────────────────────────────────────────────────────────────
	{
		"id": "grondar",
		"name": "Grondar",
		"title": "the Mountain King",
		"theme": "Primal Titan / Simian Warlord",
		"origin": "Ancient jungle highlands, worshipped as a god by lost tribes.",
		"region": "Wilds of Endero",  # verdant peaks and forgotten valleys
		"level": 13,
		"stats": {"str": 9, "spd": 6, "int": 4, "vit": 7, "div": 3},
		"ac": 16,
		"hp": 137,  # 10*13 + 7
		"threshold": 13,
		"immunities": ["fear", "charm"],
		"resistances": ["non-magical physical", "bludgeoning", "thunder"],
		"conditional": [
			{"type": "cold", "condition": "in high altitudes", "effect": "resist"},
		],
		"abilities": [
			{"name": "Multiattack", "ap_cost": 2, "sp_cost": 0,
				"desc": "Make two basic melee attacks on this turn."},
			{"name": "Regeneration", "ap_cost": 0, "sp_cost": 0,
				"desc": "Passive. Regenerates 2d6 HP per round."},
			{"name": "Thunderous Roar", "ap_cost": 3, "sp_cost": 2,
				"desc": "Cone of thunder damage. Creatures in cone save or be stunned for 1 round."},
			{"name": "Crushing Grip", "ap_cost": 2, "sp_cost": 0,
				"desc": "Grapple. Target takes 2d8 bludgeoning per round held."},
			{"name": "Boulder Throw", "ap_cost": 2, "sp_cost": 0,
				"desc": "Hurl terrain. Ranged 60 ft, 4d10 bludgeoning."},
			{"name": "Leap", "ap_cost": 3, "sp_cost": 0,
				"desc": "Jump up to 100 ft. Causes Earthquake on landing."},
			{"name": "Earthquake", "ap_cost": 0, "sp_cost": 0,
				"desc": "After Leap lands, creatures within 60 ft save SPD (DC 10+STR) or fall prone."},
			{"name": "Legendary Resistance", "ap_cost": 0, "sp_cost": 0,
				"desc": "Auto-succeed on a save, VIT (7) times per short rest."},
			{"name": "Terrain Manipulation", "ap_cost": 2, "sp_cost": 0,
				"desc": "Throw boulders, uproot trees. Creates difficult terrain or cover."},
			{"name": "Climb", "ap_cost": 1, "sp_cost": 0,
				"desc": "Climbs any surface at full movement speed."},
		],
		"feats": [
			{"name": "Iron Vitality Tier 2", "tier": 2,
				"desc": "Once per long rest when reduced to 0 HP, stay at 1 HP instead if not outright killed."},
		],
		"size": "Colossal",
		"height_ft": 80,
		"recruit_cost": {"gold": 2500, "rf": 12},
		"description":
"Grondar is a towering ape-like Kaiju with moss-covered fur and stone-plated arms. He rules the mountain jungles with primal fury and unmatched strength. His roar can shatter glass and stun armies, and his leaps shake the earth. Tribal legends speak of him as a guardian spirit, but modern civilization sees him as a walking catastrophe.",
	},

	# ──────────────────────────────────────────────────────────────────────────
	# 2: Thal'Zuur, the Drowned One
	# ──────────────────────────────────────────────────────────────────────────
	{
		"id": "thal_zuur",
		"name": "Thal'Zuur",
		"title": "the Drowned One",
		"theme": "Abyssal Leviathan / Eldritch God of Rot",
		"origin": "Awakened in the Hadal Trench by tectonic rupture.",
		"region": "Gloamfen Hollow",  # + deep ocean trenches, rotting shorelines
		"level": 14,
		"stats": {"str": 7, "spd": 4, "int": 6, "vit": 9, "div": 8},
		"ac": 14,
		"hp": 149,  # 10*14 + 9
		"threshold": 14,
		"immunities": ["poison", "psychic", "charm", "fear", "disease"],
		"resistances": ["cold", "acid", "magical"],
		"conditional": [
			{"type": "lightning", "condition": "while submerged", "effect": "resist"},
			{"type": "fire", "condition": "in Gloamfen Hollow", "effect": "resist"},
		],
		"abilities": [
			{"name": "Regeneration", "ap_cost": 0, "sp_cost": 0,
				"desc": "Passive. Heals 10 HP per round unless exposed to radiant or fire damage."},
			{"name": "Legendary Resistance", "ap_cost": 0, "sp_cost": 0,
				"desc": "Auto-succeed on a save, 3 times per day."},
			{"name": "Swim", "ap_cost": 0, "sp_cost": 0,
				"desc": "Passive. Ignores underwater terrain."},
			{"name": "Burrow", "ap_cost": 1, "sp_cost": 0,
				"desc": "Tunnel through seabed and soft terrain."},
			{"name": "Teleport", "ap_cost": 0, "sp_cost": 3,
				"desc": "Move through deep-sea rift or bile portal, up to 300 ft."},
			{"name": "Tentacle Barrage", "ap_cost": 3, "sp_cost": 0,
				"desc": "Multi-target melee (3 targets within 15 ft). Bludgeoning + poison damage."},
			{"name": "Abyssal Howl", "ap_cost": 3, "sp_cost": 2,
				"desc": "Cone of psychic damage. Causes confusion or fear on failed save."},
			{"name": "Digestive Bloom", "ap_cost": 2, "sp_cost": 2,
				"desc": "Release spores that mutate or dissolve organic matter in 20 ft radius."},
			{"name": "Disguise", "ap_cost": 0, "sp_cost": 2,
				"desc": "Appear as a sunken island or coral reef."},
			{"name": "Terrain Manipulation", "ap_cost": 2, "sp_cost": 1,
				"desc": "Creates bile pits, acidic bogs, or coral barricades."},
			{"name": "Weather Control", "ap_cost": 0, "sp_cost": 4,
				"desc": "Summons acidic rain, fog, or storms for 10 minutes."},
			{"name": "Toxic Cloud", "ap_cost": 2, "sp_cost": 3,
				"desc": "60 ft radius lingering poison mist — corrosion + hallucination."},
			{"name": "Rot Pulse", "ap_cost": 0, "sp_cost": 5,
				"desc": "Once per long rest. All organic matter within 60 ft decays rapidly."},
			{"name": "AP Reduction", "ap_cost": 1, "sp_cost": 0,
				"desc": "Reactive. Spend 1 AP to reduce incoming damage by 1d6."},
			{"name": "Abyssal Armor", "ap_cost": 0, "sp_cost": 0,
				"desc": "Redirect up to half damage to chitinous plating (ignores threshold once per round)."},
			{"name": "Mind Shield", "ap_cost": 0, "sp_cost": 1,
				"desc": "Contest psychic or magical effects using INT or DIV."},
		],
		"feats": [],
		"size": "Colossal",
		"height_ft": 120,
		"recruit_cost": {"gold": 3000, "rf": 15},
		"description":
"Thal'Zuur is not dead. It dreams beneath the Hollow, its thoughts leaking into the minds of the Gutborn and reshaping the land in its image. Its body is a cathedral of rot, its bile a sacrament. When it stirs, the swamp pulses. When it speaks, the air curdles. It is not a god of death — it is a god of what comes after.",
	},

	# ──────────────────────────────────────────────────────────────────────────
	# 3: Ny'Zorrak, the Starborn Maw
	# ──────────────────────────────────────────────────────────────────────────
	{
		"id": "ny_zorrak",
		"name": "Ny'Zorrak",
		"title": "the Starborn Maw",
		"theme": "Eldritch Cosmic Horror / Interdimensional Entity",
		"origin": "Emerged from a collapsing star beyond the veil of reality.",
		"region": "Arcane Collapse",  # orbiting ruins, impact craters, psychic dead zones
		"level": 15,
		"stats": {"str": 6, "spd": 5, "int": 10, "vit": 8, "div": 10},
		"ac": 15,
		"hp": 158,  # 10*15 + 8
		"threshold": 15,
		"immunities": ["psychic", "poison", "charm"],
		"resistances": ["magical", "cold", "radiant"],
		"conditional": [
			{"type": "all", "condition": "while phasing between dimensions (1 round per short rest)", "effect": "immune"},
		],
		"abilities": [
			{"name": "Legendary Resistance", "ap_cost": 0, "sp_cost": 0,
				"desc": "Auto-succeed on a save, VIT (8) times per short rest."},
			{"name": "Regeneration", "ap_cost": 0, "sp_cost": 0,
				"desc": "Passive. Regenerates 2d6 HP at start of turn."},
			{"name": "Multiattack", "ap_cost": 2, "sp_cost": 0,
				"desc": "Make two attacks. Each may target up to 3 creatures within 15 ft (level-scaled)."},
			{"name": "Flight (Telekinetic Levitation)", "ap_cost": 0, "sp_cost": 0,
				"desc": "Passive. Fly at full speed, ignoring terrain."},
			{"name": "Teleport (Interdimensional)", "ap_cost": 0, "sp_cost": 3,
				"desc": "Teleport between dimensions. 500+ ft range, no line-of-sight requirement."},
			{"name": "Mind Rend", "ap_cost": 3, "sp_cost": 2,
				"desc": "Cone of psychic damage. Causes hallucinations on failed save."},
			{"name": "Reality Warp", "ap_cost": 2, "sp_cost": 3,
				"desc": "Causes hallucinations and terrain distortion in a 30 ft radius."},
			{"name": "Disguise", "ap_cost": 0, "sp_cost": 2,
				"desc": "Appears as a celestial body or temple."},
			{"name": "Terrain Manipulation", "ap_cost": 2, "sp_cost": 2,
				"desc": "Warps gravity and space in 30 ft radius."},
			{"name": "Void Pulse", "ap_cost": 0, "sp_cost": 4,
				"desc": "Destroys all active magical effects in 60 ft radius."},
			{"name": "Starfall", "ap_cost": 4, "sp_cost": 3,
				"desc": "Summons meteors in 60 ft radius. Each meteor (3 total) deals 6d10 force."},
			{"name": "AP Reduction", "ap_cost": 1, "sp_cost": 0,
				"desc": "Reactive. Spend 1 AP to reduce damage by 1d6."},
			{"name": "Dimensional Shielding", "ap_cost": 0, "sp_cost": 0,
				"desc": "Redirect damage to shielding (ignores threshold once per round)."},
			{"name": "Mind Shield", "ap_cost": 0, "sp_cost": 1,
				"desc": "Contest magical attacks with DIV or INT."},
		],
		"feats": [],
		"size": "Colossal",
		"height_ft": 150,
		"recruit_cost": {"gold": 4000, "rf": 20},
		"description":
"Ny'Zorrak is a being of impossible geometry and unknowable intent. Its form defies physics, appearing as a writhing mass of tentacles, eyes, and void matter. It drifts silently above the earth, warping reality in its wake. Mortals who gaze upon it suffer madness, and even demigods hesitate to speak its name. Ny'Zorrak does not attack out of malice — it simply exists, and its existence is incompatible with ours.",
	},

	# ──────────────────────────────────────────────────────────────────────────
	# 4: Mirecoast Sleeper, the Tidemaker Colossus
	# ──────────────────────────────────────────────────────────────────────────
	{
		"id": "mirecoast_sleeper",
		"name": "Mirecoast Sleeper",
		"title": "the Tidemaker Colossus",
		"theme": "Prehistoric Titan / Continental Drift",
		"origin": "Woke in the mires when continental shelves rearranged.",
		"region": "Corrupted Marshes",  # + Shadows Beneath shorelines
		"level": 14,
		"stats": {"str": 10, "spd": 3, "int": 2, "vit": 10, "div": 4},
		"ac": 12,
		"hp": 150,  # 10*14 + 10
		"threshold": 14,
		"immunities": ["non-magical physical", "cold", "psychic", "prone", "stun", "fear", "charm", "drowning", "suffocation", "forced movement"],
		"resistances": ["thunder", "acid", "magical physical"],
		"conditional": [
			{"type": "lightning", "condition": "while submerged", "effect": "resist"},
		],
		"abilities": [
			{"name": "Primordial Tread", "ap_cost": 0, "sp_cost": 0,
				"desc": "Passive. Creatures within 100 ft while the Sleeper moves: SPD save (DC 10+STR=20) or fall prone + 4d6 bludgeoning + 4d6 thunder. Success = half damage, remain standing. Structures automatically take 6d6 damage."},
			{"name": "Tidal Collapse", "ap_cost": 10, "sp_cost": 0,
				"desc": "150 ft cone or 200 ft line. 8d6 bludgeoning + 8d6 cold. Creatures pushed 50 ft."},
			{"name": "Continental Wake", "ap_cost": 4, "sp_cost": 2,
				"desc": "Creatures within 300 ft make VIT save DC 24. Fail = swept away, restrained underwater. Success = prone or shoved 30 ft."},
			{"name": "Abyssal Pulse", "ap_cost": 12, "sp_cost": 0,
				"desc": "200 ft radius. 6d6 force + 6d6 thunder. Reduces to 0 HP → thrown 100 ft. Structures take max damage."},
			{"name": "Leviathan Hide", "ap_cost": 0, "sp_cost": 0,
				"desc": "Passive. Reduces all incoming damage by 14 (20 while submerged)."},
			{"name": "Tidal Regeneration", "ap_cost": 0, "sp_cost": 0,
				"desc": "Passive. Regenerates 2d6 + VIT HP at start of turn unless dealt radiant damage."},
			{"name": "Submerge", "ap_cost": 2, "sp_cost": 0,
				"desc": "Sink beneath deep water as part of movement, becoming untargetable until rising."},
			{"name": "World-Breaker Momentum", "ap_cost": 0, "sp_cost": 0,
				"desc": "Passive. Every 20 ft of straight movement creates a 10 ft trench or 30 ft pool, permanently altering terrain."},
			{"name": "Legendary Resistance", "ap_cost": 0, "sp_cost": 0,
				"desc": "Auto-succeed on a save, VIT (10) times per short rest."},
		],
		"feats": [],
		"size": "Colossal",
		"height_ft": 200,
		"recruit_cost": {"gold": 3200, "rf": 16},
		"description":
"A prehistoric titan that rises from the marshes like a drifting continent of barnacle, coral, and drowned stone. The Mirecoast Sleeper is not malicious, but its sheer scale reshapes the world with every step. Waves shatter against its shell without notice, and whole coastlines can vanish beneath its tread. Its eyes burn with tidal fire, older than the gods themselves. When the Sleeper walks, the sea follows, and the land remembers how small it is.",
	},

	# ──────────────────────────────────────────────────────────────────────────
	# 5: Aegis Ultima, the Arcane Sentinel
	# ──────────────────────────────────────────────────────────────────────────
	{
		"id": "aegis_ultima",
		"name": "Aegis Ultima",
		"title": "the Arcane Sentinel",
		"theme": "Arcane Construct / Lawbringer Mecha",
		"origin": "Forged in the Metropolitan's Spark Core for riot suppression and Kaiju-scale threats.",
		"region": "Land of Tomorrow",  # deployed from the Citadel of Enforcement
		"level": 13,
		"stats": {"str": 7, "spd": 4, "int": 6, "vit": 8, "div": 6},
		"ac": 25,  # Plate Armor (Heavy)
		"hp": 138,  # 10*13 + 8
		"threshold": 13,
		"immunities": ["force", "paralysis", "charm"],
		"resistances": ["non-magical physical", "piercing", "slashing", "thunder", "radiant"],
		"conditional": [
			{"type": "EMP", "condition": "while inside the Metropolitan", "effect": "resist"},
		],
		"piloting_requirement": "Two synchronized pilots — Gunner + Controller. With one pilot, Aegis Ultima can only move or attack (not both).",
		"spark_tank": {
			"tanks_on_vehicle": 5,
			"max_st": 15,
			"recharge_metropolitan": "2 SP restores all ST",
			"recharge_outside": "10 SP restores all ST",
			"abilities_using_st": {
				"Arcane Cannon": 2, "Disruption Blast": 4, "Bulwark Mode": 5,
				"Force Field Deployment": 3, "Ash Protocol": 2, "Teleport": 1
			}
		},
		"abilities": [
			{"name": "Multiattack", "ap_cost": 2, "sp_cost": 0,
				"desc": "Fire two arcane weapons per basic attack action."},
			{"name": "Regeneration", "ap_cost": 0, "sp_cost": 0,
				"desc": "Passive. Repairs 10 HP per round unless exposed to EMP or void damage."},
			{"name": "Legendary Resistance", "ap_cost": 0, "sp_cost": 0,
				"desc": "Auto-succeed on a save, VIT (8) times per day."},
			{"name": "Flight (Hover)", "ap_cost": 0, "sp_cost": 0,
				"desc": "Hover propulsion up to 15 MPH. Turning radius 60 ft per 45°."},
			{"name": "Teleport (Spark Rift)", "ap_cost": 0, "sp_cost": 1,
				"desc": "Short-range blink (up to 300 ft). Costs 1 Spark Tank."},
			{"name": "Arcane Baton Strike", "ap_cost": 2, "sp_cost": 0,
				"desc": "Melee. 6d6 force damage. Optional: VIT save (DC 16) or paralyze."},
			{"name": "Arcane Cannon", "ap_cost": 2, "sp_cost": 0,
				"desc": "Ranged (150/300 ft). 8d10 force damage. Costs 2 Spark Tank."},
			{"name": "Disruption Blast", "ap_cost": 0, "sp_cost": 0,
				"desc": "20 ft radius within 120 ft. VIT save DC 18 or stunned. Costs 4 Spark Tank."},
			{"name": "Force Field Deployment", "ap_cost": 0, "sp_cost": 0,
				"desc": "Grant +4 AC to allies within 30 ft for 1 round. Costs 3 Spark Tank."},
			{"name": "Bulwark Mode", "ap_cost": 0, "sp_cost": 0,
				"desc": "Deploy a 30 ft radius dome. Immunity to forced movement + 4 AC for 3 rounds. Costs 5 Spark Tank."},
			{"name": "Ash Protocol", "ap_cost": 2, "sp_cost": 0,
				"desc": "Ejects smoke. Disadvantage on perception in cloud; hostile units within 60 ft make morale checks. Costs 2 Spark Tank."},
			{"name": "Spark Tank Overdrive", "ap_cost": 0, "sp_cost": 2,
				"desc": "Restore all ST. 2 SP cost inside Metropolitan; 10 SP outside."},
			{"name": "AP Reduction", "ap_cost": 1, "sp_cost": 0,
				"desc": "Reactive. Spend 1 AP to reduce damage by 1d4."},
			{"name": "Reactive Plating", "ap_cost": 0, "sp_cost": 0,
				"desc": "Redirect up to half damage to reactive plating (ignores threshold once per round)."},
		],
		"feats": [
			{"name": "Titanic Bastion Tier 1 (Heavy Armor Training)", "tier": 1,
				"desc": "Proficiency with Heavy Armor. Advantage on checks against being pushed while in Heavy Armor."},
			{"name": "Titanic Bastion Tier 2 (Stalwart Plate)", "tier": 2,
				"desc": "In Heavy Armor: add full STR to AC. Advantage vs. knock-prone."},
			{"name": "Titanic Bastion Tier 3 (Impenetrable)", "tier": 3,
				"desc": "In Heavy Armor: resist all non-magical physical. Once per long rest at 0 HP, drop to 1 HP instead (if not outright killed)."},
		],
		"size": "Colossal",
		"height_ft": 60,
		"recruit_cost": {"gold": 2800, "rf": 14},
		"description":
"Aegis Ultima is the final word in arcane enforcement. Towering above the skyline, its body hums with stabilized Spark energy, and its limbs are etched with runes of suppression and control. Piloted by two elite enforcers — one to guide its mind, the other to command its weapons — Aegis Ultima is deployed only when the laws of reality themselves are under siege. Its presence is a warning: order will be restored.",
	},
]

# ══════════════════════════════════════════════════════════════════════════════
# FORMULAS (reusable by anywhere in the game)
# ══════════════════════════════════════════════════════════════════════════════

## HP = 10 × Level + VIT. Feats may override (Iron Vitality, etc.).
static func compute_hp(level: int, vit: int, feats: Array = []) -> int:
	# Iron Vitality Tier 1 substitutes the formula entirely.
	for f in feats:
		if typeof(f) == TYPE_DICTIONARY and str(f.get("name", "")).begins_with("Iron Vitality Tier 1"):
			return (2 * vit) + (3 * level) + 3
	return 10 * level + vit

## AP = 10 + Level + STR.
static func compute_ap(level: int, str_score: int) -> int:
	return 10 + level + str_score

## SP = 10 + Level + DIV.
static func compute_sp(level: int, div: int) -> int:
	return 10 + level + div

## Threat Points: Kaiju receive an equal number of Threat Points as their Level.
## Abilities and feats each cost 1 TP.
static func threat_points(level: int) -> int:
	return level

## Damage Threshold = Kaiju's Level by default.
static func damage_threshold(level: int) -> int:
	return level

## Legendary Resistance uses = VIT per short rest.
static func legendary_resistance_uses(vit: int) -> int:
	return vit

## Kaiju movement: 40 ft per SPD point (2× normal 20 ft).
static func movement_ft_per_speed(speed_score: int) -> int:
	return 40 * speed_score

## Area attacks double in radius every 5 levels: 5 → 10 → 20 → 40 → 80 → …
static func scaled_area_ft(level: int, base_ft: int = 5) -> int:
	var doublings: int = level / 5   # 5–9 = 0, 10–14 = 1, 15–19 = 2, 20+ = 3…
	return base_ft * int(pow(2.0, float(doublings)))

## Multi-target single attacks: +1 creature target per 5 levels (each within 15 ft).
## A level-14 Kaiju targets up to 3 creatures with a single attack.
static func multi_target_count(level: int) -> int:
	return 1 + (level / 5)

## Apply damage threshold: return the HP-removing portion of an incoming hit.
## If `damage < threshold`, returns 0 (fully ignored).
static func apply_threshold(damage: int, threshold: int, ignore_threshold: bool = false) -> int:
	if ignore_threshold:
		return damage
	if damage < threshold:
		return 0
	return damage - threshold

## Kaiju ignore damage thresholds when dealing with structures (buildings, boats).
static func kaiju_vs_structure_damage(raw_damage: int) -> int:
	return raw_damage  # passthrough — thresholds ignored by spec

# ══════════════════════════════════════════════════════════════════════════════
# QUERY HELPERS
# ══════════════════════════════════════════════════════════════════════════════

static func get_def(idx: int) -> Dictionary:
	if idx < 0 or idx >= KAIJU_DEFS.size():
		return {}
	return KAIJU_DEFS[idx]

static func get_def_by_id(kaiju_id: String) -> Dictionary:
	for k in KAIJU_DEFS:
		if str(k.get("id", "")) == kaiju_id:
			return k
	return {}

static func count() -> int:
	return KAIJU_DEFS.size()

## Resolve a kaiju def into a live stat snapshot using the spec formulas.
## Returns the full live block: stats, HP/AP/SP, threshold, LR uses, movement,
## multi-target count, scaled area ft, AND size-based footprint fields:
##   size_tile_count   total tiles (Colossal → 16)
##   footprint_tiles   Vector2i(width, height) — Colossal → (4, 4)
##   reach_ft          melee reach for that size tier
## If `size` in the def is missing, `height_ft` is used to pick the smallest
## tier that covers the Kaiju's height.
static func resolve(idx: int) -> Dictionary:
	var d: Dictionary = get_def(idx)
	if d.is_empty():
		return {}
	var s: Dictionary = d["stats"]
	var lvl: int = int(d["level"])
	var hp: int = int(d.get("hp", compute_hp(lvl, int(s["vit"]), d.get("feats", []))))

	# Resolve size tier. Prefer explicit `size` name; fall back to height_ft.
	var size_name: String = str(d.get("size", ""))
	var size_def: Dictionary = _CreatureSize.get_size(size_name) if size_name != "" else {}
	if size_def.is_empty():
		size_def = _CreatureSize.tier_for_height_ft(int(d.get("height_ft", 50)))

	return {
		"name":           d["name"],
		"title":          d.get("title", ""),
		"level":          lvl,
		"stats":          s,
		"ac":             int(d["ac"]),
		"hp":             hp,
		"max_hp":         hp,
		"ap":             compute_ap(lvl, int(s["str"])),
		"max_ap":         compute_ap(lvl, int(s["str"])),
		"sp":             compute_sp(lvl, int(s["div"])),
		"max_sp":         compute_sp(lvl, int(s["div"])),
		"threshold":      int(d.get("threshold", damage_threshold(lvl))),
		"lr_uses":        legendary_resistance_uses(int(s["vit"])),
		"move_ft":        movement_ft_per_speed(int(s["spd"])),
		"multi_target":   multi_target_count(lvl),
		"scaled_area_ft": scaled_area_ft(lvl),
		"immunities":     d.get("immunities", []),
		"resistances":    d.get("resistances", []),
		"conditional":    d.get("conditional", []),
		"abilities":      d.get("abilities", []),
		"feats":          d.get("feats", []),
		# ── Size / footprint fields ────────────────────────────────────────
		"size":              str(size_def["name"]),
		"size_id":           str(size_def["id"]),
		"size_tile_count":   int(size_def["spaces"]),                                # e.g. Colossal = 16
		"footprint_tiles":   Vector2i(int(size_def["width_tiles"]), int(size_def["height_tiles"])),  # e.g. 4×4
		"reach_ft":          int(size_def["reach_ft"]),                              # e.g. Colossal = 30 ft
		"height_ft":         int(d.get("height_ft", size_def["height_ft_min"])),
		"recruit_cost":      d.get("recruit_cost", {"gold": 2000, "rf": 10}),
	}

## Generate a procedural Kaiju at the given level using the spec formulas.
## Useful for legacy `generate_kaiju(level)` callsites; stats are distributed
## linearly (most points in STR+VIT for combat viability).
static func generate_procedural(level: int, str_score: int = -1, spd: int = -1, intel: int = -1, vit: int = -1, div: int = -1) -> Dictionary:
	# Sensible defaults: favor STR + VIT for brute Kaiju; exceeding 5 still costs 1/point
	if str_score < 0: str_score = 6 + (level / 5)
	if vit < 0:       vit       = 6 + (level / 5)
	if spd < 0:       spd       = 3 + (level / 6)
	if intel < 0:     intel     = 2 + (level / 7)
	if div < 0:       div       = 3 + (level / 7)
	var height_ft: int = 50 + level * 3
	var size_def: Dictionary = _CreatureSize.tier_for_height_ft(height_ft)
	return {
		"name":             "Kaiju Lv.%d" % level,
		"level":            level,
		"stats":            {"str": str_score, "spd": spd, "int": intel, "vit": vit, "div": div},
		"ac":               12 + (level / 2),
		"hp":               compute_hp(level, vit),
		"max_hp":           compute_hp(level, vit),
		"ap":               compute_ap(level, str_score),
		"max_ap":           compute_ap(level, str_score),
		"sp":               compute_sp(level, div),
		"max_sp":           compute_sp(level, div),
		"threshold":        damage_threshold(level),
		"lr_uses":          legendary_resistance_uses(vit),
		"move_ft":          movement_ft_per_speed(spd),
		"multi_target":     multi_target_count(level),
		"scaled_area_ft":   scaled_area_ft(level),
		"size":             str(size_def["name"]),
		"size_id":          str(size_def["id"]),
		"size_tile_count":  int(size_def["spaces"]),
		"footprint_tiles":  Vector2i(int(size_def["width_tiles"]), int(size_def["height_tiles"])),
		"reach_ft":         int(size_def["reach_ft"]),
		"height_ft":        height_ft,
		"threat_points":    threat_points(level),
	}
