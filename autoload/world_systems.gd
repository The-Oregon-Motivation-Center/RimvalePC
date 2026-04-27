## world_systems.gd
## Data and logic for World Guide + GMG systems:
## subregions, terrain effects, quests, economy, politics, hazards, bounty hunters, etc.
class_name WorldSystems
extends RefCounted

# ══════════════════════════════════════════════════════════════════════════════
# REGIONAL SUBREGIONS (WG Section 5)
# ══════════════════════════════════════════════════════════════════════════════
const SUBREGIONS: Dictionary = {
	"plains": {  # Argent Hall
		"The Argent Expanse": {"desc": "Rolling silver-grass plains stretching to the horizon.", "terrain": "grassland", "travel_days": 1, "encounter_mod": 0},
		"The Hearthlands": {"desc": "Farmsteads and trade roads connecting scattered villages.", "terrain": "farmland", "travel_days": 1, "encounter_mod": -1},
		"The Shattered Marches": {"desc": "War-scarred borderlands littered with old fortifications.", "terrain": "ruins", "travel_days": 2, "encounter_mod": 2},
	},
	"frost": {  # Frostmere
		"The Icebound Reach": {"desc": "Permanent glacial shelf where nothing grows.", "terrain": "glacier", "travel_days": 2, "encounter_mod": 1},
		"Misthollow Vale": {"desc": "Fog-shrouded valleys hiding ancient secrets.", "terrain": "valley", "travel_days": 1, "encounter_mod": 0},
		"The Embered Tundra": {"desc": "Geothermal hot springs amid ice fields.", "terrain": "tundra", "travel_days": 2, "encounter_mod": 0},
	},
	"forest": {  # Verdana
		"The Emerald Canopy": {"desc": "Dense ancient rainforest teeming with life.", "terrain": "rainforest", "travel_days": 2, "encounter_mod": 1},
		"The Thornveil": {"desc": "Overgrown ruins choked with toxic flora.", "terrain": "toxic_forest", "travel_days": 2, "encounter_mod": 2},
		"Shimmerfen": {"desc": "Bioluminescent marshland glowing in eternal twilight.", "terrain": "marsh", "travel_days": 1, "encounter_mod": 1},
	},
	"underground": {  # Shadows Beneath
		"The Hollowdeep": {"desc": "Vast cavern networks extending miles underground.", "terrain": "cavern", "travel_days": 2, "encounter_mod": 2},
		"Gloomtide Passages": {"desc": "Underground rivers carving through darkness.", "terrain": "underground_river", "travel_days": 2, "encounter_mod": 1},
		"The Fungal Expanse": {"desc": "Giant mushroom forests glowing with spore-light.", "terrain": "fungal", "travel_days": 1, "encounter_mod": 1},
	},
	"city": {  # Metropolitan
		"The Grand Bazaar District": {"desc": "The busiest trade hub in all of Rimvale.", "terrain": "urban", "travel_days": 0, "encounter_mod": -2},
		"The Spire Quarters": {"desc": "Noble estates and towers reaching toward the sky.", "terrain": "urban", "travel_days": 0, "encounter_mod": -3},
		"Ironworks Row": {"desc": "Industrial forges billowing smoke day and night.", "terrain": "industrial", "travel_days": 0, "encounter_mod": -1},
	},
	"astral": {  # Astral Tear
		"The Shattered Veil": {"desc": "Reality-warping zones where physics bends.", "terrain": "astral", "travel_days": 3, "encounter_mod": 3},
		"Starfall Basins": {"desc": "Meteorite craters glowing with residual magic.", "terrain": "crater", "travel_days": 2, "encounter_mod": 2},
		"Echoing Wastes": {"desc": "Psionic resonance fields that echo thoughts.", "terrain": "psionic", "travel_days": 2, "encounter_mod": 1},
	},
	"arena": {  # Mortal Arena
		"The Blood Sands": {"desc": "Gladiatorial battlefields stained with history.", "terrain": "arena", "travel_days": 0, "encounter_mod": 0},
		"The Proving Grounds": {"desc": "Military training camps and obstacle courses.", "terrain": "training", "travel_days": 0, "encounter_mod": -1},
		"Champion's Rest": {"desc": "Veteran settlements where retired warriors live.", "terrain": "settlement", "travel_days": 0, "encounter_mod": -2},
	},
	"throne": {  # Crimson Throne
		"The Scarlet Court": {"desc": "The political heart of the Crimson Throne.", "terrain": "palace", "travel_days": 0, "encounter_mod": -2},
		"Thornwall Keeps": {"desc": "Border fortresses defending the realm.", "terrain": "fortress", "travel_days": 1, "encounter_mod": 1},
		"The Ashen Fields": {"desc": "Scorched war zones still smoldering.", "terrain": "wasteland", "travel_days": 2, "encounter_mod": 3},
	},
	"islands": {  # Wandering Isles
		"Driftwood Harbors": {"desc": "Floating ports built on reclaimed wreckage.", "terrain": "harbor", "travel_days": 1, "encounter_mod": 0},
		"Coral Spire Archipelago": {"desc": "Underwater ruins rising from coral formations.", "terrain": "coastal", "travel_days": 2, "encounter_mod": 1},
		"Mistborne Atolls": {"desc": "Disappearing islands that shift with the tides.", "terrain": "mystical_island", "travel_days": 3, "encounter_mod": 2},
	},
	"titan": {  # Titan's Rest
		"The Bone Valley": {"desc": "A landscape of titan skeletons stretching for miles.", "terrain": "bone_field", "travel_days": 2, "encounter_mod": 2},
		"Colossus Falls": {"desc": "A waterfall cascading from a titan's empty eye socket.", "terrain": "waterfall", "travel_days": 1, "encounter_mod": 1},
		"The Living Stone": {"desc": "A petrified titan whose heart still beats.", "terrain": "living_stone", "travel_days": 2, "encounter_mod": 3},
	},
}

