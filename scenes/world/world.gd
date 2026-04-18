extends Control

var current_tab: int = 0
var quests: Array = []
var active_tasks: Dictionary = {}
var active_forages: Array = []
var _content_area: Control  # stored so _on_tab_selected can find children
var _quests_vbox: VBoxContainer  # stored for _on_generate_quest refresh
var _region_filter: String = ""  # "" = show all

# ── Crafting / Foraging UI refs ───────────────────────────────────────────────
var _craft_member_dropdown: OptionButton
var _craft_type_dropdown:   OptionButton
var _craft_active_handles:  Array = []
var _craft_tasks_vbox:      VBoxContainer
var _craftable_items:       Array = []   # cached from engine

# ── Magic tab refs ────────────────────────────────────────────────────────────
var _magic_char_handles:    Array = []
var _magic_char_dropdown:   OptionButton
var _magic_sp_lbl:          Label
var _magic_custom_vbox:     VBoxContainer
var _magic_domain_idx:      int = 0
var _magic_effect_idx:      int = 0
var _magic_range_idx:       int = 0
var _magic_area_idx:        int = 0
var _magic_die_count:       int = 1
var _magic_die_sides:       int = 6
var _magic_dmg_type_idx:    int = 0
var _magic_cost_lbl:        Label
var _magic_name_edit:       LineEdit
var _magic_dice_lbl:        Label
var _magic_die_count_slider: HSlider
var _forage_char_dropdown: OptionButton
var _forage_type: String = "hunting"
var _forage_active_handles: Array = []
var _forage_tasks_vbox: VBoxContainer
var _task_timer: float = 0.0

# ── Dungeon Dive state ───────────────────────────────────────────────────────
var _dd_type: int          = 0   # 0=Standard 1=Kaiju 2=Apex 3=Militia 4=Mob
var _dd_enemy_level: int   = 3
var _dd_kaiju_idx: int     = 0
var _dd_apex_idx: int      = 0
var _dd_militia_idx: int   = 0
var _dd_mob_count: int     = 30
var _dd_mob_level: int     = 3
var _dd_terrain_style: int = 0
var _dd_config_panel: VBoxContainer
var _dd_type_btns: Array   = []

# ── Story tab refs ────────────────────────────────────────────────────────────
var _story_sections_vbox: VBoxContainer  # rebuilt when badges change
var _story_badge_lbl: Label

# ── Overworld state ──────────────────────────────────────────────────────────
var _overworld_panel: Control
var _overworld_map_control: Control           # canvas holding region nodes
var _overworld_detail_vbox: VBoxContainer     # right-hand detail column
var _overworld_region_buttons: Dictionary = {}  # region_id -> Button
var _overworld_focused_region: String = ""   # which region is currently opened in detail
var _overworld_location_list_vbox: VBoxContainer  # refreshed when region focused

# ── Ritual tab refs ───────────────────────────────────────────────────────────
var _ritual_tasks_vbox:   VBoxContainer
var _ritual_active_vbox:  VBoxContainer
var _ritual_result_lbl:   Label
var _ritual_empty_lbl:    Label

const DD_TERRAIN_NAMES: Array = [
	"Cave", "Grassland", "Dense Forest", "City Ruins",
	"Volcanic Rift", "Sunken Grotto", "Arcane Sanctum", "Necropolis",
	"Frozen Cavern", "Swamp Bog", "Desert Temple", "Mushroom Hollow",
	"Crystal Mines", "Infernal Pit", "Clockwork Forge", "Elven Ruins",
	"Sewer Depths", "Sky Citadel", "Abyssal Void", "Haunted Manor",
	"Coral Reef", "Dwarven Stronghold", "Blood Sanctum", "Overgrown Ruin",
]
const DD_TERRAIN_DESCS: Array = [
	"Enclosed rock caverns with stalagmites and jagged stone — indoor, dim",
	"Rolling plains and open sky — outdoor, bright sunlight",
	"Dense forest canopy with trees and undergrowth — outdoor, dappled light",
	"Crumbling city streets with rubble and broken columns — indoor, dusty",
	"Lava tunnels and volcanic ravines with obsidian shards — indoor, fiery glow",
	"Submerged grotto with coral and bioluminescent flora — underwater, dim blue",
	"Arcane sanctum with floating runes and obelisks — indoor, purple glow",
	"Ancient crypts with tombstones and bone piles — outdoor, eerie green",
	"Frozen cavern with icicles and ice boulders — indoor, cold blue light",
	"Murky swamp bog with dead trees and mud mounds — outdoor, hazy green",
	"Sandstone temple with pillars and urns — indoor, bright golden",
	"Bioluminescent mushroom hollow with giant fungi — indoor, purple glow",
	"Glittering crystal mines with gem clusters — indoor, blue shimmer",
	"Hellish pit of fire and brimstone — indoor, deep red",
	"Clockwork forge with gears and anvils — indoor, warm amber",
	"Overgrown elven ruins with graceful arches — outdoor, soft green",
	"Dark sewer depths with pipes and sludge — indoor, sickly dim",
	"Sky citadel above the clouds with floating stones — outdoor, brilliant white",
	"Abyssal void of dark energy and strange geometry — indoor, deep purple",
	"Haunted manor with creaky furniture and cobwebs — indoor, flickering warmth",
	"Vibrant coral reef with sea life and kelp — underwater, teal",
	"Sturdy dwarven stronghold with forges and arches — indoor, warm firelight",
	"Blood-soaked sanctum with altars and bone walls — indoor, crimson",
	"Overgrown ruin reclaimed by nature with vines and moss — outdoor, green haze",
]
const DD_KAIJUS: Array = [
	["Pyroclast",        "the Living Volcano",      "Lv.12 — Volcanic titan immune to fire. Obsidian scales and molten veins; its roar shakes the land."],
	["Grondar",          "the Mountain King",       "Lv.13 — Primal simian warlord. Stone-plated arms; its roar shatters glass and stuns armies."],
	["Thal'Zuur",        "the Drowned One",         "Lv.14 — Abyssal leviathan. A cathedral of rot; its bile reshapes the swamp."],
	["Ny'Zorrak",        "the Starborn Maw",         "Lv.15 — Eldritch cosmic horror. Impossible geometry; its existence rewrites reality."],
	["Mirecoast Sleeper","the Tidemaker Colossus",  "Lv.14 — Prehistoric titan. Rises like a drifting continent; coastlines vanish beneath its tread."],
	["Aegis Ultima",     "the Arcane Sentinel",     "Lv.13 — Arcane construct / lawbringer mecha. Deployed when reality is under siege."],
]
const DD_APEXES: Array = [
	["Varnok",           "the Moonbound Tyrant",        "Lv.11 — Apex Werewolf. Regenerates in moonlight; branded targets cannot heal."],
	["Lady Nyssara",     "the Crimson Countess",        "Lv.12 — Apex Vampire. Commands phantom legions; dominates the wounded."],
	["Malgrin",          "the Bound",                   "Lv.13 — Apex Lich. Freezes time; reforms unless its phylactery is destroyed."],
	["Sithra",           "the Venom-Touched Hatchling", "Lv.1 — Apex Serpent. Small but lethally toxic; spits bile and slithers through lines."],
	["Korrak",           "the Bonehowl Ravager",        "Lv.3 — Apex Hyena / Undead Packlord. Summons skeletal hyenas; feasts on the slain."],
	["Veltraxis",        "the Emberborn Duelist",       "Lv.5 — Apex Fire Elemental. Ripostes with flame; vanishes into smoke."],
	["Xal'Thuun",        "the Dreaming Maw",            "Lv.20 — Apex Cosmic Horror. Consumes dreams, collapses reality, returns from death at full HP."],
	["High Null Sereth", "Speaker of the Unwritten Law","Lv.15 — Choir Leader / Null Mage. Silences magic, erases memories, rewinds time itself."],
	["Veyra's Echo",     "the Last Reflection",         "Lv.15 — Choir Diviner / Echo Mage. Sees futures before they happen; redirects fate."],
	["Korrin",           "of the Forgotten Flame",      "Lv.15 — Choir Pyromancer. Burns not just flesh but thought; invokes the Forgotten Flame."],
	["The Culled",       "the Hollow Collective",       "Lv.10 — Mob Entity. Hundreds of minds devoured and merged into one shrieking mass."],
	["Zorin Blackscale", "the Enclave Warden",          "Lv.8 — Dragonkin Enforcer. Armored in obsidian scales; shrugs off blades; punishes ranged."],
	["Thalia Darksong",  "the Enclave Bard",            "Lv.5 — Shadow Bard. Songs unravel concentration; retreats behind illusions."],
	["Gorrim Ironfist",  "the Enclave Bruiser",         "Lv.5 — Berserker. Pure muscle and fury; charges the front line and refuses to fall."],
	["Seraphina Windwalker","the Enclave Scout",        "Lv.5 — Wind Adept. Darts across battlefield; strikes soft targets and fades before reprisal."],
	["Rurik Stormbringer","the Enclave Invoker",        "Lv.5 — Storm Invoker. Hurls lightning and thunder; resists both."],
	["Lyra Moonshadow",  "the Enclave Illusionist",     "Lv.5 — Illusion Mage. Bends light; forces enemies to doubt their senses mid-combat."],
	["The Vorath Twins", "Ilyra & Kael",                "Lv.5 each — Pact Duelists. Fight as one; harming one enrages the other."],
	["Morthis the Binder","Enclave Chain-Mage",         "Lv.5 — Restraint Mage. Magical chains lock down warriors and drag them into kill zones."],
	["Kaelen the Hollow","Enclave Shade",               "Lv.5 — Necrotic Shade. Drains vitality with each strike; fades into shadow when struck."],
	["Nirael",           "of the Glass Veil",           "Lv.5 — Enchantment Sage. Crystallizes thought; turns allies' minds against them."],
]
const DD_MILITIAS: Array = [
	["Ironroot Guard",   "Guard Militia — Lv.5",      "10 dwarves & humans. Shield Wall, Veteran commander. AC 19, morale 8. Disciplined defensive force."],
	["Emberveil Recon",  "Recon Militia — Lv.4",      "5 elves & halflings. Ambush Tactics, Tactician commander. AC 14, morale 4. Advantage on initiative."],
	["Crimson Crusaders","Crusader Militia — Lv.6",   "10 zealots. Battle Chant, Priest commander. AC 18, morale 9. Gain +2 attack & damage when bloodied."],
	["Shadow Blades",    "Shadow Militia — Lv.5",     "5 assassins. Ambush Tactics, no commander. AC 16, crits on 18–20. Vanish and eliminate from hiding."],
	["Iron Legion",      "Iron Legionnaire — Lv.7",   "20 heavy infantry. Iron Discipline, Veteran commander. AC 20, immune to fear. Immovable phalanx."],
	["Void Warband",     "Raid Militia — Lv.6",       "10 void-touched warriors. Void-Touched Frenzy. Immune to charm & fear; breaks at 50% losses."],
	["Storm Riders",     "Storm Militia — Lv.5",      "10 riders. Skirmishers, Tactician commander. Resistant to lightning & thunder. High mobility."],
	["Sacred Vigil",     "Sacred Militia — Lv.5",     "10 temple guards. Divine Zeal, Priest commander. AC 18, +1d4 radiant vs undead. Healing costs –2 SP."],
]

# ── Training missions ──────────────────────────────────────────────────────────
# Each entry: [id, title, region, teaser, xp_reward, is_boss_fight]
const TRAINING_MISSIONS: Array = [
	["t1", "Training I: Tainted Waters", "Kingdom of Qunorum",
		"Illness is spreading through a Qunorum village. Purify the drinking source and root out who is responsible.",
		80, false],
	["t2", "Training II: The Defiled Grotto", "House of Arachana",
		"A cave in the House of Arachana runs foul with corrupted ichor.",
		80, false],
	["t3", "Training III: The Poisoned Spring", "The Forest of SubEden",
		"A sacred spring in SubEden has turned black. The fae have fled. The Sinister Agent's trail grows clearer.",
		80, false],
	["t4", "Training IV: The Heart-Tree", "The Wilds of Endero",
		"The ancient Heart-Tree of Endero is dying. Its roots have been deliberately poisoned.",
		80, false],
	["t5", "Training V: The Sinister Agent", "Kingdom of Qunorum",
		"Velmara Dusk — a corrupted scholar — has been identified. Return to where it began and stop them.",
		200, true],
]

# ── Story sections ─────────────────────────────────────────────────────────────
# Each entry: [section_id, title, badge_name_or_empty, requires_all_badges, missions_array]
# Mission entry: [mission_id, title, region, teaser, xp, is_boss]
const STORY_SECTIONS: Array = [
	["plains", "The Plains", "Plains Badge", false, [
		["plains-1", "Plains I: Wilted Wanderers", "The Plains",
			"Fae-touched plants are siphoning memories from Plains villagers.", 100, false],
		["plains-2", "Plains II: The Root Network", "The Plains",
			"A memory-harvest network woven through ancient root systems. The Enclave's geometry is unmistakable.", 100, false],
		["plains-boss", "Plains III: The Tracker Revealed", "The Plains",
			"Seraphina Windwalker — Fae-Touched Wilderness Tracker — stands at the convergence point.", 300, true],
	]],
	["shadows", "The Shadows Beneath", "Shadows Beneath Badge", false, [
		["shadows-1", "Shadows I: Voices in the Dark", "The Shadows Beneath",
			"Underground settlements report memory-stealing shadows.", 100, false],
		["shadows-2", "Shadows II: The Hollow Path", "The Shadows Beneath",
			"Enclave ritual geometry marks every junction. The tunnels are a circuit being charged.", 100, false],
		["shadows-boss", "Shadows III: Blade of Forgotten Names", "The Shadows Beneath",
			"Thalia Darksong — Shadowblade of the Eclipsed Enclave — steps from the dark.", 300, true],
	]],
	["astral", "The Astral Tear", "Astral Tear Badge", false, [
		["astral-1", "Astral I: Shattered Visions", "The Astral Tear",
			"Travelers through the Astral Tear return without their identities. The planar membrane fractures.", 100, false],
		["astral-2", "Astral II: The Weave Unraveling", "The Astral Tear",
			"Void energy seeps through fractured planar seams. The anchor network is almost complete.", 100, false],
		["astral-boss", "Astral III: Oracle of Dissolution", "The Astral Tear",
			"Nirael of the Glass Veil guards the final anchor and speaks in futures already passed.", 300, true],
	]],
	["terminus", "The Terminus Volarus", "Terminus Volarus Badge", false, [
		["terminus-1", "Terminus I: Static in the Sky", "The Terminus Volarus",
			"Unnatural storms have grounded all air travel and severed communication lines.", 100, false],
		["terminus-2", "Terminus II: The Storm Conductor", "The Terminus Volarus",
			"A ritual lightning-rod network converts storm energy to SP. The Choir's coffers are being filled from the sky.", 100, false],
		["terminus-boss", "Terminus III: Tempest of Forgetting", "The Terminus Volarus",
			"Rurik Stormbringer — Elemental Mage of the Eclipsed Enclave — calls down his storm for one final performance.", 300, true],
	]],
	["glass", "The Glass Passage", "Glass Passage Badge", false, [
		["glass-1", "Glass I: Mirror in the Path", "The Glass Passage",
			"Travelers encounter perfect copies of themselves that lead them into traps.", 100, false],
		["glass-2", "Glass II: A Reflection of Nothing", "The Glass Passage",
			"Two illusionists have replaced the passage's true geography with a false reality.", 100, false],
		["glass-boss", "Glass III: Twin Reflections", "The Glass Passage",
			"Ilyra and Kael Vorath — Mirrorborn dual illusionists — finish each other's sentences and attacks.", 300, true],
	]],
	["isles", "The Isles", "Isles Badge", false, [
		["isles-1", "Isles I: Iron in the Water", "The Isles",
			"Strange mechanical anchors on the seabed are drawing something up — or sending something down.", 100, false],
		["isles-2", "Isles II: The Engine Below", "The Isles",
			"An underwater workshop harvests SP from the ocean's natural currents. It is almost at capacity.", 100, false],
		["isles-boss", "Isles III: The Tinkering Binder", "The Isles",
			"Gorrim Ironfist — Battle Engineer of the Eclipsed Enclave — does not intend to stop tinkering.", 300, true],
	]],
	["metro", "The Metropolitan", "Metropolitan Badge", false, [
		["metro-1", "Metro I: The Academic Conspiracy", "The Metropolitan",
			"A prestigious arcane academy has been quietly recruiting students for Enclave rituals.", 100, false],
		["metro-2", "Metro II: City Under Influence", "The Metropolitan",
			"Civic records are being rewritten. Hundreds report memory gaps. An entire city prepared for identity erasure.", 120, false],
		["metro-boss", "Metro III: Draconic Reckoning", "The Metropolitan",
			"Zorin Blackscale — Arcane Strategist — has turned the Metropolitan's arcane infrastructure into his fortress.", 400, true],
	]],
	["titans", "The Titan's Lament", "Titan's Lament Badge", false, [
		["titans-1", "Titan I: Chains in the Deep", "The Titan's Lament",
			"Ancient Titan ruins have been disturbed. Ritual chains and arcane anchors litter the sacred sites.", 100, false],
		["titans-2", "Titan II: The Bound Echoes", "The Titan's Lament",
			"The spirits of the Titans are being captured in soul shackles and converted to raw SP.", 100, false],
		["titans-boss", "Titan III: The Last Chain", "The Titan's Lament",
			"Morthis the Binder — Soulbinder Ritualist — mutters the names of each bound Titan spirit as you approach.", 300, true],
	]],
	["peaks", "The Peaks of Isolation", "Peaks of Isolation Badge", false, [
		["peaks-1", "Peaks I: The Nameless Pilgrims", "The Peaks of Isolation",
			"Hermits and wanderers of the Peaks have forgotten their names and walk toward an unknown destination.", 100, false],
		["peaks-2", "Peaks II: Masks Among the Stones", "The Peaks of Isolation",
			"The Rite of Hollow Identity has been performed at multiple mountain shrines. Faces have been collected.", 100, false],
		["peaks-boss", "Peaks III: The Face Collector", "The Peaks of Isolation",
			"Kaelen the Hollow — Identity Thief — wears a different face every time you look at him.", 300, true],
	]],
	["sublimini", "Sublimini Dominus", "", true, [
		["sub-1", "Sublimini I: The Threshold", "Sublimini Dominus",
			"Enter Sublimini Dominus through metaphysical resonance. The Culled are everywhere. The Heart is beating.", 200, false],
		["sub-2", "Sublimini II: Through the Culled", "Sublimini Dominus",
			"Eighty minds erased into one. The Culled stand between you and the inner sanctum.", 400, true],
		["sub-3", "Sublimini III: Flames and Echoes", "Sublimini Dominus",
			"Korrin of the Forgotten Flame and Veyra's Echo guard the approach to the Beating Heart of the Void.", 500, true],
		["sub-final", "Sublimini IV: The Architect of Oblivion", "Sublimini Dominus",
			"High Null Sereth conducts the Final Rite. Stop the Architect. Stop the Heart.", 1000, true],
	]],
]