# ══════════════════════════════════════════════════════════════════════════════
# TERRAIN EFFECTS (WG Section 6)
# ══════════════════════════════════════════════════════════════════════════════
const TERRAIN_EFFECTS: Dictionary = {
	"glacier": {"speed_mod": -2, "fire_dmg_mod": 0.25, "cold_dmg_mod": -0.25, "desc": "Frostwaste: -2 Speed, fire +25%, cold -25%"},
	"crater": {"speed_mod": -1, "prone_dc": 12, "desc": "Glass Dunes: movement doubled, prone DC 12"},
	"rainforest": {"heal_mod": 4, "stealth_mod": 1, "desc": "Crystal Bloom: healing +1d4, stealth advantage"},
	"toxic_forest": {"speed_mod": -1, "dot_dmg": 4, "stealth_mod": 1, "desc": "Thornveil: 1d4 piercing/turn, stealth advantage"},
	"cavern": {"darkvision_mod": -0.5, "stealth_mod": -1, "desc": "Hollowdeep: darkvision halved, stealth disadvantage"},
	"marsh": {"heavy_armor_penalty": true, "poison_dc": 12, "desc": "Shimmerfen: heavy armor disadvantage, poison checks"},
	"astral": {"spell_cost_mod": -1, "wild_surge": true, "desc": "Astral Zones: spell costs -1 AP, wild surge on nat 1"},
	"arena": {"crit_range_mod": 1, "desc": "Blood Sands: crit range expanded by 1"},
	"bone_field": {"undead_encounter_mod": 0.5, "holy_dmg_mod": 0.25, "desc": "Bone Valley: undead +50%, holy damage +25%"},
	"harbor": {"swim_check": true, "ranged_penalty": true, "desc": "Harbors: swim checks, ranged disadvantage in rain"},
	"living_stone": {"tremor_dc": 13, "earth_mod": 0.5, "desc": "Living Stone: tremor DC 13, earth magic +50%"},
	"palace": {"social_mod": 1, "combat_consequences": true, "desc": "Scarlet Court: social advantage, combat = consequences"},
	"industrial": {"fire_resist_dc": 12, "metal_heat": 4, "desc": "Ironworks: fire saves, metal heats (1d4 fire/round)"},
	"psionic": {"random_magic": true, "psionic_interference": true, "desc": "Echoing Wastes: random magic effects, psionic interference"},
	"fungal": {"spore_dc": 11, "poison_resist": true, "desc": "Fungal Expanse: spore DC 11, poison resistance checks"},
	"wasteland": {"fire_dmg_mod": 0.15, "movement_penalty": true, "desc": "Ashen Fields: fire +15%, difficult terrain"},
}

# ══════════════════════════════════════════════════════════════════════════════
# QUEST TYPES (WG Section 7)
# ══════════════════════════════════════════════════════════════════════════════
const QUEST_TYPES: Array = [
	{"id": "retrieval", "name": "Retrieval", "desc": "Recover a specific item from a dangerous location.", "reward_mult": 1.0},
	{"id": "escort", "name": "Escort", "desc": "Protect an NPC during travel between locations.", "reward_mult": 0.8},
	{"id": "extermination", "name": "Extermination", "desc": "Clear an area of hostile creatures.", "reward_mult": 1.2},
	{"id": "investigation", "name": "Investigation", "desc": "Uncover clues and solve a mystery.", "reward_mult": 0.9},
	{"id": "defense", "name": "Defense", "desc": "Protect a location from waves of attackers.", "reward_mult": 1.1},
	{"id": "diplomacy", "name": "Diplomacy", "desc": "Negotiate between factions without combat.", "reward_mult": 0.7},
	{"id": "sabotage", "name": "Sabotage", "desc": "Infiltrate and destroy enemy resources.", "reward_mult": 1.3},
	{"id": "rescue", "name": "Rescue", "desc": "Extract a captured NPC from enemy territory.", "reward_mult": 1.0},
	{"id": "exploration", "name": "Exploration", "desc": "Map unknown territory, discover new subregions.", "reward_mult": 0.8},
	{"id": "bounty_hunt", "name": "Bounty Hunt", "desc": "Track and defeat a specific powerful target.", "reward_mult": 1.5},
	{"id": "ritual", "name": "Ritual", "desc": "Gather components and perform a magical ceremony.", "reward_mult": 1.0},
	{"id": "tournament", "name": "Tournament", "desc": "Compete in structured combat or skill challenges.", "reward_mult": 0.9},
]

const THREAT_TYPES: Array = [
	"Bandits", "Undead Horde", "Dragon", "Cult", "Elemental Incursion",
	"Aberration", "Fey Trickery", "Plague", "War Band", "Demonic Rift",
	"Natural Disaster", "Political Conspiracy",
]

const MAGICAL_ANOMALIES: Array = [
	{"name": "Wild Magic Surge", "desc": "Random spell effects trigger on any magical action.", "spell_fail_chance": 0.2},
	{"name": "Dead Magic Zone", "desc": "All magic fails, magical items temporarily inert.", "spell_fail_chance": 1.0},
	{"name": "Time Dilation", "desc": "Turns last longer/shorter, initiative rerolled each round.", "reroll_init": true},
	{"name": "Planar Bleed", "desc": "Creatures from other planes appear randomly.", "extra_spawn_chance": 0.3},
	{"name": "Gravity Well", "desc": "Movement costs tripled, ranged attacks arc unpredictably.", "move_cost_mult": 3},
	{"name": "Psionic Storm", "desc": "Wisdom saves each turn or suffer confusion.", "wisdom_dc": 13},
]

# ══════════════════════════════════════════════════════════════════════════════
# POLITICAL SYSTEMS (WG Section 11)
# ══════════════════════════════════════════════════════════════════════════════
const GOVERNMENT_TYPES: Dictionary = {
	"monarchy":     {"name": "Monarchy", "tax_rate": 0.10, "price_mod": 1.0, "crime_severity": 1.5, "desc": "Stable taxes, royal favor required"},
	"republic":     {"name": "Republic", "tax_rate": 0.08, "price_mod": 1.0, "crime_severity": 1.0, "desc": "Elected leaders, fair treatment"},
	"theocracy":    {"name": "Theocracy", "tax_rate": 0.12, "price_mod": 0.9, "crime_severity": 1.2, "desc": "Divine magic empowered, arcane restricted"},
	"merchant":     {"name": "Merchant Council", "tax_rate": 0.05, "price_mod": 0.95, "crime_severity": 0.5, "desc": "Everything negotiable, bribery standard"},
	"military":     {"name": "Military Junta", "tax_rate": 0.15, "price_mod": 1.1, "crime_severity": 2.0, "desc": "Curfews, weapon restrictions"},
	"anarchy":      {"name": "Anarchy", "tax_rate": 0.0, "price_mod": 1.2, "crime_severity": 0.0, "desc": "No law, everything available but dangerous"},
	"tribal":       {"name": "Tribal Confederation", "tax_rate": 0.05, "price_mod": 1.0, "crime_severity": 1.0, "desc": "Respect earned through trials"},
	"magocracy":    {"name": "Magocracy", "tax_rate": 0.10, "price_mod": 0.85, "crime_severity": 1.0, "desc": "Magic = status, spell components cheap"},
	"feudal":       {"name": "Feudal Lords", "tax_rate": 0.12, "price_mod": 1.05, "crime_severity": 1.3, "desc": "Land ownership matters, station-based access"},
	"democracy":    {"name": "Democracy", "tax_rate": 0.08, "price_mod": 1.0, "crime_severity": 1.0, "desc": "Slow bureaucracy, permits required"},
	"pirate":       {"name": "Pirate Haven", "tax_rate": 0.0, "price_mod": 1.15, "crime_severity": 0.2, "desc": "Maritime law only, stolen goods welcome"},
	"undead":       {"name": "Undead Dominion", "tax_rate": 0.10, "price_mod": 1.1, "crime_severity": 1.5, "desc": "Living are second-class, necromancy legal"},
	"fey":          {"name": "Fey Court", "tax_rate": 0.0, "price_mod": 0.8, "crime_severity": 0.0, "desc": "Rules change whimsically, bargains binding"},
}

# Region → government type mapping
const REGION_GOVERNMENTS: Dictionary = {
	"plains":      "monarchy",
	"frost":       "tribal",
	"forest":      "fey",
	"underground": "anarchy",
	"city":        "merchant",
	"astral":      "magocracy",
	"arena":       "military",
	"throne":      "monarchy",
	"islands":     "pirate",
	"titan":       "tribal",
}