# ── Overworld regions ─────────────────────────────────────────────────────────
# The Rimvale overworld — 9 major regions + endgame Sublimini Dominus.
# Each region entry is a Dictionary (keys):
#   id          : String — stable region id (used by GameState.current_region)
#   name        : String — display name shown on map
#   flavor      : String — one-line flavor tag
#   icon        : String — emoji glyph rendered on the map node
#   pos         : Vector2 — normalised (0..1) map coords (x=left→right, y=top→bottom)
#   accent      : Color — region-unique accent colour (used for borders / buttons)
#   badge       : String — badge awarded for clearing the story arc here, or ""
#   subregions  : Array[String] — lineage-home sub-region names (from _LINEAGE_REGIONS)
#   acf         : Array — ACF mission locations (see ACF_LOCATIONS inside each entry)
#                 Each ACF entry: [id, title, subregion, teaser, xp_reward, is_boss]
# NOTE: `var` (not `const`) because the nested Dictionary values include
# Vector2 / Color constructors, and GDScript 4's const evaluator is stricter.
var OVERWORLD_REGIONS: Array = [
	{
		"id": "plains", "name": "The Plains",
		"flavor": "Rolling grasslands and the cradle of civilization.",
		"icon": "🌾",
		"pos": Vector2(0.52, 0.50),
		"accent": Color(0.60, 0.85, 0.35, 1.0),
		"badge": "Plains Badge",
		"subregions": ["The Plains", "Forest of SubEden", "Kingdom of Qunorum", "Wilds of Endero", "Mortal Arena"],
		"acf": [
			["acf-plains-outpost", "ACF Plains Outpost", "The Plains",
				"Our regional HQ. Stock up, report findings, pick up Director briefings.", 40, false],
			["acf-subeden-grove", "SubEden Sentinel Grove", "Forest of SubEden",
				"A fae-touched watchpost. Scouts report memory fog rolling through the glades.", 80, false],
			["acf-qunorum-annex", "Qunorum Palace Annex", "Kingdom of Qunorum",
				"Gilded corridors. The Crown's liaison is feeding the Enclave intel — trace the leak.", 120, false],
			["acf-endero-lodge", "Endero Wilds Lodge", "Wilds of Endero",
				"A druidic waystation. Heart-Tree blight is radiating outward in concentric rings.", 120, false],
			["acf-arena-post", "Arena Command Post", "Mortal Arena",
				"Blood-sands diplomacy. Survive three exhibition bouts to unlock the real investigation.", 160, true],
		],
	},
	{
		"id": "peaks", "name": "The Peaks of Isolation",
		"flavor": "Windswept spires that swallow names whole.",
		"icon": "🏔",
		"pos": Vector2(0.48, 0.15),
		"accent": Color(0.75, 0.85, 0.95, 1.0),
		"badge": "Peaks of Isolation Badge",
		"subregions": ["Peaks of Isolation", "Pharaoh's Den"],
		"acf": [
			["acf-peaks-camp", "Cragborn Highwatch", "Peaks of Isolation",
				"A frozen watchtower. Pilgrims ascend with names — none return with them.", 100, false],
			["acf-peaks-shrine", "Shrine of Hollow Identity", "Peaks of Isolation",
				"Where the Rite is performed. Masks line the basalt walls.", 180, false],
			["acf-pharaohs-den", "Pharaoh's Den Dig Site", "Pharaoh's Den",
				"Sand-buried tombs. Enclave expeditions are plundering identity-locks.", 140, false],
		],
	},
	{
		"id": "shadows", "name": "The Shadows Beneath",
		"flavor": "The undercity where whispers become laws.",
		"icon": "🕳",
		"pos": Vector2(0.68, 0.75),
		"accent": Color(0.55, 0.35, 0.75, 1.0),
		"badge": "Shadows Beneath Badge",
		"subregions": ["Shadows Beneath", "The Darkness", "House of Arachana", "Crypt at End of Valley", "Spindle York's Schism"],
		"acf": [
			["acf-shadows-junction", "Hollow Path Junction", "Shadows Beneath",
				"A convergence of lightless tunnels. The Enclave is wiring it as a ritual circuit.", 120, false],
			["acf-darkness-threshold", "Threshold of the Dark", "The Darkness",
				"Where light fails. Shades recruit from anyone who arrives alone.", 140, false],
			["acf-arachana-brood", "Arachana Brood Halls", "House of Arachana",
				"Blood-silk webs. A matriarch brokers souls to the Enclave for safe passage.", 180, false],
			["acf-crypt-end", "Crypt at Valley's End", "Crypt at End of Valley",
				"Last stop before the river. The tombwalkers are awake — and polite.", 160, false],
			["acf-spindle", "Spindle Schism Rift", "Spindle York's Schism",
				"A tear in time itself. Echoes of futures bleed through.", 220, true],
		],
	},
	{
		"id": "glass", "name": "The Glass Passage",
		"flavor": "A mirror-lined corridor where reflection is a weapon.",
		"icon": "🪞",
		"pos": Vector2(0.15, 0.40),
		"accent": Color(0.75, 0.95, 1.00, 1.0),
		"badge": "Glass Passage Badge",
		"subregions": ["Glass Passage", "Argent Hall", "Sacral Separation"],
		"acf": [
			["acf-glass-midpoint", "Mirrored Midpoint", "Glass Passage",
				"Where the true path diverges from its copy. Do not trust your own footsteps.", 140, false],
			["acf-argent-hall", "Argent Hall Vestibule", "Argent Hall",
				"Silver-veined marble. Lightbound guards test every traveller's reflection.", 120, false],
			["acf-sacral-rift", "Sacral Separation Rift", "Sacral Separation",
				"Faith splits cleanly here. A seraph's shed flesh warns the rest.", 180, false],
		],
	},
	{
		"id": "isles", "name": "The Isles",
		"flavor": "Salt-kissed archipelagos and drowned workshops.",
		"icon": "🏝",
		"pos": Vector2(0.82, 0.60),
		"accent": Color(0.20, 0.75, 0.85, 1.0),
		"badge": "Isles Badge",
		"subregions": ["The Isles", "Depths of Denorim", "Corrupted Marshes", "Gloamfen Hollow", "Moroboros"],
		"acf": [
			["acf-isles-harbor", "Tiderunner Harbor", "The Isles",
				"Our floating dock-yard. Smugglers run Enclave cores past the blockade nightly.", 120, false],
			["acf-denorim-depths", "Denorim Deep Shaft", "Depths of Denorim",
				"Pressure-crushed tunnels. Fathomari miners strike bargains with abyssal things.", 160, false],
			["acf-marshes-trail", "Corrupted Marshes Boardwalk", "Corrupted Marshes",
				"Blight creeps up the planks each night. Bogtenders are barely holding.", 140, false],
			["acf-gloamfen-hollow", "Gloamfen Hollow Basin", "Gloamfen Hollow",
				"Mossy ruins. Mirelings chant names of drowned gods.", 140, false],
			["acf-moroboros-den", "Moroboros Den", "Moroboros",
				"Where filth becomes mind. The Scornshard nests grow bold.", 180, true],
		],
	},
	{
		"id": "metro", "name": "The Metropolitan",
		"flavor": "The beating bureaucratic heart of the kingdoms.",
		"icon": "🏙",
		"pos": Vector2(0.35, 0.65),
		"accent": Color(0.95, 0.80, 0.30, 1.0),
		"badge": "Metropolitan Badge",
		"subregions": ["Metropolitan", "Upper Forty", "Lower Forty", "Eternal Library", "West End Gullet", "Cradling Depths"],
		"acf": [
			["acf-metro-plaza", "Metropolitan Central Plaza", "Metropolitan",
				"Civic records are being rewritten in broad daylight. No one notices.", 120, false],
			["acf-upper-forty", "Upper Forty Promenade", "Upper Forty",
				"Gilded balconies. Nobles whisper about memory gaps between cocktails.", 120, false],
			["acf-lower-forty", "Lower Forty Sluice", "Lower Forty",
				"Sewer tunnels. A rustspawn cell runs Enclave logistics from a scrap-den.", 140, false],
			["acf-eternal-library", "Eternal Library Annex", "Eternal Library",
				"Archivists are vanishing with their own indexes. Books breathe now.", 180, false],
			["acf-gullet", "West End Gullet Alley", "West End Gullet",
				"Where the city dumps what it can't admit. The gullet mimes run the block.", 120, false],
			["acf-cradling-depths", "Cradling Depths Cistern", "Cradling Depths",
				"Slime-choked under-galleries. A hollowroot network links the sewers citywide.", 160, false],
		],
	},
	{
		"id": "astral", "name": "The Astral Tear",
		"flavor": "A wound in reality that weeps futures.",
		"icon": "🌌",
		"pos": Vector2(0.85, 0.20),
		"accent": Color(0.70, 0.55, 0.95, 1.0),
		"badge": "Astral Tear Badge",
		"subregions": ["Astral Tear", "Arcane Collapse", "L.I.T.O.", "Land of Tomorrow"],
		"acf": [
			["acf-astral-anchor", "Astral Tear Anchor", "Astral Tear",
				"Final anchor point for the weave-unraveling ritual. Nirael walks there already.", 200, true],
			["acf-arcane-collapse", "Arcane Collapse Breach", "Arcane Collapse",
				"Where magic itself died. Riftborn survivors guard the wound.", 160, false],
			["acf-lito-foundry", "L.I.T.O. Clockwork Foundry", "L.I.T.O.",
				"A city-sized mechanism. Gears the size of cathedrals grind futures to dust.", 200, false],
			["acf-tomorrow-gate", "Gate of Tomorrow", "Land of Tomorrow",
				"A threshold where time runs backwards. Dreamer-priests warn: do not linger.", 240, false],
		],
	},
	{
		"id": "terminus", "name": "The Terminus Volarus",
		"flavor": "Storm-wracked skies where thunder has orders.",
		"icon": "⚡",
		"pos": Vector2(0.20, 0.15),
		"accent": Color(0.45, 0.70, 0.95, 1.0),
		"badge": "Terminus Volarus Badge",
		"subregions": ["Terminus Volarus", "City of Eternal Light", "Hallowed Sacrament"],
		"acf": [
			["acf-terminus-rod", "Lightning Rod Array", "Terminus Volarus",
				"A ritual SP-harvester drawing from the storm itself. Rurik commands the array.", 200, true],
			["acf-eternal-light", "City of Eternal Light Beacon", "City of Eternal Light",
				"The beacon never dims — and its keepers never sleep. Something is wrong with both facts.", 180, false],
			["acf-hallowed", "Hallowed Sacrament Reliquary", "Hallowed Sacrament",
				"Soulbinders have infiltrated the reliquary. A convergent prays over an empty seat.", 200, false],
		],
	},
	{
		"id": "titans", "name": "The Titan's Lament",
		"flavor": "Volcanic scar where ancient giants wept iron.",
		"icon": "🌋",
		"pos": Vector2(0.68, 0.35),
		"accent": Color(0.95, 0.50, 0.30, 1.0),
		"badge": "Titan's Lament Badge",
		"subregions": ["Titan's Lament", "Vulcan Valley", "Infernal Machine"],
		"acf": [
			["acf-titan-bound", "Chained Colossus Site", "Titan's Lament",
				"The Last Chain rattles in its socket. Morthis counts the spirit-names.", 220, true],
			["acf-vulcan-forge", "Vulcan Valley Forge", "Vulcan Valley",
				"Volcant smiths hammer soul-iron for the Enclave. Stop the shipments.", 180, false],
			["acf-infernal-gate", "Infernal Machine Gate", "Infernal Machine",
				"Hellforged sentinels guard a gate that should not exist.", 220, false],
		],
	},
	{
		"id": "sublimini", "name": "Sublimini Dominus",
		"flavor": "The beating heart of the void. Requires all 9 badges.",
		"icon": "🕳",
		"pos": Vector2(0.50, 0.90),
		"accent": Color(0.95, 0.20, 0.35, 1.0),
		"badge": "",
		"subregions": ["Sublimini Dominus", "Beating Heart of The Void"],
		"acf": [
			["acf-sublimini-threshold", "Sublimini Threshold", "Sublimini Dominus",
				"Metaphysical resonance only. The Culled watch from everywhere.", 300, false],
			["acf-void-heart", "Beating Heart of the Void", "Beating Heart of The Void",
				"The Architect conducts. End it here — or end everywhere.", 600, true],
		],
	},
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RimvaleUtils.add_bg(self, RimvaleColors.BG_DARK)

	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 0)
	add_child(main_vbox)

	# Tab selector buttons
	var tab_container = HBoxContainer.new()
	tab_container.custom_minimum_size.y = 60
	main_vbox.add_child(tab_container)

	var tabs = ["Map", "Missions", "Story", "Dungeon", "Crafting", "Foraging", "Rituals", "Base", "Magic"]
	for i in range(tabs.size()):
		var tab_btn = RimvaleUtils.button(tabs[i], RimvaleColors.ACCENT, 50, 14)
		tab_btn.pressed.connect(_on_tab_selected.bindv([i]))
		tab_container.add_child(tab_btn)

	RimvaleUtils.add_bg(tab_container, RimvaleColors.BG_CARD_DARK)

	# Content area — stored as class var so tab switching can reference it
	_content_area = Control.new()
	_content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_child(_content_area)

	# Initialize tabs
	_build_overworld_tab(_content_area)
	_build_missions_tab(_content_area)
	_build_story_tab(_content_area)
	_build_dungeon_tab(_content_area)
	_build_crafting_tab(_content_area)
	_build_foraging_tab(_content_area)
	_build_rituals_tab(_content_area)
	_build_base_tab(_content_area)
	_build_magic_world_tab(_content_area)

	# Show first tab
	_on_tab_selected(0)

func _on_tab_selected(idx: int) -> void:
	current_tab = idx
	for child in _content_area.get_children():
		child.visible = false
	if idx < _content_area.get_child_count():
		_content_area.get_child(idx).visible = true
	# When showing the overworld map, re-run the layout so buttons land correctly.
	if idx == 0 and _overworld_map_control != null:
		call_deferred("_overworld_layout_regions")
	# Auto-save whenever the player navigates — keeps state fresh
	GameState.save_game()

func _build_missions_tab(parent: Control) -> void:
	var missions_panel = Control.new()
	missions_panel.anchor_left = 0.0
	missions_panel.anchor_top = 0.0
	missions_panel.anchor_right = 1.0
	missions_panel.anchor_bottom = 1.0
	missions_panel.visible = false
	parent.add_child(missions_panel)

	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	missions_panel.add_child(vbox)

	# Region filter buttons
	var regions = RimvaleAPI.engine.get_all_regions()
	var region_scroll = ScrollContainer.new()
	region_scroll.custom_minimum_size.y = 80
	var region_hbox = HBoxContainer.new()
	region_hbox.add_theme_constant_override("separation", 8)
	region_scroll.add_child(region_hbox)
	vbox.add_child(region_scroll)

	# "All" clears filter
	var all_btn = RimvaleUtils.button("All", RimvaleColors.ACCENT, 70, 12)
	all_btn.pressed.connect(func(): _on_region_filter_selected(""))
	region_hbox.add_child(all_btn)

	for region in regions:
		var region_btn = RimvaleUtils.button(str(region), RimvaleColors.CYAN, 70, 12)
		region_btn.pressed.connect(_on_region_filter_selected.bindv([str(region)]))
		region_hbox.add_child(region_btn)

	vbox.add_child(RimvaleUtils.spacer(8))

	# Quests list
	var quests_scroll = ScrollContainer.new()
	quests_scroll.anchor_left = 0.0
	quests_scroll.anchor_top = 0.0
	quests_scroll.anchor_right = 1.0
	quests_scroll.anchor_bottom = 1.0
	quests_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_quests_vbox = VBoxContainer.new()
	_quests_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quests_scroll.add_child(_quests_vbox)
	vbox.add_child(quests_scroll)

	# Generate quest button
	var gen_quest_btn = RimvaleUtils.button("Generate Quest", RimvaleColors.GOLD, 60, 14)
	gen_quest_btn.pressed.connect(_on_generate_quest)
	vbox.add_child(gen_quest_btn)

	# Sample quests
	_generate_sample_quests()
	_refresh_quests_display(_quests_vbox)

func _build_story_tab(parent: Control) -> void:
	var story_panel = Control.new()
	story_panel.anchor_left   = 0.0; story_panel.anchor_top    = 0.0
	story_panel.anchor_right  = 1.0; story_panel.anchor_bottom = 1.0
	story_panel.visible = false
	parent.add_child(story_panel)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	story_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# ── Badge Row ────────────────────────────────────────────────────────────
	var badge_card = PanelContainer.new()
	badge_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bcard_style = StyleBoxFlat.new()
	bcard_style.bg_color = Color(0.10, 0.10, 0.16, 1.0)
	bcard_style.content_margin_left = 10; bcard_style.content_margin_right  = 10
	bcard_style.content_margin_top  = 8;  bcard_style.content_margin_bottom = 8
	badge_card.add_theme_stylebox_override("panel", bcard_style)
	vbox.add_child(badge_card)

	var badge_vbox = VBoxContainer.new()
	badge_vbox.add_theme_constant_override("separation", 6)
	badge_card.add_child(badge_vbox)

	var badge_hdr = HBoxContainer.new()
	badge_hdr.add_theme_constant_override("separation", 6)
	badge_hdr.add_child(RimvaleUtils.label("🏅", 14, Color(1.0, 0.84, 0.0)))
	_story_badge_lbl = RimvaleUtils.label(
		"Region Badges  0/9", 13, RimvaleColors.TEXT_WHITE)
	badge_hdr.add_child(_story_badge_lbl)
	badge_vbox.add_child(badge_hdr)

	var badge_scroll = ScrollContainer.new()
	badge_scroll.custom_minimum_size = Vector2(0, 48)
	var badge_hbox = HBoxContainer.new()
	badge_hbox.add_theme_constant_override("separation", 6)
	badge_scroll.add_child(badge_hbox)
	badge_vbox.add_child(badge_scroll)

	# Populate badge chips (will update based on GameState)
	var BADGE_NAMES: Array = [
		"Plains Badge", "Shadows Beneath Badge", "Astral Tear Badge",
		"Terminus Volarus Badge", "Glass Passage Badge", "Isles Badge",
		"Metropolitan Badge", "Titan's Lament Badge", "Peaks of Isolation Badge",
	]
	for badge in BADGE_NAMES:
		var earned: bool = badge in GameState.story_earned_badges
		var short_name: String = badge.replace(" Badge", "").split(" ")[0]
		var chip_style = StyleBoxFlat.new()
		chip_style.bg_color = Color(0.85, 0.65, 0.0, 1.0) if earned else Color(0.15, 0.15, 0.20, 1.0)
		chip_style.corner_radius_top_left     = 4; chip_style.corner_radius_top_right    = 4
		chip_style.corner_radius_bottom_left  = 4; chip_style.corner_radius_bottom_right = 4
		chip_style.content_margin_left = 6; chip_style.content_margin_right  = 6
		chip_style.content_margin_top  = 3; chip_style.content_margin_bottom = 3
		var chip = PanelContainer.new()
		chip.add_theme_stylebox_override("panel", chip_style)
		var chip_lbl = RimvaleUtils.label(short_name, 10,
			Color(0.24, 0.16, 0.0) if earned else RimvaleColors.TEXT_GRAY)
		chip.add_child(chip_lbl)
		badge_hbox.add_child(chip)

	_update_story_badge_lbl()

	vbox.add_child(RimvaleUtils.spacer(2))

	# ── Training Section ──────────────────────────────────────────────────────
	vbox.add_child(_build_story_section_card(
		"Training", "training", TRAINING_MISSIONS, false))

	# ── Story Sections ────────────────────────────────────────────────────────
	_story_sections_vbox = VBoxContainer.new()
	_story_sections_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_story_sections_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(_story_sections_vbox)
	_rebuild_story_sections()

func _update_story_badge_lbl() -> void:
	if _story_badge_lbl == null:
		return
	var count: int = 0
	var BADGE_NAMES: Array = [
		"Plains Badge", "Shadows Beneath Badge", "Astral Tear Badge",
		"Terminus Volarus Badge", "Glass Passage Badge", "Isles Badge",
		"Metropolitan Badge", "Titan's Lament Badge", "Peaks of Isolation Badge",
	]
	for b in BADGE_NAMES:
		if b in GameState.story_earned_badges:
			count += 1
	_story_badge_lbl.text = "Region Badges  %d/9" % count

func _rebuild_story_sections() -> void:
	if _story_sections_vbox == null:
		return
	for c in _story_sections_vbox.get_children():
		c.queue_free()
	for sec in STORY_SECTIONS:
		_story_sections_vbox.add_child(_build_story_section_card(
			sec[1], sec[0], sec[4], sec[3]))