# ══════════════════════════════════════════════════════════════════════════════
# REGIONAL ECONOMY (WG Section 10)
# ══════════════════════════════════════════════════════════════════════════════
const REGIONAL_PRICE_MODIFIERS: Dictionary = {
	"plains":      {"weapons": 1.0,  "armor": 1.0,  "potions": 1.0,  "food": 0.8,  "luxury": 1.1},
	"frost":       {"weapons": 1.1,  "armor": 1.1,  "potions": 1.2,  "food": 1.3,  "luxury": 1.2},
	"forest":      {"weapons": 1.05, "armor": 1.1,  "potions": 0.8,  "food": 0.9,  "luxury": 1.0},
	"underground": {"weapons": 1.2,  "armor": 1.2,  "potions": 0.9,  "food": 1.4,  "luxury": 1.3},
	"city":        {"weapons": 1.1,  "armor": 1.1,  "potions": 1.0,  "food": 1.0,  "luxury": 0.9},
	"astral":      {"weapons": 1.3,  "armor": 1.3,  "potions": 0.7,  "food": 1.5,  "luxury": 1.0},
	"arena":       {"weapons": 0.85, "armor": 0.85, "potions": 1.0,  "food": 1.1,  "luxury": 1.2},
	"throne":      {"weapons": 1.0,  "armor": 1.0,  "potions": 1.0,  "food": 1.0,  "luxury": 0.85},
	"islands":     {"weapons": 1.15, "armor": 1.15, "potions": 1.1,  "food": 0.9,  "luxury": 1.1},
	"titan":       {"weapons": 1.2,  "armor": 1.0,  "potions": 1.1,  "food": 1.2,  "luxury": 1.3},
}

# ══════════════════════════════════════════════════════════════════════════════
# REGIONAL LOOT MODIFIERS (GMG Section 23)
# ══════════════════════════════════════════════════════════════════════════════
const REGIONAL_LOOT_MODIFIERS: Dictionary = {
	"plains":      {"gold": 1.15, "weapons": 1.0,  "armor": 1.0,  "magic": 1.0,  "gems": 1.0,  "herbs": 1.10},
	"frost":       {"gold": 1.0,  "weapons": 1.0,  "armor": 0.8,  "magic": 1.0,  "gems": 1.1,  "herbs": 0.85},
	"forest":      {"gold": 1.0,  "weapons": 0.85, "armor": 0.85, "magic": 1.0,  "gems": 0.9,  "herbs": 1.30},
	"underground": {"gold": 0.85, "weapons": 1.0,  "armor": 1.0,  "magic": 1.1,  "gems": 1.30, "herbs": 0.8},
	"city":        {"gold": 1.25, "weapons": 1.0,  "armor": 1.0,  "magic": 1.20, "gems": 1.0,  "herbs": 0.9},
	"astral":      {"gold": 0.7,  "weapons": 0.8,  "armor": 0.8,  "magic": 1.50, "gems": 1.2,  "herbs": 0.8},
	"arena":       {"gold": 1.0,  "weapons": 1.20, "armor": 1.20, "magic": 0.9,  "gems": 0.9,  "herbs": 0.9},
	"throne":      {"gold": 1.1,  "weapons": 1.0,  "armor": 1.0,  "magic": 1.0,  "gems": 1.0,  "herbs": 0.9},
	"islands":     {"gold": 1.1,  "weapons": 1.0,  "armor": 0.9,  "magic": 1.0,  "gems": 1.15, "herbs": 1.0},
	"titan":       {"gold": 0.9,  "weapons": 1.15, "armor": 1.1,  "magic": 1.2,  "gems": 1.1,  "herbs": 0.8},
}

# ══════════════════════════════════════════════════════════════════════════════
# ENVIRONMENTAL HAZARDS (WG Section 12 + GMG Section 24)
# ══════════════════════════════════════════════════════════════════════════════
const ENVIRONMENTAL_HAZARDS: Array = [
	{"name": "Blizzard", "save": "VIT", "dc": 13, "dmg_dice": [1, 6], "type": "cold", "duration": 4, "effect": "speed_halved", "regions": ["frost"]},
	{"name": "Sandstorm", "save": "SPD", "dc": 12, "dmg_dice": [1, 4], "type": "slashing", "duration": 3, "effect": "ranged_disadvantage", "regions": ["plains", "titan"]},
	{"name": "Volcanic Eruption", "save": "SPD", "dc": 15, "dmg_dice": [10, 10], "type": "fire", "duration": 1, "effect": "terrain_destruction", "regions": ["titan"]},
	{"name": "Flood", "save": "STR", "dc": 14, "dmg_dice": [2, 6], "type": "bludgeoning", "duration": 2, "effect": "swept_away", "regions": ["forest", "islands"]},
	{"name": "Earthquake", "save": "SPD", "dc": 13, "dmg_dice": [2, 8], "type": "bludgeoning", "duration": 1, "effect": "prone", "regions": ["underground", "titan"]},
	{"name": "Toxic Fog", "save": "VIT", "dc": 13, "dmg_dice": [1, 8], "type": "poison", "duration": 5, "effect": "poisoned", "regions": ["underground", "forest"]},
	{"name": "Wildfire", "save": "SPD", "dc": 14, "dmg_dice": [3, 6], "type": "fire", "duration": 3, "effect": "smoke_inhalation", "regions": ["plains", "forest"]},
	{"name": "Magical Storm", "save": "INT", "dc": 14, "dmg_dice": [2, 8], "type": "force", "duration": 3, "effect": "wild_surge", "regions": ["astral"]},
	{"name": "Planar Rift", "save": "DIV", "dc": 15, "dmg_dice": [2, 10], "type": "force", "duration": 2, "effect": "extra_spawns", "regions": ["astral"]},
	{"name": "Avalanche", "save": "STR", "dc": 15, "dmg_dice": [4, 10], "type": "bludgeoning", "duration": 1, "effect": "buried", "regions": ["frost"]},
	{"name": "Sinkhole", "save": "SPD", "dc": 13, "dmg_dice": [2, 6], "type": "bludgeoning", "duration": 1, "effect": "separated", "regions": ["underground", "plains"]},
	{"name": "Psychic Miasma", "save": "DIV", "dc": 14, "dmg_dice": [1, 8], "type": "psychic", "duration": 4, "effect": "hallucinate", "regions": ["astral", "underground"]},
	{"name": "Lightning Field", "save": "SPD", "dc": 14, "dmg_dice": [3, 8], "type": "lightning", "duration": 2, "effect": "metal_attract", "regions": ["plains", "islands"]},
	{"name": "Temporal Rift", "save": "INT", "dc": 15, "dmg_dice": [1, 4], "type": "psychic", "duration": 3, "effect": "time_skip", "regions": ["astral"]},
]