func _build_story_section_card(
		section_title: String, section_id: String,
		missions: Array, requires_all_badges: bool) -> Control:
	# Determine unlock state
	var badge_count: int = GameState.story_earned_badges.size()
	var unlocked: bool = not requires_all_badges or badge_count >= 9

	# Find badge for this section (only regional sections, not training/sublimini)
	var badge_earned: bool = false
	for sec in STORY_SECTIONS:
		if sec[0] == section_id and sec[2] != "":
			badge_earned = sec[2] in GameState.story_earned_badges
			break

	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = (
		Color(0.10, 0.16, 0.10, 1.0) if badge_earned
		else Color(0.08, 0.08, 0.12, 0.7) if not unlocked
		else Color(0.10, 0.10, 0.16, 1.0)
	)
	card_style.content_margin_left = 10; card_style.content_margin_right  = 10
	card_style.content_margin_top  = 8;  card_style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", card_style)

	var cvbox = VBoxContainer.new()
	cvbox.add_theme_constant_override("separation", 0)
	card.add_child(cvbox)

	# Header row
	var hdr = HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	cvbox.add_child(hdr)

	# Icon
	var icon_str: String = (
		"🏅" if badge_earned
		else "🔒" if not unlocked
		else "📖"
	)
	hdr.add_child(RimvaleUtils.label(icon_str, 14, Color(1.0, 0.84, 0.0)))

	# Title + progress
	var title_vbox = VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 2)
	hdr.add_child(title_vbox)

	title_vbox.add_child(RimvaleUtils.label(
		section_title, 13, RimvaleColors.TEXT_WHITE))

	if not unlocked:
		title_vbox.add_child(RimvaleUtils.label(
			"Requires all 9 region badges (%d/9)" % badge_count, 10, RimvaleColors.TEXT_GRAY))
	else:
		var done: int = 0
		for m in missions:
			if m[0] in GameState.story_completed_missions:
				done += 1
		var prog_str: String = "%d/%d completed" % [done, missions.size()]
		if badge_earned and section_id != "training":
			for sec in STORY_SECTIONS:
				if sec[0] == section_id:
					prog_str += "  ·  " + sec[2]
					break
		title_vbox.add_child(RimvaleUtils.label(prog_str, 10, RimvaleColors.TEXT_GRAY))

	# Expand button (only if unlocked)
	var expand_btn: Button = null
	if unlocked:
		expand_btn = RimvaleUtils.button("▼", RimvaleColors.TEXT_GRAY, 24, 11)
		hdr.add_child(expand_btn)

	# Mission list (hidden by default)
	var missions_vbox = VBoxContainer.new()
	missions_vbox.add_theme_constant_override("separation", 0)
	missions_vbox.visible = false
	cvbox.add_child(missions_vbox)

	# Separator + mission rows
	missions_vbox.add_child(RimvaleUtils.spacer(6))
	missions_vbox.add_child(RimvaleUtils.separator())

	for m_data in missions:
		missions_vbox.add_child(_build_story_mission_row(m_data))

	# Wire expand button
	if expand_btn:
		expand_btn.pressed.connect(func():
			missions_vbox.visible = not missions_vbox.visible
			expand_btn.text = "▲" if missions_vbox.visible else "▼"
		)

	return card

func _build_story_mission_row(m_data: Array) -> Control:
	# m_data: [id, title, region, teaser, xp, is_boss]
	var mid: String     = m_data[0]
	var mtitle: String  = m_data[1]
	var mregion: String = m_data[2]
	var mteaser: String = m_data[3]
	var mxp: int        = m_data[4]
	var is_boss: bool   = m_data[5]
	var completed: bool = mid in GameState.story_completed_missions

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 50)

	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	row.add_child(info_vbox)

	# Title row
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 4)
	if is_boss:
		title_row.add_child(RimvaleUtils.label("⚔", 11, RimvaleColors.DANGER if not completed else RimvaleColors.TEXT_GRAY))
	title_row.add_child(RimvaleUtils.label(
		mtitle, 12,
		RimvaleColors.TEXT_WHITE if not completed else RimvaleColors.TEXT_GRAY))
	if completed:
		title_row.add_child(RimvaleUtils.label("✓", 12, RimvaleColors.HP_GREEN))
	info_vbox.add_child(title_row)

	info_vbox.add_child(RimvaleUtils.label(mregion, 10, RimvaleColors.CYAN))
	var teaser_lbl = RimvaleUtils.label(mteaser, 10, RimvaleColors.TEXT_GRAY)
	teaser_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(teaser_lbl)

	# XP + play button
	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 4)
	row.add_child(right_vbox)

	var xp_show: int = maxi(1, mxp / 10) if completed else mxp
	right_vbox.add_child(RimvaleUtils.label(
		str(xp_show) + " XP", 10,
		RimvaleColors.TEXT_GRAY if completed else RimvaleColors.GOLD))

	var btn_color: Color = RimvaleColors.DANGER if is_boss else RimvaleColors.ACCENT
	var btn_lbl: String  = "Replay" if completed else "Begin"
	var play_btn = RimvaleUtils.button(btn_lbl, btn_color, 28, 11)
	play_btn.custom_minimum_size = Vector2(60, 28)
	var cap_mid = mid; var cap_title = mtitle
	var cap_teaser = mteaser; var cap_xp = mxp
	play_btn.pressed.connect(func():
		_start_story_mission(cap_mid, cap_title, cap_teaser, cap_xp))
	right_vbox.add_child(play_btn)

	return row

func _start_story_mission(mid: String, title: String, teaser: String, xp: int) -> void:
	var party: Array = GameState.get_active_handles()
	if party.is_empty():
		push_warning("[Story] No active party")
		return

	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.get_ok_button().text = "Complete Mission"
	dialog.min_size = Vector2i(460, 340)

	var dvbox = VBoxContainer.new()
	dvbox.add_theme_constant_override("separation", 8)
	dialog.add_child(dvbox)

	var teaser_lbl = RimvaleUtils.label(teaser, 12, RimvaleColors.TEXT_WHITE)
	teaser_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dvbox.add_child(teaser_lbl)
	dvbox.add_child(HSeparator.new())

	# Simple skill check log
	var dc: int = 12
	var log_rtl = RichTextLabel.new()
	log_rtl.bbcode_enabled = true
	log_rtl.fit_content = true
	log_rtl.scroll_active = false
	log_rtl.add_theme_font_size_override("normal_font_size", 12)
	log_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dvbox.add_child(log_rtl)

	var checks: Array = ["Perception", "Exertion", "Survival"]
	var log_text: String = ""
	var successes: int = 0
	for skill in checks:
		var best: PackedStringArray = PackedStringArray()
		var best_total: int = 0
		for ph in party:
			var result: PackedStringArray = RimvaleAPI.engine.execute_skill_challenge(ph, skill, dc)
			if result.is_empty(): continue
			var total: int = int(str(result[1]))
			if total > best_total:
				best_total = total; best = result
		if best.is_empty():
			best = RimvaleAPI.engine.execute_skill_challenge(-1, skill, dc)
		var passed: bool = (not best.is_empty()) and best[0] == "1"
		if passed: successes += 1
		var detail: String = str(best[4]) if best.size() > 4 else "No roll data"
		var col: String = "#88dd88" if passed else "#dd8888"
		log_text += "[b]%s check (DC %d)[/b]\n[color=%s]%s[/color]\n\n" % [skill, dc, col, detail]
	log_rtl.text = log_text

	var victory: bool = successes >= ceili(checks.size() / 2.0)
	if victory:
		dvbox.add_child(RimvaleUtils.label(
			"✓ MISSION COMPLETE — +%d XP" % xp, 14, Color(0.50, 0.90, 0.50)))
	else:
		dvbox.add_child(RimvaleUtils.label(
			"✗ MISSION FAILED — %d/%d checks passed" % [successes, checks.size()],
			14, Color(0.90, 0.40, 0.40)))

	dialog.confirmed.connect(func():
		if victory:
			if mid not in GameState.story_completed_missions:
				GameState.story_completed_missions.append(mid)
				for ph in party:
					RimvaleAPI.engine.add_xp(ph, xp, 20)
				_check_and_award_story_badges()
			_update_story_badge_lbl()
			_rebuild_story_sections()
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2(460, 340))

func _check_and_award_story_badges() -> void:
	for sec in STORY_SECTIONS:
		var badge: String = sec[2]
		if badge.is_empty() or badge in GameState.story_earned_badges:
			continue
		var all_done: bool = true
		for m in (sec[4] as Array):
			if m[0] not in GameState.story_completed_missions:
				all_done = false; break
		if all_done:
			GameState.story_earned_badges.append(badge)

func _build_dungeon_tab(parent: Control) -> void:
	var dungeon_panel = Control.new()
	dungeon_panel.anchor_left   = 0.0
	dungeon_panel.anchor_top    = 0.0
	dungeon_panel.anchor_right  = 1.0
	dungeon_panel.anchor_bottom = 1.0
	dungeon_panel.visible = false
	parent.add_child(dungeon_panel)

	var scroll = ScrollContainer.new()
	scroll.anchor_left   = 0.0
	scroll.anchor_top    = 0.0
	scroll.anchor_right  = 1.0
	scroll.anchor_bottom = 1.0
	dungeon_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	# ── Header ──────────────────────────────────────────────────────────────
	vbox.add_child(RimvaleUtils.label("Dungeon Dive", 18, RimvaleColors.ACCENT))
	var sub_lbl = RimvaleUtils.label(
		"Enter the field for tactical maneuvers and environmental data collection.",
		12, RimvaleColors.TEXT_GRAY)
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(sub_lbl)
	vbox.add_child(RimvaleUtils.spacer(4))

	# ── Encounter Type ───────────────────────────────────────────────────────
	vbox.add_child(RimvaleUtils.label("Encounter Type", 14, RimvaleColors.TEXT_WHITE))

	var type_data: Array = [
		["Launch Simulation", RimvaleColors.ACCENT],
		["Kaiju Hunt",        Color(0.90, 0.20, 0.20, 1.0)],
		["Apex Encounter",    Color(0.48, 0.12, 0.64, 1.0)],
		["Militia Encounter", Color(0.00, 0.51, 0.56, 1.0)],
		["Mob Encounter",     Color(0.75, 0.44, 0.25, 1.0)],
	]
	_dd_type_btns.clear()
	for i in range(type_data.size()):
		var td = type_data[i]
		var btn = RimvaleUtils.button(td[0], td[1], 52, 13)
		btn.custom_minimum_size = Vector2(220, 52)
		btn.pressed.connect(_dd_select_type.bind(i))
		vbox.add_child(btn)
		_dd_type_btns.append(btn)

	vbox.add_child(RimvaleUtils.separator())

	# ── Config Panel (swapped by encounter type) ─────────────────────────────
	_dd_config_panel = VBoxContainer.new()
	_dd_config_panel.add_theme_constant_override("separation", 8)
	_dd_config_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_dd_config_panel)

	vbox.add_child(RimvaleUtils.separator())

	# ── Terrain Style ────────────────────────────────────────────────────────
	vbox.add_child(RimvaleUtils.label("Terrain Style", 14, RimvaleColors.TEXT_WHITE))

	var terrain_row = HBoxContainer.new()
	terrain_row.add_theme_constant_override("separation", 8)
	terrain_row.add_child(RimvaleUtils.label("Style:", 12, RimvaleColors.TEXT_GRAY))
	var terrain_opt = OptionButton.new()
	terrain_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for tname in DD_TERRAIN_NAMES:
		terrain_opt.add_item(tname)
	terrain_opt.selected = 0
	terrain_row.add_child(terrain_opt)
	vbox.add_child(terrain_row)

	var terrain_desc_lbl = RimvaleUtils.label(DD_TERRAIN_DESCS[0], 11, RimvaleColors.TEXT_GRAY)
	terrain_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(terrain_desc_lbl)

	terrain_opt.item_selected.connect(func(idx: int) -> void:
		_dd_terrain_style = idx
		terrain_desc_lbl.text = DD_TERRAIN_DESCS[idx])

	vbox.add_child(RimvaleUtils.spacer(6))

	# ── Allies deploying ─────────────────────────────────────────────────────
	if GameState.recruited_allies.size() > 0:
		vbox.add_child(RimvaleUtils.label("ALLIES DEPLOYING", 13, Color(0.20, 0.78, 0.40)))
		var allies_row = HBoxContainer.new()
		allies_row.add_theme_constant_override("separation", 8)
		vbox.add_child(allies_row)
		for ra in GameState.recruited_allies:
			var atype: String = str(ra.get("type", ""))
			var aicon: String = "👹" if atype == "kaiju" else ("🗡" if atype == "militia" else "🔥")
			var acol: Color = Color(0.90, 0.30, 0.20) if atype == "kaiju" else (Color(0.20, 0.65, 0.80) if atype == "militia" else Color(0.80, 0.65, 0.15))
			var chip := PanelContainer.new()
			var csb := StyleBoxFlat.new()
			csb.bg_color = Color(acol, 0.15)
			csb.border_color = Color(acol, 0.40)
			csb.set_border_width_all(1)
			csb.set_corner_radius_all(4)
			csb.set_content_margin_all(4)
			chip.add_theme_stylebox_override("panel", csb)
			chip.add_child(RimvaleUtils.label("%s %s" % [aicon, str(ra.get("name", "Ally"))], 10, acol))
			allies_row.add_child(chip)
		vbox.add_child(RimvaleUtils.spacer(4))

	# ── Launch Button ────────────────────────────────────────────────────────
	var launch_btn = RimvaleUtils.button("Launch Dungeon Dive", RimvaleColors.GOLD, 60, 14)
	launch_btn.custom_minimum_size = Vector2(250, 60)
	launch_btn.pressed.connect(_dd_launch)
	vbox.add_child(launch_btn)

	# Build initial config (Standard)
	_dd_rebuild_config()

func _dd_select_type(t: int) -> void:
	_dd_type = t
	_dd_rebuild_config()

func _dd_rebuild_config() -> void:
	for child in _dd_config_panel.get_children():
		child.queue_free()

	match _dd_type:
		0: # Standard Simulation
			var info = RimvaleUtils.label(
				"Combat simulation against enemies at the selected threat level.", 11, RimvaleColors.TEXT_GRAY)
			info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_dd_config_panel.add_child(info)
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var lbl = RimvaleUtils.label("Enemy Level: %d" % _dd_enemy_level, 13, RimvaleColors.TEXT_WHITE)
			lbl.custom_minimum_size = Vector2(150, 0)
			row.add_child(lbl)
			var slider = HSlider.new()
			slider.min_value = 1
			slider.max_value = 15
			slider.step = 1
			slider.value = _dd_enemy_level
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.value_changed.connect(func(v: float) -> void:
				_dd_enemy_level = int(v)
				lbl.text = "Enemy Level: %d" % _dd_enemy_level)
			row.add_child(slider)
			_dd_config_panel.add_child(row)

		1: # Kaiju Hunt
			var info = RimvaleUtils.label(
				"These beings are considered demigods. Only one or two may be seen worldwide each generation. Engage at your own risk.",
				11, RimvaleColors.TEXT_GRAY)
			info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_dd_config_panel.add_child(info)
			var kopt = OptionButton.new()
			kopt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for k in DD_KAIJUS:
				kopt.add_item(k[0])
			kopt.selected = _dd_kaiju_idx
			_dd_config_panel.add_child(kopt)
			var kdesc = RimvaleUtils.label(_dd_kaiju_desc(_dd_kaiju_idx), 11, RimvaleColors.TEXT_GRAY)
			kdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_dd_config_panel.add_child(kdesc)
			kopt.item_selected.connect(func(idx: int) -> void:
				_dd_kaiju_idx = idx
				kdesc.text = _dd_kaiju_desc(idx))

		2: # Apex Encounter
			var info = RimvaleUtils.label(
				"Apex monsters — powerful named threats each with unique mechanics and lore.", 11, RimvaleColors.TEXT_GRAY)
			info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_dd_config_panel.add_child(info)
			var aopt = OptionButton.new()
			aopt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for a in DD_APEXES:
				aopt.add_item(a[0])
			aopt.selected = _dd_apex_idx
			_dd_config_panel.add_child(aopt)
			var adesc = RimvaleUtils.label(_dd_apex_desc(_dd_apex_idx), 11, RimvaleColors.TEXT_GRAY)
			adesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_dd_config_panel.add_child(adesc)
			aopt.item_selected.connect(func(idx: int) -> void:
				_dd_apex_idx = idx
				adesc.text = _dd_apex_desc(idx))

		3: # Militia Encounter
			var info = RimvaleUtils.label(
				"Semi-organised forces with shared HP, AP, and SP pools. Each militia has distinct equipment, a defining trait, and optional command structure.",
				11, RimvaleColors.TEXT_GRAY)
			info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_dd_config_panel.add_child(info)
			var mopt = OptionButton.new()
			mopt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for m in DD_MILITIAS:
				mopt.add_item(m[0])
			mopt.selected = _dd_militia_idx
			_dd_config_panel.add_child(mopt)
			var mdesc = RimvaleUtils.label(_dd_militia_desc(_dd_militia_idx), 11, RimvaleColors.TEXT_GRAY)
			mdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_dd_config_panel.add_child(mdesc)
			mopt.item_selected.connect(func(idx: int) -> void:
				_dd_militia_idx = idx
				mdesc.text = _dd_militia_desc(idx))

		4: # Mob Encounter
			var info = RimvaleUtils.label(
				"A disorganised mass acting as a single chaotic unit. Choose size and threat level before engagement.",
				11, RimvaleColors.TEXT_GRAY)
			info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_dd_config_panel.add_child(info)

			# Member count slider
			var crow = HBoxContainer.new()
			crow.add_theme_constant_override("separation", 8)
			var clbl = RimvaleUtils.label("Members: %d" % _dd_mob_count, 13, RimvaleColors.TEXT_WHITE)
			clbl.custom_minimum_size = Vector2(150, 0)
			crow.add_child(clbl)
			var cslider = HSlider.new()
			cslider.min_value = 10
			cslider.max_value = 100
			cslider.step = 5
			cslider.value = _dd_mob_count
			cslider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			crow.add_child(cslider)
			_dd_config_panel.add_child(crow)
			var cinfo = RimvaleUtils.label(_dd_mob_size_label(_dd_mob_count), 11, RimvaleColors.TEXT_GRAY)
			_dd_config_panel.add_child(cinfo)
			cslider.value_changed.connect(func(v: float) -> void:
				_dd_mob_count = int(v)
				clbl.text = "Members: %d" % _dd_mob_count
				cinfo.text = _dd_mob_size_label(_dd_mob_count))

			# Threat level slider
			var lrow = HBoxContainer.new()
			lrow.add_theme_constant_override("separation", 8)
			var llbl = RimvaleUtils.label("Threat Level: %d" % _dd_mob_level, 13, RimvaleColors.TEXT_WHITE)
			llbl.custom_minimum_size = Vector2(150, 0)
			lrow.add_child(llbl)
			var lslider = HSlider.new()
			lslider.min_value = 1
			lslider.max_value = 10
			lslider.step = 1
			lslider.value = _dd_mob_level
			lslider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lslider.value_changed.connect(func(v: float) -> void:
				_dd_mob_level = int(v)
				llbl.text = "Threat Level: %d" % _dd_mob_level)
			lrow.add_child(lslider)
			_dd_config_panel.add_child(lrow)

func _dd_mob_size_label(count: int) -> String:
	if count <= 20:
		return "Small mob (≤20) — +5 ft movement"
	elif count <= 50:
		return "Standard mob (21–50)"
	else:
		return "Large mob (≥51) — −5 ft movement"

func _dd_kaiju_desc(idx: int) -> String:
	if idx < 0 or idx >= DD_KAIJUS.size():
		return ""
	var k: Array = DD_KAIJUS[idx]
	return "%s, %s\n%s" % [k[0], k[1], k[2]]

func _dd_apex_desc(idx: int) -> String:
	if idx < 0 or idx >= DD_APEXES.size():
		return ""
	var a: Array = DD_APEXES[idx]
	return "%s, %s\n%s" % [a[0], a[1], a[2]]

func _dd_militia_desc(idx: int) -> String:
	if idx < 0 or idx >= DD_MILITIAS.size():
		return ""
	var m: Array = DD_MILITIAS[idx]
	return "%s\n%s" % [m[1], m[2]]

func _dd_launch() -> void:
	var handles: PackedInt64Array = GameState.get_active_handles()
	if handles.is_empty():
		push_warning("[Dungeon] No active party — assign a strike team first")
		return
	match _dd_type:
		0: # Standard
			RimvaleAPI.engine.start_dungeon(handles, _dd_enemy_level, 0, _dd_terrain_style)
		1: # Kaiju
			RimvaleAPI.engine.start_kaiju_dungeon(handles, _dd_kaiju_idx, _dd_terrain_style)
		2: # Apex
			RimvaleAPI.engine.start_apex_dungeon(handles, _dd_apex_idx, _dd_terrain_style)
		3: # Militia
			RimvaleAPI.engine.start_militia_dungeon(handles, _dd_militia_idx, _dd_terrain_style)
		4: # Mob
			RimvaleAPI.engine.start_mob_dungeon(handles, _dd_mob_count, _dd_mob_level, _dd_terrain_style)
	# Spawn recruited allies into the dungeon as friendly entities
	if GameState.recruited_allies.size() > 0:
		RimvaleAPI.engine.spawn_allies(GameState.recruited_allies)
	# Push dungeon as a full-screen overlay through the main shell.
	var main = get_parent().get_parent() if get_parent() else null
	if main and main.has_method("push_screen"):
		main.push_screen("res://scenes/dungeon/dungeon.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/dungeon/dungeon.tscn")

func _build_crafting_tab(parent: Control) -> void:
	var craft_panel = Control.new()
	craft_panel.anchor_left = 0.0
	craft_panel.anchor_top = 0.0
	craft_panel.anchor_right = 1.0
	craft_panel.anchor_bottom = 1.0
	craft_panel.visible = false
	parent.add_child(craft_panel)

	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 12)
	craft_panel.add_child(vbox)

	vbox.add_child(RimvaleUtils.label("Assign Crafting Tasks", 16, RimvaleColors.ACCENT))

	# Party member selector
	_craft_active_handles = GameState.get_active_handles()
	if _craft_active_handles.size() > 0:
		var member_hbox = HBoxContainer.new()
		member_hbox.add_child(RimvaleUtils.label("Crafter:", 12, RimvaleColors.TEXT_WHITE))
		_craft_member_dropdown = OptionButton.new()
		for h in _craft_active_handles:
			var cname: String = str(RimvaleAPI.engine.get_character_name(h))
			_craft_member_dropdown.add_item(cname)
		member_hbox.add_child(_craft_member_dropdown)
		vbox.add_child(member_hbox)

	# Item type selector — populated from engine recipe DB
	_craftable_items = RimvaleAPI.engine.get_craftable_items()
	var type_hbox = HBoxContainer.new()
	type_hbox.add_child(RimvaleUtils.label("Item:", 12, RimvaleColors.TEXT_WHITE))
	_craft_type_dropdown = OptionButton.new()
	for item_entry in _craftable_items:
		var iname: String = str(item_entry[0])
		_craft_type_dropdown.add_item(iname)
	if _craftable_items.is_empty():
		for fallback in ["Weapon", "Armor", "Potion", "Tool"]:
			_craft_type_dropdown.add_item(fallback)
	_craft_type_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_hbox.add_child(_craft_type_dropdown)
	vbox.add_child(type_hbox)

	# Recipe detail label (shows materials + duration for selected item)
	var recipe_lbl := RimvaleUtils.label("", 11, RimvaleColors.TEXT_GRAY)
	recipe_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(recipe_lbl)
	_craft_type_dropdown.item_selected.connect(func(idx: int):
		if idx < _craftable_items.size():
			var entry: PackedStringArray = _craftable_items[idx] as PackedStringArray
			var dur_sec: int = int(str(entry[2])) if entry.size() > 2 else 60
			var mins: int = dur_sec / 60; var secs: int = dur_sec % 60
			var dur_str: String = "%dm %ds" % [mins, secs] if mins > 0 else "%ds" % secs
			recipe_lbl.text = "Materials: %s  |  Time: %s" % [str(entry[1]), dur_str]
		else:
			recipe_lbl.text = ""
	)
	# Trigger initial recipe display
	if not _craftable_items.is_empty():
		var first: PackedStringArray = _craftable_items[0] as PackedStringArray
		var dur0: int = int(str(first[2])) if first.size() > 2 else 60
		var m0: int = dur0 / 60; var s0: int = dur0 % 60
		recipe_lbl.text = "Materials: %s  |  Time: %s" % [str(first[1]),
			"%dm %ds" % [m0, s0] if m0 > 0 else "%ds" % s0]

	var assign_btn = RimvaleUtils.button("Start Crafting", RimvaleColors.GOLD, 60, 14)
	assign_btn.pressed.connect(_on_assign_crafting)
	vbox.add_child(assign_btn)

	vbox.add_child(RimvaleUtils.separator())

	# Active tasks
	vbox.add_child(RimvaleUtils.label("Active Tasks", 16, RimvaleColors.ACCENT))
	var tasks_scroll = ScrollContainer.new()
	tasks_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_craft_tasks_vbox = VBoxContainer.new()
	_craft_tasks_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tasks_scroll.add_child(_craft_tasks_vbox)
	vbox.add_child(tasks_scroll)

	_refresh_crafting_tasks()

func _build_foraging_tab(parent: Control) -> void:
	var forage_panel = Control.new()
	forage_panel.anchor_left = 0.0
	forage_panel.anchor_top = 0.0
	forage_panel.anchor_right = 1.0
	forage_panel.anchor_bottom = 1.0
	forage_panel.visible = false
	parent.add_child(forage_panel)

	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 12)
	forage_panel.add_child(vbox)

	vbox.add_child(RimvaleUtils.label("Assign Foraging Tasks", 16, RimvaleColors.ACCENT))

	# Selected forage type label
	var forage_type_lbl = RimvaleUtils.label("Type: Hunting", 12, RimvaleColors.CYAN)
	vbox.add_child(forage_type_lbl)

	# Forage type buttons
	var forage_types = [["🏹 Hunting", "hunting"], ["🎣 Fishing", "fishing"], ["⛏ Mining", "mining"], ["🌿 Gathering", "gathering"]]
	var forage_hbox = HBoxContainer.new()
	forage_hbox.add_theme_constant_override("separation", 8)
	for forage_data in forage_types:
		var forage_btn = RimvaleUtils.button(forage_data[0], RimvaleColors.CYAN, 50, 12)
		var ft: String = forage_data[1]
		forage_btn.pressed.connect(func():
			_on_foraging_selected(ft)
			forage_type_lbl.text = "Type: " + ft.capitalize())
		forage_hbox.add_child(forage_btn)
	vbox.add_child(forage_hbox)

	# Character selector
	_forage_active_handles = GameState.get_active_handles()
	if _forage_active_handles.size() > 0:
		var char_hbox = HBoxContainer.new()
		char_hbox.add_child(RimvaleUtils.label("Character:", 12, RimvaleColors.TEXT_WHITE))
		_forage_char_dropdown = OptionButton.new()
		for h in _forage_active_handles:
			var cname: String = str(RimvaleAPI.engine.get_character_name(h))
			_forage_char_dropdown.add_item(cname)
		_forage_char_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		char_hbox.add_child(_forage_char_dropdown)
		vbox.add_child(char_hbox)

	var assign_forage_btn = RimvaleUtils.button("Start Foraging", RimvaleColors.GOLD, 60, 14)
	assign_forage_btn.pressed.connect(_on_assign_foraging)
	vbox.add_child(assign_forage_btn)

	vbox.add_child(RimvaleUtils.separator())

	# Active forages
	vbox.add_child(RimvaleUtils.label("Active Tasks", 16, RimvaleColors.ACCENT))
	var forage_scroll = ScrollContainer.new()
	forage_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_forage_tasks_vbox = VBoxContainer.new()
	_forage_tasks_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forage_scroll.add_child(_forage_tasks_vbox)
	vbox.add_child(forage_scroll)

	_refresh_forage_tasks()

func _build_rituals_tab(parent: Control) -> void:
	var rituals_panel = Control.new()
	rituals_panel.anchor_left   = 0.0; rituals_panel.anchor_top    = 0.0
	rituals_panel.anchor_right  = 1.0; rituals_panel.anchor_bottom = 1.0
	rituals_panel.visible = false
	parent.add_child(rituals_panel)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rituals_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	# ── Header row ───────────────────────────────────────────────────────────
	var hdr = HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	vbox.add_child(hdr)

	var hdr_vbox = VBoxContainer.new()
	hdr_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_vbox.add_theme_constant_override("separation", 2)
	hdr.add_child(hdr_vbox)
	hdr_vbox.add_child(RimvaleUtils.label("Arcane Rituals", 16, RimvaleColors.ACCENT))
	hdr_vbox.add_child(RimvaleUtils.label(
		"Extended casting for powerful effects.", 11, RimvaleColors.TEXT_GRAY))

	var new_ritual_btn = RimvaleUtils.button("+ New Ritual", RimvaleColors.SP_PURPLE, 36, 12)
	new_ritual_btn.custom_minimum_size = Vector2(110, 36)
	new_ritual_btn.pressed.connect(_on_new_ritual)
	hdr.add_child(new_ritual_btn)

	# ── Result message (hidden until Make Check) ─────────────────────────────
	_ritual_result_lbl = RimvaleUtils.label("", 12, RimvaleColors.TEXT_WHITE)
	_ritual_result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ritual_result_lbl.visible = false
	vbox.add_child(_ritual_result_lbl)

	# ── In-Progress Rituals ───────────────────────────────────────────────────
	vbox.add_child(RimvaleUtils.label("In Progress", 13, RimvaleColors.TEXT_LIGHT))
	_ritual_tasks_vbox = VBoxContainer.new()
	_ritual_tasks_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ritual_tasks_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(_ritual_tasks_vbox)

	vbox.add_child(RimvaleUtils.separator())

	# ── Active Rituals ────────────────────────────────────────────────────────
	vbox.add_child(RimvaleUtils.label(
		"Active Spells (Ready for Dungeon)", 13, RimvaleColors.TEXT_LIGHT))
	_ritual_active_vbox = VBoxContainer.new()
	_ritual_active_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ritual_active_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(_ritual_active_vbox)

	# ── Empty state ───────────────────────────────────────────────────────────
	_ritual_empty_lbl = RimvaleUtils.label(
		"No active rituals.\nTap 'New Ritual' to design and begin extended casting.",
		12, RimvaleColors.TEXT_GRAY)
	_ritual_empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_ritual_empty_lbl)

	_refresh_ritual_ui()

func _refresh_ritual_ui() -> void:
	if _ritual_tasks_vbox == null:
		return

	# Clear both lists
	for c in _ritual_tasks_vbox.get_children(): c.queue_free()
	for c in _ritual_active_vbox.get_children(): c.queue_free()

	var any_content: bool = false

	# ── In-progress tasks ────────────────────────────────────────────────────
	for task in GameState.ritual_tasks:
		any_content = true
		var dc: int = 10 + int(task["sp_committed"])
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.06, 0.08, 0.30, 1.0)
		card_style.content_margin_left = 10; card_style.content_margin_right  = 10
		card_style.content_margin_top  = 8;  card_style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", card_style)
		var card_vbox = VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 4)
		card.add_child(card_vbox)

		# Title row
		var title_hbox = HBoxContainer.new()
		title_hbox.add_theme_constant_override("separation", 8)
		title_hbox.add_child(RimvaleUtils.label(
			str(task["spell_name"]), 13, RimvaleColors.TEXT_WHITE))
		title_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var dc_lbl = RimvaleUtils.label("DC %d" % dc, 12, RimvaleColors.ORANGE)
		title_hbox.add_child(dc_lbl)
		card_vbox.add_child(title_hbox)

		var desc_lbl = RimvaleUtils.label(str(task["spell_desc"]), 11, RimvaleColors.TEXT_GRAY)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_vbox.add_child(desc_lbl)
		card_vbox.add_child(RimvaleUtils.label(
			"Caster: %s · SP committed: %d" % [str(task["caster_name"]), int(task["sp_committed"])],
			10, RimvaleColors.TEXT_GRAY))

		# Action buttons row
		var btn_row = HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 6)
		card_vbox.add_child(btn_row)

		var task_id: String = str(task["id"])
		var make_check_btn = RimvaleUtils.button("Make Check", RimvaleColors.AP_BLUE, 30, 10)
		make_check_btn.pressed.connect(func(): _ritual_make_check(task_id))
		btn_row.add_child(make_check_btn)

		var add_sp_btn = RimvaleUtils.button("Add SP (DC→%d)" % (dc + 1), RimvaleColors.SP_PURPLE, 30, 10)
		add_sp_btn.pressed.connect(func(): _ritual_add_sp(task_id))
		btn_row.add_child(add_sp_btn)

		var abandon_btn = RimvaleUtils.button("Abandon", RimvaleColors.DANGER, 30, 10)
		abandon_btn.pressed.connect(func(): _ritual_abandon(task_id))
		btn_row.add_child(abandon_btn)

		_ritual_tasks_vbox.add_child(card)

	if GameState.ritual_tasks.is_empty():
		_ritual_tasks_vbox.add_child(
			RimvaleUtils.label("No rituals in progress.", 12, RimvaleColors.TEXT_GRAY))

	# ── Active rituals ────────────────────────────────────────────────────────
	for ritual in GameState.active_rituals:
		any_content = true
		var acard = PanelContainer.new()
		acard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var acard_style = StyleBoxFlat.new()
		acard_style.bg_color = Color(0.06, 0.22, 0.08, 1.0)
		acard_style.content_margin_left = 10; acard_style.content_margin_right  = 10
		acard_style.content_margin_top  = 8;  acard_style.content_margin_bottom = 8
		acard.add_theme_stylebox_override("panel", acard_style)

		var acbox = HBoxContainer.new()
		acbox.add_theme_constant_override("separation", 8)
		acard.add_child(acbox)

		var a_info = VBoxContainer.new()
		a_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		a_info.add_theme_constant_override("separation", 2)
		acbox.add_child(a_info)

		a_info.add_child(RimvaleUtils.label(
			"✦ " + str(ritual["spell_name"]), 13, Color(1.0, 0.84, 0.3)))
		var adesc_lbl = RimvaleUtils.label(str(ritual["spell_desc"]), 10, RimvaleColors.TEXT_GRAY)
		adesc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		a_info.add_child(adesc_lbl)
		a_info.add_child(RimvaleUtils.label(
			"Caster: %s · SP: %d" % [str(ritual["caster_name"]), int(ritual["sp_committed"])],
			10, RimvaleColors.TEXT_GRAY))

		var ritual_id: String = str(ritual["id"])
		var dispel_btn = RimvaleUtils.button("Dispel", RimvaleColors.DANGER, 28, 10)
		dispel_btn.pressed.connect(func(): _ritual_dispel(ritual_id))
		acbox.add_child(dispel_btn)
		_ritual_active_vbox.add_child(acard)

	if GameState.active_rituals.is_empty():
		_ritual_active_vbox.add_child(
			RimvaleUtils.label("No active spells.", 12, RimvaleColors.TEXT_GRAY))

	if _ritual_empty_lbl:
		_ritual_empty_lbl.visible = not any_content

func _on_new_ritual() -> void:
	var handles: Array = GameState.get_active_handles()
	if handles.is_empty():
		push_warning("[Rituals] No active party members")
		return

	var dialog = AcceptDialog.new()
	dialog.title = "Design Ritual Spell"
	dialog.get_ok_button().text = "Begin Ritual"
	dialog.min_size = Vector2i(460, 480)

	var dvbox = VBoxContainer.new()
	dvbox.add_theme_constant_override("separation", 8)
	dialog.add_child(dvbox)

	dvbox.add_child(RimvaleUtils.label("Caster", 12, RimvaleColors.TEXT_WHITE))
	var caster_opt = OptionButton.new()
	caster_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sp_by_idx: Array = []
	for h in handles:
		var cname: String = str(RimvaleAPI.engine.get_character_name(h))
		var sp_cur: int = RimvaleAPI.engine.get_character_sp(h)
		caster_opt.add_item("%s  (%d SP)" % [cname, sp_cur])
		sp_by_idx.append(sp_cur)
	dvbox.add_child(caster_opt)

	dvbox.add_child(RimvaleUtils.separator())

	# Spell name
	dvbox.add_child(RimvaleUtils.label("Spell Name", 12, RimvaleColors.TEXT_WHITE))
	var name_edit = LineEdit.new()
	name_edit.placeholder_text = "Enter ritual name..."
	name_edit.custom_minimum_size = Vector2(0, 36)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dvbox.add_child(name_edit)

	# Domain
	dvbox.add_child(RimvaleUtils.label("Domain", 12, RimvaleColors.TEXT_WHITE))
	var domain_opt = OptionButton.new()
	domain_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for d in ["Biological", "Chemical", "Physical", "Spiritual"]:
		domain_opt.add_item(d)
	dvbox.add_child(domain_opt)

	# Effect
	dvbox.add_child(RimvaleUtils.label("Effect", 12, RimvaleColors.TEXT_WHITE))
	var effect_opt = OptionButton.new()
	effect_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for e in ["Damage", "Heal", "Buff", "Debuff", "Conjure", "Control", "Reveal", "Shield"]:
		effect_opt.add_item(e)
	dvbox.add_child(effect_opt)

	# SP committed
	dvbox.add_child(RimvaleUtils.label("SP to Commit", 12, RimvaleColors.TEXT_WHITE))
	var sp_row = HBoxContainer.new()
	sp_row.add_theme_constant_override("separation", 8)
	var sp_lbl = RimvaleUtils.label("SP: 1", 13, RimvaleColors.SP_PURPLE)
	sp_lbl.custom_minimum_size = Vector2(80, 0)
	sp_row.add_child(sp_lbl)
	var sp_slider = HSlider.new()
	sp_slider.min_value = 1; sp_slider.max_value = 20; sp_slider.step = 1; sp_slider.value = 1
	sp_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp_row.add_child(sp_slider)
	dvbox.add_child(sp_row)

	var cost_info = RimvaleUtils.label(
		"DC: 11 · Duration: 1 hour · Cost: 1 SP", 11, RimvaleColors.TEXT_GRAY)
	dvbox.add_child(cost_info)

	sp_slider.value_changed.connect(func(v: float):
		var sp: int = int(v)
		sp_lbl.text = "SP: %d" % sp
		cost_info.text = "DC: %d · Duration: %d hour%s · Cost: %d SP" % [
			10 + sp, sp, "s" if sp > 1 else "", sp])

	var domains: Array = ["Biological", "Chemical", "Physical", "Spiritual"]
	var effects: Array = ["Damage", "Heal", "Buff", "Debuff", "Conjure", "Control", "Reveal", "Shield"]

	dialog.confirmed.connect(func():
		var spell_name: String = name_edit.text.strip_edges()
		if spell_name.is_empty():
			dialog.queue_free(); return
		var caster_idx: int = caster_opt.selected
		if caster_idx < 0 or caster_idx >= handles.size():
			dialog.queue_free(); return
		var handle: int = handles[caster_idx]
		var caster_name: String = str(RimvaleAPI.engine.get_character_name(handle))
		var sp: int = int(sp_slider.value)
		var domain: String = domains[domain_opt.selected]
		var effect: String = effects[effect_opt.selected]
		var desc: String = "%s %s ritual — SP: %d, DC: %d" % [domain, effect, sp, 10 + sp]
		var task_id: String = "ritual_%d_%s" % [
			Time.get_unix_time_from_system(), spell_name.replace(" ", "_")]
		GameState.ritual_tasks.append({
			"id":           task_id,
			"spell_name":   spell_name,
			"spell_desc":   desc,
			"caster_handle": handle,
			"caster_name":  caster_name,
			"sp_committed": sp,
		})
		_refresh_ritual_ui()
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2(460, 480))

func _ritual_make_check(task_id: String) -> void:
	var task: Dictionary = {}
	for t in GameState.ritual_tasks:
		if str(t["id"]) == task_id:
			task = t; break
	if task.is_empty():
		return
	var sp: int = int(task["sp_committed"])
	var dc: int = 10 + sp
	var handle: int = int(task["caster_handle"])
	var result: PackedStringArray = RimvaleAPI.engine.execute_skill_challenge(handle, "Arcane", dc)
	var passed: bool = (not result.is_empty()) and result[0] == "1"
	var detail: String = str(result[4]) if result.size() > 4 else "Roll failed"
	var total: int = int(str(result[1])) if result.size() > 1 else 0

	if passed:
		# Promote to active
		GameState.ritual_tasks.erase(task)
		GameState.active_rituals.append(task)
		_show_ritual_result(
			"✓ Success! Roll %d vs DC %d — %s is now active." % [total, dc, str(task["spell_name"])],
			true)
	else:
		_show_ritual_result(
			"✗ Failed. Roll %d vs DC %d — %s" % [total, dc, detail],
			false)
	_refresh_ritual_ui()

func _ritual_add_sp(task_id: String) -> void:
	for t in GameState.ritual_tasks:
		if str(t["id"]) == task_id:
			var sp: int = int(t["sp_committed"]) + 1
			t["sp_committed"] = sp
			_show_ritual_result(
				"Spent 1 SP — DC is now %d. Roll again." % (10 + sp), false)
			_refresh_ritual_ui()
			return

func _ritual_abandon(task_id: String) -> void:
	for i in range(GameState.ritual_tasks.size()):
		if str(GameState.ritual_tasks[i]["id"]) == task_id:
			GameState.ritual_tasks.remove_at(i)
			_refresh_ritual_ui()
			return

func _ritual_dispel(ritual_id: String) -> void:
	for i in range(GameState.active_rituals.size()):
		if str(GameState.active_rituals[i]["id"]) == ritual_id:
			GameState.active_rituals.remove_at(i)
			_refresh_ritual_ui()
			return

func _show_ritual_result(msg: String, success: bool) -> void:
	if _ritual_result_lbl == null:
		return
	_ritual_result_lbl.text = msg
	_ritual_result_lbl.add_theme_color_override("font_color",
		RimvaleColors.HP_GREEN if success else RimvaleColors.DANGER)
	_ritual_result_lbl.visible = true