# ══════════════════════════════════════════════════════════════════════════════
# BOUNTY HUNTERS (GMG Section 13)
# ══════════════════════════════════════════════════════════════════════════════
const BOUNTY_HUNTER_TEMPLATES: Array = [
	{"name": "Tracker", "level_mod": 0, "rank": "Minor", "hp_mult": 1.0, "abilities": ["Track"]},
	{"name": "Enforcer", "level_mod": 1, "rank": "Notable", "hp_mult": 1.2, "abilities": ["Track", "Net Throw"]},
	{"name": "Hunter Squad", "level_mod": 2, "rank": "Dangerous", "hp_mult": 1.5, "abilities": ["Track", "Net Throw", "Coordinated Strike"]},
	{"name": "Elite Manhunter", "level_mod": 3, "rank": "Severe", "hp_mult": 2.0, "abilities": ["Track", "Net Throw", "Coordinated Strike", "Lockdown"]},
	{"name": "Legendary Pursuer", "level_mod": 5, "rank": "Infamous", "hp_mult": 3.0, "abilities": ["Track", "Net Throw", "Coordinated Strike", "Lockdown", "Planar Chase"]},
]

# ══════════════════════════════════════════════════════════════════════════════
# BULK TRADING (GMG Section 17)
# ══════════════════════════════════════════════════════════════════════════════
const TRADE_GOODS: Array = [
	{"name": "Grain", "base_value": 10, "weight": 5, "category": "food"},
	{"name": "Livestock", "base_value": 50, "weight": 20, "category": "food"},
	{"name": "Iron Ore", "base_value": 25, "weight": 10, "category": "raw"},
	{"name": "Timber", "base_value": 15, "weight": 15, "category": "raw"},
	{"name": "Silk", "base_value": 100, "weight": 1, "category": "luxury"},
	{"name": "Spices", "base_value": 75, "weight": 1, "category": "luxury"},
	{"name": "Magical Components", "base_value": 200, "weight": 1, "category": "magic"},
	{"name": "Healing Herbs", "base_value": 30, "weight": 2, "category": "herb"},
	{"name": "Gemstones", "base_value": 150, "weight": 1, "category": "gem"},
	{"name": "Weapons (Bulk)", "base_value": 80, "weight": 10, "category": "weapons"},
	{"name": "Armor (Bulk)", "base_value": 120, "weight": 15, "category": "armor"},
	{"name": "Ale & Spirits", "base_value": 20, "weight": 8, "category": "food"},
]

## Settlement tier for trade dice
const SETTLEMENT_TRADE_DICE: Dictionary = {
	"hamlet": 1, "village": 2, "town": 3, "city": 4, "metropolis": 5,
}

# ══════════════════════════════════════════════════════════════════════════════
# SIEGE DEFENSE TIERS (GMG Section 18)
# ══════════════════════════════════════════════════════════════════════════════
const SIEGE_TIERS: Array = [
	{"name": "Palisade", "wall_hp": 50, "defenders": "militia", "duration_days": [1, 3], "tier": 1},
	{"name": "Stone Walls", "wall_hp": 150, "defenders": "trained", "duration_days": [7, 14], "tier": 2},
	{"name": "Castle", "wall_hp": 300, "defenders": "professional", "duration_days": [14, 42], "tier": 3},
	{"name": "Fortress", "wall_hp": 500, "defenders": "elite", "duration_days": [30, 90], "tier": 4},
	{"name": "Citadel", "wall_hp": 1000, "defenders": "legendary", "duration_days": [90, 180], "tier": 5},
]