func _build_magic_world_tab(parent: Control) -> void:
	var magic_panel = Control.new()
	magic_panel.anchor_left = 0.0; magic_panel.anchor_top = 0.0
	magic_panel.anchor_right = 1.0; magic_panel.anchor_bottom = 1.0
	magic_panel.visible = false
	parent.add_child(magic_panel)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	magic_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	# ── Header ──
	vbox.add_child(RimvaleUtils.label("✦ Magic", 18, RimvaleColors.SP_PURPLE))
	vbox.add_child(RimvaleUtils.separator())

	# ── Character selector + SP display ──
	_magic_char_handles = GameState.get_active_handles()
	if _magic_char_handles.is_empty():
		vbox.add_child(RimvaleUtils.label("No active party members.", 13, RimvaleColors.TEXT_GRAY))
		return

	var sel_row = HBoxContainer.new()
	sel_row.add_theme_constant_override("separation", 8)
	vbox.add_child(sel_row)
	sel_row.add_child(RimvaleUtils.label("Caster:", 12, RimvaleColors.TEXT_WHITE))
	_magic_char_dropdown = OptionButton.new()
	_magic_char_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for h in _magic_char_handles:
		_magic_char_dropdown.add_item(str(RimvaleAPI.engine.get_character_name(h)))
	sel_row.add_child(_magic_char_dropdown)

	_magic_sp_lbl = RimvaleUtils.label("", 13, Color(0.74, 0.40, 1.0))
	sel_row.add_child(_magic_sp_lbl)

	_magic_char_dropdown.item_selected.connect(func(_idx: int): _refresh_magic_world_tab(vbox))

	# ── Learned Spells ──
	vbox.add_child(RimvaleUtils.label("LEARNED SPELLS", 13, RimvaleColors.TEXT_DIM))
	var learned_scroll = ScrollContainer.new()
	learned_scroll.custom_minimum_size = Vector2(0, 120)
	var learned_vbox = VBoxContainer.new()
	learned_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	learned_vbox.add_theme_constant_override("separation", 4)
	learned_scroll.add_child(learned_vbox)
	vbox.add_child(learned_scroll)
	# tag for refresh
	learned_vbox.set_meta("magic_learned_vbox", true)

	vbox.add_child(RimvaleUtils.separator())

	# ── Spell Builder ──
	vbox.add_child(RimvaleUtils.label("BUILD A SPELL", 13, RimvaleColors.TEXT_DIM))

	const DOMAINS: Array = ["Biological", "Chemical", "Physical", "Spiritual"]
	const EFFECTS: Array = ["Damage", "Heal", "Buff", "Debuff", "Conjure", "Control", "Reveal", "Shield"]
	const RANGES:  Array = ["Self", "Touch", "Short (30ft)", "Medium (60ft)", "Long (120ft)", "Extreme (300ft)"]
	const AREAS:   Array = ["Single Target", "Line", "Cone", "Burst (10ft)", "Burst (20ft)", "All Visible"]
	const RANGE_COSTS: Array  = [0, 1, 2, 3, 4, 6]
	const AREA_COSTS: Array   = [0, 2, 2, 3, 5, 8]
	const EFFECT_COSTS: Array = [3, 2, 2, 2, 4, 3, 2, 3]
	const AREA_TYPE_IDS: Array = [0, 1, 2, 3, 4, 6]  # map AREAS index → engine area_type int

	# Name field
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	vbox.add_child(name_row)
	name_row.add_child(RimvaleUtils.label("Name:", 12, RimvaleColors.TEXT_WHITE))
	_magic_name_edit = LineEdit.new()
	_magic_name_edit.placeholder_text = "Enter spell name..."
	_magic_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_magic_name_edit.custom_minimum_size = Vector2(0, 36)
	name_row.add_child(_magic_name_edit)

	# Grid of selectors
	var grid_pairs: Array = [
		["Domain", DOMAINS, "_magic_domain_idx"],
		["Effect", EFFECTS, "_magic_effect_idx"],
		["Range",  RANGES,  "_magic_range_idx"],
		["Area",   AREAS,   "_magic_area_idx"],
	]

	var _init_cost: int = _magic_calc_sp_cost(0, 0, 0, 0, EFFECT_COSTS, RANGE_COSTS, AREA_COSTS)
	_magic_cost_lbl = RimvaleUtils.label("SP Cost: %d" % _init_cost, 14, Color(0.74, 0.40, 1.0))

	for pair in grid_pairs:
		var label_txt: String = str(pair[0])
		var options: Array   = pair[1] as Array
		var prop: String     = str(pair[2])
		var row2 = HBoxContainer.new()
		row2.add_theme_constant_override("separation", 8)
		vbox.add_child(row2)
		var lbl2 = RimvaleUtils.label(label_txt + ":", 12, RimvaleColors.TEXT_WHITE)
		lbl2.custom_minimum_size = Vector2(60, 0)
		row2.add_child(lbl2)
		var opt2 = OptionButton.new()
		opt2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for o in options:
			opt2.add_item(str(o))
		# Restore current selection
		opt2.selected = int(get(prop))
		opt2.item_selected.connect(func(idx: int):
			set(prop, idx)
			_magic_cost_lbl.text = "SP Cost: %d" % _magic_calc_sp_cost(
				_magic_domain_idx, _magic_effect_idx, _magic_range_idx, _magic_area_idx,
				EFFECT_COSTS, RANGE_COSTS, AREA_COSTS)
		)
		row2.add_child(opt2)

	# ── Damage Dice: count slider ─────────────────────────────────────────
	var dice_header = RimvaleUtils.label("DAMAGE DICE", 13, RimvaleColors.TEXT_DIM)
	vbox.add_child(dice_header)

	_magic_dice_lbl = RimvaleUtils.label("Dice: %dd%d" % [_magic_die_count, _magic_die_sides], 13, Color(0.90, 0.60, 0.20))

	var count_row = HBoxContainer.new()
	count_row.add_theme_constant_override("separation", 8)
	vbox.add_child(count_row)
	var cnt_lbl = RimvaleUtils.label("Count:", 12, RimvaleColors.TEXT_WHITE)
	cnt_lbl.custom_minimum_size = Vector2(60, 0)
	count_row.add_child(cnt_lbl)
	_magic_die_count_slider = HSlider.new()
	_magic_die_count_slider.min_value = 0
	_magic_die_count_slider.max_value = 10
	_magic_die_count_slider.step = 1
	_magic_die_count_slider.value = _magic_die_count
	_magic_die_count_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_magic_die_count_slider.custom_minimum_size = Vector2(0, 28)
	count_row.add_child(_magic_die_count_slider)
	var cnt_val_lbl = RimvaleUtils.label(str(_magic_die_count), 13, Color(0.90, 0.60, 0.20))
	count_row.add_child(cnt_val_lbl)
	_magic_die_count_slider.value_changed.connect(func(val: float):
		_magic_die_count = int(val)
		cnt_val_lbl.text = str(_magic_die_count)
		_magic_dice_lbl.text = "Dice: %dd%d" % [_magic_die_count, _magic_die_sides]
		_magic_cost_lbl.text = "SP Cost: %d" % _magic_calc_sp_cost(
			_magic_domain_idx, _magic_effect_idx, _magic_range_idx, _magic_area_idx,
			EFFECT_COSTS, RANGE_COSTS, AREA_COSTS)
	)

	# ── Die size chips (d4, d6, d8, d10, d12) ─────────────────────────────
	var size_row = HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 6)
	vbox.add_child(size_row)
	var sz_lbl = RimvaleUtils.label("Die:", 12, RimvaleColors.TEXT_WHITE)
	sz_lbl.custom_minimum_size = Vector2(60, 0)
	size_row.add_child(sz_lbl)
	var die_sizes: Array = [4, 6, 8, 10, 12]
	var _die_size_btns: Array = []
	for ds in die_sizes:
		var dbtn = Button.new()
		dbtn.text = "d%d" % ds
		dbtn.custom_minimum_size = Vector2(48, 32)
		dbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style_n = StyleBoxFlat.new()
		style_n.bg_color = RimvaleColors.SP_PURPLE.darkened(0.4) if ds == _magic_die_sides else Color(0.18, 0.14, 0.22)
		style_n.corner_radius_top_left = 6; style_n.corner_radius_top_right = 6
		style_n.corner_radius_bottom_left = 6; style_n.corner_radius_bottom_right = 6
		dbtn.add_theme_stylebox_override("normal", style_n)
		dbtn.add_theme_color_override("font_color", Color.WHITE)
		dbtn.add_theme_font_size_override("font_size", 12)
		_die_size_btns.append(dbtn)
		size_row.add_child(dbtn)
		var cap_ds: int = ds
		var cap_btns: Array = _die_size_btns
		dbtn.pressed.connect(func():
			_magic_die_sides = cap_ds
			_magic_dice_lbl.text = "Dice: %dd%d" % [_magic_die_count, _magic_die_sides]
			# Re-highlight active button
			for i in cap_btns.size():
				var s: StyleBoxFlat = cap_btns[i].get_theme_stylebox("normal") as StyleBoxFlat
				if s:
					s.bg_color = RimvaleColors.SP_PURPLE.darkened(0.4) if die_sizes[i] == cap_ds else Color(0.18, 0.14, 0.22)
			_magic_cost_lbl.text = "SP Cost: %d" % _magic_calc_sp_cost(
				_magic_domain_idx, _magic_effect_idx, _magic_range_idx, _magic_area_idx,
				EFFECT_COSTS, RANGE_COSTS, AREA_COSTS)
		)

	vbox.add_child(_magic_dice_lbl)

	# ── Damage type selector ──────────────────────────────────────────────
	const DAMAGE_TYPES: Array = ["Bludgeoning", "Piercing", "Slashing", "Fire", "Cold",
			"Lightning", "Acid", "Poison", "Radiant", "Necrotic", "Psychic", "Thunder", "Force"]
	var dmg_row = HBoxContainer.new()
	dmg_row.add_theme_constant_override("separation", 8)
	vbox.add_child(dmg_row)
	var dmg_lbl = RimvaleUtils.label("Damage:", 12, RimvaleColors.TEXT_WHITE)
	dmg_lbl.custom_minimum_size = Vector2(60, 0)
	dmg_row.add_child(dmg_lbl)
	var dmg_opt = OptionButton.new()
	dmg_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for dt in DAMAGE_TYPES:
		dmg_opt.add_item(str(dt))
	dmg_opt.selected = _magic_dmg_type_idx
	dmg_opt.item_selected.connect(func(idx: int): _magic_dmg_type_idx = idx)
	dmg_row.add_child(dmg_opt)

	vbox.add_child(_magic_cost_lbl)

	# Register button
	var reg_btn = RimvaleUtils.button("Register Spell", RimvaleColors.SP_PURPLE, 44, 14)
	reg_btn.pressed.connect(func():
		var spell_name: String = _magic_name_edit.text.strip_edges()
		if spell_name.is_empty():
			return
		var cost: int = _magic_calc_sp_cost(
			_magic_domain_idx, _magic_effect_idx, _magic_range_idx, _magic_area_idx,
			EFFECT_COSTS, RANGE_COSTS, AREA_COSTS)
		var domain_name: String = DOMAINS[_magic_domain_idx]
		var effect_name: String = EFFECTS[_magic_effect_idx]
		var range_name: String  = RANGES[_magic_range_idx]
		var area_name: String   = AREAS[_magic_area_idx]
		var dice_str: String = "%dd%d" % [_magic_die_count, _magic_die_sides]
		var dmg_str: String  = DAMAGE_TYPES[_magic_dmg_type_idx] if _magic_effect_idx == 0 else ""
		var desc: String = "%s %s — %s, %s. %s %s SP: %d" % [
			domain_name, effect_name, range_name, area_name, dice_str, dmg_str, cost]
		var is_atk: bool  = (_magic_effect_idx == 0)   # Damage = attack spell
		var is_heal: bool = (_magic_effect_idx == 1)   # Heal
		var dur: int      = 3 if _magic_effect_idx in [2, 3, 5, 7] else 0  # Buff/Debuff/Control/Shield sustain
		var area_id: int  = AREA_TYPE_IDS[_magic_area_idx]
		var max_t: int    = 1 if _magic_area_idx == 0 else 4
		RimvaleAPI.engine.add_custom_spell(
			spell_name, _magic_domain_idx, cost, desc,
			_magic_range_idx, is_atk,
			_magic_die_count, _magic_die_sides,   # user-selected dice
			_magic_dmg_type_idx, is_heal,          # user-selected damage type
			dur, max_t,      # duration_rounds, max_targets
			area_id, "",     # area_type, conditions_csv
			false            # is_teleport
		)
		_magic_name_edit.text = ""
		_refresh_magic_world_tab(vbox)
	)
	vbox.add_child(reg_btn)

	# ── Custom Spells list ──
	vbox.add_child(RimvaleUtils.separator())
	vbox.add_child(RimvaleUtils.label("CUSTOM SPELLS", 13, RimvaleColors.TEXT_DIM))
	_magic_custom_vbox = VBoxContainer.new()
	_magic_custom_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_magic_custom_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(_magic_custom_vbox)

	# Initial populate
	_refresh_magic_world_tab(vbox)

func _refresh_magic_world_tab(vbox: VBoxContainer) -> void:
	# Update SP label
	if _magic_char_dropdown and not _magic_char_handles.is_empty():
		var idx: int = _magic_char_dropdown.selected
		if idx < _magic_char_handles.size():
			var ph: int = _magic_char_handles[idx]
			var cur_sp: int = RimvaleAPI.engine.get_character_sp(ph)
			var max_sp: int = RimvaleAPI.engine.get_character_max_sp(ph)
			if _magic_sp_lbl:
				_magic_sp_lbl.text = "SP: %d / %d" % [cur_sp, max_sp]

	# Refresh learned spells pane
	for child in vbox.get_children():
		if child is VBoxContainer and child.has_meta("magic_learned_vbox"):
			for c in child.get_children(): c.queue_free()
			if not _magic_char_handles.is_empty():
				var ph2: int = _magic_char_handles[clamp(_magic_char_dropdown.selected if _magic_char_dropdown else 0,
					0, _magic_char_handles.size() - 1)]
				var learned_raw: PackedStringArray = RimvaleAPI.engine.get_learned_spells(ph2)
				if learned_raw.is_empty():
					child.add_child(RimvaleUtils.label("No spells learned yet.", 12, RimvaleColors.TEXT_GRAY))
				else:
					for sn in learned_raw:
						child.add_child(RimvaleUtils.label("• " + str(sn), 13, Color(0.74, 0.40, 1.0)))
			break

	# Refresh custom spells
	if _magic_custom_vbox:
		for c2 in _magic_custom_vbox.get_children(): c2.queue_free()
		var custom_raw: PackedStringArray = RimvaleAPI.engine.get_custom_spells()
		if custom_raw.is_empty():
			_magic_custom_vbox.add_child(RimvaleUtils.label("No custom spells registered.", 12, RimvaleColors.TEXT_GRAY))
		else:
			for csp in custom_raw:
				var spell_name: String = str(csp)
				var csp_row = HBoxContainer.new()
				csp_row.add_theme_constant_override("separation", 8)
				var csp_lbl = RimvaleUtils.label("⚗ " + spell_name, 13, Color(0.90, 0.60, 0.95))
				csp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				csp_row.add_child(csp_lbl)
				# Learn button for active caster
				var learn_btn = RimvaleUtils.button("Learn", RimvaleColors.SP_PURPLE, 28, 11)
				var sn_cap: String = spell_name
				learn_btn.pressed.connect(func():
					if not _magic_char_handles.is_empty():
						var ph3: int = _magic_char_handles[clamp(
							_magic_char_dropdown.selected if _magic_char_dropdown else 0,
							0, _magic_char_handles.size() - 1)]
						RimvaleAPI.engine.learn_spell(ph3, sn_cap)
						_refresh_magic_world_tab(vbox)
				)
				csp_row.add_child(learn_btn)
				_magic_custom_vbox.add_child(csp_row)

func _build_base_tab(parent: Control) -> void:
	var base_panel := Control.new()
	base_panel.anchor_left = 0.0; base_panel.anchor_top    = 0.0
	base_panel.anchor_right = 1.0; base_panel.anchor_bottom = 1.0
	base_panel.visible = false
	parent.add_child(base_panel)

	var scroll := ScrollContainer.new()
	scroll.anchor_left   = 0.0; scroll.anchor_top    = 0.0
	scroll.anchor_right  = 1.0; scroll.anchor_bottom = 1.0
	base_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)
	vbox.set_meta("base_root_vbox", true)

	_populate_base_tab(vbox)

func _populate_base_tab(vbox: VBoxContainer) -> void:
	for c in vbox.get_children():
		c.queue_free()

	# Header + base stats overview
	vbox.add_child(RimvaleUtils.label("ACF Headquarters", 22, RimvaleColors.ACCENT))
	var sub := RimvaleUtils.label(
		"Manage your agency's facilities. Build and upgrade to unlock new capabilities.",
		12, RimvaleColors.TEXT_GRAY)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(sub)
	vbox.add_child(RimvaleUtils.separator())

	# ── Base Stats Panel ──────────────────────────────────────────────────
	var stats_card := PanelContainer.new()
	stats_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stats_sb := StyleBoxFlat.new()
	stats_sb.bg_color = Color(0.08, 0.14, 0.22)
	stats_sb.border_color = Color(RimvaleColors.CYAN, 0.45)
	stats_sb.set_border_width_all(1)
	stats_sb.set_corner_radius_all(6)
	stats_sb.set_content_margin_all(12)
	stats_card.add_theme_stylebox_override("panel", stats_sb)
	vbox.add_child(stats_card)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 6)
	stats_card.add_child(stats_vbox)

	var tier_row := HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 12)
	stats_vbox.add_child(tier_row)
	tier_row.add_child(RimvaleUtils.label("Base Tier: %d / 5" % GameState.base_tier, 15, RimvaleColors.GOLD))
	var fac_count: int = GameState.base_facilities.size()
	var fac_max: int   = GameState.get_base_max_facilities()
	tier_row.add_child(RimvaleUtils.label("Facilities: %d / %d" % [fac_count, fac_max], 12, RimvaleColors.TEXT_WHITE))

	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 16)
	stats_vbox.add_child(stat_row)
	stat_row.add_child(RimvaleUtils.label("Supplies: %d" % GameState.base_supplies, 12, RimvaleColors.HP_GREEN))
	stat_row.add_child(RimvaleUtils.label("Defense: %d (%+d)" % [GameState.base_defense, GameState.get_base_defense_mod()], 12, RimvaleColors.CYAN))
	stat_row.add_child(RimvaleUtils.label("Morale: %d" % GameState.base_morale, 12, Color(0.90, 0.75, 0.20)))
	stat_row.add_child(RimvaleUtils.label("Acreage: %d" % GameState.base_acreage, 12, RimvaleColors.TEXT_DIM))

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 16)
	stats_vbox.add_child(res_row)
	res_row.add_child(RimvaleUtils.label("Gold: %d" % GameState.gold, 12, RimvaleColors.GOLD))
	res_row.add_child(RimvaleUtils.label("Remnant Fragments: %d" % GameState.remnant_fragments, 12, RimvaleColors.SP_PURPLE))

	# Upgrade tier button
	if GameState.base_tier < 5:
		var tier_cost_g: int = 500 * GameState.base_tier
		var tier_cost_rf: int = 3 * GameState.base_tier
		var upgrade_btn = RimvaleUtils.button(
			"Upgrade to Tier %d  (%dg + %d RF)" % [GameState.base_tier + 1, tier_cost_g, tier_cost_rf],
			RimvaleColors.GOLD, 38, 13)
		var can_upgrade: bool = (GameState.gold >= tier_cost_g and GameState.remnant_fragments >= tier_cost_rf)
		upgrade_btn.disabled = not can_upgrade
		upgrade_btn.modulate = Color.WHITE if can_upgrade else Color(1, 1, 1, 0.4)
		var cap_vbox: VBoxContainer = vbox
		upgrade_btn.pressed.connect(func():
			if GameState.upgrade_base_tier():
				_populate_base_tab(cap_vbox)
		)
		stats_vbox.add_child(upgrade_btn)

	vbox.add_child(RimvaleUtils.separator())
	vbox.add_child(RimvaleUtils.label("FACILITIES", 14, RimvaleColors.TEXT_DIM))

	# ── Facility Cards ────────────────────────────────────────────────────
	var fac_colors: Array = [
		RimvaleColors.ACCENT,   RimvaleColors.ORANGE,   RimvaleColors.CYAN,
		RimvaleColors.SUCCESS,  RimvaleColors.HP_GREEN,  Color(0.55, 0.55, 0.65),
		RimvaleColors.SP_PURPLE, Color(0.25, 0.55, 0.75), Color(0.80, 0.50, 0.50),
		Color(0.65, 0.40, 0.25), Color(0.60, 0.40, 0.80),
	]

	for fi in GameState.FACILITY_DEFS.size():
		var fac: Dictionary = GameState.FACILITY_DEFS[fi]
		var is_built: bool  = fi in GameState.base_facilities
		var check: Dictionary = GameState.can_build_facility(fi)
		var can_build: bool = bool(check["ok"])
		var bcol: Color = fac_colors[fi % fac_colors.size()]

		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_sb := StyleBoxFlat.new()
		card_sb.bg_color     = Color(bcol, 0.14) if is_built else Color(bcol, 0.05)
		card_sb.border_color = Color(bcol, 0.65) if is_built else Color(bcol, 0.25)
		card_sb.set_border_width_all(1)
		card_sb.set_corner_radius_all(6)
		card_sb.set_content_margin_all(12)
		card.add_theme_stylebox_override("panel", card_sb)
		vbox.add_child(card)

		var cvbox := VBoxContainer.new()
		cvbox.add_theme_constant_override("separation", 4)
		card.add_child(cvbox)

		# Title row: icon + name | status
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 8)
		var title_col: Color = bcol if is_built else Color(bcol, 0.55)
		title_row.add_child(RimvaleUtils.label(
			"%s %s" % [str(fac["icon"]), str(fac["name"])], 15, title_col))
		var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(spacer)
		if is_built:
			title_row.add_child(RimvaleUtils.label("BUILT", 11, RimvaleColors.HP_GREEN))
		else:
			var tier_txt: String = "Tier %d" % int(fac["tier"])
			title_row.add_child(RimvaleUtils.label(tier_txt, 11, RimvaleColors.TEXT_DIM))
		cvbox.add_child(title_row)

		# Description
		var desc_lbl := RimvaleUtils.label(str(fac["desc"]), 11,
				RimvaleColors.TEXT_WHITE if is_built else RimvaleColors.TEXT_GRAY)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cvbox.add_child(desc_lbl)

		# Cost row + Build button (if not built)
		if not is_built:
			var cost_row := HBoxContainer.new()
			cost_row.add_theme_constant_override("separation", 12)
			cvbox.add_child(cost_row)
			if int(fac["gold"]) > 0:
				cost_row.add_child(RimvaleUtils.label("%dg" % int(fac["gold"]), 11, RimvaleColors.GOLD))
			if int(fac["rf"]) > 0:
				cost_row.add_child(RimvaleUtils.label("%d RF" % int(fac["rf"]), 11, RimvaleColors.SP_PURPLE))

			if can_build:
				var build_btn = RimvaleUtils.button("Build", bcol, 32, 12)
				var cap_fi: int = fi
				var cap_vbox2: VBoxContainer = vbox
				build_btn.pressed.connect(func():
					if GameState.build_facility(cap_fi):
						_populate_base_tab(cap_vbox2)
				)
				cvbox.add_child(build_btn)
			else:
				var reason_lbl := RimvaleUtils.label(
					str(check["reason"]), 10, RimvaleColors.TEXT_DIM)
				cvbox.add_child(reason_lbl)

	vbox.add_child(RimvaleUtils.spacer(16))

	# ══════════════════════════════════════════════════════════════════════════
	#  ALLIES SECTION — Recruit Militia, Mobs, and Kaijus
	# ══════════════════════════════════════════════════════════════════════════
	vbox.add_child(RimvaleUtils.separator())
	vbox.add_child(RimvaleUtils.label("ALLIES", 18, Color(0.20, 0.78, 0.40)))
	var ally_desc := RimvaleUtils.label(
		"Recruit militia squads, mob swarms, and kaijus to summon into dungeon battles.",
		12, RimvaleColors.TEXT_GRAY)
	ally_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(ally_desc)

	# ── Current roster ─────────────────────────────────────────────────────
	if GameState.recruited_allies.size() > 0:
		vbox.add_child(RimvaleUtils.label("ROSTER (%d)" % GameState.recruited_allies.size(), 13, RimvaleColors.TEXT_DIM))
		for ai in range(GameState.recruited_allies.size()):
			var ally: Dictionary = GameState.recruited_allies[ai]
			var atype: String = str(ally.get("type", "militia"))
			var aname: String = str(ally.get("name", "Unknown"))
			var alv: int      = int(ally.get("level", 1))
			var ahp: int      = int(ally.get("hp", 1))
			var amaxhp: int   = int(ally.get("max_hp", ahp))
			var amembers: int = int(ally.get("members", 1))
			var acol: Color
			if atype == "kaiju":   acol = Color(0.90, 0.30, 0.20)
			elif atype == "mob":   acol = Color(0.80, 0.65, 0.15)
			else:                  acol = Color(0.20, 0.65, 0.80)

			var acard := PanelContainer.new()
			acard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var asb := StyleBoxFlat.new()
			asb.bg_color = Color(acol, 0.10)
			asb.border_color = Color(acol, 0.40)
			asb.set_border_width_all(1)
			asb.set_corner_radius_all(5)
			asb.set_content_margin_all(10)
			acard.add_theme_stylebox_override("panel", asb)
			vbox.add_child(acard)

			var avbox := VBoxContainer.new()
			avbox.add_theme_constant_override("separation", 3)
			acard.add_child(avbox)

			var arow := HBoxContainer.new()
			arow.add_theme_constant_override("separation", 8)
			avbox.add_child(arow)
			var type_icon: String = "👹" if atype == "kaiju" else ("🗡" if atype == "militia" else "🔥")
			arow.add_child(RimvaleUtils.label("%s %s" % [type_icon, aname], 13, acol))
			var aspacer := Control.new(); aspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			arow.add_child(aspacer)
			arow.add_child(RimvaleUtils.label("Lv.%d" % alv, 11, RimvaleColors.GOLD))
			if amembers > 1:
				arow.add_child(RimvaleUtils.label("%d members" % amembers, 11, RimvaleColors.TEXT_DIM))

			var ally_stat_row := HBoxContainer.new()
			ally_stat_row.add_theme_constant_override("separation", 12)
			avbox.add_child(ally_stat_row)
			ally_stat_row.add_child(RimvaleUtils.label("HP: %d/%d" % [ahp, amaxhp], 11, RimvaleColors.HP_GREEN))
			ally_stat_row.add_child(RimvaleUtils.label("AC: %d" % int(ally.get("ac", 12)), 11, RimvaleColors.CYAN))
			var atrait: String = str(ally.get("trait", ""))
			if atrait != "":
				ally_stat_row.add_child(RimvaleUtils.label(atrait, 11, Color(0.75, 0.60, 0.90)))

			# Dismiss button
			var dismiss_btn = RimvaleUtils.button("Dismiss", Color(0.60, 0.25, 0.20), 28, 11)
			var cap_ai: int = ai
			var cap_vbox3: VBoxContainer = vbox
			dismiss_btn.pressed.connect(func():
				GameState.dismiss_ally(cap_ai)
				_populate_base_tab(cap_vbox3)
			)
			avbox.add_child(dismiss_btn)
	else:
		vbox.add_child(RimvaleUtils.label("No allies recruited yet.", 12, RimvaleColors.TEXT_GRAY))

	vbox.add_child(RimvaleUtils.separator())

	# ── Recruit Militia ────────────────────────────────────────────────────
	vbox.add_child(RimvaleUtils.label("RECRUIT MILITIA", 14, Color(0.20, 0.65, 0.80)))
	var mil_desc := RimvaleUtils.label(
		"Organized squads with equipment. Formation Attack deals (members/3)d6 damage.",
		11, RimvaleColors.TEXT_GRAY)
	mil_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(mil_desc)

	# Type selector
	var mil_type_row := HBoxContainer.new()
	mil_type_row.add_theme_constant_override("separation", 8)
	vbox.add_child(mil_type_row)
	mil_type_row.add_child(RimvaleUtils.label("Type:", 12, RimvaleColors.TEXT_WHITE))
	var mil_type_opt := OptionButton.new()
	mil_type_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for mt in GameState.MILITIA_TYPES:
		mil_type_opt.add_item(str(mt["name"]))
	mil_type_row.add_child(mil_type_opt)

	var mil_desc_lbl := RimvaleUtils.label(str(GameState.MILITIA_TYPES[0]["desc"]), 11, RimvaleColors.TEXT_GRAY)
	mil_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(mil_desc_lbl)
	mil_type_opt.item_selected.connect(func(idx: int):
		mil_desc_lbl.text = str(GameState.MILITIA_TYPES[idx]["desc"])
	)

	# Equipment tier
	var mil_equip_row := HBoxContainer.new()
	mil_equip_row.add_theme_constant_override("separation", 8)
	vbox.add_child(mil_equip_row)
	mil_equip_row.add_child(RimvaleUtils.label("Equipment:", 12, RimvaleColors.TEXT_WHITE))
	var mil_equip_opt := OptionButton.new()
	mil_equip_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for et in GameState.MILITIA_EQUIP_TIERS:
		mil_equip_opt.add_item("%s (AC %d, +%d dmg, %dg)" % [et["name"], et["ac"], et["dmg_bonus"], et["gold"]])
	mil_equip_opt.selected = 1  # Standard default
	mil_equip_row.add_child(mil_equip_opt)

	# Member count slider
	var mil_count_row := HBoxContainer.new()
	mil_count_row.add_theme_constant_override("separation", 8)
	vbox.add_child(mil_count_row)
	mil_count_row.add_child(RimvaleUtils.label("Members:", 12, RimvaleColors.TEXT_WHITE))
	var mil_slider := HSlider.new()
	mil_slider.min_value = 3; mil_slider.max_value = 20; mil_slider.step = 1; mil_slider.value = 8
	mil_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mil_slider.custom_minimum_size = Vector2(0, 28)
	mil_count_row.add_child(mil_slider)
	var mil_count_lbl := RimvaleUtils.label("8", 13, RimvaleColors.GOLD)
	mil_count_row.add_child(mil_count_lbl)

	# Cost display
	var mil_cost_lbl := RimvaleUtils.label("", 12, RimvaleColors.GOLD)
	vbox.add_child(mil_cost_lbl)
	var _update_mil_cost := func():
		var etier: int = mil_equip_opt.selected
		var cnt: int = int(mil_slider.value)
		var cost_per: int = 25 + int(GameState.MILITIA_EQUIP_TIERS[etier]["gold"])
		var total: int = cost_per * cnt / 5
		mil_cost_lbl.text = "Cost: %dg (have %dg)" % [total, GameState.gold]
		mil_count_lbl.text = str(cnt)
	_update_mil_cost.call()
	mil_slider.value_changed.connect(func(_v: float): _update_mil_cost.call())
	mil_equip_opt.item_selected.connect(func(_i: int): _update_mil_cost.call())

	# Name field + recruit button
	var mil_name_row := HBoxContainer.new()
	mil_name_row.add_theme_constant_override("separation", 8)
	vbox.add_child(mil_name_row)
	var mil_name_edit := LineEdit.new()
	mil_name_edit.placeholder_text = "Squad name (optional)..."
	mil_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mil_name_edit.custom_minimum_size = Vector2(0, 32)
	mil_name_row.add_child(mil_name_edit)
	var mil_recruit_btn = RimvaleUtils.button("Recruit Militia", Color(0.20, 0.65, 0.80), 36, 13)
	var cap_vbox_mil: VBoxContainer = vbox
	mil_recruit_btn.pressed.connect(func():
		if GameState.recruit_militia(mil_type_opt.selected, mil_equip_opt.selected,
				int(mil_slider.value), mil_name_edit.text.strip_edges()):
			_populate_base_tab(cap_vbox_mil)
	)
	mil_name_row.add_child(mil_recruit_btn)

	vbox.add_child(RimvaleUtils.separator())

	# ── Recruit Mob ────────────────────────────────────────────────────────
	vbox.add_child(RimvaleUtils.label("RECRUIT MOB", 14, Color(0.80, 0.65, 0.15)))
	var mob_info := RimvaleUtils.label(
		"Chaotic swarms. Mob Attack deals (members/2)d4 damage. Cheap but unpredictable.",
		11, RimvaleColors.TEXT_GRAY)
	mob_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(mob_info)

	# Trait selector
	var mob_trait_row := HBoxContainer.new()
	mob_trait_row.add_theme_constant_override("separation", 8)
	vbox.add_child(mob_trait_row)
	mob_trait_row.add_child(RimvaleUtils.label("Trait:", 12, RimvaleColors.TEXT_WHITE))
	var mob_trait_opt := OptionButton.new()
	mob_trait_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for mt2 in GameState.MOB_TRAITS:
		mob_trait_opt.add_item(str(mt2["name"]))
	mob_trait_row.add_child(mob_trait_opt)

	var mob_trait_desc := RimvaleUtils.label(str(GameState.MOB_TRAITS[0]["desc"]), 11, RimvaleColors.TEXT_GRAY)
	mob_trait_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(mob_trait_desc)
	mob_trait_opt.item_selected.connect(func(idx: int):
		mob_trait_desc.text = str(GameState.MOB_TRAITS[idx]["desc"])
	)

	# Leader selector
	var mob_leader_row := HBoxContainer.new()
	mob_leader_row.add_theme_constant_override("separation", 8)
	vbox.add_child(mob_leader_row)
	mob_leader_row.add_child(RimvaleUtils.label("Leader:", 12, RimvaleColors.TEXT_WHITE))
	var mob_leader_opt := OptionButton.new()
	mob_leader_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for ml in GameState.MOB_LEADERS:
		mob_leader_opt.add_item(str(ml["name"]))
	mob_leader_row.add_child(mob_leader_opt)

	# Member count slider
	var mob_count_row := HBoxContainer.new()
	mob_count_row.add_theme_constant_override("separation", 8)
	vbox.add_child(mob_count_row)
	mob_count_row.add_child(RimvaleUtils.label("Members:", 12, RimvaleColors.TEXT_WHITE))
	var mob_slider := HSlider.new()
	mob_slider.min_value = 5; mob_slider.max_value = 50; mob_slider.step = 1; mob_slider.value = 15
	mob_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mob_slider.custom_minimum_size = Vector2(0, 28)
	mob_count_row.add_child(mob_slider)
	var mob_count_lbl := RimvaleUtils.label("15", 13, RimvaleColors.GOLD)
	mob_count_row.add_child(mob_count_lbl)

	var mob_cost_lbl := RimvaleUtils.label("", 12, RimvaleColors.GOLD)
	vbox.add_child(mob_cost_lbl)
	var _update_mob_cost := func():
		var cnt2: int = int(mob_slider.value)
		mob_cost_lbl.text = "Cost: %dg (have %dg)" % [cnt2 * 10, GameState.gold]
		mob_count_lbl.text = str(cnt2)
	_update_mob_cost.call()
	mob_slider.value_changed.connect(func(_v: float): _update_mob_cost.call())

	var mob_name_row := HBoxContainer.new()
	mob_name_row.add_theme_constant_override("separation", 8)
	vbox.add_child(mob_name_row)
	var mob_name_edit := LineEdit.new()
	mob_name_edit.placeholder_text = "Mob name (optional)..."
	mob_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mob_name_edit.custom_minimum_size = Vector2(0, 32)
	mob_name_row.add_child(mob_name_edit)
	var mob_recruit_btn = RimvaleUtils.button("Recruit Mob", Color(0.80, 0.65, 0.15), 36, 13)
	var cap_vbox_mob: VBoxContainer = vbox
	mob_recruit_btn.pressed.connect(func():
		if GameState.recruit_mob(int(mob_slider.value), mob_trait_opt.selected,
				mob_leader_opt.selected, mob_name_edit.text.strip_edges()):
			_populate_base_tab(cap_vbox_mob)
	)
	mob_name_row.add_child(mob_recruit_btn)

	vbox.add_child(RimvaleUtils.separator())

	# ── Recruit Kaiju ──────────────────────────────────────────────────────
	vbox.add_child(RimvaleUtils.label("RECRUIT KAIJU", 14, Color(0.90, 0.30, 0.20)))
	if not GameState.has_facility("defenders"):
		var no_barracks := RimvaleUtils.label(
			"Requires Barracks facility to recruit Kaijus.", 12, RimvaleColors.TEXT_DIM)
		vbox.add_child(no_barracks)
	else:
		var kaiju_info := RimvaleUtils.label(
			"Massive creatures of immense power. Expensive but devastating in battle.",
			11, RimvaleColors.TEXT_GRAY)
		kaiju_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(kaiju_info)

		for ki in range(GameState.KAIJU_RECRUITS.size()):
			var k: Dictionary = GameState.KAIJU_RECRUITS[ki]
			var kcard := PanelContainer.new()
			kcard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var ksb := StyleBoxFlat.new()
			ksb.bg_color = Color(0.90, 0.30, 0.20, 0.08)
			ksb.border_color = Color(0.90, 0.30, 0.20, 0.30)
			ksb.set_border_width_all(1)
			ksb.set_corner_radius_all(5)
			ksb.set_content_margin_all(10)
			kcard.add_theme_stylebox_override("panel", ksb)
			vbox.add_child(kcard)

			var kvbox := VBoxContainer.new()
			kvbox.add_theme_constant_override("separation", 3)
			kcard.add_child(kvbox)

			var krow := HBoxContainer.new()
			krow.add_theme_constant_override("separation", 8)
			kvbox.add_child(krow)
			krow.add_child(RimvaleUtils.label(
				"👹 %s, %s" % [str(k["name"]), str(k["title"])], 13, Color(0.90, 0.30, 0.20)))
			var kspacer := Control.new(); kspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			krow.add_child(kspacer)
			krow.add_child(RimvaleUtils.label("Lv.%d" % int(k["level"]), 11, RimvaleColors.GOLD))

			var kstat_row := HBoxContainer.new()
			kstat_row.add_theme_constant_override("separation", 10)
			kvbox.add_child(kstat_row)
			kstat_row.add_child(RimvaleUtils.label("HP: %d" % int(k["hp"]), 11, RimvaleColors.HP_GREEN))
			kstat_row.add_child(RimvaleUtils.label("AC: %d" % int(k["ac"]), 11, RimvaleColors.CYAN))
			kstat_row.add_child(RimvaleUtils.label("%dg + %d RF" % [int(k["gold"]), int(k["rf"])], 11, RimvaleColors.GOLD))

			var can_afford: bool = (GameState.gold >= int(k["gold"]) and GameState.remnant_fragments >= int(k["rf"]))
			var kbtn = RimvaleUtils.button("Recruit", Color(0.90, 0.30, 0.20), 32, 12)
			kbtn.disabled = not can_afford
			kbtn.modulate = Color.WHITE if can_afford else Color(1, 1, 1, 0.4)
			var cap_ki: int = ki
			var cap_vbox_k: VBoxContainer = vbox
			kbtn.pressed.connect(func():
				if GameState.recruit_kaiju(cap_ki):
					_populate_base_tab(cap_vbox_k)
			)
			kvbox.add_child(kbtn)

	vbox.add_child(RimvaleUtils.spacer(24))

const QUEST_TEMPLATES: Array = [
	# [title_prefix, type, description_template, skill_checks]
	["Investigate the", "Exploration",
		"Strange activity has been reported near {region}. Scout the area and report back.",
		["Perception", "Survival", "Cunning"]],
	["Clear Bandits from", "Combat",
		"Outlaws have set up camp near {region}. Drive them out and secure the road.",
		["Exertion", "Perception", "Intimidation"]],
	["Escort Merchant through", "Escort",
		"A trader needs protection travelling through the dangers of {region}.",
		["Perception", "Speechcraft", "Exertion"]],
	["Collect Reagents in", "Gathering",
		"The alchemist requires rare reagents found only in {region}. Retrieve them.",
		["Survival", "Medical", "Creature Handling"]],
	["Negotiate Peace in", "Diplomacy",
		"Rival factions are clashing in {region}. Broker a truce before blood is spilled.",
		["Speechcraft", "Cunning", "Learnedness"]],
	["Hunt the Beast of", "Combat",
		"A dangerous creature has been preying on settlements near {region}. End the threat.",
		["Exertion", "Perception", "Survival"]],
	["Recover Artifact from", "Exploration",
		"An ancient relic is rumoured to lie buried beneath {region}. Retrieve it.",
		["Learnedness", "Cunning", "Perception"]],
	["Rescue Prisoners in", "Escort",
		"Captives are held by hostile forces somewhere in {region}. Bring them home.",
		["Sneak", "Exertion", "Perception"]],
]

func _make_quest(region: String, difficulty: int) -> Dictionary:
	var tpl: Array = QUEST_TEMPLATES[randi() % QUEST_TEMPLATES.size()]
	var short_region: String = region.split(" ")[0]
	return {
		"title":       tpl[0] + " " + short_region,
		"region":      region,
		"difficulty":  clamp(difficulty, 1, 3),
		"type":        tpl[1],
		"description": (tpl[2] as String).replace("{region}", region),
		"skill_checks":tpl[3],
		"reward_gold": 40 * difficulty + randi() % (20 * difficulty + 10),
		"reward_xp":   25 * difficulty,
	}