# ══════════════════════════════════════════════════════════════════════════════
# CIVIC RITES (GMG Section 16)
# ══════════════════════════════════════════════════════════════════════════════
const CIVIC_RITES: Array = [
	{"name": "Harvest Rite", "sp_cost": [50, 200], "effect": "crop_yield_25", "duration_days": 90, "desc": "+25% crop yield, food prices drop"},
	{"name": "Siege Ward", "sp_cost": [500, 2000], "effect": "wall_hp_50", "duration_days": 30, "desc": "+50% wall HP, enemies take radiant damage"},
	{"name": "Weather Call", "sp_cost": [100, 500], "effect": "weather_control", "duration_days": 7, "desc": "Control local weather for 1 week"},
	{"name": "Peace Accord", "sp_cost": [200, 1000], "effect": "ceasefire", "duration_days": 30, "desc": "Ceasefire between factions for 1 month"},
]

# ══════════════════════════════════════════════════════════════════════════════
# NAMED NPCs (World Section 9)
# ══════════════════════════════════════════════════════════════════════════════
const NAMED_NPCS: Array = [
	{"name": "Theron the Bold", "region": "plains", "lineage": "Boreal Human", "role": "quest_giver", "desc": "A retired general who lost his arm in the Marches War.", "dialogue": ["The Shattered Marches still hold secrets.", "I once led 500 men into that hellscape.", "If you're heading north, watch for the bone pits."], "quest_hook": "retrieval"},
	{"name": "Sylvara Mistweave", "region": "forest", "lineage": "Elf", "role": "trainer", "desc": "An ancient elf who teaches natural magic.", "dialogue": ["The forest remembers what we forget.", "Every herb has a purpose.", "Close your eyes. Now listen."], "quest_hook": "ritual"},
	{"name": "Korth Ironforge", "region": "underground", "lineage": "Argent Dvarrim", "role": "merchant", "desc": "A dwarf merchant dealing in rare minerals and gems.", "dialogue": ["Aye, the deep places yield wealth beyond measure.", "Watch yer step down here. The dark has teeth.", "I'll trade ye fair, friend."], "quest_hook": "escort"},
	{"name": "Maelis Starwhisper", "region": "astral", "lineage": "Aetherian", "role": "lore_keeper", "desc": "A scholar of planar magic and cosmic phenomena.", "dialogue": ["The stars speak to those who listen.", "Reality is thinner here than elsewhere.", "What you see is not always what is."], "quest_hook": "investigation"},
	{"name": "Garrick Stonefist", "region": "frost", "lineage": "Cragborn Human", "role": "trainer", "desc": "A battle-hardened warrior training in the frozen wastes.", "dialogue": ["The cold sharpens the mind and the blade.", "Weakness is frozen out here.", "Survive a night on these plains and you'll survive anything."], "quest_hook": "defense"},
	{"name": "Lyris the Shadowblade", "region": "city", "lineage": "Duskling", "role": "quest_giver", "desc": "A roguish figure with connections to the underground.", "dialogue": ["In the city, everything has a price.", "I know people. Good people. Dangerous people.", "What's yer business in the Bazaar?"], "quest_hook": "sabotage"},
	{"name": "Veris Moonfall", "region": "islands", "lineage": "Fathomari", "role": "merchant", "desc": "A pirate captain turned trader with stories of the deep.", "dialogue": ["The seas hold treasures and terrors in equal measure.", "I've seen things in the deep that would break yer mind.", "Interested in a voyage?"], "quest_hook": "exploration"},
	{"name": "Brother Aldric", "region": "arena", "lineage": "Arcanite Human", "role": "trainer", "desc": "A holy warrior of the Proving Grounds.", "dialogue": ["Combat is prayer. Victory is grace.", "Every scar teaches a lesson.", "Face yourself in the arena and you face truth."], "quest_hook": "tournament"},
	{"name": "Countess Erebis", "region": "throne", "lineage": "Gilded Human", "role": "lore_keeper", "desc": "A noble with secrets about the royal lineage.", "dialogue": ["Power flows through blood and coin.", "The court is a battlefield where none bleed.", "Trust no one's smile, only their fear."], "quest_hook": "diplomacy"},
	{"name": "Kael Bonewright", "region": "titan", "lineage": "Ashenborn", "role": "quest_giver", "desc": "A scholar fascinated by the giant corpses.", "dialogue": ["These titans fell ages ago. Yet their echoes remain.", "We walk upon the bones of gods.", "Their reach extends even in death."], "quest_hook": "retrieval"},
	{"name": "Marta Goldleaf", "region": "plains", "lineage": "Ferrusk", "role": "merchant", "desc": "A half-orc farmer and trader of rare seeds.", "dialogue": ["Good soil, good harvest. Simple as that.", "The land provides if you respect it.", "Come spring, I'll have the finest crops in the realm."], "quest_hook": "escort"},
	{"name": "Rodrik the Wise", "region": "forest", "lineage": "Bramblekin", "role": "lore_keeper", "desc": "A scholar of druidic traditions and beast speech.", "dialogue": ["The beasts have much to teach, if you listen.", "This forest is alive, truly alive.", "Some knowledge costs more than gold."], "quest_hook": "ritual"},
	{"name": "Grimble Sparkshine", "region": "underground", "lineage": "Nimbari", "role": "trainer", "desc": "A gnome inventor with gadgets and explosives.", "dialogue": ["Problem? I've got a contraption for that.", "Alchemy meets engineering down here.", "Careful with that. It's liable to explode."], "quest_hook": "sabotage"},
	{"name": "Zara the Void-touched", "region": "astral", "lineage": "Fae-Touched Human", "role": "quest_giver", "desc": "A human touched by planar energies, half-fey, half-mortal.", "dialogue": ["The void whispers truths mortals cannot bear.", "My blood sings with star-fire.", "Reality bends for those mad enough to push."], "quest_hook": "investigation"},
	{"name": "Bjorn Frostborn", "region": "frost", "lineage": "Frostborn", "role": "merchant", "desc": "A trader in furs, scales, and exotic animal parts.", "dialogue": ["The tundra provides everything if you know where to look.", "Beast hides fetch a fine price in warmer lands.", "Winter is coming. Always coming."], "quest_hook": "extermination"},
	{"name": "Lady Seraphine", "region": "city", "lineage": "Glimmerfolk", "role": "lore_keeper", "desc": "A mysterious enchantress with a network of spies.", "dialogue": ["Information is more valuable than gold in the city.", "I know everyone. Everyone knows me.", "What would you trade for the truth?"], "quest_hook": "diplomacy"},
	{"name": "Thalassa the Pearl", "region": "islands", "lineage": "Fathomari", "role": "trainer", "desc": "A legendary sea priestess and navigator.", "dialogue": ["The tides speak in a language older than words.", "She who masters the waves masters destiny.", "The ocean calls to all who listen."], "quest_hook": "rescue"},
	{"name": "Daemon Bloodfist", "region": "arena", "lineage": "Cindervolk", "role": "quest_giver", "desc": "A champion gladiator with a past shrouded in mystery.", "dialogue": ["Every scar is a story. Every story is written in blood.", "The arena doesn't lie. It shows what you truly are.", "Want glory? Step into the Blood Sands."], "quest_hook": "bounty_hunt"},
	{"name": "Duke Malachai", "region": "throne", "lineage": "Gilded Human", "role": "merchant", "desc": "A wealthy noble dealing in political favors and secrets.", "dialogue": ["The kingdom is a game, and I know all the rules.", "Gold opens doors. Secrets open kingdoms.", "Shall we discuss business?"], "quest_hook": "sabotage"},
	{"name": "Esha Bonespeaker", "region": "titan", "lineage": "Gravetouched", "role": "trainer", "desc": "A shaman who communes with the remnants of fallen gods.", "dialogue": ["The titans speak through bone and stone.", "Death is not the end, only a transition.", "Those who hear the songs of titans are forever changed."], "quest_hook": "ritual"},
]