func _generate_sample_quests() -> void:
	quests.clear()
	var regions: PackedStringArray = RimvaleAPI.engine.get_all_regions()
	if regions.is_empty():
		# Fallback region names if engine not loaded yet
		regions = PackedStringArray(["The Plains", "The Metropolitan", "The Shadows Beneath",
			"Titan's Lament", "The Isles"])
	# Seed 5 sample quests spread across regions with varying difficulties
	for i in range(5):
		var r: String = str(regions[i % regions.size()])
		quests.append(_make_quest(r, (i % 3) + 1))

func _refresh_quests_display(vbox: VBoxContainer) -> void:
	for child in vbox.get_children():
		child.queue_free()

	var shown: int = 0
	for quest in quests:
		if _region_filter != "" and quest["region"] != _region_filter:
			continue
		shown += 1
		var quest_hbox = HBoxContainer.new()
		quest_hbox.custom_minimum_size.y = 70
		quest_hbox.add_theme_constant_override("separation", 8)
		RimvaleUtils.add_bg(quest_hbox, RimvaleColors.BG_CARD)

		var details_vbox = VBoxContainer.new()
		details_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var diff_stars: String = "★".repeat(int(quest["difficulty"])) + "☆".repeat(3 - int(quest["difficulty"]))
		details_vbox.add_child(RimvaleUtils.label(quest["title"], 14, RimvaleColors.TEXT_WHITE))
		details_vbox.add_child(RimvaleUtils.label(
			quest["region"] + "  |  " + quest.get("type", "Mission") + "  |  " + diff_stars +
			"  |  " + str(quest.get("reward_gold", 0)) + "g  " + str(quest.get("reward_xp", 0)) + "xp",
			11, RimvaleColors.TEXT_GRAY))
		quest_hbox.add_child(details_vbox)

		var q_ref: Dictionary = quest

		var btn_vbox := VBoxContainer.new()
		btn_vbox.add_theme_constant_override("separation", 4)

		var start_btn = RimvaleUtils.button("▶ Start", RimvaleColors.GOLD, 50, 12)
		start_btn.pressed.connect(func(): _start_quest(q_ref))
		btn_vbox.add_child(start_btn)

		# Deploy-to-Dungeon: links this quest to the next dungeon victory so its
		# rewards are added automatically on completion.
		var deploy_btn = RimvaleUtils.button("⚔ Dungeon", RimvaleColors.DANGER, 50, 11)
		deploy_btn.pressed.connect(func():
			GameState.deploy_quest_to_dungeon(q_ref)
			_dd_launch()
		)
		btn_vbox.add_child(deploy_btn)

		quest_hbox.add_child(btn_vbox)

		vbox.add_child(quest_hbox)

	if shown == 0:
		vbox.add_child(RimvaleUtils.label(
			"No quests match the current filter." if _region_filter != "" else "No quests available.",
			13, RimvaleColors.TEXT_GRAY))

func _on_generate_quest() -> void:
	# Prefer engine-generated quest for richer variety; fall back to local if region list empty
	var regions: PackedStringArray = RimvaleAPI.engine.get_all_regions()
	var region: String = ""
	if not regions.is_empty():
		region = str(regions[randi() % regions.size()])

	var engine_quest: PackedStringArray = RimvaleAPI.engine.generate_quest(region)
	if engine_quest.size() >= 10:
		# PackedStringArray: [title, region, type, desc, skill1, skill2, skill3, diff, gold, xp, anomaly, complication]
		var q: Dictionary = {
			"title":       str(engine_quest[0]),
			"region":      str(engine_quest[1]),
			"type":        str(engine_quest[2]),
			"description": str(engine_quest[3]),
			"skill_checks": [str(engine_quest[4]), str(engine_quest[5]), str(engine_quest[6])],
			"difficulty":  int(str(engine_quest[7])),
			"reward_gold": int(str(engine_quest[8])),
			"reward_xp":   int(str(engine_quest[9])),
			"anomaly":     str(engine_quest[10]) if engine_quest.size() > 10 else "",
			"complication":str(engine_quest[11]) if engine_quest.size() > 11 else "",
		}
		quests.append(q)
	elif not region.is_empty():
		quests.append(_make_quest(region, randi() % 3 + 1))
	_refresh_quests_display(_quests_vbox)

## SP cost calculator for the Magic tab spell builder.
## Matches Rimvale Mobile formula: base + effect + range + area + dice scaling.
## Phase 2: Sustained spells (Buff/Debuff/Control/Shield) get a duration multiplier.
func _magic_calc_sp_cost(domain_i: int, effect_i: int, range_i: int, area_i: int,
		effect_costs: Array, range_costs: Array, area_costs: Array) -> int:
	var base: int = 2 + effect_costs[effect_i] + range_costs[range_i] + area_costs[area_i]
	if domain_i == 0 or domain_i == 3:   # Biological / Spiritual cost slightly more
		base += 1
	# Dice scaling: each die adds cost based on its size (d4=0, d6=1, d8=2, d10=3, d12=4)
	var sides_mod: int = 0
	match _magic_die_sides:
		6:  sides_mod = 1
		8:  sides_mod = 2
		10: sides_mod = 3
		12: sides_mod = 4
	base += _magic_die_count * (1 + sides_mod)
	# PHB sustained spell duration multiplier: sustained effects cost +50% SP (rounded up)
	# Effects 2=Buff, 3=Debuff, 5=Control, 7=Shield are sustained
	if effect_i in [2, 3, 5, 7]:
		base = int(ceil(float(base) * 1.5))
	return maxi(1, base)

func _on_region_filter_selected(region: String) -> void:
	# region == "" means "All" — clear filter; toggling same region also clears
	if region == "" or _region_filter == region:
		_region_filter = ""
	else:
		_region_filter = region
	_refresh_quests_display(_quests_vbox)

# ── Quest execution popup ─────────────────────────────────────────────────────

func _start_quest(quest: Dictionary) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = quest["title"]
	dialog.get_ok_button().text = "Close"
	dialog.min_size = Vector2i(480, 520)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	dialog.add_child(vbox)

	# Header
	var diff_stars: String = "★".repeat(int(quest["difficulty"])) + "☆".repeat(3 - int(quest["difficulty"]))
	var hdr_text: String = str(quest.get("region", "")) + "  •  " + str(quest.get("type","")) + "  •  " + diff_stars
	vbox.add_child(RimvaleUtils.label(hdr_text, 12, RimvaleColors.TEXT_GRAY))
	var desc_lbl = RimvaleUtils.label(str(quest.get("description", "")), 12, RimvaleColors.TEXT_WHITE)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	# Anomaly / Complication flavour lines
	var anomaly: String = str(quest.get("anomaly", ""))
	var complication: String = str(quest.get("complication", ""))
	if not anomaly.is_empty():
		var a_lbl = RimvaleUtils.label("⚠ " + anomaly, 11, Color(0.90, 0.65, 0.20))
		a_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(a_lbl)
	if not complication.is_empty():
		var c_lbl = RimvaleUtils.label("✦ " + complication, 11, Color(0.75, 0.55, 0.85))
		c_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(c_lbl)

	vbox.add_child(HSeparator.new())
	vbox.add_child(RimvaleUtils.label("Mission Log", 13, RimvaleColors.ACCENT))

	# Resolve skill checks — use engine execute_skill_challenge() for proper d20 + modifier rolls
	var skill_checks: Array = quest.get("skill_checks", ["Perception", "Exertion", "Survival"])
	var difficulty: int = int(quest.get("difficulty", 1))
	var dc: int = 8 + difficulty * 3  # DC 11 / 14 / 17 for diff 1/2/3
	var party: Array = GameState.get_active_handles()
	var successes: int = 0

	var log_rtl = RichTextLabel.new()
	log_rtl.bbcode_enabled = true
	log_rtl.fit_content = true
	log_rtl.scroll_active = false
	log_rtl.add_theme_font_size_override("normal_font_size", 13)
	log_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(log_rtl)

	var log_text: String = ""
	for i in range(skill_checks.size()):
		var skill_name: String = skill_checks[i]
		# Find best challenger in party for this skill via engine roll
		var best_result: PackedStringArray = PackedStringArray()
		var best_total: int = 0
		for ph in party:
			var result: PackedStringArray = RimvaleAPI.engine.execute_skill_challenge(ph, skill_name, dc)
			if result.is_empty(): continue
			var total: int = int(str(result[1]))
			if total > best_total:
				best_total = total
				best_result = result
		if best_result.is_empty():
			# No party — solo roll with no modifier
			best_result = RimvaleAPI.engine.execute_skill_challenge(-1, skill_name, dc)
		var passed: bool = (not best_result.is_empty()) and best_result[0] == "1"
		if passed: successes += 1
		var detail_text: String = str(best_result[4]) if best_result.size() > 4 else "No roll data"
		var result_col: String = "#88dd88" if passed else "#dd8888"
		log_text += "[b]Event %d — %s check  (DC %d)[/b]\n" % [i + 1, skill_name, dc]
		log_text += "[color=%s]%s[/color]\n\n" % [result_col, detail_text]

	log_rtl.text = log_text

	# Outcome
	var victory: bool = successes >= ceili(skill_checks.size() / 2.0)
	var outcome_lbl: Label
	if victory:
		outcome_lbl = RimvaleUtils.label(
			"✓ QUEST COMPLETE — +" + str(quest.get("reward_gold", 0)) + " gold, +" +
			str(quest.get("reward_xp", 0)) + " XP", 14, Color(0.50, 0.90, 0.50, 1.0))
		GameState.earn_gold(int(quest.get("reward_gold", 0)))
		# Award XP
		var xp_amt: int = int(quest.get("reward_xp", 0))
		for ph in party:
			RimvaleAPI.engine.add_xp(ph, xp_amt, 20)
		# Remove quest from list
		quests.erase(quest)
	else:
		outcome_lbl = RimvaleUtils.label(
			"✗ QUEST FAILED — " + str(successes) + "/" + str(skill_checks.size()) + " checks passed",
			14, Color(0.90, 0.40, 0.40, 1.0))
	vbox.add_child(outcome_lbl)

	dialog.confirmed.connect(func():
		dialog.queue_free()
		_refresh_quests_display(_quests_vbox))
	add_child(dialog)
	dialog.popup_centered(Vector2(480, 520))

## Map skill name string to index matching SKILL_NAMES in level_up.gd / engine.
func _skill_name_to_idx(sname: String) -> int:
	const NAMES: Array = [
		"Arcane","Crafting","Creature Handling","Cunning","Exertion",
		"Intuition","Learnedness","Medical","Nimble","Perception",
		"Perform","Sneak","Speechcraft","Survival"
	]
	return NAMES.find(sname)

func _on_assign_crafting() -> void:
	if _craft_active_handles.is_empty():
		push_warning("[Crafting] No active party members")
		return
	var sel_idx: int = _craft_member_dropdown.selected if _craft_member_dropdown != null else 0
	sel_idx = clamp(sel_idx, 0, _craft_active_handles.size() - 1)
	var handle: int = _craft_active_handles[sel_idx]
	if GameState.is_busy(handle):
		push_warning("[Crafting] Character is already busy")
		return
	var sel_item_idx: int = _craft_type_dropdown.selected
	var item_type: String = _craft_type_dropdown.get_item_text(sel_item_idx)
	var duration: float = 60.0
	if sel_item_idx < _craftable_items.size():
		var entry: PackedStringArray = _craftable_items[sel_item_idx] as PackedStringArray
		duration = float(int(str(entry[2]))) if entry.size() > 2 else 60.0
	var task: Dictionary = {
		"character_handle": handle,
		"character_name": str(RimvaleAPI.engine.get_character_name(handle)),
		"item_type":       item_type,
		"end_time":        Time.get_unix_time_from_system() + duration,
	}
	GameState.crafting_tasks.append(task)
	GameState.set_busy(handle, true)
	_refresh_crafting_tasks()
	print("[Crafting] %s started crafting %s (%.0fs)" % [task["character_name"], item_type, duration])

func _on_foraging_selected(forage_type: String) -> void:
	_forage_type = forage_type

func _on_assign_foraging() -> void:
	if _forage_active_handles.is_empty():
		push_warning("[Foraging] No active party members")
		return
	var sel_idx: int = _forage_char_dropdown.selected if _forage_char_dropdown != null else 0
	sel_idx = clamp(sel_idx, 0, _forage_active_handles.size() - 1)
	var handle: int = _forage_active_handles[sel_idx]
	if GameState.is_busy(handle):
		push_warning("[Foraging] Character is already busy")
		return
	var gold_by_type: Dictionary = {"hunting": 25, "fishing": 20, "mining": 30, "gathering": 15}
	var task: Dictionary = {
		"character_handle": handle,
		"character_name":   str(RimvaleAPI.engine.get_character_name(handle)),
		"forage_type":      _forage_type,
		"end_time":         Time.get_unix_time_from_system() + 45.0,
		"gold_reward":      gold_by_type.get(_forage_type, 15),
	}
	GameState.forage_tasks.append(task)
	GameState.set_busy(handle, true)
	_refresh_forage_tasks()
	print("[Foraging] %s started %s (45s, +%dg)" % [task["character_name"], _forage_type, task["gold_reward"]])

# ── Task display helpers ──────────────────────────────────────────────────────

func _refresh_crafting_tasks() -> void:
	if _craft_tasks_vbox == null:
		return
	for c in _craft_tasks_vbox.get_children():
		c.queue_free()
	if GameState.crafting_tasks.is_empty():
		_craft_tasks_vbox.add_child(RimvaleUtils.label("No active crafting tasks", 12, RimvaleColors.TEXT_GRAY))
		return
	var now: float = Time.get_unix_time_from_system()
	for task in GameState.crafting_tasks:
		var remaining: float = maxf(0.0, task["end_time"] - now)
		var row = HBoxContainer.new()
		var info = "%s → %s  (%.0fs)" % [task["character_name"], task["item_type"], remaining]
		row.add_child(RimvaleUtils.label(info, 12, RimvaleColors.TEXT_WHITE))
		_craft_tasks_vbox.add_child(row)

func _refresh_forage_tasks() -> void:
	if _forage_tasks_vbox == null:
		return
	for c in _forage_tasks_vbox.get_children():
		c.queue_free()
	if GameState.forage_tasks.is_empty():
		_forage_tasks_vbox.add_child(RimvaleUtils.label("No active foraging tasks", 12, RimvaleColors.TEXT_GRAY))
		return
	var now: float = Time.get_unix_time_from_system()
	for task in GameState.forage_tasks:
		var remaining: float = maxf(0.0, task["end_time"] - now)
		var row = HBoxContainer.new()
		var info = "%s → %s  (%.0fs, +%dg)" % [
			task["character_name"], task["forage_type"].capitalize(), remaining, task["gold_reward"]]
		row.add_child(RimvaleUtils.label(info, 12, RimvaleColors.TEXT_WHITE))
		_forage_tasks_vbox.add_child(row)

# ── Task completion polling ───────────────────────────────────────────────────

func _process(delta: float) -> void:
	_task_timer += delta
	if _task_timer < 1.0:
		return
	_task_timer = 0.0
	var now: float = Time.get_unix_time_from_system()

	# Complete expired crafting tasks
	var i: int = GameState.crafting_tasks.size() - 1
	while i >= 0:
		var task = GameState.crafting_tasks[i]
		if now >= task["end_time"]:
			GameState.add_to_stash(task["item_type"])
			GameState.set_busy(task["character_handle"], false)
			print("[Crafting] %s completed! Added %s to stash." % [task["character_name"], task["item_type"]])
			GameState.crafting_tasks.remove_at(i)
		i -= 1

	# Complete expired foraging tasks
	i = GameState.forage_tasks.size() - 1
	while i >= 0:
		var task = GameState.forage_tasks[i]
		if now >= task["end_time"]:
			GameState.earn_gold(task["gold_reward"])
			GameState.set_busy(task["character_handle"], false)
			print("[Foraging] %s returned with %d gold." % [task["character_name"], task["gold_reward"]])
			GameState.forage_tasks.remove_at(i)
		i -= 1

	# Refresh countdown displays every second
	_refresh_crafting_tasks()
	_refresh_forage_tasks()

# ═══════════════════════════════════════════════════════════════════════════
#   OVERWORLD MAP TAB
# ═══════════════════════════════════════════════════════════════════════════

func _build_overworld_tab(parent: Control) -> void:
	_overworld_panel = Control.new()
	_overworld_panel.anchor_left = 0.0; _overworld_panel.anchor_top = 0.0
	_overworld_panel.anchor_right = 1.0; _overworld_panel.anchor_bottom = 1.0
	_overworld_panel.visible = false
	parent.add_child(_overworld_panel)

	# Root layout: map on left (2/3) + detail on right (1/3)
	var hbox = HBoxContainer.new()
	hbox.anchor_left = 0.0; hbox.anchor_top = 0.0
	hbox.anchor_right = 1.0; hbox.anchor_bottom = 1.0
	hbox.add_theme_constant_override("separation", 0)
	_overworld_panel.add_child(hbox)

	# ── LEFT: Map canvas ────────────────────────────────────────────────────
	var map_col = VBoxContainer.new()
	map_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_col.size_flags_stretch_ratio = 2.0
	map_col.add_theme_constant_override("separation", 0)
	hbox.add_child(map_col)

	# Title strip
	var title_panel = PanelContainer.new()
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.08, 0.05, 0.15, 1.0)
	title_style.content_margin_left = 12; title_style.content_margin_right = 12
	title_style.content_margin_top = 8;   title_style.content_margin_bottom = 8
	title_panel.add_theme_stylebox_override("panel", title_style)
	var title_hbox = HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 10)
	title_panel.add_child(title_hbox)
	title_hbox.add_child(RimvaleUtils.label("🗺", 20, RimvaleColors.GOLD))
	title_hbox.add_child(RimvaleUtils.label("RIMVALE — Overworld Map", 18, RimvaleColors.ACCENT))
	var spacer = Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(spacer)
	title_hbox.add_child(RimvaleUtils.label("Tap a region to visit.", 11, RimvaleColors.TEXT_GRAY))
	map_col.add_child(title_panel)

	# Map canvas — fills the rest of the left column
	_overworld_map_control = Control.new()
	_overworld_map_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overworld_map_control.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_overworld_map_control.clip_contents = true
	map_col.add_child(_overworld_map_control)

	# Map parchment background
	var parchment = ColorRect.new()
	parchment.color = Color(0.10, 0.08, 0.14, 1.0)
	parchment.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overworld_map_control.add_child(parchment)

	# Subtle grid overlay
	var grid = _overworld_grid_overlay()
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overworld_map_control.add_child(grid)

	# Populate region buttons (positioned in _overworld_layout_regions, called deferred)
	_overworld_region_buttons.clear()
	for region in OVERWORLD_REGIONS:
		var btn = _overworld_region_button(region)
		_overworld_map_control.add_child(btn)
		_overworld_region_buttons[region["id"]] = btn

	# Reposition whenever the map resizes
	_overworld_map_control.resized.connect(_overworld_layout_regions)
	# Initial layout (deferred so size is valid)
	call_deferred("_overworld_layout_regions")

	# ── RIGHT: Detail panel ─────────────────────────────────────────────────
	var detail_col = PanelContainer.new()
	detail_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_col.size_flags_stretch_ratio = 1.0
	detail_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var detail_style = StyleBoxFlat.new()
	detail_style.bg_color = Color(0.06, 0.04, 0.10, 1.0)
	detail_style.border_width_left = 2
	detail_style.border_color = Color(0.30, 0.20, 0.50, 1.0)
	detail_style.content_margin_left = 12; detail_style.content_margin_right = 12
	detail_style.content_margin_top = 12;  detail_style.content_margin_bottom = 12
	detail_col.add_theme_stylebox_override("panel", detail_style)
	hbox.add_child(detail_col)

	var detail_scroll = ScrollContainer.new()
	detail_col.add_child(detail_scroll)

	_overworld_detail_vbox = VBoxContainer.new()
	_overworld_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overworld_detail_vbox.add_theme_constant_override("separation", 8)
	detail_scroll.add_child(_overworld_detail_vbox)

	# Open the current region (from GameState) in the detail panel
	var cur: String = GameState.current_region
	if cur == "": cur = "plains"
	_overworld_focus_region(cur)


func _overworld_grid_overlay() -> Control:
	# Lightweight crosshatch suggesting a map grid.
	var c = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(1, 10):
		var vline = ColorRect.new()
		vline.color = Color(0.20, 0.18, 0.30, 0.25)
		vline.anchor_left = i / 10.0; vline.anchor_right = i / 10.0
		vline.anchor_top = 0.0; vline.anchor_bottom = 1.0
		vline.offset_left = 0; vline.offset_right = 1
		vline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(vline)
	for j in range(1, 10):
		var hline = ColorRect.new()
		hline.color = Color(0.20, 0.18, 0.30, 0.25)
		hline.anchor_top = j / 10.0; hline.anchor_bottom = j / 10.0
		hline.anchor_left = 0.0; hline.anchor_right = 1.0
		hline.offset_top = 0; hline.offset_bottom = 1
		hline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(hline)
	return c


func _overworld_region_button(region: Dictionary) -> Control:
	# A clickable region marker: icon + short name + glow when visited/current.
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(140, 72)
	btn.flat = false
	btn.clip_text = true
	btn.text = "%s  %s" % [str(region["icon"]), str(region["name"])]
	btn.add_theme_font_size_override("font_size", 12)

	var accent: Color = region.get("accent", RimvaleColors.ACCENT)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.08, 0.18, 0.92)
	bg.border_color = accent
	bg.border_width_left = 2; bg.border_width_right = 2
	bg.border_width_top = 2;  bg.border_width_bottom = 2
	bg.corner_radius_top_left = 6; bg.corner_radius_top_right = 6
	bg.corner_radius_bottom_left = 6; bg.corner_radius_bottom_right = 6
	bg.content_margin_left = 6; bg.content_margin_right = 6
	btn.add_theme_stylebox_override("normal", bg)

	var hover = bg.duplicate()
	hover.bg_color = Color(0.18, 0.12, 0.26, 0.95)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = bg.duplicate()
	pressed.bg_color = Color(0.22, 0.14, 0.32, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", RimvaleColors.TEXT_WHITE)
	btn.add_theme_color_override("font_hover_color", accent)

	var rid: String = str(region["id"])
	btn.pressed.connect(func(): _overworld_focus_region(rid))
	return btn


func _overworld_layout_regions() -> void:
	# Position each region button at its (pos × map_size) coordinate.
	if _overworld_map_control == null: return
	var sz: Vector2 = _overworld_map_control.size
	if sz.x < 40.0 or sz.y < 40.0: return  # not laid out yet

	for region in OVERWORLD_REGIONS:
		var rid: String = str(region["id"])
		if not _overworld_region_buttons.has(rid): continue
		var btn: Button = _overworld_region_buttons[rid]
		var pos: Vector2 = region["pos"]
		var bx: float = pos.x * sz.x - btn.custom_minimum_size.x * 0.5
		var by: float = pos.y * sz.y - btn.custom_minimum_size.y * 0.5
		btn.position = Vector2(bx, by)
		btn.size = btn.custom_minimum_size

	_overworld_refresh_region_highlights()


func _overworld_refresh_region_highlights() -> void:
	for region in OVERWORLD_REGIONS:
		var rid: String = str(region["id"])
		if not _overworld_region_buttons.has(rid): continue
		var btn: Button = _overworld_region_buttons[rid]
		var accent: Color = region.get("accent", RimvaleColors.ACCENT)
		var is_current: bool = GameState.current_region == rid
		var is_visited: bool = rid in GameState.visited_regions
		var badge: String = str(region.get("badge", ""))
		var has_badge: bool = (not badge.is_empty()) and badge in GameState.story_earned_badges

		var bg = StyleBoxFlat.new()
		bg.bg_color = (
			Color(0.30, 0.24, 0.10, 0.95) if has_badge
			else Color(0.20, 0.14, 0.28, 0.95) if is_current
			else Color(0.14, 0.10, 0.20, 0.92) if is_visited
			else Color(0.10, 0.08, 0.14, 0.88)
		)
		bg.border_color = accent
		bg.border_width_left = 3 if is_current else 2
		bg.border_width_right = 3 if is_current else 2
		bg.border_width_top = 3 if is_current else 2
		bg.border_width_bottom = 3 if is_current else 2
		bg.corner_radius_top_left = 6; bg.corner_radius_top_right = 6
		bg.corner_radius_bottom_left = 6; bg.corner_radius_bottom_right = 6
		bg.content_margin_left = 6; bg.content_margin_right = 6
		btn.add_theme_stylebox_override("normal", bg)

		# Rebuild button label showing state markers
		var marker: String = ""
		if has_badge: marker = " 🏅"
		elif is_current: marker = " ●"
		elif is_visited: marker = " ·"
		btn.text = "%s  %s%s" % [str(region["icon"]), str(region["name"]), marker]


func _overworld_find_region(rid: String) -> Dictionary:
	for region in OVERWORLD_REGIONS:
		if str(region["id"]) == rid:
			return region
	return {}


func _overworld_focus_region(rid: String) -> void:
	_overworld_focused_region = rid
	var region: Dictionary = _overworld_find_region(rid)
	if region.is_empty(): return

	# Clear detail panel
	for c in _overworld_detail_vbox.get_children():
		c.queue_free()

	# ── Header ──────────────────────────────────────────────────────────────
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	header_row.add_child(RimvaleUtils.label(str(region["icon"]), 28, RimvaleColors.GOLD))
	var title_vbox = VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 0)
	header_row.add_child(title_vbox)
	title_vbox.add_child(RimvaleUtils.label(str(region["name"]), 18, region.get("accent", RimvaleColors.ACCENT)))
	var flavor_lbl = RimvaleUtils.label(str(region["flavor"]), 11, RimvaleColors.TEXT_GRAY)
	flavor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_vbox.add_child(flavor_lbl)
	_overworld_detail_vbox.add_child(header_row)

	# Status chips row: current / visited / badge
	var chips_row = HBoxContainer.new()
	chips_row.add_theme_constant_override("separation", 6)
	var is_current: bool = GameState.current_region == rid
	var is_visited: bool = rid in GameState.visited_regions
	var badge: String = str(region.get("badge", ""))
	var has_badge: bool = (not badge.is_empty()) and badge in GameState.story_earned_badges
	if is_current:
		chips_row.add_child(_overworld_chip("● Current", RimvaleColors.ACCENT, Color(0.18, 0.10, 0.26)))
	if is_visited and not is_current:
		chips_row.add_child(_overworld_chip("Visited", RimvaleColors.CYAN, Color(0.08, 0.16, 0.22)))
	if has_badge:
		chips_row.add_child(_overworld_chip("🏅 " + badge.replace(" Badge", ""), RimvaleColors.GOLD, Color(0.20, 0.16, 0.05)))
	_overworld_detail_vbox.add_child(chips_row)

	_overworld_detail_vbox.add_child(RimvaleUtils.separator())

	# ── Travel button ───────────────────────────────────────────────────────
	if not is_current:
		var travel_btn = RimvaleUtils.button("✈ Travel to " + str(region["name"]), RimvaleColors.ACCENT, 44, 14)
		travel_btn.pressed.connect(func():
			GameState.travel_to_region(rid)
			_overworld_refresh_region_highlights()
			_overworld_focus_region(rid)
		)
		_overworld_detail_vbox.add_child(travel_btn)
		_overworld_detail_vbox.add_child(RimvaleUtils.spacer(4))

	# ── Explore button ──────────────────────────────────────────────────────
	if is_current:
		var explore_btn = RimvaleUtils.button("🗺 Explore This Region", RimvaleColors.HP_GREEN, 48, 14)
		explore_btn.pressed.connect(func():
			_launch_explore(rid)
		)
		_overworld_detail_vbox.add_child(explore_btn)
		_overworld_detail_vbox.add_child(RimvaleUtils.spacer(4))

	# ── Sub-regions list ────────────────────────────────────────────────────
	_overworld_detail_vbox.add_child(RimvaleUtils.label("SUB-REGIONS", 13, RimvaleColors.TEXT_GRAY))
	var subs: Array = region.get("subregions", [])
	for sub in subs:
		var sub_row = HBoxContainer.new()
		sub_row.add_theme_constant_override("separation", 6)
		var visited_here: bool = sub in GameState.visited_subregions
		var icon_s: String = "●" if visited_here else "○"
		var col: Color = RimvaleColors.HP_GREEN if visited_here else RimvaleColors.TEXT_GRAY
		sub_row.add_child(RimvaleUtils.label(icon_s, 11, col))
		var sub_lbl = RimvaleUtils.label(str(sub), 12, RimvaleColors.TEXT_WHITE)
		sub_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sub_row.add_child(sub_lbl)
		# Lineage hint (how many native lineages)
		var natives: PackedStringArray = RimvaleAPI.engine.get_lineages_for_region(str(sub))
		sub_row.add_child(RimvaleUtils.label("%d lineages" % natives.size(), 10, RimvaleColors.CYAN))
		# Explore button per subregion (only if current region)
		if is_current:
			var cap_sub: String = str(sub)
			var cap_rid: String = rid
			var explore_sub_btn = RimvaleUtils.button("🗺", RimvaleColors.HP_GREEN, 28, 10)
			explore_sub_btn.custom_minimum_size.x = 32
			explore_sub_btn.tooltip_text = "Explore " + cap_sub
			explore_sub_btn.pressed.connect(func(): _launch_explore(cap_rid, cap_sub))
			sub_row.add_child(explore_sub_btn)
		_overworld_detail_vbox.add_child(sub_row)

	_overworld_detail_vbox.add_child(RimvaleUtils.separator())

	# ── ACF locations + missions ────────────────────────────────────────────
	_overworld_detail_vbox.add_child(RimvaleUtils.label("ACF LOCATIONS", 13, RimvaleColors.TEXT_GRAY))

	_overworld_location_list_vbox = VBoxContainer.new()
	_overworld_location_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overworld_location_list_vbox.add_theme_constant_override("separation", 6)
	_overworld_detail_vbox.add_child(_overworld_location_list_vbox)

	var acf_list: Array = region.get("acf", [])
	for loc in acf_list:
		_overworld_location_list_vbox.add_child(_overworld_location_card(rid, loc))

	# ── Story missions anchored to this region ──────────────────────────────
	_overworld_detail_vbox.add_child(RimvaleUtils.separator())
	_overworld_detail_vbox.add_child(RimvaleUtils.label("STORY ARC", 13, RimvaleColors.TEXT_GRAY))
	var story_arc_found: bool = false
	for sec in STORY_SECTIONS:
		if str(sec[0]) == rid:
			story_arc_found = true
			for m in (sec[4] as Array):
				_overworld_detail_vbox.add_child(_overworld_story_row(m))
	if not story_arc_found:
		_overworld_detail_vbox.add_child(RimvaleUtils.label(
			"No story arc anchored here yet.", 11, RimvaleColors.TEXT_DIM))

	# Keep highlights in sync
	_overworld_refresh_region_highlights()


func _overworld_chip(text: String, fg: Color, bg_col: Color) -> Control:
	var p = PanelContainer.new()
	var st = StyleBoxFlat.new()
	st.bg_color = bg_col
	st.corner_radius_top_left = 4; st.corner_radius_top_right = 4
	st.corner_radius_bottom_left = 4; st.corner_radius_bottom_right = 4
	st.content_margin_left = 6; st.content_margin_right = 6
	st.content_margin_top = 2;  st.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", st)
	var l = RimvaleUtils.label(text, 10, fg)
	p.add_child(l)
	return p


func _overworld_location_card(region_id: String, loc: Array) -> Control:
	# loc: [id, title, subregion, teaser, xp_reward, is_boss]
	var lid: String = str(loc[0])
	var ltitle: String = str(loc[1])
	var lsub: String = str(loc[2])
	var lteaser: String = str(loc[3])
	var lxp: int = int(loc[4])
	var is_boss: bool = bool(loc[5])
	var cleared: bool = GameState.is_acf_cleared(lid)

	var panel = PanelContainer.new()
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.12, 0.10, 0.18, 1.0) if not cleared else Color(0.10, 0.16, 0.10, 1.0)
	st.border_color = RimvaleColors.DANGER if is_boss and not cleared else Color(0.30, 0.25, 0.40, 1.0)
	st.border_width_left = 2
	st.corner_radius_top_left = 4; st.corner_radius_top_right = 4
	st.corner_radius_bottom_left = 4; st.corner_radius_bottom_right = 4
	st.content_margin_left = 8; st.content_margin_right = 8
	st.content_margin_top = 6; st.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", st)

	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)

	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	if is_boss:
		head.add_child(RimvaleUtils.label("⚔", 11, RimvaleColors.DANGER))
	head.add_child(RimvaleUtils.label(ltitle, 12,
		RimvaleColors.TEXT_GRAY if cleared else RimvaleColors.TEXT_WHITE))
	if cleared:
		head.add_child(RimvaleUtils.label("✓", 12, RimvaleColors.HP_GREEN))
	var spacer2 = Control.new(); spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer2)
	head.add_child(RimvaleUtils.label(lsub, 10, RimvaleColors.CYAN))
	v.add_child(head)

	var t = RimvaleUtils.label(lteaser, 10, RimvaleColors.TEXT_GRAY)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)

	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	var xp_show: int = maxi(1, lxp / 10) if cleared else lxp
	actions.add_child(RimvaleUtils.label(
		"%d XP" % xp_show, 10,
		RimvaleColors.TEXT_GRAY if cleared else RimvaleColors.GOLD))
	var sp = Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(sp)

	var btn_color: Color = RimvaleColors.DANGER if is_boss else RimvaleColors.ACCENT
	var btn_text: String = "Replay" if cleared else ("Assault" if is_boss else "Investigate")
	var act_btn = RimvaleUtils.button(btn_text, btn_color, 28, 11)
	act_btn.custom_minimum_size = Vector2(88, 28)
	var cap_id = lid; var cap_title = ltitle; var cap_sub = lsub
	var cap_tease = lteaser; var cap_xp = lxp; var cap_boss = is_boss
	var cap_region = region_id
	act_btn.pressed.connect(func():
		_overworld_start_acf_mission(cap_region, cap_id, cap_title, cap_sub, cap_tease, cap_xp, cap_boss))
	actions.add_child(act_btn)
	v.add_child(actions)

	return panel


func _overworld_story_row(m_data: Array) -> Control:
	# m_data: [id, title, region, teaser, xp, is_boss]
	var mid: String     = m_data[0]
	var mtitle: String  = m_data[1]
	var mregion: String = m_data[2]
	var mteaser: String = m_data[3]
	var mxp: int        = m_data[4]
	var is_boss: bool   = m_data[5]
	var completed: bool = mid in GameState.story_completed_missions

	var row = PanelContainer.new()
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.14, 0.10, 0.20, 1.0) if not completed else Color(0.10, 0.16, 0.10, 1.0)
	st.border_color = RimvaleColors.DANGER if is_boss and not completed else Color(0.25, 0.20, 0.35, 1.0)
	st.border_width_left = 2
	st.corner_radius_top_left = 4; st.corner_radius_top_right = 4
	st.corner_radius_bottom_left = 4; st.corner_radius_bottom_right = 4
	st.content_margin_left = 8; st.content_margin_right = 8
	st.content_margin_top = 4; st.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", st)

	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	row.add_child(v)

	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	if is_boss:
		head.add_child(RimvaleUtils.label("⚔", 11, RimvaleColors.DANGER))
	head.add_child(RimvaleUtils.label(mtitle, 12,
		RimvaleColors.TEXT_WHITE if not completed else RimvaleColors.TEXT_GRAY))
	if completed:
		head.add_child(RimvaleUtils.label("✓", 12, RimvaleColors.HP_GREEN))
	var sp = Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(RimvaleUtils.label(str(mxp) + " XP", 10, RimvaleColors.GOLD))
	v.add_child(head)

	var t = RimvaleUtils.label(mteaser, 10, RimvaleColors.TEXT_GRAY)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)

	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	actions.add_child(RimvaleUtils.label(mregion, 10, RimvaleColors.CYAN))
	var sp2 = Control.new(); sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(sp2)

	var btn_color: Color = RimvaleColors.DANGER if is_boss else RimvaleColors.ACCENT
	var btn_text: String = "Replay" if completed else "Begin"
	var play_btn = RimvaleUtils.button(btn_text, btn_color, 28, 11)
	play_btn.custom_minimum_size = Vector2(72, 28)
	var cap_mid = mid; var cap_title = mtitle
	var cap_teaser = mteaser; var cap_xp = mxp
	play_btn.pressed.connect(func():
		_start_story_mission(cap_mid, cap_title, cap_teaser, cap_xp))
	actions.add_child(play_btn)
	v.add_child(actions)

	return row


# ── Overworld exploration launch ──────────────────────────────────────────────
func _launch_explore(region_id: String, subregion_name: String = "") -> void:
	var party: Array = GameState.get_active_handles()
	if party.is_empty():
		var info = AcceptDialog.new()
		info.title = "No Active Party"
		info.dialog_text = "Deploy a unit to your Active Team before exploring, Agent."
		add_child(info); info.popup_centered()
		return
	GameState.travel_to_region(region_id)
	if not subregion_name.is_empty():
		GameState.travel_to_subregion(subregion_name)
	elif GameState.current_subregion.is_empty():
		# Default to first subregion of the region
		var region: Dictionary = _overworld_find_region(region_id)
		var subs: Array = region.get("subregions", [])
		if not subs.is_empty():
			GameState.travel_to_subregion(str(subs[0]))
	var main = get_parent().get_parent() if get_parent() else null
	if main and main.has_method("push_screen"):
		main.push_screen("res://scenes/explore/explore.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/explore/explore.tscn")

# ── ACF mission resolution ────────────────────────────────────────────────────
func _overworld_start_acf_mission(region_id: String, mid: String, title: String,
		subregion: String, teaser: String, xp: int, is_boss: bool) -> void:
	var party: Array = GameState.get_active_handles()
	if party.is_empty():
		push_warning("[Overworld] No active party — recruit in the Units tab first.")
		var info = AcceptDialog.new()
		info.title = "No Active Party"
		info.dialog_text = "Deploy a unit to your Active Team before venturing out, Agent."
		add_child(info); info.popup_centered()
		return

	# Travel the party to this sub-region as part of the mission launch
	GameState.travel_to_region(region_id)
	GameState.travel_to_subregion(subregion)

	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.get_ok_button().text = "Confirm"
	dialog.min_size = Vector2i(520, 420)

	var dvbox = VBoxContainer.new()
	dvbox.add_theme_constant_override("separation", 8)
	dialog.add_child(dvbox)

	dvbox.add_child(RimvaleUtils.label("📍 " + subregion, 12, RimvaleColors.CYAN))
	var t = RimvaleUtils.label(teaser, 12, RimvaleColors.TEXT_WHITE)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dvbox.add_child(t)
	dvbox.add_child(HSeparator.new())

	# Multi-skill check. Boss missions are harder.
	var dc: int = 14 if is_boss else 11
	var checks: Array = ["Perception", "Exertion", "Survival", "Social"] if is_boss else ["Perception", "Exertion"]

	var log_rtl = RichTextLabel.new()
	log_rtl.bbcode_enabled = true
	log_rtl.fit_content = true
	log_rtl.scroll_active = false
	log_rtl.add_theme_font_size_override("normal_font_size", 12)
	log_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dvbox.add_child(log_rtl)

	var log_text: String = ""
	var successes: int = 0
	for skill in checks:
		var best: PackedStringArray = PackedStringArray()
		var best_total: int = 0
		for ph in party:
			var result: PackedStringArray = RimvaleAPI.engine.execute_skill_challenge(ph, skill, dc)
			if result.is_empty(): continue
			var total: int = int(str(result[1]))
			if total > best_total:
				best_total = total; best = result
		if best.is_empty():
			best = RimvaleAPI.engine.execute_skill_challenge(-1, skill, dc)
		var passed: bool = (not best.is_empty()) and best[0] == "1"
		if passed: successes += 1
		var detail: String = str(best[4]) if best.size() > 4 else "No roll data"
		var col: String = "#88dd88" if passed else "#dd8888"
		log_text += "[b]%s check (DC %d)[/b]\n[color=%s]%s[/color]\n\n" % [skill, dc, col, detail]
	log_rtl.text = log_text

	var required_successes: int = ceili(checks.size() / 2.0)
	var victory: bool = successes >= required_successes

	if victory:
		dvbox.add_child(RimvaleUtils.label(
			"✓ OPERATION COMPLETE — +%d XP" % xp, 14, Color(0.50, 0.90, 0.50)))
	else:
		dvbox.add_child(RimvaleUtils.label(
			"✗ OPERATION FAILED — %d/%d checks passed" % [successes, checks.size()],
			14, Color(0.90, 0.40, 0.40)))

	dialog.confirmed.connect(func():
		if victory:
			if not GameState.is_acf_cleared(mid):
				GameState.mark_acf_cleared(mid)
				for ph in party:
					RimvaleAPI.engine.add_xp(ph, xp, 20)
			_overworld_focus_region(region_id)
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2(520, 420))