# ══════════════════════════════════════════════════════════════════════════════
# DIVINE ASCENSION (WG Section 8)
# ══════════════════════════════════════════════════════════════════════════════
const ASCENSION_PATHS: Dictionary = {
	"Unity": {
		"desc": "Order, protection, civilization",
		"milestones": ["Minor Boon: +1 to healing spells", "Major Boon: Allies in 10ft gain +2 AC", "Demigod: Resurrect one ally per long rest", "Ascension: Become a God of Unity"],
		"tasks": ["Unite warring factions", "Build 3 temples", "Establish laws in 3 regions", "Protect 100 innocents"],
	},
	"Chaos": {
		"desc": "Freedom, change, destruction of the old order",
		"milestones": ["Minor Boon: +1d4 to all attack rolls", "Major Boon: Wild Magic always benefits you", "Demigod: Shatter any magical barrier once/day", "Ascension: Become a God of Chaos"],
		"tasks": ["Topple 3 governments", "Free 50 prisoners", "Disrupt 5 trade monopolies", "Unleash 3 magical anomalies"],
	},
	"Void": {
		"desc": "Entropy, balance, the spaces between",
		"milestones": ["Minor Boon: Resistance to all damage types", "Major Boon: Negate one spell per encounter", "Demigod: Erase one entity from existence per day", "Ascension: Become a God of the Void"],
		"tasks": ["Seal 5 planar rifts", "Destroy 3 artifacts of power", "Maintain balance in 5 conflicts", "Sacrifice 10 memories"],
	},
}

# ══════════════════════════════════════════════════════════════════════════════
# KAIJU CREATOR (GMG Section 21)
# ══════════════════════════════════════════════════════════════════════════════
# Canonical Kaiju data + formulas now live in autoload/kaiju_system.gd.
# This wrapper remains for backwards compatibility with older callsites.

const _KaijuSystem = preload("res://autoload/kaiju_system.gd")

## Generate a procedural Kaiju at the given level using the Kaiju Creator spec.
## HP = 10 × Level + VIT,  AP = 10 + Level + STR,  SP = 10 + Level + DIV,
## Threat Points = Level,  Damage Threshold = Level,  Movement = 40 ft × SPD.
## For a specific named Kaiju, use KaijuSystem.resolve(idx) instead.
static func generate_kaiju(level: int) -> Dictionary:
	var k: Dictionary = _KaijuSystem.generate_procedural(level)
	# Back-compat shape: older code expects hit_zones + area_attacks arrays.
	var ac: int = int(k["ac"])
	var hp: int = int(k["hp"])
	k["hit_zones"] = [
		{"name": "Head",       "ac": ac + 2, "hp": hp / 4},
		{"name": "Body",       "ac": ac,     "hp": hp / 2},
		{"name": "Left Limb",  "ac": ac - 1, "hp": hp / 8},
		{"name": "Right Limb", "ac": ac - 1, "hp": hp / 8},
	]
	var area_ft: int = int(k["scaled_area_ft"])
	var multi: int = int(k["multi_target"])
	k["area_attacks"] = [
		{"name": "Stomp",         "dice": [level / 2, 8],  "area_ft": area_ft,     "targets": multi, "type": "bludgeoning"},
		{"name": "Breath Weapon", "dice": [level / 3, 10], "area_ft": area_ft * 2, "targets": multi, "type": "fire"},
		{"name": "Tail Sweep",    "dice": [level / 3, 6],  "area_ft": area_ft,     "targets": multi, "type": "bludgeoning"},
	]
	k["legendary_actions"] = 1 + level / 5
	k["speed"] = int(k["stats"]["spd"])
	return k

# ══════════════════════════════════════════════════════════════════════════════
# ADVERSARY LEVELING (GMG Section 22)
# ══════════════════════════════════════════════════════════════════════════════
## Calculate effective adversary level based on party and encounters survived
static func calc_adversary_level(party_levels: Array, encounters_survived: int) -> int:
	var cumulative: int = 0
	var max_level: int = 0
	for lv in party_levels:
		cumulative += int(lv)
		max_level = maxi(max_level, int(lv))
	var base: int = cumulative / 2
	var bonus: int = encounters_survived
	return mini(base + bonus, max_level + 5)

# ══════════════════════════════════════════════════════════════════════════════
# QUEST GENERATOR
# ══════════════════════════════════════════════════════════════════════════════
## Generate a random quest for a given region and party level
static func generate_quest(region: String, party_level: int) -> Dictionary:
	var qt: Dictionary = QUEST_TYPES[randi() % QUEST_TYPES.size()]
	var threat: String = THREAT_TYPES[randi() % THREAT_TYPES.size()]
	var subregions: Dictionary = SUBREGIONS.get(region, {})
	var sub_names: Array = subregions.keys()
	var location: String = sub_names[randi() % sub_names.size()] if not sub_names.is_empty() else region
	var base_reward: int = 50 + party_level * 25
	var reward: int = int(float(base_reward) * float(qt["reward_mult"]))
	var xp_reward: int = 25 + party_level * 15
	var difficulty: int = clampi(party_level + randi_range(-2, 2), 1, 30)
	return {
		"quest_id": "q_%d_%d" % [randi() % 99999, party_level],
		"type": str(qt["id"]),
		"type_name": str(qt["name"]),
		"desc": str(qt["desc"]),
		"threat": threat,
		"location": location,
		"region": region,
		"difficulty": difficulty,
		"gold_reward": reward,
		"xp_reward": xp_reward,
		"objectives": _generate_objectives(str(qt["id"]), difficulty),
	}

static func _generate_objectives(quest_type: String, difficulty: int) -> Array:
	match quest_type:
		"retrieval": return ["Find the artifact", "Defeat guardian (Lv.%d)" % difficulty, "Return to quest giver"]
		"escort": return ["Meet the NPC", "Travel through %d zones" % maxi(2, difficulty / 3), "Arrive safely"]
		"extermination": return ["Locate the nest", "Defeat %d enemies" % (3 + difficulty / 2), "Confirm area clear"]
		"investigation": return ["Gather %d clues" % maxi(2, difficulty / 4), "Interrogate suspect", "Solve the mystery"]
		"defense": return ["Prepare defenses", "Survive %d waves" % maxi(2, difficulty / 3), "Defeat the final assault"]
		"diplomacy": return ["Meet faction A", "Meet faction B", "Negotiate terms", "Seal the accord"]
		"sabotage": return ["Infiltrate the base", "Plant explosives / disable machinery", "Escape undetected"]
		"rescue": return ["Locate the prisoner", "Defeat guards (Lv.%d)" % difficulty, "Extract safely"]
		"exploration": return ["Enter unknown territory", "Map %d areas" % maxi(2, difficulty / 3), "Return with findings"]
		"bounty_hunt": return ["Track the target", "Corner the target", "Defeat the target (Lv.%d)" % (difficulty + 2)]
		"ritual": return ["Gather %d components" % maxi(2, difficulty / 4), "Find ritual site", "Perform the ritual"]
		"tournament": return ["Register for tournament", "Win %d rounds" % maxi(2, difficulty / 3), "Face the champion"]
		_: return ["Complete the objective"]
