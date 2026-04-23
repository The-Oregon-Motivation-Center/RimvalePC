extends Control

const _WS = preload("res://autoload/world_systems.gd")

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
var _repair_vbox:           VBoxContainer
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
var _dd_type: int          = 0   # 0=Standard 1=Kaiju 2=Apex 3=Militia 4=Mob 5=Custom 6=Siege
var _dd_enemy_level: int   = 3
var _dd_kaiju_idx: int     = 0
var _dd_apex_idx: int      = 0
var _dd_militia_idx: int   = 0
var _dd_mob_count: int     = 30
var _dd_mob_level: int     = 3
var _dd_siege_tier: int    = 1
var _dd_terrain_style: int = 0
var _dd_config_panel: VBoxContainer
var _dd_type_btns: Array   = []
var _dd_custom_monster_idx: int = 0

# ── Monster Creator state ────────────────────────────────────────────────────
var _mc_overlay: Control
var _mc_name_edit: LineEdit
var _mc_level_slider: HSlider
var _mc_apex_check: CheckButton
var _mc_stats: Dictionary = {"STR": 1, "SPD": 1, "INT": 1, "VIT": 1, "DIV": 1}
var _mc_stat_labels: Dictionary = {}
var _mc_abilities: Array = []
var _mc_ability_category_opt: OptionButton
var _mc_ability_buttons: Array = []
var _mc_ability_grid: GridContainer
var _mc_saved_vbox: VBoxContainer

# ── Quest Board tab refs ────────────────────────────────────────────────────
var _quest_board_quests: Array = []  # available quests shown on board
var _quest_active_vbox: VBoxContainer
var _quest_board_vbox: VBoxContainer

# ── Story tab refs ────────────────────────────────────────────────────────────
var _story_sections_vbox: VBoxContainer  # rebuilt when badges change
var _story_badge_lbl: Label

# ── Story mission execution state ────────────────────────────────────────────
var _story_exec_overlay: Control          # full-screen mission execution panel
var _story_exec_mission: Dictionary = {}  # current mission data dict
var _story_exec_quest: Dictionary = {}    # quest state (part, challenge, log, etc.)
var _story_exec_agent_handle: int = 0     # selected agent for current challenge
var _story_exec_log_rtl: RichTextLabel    # mission log display
var _story_exec_header_lbl: Label
var _story_exec_progress_bar: ProgressBar
var _story_exec_progress_lbl: Label
var _story_exec_team_hbox: HBoxContainer
var _story_exec_action_vbox: VBoxContainer
var _story_exec_agent_bars: Dictionary = {}  # handle -> {name_lbl, hp_bar, sp_bar}
var _story_exec_is_rolling: bool = false

# ── Overworld state ──────────────────────────────────────────────────────────
var _overworld_panel: Control
var _overworld_map_control: Control           # canvas holding region nodes
var _overworld_detail_vbox: VBoxContainer     # right-hand detail column
var _overworld_region_buttons: Dictionary = {}  # region_id -> Button
var _overworld_focused_region: String = ""   # which region is currently opened in detail
var _overworld_location_list_vbox: VBoxContainer  # refreshed when region focused

# ── 3D World Map state ──────────────────────────────────────────────────────
var _ow_viewport: SubViewport
var _ow_camera: Camera3D
var _ow_world_root: Node3D
var _ow_region_markers: Dictionary = {}   # region_id -> Node3D (beacon)
var _ow_zoomed_region: String = ""        # "" = full-map view
var _ow_cam_animating: bool = false
var _ow_cam_from_pos: Vector3 = Vector3.ZERO
var _ow_cam_from_look: Vector3 = Vector3.ZERO
var _ow_cam_to_pos: Vector3 = Vector3.ZERO
var _ow_cam_to_look: Vector3 = Vector3.ZERO
var _ow_cam_t: float = 0.0
var _ow_svc: SubViewportContainer
var _ow_back_btn: Button
var _ow_label_overlay: Control
var _ow_region_label_nodes: Dictionary = {}  # region_id -> PanelContainer
var _ow_subregion_label_nodes: Array = []    # [{panel, pos}]
var _ow_map_container: Control
var _ow_dragging: bool = false
var _ow_drag_start: Vector2 = Vector2.ZERO
var _ow_drag_moved: bool = false           # true if mouse moved enough to count as drag
var _ow_cam_look_target: Vector3 = Vector3(0, 0, -2)  # current look-at point

# ── Ritual tab refs ───────────────────────────────────────────────────────────
var _ritual_tasks_vbox:   VBoxContainer
var _ritual_active_vbox:  VBoxContainer
var _ritual_result_lbl:   Label
var _ritual_empty_lbl:    Label
var _ritual_overlay:      Control   # full-screen spell builder overlay
var _ritual_inner:        VBoxContainer
var _ritual_preview_lbl:  Label
var _ritual_breakdown_lbl: Label
var _ritual_desc_lbl:     Label
var _rb_tp_range_row:     HBoxContainer  # teleport range slider row (shown/hidden)

# ── Ritual spell builder state (mirrors dungeon.gd PHB builder) ──────────────
var _rb_name:          String = ""
var _rb_caster_idx:    int = 0
var _rb_domain:        int = 0
var _rb_effect_idx:    int = 0
var _rb_duration_idx:  int = 0
var _rb_range_idx:     int = 1
var _rb_targets:       int = 1
var _rb_area_idx:      int = 0
var _rb_die_count:     int = 1
var _rb_die_idx:       int = 0
var _rb_damage_type:   int = 3
var _rb_is_healing:    bool = false
var _rb_is_saving_throw: bool = false
var _rb_is_teleport:   bool = false
var _rb_tp_range:      int = 5       # teleport max distance in tiles (when teleport enabled)
var _rb_is_combustion: bool = false
var _rb_conditions:    Array = []
var _rb_handles:       Array = []    # active party handles for caster selection

# PHB spell formula constants (same as dungeon.gd)
const RB_DOMAIN_NAMES: PackedStringArray = ["Biological", "Chemical", "Physical", "Spiritual"]
const RB_DOMAIN_EFFECTS: Array = [
	[["Augment Trait", 1], ["Health Regeneration", 1], ["Memory Edit", 4],
	 ["Mind Control", 6], ["Revivify", 5], ["Terrain Manipulation", 1],
	 ["Undeath", 1], ["Weather Resistance", 1]],
	[["Combustion", 4], ["Damage an Object", 1], ["Mend an Object", 2],
	 ["Remove Grime", 1], ["Transmutation", 40]],
	[["Accuracy", 1], ["Ambient Temperature", 1], ["Create Construct", 2],
	 ["Damage Output Increase", 1], ["Damage Reduction", 2], ["Illusions", 2],
	 ["Light", 2], ["Shield", 1], ["Telekinesis", 1], ["Teleportation", 1],
	 ["Time Manipulation", 2]],
	[["Bless", 1], ["Conjure Damage or Healing", 1], ["Curse", 1],
	 ["Intangibility", 4], ["Suppress Magic", 2], ["Summon", 2]],
]
const RB_CONDITIONS_BENEFICIAL: PackedStringArray = [
	"Calm", "Dodging", "Flying", "Hidden", "Invisible",
	"Invulnerable", "Resistance", "Shielded", "Silent", "Stoneskin"
]
const RB_CONDITIONS_HARMFUL: PackedStringArray = [
	"Bleed", "Blinded", "Charm", "Confused", "Dazed", "Deafened",
	"Depleted", "Diseased", "Enraged", "Exhausted", "Fear", "Fever",
	"Incapacitated", "Paralyzed", "Petrified", "Poisoned", "Prone",
	"Restrained", "Slowed", "Squeeze", "Stunned", "Unconscious", "Vulnerable"
]
const RB_DAMAGE_TYPES: PackedStringArray = [
	"Bludgeoning", "Piercing", "Slashing", "Force", "Fire", "Cold",
	"Lightning", "Acid", "Poison", "Psychic", "Radiant", "Necrotic", "Thunder"
]
const RB_DURATION_LABELS: PackedStringArray = ["Instant", "1 Minute", "10 Minutes", "1 Hour", "1 Day"]
const RB_DURATION_ROUNDS: PackedInt32Array  = [0, 10, 100, 600, 14400]
const RB_DURATION_MULT:   PackedInt32Array  = [1, 2, 3, 5, 10]
const RB_RANGE_LABELS:   PackedStringArray = ["Self", "Touch", "15 ft", "30 ft", "100 ft", "500 ft", "1000 ft"]
const RB_RANGE_SP_COST:  PackedInt32Array  = [0, 0, 1, 2, 3, 6, 10]
const RB_AREA_LABELS: PackedStringArray = ["Single Target", "Small (10 ft cube)", "Large (30 ft cube)", "Massive (100 ft cube)"]
const RB_AREA_MULT:   PackedInt32Array  = [1, 2, 3, 10]
const RB_DIE_LABELS:    PackedStringArray = ["d4", "d6", "d8", "d10", "d12"]
const RB_DIE_SIDES_MOD: PackedInt32Array  = [0, 1, 2, 3, 4]

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

# -- Monster Abilities (14 categories) ------------------------------------
const MONSTER_ABILITY_CATEGORIES: Array = [
	{"name": "General", "abilities": [
		"Multiattack", "Pack Tactics", "Regeneration", "Ambush",
		"Resistance", "Frightful Presence", "Legendary Action"
	]},
	{"name": "Movement", "abilities": [
		"Burrowing", "Climbing", "Swimming", "Flying",
		"Teleportation", "Phasing", "Amphibious"
	]},
	{"name": "Size", "abilities": [
		"Tiny", "Small", "Medium", "Large", "Huge", "Gargantuan", "Colossal"
	]},
	{"name": "Magic", "abilities": [
		"Innate Spellcasting", "Spell Resistance", "Antimagic Aura",
		"Magic Absorption", "Counterspell", "Arcane Burst"
	]},
	{"name": "Animal", "abilities": [
		"Keen Senses", "Pounce", "Constrict", "Swallow",
		"Venomous Bite", "Camouflage", "Pack Leader"
	]},
	{"name": "Environmental", "abilities": [
		"Tremorsense", "Darkvision", "Heat Aura", "Cold Aura",
		"Sandstorm", "Aquatic Adaptation", "Bioluminescence"
	]},
	{"name": "Biological", "abilities": [
		"Acid Spit", "Poison Cloud", "Spore Burst", "Regenerative Limbs",
		"Hive Mind", "Adaptive Hide", "Parasitic Bond"
	]},
	{"name": "Chemical", "abilities": [
		"Corrosive Touch", "Explosive Gas", "Paralytic Toxin",
		"Pheromone Control", "Alchemical Blood", "Ink Cloud"
	]},
	{"name": "Physical", "abilities": [
		"Tail Sweep", "Gore", "Trample", "Stone Skin",
		"Iron Grip", "Quake Stomp", "Spine Volley"
	]},
	{"name": "Spiritual", "abilities": [
		"Life Drain", "Fear Aura", "Spirit Walk", "Possession",
		"Soul Bind", "Radiant Smite", "Haunt"
	]},
	{"name": "Unity", "abilities": [
		"War Cry", "Shield Wall", "Coordinated Strike", "Rally",
		"Formation", "Sacrifice", "Inspire"
	]},
	{"name": "Void", "abilities": [
		"Void Bolt", "Dimensional Rift", "Gravity Well", "Nullify",
		"Entropy", "Void Shield", "Spatial Tear"
	]},
	{"name": "Chaos", "abilities": [
		"Wild Surge", "Mutation", "Reality Warp", "Chaos Bolt",
		"Instability Aura", "Madness Gaze", "Probability Shift"
	]},
	{"name": "Lineage", "abilities": [
		"Breath Weapon", "Shapeshift", "Elemental Body", "Fey Step",
		"Undead Fortitude", "Celestial Radiance", "Infernal Command"
	]},
]

# ── Contact NPCs ─────────────────────────────────────────────────────────────
# Each entry: section_id -> {name, lineage, intro, sendoff}
const STORY_CONTACTS: Dictionary = {
	"plains": {"name": "Lyra", "lineage": "Lyra",
		"intro": "Lyra, ACF Plains Liaison. I've been embedded here for weeks — this is worse than the reports suggest.",
		"sendoff": "The Plains are counting on you. Good luck out there."},
	"shadows": {"name": "Seris", "lineage": "Twilightkin",
		"intro": "Seris. Shadows Beneath contact. Listen more than you look — sight fails in the deep.",
		"sendoff": "Stay quiet. Stay whole. Good luck out there."},
	"astral": {"name": "Gronk", "lineage": "Tetrasimian",
		"intro": "Gronk. Astral Tear contact. I'll keep this short — the planar static cuts transmissions.",
		"sendoff": "Don't let the void take your name. Good hunting."},
	"terminus": {"name": "Unit 4", "lineage": "Watchling",
		"intro": "Unit 4, Terminus Volarus station. Operational status: active. Weather interference: significant.",
		"sendoff": "Signal acknowledged. Good luck, agent."},
	"glass": {"name": "Arvane", "lineage": "Hellforged",
		"intro": "Arvane. Glass Passage. Trust nothing you see reflected — the Enclave has salted every surface.",
		"sendoff": "See clearly. Strike true. Do not let the glass keep you."},
	"isles": {"name": "Loxy", "lineage": "Cloudling",
		"intro": "Loxy here! Isles liaison — yes, I'm the one with the boat. Try not to sink it.",
		"sendoff": "Wind at your backs! Good luck out there!"},
	"metro": {"name": "Calder", "lineage": "Corvian",
		"intro": "Calder, Metro contact. I've been pulling threads on this one for three weeks. The picture's not pretty.",
		"sendoff": "Watch the rooftops. Good luck, agent."},
	"titans": {"name": "Veyraen", "lineage": "Drakari",
		"intro": "Veyraen. I have walked the Lament for centuries. What the Enclave has done here is desecration.",
		"sendoff": "May the Titans bear witness. Do not fail them. Good luck."},
	"peaks": {"name": "Edda", "lineage": "Archivist",
		"intro": "Edda, Peaks Liaison. I've cross-referenced every shrine record. The pattern is undeniable.",
		"sendoff": "Knowledge is armor. Stay sharp. Good luck, agent."},
	"sublimini": {"name": "Director Victor Sorn", "lineage": "Regal Human",
		"intro": "Director Sorn, ACF Command. All nine regional nodes have been dismantled. This is the endgame. The entire operation has led here.",
		"sendoff": "Don't make me write the after-action report myself. Good hunting."},
}

# ── Training missions ──────────────────────────────────────────────────────────
# Each entry: [id, title, region, teaser, flavor, xp_reward, is_boss, boss_name, boss_level, boss_apex_idx]
const TRAINING_MISSIONS: Array = [
	["t1", "Training I: Tainted Waters", "Kingdom of Qunorum",
		"Illness is spreading through a Qunorum village. Purify the drinking source and root out who is responsible.",
		"Reports of sickness have reached ACF command. A village well in the Kingdom of Qunorum has been deliberately contaminated. Locate the underground cistern, clear any hostile presence, and purify the water supply. Investigators who came before found strange markings near the well — someone has been here, and they were thorough.",
		80, false, "", 0, -1],
	["t2", "Training II: The Defiled Grotto", "House of Arachana",
		"A cave in the House of Arachana runs foul with corrupted ichor. The same hand that fouled Qunorum's water is at work here.",
		"The spider-silk territories of the House of Arachana report corrupted ichor pooling in the deep grottos. Creatures behave erratically and the web-keepers have retreated. The same strange sigils found in Qunorum mark the cavern walls — a deliberate pattern is emerging. Purify the grotto and confirm what is being done and why.",
		80, false, "", 0, -1],
	["t3", "Training III: The Poisoned Spring", "The Forest of SubEden",
		"A sacred spring in SubEden has turned black. The fae have fled. The Sinister Agent's trail grows clearer.",
		"A spring sacred to the fae of SubEden has been fouled with dark energies. The surrounding forest is dying. The fae will not return until it is cleansed. Commune with the spirits if you can — they have witnessed the agent at work and may know the identity of whoever is orchestrating this.",
		80, false, "", 0, -1],
	["t4", "Training IV: The Heart-Tree", "The Wilds of Endero",
		"The ancient Heart-Tree of Endero is dying. Its roots have been deliberately poisoned. This is the final site before the convergence.",
		"The Heart-Tree of the Wilds of Endero — revered by the Tetrasimian and Cervin lineages for generations — is dying from a corruption laced into its roots. Ritual implements and camp remnants surround it. Purify the tree, destroy the ritual anchors, and recover whatever the agent left behind.",
		80, false, "", 0, -1],
	["t5", "Training V: The Sinister Agent", "Kingdom of Qunorum",
		"Velmara Dusk — a corrupted scholar — has been identified. Return to where it began and stop them before the ritual is complete.",
		"The agent is Velmara Dusk, a corrupted scholar once of the Eternal Library who seeks to destabilize the world's natural anchors to fuel a dark ascension ritual. Each poisoned source was a node in a vast working. The convergence point traces back to Qunorum — where it all began. Your team must confront and stop Velmara Dusk before the final rite is enacted.",
		200, true, "Velmara Dusk", 5, -1],
]

# ── Story sections ─────────────────────────────────────────────────────────────
# Each entry: [section_id, title, badge_name_or_empty, requires_all_badges, missions_array]
# Mission entry: [id, title, region, teaser, flavor, xp, is_boss, boss_name, boss_level, boss_apex_idx]
const STORY_SECTIONS: Array = [
	["plains", "The Plains", "Plains Badge", false, [
		["plains-1", "Plains I: Wilted Wanderers", "The Plains",
			"Fae-touched plants are siphoning memories from Plains villagers. A pattern points toward a deliberate hand.",
			"Farmers across the Plains wake unable to recall their names. Strange root-webs have grown overnight, pulsing with dim light. Local fae report a woman whispering to the plants — a tracker who should not know these lands. Find the source before the harvest completes.",
			100, false, "", 0, -1],
		["plains-2", "Plains II: The Root Network", "The Plains",
			"A memory-harvest network woven through ancient root systems. The Enclave's geometry is unmistakable.",
			"Following the trails of dying crops and forgotten faces, your team has traced the memory-drain to a vast underground root network. Enclave ritual anchors pulse at every node. Destroy the anchors before the harvest feeds back to Sublimini Dominus.",
			100, false, "", 0, -1],
		["plains-boss", "Plains III: The Tracker Revealed", "The Plains",
			"Seraphina Windwalker — Fae-Touched Wilderness Tracker of the Eclipsed Enclave — stands at the convergence point.",
			"Seraphina Windwalker has completed the first node of the Final Rite. She speaks to the roots as though they are kin. She will not stop unless stopped. End her ritual here, in the heart of the Plains.",
			300, true, "Seraphina Windwalker", 5, 14],
	]],
	["shadows", "The Shadows Beneath", "Shadows Beneath Badge", false, [
		["shadows-1", "Shadows I: Voices in the Dark", "The Shadows Beneath",
			"Underground settlements report memory-stealing shadows. No culprit. No trace. Only silence where names once were.",
			"The deep settlements of the Shadows Beneath have been experiencing targeted identity erasure. Witnesses describe shadows that move against the light — and a woman's laughter where there is no woman. ACF agents went missing. Follow the geometric patterns on the tunnel walls.",
			100, false, "", 0, -1],
		["shadows-2", "Shadows II: The Hollow Path", "The Shadows Beneath",
			"Enclave ritual geometry marks every junction. The tunnels are a circuit. Something is being charged.",
			"The tunnel network of the Shadows Beneath has been mapped with Enclave ritual geometry — every crossroads is a node, every dead-end a capacitor. Disable the circuit before it completes its cycle and collapses the identities of everyone in the undercity.",
			100, false, "", 0, -1],
		["shadows-boss", "Shadows III: Blade of Forgotten Names", "The Shadows Beneath",
			"Thalia Darksong — Shadowblade of the Eclipsed Enclave — steps from the dark to protect the circuit's final node.",
			"Thalia Darksong does not speak. She moves through shadow, collects names, and adds them to her silence. She has stolen the identities of three ACF agents before you arrived. You will not give her yours.",
			300, true, "Thalia Darksong", 5, 12],
	]],
	["astral", "The Astral Tear", "Astral Tear Badge", false, [
		["astral-1", "Astral I: Shattered Visions", "The Astral Tear",
			"Travelers through the Astral Tear return without their identities. The planar membrane has begun to fracture.",
			"The Astral Tear was already an unstable crossing. Now it is a weapon. Those who pass through arrive on the other side hollow — no name, no past. The fracture is deliberate. Someone has placed ritual anchors in the planar membrane itself.",
			100, false, "", 0, -1],
		["astral-2", "Astral II: The Weave Unraveling", "The Astral Tear",
			"Void energy seeps through fractured planar seams. The anchor network is almost complete.",
			"The fractured planar membrane of the Astral Tear has become a conduit for Void energy. The anchor network powering it runs across three seam-nodes deep in the metaphysical layer. Destroy them before the full fracture opens and makes the Tear impassable permanently.",
			100, false, "", 0, -1],
		["astral-boss", "Astral III: Oracle of Dissolution", "The Astral Tear",
			"Nirael of the Glass Veil — Oracle of Fractured Timelines — guards the final anchor and speaks in futures that have already passed.",
			"Nirael answered your questions before you asked them. She has been watching this moment in fractured timeline after fractured timeline. In every one, the Tear opens. Prove her wrong.",
			300, true, "Nirael of the Glass Veil", 5, 21],
	]],
	["terminus", "The Terminus Volarus", "Terminus Volarus Badge", false, [
		["terminus-1", "Terminus I: Static in the Sky", "The Terminus Volarus",
			"Unnatural storms have grounded all air travel and severed communication lines across the Terminus.",
			"The sky routes of the Terminus Volarus — lifelines of trade and communication — have gone dark. Crackling static erases messages mid-transmission. The storms form perfect geometric patterns over key relay towers. Someone is conducting them.",
			100, false, "", 0, -1],
		["terminus-2", "Terminus II: The Storm Conductor", "The Terminus Volarus",
			"A ritual lightning-rod network converts storm energy directly into SP. The Choir's coffers are being filled from the sky.",
			"Each tower in the Terminus is a link in a ritual circuit converting storm energy to SP, funneled directly to Sublimini Dominus. Dismantle the network. The Stormclad who built it will not let you do so quietly.",
			100, false, "", 0, -1],
		["terminus-boss", "Terminus III: Tempest of Forgetting", "The Terminus Volarus",
			"Rurik Stormbringer — Elemental Mage of the Eclipsed Enclave — calls down his storm for one final performance.",
			"Rurik strikes dramatic poses and narrates every bolt of lightning. He believes his work is art. Dismantle his masterpiece and end his contribution to the Final Rite.",
			300, true, "Rurik Stormbringer", 5, 15],
	]],
	["glass", "The Glass Passage", "Glass Passage Badge", false, [
		["glass-1", "Glass I: Mirror in the Path", "The Glass Passage",
			"Travelers encounter perfect copies of themselves that speak with their voices — and lead them into traps.",
			"No one who enters the Glass Passage alone returns the same person. The reflections are too perfect. They know things they should not know. The Enclave has layered illusions into the passage's refractive walls as a memory-trap and identity-siphon.",
			100, false, "", 0, -1],
		["glass-2", "Glass II: A Reflection of Nothing", "The Glass Passage",
			"Two illusionists have replaced the passage's true geography with a false reality. Navigating it requires seeing through the lie.",
			"The Vorath Twins have rebuilt the Glass Passage in their own image — an overlapping maze of false terrain and stolen faces. The only path through is to dismantle the illusion anchors placed at three mirror-nodes deep in the false geography.",
			100, false, "", 0, -1],
		["glass-boss", "Glass III: Twin Reflections", "The Glass Passage",
			"Ilyra and Kael Vorath — Mirrorborn dual illusionists — finish each other's sentences and each other's attacks.",
			"They speak in unison. When one moves, the other mirrors it. Their illusions stack into false realities within false realities. Both must be stopped — and only when both fall does the passage become real again.",
			300, true, "Vorath Twins", 5, 17],
	]],
	["isles", "The Isles", "Isles Badge", false, [
		["isles-1", "Isles I: Iron in the Water", "The Isles",
			"Strange mechanical anchors on the seabed are drawing something up — or sending something down.",
			"Fishermen haul up machine-parts instead of fish. Divers report vast metal scaffolding below the surface between the Isles. Enclave sigils run along every strut. Something is being built — or harvested — from the ocean floor.",
			100, false, "", 0, -1],
		["isles-2", "Isles II: The Engine Below", "The Isles",
			"An underwater workshop harvests SP from the ocean's natural currents. It is almost at capacity.",
			"The scaffolding conceals a vast SP-harvesting engine built into an underwater cavern. Gorrim Ironfist has been tinkering with it for months. The ocean's own energy is being siphoned to Sublimini Dominus. Disable it before the transfer completes.",
			100, false, "", 0, -1],
		["isles-boss", "Isles III: The Tinkering Binder", "The Isles",
			"Gorrim Ironfist — Battle Engineer of the Eclipsed Enclave — is still tinkering when you arrive, and does not intend to stop.",
			"Gorrim is deeply annoyed by your interruption. He has seventeen gadgets half-assembled and a very large engine to protect. He will fight you with all of them.",
			300, true, "Gorrim Ironfist", 5, 13],
	]],
	["metro", "The Metropolitan", "Metropolitan Badge", false, [
		["metro-1", "Metro I: The Academic Conspiracy", "The Metropolitan",
			"A prestigious arcane academy has been quietly recruiting students for Enclave rituals. The dean has no memory of approving this.",
			"The most respected arcane academy in the Metropolitan has students it cannot name and classes it cannot explain. Enrollment has doubled. SP reserves have tripled. The Enclave is using the academy's infrastructure to train ritual conduits for the Final Rite.",
			100, false, "", 0, -1],
		["metro-2", "Metro II: City Under Influence", "The Metropolitan",
			"Civic records are being rewritten across the city. Hundreds report memory gaps. The Enclave is preparing an entire city for identity erasure.",
			"The Metropolitan's administrative core has been infiltrated at every level. Records offices report logs written in hands that do not match their scribes. Identity erasure has been slow and surgical — preparing the population for the Rite of Hollow Identity on a city-wide scale.",
			120, false, "", 0, -1],
		["metro-boss", "Metro III: Draconic Reckoning", "The Metropolitan",
			"Zorin Blackscale — Arcane Strategist of the Eclipsed Enclave — has turned the Metropolitan's own arcane infrastructure into his fortress.",
			"Zorin quotes obscure arcane texts while directing city-wide wards and countermeasures against your team. He has transformed the academy's ley-line grid into a combat arena. And then he enters his draconic form.",
			400, true, "Zorin Blackscale", 8, 11],
	]],
	["titans", "The Titan's Lament", "Titan's Lament Badge", false, [
		["titans-1", "Titan I: Chains in the Deep", "The Titan's Lament",
			"Ancient Titan ruins have been disturbed. Ritual chains and arcane anchors litter the sacred sites.",
			"The Titan's Lament has always been a place of mourning — but the mourning has taken a new shape. Enclave chains run between every ruin. The sacred silence of the Titans has been replaced with a low hum of bound SP. Someone is harvesting the grief of an age.",
			100, false, "", 0, -1],
		["titans-2", "Titan II: The Bound Echoes", "The Titan's Lament",
			"The spirits of the Titans are being captured in soul shackles and converted to raw SP. The lament has become a factory.",
			"Morthis the Binder has chained the echo-spirits of the Titans themselves to his collection apparatus. Each bound spirit feeds the Final Rite. The chains must be broken from the inside — which means entering the ruins that no one returns from unchanged.",
			100, false, "", 0, -1],
		["titans-boss", "Titan III: The Last Chain", "The Titan's Lament",
			"Morthis the Binder — Soulbinder Ritualist of the Eclipsed Enclave — mutters the names of the bound Titan spirits as you approach.",
			"Morthis knows each soul he has bound by name. He considers this respectful. He will add your names to the list. His iron chains reach 30 feet in every direction, and he has not slept since the binding began.",
			300, true, "Morthis the Binder", 5, 18],
	]],
	["peaks", "The Peaks of Isolation", "Peaks of Isolation Badge", false, [
		["peaks-1", "Peaks I: The Nameless Pilgrims", "The Peaks of Isolation",
			"Hermits and wanderers of the Peaks have forgotten their names and are walking toward an unknown destination.",
			"The solitary figures who keep the mountain shrines have abandoned their posts, walking downward in silence. They respond to nothing. Their faces are wrong — borrowed expressions, stolen postures. Something is drawing them somewhere, and emptying them as it does.",
			100, false, "", 0, -1],
		["peaks-2", "Peaks II: Masks Among the Stones", "The Peaks of Isolation",
			"The Rite of Hollow Identity has been performed at multiple mountain shrines. Faces have been collected.",
			"Every shrine in the Peaks bears evidence of the Rite of Hollow Identity. Bone-masks carved from the faces of the willing and unwilling alike are stacked at each altar. This is not theft of memory — it is collection. Someone is wearing the faces of the forgotten.",
			100, false, "", 0, -1],
		["peaks-boss", "Peaks III: The Face Collector", "The Peaks of Isolation",
			"Kaelen the Hollow — Identity Thief of the Eclipsed Enclave — wears a different face every time you look at him.",
			"Kaelen speaks in stolen voices and watches you through borrowed eyes. His masks are made from fragments of the people he has unmade. He has been collecting faces for years, and he intends to add yours to his collection.",
			300, true, "Kaelen the Hollow", 5, 19],
	]],
	["sublimini", "Sublimini Dominus", "", true, [
		["sub-1", "Sublimini I: The Threshold", "Sublimini Dominus",
			"Enter Sublimini Dominus through metaphysical resonance. The Culled are everywhere. The Heart is beating.",
			"Sublimini Dominus does not exist on any map. It is reached through metaphysical resonance — a shared frequency with the Beating Heart of the Void. The transition is dreamlike. The geometry is wrong. The Culled patrol in absolute silence. The Final Rite is already underway. Move carefully.",
			200, false, "", 0, -1],
		["sub-2", "Sublimini II: Through the Culled", "Sublimini Dominus",
			"Eighty minds erased into one. The Culled stand between you and the inner sanctum.",
			"The Culled do not speak. They do not remember. They chant in harmonic unison and move as a single organism. Their constant whispering disrupts focus and makes ranged combat unreliable. They must be broken through. All of them.",
			400, true, "The Culled", 16, 10],
		["sub-3", "Sublimini III: Flames and Echoes", "Sublimini Dominus",
			"Korrin of the Forgotten Flame and Veyra's Echo guard the approach to the Beating Heart of the Void.",
			"Korrin converts everything he touches into entropy and fire. Veyra's Echo has no face and no past — she interprets the pulses of the Beating Heart as divine commands. They guard the final approach. They believe what they are doing is mercy. Convince them otherwise, or end the debate.",
			500, true, "Korrin of the Forgotten Flame", 15, 9],
		["sub-final", "Sublimini IV: The Architect of Oblivion", "Sublimini Dominus",
			"High Null Sereth conducts the Final Rite. The Beating Heart of the Void pulses in perfect rhythm with the chant.",
			"High Null Sereth burned his own name from the records of the Eternal Library. He has no name, no past — only the Rite. The Beating Heart pulses beneath you as he channels over 100,000 SP into the vessel that will become The Rewritten. Stop the Rite. Stop the Architect. Stop the Heart. This is the end of what the Choir began.",
			1000, true, "High Null Sereth", 15, 7],
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
		"pos": Vector2(0.70, 0.40),
		"accent": Color(0.60, 0.85, 0.35, 1.0),
		"badge": "Plains Badge",
		"subregions": ["The Plains", "Forest of SubEden", "Kingdom of Qunorum", "Wilds of Endero", "House of Arachana", "Eternal Library"],
		"acf": [
			["acf-plains-outpost", "ACF Plains Outpost", "The Plains",
				"Our regional HQ. Stock up, report findings, pick up Director briefings.", 40, false],
			["acf-subeden-grove", "SubEden Sentinel Grove", "Forest of SubEden",
				"A fae-touched watchpost. Scouts report memory fog rolling through the glades.", 80, false],
			["acf-qunorum-annex", "Qunorum Palace Annex", "Kingdom of Qunorum",
				"Gilded corridors. The Crown's liaison is feeding the Enclave intel — trace the leak.", 120, false],
			["acf-endero-lodge", "Endero Wilds Lodge", "Wilds of Endero",
				"A druidic waystation. Heart-Tree blight is radiating outward in concentric rings.", 120, false],
			["acf-arachana-brood", "Arachana Brood Halls", "House of Arachana",
				"Blood-silk webs. A matriarch brokers souls to the Enclave for safe passage.", 180, false],
			["acf-eternal-library", "Eternal Library Annex", "Eternal Library",
				"Archivists are vanishing with their own indexes. Books breathe now.", 180, false],
		],
	},
	{
		"id": "peaks", "name": "The Peaks of Isolation",
		"flavor": "Windswept spires that swallow names whole.",
		"icon": "🏔",
		"pos": Vector2(0.35, 0.14),
		"accent": Color(0.75, 0.85, 0.95, 1.0),
		"badge": "Peaks of Isolation Badge",
		"subregions": ["Peaks of Isolation", "Pharaoh's Den", "The Darkness", "Arcane Collapse", "Argent Hall"],
		"acf": [
			["acf-peaks-camp", "Cragborn Highwatch", "Peaks of Isolation",
				"A frozen watchtower. Pilgrims ascend with names — none return with them.", 100, false],
			["acf-peaks-shrine", "Shrine of Hollow Identity", "Peaks of Isolation",
				"Where the Rite is performed. Masks line the basalt walls.", 180, false],
			["acf-pharaohs-den", "Pharaoh's Den Dig Site", "Pharaoh's Den",
				"Sand-buried tombs. Enclave expeditions are plundering identity-locks.", 140, false],
			["acf-darkness-threshold", "Threshold of the Dark", "The Darkness",
				"Where light fails. Shades recruit from anyone who arrives alone.", 140, false],
			["acf-arcane-collapse", "Arcane Collapse Breach", "Arcane Collapse",
				"Where magic itself died. Riftborn survivors guard the wound.", 160, false],
			["acf-argent-hall", "Argent Hall Vestibule", "Argent Hall",
				"Silver-veined marble. Lightbound guards test every traveller's reflection.", 120, false],
		],
	},
	{
		"id": "shadows", "name": "The Shadows Beneath",
		"flavor": "The undercity where whispers become laws.",
		"icon": "🕳",
		"pos": Vector2(0.56, 0.22),
		"accent": Color(0.55, 0.35, 0.75, 1.0),
		"badge": "Shadows Beneath Badge",
		"subregions": ["Shadows Beneath", "Corrupted Marshes", "Crypt at End of Valley", "Spindle York's Schism"],
		"acf": [
			["acf-shadows-junction", "Hollow Path Junction", "Shadows Beneath",
				"A convergence of lightless tunnels. The Enclave is wiring it as a ritual circuit.", 120, false],
			["acf-marshes-trail", "Corrupted Marshes Boardwalk", "Corrupted Marshes",
				"Blight creeps up the planks each night. Bogtenders are barely holding.", 140, false],
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
		"subregions": ["Glass Passage", "Sacral Separation", "Infernal Machine"],
		"acf": [
			["acf-glass-midpoint", "Mirrored Midpoint", "Glass Passage",
				"Where the true path diverges from its copy. Do not trust your own footsteps.", 140, false],
			["acf-sacral-rift", "Sacral Separation Rift", "Sacral Separation",
				"Faith splits cleanly here. A seraph's shed flesh warns the rest.", 180, false],
			["acf-infernal-gate", "Infernal Machine Gate", "Infernal Machine",
				"Hellforged sentinels guard a gate that should not exist.", 220, false],
		],
	},
	{
		"id": "isles", "name": "The Isles",
		"flavor": "Salt-kissed archipelagos and drowned workshops.",
		"icon": "🏝",
		"pos": Vector2(0.24, 0.90),
		"accent": Color(0.20, 0.75, 0.85, 1.0),
		"badge": "Isles Badge",
		"subregions": ["Gloamfen Hollow", "The Isles", "Depths of Denorim", "Moroboros"],
		"acf": [
			["acf-isles-harbor", "Tiderunner Harbor", "The Isles",
				"Our floating dock-yard. Smugglers run Enclave cores past the blockade nightly.", 120, false],
			["acf-denorim-depths", "Denorim Deep Shaft", "Depths of Denorim",
				"Pressure-crushed tunnels. Fathomari miners strike bargains with abyssal things.", 160, false],
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
		"pos": Vector2(0.74, 0.48),
		"accent": Color(0.95, 0.80, 0.30, 1.0),
		"badge": "Metropolitan Badge",
		"subregions": ["Metropolitan", "Upper Forty", "Lower Forty"],
		"acf": [
			["acf-metro-plaza", "Metropolitan Central Plaza", "Metropolitan",
				"Civic records are being rewritten in broad daylight. No one notices.", 120, false],
			["acf-upper-forty", "Upper Forty Promenade", "Upper Forty",
				"Gilded balconies. Nobles whisper about memory gaps between cocktails.", 120, false],
			["acf-lower-forty", "Lower Forty Sluice", "Lower Forty",
				"Sewer tunnels. A rustspawn cell runs Enclave logistics from a scrap-den.", 140, false],
		],
	},
	{
		"id": "astral", "name": "The Astral Tear",
		"flavor": "A wound in reality that weeps futures.",
		"icon": "🌌",
		"pos": Vector2(0.78, 0.80),
		"accent": Color(0.70, 0.55, 0.95, 1.0),
		"badge": "Astral Tear Badge",
		"subregions": ["Astral Tear", "L.I.T.O.", "West End Gullet", "Cradling Depths"],
		"acf": [
			["acf-astral-anchor", "Astral Tear Anchor", "Astral Tear",
				"Final anchor point for the weave-unraveling ritual. Nirael walks there already.", 200, true],
			["acf-lito-foundry", "L.I.T.O. Clockwork Foundry", "L.I.T.O.",
				"A city-sized mechanism. Gears the size of cathedrals grind futures to dust.", 200, false],
			["acf-gullet", "West End Gullet Alley", "West End Gullet",
				"Where the city dumps what it can't admit. The gullet mimes run the block.", 120, false],
			["acf-cradling-depths", "Cradling Depths Cistern", "Cradling Depths",
				"Slime-choked under-galleries. A hollowroot network links the sewers citywide.", 160, false],
		],
	},
	{
		"id": "terminus", "name": "The Terminus Volarus",
		"flavor": "Storm-wracked skies where thunder has orders.",
		"icon": "⚡",
		"pos": Vector2(0.86, 0.10),
		"accent": Color(0.45, 0.70, 0.95, 1.0),
		"badge": "Terminus Volarus Badge",
		"subregions": ["Terminus Volarus", "City of Eternal Light", "Land of Tomorrow", "Hallowed Sacrament"],
		"acf": [
			["acf-terminus-rod", "Lightning Rod Array", "Terminus Volarus",
				"A ritual SP-harvester drawing from the storm itself. Rurik commands the array.", 200, true],
			["acf-eternal-light", "City of Eternal Light Beacon", "City of Eternal Light",
				"The beacon never dims — and its keepers never sleep. Something is wrong with both facts.", 180, false],
			["acf-tomorrow-gate", "Gate of Tomorrow", "Land of Tomorrow",
				"A threshold where time runs backwards. Dreamer-priests warn: do not linger.", 240, false],
			["acf-hallowed", "Hallowed Sacrament Reliquary", "Hallowed Sacrament",
				"Soulbinders have infiltrated the reliquary. A convergent prays over an empty seat.", 200, false],
		],
	},
	{
		"id": "titans", "name": "The Titan's Lament",
		"flavor": "Volcanic scar where ancient giants wept iron.",
		"icon": "🌋",
		"pos": Vector2(0.13, 0.64),
		"accent": Color(0.95, 0.50, 0.30, 1.0),
		"badge": "Titan's Lament Badge",
		"subregions": ["Titan's Lament", "Vulcan Valley", "Mortal Arena"],
		"acf": [
			["acf-titan-bound", "Chained Colossus Site", "Titan's Lament",
				"The Last Chain rattles in its socket. Morthis counts the spirit-names.", 220, true],
			["acf-vulcan-forge", "Vulcan Valley Forge", "Vulcan Valley",
				"Volcant smiths hammer soul-iron for the Enclave. Stop the shipments.", 180, false],
			["acf-arena-post", "Arena Command Post", "Mortal Arena",
				"Blood-sands diplomacy. Survive three exhibition bouts to unlock the real investigation.", 160, true],
		],
	},
	{
		"id": "sublimini", "name": "Sublimini Dominus",
		"flavor": "The beating heart of the void. Requires all 9 badges.",
		"icon": "🕳",
		"pos": Vector2(0.50, 0.02),
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

	var tabs = ["Map", "Missions", "Story", "Dungeon", "Crafting", "Foraging", "Rituals", "Base", "Magic", "Quests"]
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
	_build_quests_tab(_content_area)

	# Show the correct tab — if returning from a tab-launched dungeon, go back there;
	# otherwise restore the last sub-tab the player was on.
	var start_tab: int = GameState.world_sub_tab
	if GameState.dungeon_source == "tab":
		start_tab = GameState.dungeon_return_tab
		GameState.dungeon_source = "explore"  # reset so next load starts at Map
	_on_tab_selected(start_tab)

	# Check if a story combat just finished and needs to be resolved
	if GameState.quest_state.has("story_combat_pending_result"):
		var victory: bool = bool(GameState.quest_state["story_combat_pending_result"])
		GameState.quest_state.erase("story_combat_pending_result")
		# Deferred so the UI is fully built before we try to update it
		_on_story_combat_resolved.call_deferred(victory)

func _on_tab_selected(idx: int) -> void:
	current_tab = idx
	GameState.world_sub_tab = idx
	for child in _content_area.get_children():
		child.visible = false
	if idx < _content_area.get_child_count():
		_content_area.get_child(idx).visible = true
	# When showing the overworld map, refresh 3D label positions
	if idx == 0 and _ow_label_overlay != null:
		_overworld_refresh_region_highlights()
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

	# Short rest button
	var mission_rest_row = HBoxContainer.new()
	mission_rest_row.add_theme_constant_override("separation", 8)
	vbox.add_child(mission_rest_row)
	var mission_rest_spacer = Control.new()
	mission_rest_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission_rest_row.add_child(mission_rest_spacer)
	var mission_rest_btn = RimvaleUtils.button(
		"Short Rest (%d/%d)" % [GameState.short_rests_used, GameState.MAX_SHORT_RESTS],
		RimvaleColors.CYAN, 38, 12)
	mission_rest_btn.pressed.connect(func():
		_do_tab_short_rest(mission_rest_btn)
	)
	mission_rest_row.add_child(mission_rest_btn)

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

	# Short rest button
	var story_rest_row = HBoxContainer.new()
	story_rest_row.add_theme_constant_override("separation", 8)
	vbox.add_child(story_rest_row)
	var story_rest_spacer = Control.new()
	story_rest_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_rest_row.add_child(story_rest_spacer)
	var story_rest_btn = RimvaleUtils.button(
		"Short Rest (%d/%d)" % [GameState.short_rests_used, GameState.MAX_SHORT_RESTS],
		RimvaleColors.CYAN, 38, 12)
	story_rest_btn.pressed.connect(func():
		_do_tab_short_rest(story_rest_btn)
	)
	story_rest_row.add_child(story_rest_btn)

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

	# ── Divine Ascension Section ──────────────────────────────────────────────
	vbox.add_child(RimvaleUtils.spacer(4))
	_build_ascension_section(vbox)

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

func _do_tab_short_rest(btn: Button) -> void:
	## Perform a short rest from a mission/story tab and update the button label.
	if GameState.do_short_rest():
		btn.text = "Short Rest (%d/%d)" % [GameState.short_rests_used, GameState.MAX_SHORT_RESTS]
		_show_world_toast("Short rest taken — team partially restored. (%d/%d)" % [
			GameState.short_rests_used, GameState.MAX_SHORT_RESTS])
	else:
		_show_world_toast("All 3 short rests used! Take a long rest first.")

func _show_world_toast(msg: String) -> void:
	var toast: PanelContainer = RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.ACCENT, 12, 14)
	var lbl: Label = RimvaleUtils.label(msg, 14, RimvaleColors.TEXT_WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_child(lbl)
	toast.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast.offset_bottom = -60
	toast.offset_top = -110
	toast.offset_left = 40
	toast.offset_right = -40
	add_child(toast)
	get_tree().create_timer(2.5).timeout.connect(func():
		if is_instance_valid(toast):
			toast.queue_free()
	)

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
	# m_data: [id, title, region, teaser, flavor, xp, is_boss, boss_name, boss_level, boss_apex_idx]
	var mid: String     = m_data[0]
	var mtitle: String  = m_data[1]
	var mregion: String = m_data[2]
	var mteaser: String = m_data[3]
	var mxp: int        = m_data[5]
	var is_boss: bool   = m_data[6]
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
	var cap_m_data: Array = m_data.duplicate()
	play_btn.pressed.connect(func():
		_on_story_mission_play(cap_m_data))
	right_vbox.add_child(play_btn)

	# Debug auto-complete button
	if GameState.debug_mode and not completed:
		var auto_btn = RimvaleUtils.button("Auto ⚡", RimvaleColors.WARNING, 24, 10)
		auto_btn.custom_minimum_size = Vector2(60, 24)
		auto_btn.tooltip_text = "Auto-complete for 10,000 gold"
		var cap_mid: String = mid
		var cap_mxp: int = mxp
		auto_btn.pressed.connect(func():
			_debug_auto_complete_mission(cap_mid, cap_mxp)
		)
		right_vbox.add_child(auto_btn)

	return row

func _build_ascension_section(parent: Control) -> void:
	var ascension_card = PanelContainer.new()
	ascension_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.08, 0.16, 1.0)
	card_style.content_margin_left = 10; card_style.content_margin_right = 10
	card_style.content_margin_top = 8; card_style.content_margin_bottom = 8
	ascension_card.add_theme_stylebox_override("panel", card_style)
	parent.add_child(ascension_card)

	var cvbox = VBoxContainer.new()
	cvbox.add_theme_constant_override("separation", 8)
	ascension_card.add_child(cvbox)

	# Header
	var hdr = HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	cvbox.add_child(hdr)
	hdr.add_child(RimvaleUtils.label("✦", 16, Color(0.8, 0.4, 1.0)))
	hdr.add_child(RimvaleUtils.label("Divine Ascension", 14, RimvaleColors.TEXT_WHITE))

	cvbox.add_child(RimvaleUtils.separator())

	if GameState.ascension_path.is_empty():
		# Path selection view
		cvbox.add_child(RimvaleUtils.label(
			"Choose a path to divine ascension. Your choice will shape your destiny.",
			11, RimvaleColors.TEXT_DIM))
		cvbox.add_child(RimvaleUtils.spacer(4))

		var paths: Dictionary = _WS.ASCENSION_PATHS
		for path_name in ["Unity", "Chaos", "Void"]:
			if not paths.has(path_name): continue
			var path_data: Dictionary = paths[path_name]
			var path_card = PanelContainer.new()
			path_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var path_style = StyleBoxFlat.new()
			path_style.bg_color = Color(0.08, 0.08, 0.12, 1.0)
			path_style.content_margin_left = 8; path_style.content_margin_right = 8
			path_style.content_margin_top = 6; path_style.content_margin_bottom = 6
			path_card.add_theme_stylebox_override("panel", path_style)
			cvbox.add_child(path_card)

			var path_vbox = VBoxContainer.new()
			path_vbox.add_theme_constant_override("separation", 4)
			path_card.add_child(path_vbox)

			path_vbox.add_child(RimvaleUtils.label(
				path_name, 12, RimvaleColors.ACCENT))
			var desc_lbl = RimvaleUtils.label(
				str(path_data.get("desc", "")), 10, RimvaleColors.TEXT_GRAY)
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			path_vbox.add_child(desc_lbl)

			var choose_btn = RimvaleUtils.button(
				"Choose " + path_name, RimvaleColors.ACCENT, 40, 11)
			var cap_path: String = path_name
			choose_btn.pressed.connect(func():
				GameState.ascension_path = cap_path
				GameState.save_game()
				_rebuild_story_sections()  # Triggers UI refresh
			)
			path_vbox.add_child(choose_btn)
	else:
		# Active path view
		cvbox.add_child(RimvaleUtils.label(
			"Path: " + GameState.ascension_path, 12, RimvaleColors.GOLD))
		cvbox.add_child(RimvaleUtils.spacer(2))

		var paths: Dictionary = _WS.ASCENSION_PATHS
		var path_data: Dictionary = paths.get(GameState.ascension_path, {})
		var milestones: Array = path_data.get("milestones", [])
		var tasks: Array = path_data.get("tasks", [])

		# Milestone progress
		if not milestones.is_empty():
			cvbox.add_child(RimvaleUtils.label("Milestones:", 11, RimvaleColors.TEXT_WHITE))
			for i in range(milestones.size()):
				var milestone: String = str(milestones[i])
				var completed: bool = i < GameState.ascension_progress
				var color: Color = RimvaleColors.GOLD if completed else RimvaleColors.TEXT_DIM
				var icon: String = "✓" if completed else "○"
				cvbox.add_child(RimvaleUtils.label(
					icon + " " + milestone, 10, color))

		cvbox.add_child(RimvaleUtils.spacer(2))

		# Progress bar
		var progress_bar = ProgressBar.new()
		progress_bar.custom_minimum_size = Vector2(0, 24)
		progress_bar.value = minf(float(GameState.ascension_progress) / maxf(1.0, float(milestones.size())), 1.0) * 100.0
		var bar_style = StyleBoxFlat.new()
		bar_style.bg_color = Color(0.2, 0.2, 0.25)
		progress_bar.add_theme_stylebox_override("background", bar_style)
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = Color(0.8, 0.4, 1.0)
		progress_bar.add_theme_stylebox_override("fill", fill_style)
		progress_bar.show_percentage = true
		cvbox.add_child(progress_bar)

		# Tasks
		if not tasks.is_empty():
			cvbox.add_child(RimvaleUtils.spacer(2))
			cvbox.add_child(RimvaleUtils.label("Tasks for current milestone:", 11, RimvaleColors.TEXT_WHITE))
			for task in tasks:
				var task_str: String = str(task)
				cvbox.add_child(RimvaleUtils.label("• " + task_str, 10, RimvaleColors.TEXT_GRAY))

		# Advance button
		if GameState.ascension_progress < milestones.size():
			cvbox.add_child(RimvaleUtils.spacer(2))
			var advance_btn = RimvaleUtils.button(
				"Advance to Next Milestone", RimvaleColors.GOLD, 40, 12)
			advance_btn.pressed.connect(func():
				var milestone: String = GameState.advance_ascension()
				if not milestone.is_empty():
					_rebuild_story_sections()  # Refresh UI
			)
			cvbox.add_child(advance_btn)
		else:
			cvbox.add_child(RimvaleUtils.spacer(2))
			cvbox.add_child(RimvaleUtils.label(
				"Ascension Complete! You have become a god.", 12, RimvaleColors.GOLD))

# ══════════════════════════════════════════════════════════════════════════════
#  STORY MISSION SYSTEM — Contact Dialogue + Quest Execution + Combat
# ══════════════════════════════════════════════════════════════════════════════

# Challenge grid: stat_id, stat_name, skill_id, skill_name per (part, challenge)
const CHALLENGE_GRID: Array = [
	# Part 1
	[[1, "Speed",     8,  "Nimble"],
	 [3, "Vitality",  4,  "Exertion"],
	 [0, "Strength", 13,  "Survival"]],
	# Part 2
	[[2, "Intellect", 6,  "Learnedness"],
	 [1, "Speed",    11,  "Sneak"],
	 [4, "Divinity",  0,  "Arcane"]],
	# Part 3
	[[0, "Strength",  4,  "Exertion"],
	 [2, "Intellect", 5,  "Intuition"],
	 [3, "Vitality", 13,  "Survival"]],
]

## Called when a story mission "Begin" / "Replay" button is pressed.
func _on_story_mission_play(m_data: Array) -> void:
	var party: Array = GameState.get_active_handles()
	if party.is_empty():
		push_warning("[Story] No active party")
		return

	# Find which section this mission belongs to (for contact lookup)
	var section_id: String = ""
	for sec in STORY_SECTIONS:
		for m in sec[4]:
			if m[0] == m_data[0]:
				section_id = sec[0]; break
		if not section_id.is_empty(): break
	if section_id.is_empty():
		# Check training missions
		for m in TRAINING_MISSIONS:
			if m[0] == m_data[0]:
				section_id = "training"; break

	# Show contact dialogue on first play (if contact exists and not yet shown)
	var mid: String = m_data[0]
	if mid not in GameState.story_shown_contacts and section_id in STORY_CONTACTS:
		_show_contact_dialogue(section_id, m_data)
		return

	# Otherwise go directly to mission execution
	_start_quest_execution(m_data)

# ── Contact Dialogue Modal ────────────────────────────────────────────────────

func _show_contact_dialogue(section_id: String, m_data: Array) -> void:
	var contact: Dictionary = STORY_CONTACTS[section_id]
	var mid: String = m_data[0]

	var overlay = PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.85)
	overlay.add_theme_stylebox_override("panel", bg_style)
	add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(440, 0)
	var card_s = StyleBoxFlat.new()
	card_s.bg_color = Color(0.10, 0.08, 0.16, 1.0)
	card_s.corner_radius_top_left = 8; card_s.corner_radius_top_right = 8
	card_s.corner_radius_bottom_left = 8; card_s.corner_radius_bottom_right = 8
	card_s.content_margin_left = 20; card_s.content_margin_right = 20
	card_s.content_margin_top = 16; card_s.content_margin_bottom = 16
	card_s.border_width_top = 2; card_s.border_color = Color(0.45, 0.35, 0.70)
	card.add_theme_stylebox_override("panel", card_s)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	# Contact name + lineage
	var name_lbl = RimvaleUtils.label(contact["name"], 16, Color(0.85, 0.75, 1.0))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)
	var lineage_lbl = RimvaleUtils.label(contact["lineage"], 11, RimvaleColors.TEXT_GRAY)
	lineage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lineage_lbl)

	vbox.add_child(HSeparator.new())

	# Intro line
	var intro_lbl = RimvaleUtils.label(contact["intro"], 12, RimvaleColors.TEXT_WHITE)
	intro_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(intro_lbl)

	vbox.add_child(HSeparator.new())

	# Mission teaser in italics
	var teaser_lbl = RimvaleUtils.label(
		"\"%s\"" % m_data[3], 11, Color(0.70, 0.70, 0.80))
	teaser_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(teaser_lbl)

	vbox.add_child(HSeparator.new())

	# Sendoff
	var sendoff_lbl = RimvaleUtils.label(contact["sendoff"], 12, Color(0.90, 0.85, 0.70))
	sendoff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(sendoff_lbl)

	# Buttons
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var cancel_btn = RimvaleUtils.button("Cancel", RimvaleColors.TEXT_GRAY, 36, 12)
	cancel_btn.custom_minimum_size = Vector2(100, 36)
	var cap_overlay = overlay
	cancel_btn.pressed.connect(func(): cap_overlay.queue_free())
	btn_row.add_child(cancel_btn)

	var deploy_btn = RimvaleUtils.button("Deploy", RimvaleColors.ACCENT, 36, 12)
	deploy_btn.custom_minimum_size = Vector2(100, 36)
	var cap_mid = mid; var cap_m_data = m_data.duplicate()
	deploy_btn.pressed.connect(func():
		GameState.story_shown_contacts.append(cap_mid)
		cap_overlay.queue_free()
		_start_quest_execution(cap_m_data)
	)
	btn_row.add_child(deploy_btn)

# ── Quest Execution Screen ────────────────────────────────────────────────────

func _start_quest_execution(m_data: Array) -> void:
	var mid: String      = m_data[0]
	var mtitle: String   = m_data[1]
	var mregion: String  = m_data[2]
	var mflavor: String  = m_data[4]
	var mxp: int         = m_data[5]
	var is_boss: bool    = m_data[6]
	var boss_name: String = m_data[7] if m_data.size() > 7 else ""
	var boss_level: int  = m_data[8] if m_data.size() > 8 else 0
	var boss_apex: int   = m_data[9] if m_data.size() > 9 else -1

	_story_exec_mission = {
		"id": mid, "title": mtitle, "region": mregion, "flavor": mflavor,
		"xp": mxp, "is_boss": is_boss, "boss_name": boss_name,
		"boss_level": boss_level, "boss_apex": boss_apex,
	}

	# Boss missions skip straight to combat
	if is_boss:
		_story_exec_quest = {
			"part": 3, "challenge": 3, "progress": 100,
			"log": [
				"Mission control online. Team deployed to %s." % mregion,
				mflavor,
				"HOSTILE CONTACT: %s detected. Engage." % boss_name,
			],
			"agent_handle": 0, "waiting_combat": true, "combat_action": "FINISH",
			"last_combat_result": -1, "completed": false,
		}
	else:
		_story_exec_quest = {
			"part": 1, "challenge": 1, "progress": 0,
			"log": [
				"Mission control online. Team deployed to %s." % mregion,
				mflavor,
			],
			"agent_handle": 0, "waiting_combat": false, "combat_action": "",
			"last_combat_result": -1, "completed": false,
		}

	_build_quest_execution_overlay()

func _build_quest_execution_overlay() -> void:
	if _story_exec_overlay != null:
		_story_exec_overlay.queue_free()

	_story_exec_overlay = PanelContainer.new()
	_story_exec_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.04, 0.10, 1.0)
	_story_exec_overlay.add_theme_stylebox_override("panel", bg)
	add_child(_story_exec_overlay)

	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	_story_exec_overlay.add_child(main_vbox)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_story_exec_overlay.add_child(margin)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	# ── Header card ──
	var hdr_card = PanelContainer.new()
	hdr_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hdr_s = StyleBoxFlat.new()
	hdr_s.bg_color = Color(0.10, 0.10, 0.16, 1.0)
	hdr_s.corner_radius_top_left = 6; hdr_s.corner_radius_top_right = 6
	hdr_s.corner_radius_bottom_left = 6; hdr_s.corner_radius_bottom_right = 6
	hdr_s.content_margin_left = 12; hdr_s.content_margin_right = 12
	hdr_s.content_margin_top = 8; hdr_s.content_margin_bottom = 8
	hdr_card.add_theme_stylebox_override("panel", hdr_s)
	content.add_child(hdr_card)

	var hdr_vbox = VBoxContainer.new()
	hdr_vbox.add_theme_constant_override("separation", 4)
	hdr_card.add_child(hdr_vbox)

	_story_exec_header_lbl = RimvaleUtils.label(
		_story_exec_mission["title"], 14, RimvaleColors.TEXT_WHITE)
	hdr_vbox.add_child(_story_exec_header_lbl)

	var prog_row = HBoxContainer.new()
	prog_row.add_theme_constant_override("separation", 8)
	hdr_vbox.add_child(prog_row)

	_story_exec_progress_lbl = RimvaleUtils.label("Part 1/3 | Challenge 1/3", 10, RimvaleColors.CYAN)
	prog_row.add_child(_story_exec_progress_lbl)
	var sp_h = Control.new(); sp_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog_row.add_child(sp_h)
	var pct_lbl = RimvaleUtils.label("0%", 10, RimvaleColors.TEXT_WHITE)
	prog_row.add_child(pct_lbl)

	_story_exec_progress_bar = ProgressBar.new()
	_story_exec_progress_bar.min_value = 0; _story_exec_progress_bar.max_value = 100
	_story_exec_progress_bar.value = 0
	_story_exec_progress_bar.custom_minimum_size = Vector2(0, 6)
	_story_exec_progress_bar.show_percentage = false
	hdr_vbox.add_child(_story_exec_progress_bar)

	# ── Team status bar ──
	_story_exec_team_hbox = HBoxContainer.new()
	_story_exec_team_hbox.add_theme_constant_override("separation", 6)
	content.add_child(_story_exec_team_hbox)
	_refresh_team_status()

	# ── Mission log ──
	var log_card = PanelContainer.new()
	log_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var log_s = StyleBoxFlat.new()
	log_s.bg_color = Color(0.08, 0.06, 0.12, 1.0)
	log_s.corner_radius_top_left = 4; log_s.corner_radius_top_right = 4
	log_s.corner_radius_bottom_left = 4; log_s.corner_radius_bottom_right = 4
	log_s.content_margin_left = 8; log_s.content_margin_right = 8
	log_s.content_margin_top = 6; log_s.content_margin_bottom = 6
	log_card.add_theme_stylebox_override("panel", log_s)
	content.add_child(log_card)

	var log_scroll = ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_card.add_child(log_scroll)

	_story_exec_log_rtl = RichTextLabel.new()
	_story_exec_log_rtl.bbcode_enabled = true
	_story_exec_log_rtl.fit_content = true
	_story_exec_log_rtl.scroll_active = false
	_story_exec_log_rtl.add_theme_font_size_override("normal_font_size", 11)
	_story_exec_log_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_scroll.add_child(_story_exec_log_rtl)

	# ── Action area ──
	_story_exec_action_vbox = VBoxContainer.new()
	_story_exec_action_vbox.add_theme_constant_override("separation", 6)
	_story_exec_action_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_story_exec_action_vbox)

	# ── Bottom row: Short Rest + Abort ──
	var bottom_row = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 8)
	bottom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(bottom_row)

	var exec_rest_btn = RimvaleUtils.button(
		"Short Rest (%d/%d)" % [GameState.short_rests_used, GameState.MAX_SHORT_RESTS],
		RimvaleColors.CYAN, 28, 11)
	exec_rest_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exec_rest_btn.pressed.connect(func():
		_do_tab_short_rest(exec_rest_btn)
		_refresh_team_status()
	)
	bottom_row.add_child(exec_rest_btn)

	var abort_btn = RimvaleUtils.button("Abort Mission", Color(0.80, 0.20, 0.20), 28, 11)
	abort_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	abort_btn.pressed.connect(_on_story_abort)
	bottom_row.add_child(abort_btn)

	_refresh_quest_ui()

func _refresh_team_status() -> void:
	if _story_exec_team_hbox == null: return
	for c in _story_exec_team_hbox.get_children():
		c.queue_free()
	_story_exec_agent_bars.clear()

	var party: Array = GameState.get_active_handles()
	for ph in party:
		var name_str: String = RimvaleAPI.engine.get_character_name(ph)
		var hp: int = RimvaleAPI.engine.get_character_hp(ph)
		var max_hp: int = RimvaleAPI.engine.get_character_max_hp(ph)
		var sp: int = RimvaleAPI.engine.get_character_sp(ph)
		var max_sp: int = RimvaleAPI.engine.get_character_max_sp(ph)

		var agent_card = PanelContainer.new()
		agent_card.custom_minimum_size = Vector2(70, 50)
		var ac_s = StyleBoxFlat.new()
		var is_sel: bool = _story_exec_quest.get("agent_handle", 0) == ph
		ac_s.bg_color = Color(0.15, 0.18, 0.28, 1.0)
		if is_sel:
			ac_s.border_width_top = 2; ac_s.border_width_bottom = 2
			ac_s.border_width_left = 2; ac_s.border_width_right = 2
			ac_s.border_color = RimvaleColors.ACCENT
		ac_s.corner_radius_top_left = 4; ac_s.corner_radius_top_right = 4
		ac_s.corner_radius_bottom_left = 4; ac_s.corner_radius_bottom_right = 4
		ac_s.content_margin_left = 4; ac_s.content_margin_right = 4
		ac_s.content_margin_top = 3; ac_s.content_margin_bottom = 3
		agent_card.add_theme_stylebox_override("panel", ac_s)

		var avbox = VBoxContainer.new()
		avbox.add_theme_constant_override("separation", 2)
		agent_card.add_child(avbox)

		var nlbl = RimvaleUtils.label(name_str, 9, RimvaleColors.TEXT_WHITE)
		nlbl.clip_text = true
		avbox.add_child(nlbl)

		# HP bar
		var hp_bar = ProgressBar.new()
		hp_bar.min_value = 0; hp_bar.max_value = maxi(max_hp, 1)
		hp_bar.value = hp; hp_bar.show_percentage = false
		hp_bar.custom_minimum_size = Vector2(0, 4)
		var hp_sb = StyleBoxFlat.new(); hp_sb.bg_color = Color(0.80, 0.20, 0.20)
		hp_sb.corner_radius_top_left = 1; hp_sb.corner_radius_top_right = 1
		hp_sb.corner_radius_bottom_left = 1; hp_sb.corner_radius_bottom_right = 1
		hp_bar.add_theme_stylebox_override("fill", hp_sb)
		avbox.add_child(hp_bar)

		# SP bar
		var sp_bar = ProgressBar.new()
		sp_bar.min_value = 0; sp_bar.max_value = maxi(max_sp, 1)
		sp_bar.value = sp; sp_bar.show_percentage = false
		sp_bar.custom_minimum_size = Vector2(0, 4)
		var sp_sb = StyleBoxFlat.new(); sp_sb.bg_color = Color(0.20, 0.40, 0.90)
		sp_sb.corner_radius_top_left = 1; sp_sb.corner_radius_top_right = 1
		sp_sb.corner_radius_bottom_left = 1; sp_sb.corner_radius_bottom_right = 1
		sp_bar.add_theme_stylebox_override("fill", sp_sb)
		avbox.add_child(sp_bar)

		_story_exec_agent_bars[ph] = {"card": agent_card, "name": nlbl, "hp": hp_bar, "sp": sp_bar}
		_story_exec_team_hbox.add_child(agent_card)

func _refresh_quest_ui() -> void:
	if _story_exec_action_vbox == null: return
	for c in _story_exec_action_vbox.get_children():
		c.queue_free()

	var q: Dictionary = _story_exec_quest
	var part: int = q.get("part", 1)
	var chal: int = q.get("challenge", 1)
	var prog: int = q.get("progress", 0)

	# Update header
	if _story_exec_progress_lbl:
		_story_exec_progress_lbl.text = "Part %d/3 | Challenge %d/3" % [part, chal]
	if _story_exec_progress_bar:
		_story_exec_progress_bar.value = prog

	# Update log
	_refresh_mission_log()

	# Refresh team highlights
	_refresh_team_status()

	# ── Determine what action to show ──
	if q.get("completed", false):
		# Mission complete — show debrief button
		var done_btn = RimvaleUtils.button(
			"Mission Debrief & Rewards", Color(0.30, 0.70, 0.30), 40, 13)
		done_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		done_btn.pressed.connect(_on_story_mission_complete)
		_story_exec_action_vbox.add_child(done_btn)

	elif q.get("waiting_combat", false):
		# Waiting for combat — show engage button
		var combat_card = PanelContainer.new()
		combat_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cc_s = StyleBoxFlat.new()
		cc_s.bg_color = Color(0.30, 0.12, 0.12, 1.0)
		cc_s.corner_radius_top_left = 4; cc_s.corner_radius_top_right = 4
		cc_s.corner_radius_bottom_left = 4; cc_s.corner_radius_bottom_right = 4
		cc_s.content_margin_left = 12; cc_s.content_margin_right = 12
		cc_s.content_margin_top = 8; cc_s.content_margin_bottom = 8
		combat_card.add_theme_stylebox_override("panel", cc_s)

		var cc_hbox = HBoxContainer.new()
		cc_hbox.add_theme_constant_override("separation", 8)
		combat_card.add_child(cc_hbox)
		cc_hbox.add_child(RimvaleUtils.label("⚔ Hostile presence detected.", 12, Color(0.90, 0.50, 0.50)))

		_story_exec_action_vbox.add_child(combat_card)

		var engage_btn = RimvaleUtils.button("Engage in Combat", RimvaleColors.DANGER, 40, 13)
		engage_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		engage_btn.pressed.connect(_on_story_trigger_combat)
		_story_exec_action_vbox.add_child(engage_btn)

	elif q.get("last_combat_result", -1) != -1:
		# Just returned from combat — show continue/regroup
		var success: bool = q.get("last_combat_result", 0) == 1
		var cont_btn: Button
		if success:
			cont_btn = RimvaleUtils.button(
				"Combat Won: Continue Mission", Color(0.30, 0.70, 0.30), 40, 13)
		else:
			cont_btn = RimvaleUtils.button(
				"Combat Failed: Regroup", Color(0.50, 0.50, 0.50), 40, 13)
		cont_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cont_btn.pressed.connect(_on_story_continue_after_combat)
		_story_exec_action_vbox.add_child(cont_btn)

	elif q.get("agent_handle", 0) == 0:
		# Need to select an agent
		_story_exec_action_vbox.add_child(RimvaleUtils.label(
			"Deploy Agent for Challenge:", 13, RimvaleColors.TEXT_WHITE))

		var agent_row = HBoxContainer.new()
		agent_row.add_theme_constant_override("separation", 4)
		_story_exec_action_vbox.add_child(agent_row)

		var party: Array = GameState.get_active_handles()
		for ph in party:
			var aname: String = RimvaleAPI.engine.get_character_name(ph)
			var ahp: int = RimvaleAPI.engine.get_character_hp(ph)
			var btn = RimvaleUtils.button(aname, RimvaleColors.ACCENT, 36, 11)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 36)
			btn.disabled = (ahp <= 0)
			var cap_ph = ph; var cap_name = aname
			btn.pressed.connect(func():
				_story_exec_quest["agent_handle"] = cap_ph
				_add_log_entry("Agent %s deployed." % cap_name)
				_refresh_quest_ui()
			)
			agent_row.add_child(btn)

	elif _story_exec_is_rolling:
		# Rolling animation
		_story_exec_action_vbox.add_child(RimvaleUtils.label(
			"Rolling...", 14, RimvaleColors.GOLD))

	else:
		# Ready to roll — show skill check button
		var p: int = part - 1; var c: int = chal - 1
		if p < 0 or p >= CHALLENGE_GRID.size(): p = 0
		if c < 0 or c >= CHALLENGE_GRID[p].size(): c = 0
		var grid_entry: Array = CHALLENGE_GRID[p][c]
		var stat_name: String = grid_entry[1]
		var skill_name: String = grid_entry[3]

		var roll_btn = RimvaleUtils.button(
			"Roll %s (%s)" % [skill_name, stat_name], RimvaleColors.ACCENT, 40, 13)
		roll_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		roll_btn.pressed.connect(_on_story_roll_check)
		_story_exec_action_vbox.add_child(roll_btn)

func _refresh_mission_log() -> void:
	if _story_exec_log_rtl == null: return
	var log_arr: Array = _story_exec_quest.get("log", [])
	var text: String = ""
	for i in range(log_arr.size() - 1, -1, -1):
		text += str(log_arr[i]) + "\n"
	_story_exec_log_rtl.text = text

func _add_log_entry(msg: String) -> void:
	var log_arr: Array = _story_exec_quest.get("log", [])
	log_arr.append(msg)
	_story_exec_quest["log"] = log_arr
	_refresh_mission_log()

# ── Skill Check Roll ──────────────────────────────────────────────────────────

func _on_story_roll_check() -> void:
	if _story_exec_is_rolling: return
	_story_exec_is_rolling = true
	_refresh_quest_ui()

	# Defer the actual roll so the UI can show "Rolling..."
	var timer = get_tree().create_timer(0.6)
	timer.timeout.connect(_execute_skill_check)

func _execute_skill_check() -> void:
	_story_exec_is_rolling = false
	var q: Dictionary = _story_exec_quest
	var part: int = q.get("part", 1)
	var chal: int = q.get("challenge", 1)
	var handle: int = q.get("agent_handle", 0)

	var p: int = part - 1; var c: int = chal - 1
	if p < 0 or p >= CHALLENGE_GRID.size(): p = 0
	if c < 0 or c >= CHALLENGE_GRID[p].size(): c = 0
	var grid_entry: Array = CHALLENGE_GRID[p][c]
	var stat_id: int = grid_entry[0]
	var stat_name: String = grid_entry[1]
	var skill_id: int = grid_entry[2]
	var skill_name: String = grid_entry[3]

	var agent_name: String = RimvaleAPI.engine.get_character_name(handle)

	# Roll: d20 + base_stat + intellect + skill_rank
	var base_stat: int = RimvaleAPI.engine.get_character_stat(handle, stat_id)
	var intel_stat: int = RimvaleAPI.engine.get_character_stat(handle, 2)
	var skill_rank: int = RimvaleAPI.engine.get_character_skill(handle, skill_id)
	var die_roll: int = randi_range(1, 20)
	var total_mod: int = base_stat + intel_stat + skill_rank
	var roll_total: int = die_roll + total_mod
	var check_index: int = (part - 1) * 3 + (chal - 1)   # 0–8
	var dc: int = mini(10 + check_index * 2, 20)

	var roll_detail: String = "(%d + %d = %d vs DC %d)" % [die_roll, total_mod, roll_total, dc]

	if roll_total >= dc:
		# Success — advance
		var msg: String = "[color=#88dd88]SUCCESS: %s passed %s %s[/color]" % [agent_name, skill_name, roll_detail]
		_add_log_entry(msg)

		var next_part: int = part
		var next_chal: int = chal
		if next_chal < 3:
			next_chal += 1
		elif next_part < 3:
			next_part += 1; next_chal = 1

		var new_prog: int = int(((next_part - 1) * 3 + (next_chal - 1)) / 9.0 * 100.0)
		q["part"] = next_part; q["challenge"] = next_chal; q["progress"] = new_prog
		if next_chal == 1:
			q["agent_handle"] = 0  # reset agent selection for new part

		# Check if we just completed part 3 challenge 3 successfully
		if next_part == 3 and next_chal == 3 and part == 3 and chal == 3:
			_add_log_entry("[color=gold]FINAL CONFRONTATION INITIATED.[/color]")
			q["progress"] = 100
			q["waiting_combat"] = true
			q["combat_action"] = "FINISH"
	else:
		# Failure — trigger combat
		var msg: String = "[color=#dd8888]FAILURE: %s failed %s %s — COMBAT![/color]" % [agent_name, skill_name, roll_detail]
		_add_log_entry(msg)
		q["waiting_combat"] = true
		q["combat_action"] = "PROCEED"

	_refresh_quest_ui()

# ── Combat Integration ────────────────────────────────────────────────────────

func _on_story_trigger_combat() -> void:
	var q: Dictionary = _story_exec_quest
	var m: Dictionary = _story_exec_mission
	var party: Array = GameState.get_active_handles()
	if party.is_empty(): return

	var boss_apex: int = m.get("boss_apex", -1)
	var boss_level: int = m.get("boss_level", 0)
	var is_boss: bool = m.get("is_boss", false)
	var difficulty: int = q.get("part", 1) * 2

	# Hide the execution overlay while in combat
	if _story_exec_overlay:
		_story_exec_overlay.visible = false

	# Ensure all ritual spells are registered before entering dungeon
	GameState.ensure_ritual_spells_registered()

	if is_boss and boss_apex >= 0:
		# Boss fight — use apex encounter
		RimvaleAPI.engine.start_apex_dungeon(party, boss_apex, 0)
	else:
		# Standard combat from failed skill check
		RimvaleAPI.engine.start_dungeon(party, difficulty, 0, 0)

	# Mark source so dungeon returns to world scene (Story tab) not explore
	GameState.dungeon_source = "tab"
	GameState.dungeon_return_tab = 2  # Story tab index
	# Persist full quest + mission state so the fresh world scene can restore
	GameState.quest_state["story_combat_active"] = true
	GameState.quest_state["exec_quest"] = _story_exec_quest.duplicate()
	GameState.quest_state["exec_mission"] = _story_exec_mission.duplicate()

	# Push dungeon as a full-screen overlay through the main shell
	var main = get_parent().get_parent() if get_parent() else null
	if main and main.has_method("push_screen"):
		main.push_screen("res://scenes/dungeon/dungeon.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/dungeon/dungeon.tscn")

## Called by dungeon scene when combat concludes during a story mission
func _on_story_combat_resolved(victory: bool) -> void:
	GameState.quest_state["story_combat_active"] = false

	# After pop_screen, this is a FRESH world scene instance — restore state
	if _story_exec_overlay == null:
		var saved_q: Dictionary = GameState.quest_state.get("exec_quest", {})
		var saved_m: Dictionary = GameState.quest_state.get("exec_mission", {})
		if saved_q.is_empty() or saved_m.is_empty():
			push_warning("Story combat resolved but no saved quest state found.")
			return
		_story_exec_mission = saved_m
		_story_exec_quest = saved_q
		_build_quest_execution_overlay()

	if _story_exec_overlay:
		_story_exec_overlay.visible = true

	var q: Dictionary = _story_exec_quest
	if victory:
		_add_log_entry("[color=#88dd88]Engagement successful. Area secured.[/color]")
		q["last_combat_result"] = 1
	else:
		_add_log_entry("[color=#dd8888]Agents forced to retreat.[/color]")
		q["last_combat_result"] = 0
	q["waiting_combat"] = false

	_refresh_quest_ui()

func _on_story_continue_after_combat() -> void:
	var q: Dictionary = _story_exec_quest
	var result: int = q.get("last_combat_result", 0)
	q["last_combat_result"] = -1

	if result == 1:
		# Won combat
		if q.get("combat_action", "") == "FINISH":
			q["completed"] = true
		else:
			# Advance past the failed challenge
			var next_part: int = q.get("part", 1)
			var next_chal: int = q.get("challenge", 1)
			if next_chal < 3:
				next_chal += 1
			elif next_part < 3:
				next_part += 1; next_chal = 1
			q["part"] = next_part; q["challenge"] = next_chal
			q["progress"] = int(((next_part - 1) * 3 + (next_chal - 1)) / 9.0 * 100.0)
			if next_chal == 1:
				q["agent_handle"] = 0
	else:
		# Lost combat — can retry the challenge
		q["waiting_combat"] = false

	_refresh_quest_ui()

# ── Mission Completion ────────────────────────────────────────────────────────

func _on_story_mission_complete() -> void:
	var m: Dictionary = _story_exec_mission
	var mid: String = m.get("id", "")
	var mxp: int = m.get("xp", 0)
	var already_done: bool = mid in GameState.story_completed_missions
	var xp_award: int = maxi(1, mxp / 10) if already_done else mxp

	var party: Array = GameState.get_active_handles()
	for ph in party:
		RimvaleAPI.engine.add_xp(ph, xp_award, 20)

	if not already_done:
		GameState.story_completed_missions.append(mid)

	_check_and_award_story_badges()

	# Persist completion state to disk
	GameState.save_game()

	# Close overlay and refresh story UI
	if _story_exec_overlay:
		_story_exec_overlay.queue_free()
		_story_exec_overlay = null
	_story_exec_mission.clear()
	_story_exec_quest.clear()
	GameState.quest_state.erase("exec_quest")
	GameState.quest_state.erase("exec_mission")
	GameState.quest_state.erase("story_combat_active")

	_update_story_badge_lbl()
	_rebuild_story_sections()

	# Show reward popup
	var reward_dialog = AcceptDialog.new()
	reward_dialog.title = "Mission Complete"
	reward_dialog.get_ok_button().text = "Continue"
	reward_dialog.min_size = Vector2i(360, 200)
	var rvbox = VBoxContainer.new()
	rvbox.add_theme_constant_override("separation", 8)
	reward_dialog.add_child(rvbox)
	rvbox.add_child(RimvaleUtils.label("✓ MISSION COMPLETE", 16, Color(0.50, 0.90, 0.50)))
	rvbox.add_child(RimvaleUtils.label(
		"+%d XP awarded to team%s" % [xp_award, " (replay)" if already_done else ""],
		12, RimvaleColors.TEXT_WHITE))
	var new_badges: String = ""
	for sec in STORY_SECTIONS:
		if sec[2] != "" and sec[2] in GameState.story_earned_badges:
			# Check if this badge was just earned
			var sec_missions: Array = sec[4]
			var all_done: bool = true
			for sm in sec_missions:
				if sm[0] not in GameState.story_completed_missions:
					all_done = false; break
			var sec_has_mid: bool = false
			for sm in sec_missions:
				if sm[0] == mid: sec_has_mid = true; break
			if all_done and sec_has_mid:
				new_badges += "🏅 %s earned!\n" % sec[2]
	if not new_badges.is_empty():
		var badge_lbl = RimvaleUtils.label(new_badges.strip_edges(), 13, Color(1.0, 0.84, 0.0))
		badge_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rvbox.add_child(badge_lbl)
	reward_dialog.confirmed.connect(func(): reward_dialog.queue_free())
	add_child(reward_dialog)
	reward_dialog.popup_centered(Vector2(360, 200))

func _debug_auto_complete_mission(mid: String, mxp: int) -> void:
	if not GameState.debug_mode:
		return
	if mid in GameState.story_completed_missions:
		_show_world_toast("Already completed.")
		return

	# Award XP to party
	var party: Array = GameState.get_active_handles()
	for ph in party:
		RimvaleAPI.engine.add_xp(ph, mxp, 20)

	# Mark complete
	GameState.story_completed_missions.append(mid)

	# Award gold
	GameState.earn_gold(10000)

	# Check badges
	_check_and_award_story_badges()
	_update_story_badge_lbl()

	# Save and refresh UI
	GameState.save_game()
	_rebuild_story_sections()

	_show_world_toast("⚡ Auto-completed! +%d XP, +10,000 gold" % mxp)

func _on_story_abort() -> void:
	if _story_exec_overlay:
		_story_exec_overlay.queue_free()
		_story_exec_overlay = null
	_story_exec_mission.clear()
	_story_exec_quest.clear()
	GameState.quest_state.erase("exec_quest")
	GameState.quest_state.erase("exec_mission")
	GameState.quest_state.erase("story_combat_active")

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
		["Custom Monster",    Color(0.80, 0.20, 0.80, 1.0)],
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

	# ── Monster Creator Button ───────────────────────────────────────────────────
	var monster_creator_btn = RimvaleUtils.button("Monster Creator", RimvaleColors.ACCENT, 52, 13)
	monster_creator_btn.custom_minimum_size = Vector2(250, 52)
	monster_creator_btn.pressed.connect(_mc_open)
	vbox.add_child(monster_creator_btn)

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

		5: # Custom Monster
			var info = RimvaleUtils.label(
				"Deploy a custom monster you have created. Select from your collection.",
				11, RimvaleColors.TEXT_GRAY)
			info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_dd_config_panel.add_child(info)
			if GameState.custom_monsters.size() == 0:
				_dd_config_panel.add_child(RimvaleUtils.label(
					"No custom monsters created. Use Monster Creator to build one.",
					11, Color(0.80, 0.30, 0.30)))
			else:
				var mopt = OptionButton.new()
				mopt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				for cm in GameState.custom_monsters:
					mopt.add_item(str(cm.get("name", "Unknown")))
				mopt.selected = _dd_custom_monster_idx
				_dd_config_panel.add_child(mopt)
				mopt.item_selected.connect(func(idx: int) -> void:
					_dd_custom_monster_idx = idx)

		6: # Siege Warfare
			var info = RimvaleUtils.label(
				"Assault a fortified position. Break through walls defended by organized forces.",
				11, RimvaleColors.TEXT_GRAY)
			info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_dd_config_panel.add_child(info)

			# Siege tier selector
			var trow = HBoxContainer.new()
			trow.add_theme_constant_override("separation", 8)
			var tlbl = RimvaleUtils.label("Siege Tier: %d" % _dd_siege_tier, 13, RimvaleColors.TEXT_WHITE)
			tlbl.custom_minimum_size = Vector2(150, 0)
			trow.add_child(tlbl)
			var tslider = HSlider.new()
			tslider.min_value = 1
			tslider.max_value = 5
			tslider.step = 1
			tslider.value = _dd_siege_tier
			tslider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tslider.value_changed.connect(func(v: float) -> void:
				_dd_siege_tier = int(v)
				tlbl.text = "Siege Tier: %d" % _dd_siege_tier)
			trow.add_child(tslider)
			_dd_config_panel.add_child(trow)

			# Tier info display
			var tier_desc = RimvaleUtils.label(_dd_siege_tier_desc(_dd_siege_tier), 11, RimvaleColors.TEXT_GRAY)
			tier_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_dd_config_panel.add_child(tier_desc)
			tslider.value_changed.connect(func(v: float) -> void:
				tier_desc.text = _dd_siege_tier_desc(int(v)))

func _dd_siege_tier_desc(tier: int) -> String:
	var idx: int = clampi(tier - 1, 0, 4)
	if idx < 0 or idx >= _WS.SIEGE_TIERS.size():
		return ""
	var s: Dictionary = _WS.SIEGE_TIERS[idx]
	var wall_hp: int = int(s.get("wall_hp", 50))
	var defenders: String = str(s.get("defenders", "unknown"))
	var duration: Array = s.get("duration_days", [1, 3])
	return "%s\nWall HP: %d | Defenders: %s | Duration: %d-%d days" % [
		s.get("name", ""), wall_hp, defenders, duration[0], duration[1]]

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
	# Mark that we launched from the dungeon tab so we return here, not explore
	GameState.dungeon_source = "tab"
	GameState.dungeon_return_tab = 3  # Dungeon tab index
	# Ensure all ritual spells are registered before entering dungeon
	GameState.ensure_ritual_spells_registered()
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
		5: # Custom Monster
			if GameState.custom_monsters.size() == 0:
				push_warning("[Dungeon] No custom monsters created")
				return
			var idx: int = clampi(_dd_custom_monster_idx, 0, GameState.custom_monsters.size() - 1)
			var monster: Dictionary = GameState.custom_monsters[idx]
			if RimvaleAPI.engine.has_method("start_custom_monster_dungeon"):
				RimvaleAPI.engine.start_custom_monster_dungeon(handles, monster, _dd_terrain_style)
		6: # Siege
			RimvaleAPI.engine.start_siege_dungeon(handles, _dd_siege_tier, _dd_terrain_style)
	# Spawn recruited allies into the dungeon as friendly entities
	if GameState.recruited_allies.size() > 0:
		RimvaleAPI.engine.spawn_allies(GameState.recruited_allies)
	# Push dungeon as a full-screen overlay through the main shell.
	var main = get_parent().get_parent() if get_parent() else null
	if main and main.has_method("push_screen"):
		main.push_screen("res://scenes/dungeon/dungeon.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/dungeon/dungeon.tscn")


# -- Monster Creator --

func _mc_open() -> void:
	if _mc_overlay != null and is_instance_valid(_mc_overlay):
		_mc_overlay.queue_free()
	_mc_overlay = Control.new()
	_mc_overlay.anchor_left = 0.0
	_mc_overlay.anchor_top = 0.0
	_mc_overlay.anchor_right = 1.0
	_mc_overlay.anchor_bottom = 1.0
	var bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.modulate.a = 0.5
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	_mc_overlay.add_child(bg)
	get_parent().add_child(_mc_overlay)

	# Main panel
	var panel = PanelContainer.new()
	panel.anchor_left = 0.05
	panel.anchor_top = 0.05
	panel.anchor_right = 0.95
	panel.anchor_bottom = 0.95
	var psb = StyleBoxFlat.new()
	psb.bg_color = RimvaleColors.BG_CARD_DARK
	psb.border_color = RimvaleColors.ACCENT
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(8)
	psb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", psb)
	_mc_overlay.add_child(panel)

	var scroll = ScrollContainer.new()
	scroll.anchor_left = 0.0
	scroll.anchor_top = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	# Header
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var back_btn = RimvaleUtils.button("Back", Color(0.5, 0.5, 0.5), 40, 12)
	back_btn.custom_minimum_size = Vector2(100, 40)
	back_btn.pressed.connect(_mc_close)
	hbox.add_child(back_btn)
	hbox.add_child(RimvaleUtils.label("Monster Creator", 18, RimvaleColors.ACCENT))
	hbox.add_spacer(false)
	vbox.add_child(hbox)

	vbox.add_child(RimvaleUtils.separator())

	# Name field
	vbox.add_child(RimvaleUtils.label("Monster Name", 13, RimvaleColors.TEXT_WHITE))
	_mc_name_edit = LineEdit.new()
	_mc_name_edit.text = "Custom Monster"
	_mc_name_edit.custom_minimum_size = Vector2(0, 36)
	vbox.add_child(_mc_name_edit)

	# Level slider
	vbox.add_child(RimvaleUtils.label("Level", 13, RimvaleColors.TEXT_WHITE))
	var level_hbox = HBoxContainer.new()
	level_hbox.add_theme_constant_override("separation", 8)
	var level_lbl = RimvaleUtils.label("Level: 1", 12, RimvaleColors.TEXT_GRAY)
	level_lbl.custom_minimum_size = Vector2(80, 0)
	level_hbox.add_child(level_lbl)
	_mc_level_slider = HSlider.new()
	_mc_level_slider.min_value = 1
	_mc_level_slider.max_value = 20
	_mc_level_slider.step = 1
	_mc_level_slider.value = 1
	_mc_level_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mc_level_slider.value_changed.connect(func(v: float) -> void:
		level_lbl.text = "Level: %d" % int(v)
		_mc_update_derived_stats())
	level_hbox.add_child(_mc_level_slider)
	vbox.add_child(level_hbox)

	# Apex toggle
	var apex_hbox = HBoxContainer.new()
	apex_hbox.add_theme_constant_override("separation", 8)
	apex_hbox.add_child(RimvaleUtils.label("Apex Monster", 12, RimvaleColors.TEXT_WHITE))
	_mc_apex_check = CheckButton.new()
	_mc_apex_check.toggled.connect(func(_v: bool) -> void:
		_mc_update_derived_stats())
	apex_hbox.add_child(_mc_apex_check)
	vbox.add_child(apex_hbox)

	vbox.add_child(RimvaleUtils.spacer(4))
	vbox.add_child(RimvaleUtils.separator())

	# Stats section
	vbox.add_child(RimvaleUtils.label("Stat Points", 13, RimvaleColors.TEXT_WHITE))
	var stats_info = RimvaleUtils.label("Level + 5 = %d points to distribute (0-20 each)" % (1 + 5), 11, RimvaleColors.TEXT_GRAY)
	vbox.add_child(stats_info)
	_mc_level_slider.value_changed.connect(func(v: float) -> void:
		var points = int(v) + 5
		stats_info.text = "Level + 5 = %d points to distribute (0-20 each)" % points)

	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 8)
	stats_grid.add_theme_constant_override("v_separation", 8)

	for stat in ["STR", "SPD", "INT", "VIT", "DIV"]:
		var stat_vbox = VBoxContainer.new()
		var stat_lbl = RimvaleUtils.label("%s: 1" % stat, 11, RimvaleColors.TEXT_GRAY)
		stat_vbox.add_child(stat_lbl)
		var stat_hbox = HBoxContainer.new()
		stat_hbox.add_theme_constant_override("separation", 4)
		var minus_btn = RimvaleUtils.button("-", Color(0.5, 0.5, 0.5), 32, 11)
		minus_btn.custom_minimum_size = Vector2(40, 32)
		minus_btn.pressed.connect(func() -> void:
			if _mc_stats[stat] > 0:
				_mc_stats[stat] -= 1
				_mc_update_stat_display())
		stat_hbox.add_child(minus_btn)
		var plus_btn = RimvaleUtils.button("+", RimvaleColors.ACCENT, 32, 11)
		plus_btn.custom_minimum_size = Vector2(40, 32)
		plus_btn.pressed.connect(func() -> void:
			if _mc_stats[stat] < 20:
				_mc_stats[stat] += 1
				_mc_update_stat_display())
		stat_hbox.add_child(plus_btn)
		stat_vbox.add_child(stat_hbox)
		stats_grid.add_child(stat_vbox)
		_mc_stat_labels[stat] = stat_lbl

	vbox.add_child(stats_grid)

	vbox.add_child(RimvaleUtils.spacer(4))

	# Derived stats card
	var derived_hbox = HBoxContainer.new()
	derived_hbox.add_theme_constant_override("separation", 16)
	var hp_lbl = RimvaleUtils.label("HP: 4", 11, RimvaleColors.ACCENT)
	derived_hbox.add_child(hp_lbl)
	var ap_lbl = RimvaleUtils.label("AP: 4", 11, RimvaleColors.ACCENT)
	derived_hbox.add_child(ap_lbl)
	var sp_lbl = RimvaleUtils.label("SP: 4", 11, RimvaleColors.ACCENT)
	derived_hbox.add_child(sp_lbl)
	vbox.add_child(derived_hbox)
	_mc_stat_labels["HP"] = hp_lbl
	_mc_stat_labels["AP"] = ap_lbl
	_mc_stat_labels["SP"] = sp_lbl

	vbox.add_child(RimvaleUtils.separator())

	# Abilities section
	vbox.add_child(RimvaleUtils.label("Abilities", 13, RimvaleColors.TEXT_WHITE))
	var abilities_info = RimvaleUtils.label("Points: 1/1", 11, RimvaleColors.TEXT_GRAY)
	vbox.add_child(abilities_info)

	var ability_select_hbox = HBoxContainer.new()
	ability_select_hbox.add_theme_constant_override("separation", 8)
	ability_select_hbox.add_child(RimvaleUtils.label("Category:", 11, RimvaleColors.TEXT_GRAY))
	_mc_ability_category_opt = OptionButton.new()
	for cat in MONSTER_ABILITY_CATEGORIES:
		_mc_ability_category_opt.add_item(cat["name"])
	_mc_ability_category_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mc_ability_category_opt.item_selected.connect(_mc_update_abilities)
	ability_select_hbox.add_child(_mc_ability_category_opt)
	vbox.add_child(ability_select_hbox)

	# Ability buttons grid
	_mc_ability_grid = GridContainer.new()
	_mc_ability_grid.columns = 3
	_mc_ability_grid.add_theme_constant_override("h_separation", 6)
	_mc_ability_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(_mc_ability_grid)
	_mc_update_abilities(0)

	vbox.add_child(RimvaleUtils.spacer(4))

	# Selected abilities display
	var sel_lbl = RimvaleUtils.label("Selected Abilities:", 12, RimvaleColors.TEXT_WHITE)
	vbox.add_child(sel_lbl)
	var abilities_display = VBoxContainer.new()
	abilities_display.custom_minimum_size = Vector2(0, 80)
	var abilities_scroll = ScrollContainer.new()
	abilities_scroll.add_child(abilities_display)
	vbox.add_child(abilities_scroll)
	_mc_stat_labels["abilities_display"] = abilities_display

	vbox.add_child(RimvaleUtils.spacer(4))
	vbox.add_child(RimvaleUtils.separator())

	# Save button
	var save_btn = RimvaleUtils.button("Save Monster", RimvaleColors.GOLD, 52, 13)
	save_btn.custom_minimum_size = Vector2(200, 52)
	save_btn.pressed.connect(_mc_save)
	vbox.add_child(save_btn)

	vbox.add_child(RimvaleUtils.spacer(4))

	# Saved monsters list
	vbox.add_child(RimvaleUtils.label("Saved Monsters", 13, RimvaleColors.TEXT_WHITE))
	_mc_saved_vbox = VBoxContainer.new()
	_mc_saved_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(_mc_saved_vbox)
	_mc_refresh_saved_list()

func _mc_close() -> void:
	if _mc_overlay != null and is_instance_valid(_mc_overlay):
		_mc_overlay.queue_free()
	_mc_overlay = null

func _mc_update_stat_display() -> void:
	for stat in ["STR", "SPD", "INT", "VIT", "DIV"]:
		if stat in _mc_stat_labels:
			_mc_stat_labels[stat].text = "%s: %d" % [stat, _mc_stats[stat]]
	_mc_update_derived_stats()

func _mc_update_derived_stats() -> void:
	var level = int(_mc_level_slider.value)
	var is_apex = _mc_apex_check.is_pressed()
	var vit = _mc_stats.get("VIT", 1)
	var str_val = _mc_stats.get("STR", 1)
	var div = _mc_stats.get("DIV", 1)

	var hp = (5 if is_apex else 3) * level + vit
	var ap = (10 if is_apex else 3) + str_val
	var sp = (10 if is_apex else 3) + level + div

	if "HP" in _mc_stat_labels:
		_mc_stat_labels["HP"].text = "HP: %d" % hp
	if "AP" in _mc_stat_labels:
		_mc_stat_labels["AP"].text = "AP: %d" % ap
	if "SP" in _mc_stat_labels:
		_mc_stat_labels["SP"].text = "SP: %d" % sp

func _mc_update_abilities(cat_idx: int) -> void:
	if cat_idx < 0 or cat_idx >= MONSTER_ABILITY_CATEGORIES.size():
		return
	# Clear old buttons from grid
	if _mc_ability_grid != null and is_instance_valid(_mc_ability_grid):
		for child in _mc_ability_grid.get_children():
			child.queue_free()
	_mc_ability_buttons.clear()
	var cat = MONSTER_ABILITY_CATEGORIES[cat_idx]
	var abilities = cat.get("abilities", [])
	for ab in abilities:
		var btn = RimvaleUtils.button(ab, Color(0.4, 0.6, 0.8), 40, 10)
		btn.custom_minimum_size = Vector2(120, 40)
		btn.toggle_mode = true
		btn.pressed.connect(func() -> void:
			if ab in _mc_abilities:
				_mc_abilities.erase(ab)
			else:
				_mc_abilities.append(ab)
			_mc_refresh_abilities_display())
		if ab in _mc_abilities:
			btn.set_pressed_no_signal(true)
		_mc_ability_buttons.append(btn)
		if _mc_ability_grid != null and is_instance_valid(_mc_ability_grid):
			_mc_ability_grid.add_child(btn)

func _mc_refresh_abilities_display() -> void:
	var display = _mc_stat_labels.get("abilities_display")
	if display:
		for child in display.get_children():
			child.queue_free()
		for ab in _mc_abilities:
			display.add_child(RimvaleUtils.label("• %s" % ab, 10, RimvaleColors.TEXT_WHITE))

func _mc_save() -> void:
	var monster: Dictionary = {
		"name": _mc_name_edit.text if _mc_name_edit.text != "" else "Custom Monster",
		"level": int(_mc_level_slider.value),
		"apex": _mc_apex_check.is_pressed(),
		"stats": _mc_stats.duplicate(),
		"abilities": _mc_abilities.duplicate(),
	}
	GameState.custom_monsters.append(monster)
	GameState.save_game()
	_mc_refresh_saved_list()

func _mc_refresh_saved_list() -> void:
	if _mc_saved_vbox == null or not is_instance_valid(_mc_saved_vbox):
		return
	for child in _mc_saved_vbox.get_children():
		child.queue_free()
	if GameState.custom_monsters.is_empty():
		_mc_saved_vbox.add_child(RimvaleUtils.label("No monsters saved yet.", 11, RimvaleColors.TEXT_GRAY))
		return
	for idx in range(GameState.custom_monsters.size()):
		var cm = GameState.custom_monsters[idx]
		var chip = PanelContainer.new()
		var csb = StyleBoxFlat.new()
		csb.bg_color = Color(0.2, 0.2, 0.3)
		csb.border_color = RimvaleColors.ACCENT
		csb.set_border_width_all(1)
		csb.set_corner_radius_all(4)
		csb.set_content_margin_all(8)
		chip.add_theme_stylebox_override("panel", csb)

		var chip_hbox = HBoxContainer.new()
		chip_hbox.add_theme_constant_override("separation", 12)
		var info_lbl = RimvaleUtils.label(
			"Lv.%d %s%s" % [cm.get("level", 1), cm.get("name", ""), " (Apex)" if cm.get("apex") else ""],
			11, RimvaleColors.TEXT_WHITE)
		chip_hbox.add_child(info_lbl)
		chip_hbox.add_spacer(false)

		var edit_btn = RimvaleUtils.button("Edit", Color(0.4, 0.6, 0.8), 36, 10)
		edit_btn.custom_minimum_size = Vector2(80, 36)
		chip_hbox.add_child(edit_btn)

		var del_btn = RimvaleUtils.button("Delete", Color(0.8, 0.3, 0.3), 36, 10)
		del_btn.custom_minimum_size = Vector2(80, 36)
		del_btn.pressed.connect(func() -> void:
			GameState.custom_monsters.remove_at(idx)
			GameState.save_game()
			_mc_refresh_saved_list())
		chip_hbox.add_child(del_btn)

		chip.add_child(chip_hbox)
		_mc_saved_vbox.add_child(chip)
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

	vbox.add_child(RimvaleUtils.separator())

	# ── Repair Equipment ─────────────────────────────────────────────────────
	vbox.add_child(RimvaleUtils.label("Repair Equipment", 16, RimvaleColors.ACCENT))
	var repair_scroll = ScrollContainer.new()
	repair_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	repair_scroll.custom_minimum_size = Vector2(0, 160)
	_repair_vbox = VBoxContainer.new()
	_repair_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_repair_vbox.add_theme_constant_override("separation", 4)
	repair_scroll.add_child(_repair_vbox)
	vbox.add_child(repair_scroll)
	_refresh_repair_list()

func _refresh_repair_list() -> void:
	if _repair_vbox == null: return
	for child in _repair_vbox.get_children():
		child.queue_free()

	var _e = RimvaleAPI.engine
	var found_any: bool = false
	var handles: Array = GameState.get_active_handles()
	for h in handles:
		var cname: String = str(_e.get_character_name(h))
		for slot in ["weapon", "armor", "shield"]:
			var cur_hp: int = _e._get_equip_hp(_e._chars[h], slot)
			var max_hp: int = _e._get_equip_max_hp(_e._chars[h], slot)
			var item_name: String = str(_e._chars[h].get(slot, "None"))
			if item_name == "None" or item_name == "": continue
			if cur_hp >= max_hp: continue
			found_any = true
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var info_lbl := Label.new()
			var status: String = "DESTROYED" if cur_hp <= -max_hp else ("BROKEN" if cur_hp <= 0 else "Damaged")
			var repair_cost: int = maxi(1, (max_hp - cur_hp) * 2)
			info_lbl.text = "%s  %s [%s] %d/%d HP — %d GP" % [cname, item_name, status, maxi(0, cur_hp), max_hp, repair_cost]
			info_lbl.add_theme_font_size_override("font_size", 11)
			info_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3) if cur_hp <= 0 else Color(0.9, 0.85, 0.7))
			info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(info_lbl)
			var repair_btn := Button.new()
			repair_btn.text = "Repair"
			repair_btn.add_theme_font_size_override("font_size", 12)
			repair_btn.custom_minimum_size = Vector2(70, 0)
			repair_btn.disabled = GameState.gold < repair_cost
			var cap_h: int = h; var cap_slot: String = slot
			repair_btn.pressed.connect(func():
				var result: String = _e.repair_equipment(cap_h, cap_slot)
				_refresh_repair_list())
			row.add_child(repair_btn)
			_repair_vbox.add_child(row)

	# ── Damaged stash items ──────────────────────────────────────────────────
	for iname in GameState.stash_hp.keys():
		var hp_arr: Array = GameState.stash_hp[iname]
		var max_hp: int = _e._weapon_max_hp(iname)
		if max_hp <= 0: max_hp = _e._armor_max_hp(iname)
		if max_hp <= 0: continue
		for copy_i in range(hp_arr.size()):
			var shp: int = int(hp_arr[copy_i])
			if shp < 0 or shp >= max_hp: continue  # -1 = full, or already full
			found_any = true
			var row2 = HBoxContainer.new()
			row2.add_theme_constant_override("separation", 8)
			var info2 := Label.new()
			var st2: String = "BROKEN" if shp <= 0 else "Damaged"
			var rc2: int = maxi(1, (max_hp - shp) * 2)
			info2.text = "Stash  %s [%s] %d/%d HP — %d GP" % [iname, st2, maxi(0, shp), max_hp, rc2]
			info2.add_theme_font_size_override("font_size", 11)
			info2.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3) if shp <= 0 else Color(0.9, 0.85, 0.7))
			info2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row2.add_child(info2)
			var rb2 := Button.new()
			rb2.text = "Repair"
			rb2.add_theme_font_size_override("font_size", 12)
			rb2.custom_minimum_size = Vector2(70, 0)
			rb2.disabled = GameState.gold < rc2
			var cap_iname: String = iname
			rb2.pressed.connect(func():
				_e.repair_stash_item(cap_iname)
				_refresh_repair_list())
			row2.add_child(rb2)
			_repair_vbox.add_child(row2)

	if not found_any:
		var lbl := Label.new()
		lbl.text = "All equipment is in good condition."
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		_repair_vbox.add_child(lbl)

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
		"Design spells via extended casting. Passes an Arcane check to learn.", 11, RimvaleColors.TEXT_GRAY))

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
		"Learned Ritual Spells (Castable in Dungeons)", 13, RimvaleColors.TEXT_LIGHT))
	_ritual_active_vbox = VBoxContainer.new()
	_ritual_active_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ritual_active_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(_ritual_active_vbox)

	# ── Empty state ───────────────────────────────────────────────────────────
	_ritual_empty_lbl = RimvaleUtils.label(
		"No active rituals.\nTap '+ New Ritual' to design a spell with the full PHB spell builder.",
		12, RimvaleColors.TEXT_GRAY)
	_ritual_empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_ritual_empty_lbl)

	# Build the spell builder overlay (hidden by default)
	_build_ritual_spell_overlay(rituals_panel)

	_refresh_ritual_ui()

# ── Ritual Spell Builder Overlay ─────────────────────────────────────────────

func _build_ritual_spell_overlay(parent: Control) -> void:
	_ritual_overlay = ColorRect.new()
	(_ritual_overlay as ColorRect).color = Color(0.0, 0.0, 0.0, 0.72)
	_ritual_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ritual_overlay.visible = false
	parent.add_child(_ritual_overlay)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.07, 0.12)
	panel_style.corner_radius_top_left = 8; panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8; panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -260.0
	panel.offset_right  =  260.0
	panel.offset_top    = -340.0
	panel.offset_bottom =  340.0
	_ritual_overlay.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)

	_ritual_inner = VBoxContainer.new()
	_ritual_inner.add_theme_constant_override("separation", 6)
	_ritual_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_ritual_inner)

func _rb_populate_inner() -> void:
	for c in _ritual_inner.get_children():
		_ritual_inner.remove_child(c)
		c.queue_free()
	var inner: VBoxContainer = _ritual_inner
	_ritual_preview_lbl = null
	_ritual_breakdown_lbl = null
	_ritual_desc_lbl = null

	# ── Title ──
	var title_lbl := Label.new()
	title_lbl.text = "✨ Ritual Spell Builder"
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.70, 1.0))
	inner.add_child(title_lbl)
	inner.add_child(HSeparator.new())

	# ── Caster ──
	var caster_opt := OptionButton.new()
	for h in _rb_handles:
		var cname: String = str(RimvaleAPI.engine.get_character_name(h))
		var sp_cur: int = RimvaleAPI.engine.get_character_sp(h)
		caster_opt.add_item("%s (%d SP)" % [cname, sp_cur])
	caster_opt.selected = mini(_rb_caster_idx, maxi(0, _rb_handles.size() - 1))
	caster_opt.item_selected.connect(func(i: int): _rb_caster_idx = i)
	inner.add_child(_rb_spell_row("Caster:", caster_opt))

	# ── Spell Name ──
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Ritual spell name..."
	name_edit.text = _rb_name
	name_edit.custom_minimum_size = Vector2(200, 36)
	name_edit.add_theme_font_size_override("font_size", 14)
	name_edit.text_changed.connect(func(t: String): _rb_name = t)
	inner.add_child(_rb_spell_row("Name:", name_edit))

	# ── Domain ──
	var domain_opt := OptionButton.new()
	for dn in RB_DOMAIN_NAMES:
		domain_opt.add_item(dn)
	domain_opt.selected = _rb_domain
	domain_opt.item_selected.connect(func(i: int):
		_rb_domain = i
		_rb_effect_idx = 0
		_rb_populate_inner()
	)
	inner.add_child(_rb_spell_row("Domain:", domain_opt))

	# ── Effect (per domain) ──
	var effect_opt := OptionButton.new()
	var effects_for_domain: Array = RB_DOMAIN_EFFECTS[_rb_domain] if _rb_domain < RB_DOMAIN_EFFECTS.size() else []
	for ef in effects_for_domain:
		effect_opt.add_item(ef[0])
	effect_opt.selected = mini(_rb_effect_idx, max(0, effects_for_domain.size() - 1))
	effect_opt.item_selected.connect(func(i: int):
		_rb_effect_idx = i
		_rb_update_preview()
	)
	inner.add_child(_rb_spell_row("Effect:", effect_opt))

	# ── Duration ──
	var dur_opt := OptionButton.new()
	for dl in RB_DURATION_LABELS:
		dur_opt.add_item(dl)
	dur_opt.selected = _rb_duration_idx
	dur_opt.item_selected.connect(func(i: int):
		_rb_duration_idx = i
		_rb_update_preview()
	)
	inner.add_child(_rb_spell_row("Duration:", dur_opt))

	# ── Range ──
	var range_opt := OptionButton.new()
	for rl in RB_RANGE_LABELS:
		range_opt.add_item(rl)
	range_opt.selected = _rb_range_idx
	range_opt.item_selected.connect(func(i: int):
		_rb_range_idx = i
		_rb_update_preview()
	)
	inner.add_child(_rb_spell_row("Range:", range_opt))

	# ── Targets (slider 1-10) ──
	var tgt_lbl := Label.new()
	tgt_lbl.text = "Targets: %d" % _rb_targets
	tgt_lbl.add_theme_font_size_override("font_size", 13)
	tgt_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.75))
	inner.add_child(tgt_lbl)
	var tgt_slider := HSlider.new()
	tgt_slider.min_value = 1; tgt_slider.max_value = 10; tgt_slider.step = 1
	tgt_slider.value = _rb_targets
	tgt_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tgt_slider.value_changed.connect(func(v: float):
		_rb_targets = int(v)
		tgt_lbl.text = "Targets: %d" % _rb_targets
		_rb_update_preview()
	)
	inner.add_child(tgt_slider)

	# ── Area ──
	var area_opt := OptionButton.new()
	for al in RB_AREA_LABELS:
		area_opt.add_item(al)
	area_opt.selected = _rb_area_idx
	area_opt.item_selected.connect(func(i: int):
		_rb_area_idx = i
		_rb_update_preview()
	)
	inner.add_child(_rb_spell_row("Area:", area_opt))

	inner.add_child(HSeparator.new())

	# ── Dice Count (slider 0-10) ──
	var dice_lbl := Label.new()
	dice_lbl.text = "Dice Count: %d" % _rb_die_count
	dice_lbl.add_theme_font_size_override("font_size", 13)
	dice_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.75))
	inner.add_child(dice_lbl)
	var dice_slider := HSlider.new()
	dice_slider.min_value = 0; dice_slider.max_value = 10; dice_slider.step = 1
	dice_slider.value = _rb_die_count
	dice_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dice_slider.value_changed.connect(func(v: float):
		_rb_die_count = int(v)
		dice_lbl.text = "Dice Count: %d" % _rb_die_count
		_rb_update_preview()
	)
	inner.add_child(dice_slider)

	# ── Die Type (d4 d6 d8 d10 d12 buttons) ──
	var die_lbl := Label.new()
	die_lbl.text = "Die Type"
	die_lbl.add_theme_font_size_override("font_size", 13)
	die_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.75))
	inner.add_child(die_lbl)
	var die_row := HBoxContainer.new()
	die_row.add_theme_constant_override("separation", 4)
	var die_btns: Array = []
	for di in range(RB_DIE_LABELS.size()):
		var di_cap: int = di
		var col: Color = Color(0.55, 0.35, 0.85) if di == _rb_die_idx else Color(0.45, 0.45, 0.50)
		var dbtn := _rb_colored_btn(RB_DIE_LABELS[di], col)
		dbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dbtn.custom_minimum_size = Vector2(0, 30)
		var btns_ref: Array = die_btns
		dbtn.pressed.connect(func():
			_rb_die_idx = di_cap
			for k in range(btns_ref.size()):
				var c2: Color = Color(0.55, 0.35, 0.85) if k == _rb_die_idx else Color(0.45, 0.45, 0.50)
				var sb2 := StyleBoxFlat.new()
				sb2.bg_color = c2
				sb2.corner_radius_top_left = 4; sb2.corner_radius_top_right = 4
				sb2.corner_radius_bottom_left = 4; sb2.corner_radius_bottom_right = 4
				btns_ref[k].add_theme_stylebox_override("normal", sb2)
			_rb_update_preview()
		)
		die_btns.append(dbtn)
		die_row.add_child(dbtn)
	inner.add_child(die_row)

	# ── Damage Type ──
	var dmg_opt := OptionButton.new()
	for dt in RB_DAMAGE_TYPES:
		dmg_opt.add_item(dt)
	dmg_opt.selected = _rb_damage_type
	dmg_opt.item_selected.connect(func(i: int):
		_rb_damage_type = i
		_rb_update_preview()
	)
	inner.add_child(_rb_spell_row("Damage Type:", dmg_opt))

	inner.add_child(HSeparator.new())

	# ── Flags: Healing, Saving Throw, Teleport, Combustion ──
	var flag_row1 := HBoxContainer.new()
	flag_row1.add_theme_constant_override("separation", 14)
	var heal_chk := CheckBox.new(); heal_chk.text = "Healing"
	heal_chk.button_pressed = _rb_is_healing
	heal_chk.add_theme_font_size_override("font_size", 12)
	heal_chk.toggled.connect(func(b: bool): _rb_is_healing = b; _rb_update_preview())
	flag_row1.add_child(heal_chk)
	var save_chk := CheckBox.new(); save_chk.text = "Save (no atk)"
	save_chk.button_pressed = _rb_is_saving_throw
	save_chk.add_theme_font_size_override("font_size", 12)
	save_chk.toggled.connect(func(b: bool): _rb_is_saving_throw = b; _rb_update_preview())
	flag_row1.add_child(save_chk)
	inner.add_child(flag_row1)

	var flag_row2 := HBoxContainer.new()
	flag_row2.add_theme_constant_override("separation", 14)
	var tp_chk := CheckBox.new(); tp_chk.text = "Teleport"
	tp_chk.button_pressed = _rb_is_teleport
	tp_chk.add_theme_font_size_override("font_size", 12)
	tp_chk.toggled.connect(func(b: bool):
		_rb_is_teleport = b
		_rb_tp_range_row.visible = b
		_rb_update_preview()
	)
	flag_row2.add_child(tp_chk)
	var comb_chk := CheckBox.new(); comb_chk.text = "Combustion (dynamic dmg)"
	comb_chk.button_pressed = _rb_is_combustion
	comb_chk.add_theme_font_size_override("font_size", 12)
	comb_chk.toggled.connect(func(b: bool): _rb_is_combustion = b; _rb_update_preview())
	flag_row2.add_child(comb_chk)
	inner.add_child(flag_row2)

	# ── Teleport range slider (visible only when teleport is checked) ──
	_rb_tp_range_row = HBoxContainer.new()
	_rb_tp_range_row.add_theme_constant_override("separation", 8)
	_rb_tp_range_row.visible = _rb_is_teleport
	var tp_range_lbl := Label.new()
	tp_range_lbl.text = "Teleport Range (tiles):"
	tp_range_lbl.add_theme_font_size_override("font_size", 12)
	_rb_tp_range_row.add_child(tp_range_lbl)
	var tp_range_val := Label.new()
	tp_range_val.text = str(_rb_tp_range)
	tp_range_val.add_theme_font_size_override("font_size", 13)
	tp_range_val.add_theme_color_override("font_color", Color(0.40, 0.80, 1.0))
	tp_range_val.custom_minimum_size = Vector2(30, 0)
	_rb_tp_range_row.add_child(tp_range_val)
	var tp_range_slider := HSlider.new()
	tp_range_slider.min_value = 1
	tp_range_slider.max_value = 20
	tp_range_slider.step = 1
	tp_range_slider.value = _rb_tp_range
	tp_range_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tp_range_slider.custom_minimum_size = Vector2(120, 0)
	tp_range_slider.value_changed.connect(func(v: float):
		_rb_tp_range = int(v)
		tp_range_val.text = str(_rb_tp_range)
		_rb_update_preview()
	)
	_rb_tp_range_row.add_child(tp_range_slider)
	inner.add_child(_rb_tp_range_row)

	inner.add_child(HSeparator.new())

	# ── Conditions (Beneficial | Harmful) ──
	var cond_title := Label.new()
	cond_title.text = "Conditions"
	cond_title.add_theme_font_size_override("font_size", 14)
	cond_title.add_theme_color_override("font_color", Color.WHITE)
	inner.add_child(cond_title)

	var cond_outer := HBoxContainer.new()
	cond_outer.add_theme_constant_override("separation", 12)
	inner.add_child(cond_outer)

	var ben_col := VBoxContainer.new()
	ben_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ben_col.add_theme_constant_override("separation", 0)
	cond_outer.add_child(ben_col)
	var ben_hdr := Label.new()
	ben_hdr.text = "Beneficial (-2 SP each)"
	ben_hdr.add_theme_font_size_override("font_size", 11)
	ben_hdr.add_theme_color_override("font_color", Color(0.30, 0.69, 0.31))
	ben_col.add_child(ben_hdr)
	for cname in RB_CONDITIONS_BENEFICIAL:
		var cn_cap: String = cname
		var chk := CheckBox.new()
		chk.text = cname
		chk.button_pressed = cname in _rb_conditions
		chk.add_theme_font_size_override("font_size", 11)
		chk.toggled.connect(func(b: bool):
			if b:
				if cn_cap not in _rb_conditions: _rb_conditions.append(cn_cap)
			else:
				_rb_conditions.erase(cn_cap)
			_rb_update_preview()
		)
		ben_col.add_child(chk)

	var harm_col := VBoxContainer.new()
	harm_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	harm_col.add_theme_constant_override("separation", 0)
	cond_outer.add_child(harm_col)
	var harm_hdr := Label.new()
	harm_hdr.text = "Harmful (+3 SP each)"
	harm_hdr.add_theme_font_size_override("font_size", 11)
	harm_hdr.add_theme_color_override("font_color", Color(0.90, 0.40, 0.40))
	harm_col.add_child(harm_hdr)
	for cname in RB_CONDITIONS_HARMFUL:
		var cn_cap: String = cname
		var chk := CheckBox.new()
		chk.text = cname
		chk.button_pressed = cname in _rb_conditions
		chk.add_theme_font_size_override("font_size", 11)
		chk.toggled.connect(func(b: bool):
			if b:
				if cn_cap not in _rb_conditions: _rb_conditions.append(cn_cap)
			else:
				_rb_conditions.erase(cn_cap)
			_rb_update_preview()
		)
		harm_col.add_child(chk)

	inner.add_child(HSeparator.new())

	# ── SP Cost Preview Card ──
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.14, 0.12, 0.22, 1.0)
	card_style.corner_radius_top_left = 8; card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8; card_style.corner_radius_bottom_right = 8
	card_style.content_margin_left = 14.0; card_style.content_margin_right = 14.0
	card_style.content_margin_top = 12.0; card_style.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", card_style)
	inner.add_child(card)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)
	card.add_child(card_vbox)

	_ritual_preview_lbl = Label.new()
	_ritual_preview_lbl.text = "SP Cost: -- · DC: --"
	_ritual_preview_lbl.add_theme_font_size_override("font_size", 18)
	_ritual_preview_lbl.add_theme_color_override("font_color", Color(0.74, 0.40, 1.0))
	card_vbox.add_child(_ritual_preview_lbl)

	_ritual_breakdown_lbl = Label.new()
	_ritual_breakdown_lbl.text = ""
	_ritual_breakdown_lbl.add_theme_font_size_override("font_size", 11)
	_ritual_breakdown_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60))
	_ritual_breakdown_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(_ritual_breakdown_lbl)

	var desc_hdr := Label.new()
	desc_hdr.text = "Description:"
	desc_hdr.add_theme_font_size_override("font_size", 12)
	desc_hdr.add_theme_color_override("font_color", Color.WHITE)
	card_vbox.add_child(desc_hdr)

	_ritual_desc_lbl = Label.new()
	_ritual_desc_lbl.text = ""
	_ritual_desc_lbl.add_theme_font_size_override("font_size", 11)
	_ritual_desc_lbl.add_theme_color_override("font_color", Color(0.70, 0.75, 0.85))
	_ritual_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(_ritual_desc_lbl)

	_rb_update_preview()

	# ── Buttons ──
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	inner.add_child(btn_row)

	var btn_begin := _rb_colored_btn("Begin Ritual", Color(0.22, 0.10, 0.35))
	btn_begin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_begin.pressed.connect(_on_begin_ritual)
	btn_row.add_child(btn_begin)

	var btn_cancel := Button.new()
	btn_cancel.text = "Cancel"
	btn_cancel.custom_minimum_size = Vector2(80, 34)
	btn_cancel.pressed.connect(func(): _ritual_overlay.visible = false)
	btn_row.add_child(btn_cancel)

# ── Ritual builder helpers (mirror dungeon.gd) ──────────────────────────────

func _rb_spell_row(label_text: String, widget: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(120, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)
	row.add_child(widget)
	return row

func _rb_colored_btn(txt: String, col: Color) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 34)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = col
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	b.add_theme_stylebox_override("normal", style)
	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = col.lightened(0.15)
	b.add_theme_stylebox_override("hover", hover_style)
	return b

func _rb_calc_cost() -> int:
	# Teleport spells: cost is based on max range (pre-paid at ritual time)
	if _rb_is_teleport:
		# Scaling: 1 SP per 2 tiles of range, minimum 1
		var tp_cost: int = maxi(1, (_rb_tp_range + 1) / 2)
		# Add target cost if multi-target
		if _rb_targets > 1:
			for i in range(_rb_targets - 1):
				tp_cost += int(pow(2.0, float(i + 1)))
		return tp_cost

	var type_cost: int   = 1 if _rb_is_saving_throw else 0
	var sides_mod: int   = RB_DIE_SIDES_MOD[_rb_die_idx] if _rb_die_idx < RB_DIE_SIDES_MOD.size() else 0
	var dice_cost: int   = _rb_die_count * (1 + sides_mod)
	var dur_mult: int    = RB_DURATION_MULT[_rb_duration_idx] if _rb_duration_idx < RB_DURATION_MULT.size() else 1
	var effects: Array   = RB_DOMAIN_EFFECTS[_rb_domain] if _rb_domain < RB_DOMAIN_EFFECTS.size() else []
	var effect_base: int = int(effects[_rb_effect_idx][1]) if _rb_effect_idx < effects.size() else 1
	var base_effect: int = effect_base + dice_cost
	var base_with_dur: int = base_effect if _rb_duration_idx == 0 else base_effect * dur_mult
	var range_cost: int  = RB_RANGE_SP_COST[_rb_range_idx] if _rb_range_idx < RB_RANGE_SP_COST.size() else 0
	var target_cost: int = 0
	if _rb_targets > 1:
		for i in range(_rb_targets - 1):
			target_cost += int(pow(2.0, float(i + 1)))
	var harmful: int    = 0
	var beneficial: int = 0
	for cname in _rb_conditions:
		if cname in RB_CONDITIONS_HARMFUL: harmful += 1
		else: beneficial += 1
	var cond_cost: int   = (harmful * 3) - (beneficial * 2)
	var area_mult: int   = RB_AREA_MULT[_rb_area_idx] if _rb_area_idx < RB_AREA_MULT.size() else 1
	var base_sum: int    = type_cost + base_with_dur + range_cost + target_cost + cond_cost
	var total: int       = base_sum * area_mult
	if total <= 0 and (dur_mult > 1 or area_mult > 1):
		total = 1
	elif total < 0:
		total = 0
	return total

func _rb_update_preview() -> void:
	var cost: int = _rb_calc_cost()
	var dc: int = 10 + cost
	if is_instance_valid(_ritual_preview_lbl):
		_ritual_preview_lbl.text = "SP Cost: %d · Arcane DC: %d" % [cost, dc]

	if is_instance_valid(_ritual_breakdown_lbl):
		var lines: PackedStringArray = []
		if _rb_is_teleport:
			# Teleport-specific breakdown
			var tp_cost: int = maxi(1, (_rb_tp_range + 1) / 2)
			lines.append("Teleport Range: %d tiles (%dft)" % [_rb_tp_range, _rb_tp_range * 5])
			lines.append("Range Cost: %d SP (1 SP per 2 tiles)" % tp_cost)
			var target_cost: int = 0
			if _rb_targets > 1:
				for i in range(_rb_targets - 1):
					target_cost += int(pow(2.0, float(i + 1)))
				lines.append("Multi-target (%d): +%d" % [_rb_targets, target_cost])
			lines.append("SP is fully pre-paid — casting costs only AP")
		else:
			var effects: Array = RB_DOMAIN_EFFECTS[_rb_domain] if _rb_domain < RB_DOMAIN_EFFECTS.size() else []
			var effect_name: String = effects[_rb_effect_idx][0] if _rb_effect_idx < effects.size() else "Unknown"
			var effect_base: int = int(effects[_rb_effect_idx][1]) if _rb_effect_idx < effects.size() else 1
			var sides_mod: int = RB_DIE_SIDES_MOD[_rb_die_idx] if _rb_die_idx < RB_DIE_SIDES_MOD.size() else 0
			var dice_cost: int = _rb_die_count * (1 + sides_mod)
			var dur_mult: int  = RB_DURATION_MULT[_rb_duration_idx] if _rb_duration_idx < RB_DURATION_MULT.size() else 1
			var range_cost: int = RB_RANGE_SP_COST[_rb_range_idx] if _rb_range_idx < RB_RANGE_SP_COST.size() else 0
			var target_cost: int = 0
			if _rb_targets > 1:
				for i in range(_rb_targets - 1):
					target_cost += int(pow(2.0, float(i + 1)))
			var harmful: int = 0; var beneficial: int = 0
			for cname in _rb_conditions:
				if cname in RB_CONDITIONS_HARMFUL: harmful += 1
				else: beneficial += 1
			var cond_cost: int = (harmful * 3) - (beneficial * 2)
			var area_mult: int = RB_AREA_MULT[_rb_area_idx] if _rb_area_idx < RB_AREA_MULT.size() else 1

			lines.append("Base Effect (%s): %d" % [effect_name, effect_base])
			if dice_cost > 0:
				lines.append("Dice (%dd%d): +%d" % [_rb_die_count, [4,6,8,10,12][_rb_die_idx], dice_cost])
			if dur_mult > 1:
				lines.append("Duration (x%d): applied" % dur_mult)
			if range_cost > 0:
				lines.append("Range (%s): +%d" % [RB_RANGE_LABELS[_rb_range_idx], range_cost])
			if target_cost > 0:
				lines.append("Multi-target (%d): +%d" % [_rb_targets, target_cost])
			if cond_cost != 0:
				lines.append("Conditions: %s%d" % ["+" if cond_cost > 0 else "", cond_cost])
			if _rb_is_saving_throw:
				lines.append("Saving throw: +1")
			if area_mult > 1:
				lines.append("Area (x%d): applied" % area_mult)
			if _rb_is_combustion:
				lines.append("Combustion: damage scales with SP spent")
		lines.append("Ritual DC = 10 + SP Cost = %d (Arcane check)" % dc)
		_ritual_breakdown_lbl.text = "\n".join(lines)

	if is_instance_valid(_ritual_desc_lbl):
		_ritual_desc_lbl.text = _rb_gen_description()

func _rb_gen_description() -> String:
	var effects_arr: Array = RB_DOMAIN_EFFECTS[_rb_domain] if _rb_domain < RB_DOMAIN_EFFECTS.size() else []
	var effect_name: String = effects_arr[_rb_effect_idx][0] if _rb_effect_idx < effects_arr.size() else "Unknown"
	var domain_name: String = RB_DOMAIN_NAMES[_rb_domain] if _rb_domain < RB_DOMAIN_NAMES.size() else "Unknown"
	var target_desc: String = "a single target" if _rb_targets <= 1 else "up to %d targets" % _rb_targets
	var range_desc: String = "on yourself" if _rb_range_idx == 0 else "within %s" % RB_RANGE_LABELS[_rb_range_idx]
	var area_desc: String = "" if _rb_area_idx == 0 else " affecting a %s" % RB_AREA_LABELS[_rb_area_idx]
	var dur_desc: String = RB_DURATION_LABELS[_rb_duration_idx]
	var save_desc: String = ". Targets may roll a saving throw to resist." if _rb_is_saving_throw else "."

	if _rb_is_teleport:
		return "Ritual teleportation. Teleport %s up to %d tiles (%dft). SP fully pre-paid — costs only AP to cast." % [
			target_desc, _rb_tp_range, _rb_tp_range * 5]
	if _rb_is_combustion:
		return "Using the %s domain, you ritually cause a violent combustion targeting %s %s%s. Damage dice scale dynamically with SP spent. Lasts %s%s" % [
			domain_name, target_desc, range_desc, area_desc, dur_desc, save_desc]

	var action_word: String = "heals for" if _rb_is_healing else "deals"
	var dice_desc: String = ""
	if _rb_die_count > 0:
		dice_desc = " %dd%d" % [_rb_die_count, [4,6,8,10,12][_rb_die_idx]]
	var type_desc: String = ""
	if not _rb_is_healing and _rb_die_count > 0:
		type_desc = " %s damage" % RB_DAMAGE_TYPES[_rb_damage_type]
	elif _rb_is_healing and _rb_die_count > 0:
		type_desc = " hit points"

	return "Ritual: Using the %s domain, weave a spell of %s that %s%s%s targeting %s %s%s. Lasts %s%s" % [
		domain_name, effect_name, action_word, dice_desc, type_desc,
		target_desc, range_desc, area_desc, dur_desc, save_desc]

# ── Ritual list display ──────────────────────────────────────────────────────

func _refresh_ritual_ui() -> void:
	if _ritual_tasks_vbox == null:
		return

	for c in _ritual_tasks_vbox.get_children(): c.queue_free()
	for c in _ritual_active_vbox.get_children(): c.queue_free()

	var any_content: bool = false

	# ── In-progress tasks ────────────────────────────────────────────────────
	for task in GameState.ritual_tasks:
		any_content = true
		var sp_cost: int = int(task.get("sp_cost", task.get("sp_committed", 1)))
		var dc: int = 10 + sp_cost
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
		title_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var domain_str: String = str(task.get("domain_name", ""))
		var name_txt: String = str(task["spell_name"])
		if not domain_str.is_empty():
			name_txt += " [%s]" % domain_str
		title_hbox.add_child(RimvaleUtils.label(name_txt, 13, RimvaleColors.TEXT_WHITE))
		var sp3 = Control.new()
		sp3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_hbox.add_child(sp3)
		title_hbox.add_child(RimvaleUtils.label("DC %d" % dc, 12, RimvaleColors.ORANGE))
		card_vbox.add_child(title_hbox)

		var desc_lbl = RimvaleUtils.label(str(task["spell_desc"]), 11, RimvaleColors.TEXT_GRAY)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_vbox.add_child(desc_lbl)

		# Spell details row
		var detail_parts: PackedStringArray = []
		detail_parts.append("Caster: %s" % str(task["caster_name"]))
		detail_parts.append("SP Cost: %d" % sp_cost)
		if task.has("die_count") and int(task["die_count"]) > 0:
			detail_parts.append("%dd%d" % [int(task["die_count"]), int(task.get("die_sides", 6))])
		if task.has("duration_rounds") and int(task["duration_rounds"]) > 0:
			detail_parts.append("Dur: %d rds" % int(task["duration_rounds"]))
		card_vbox.add_child(RimvaleUtils.label(
			" · ".join(detail_parts), 10, RimvaleColors.TEXT_GRAY))

		# Action buttons row
		var btn_row = HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 6)
		card_vbox.add_child(btn_row)

		var task_id: String = str(task["id"])
		var make_check_btn = RimvaleUtils.button("Make Arcane Check", RimvaleColors.AP_BLUE, 30, 10)
		make_check_btn.pressed.connect(func(): _ritual_make_check(task_id))
		btn_row.add_child(make_check_btn)

		var abandon_btn = RimvaleUtils.button("Abandon", RimvaleColors.DANGER, 30, 10)
		abandon_btn.pressed.connect(func(): _ritual_abandon(task_id))
		btn_row.add_child(abandon_btn)

		_ritual_tasks_vbox.add_child(card)

	if GameState.ritual_tasks.is_empty():
		_ritual_tasks_vbox.add_child(
			RimvaleUtils.label("No rituals in progress.", 12, RimvaleColors.TEXT_GRAY))

	# ── Active (learned) ritual spells ───────────────────────────────────────
	for ritual in GameState.active_rituals:
		any_content = true
		var acard = PanelContainer.new()
		acard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var acard_style = StyleBoxFlat.new()
		acard_style.bg_color = Color(0.06, 0.22, 0.08, 1.0)
		acard_style.content_margin_left = 10; acard_style.content_margin_right  = 10
		acard_style.content_margin_top  = 8;  acard_style.content_margin_bottom = 8
		acard.add_theme_stylebox_override("panel", acard_style)

		var acbox = VBoxContainer.new()
		acbox.add_theme_constant_override("separation", 4)
		acard.add_child(acbox)

		# Title row with dispel button
		var atitle = HBoxContainer.new()
		atitle.add_theme_constant_override("separation", 8)
		acbox.add_child(atitle)

		var sp_cost_a: int = int(ritual.get("sp_cost", ritual.get("sp_committed", 1)))
		atitle.add_child(RimvaleUtils.label(
			"✦ " + str(ritual["spell_name"]), 13, Color(1.0, 0.84, 0.3)))
		var sp4 = Control.new()
		sp4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		atitle.add_child(sp4)
		atitle.add_child(RimvaleUtils.label("%d SP" % sp_cost_a, 12, RimvaleColors.SP_PURPLE))

		var ritual_id: String = str(ritual["id"])
		var dispel_btn = RimvaleUtils.button("Dispel", RimvaleColors.DANGER, 28, 10)
		dispel_btn.pressed.connect(func(): _ritual_dispel(ritual_id))
		atitle.add_child(dispel_btn)

		var adesc_lbl = RimvaleUtils.label(str(ritual["spell_desc"]), 10, RimvaleColors.TEXT_GRAY)
		adesc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		acbox.add_child(adesc_lbl)

		# Details
		var adetail_parts: PackedStringArray = []
		adetail_parts.append("Caster: %s" % str(ritual["caster_name"]))
		if ritual.has("die_count") and int(ritual["die_count"]) > 0:
			adetail_parts.append("%dd%d %s" % [int(ritual["die_count"]), int(ritual.get("die_sides", 6)),
				str(ritual.get("damage_type_name", ""))])
		if ritual.has("conditions_csv") and str(ritual["conditions_csv"]) != "":
			adetail_parts.append("Conds: %s" % str(ritual["conditions_csv"]))
		acbox.add_child(RimvaleUtils.label(
			" · ".join(adetail_parts), 10, RimvaleColors.TEXT_GRAY))

		_ritual_active_vbox.add_child(acard)

	if GameState.active_rituals.is_empty():
		_ritual_active_vbox.add_child(
			RimvaleUtils.label("No learned ritual spells yet.", 12, RimvaleColors.TEXT_GRAY))

	if _ritual_empty_lbl:
		_ritual_empty_lbl.visible = not any_content

# ── Ritual actions ───────────────────────────────────────────────────────────

func _on_new_ritual() -> void:
	_rb_handles = GameState.get_active_handles()
	if _rb_handles.is_empty():
		push_warning("[Rituals] No active party members")
		return
	# Reset builder state
	_rb_name = ""
	_rb_caster_idx = 0
	_rb_domain = 0
	_rb_effect_idx = 0
	_rb_duration_idx = 0
	_rb_range_idx = 1
	_rb_targets = 1
	_rb_area_idx = 0
	_rb_die_count = 1
	_rb_die_idx = 0
	_rb_damage_type = 3
	_rb_is_healing = false
	_rb_is_saving_throw = false
	_rb_is_teleport = false
	_rb_tp_range = 5
	_rb_is_combustion = false
	_rb_conditions.clear()
	_rb_populate_inner()
	_ritual_overlay.visible = true

func _on_begin_ritual() -> void:
	var spell_name: String = _rb_name.strip_edges()
	if spell_name.is_empty():
		_show_ritual_result("Spell name cannot be empty.", false)
		_ritual_overlay.visible = false
		return
	if _rb_caster_idx < 0 or _rb_caster_idx >= _rb_handles.size():
		_ritual_overlay.visible = false
		return

	var handle: int = _rb_handles[_rb_caster_idx]
	var caster_name: String = str(RimvaleAPI.engine.get_character_name(handle))
	var sp_cost: int = _rb_calc_cost()
	var die_sides: int = [4, 6, 8, 10, 12][_rb_die_idx]
	var dur_rounds: int = RB_DURATION_ROUNDS[_rb_duration_idx] if _rb_duration_idx < RB_DURATION_ROUNDS.size() else 0
	var cond_csv: String = ",".join(_rb_conditions)
	var desc: String = _rb_gen_description()
	var domain_name: String = RB_DOMAIN_NAMES[_rb_domain] if _rb_domain < RB_DOMAIN_NAMES.size() else "Unknown"

	var task_id: String = "ritual_%d_%s" % [
		Time.get_unix_time_from_system(), spell_name.replace(" ", "_")]

	GameState.ritual_tasks.append({
		"id":              task_id,
		"spell_name":      spell_name,
		"spell_desc":      desc,
		"caster_handle":   handle,
		"caster_name":     caster_name,
		"sp_cost":         sp_cost,
		"sp_committed":    sp_cost,
		# Full spell builder params for add_custom_spell
		"domain":          _rb_domain,
		"domain_name":     domain_name,
		"range_idx":       _rb_range_idx,
		"is_attack":       (not _rb_is_saving_throw) and (not _rb_is_healing),
		"die_count":       _rb_die_count,
		"die_sides":       die_sides,
		"damage_type":     _rb_damage_type,
		"damage_type_name": RB_DAMAGE_TYPES[_rb_damage_type] if _rb_damage_type < RB_DAMAGE_TYPES.size() else "Force",
		"is_healing":      _rb_is_healing,
		"duration_rounds": dur_rounds,
		"max_targets":     _rb_targets,
		"area_type":       _rb_area_idx,
		"conditions_csv":  cond_csv,
		"is_teleport":     _rb_is_teleport,
		"tp_range":        _rb_tp_range if _rb_is_teleport else 0,
		"is_combustion":   _rb_is_combustion,
	})

	_ritual_overlay.visible = false
	_show_ritual_result(
		"Ritual '%s' started (DC %d Arcane check). Use 'Make Arcane Check' when ready." % [spell_name, 10 + sp_cost],
		true)
	_refresh_ritual_ui()
	GameState.save_game()   # persist new ritual task immediately

func _ritual_make_check(task_id: String) -> void:
	var task: Dictionary = {}
	for t in GameState.ritual_tasks:
		if str(t["id"]) == task_id:
			task = t; break
	if task.is_empty():
		return
	var sp_cost: int = int(task.get("sp_cost", task.get("sp_committed", 1)))
	var dc: int = 10 + sp_cost
	var handle: int = int(task["caster_handle"])
	var result: PackedStringArray = RimvaleAPI.engine.execute_skill_challenge(handle, "Arcane", dc)
	var passed: bool = (not result.is_empty()) and result[0] == "1"
	var detail: String = str(result[4]) if result.size() > 4 else "Roll failed"
	var total: int = int(str(result[1])) if result.size() > 1 else 0

	if passed:
		# Register as a real spell and teach only the caster
		var tp_range_val: int = int(task.get("tp_range", 0))
		RimvaleAPI.engine.add_custom_spell(
			str(task["spell_name"]),
			int(task.get("domain", 0)),
			sp_cost,
			str(task["spell_desc"]),
			int(task.get("range_idx", 1)),
			bool(task.get("is_attack", true)),
			int(task.get("die_count", 1)),
			int(task.get("die_sides", 6)),
			int(task.get("damage_type", 3)),
			bool(task.get("is_healing", false)),
			int(task.get("duration_rounds", 0)),
			int(task.get("max_targets", 1)),
			int(task.get("area_type", 0)),
			str(task.get("conditions_csv", "")),
			bool(task.get("is_teleport", false)),
			bool(task.get("is_combustion", false)),
			handle,
			tp_range_val,
		)

		# Promote to active
		GameState.ritual_tasks.erase(task)
		GameState.active_rituals.append(task)
		_show_ritual_result(
			"✓ Success! Rolled %d vs DC %d — '%s' learned by %s! Usable in dungeons." % [
				total, dc, str(task["spell_name"]), str(task.get("caster_name", "caster"))],
			true)
	else:
		_show_ritual_result(
			"✗ Failed. Rolled %d vs DC %d — %s. The ritual remains in progress; try again." % [total, dc, detail],
			false)
	_refresh_ritual_ui()
	GameState.save_game()   # persist ritual state change immediately

func _ritual_abandon(task_id: String) -> void:
	for i in range(GameState.ritual_tasks.size()):
		if str(GameState.ritual_tasks[i]["id"]) == task_id:
			GameState.ritual_tasks.remove_at(i)
			_refresh_ritual_ui()
			GameState.save_game()   # persist removal immediately
			return

func _ritual_dispel(ritual_id: String) -> void:
	for i in range(GameState.active_rituals.size()):
		if str(GameState.active_rituals[i]["id"]) == ritual_id:
			GameState.active_rituals.remove_at(i)
			_refresh_ritual_ui()
			GameState.save_game()   # persist removal immediately
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

	# ══════════════════════════════════════════════════════════════════════════
	#  LEGACY & DYNASTY SECTION
	# ══════════════════════════════════════════════════════════════════════════
	vbox.add_child(RimvaleUtils.separator())
	vbox.add_child(RimvaleUtils.label("LEGACY & DYNASTY", 18, Color(0.75, 0.55, 0.90)))
	var legacy_desc := RimvaleUtils.label(
		"Track your family line, inherited bonuses, and legendary items passed down through generations.",
		12, RimvaleColors.TEXT_GRAY)
	legacy_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(legacy_desc)

	# Family Tree Display
	var family_card := PanelContainer.new()
	family_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var family_sb := StyleBoxFlat.new()
	family_sb.bg_color = Color(0.10, 0.08, 0.15)
	family_sb.border_color = Color(0.75, 0.55, 0.90, 0.45)
	family_sb.set_border_width_all(1)
	family_sb.set_corner_radius_all(6)
	family_sb.set_content_margin_all(12)
	family_card.add_theme_stylebox_override("panel", family_sb)
	vbox.add_child(family_card)

	var family_vbox := VBoxContainer.new()
	family_vbox.add_theme_constant_override("separation", 8)
	family_card.add_child(family_vbox)

	var gen_count: int = int(GameState.legacy_data.get("generations", 0))
	family_vbox.add_child(RimvaleUtils.label("Generations: %d" % gen_count, 14, Color(0.75, 0.55, 0.90)))

	var traits_array: Array = GameState.legacy_data.get("bloodline_traits", [])
	if traits_array.size() > 0:
		var trait_txt: String = "Bloodline Traits: " + ", ".join(traits_array)
		var trait_lbl := RimvaleUtils.label(trait_txt, 12, RimvaleColors.TEXT_WHITE)
		trait_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		family_vbox.add_child(trait_lbl)

	var heirlooms_array: Array = GameState.legacy_data.get("heirlooms", [])
	if heirlooms_array.size() > 0:
		var heir_txt: String = "Heirlooms: " + ", ".join(heirlooms_array)
		var heir_lbl := RimvaleUtils.label(heir_txt, 12, RimvaleColors.GOLD)
		heir_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		family_vbox.add_child(heir_lbl)

	var achievements_array: Array = GameState.legacy_data.get("family_achievements", [])
	if achievements_array.size() > 0:
		family_vbox.add_child(RimvaleUtils.label("Family Achievements:", 12, RimvaleColors.HP_GREEN))
		for achievement in achievements_array:
			var ach_lbl := RimvaleUtils.label("  • " + str(achievement), 11, RimvaleColors.TEXT_GRAY)
			ach_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			family_vbox.add_child(ach_lbl)

	# Retire Hero section (if a character is selected and level 10+)
	if GameState.selected_hero_handle >= 0 and GameState.selected_hero_handle in GameState.collection:
		var char_dict = RimvaleAPI.engine.get_char_dict(GameState.selected_hero_handle)
		if char_dict != null and int(char_dict.get("level", 1)) >= 10:
			vbox.add_child(RimvaleUtils.spacer(12))
			var retire_card := PanelContainer.new()
			retire_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var retire_sb := StyleBoxFlat.new()
			retire_sb.bg_color = Color(0.15, 0.10, 0.10)
			retire_sb.border_color = Color(0.90, 0.30, 0.20, 0.45)
			retire_sb.set_border_width_all(1)
			retire_sb.set_corner_radius_all(6)
			retire_sb.set_content_margin_all(12)
			retire_card.add_theme_stylebox_override("panel", retire_sb)
			vbox.add_child(retire_card)

			var retire_vbox := VBoxContainer.new()
			retire_vbox.add_theme_constant_override("separation", 8)
			retire_card.add_child(retire_vbox)

			var hero_name: String = RimvaleAPI.engine.get_character_name(GameState.selected_hero_handle)
			var hero_level: int = int(char_dict.get("level", 1))
			retire_vbox.add_child(RimvaleUtils.label(
				"Retire %s (Level %d)" % [hero_name, hero_level], 14, Color(0.90, 0.30, 0.20)))

			var retire_desc := RimvaleUtils.label(
				"Archive this legendary hero and create an heir inheriting bonuses, items, and divine echoes.",
				11, RimvaleColors.TEXT_GRAY)
			retire_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			retire_vbox.add_child(retire_desc)

			var retire_btn = RimvaleUtils.button("Retire Hero & Create Heir", Color(0.90, 0.30, 0.20), 40, 13)
			var cap_handle: int = GameState.selected_hero_handle
			var cap_vbox_ret: VBoxContainer = vbox
			retire_btn.pressed.connect(func():
				var result: Dictionary = GameState.retire_hero(cap_handle)
				_populate_base_tab(cap_vbox_ret)
			)
			retire_vbox.add_child(retire_btn)

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
	# ── 3D world-map camera animation ────────────────────────────────────────
	if _ow_cam_animating:
		_ow_cam_t += delta * 2.2
		if _ow_cam_t >= 1.0:
			_ow_cam_t = 1.0
			_ow_cam_animating = false
			_ow_cam_look_target = _ow_cam_to_look
		var t: float = _ow_cam_t * _ow_cam_t * (3.0 - 2.0 * _ow_cam_t)  # ease-in-out
		if _ow_camera:
			_ow_camera.position = _ow_cam_from_pos.lerp(_ow_cam_to_pos, t)
			var look: Vector3 = _ow_cam_from_look.lerp(_ow_cam_to_look, t)
			_ow_camera.look_at(look, Vector3.UP)
	if _ow_label_overlay and _ow_camera and _ow_viewport:
		_ow_update_labels()

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

	var hbox = HBoxContainer.new()
	hbox.anchor_left = 0.0; hbox.anchor_top = 0.0
	hbox.anchor_right = 1.0; hbox.anchor_bottom = 1.0
	hbox.add_theme_constant_override("separation", 0)
	_overworld_panel.add_child(hbox)

	# ── LEFT: 3D Terrain Map ────────────────────────────────────────────────
	var map_col = VBoxContainer.new()
	map_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_col.size_flags_stretch_ratio = 2.0
	map_col.add_theme_constant_override("separation", 0)
	hbox.add_child(map_col)

	# Title strip
	var title_panel = PanelContainer.new()
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.06, 0.04, 0.12, 1.0)
	title_style.content_margin_left = 12; title_style.content_margin_right = 12
	title_style.content_margin_top = 8;   title_style.content_margin_bottom = 8
	title_panel.add_theme_stylebox_override("panel", title_style)
	var title_hbox = HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 10)
	title_panel.add_child(title_hbox)
	title_hbox.add_child(RimvaleUtils.label("🌐", 20, RimvaleColors.GOLD))
	title_hbox.add_child(RimvaleUtils.label("RIMVALE — World Terrain", 18, RimvaleColors.ACCENT))
	var spacer = Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(spacer)
	title_hbox.add_child(RimvaleUtils.label("Click a beacon to explore.", 11, RimvaleColors.TEXT_GRAY))
	map_col.add_child(title_panel)

	# 3D map container
	_ow_map_container = Control.new()
	_ow_map_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ow_map_container.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_ow_map_container.clip_contents = true
	map_col.add_child(_ow_map_container)

	_ow_svc = SubViewportContainer.new()
	_ow_svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ow_svc.stretch = true
	_ow_map_container.add_child(_ow_svc)

	_ow_viewport = SubViewport.new()
	_ow_viewport.size = Vector2i(1024, 768)
	_ow_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_ow_viewport.transparent_bg = false
	_ow_svc.add_child(_ow_viewport)

	# ── 3D scene ────────────────────────────────────────────────────────────
	_ow_world_root = Node3D.new()
	_ow_world_root.name = "WorldMap3D"
	_ow_viewport.add_child(_ow_world_root)

	# Environment
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.04, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.14, 0.28)
	env.ambient_light_energy = 0.7
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.12
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.06, 0.14)
	env.fog_density = 0.006
	env.fog_aerial_perspective = 0.5
	env_node.environment = env
	_ow_world_root.add_child(env_node)

	# Camera
	_ow_camera = Camera3D.new()
	_ow_camera.name = "WorldMapCam"
	_ow_camera.fov = 50.0
	_ow_camera.near = 0.1
	_ow_camera.far = 200.0
	_ow_camera.current = true
	_ow_world_root.add_child(_ow_camera)
	_ow_camera.position = Vector3(0, 28, 14)
	_ow_camera.look_at(Vector3(0, 0, -2), Vector3.UP)

	# Main sunlight
	var sun = DirectionalLight3D.new()
	sun.light_color = Color(0.92, 0.87, 0.97)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	_ow_world_root.add_child(sun)

	# Fill light
	var fill = DirectionalLight3D.new()
	fill.light_color = Color(0.22, 0.15, 0.38)
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(30.0, -140.0, 0.0)
	_ow_world_root.add_child(fill)

	# Terrain mesh
	_ow_world_root.add_child(_ow_build_terrain())

	# Water plane
	_ow_world_root.add_child(_ow_build_water())

	# Region beacon markers
	_ow_build_region_markers()

	# 2D label overlay (projected from 3D)
	_ow_label_overlay = Control.new()
	_ow_label_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ow_label_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ow_map_container.add_child(_ow_label_overlay)
	_ow_build_label_overlay()

	# Back button (visible when zoomed)
	_ow_back_btn = Button.new()
	_ow_back_btn.text = "◀ World View"
	_ow_back_btn.flat = false
	_ow_back_btn.position = Vector2(12, 12)
	_ow_back_btn.custom_minimum_size = Vector2(130, 32)
	_ow_back_btn.visible = false
	_ow_back_btn.add_theme_font_size_override("font_size", 12)
	var back_st = StyleBoxFlat.new()
	back_st.bg_color = Color(0.10, 0.08, 0.18, 0.90)
	back_st.border_color = RimvaleColors.ACCENT
	back_st.set_border_width_all(1)
	back_st.set_corner_radius_all(4)
	back_st.content_margin_left = 8; back_st.content_margin_right = 8
	_ow_back_btn.add_theme_stylebox_override("normal", back_st)
	_ow_back_btn.add_theme_color_override("font_color", RimvaleColors.ACCENT)
	_ow_back_btn.pressed.connect(_ow_zoom_out)
	_ow_map_container.add_child(_ow_back_btn)

	# Click handling
	_ow_svc.gui_input.connect(_ow_on_map_input)

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

	var cur: String = GameState.current_region
	if cur == "": cur = "plains"
	_overworld_focus_region(cur)


# ── 3D Terrain Generation ────────────────────────────────────────────────────

const OW_GRID := 80
const OW_HALF := 16.0

func _ow_region_world_pos(region: Dictionary) -> Vector3:
	var p: Vector2 = region["pos"]
	return Vector3((p.x - 0.5) * OW_HALF * 2.0, 0.0, (p.y - 0.5) * OW_HALF * 2.0)

func _ow_terrain_params(region_id: String) -> Array:
	# [base_height, noise_amplitude, ground_color, highlight_color]
	match region_id:
		"plains":    return [0.35, 0.12, Color(0.28, 0.48, 0.16), Color(0.40, 0.60, 0.22)]
		"peaks":     return [3.2,  1.4,  Color(0.60, 0.65, 0.75), Color(0.80, 0.88, 0.95)]
		"shadows":   return [0.15, 0.30, Color(0.18, 0.10, 0.28), Color(0.30, 0.18, 0.45)]
		"glass":     return [0.55, 0.08, Color(0.48, 0.68, 0.78), Color(0.65, 0.85, 0.95)]
		"isles":     return [0.08, 0.30, Color(0.14, 0.38, 0.45), Color(0.22, 0.55, 0.65)]
		"metro":     return [0.45, 0.04, Color(0.50, 0.42, 0.20), Color(0.65, 0.55, 0.25)]
		"astral":    return [0.9,  0.65, Color(0.32, 0.18, 0.50), Color(0.50, 0.30, 0.70)]
		"terminus":  return [2.6,  0.55, Color(0.28, 0.45, 0.65), Color(0.40, 0.60, 0.85)]
		"titans":    return [1.4,  0.65, Color(0.52, 0.22, 0.10), Color(0.70, 0.35, 0.15)]
		"sublimini": return [-0.3, 0.45, Color(0.40, 0.06, 0.10), Color(0.60, 0.12, 0.18)]
		_:           return [0.0,  0.1,  Color(0.12, 0.12, 0.12), Color(0.20, 0.20, 0.20)]

func _ow_noise(x: float, z: float) -> float:
	var v: float = 0.0
	v += sin(x * 1.7 + 0.3) * cos(z * 1.3 + 0.7) * 0.45
	v += sin(x * 3.1 - z * 2.4 + 1.2) * 0.25
	v += cos(x * 5.7 + z * 4.8 - 0.5) * 0.15
	v += sin(x * 8.3 + 1.1) * cos(z * 7.2 - 0.9) * 0.10
	v += sin(x * 13.0 - z * 11.0 + 2.0) * 0.05
	return v

func _ow_is_sublimini_unlocked() -> bool:
	# Sublimini requires all 9 region badges
	var badge_count: int = 0
	for r in OVERWORLD_REGIONS:
		var b: String = str(r.get("badge", ""))
		if not b.is_empty() and b in GameState.story_earned_badges:
			badge_count += 1
	return badge_count >= 9

func _ow_sample_terrain(uv_x: float, uv_z: float) -> Array:
	var wx: float = (uv_x - 0.5) * OW_HALF * 2.0
	var wz: float = (uv_z - 0.5) * OW_HALF * 2.0
	var ocean_col := Color(0.04, 0.08, 0.22)

	# Find closest region (skip sublimini — it's a floating island)
	var best_id: String = ""
	var best_dist: float = 999.0
	var second_dist: float = 999.0
	for r in OVERWORLD_REGIONS:
		if str(r["id"]) == "sublimini": continue
		var p: Vector2 = r["pos"]
		var dx: float = uv_x - p.x
		var dz: float = uv_z - p.y
		var d: float = sqrt(dx * dx + dz * dz)
		if d < best_dist:
			second_dist = best_dist
			best_dist = d
			best_id = str(r["id"])
		elif d < second_dist:
			second_dist = d

	var params: Array = _ow_terrain_params(best_id)
	var base_h: float = params[0]
	var noise_amp: float = params[1]
	var col: Color = params[2]
	var col_hi: Color = params[3]

	var n: float = _ow_noise(wx, wz)
	var height: float = base_h + n * noise_amp
	var col_t: float = clampf((n + 1.0) * 0.5, 0.0, 1.0)
	var final_col: Color = col.lerp(col_hi, col_t * 0.4)

	# ── Water channels ──────────────────────────────────────────────────────
	# 1. Horizontal channel: western islands (Titans) vs southern islands (Isles)
	var ch1_dist: float = absf(uv_z - 0.77)
	if ch1_dist < 0.06 and best_dist > 0.10:
		var ch1_t: float = (1.0 - clampf(ch1_dist / 0.06, 0.0, 1.0)) * 0.90
		height = lerpf(height, -0.6, ch1_t)
		final_col = final_col.lerp(ocean_col, ch1_t)

	# 2. Vertical channel: western islands (Glass/Titans x<0.30) vs mainland (x>0.44)
	#    Only applies in the mainland latitude band (y 0.15 to 0.58)
	if uv_z > 0.12 and uv_z < 0.72:
		var ch2_dist: float = absf(uv_x - 0.33)
		if ch2_dist < 0.24 and best_dist > 0.08:
			var ch2_t: float = (1.0 - clampf(ch2_dist / 0.24, 0.0, 1.0)) * 0.85
			height = lerpf(height, -0.6, ch2_t)
			final_col = final_col.lerp(ocean_col, ch2_t)

	# 3. Channel isolating Terminus Volarus (northeast island, x>0.78, y<0.28)
	if uv_x > 0.62 and uv_z < 0.32:
		var ch3_dist: float = absf(uv_x - 0.74)
		if ch3_dist < 0.10 and best_dist > 0.08:
			var ch3_t: float = (1.0 - clampf(ch3_dist / 0.10, 0.0, 1.0)) * 0.85
			height = lerpf(height, -0.6, ch3_t)
			final_col = final_col.lerp(ocean_col, ch3_t)

	# 5. Central bay — carves horseshoe shape into the mainland
	var bay_cx: float = 0.40
	var bay_top_z: float = 0.30
	var bay_bot_z: float = 0.64
	if uv_z > bay_top_z and uv_z < bay_bot_z:
		var progress: float = (uv_z - bay_top_z) / (bay_bot_z - bay_top_z)
		var half_w: float = 0.04 + progress * 0.13
		var dx_bay: float = absf(uv_x - bay_cx)
		if dx_bay < half_w and best_dist > 0.12:
			var inner_t: float = 1.0 - clampf(dx_bay / half_w, 0.0, 1.0)
			var top_fade: float = clampf((uv_z - bay_top_z) / 0.06, 0.0, 1.0)
			var bay_t: float = inner_t * top_fade * 0.88
			height = lerpf(height, -0.6, bay_t)
			final_col = final_col.lerp(ocean_col, bay_t)

	# 4. Vertical channel between Isles (x~0.24) and Astral Tear (x~0.78) in southern ocean
	if uv_z > 0.68:
		var ch4_dist: float = absf(uv_x - 0.51)
		if ch4_dist < 0.10 and best_dist > 0.12:
			var ch4_t: float = (1.0 - clampf(ch4_dist / 0.10, 0.0, 1.0)) * 0.80
			height = lerpf(height, -0.6, ch4_t)
			final_col = final_col.lerp(ocean_col, ch4_t)

	# Continent edge fade to ocean
	var edge_x: float = 1.0 - absf(uv_x - 0.5) * 2.3
	var edge_z: float = 1.0 - absf(uv_z - 0.5) * 2.0
	var continent: float = clampf(minf(edge_x, edge_z), -0.5, 1.0)
	if continent < 0.25:
		var ocean_t: float = 1.0 - clampf(continent / 0.25, 0.0, 1.0)
		height = lerpf(height, -0.6, ocean_t)
		final_col = final_col.lerp(ocean_col, ocean_t)

	# Too far from any region → ocean (per-region land radii)
	var ocean_thresh: float = 0.18
	if best_id == "metro":
		ocean_thresh = 0.09
	elif best_id == "shadows":
		ocean_thresh = 0.24
	elif best_id == "terminus":
		ocean_thresh = 0.23
	elif best_id == "peaks":
		ocean_thresh = 0.28
	elif best_id == "plains":
		ocean_thresh = 0.15
	if best_dist > ocean_thresh:
		var far_t: float = clampf((best_dist - ocean_thresh) / 0.08, 0.0, 1.0)
		height = lerpf(height, -0.6, far_t)
		final_col = final_col.lerp(ocean_col, far_t)

	return [height, final_col]

func _ow_build_terrain() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var grid: Array = []
	for gz in range(OW_GRID + 1):
		var row: Array = []
		for gx in range(OW_GRID + 1):
			row.append(_ow_sample_terrain(float(gx) / float(OW_GRID), float(gz) / float(OW_GRID)))
		grid.append(row)

	var step: float = OW_HALF * 2.0 / float(OW_GRID)
	for gz in range(OW_GRID):
		for gx in range(OW_GRID):
			var x0: float = -OW_HALF + gx * step
			var x1: float = x0 + step
			var z0: float = -OW_HALF + gz * step
			var z1: float = z0 + step

			var h00: float = grid[gz][gx][0];     var c00: Color = grid[gz][gx][1]
			var h10: float = grid[gz][gx + 1][0];  var c10: Color = grid[gz][gx + 1][1]
			var h01: float = grid[gz + 1][gx][0];  var c01: Color = grid[gz + 1][gx][1]
			var h11: float = grid[gz + 1][gx + 1][0]; var c11: Color = grid[gz + 1][gx + 1][1]

			st.set_color(c00); st.add_vertex(Vector3(x0, h00, z0))
			st.set_color(c10); st.add_vertex(Vector3(x1, h10, z0))
			st.set_color(c01); st.add_vertex(Vector3(x0, h01, z1))

			st.set_color(c10); st.add_vertex(Vector3(x1, h10, z0))
			st.set_color(c11); st.add_vertex(Vector3(x1, h11, z1))
			st.set_color(c01); st.add_vertex(Vector3(x0, h01, z1))

	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.82
	mat.metallic = 0.05
	mi.material_override = mat
	return mi

func _ow_build_water() -> MeshInstance3D:
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(OW_HALF * 2.5, OW_HALF * 2.5)
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = water_mesh
	mi.position = Vector3(0, -0.15, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.14, 0.32, 0.80)
	mat.roughness = 0.15
	mat.metallic = 0.40
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.03, 0.08, 0.20)
	mat.emission_energy_multiplier = 0.5
	mi.material_override = mat
	return mi

func _ow_build_region_markers() -> void:
	_ow_region_markers.clear()
	for region in OVERWORLD_REGIONS:
		var rid: String = str(region["id"])
		var accent: Color = region.get("accent", RimvaleColors.ACCENT)
		var wpos: Vector3 = _ow_region_world_pos(region)

		# Sublimini is a special floating island — handled separately
		if rid == "sublimini":
			_ow_build_sublimini_island(region)
			continue

		var p: Vector2 = region["pos"]
		var sample: Array = _ow_sample_terrain(p.x, p.y)
		var wy: float = maxf(sample[0], 0.0) + 0.1

		var marker := Node3D.new()
		marker.name = "Marker_" + rid
		marker.position = Vector3(wpos.x, wy, wpos.z)

		# Glowing pillar
		var pillar_mesh := CylinderMesh.new()
		pillar_mesh.top_radius = 0.12
		pillar_mesh.bottom_radius = 0.22
		pillar_mesh.height = 1.8
		var pillar := MeshInstance3D.new()
		pillar.mesh = pillar_mesh
		pillar.position.y = 0.9
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(accent.r, accent.g, accent.b, 0.75)
		pmat.emission_enabled = true
		pmat.emission = accent
		pmat.emission_energy_multiplier = 2.5
		pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pmat.roughness = 0.2
		pillar.material_override = pmat
		marker.add_child(pillar)

		# Crystal orb on top
		var cap_mesh := SphereMesh.new()
		cap_mesh.radius = 0.20
		cap_mesh.height = 0.40
		var cap := MeshInstance3D.new()
		cap.mesh = cap_mesh
		cap.position.y = 1.9
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = accent
		cmat.emission_enabled = true
		cmat.emission = accent
		cmat.emission_energy_multiplier = 4.0
		cmat.roughness = 0.1
		cap.material_override = cmat
		marker.add_child(cap)

		# Point light
		var light := OmniLight3D.new()
		light.light_color = accent
		light.light_energy = 2.0
		light.omni_range = 5.0
		light.position.y = 1.2
		light.shadow_enabled = false
		marker.add_child(light)

		# Ground ring
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 0.8
		ring_mesh.bottom_radius = 0.8
		ring_mesh.height = 0.05
		var ring := MeshInstance3D.new()
		ring.mesh = ring_mesh
		ring.position.y = 0.03
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(accent.r, accent.g, accent.b, 0.35)
		rmat.emission_enabled = true
		rmat.emission = accent
		rmat.emission_energy_multiplier = 1.0
		rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = rmat
		marker.add_child(ring)

		_ow_world_root.add_child(marker)
		_ow_region_markers[rid] = marker


func _ow_build_sublimini_island(region: Dictionary) -> void:
	# Sublimini Dominus — a floating island high above the map center.
	# Only visible when all 9 region badges are earned (unlocked).
	var accent: Color = region.get("accent", RimvaleColors.ACCENT)
	var unlocked: bool = _ow_is_sublimini_unlocked()

	var island := Node3D.new()
	island.name = "Sublimini_Island"
	# Float above the northern edge of the map
	island.position = Vector3(0.0, 12.0, -15.0)
	island.visible = unlocked

	# Floating rock platform — jagged inverted cone shape
	var rock_mesh := CylinderMesh.new()
	rock_mesh.top_radius = 2.5
	rock_mesh.bottom_radius = 0.6
	rock_mesh.height = 2.0
	var rock := MeshInstance3D.new()
	rock.mesh = rock_mesh
	rock.position.y = -1.0
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.15, 0.05, 0.08)
	rock_mat.roughness = 0.9
	rock_mat.metallic = 0.1
	rock.material_override = rock_mat
	island.add_child(rock)

	# Surface layer — dark crimson terrain
	var surface_mesh := CylinderMesh.new()
	surface_mesh.top_radius = 2.5
	surface_mesh.bottom_radius = 2.5
	surface_mesh.height = 0.15
	var surface := MeshInstance3D.new()
	surface.mesh = surface_mesh
	surface.position.y = 0.0
	var surf_mat := StandardMaterial3D.new()
	surf_mat.albedo_color = Color(0.35, 0.06, 0.10)
	surf_mat.emission_enabled = true
	surf_mat.emission = Color(0.30, 0.04, 0.08)
	surf_mat.emission_energy_multiplier = 0.5
	surf_mat.roughness = 0.7
	surface.material_override = surf_mat
	island.add_child(surface)

	# Void eye — pulsing dark sphere at center
	var void_mesh := SphereMesh.new()
	void_mesh.radius = 0.6
	void_mesh.height = 1.2
	var void_orb := MeshInstance3D.new()
	void_orb.mesh = void_mesh
	void_orb.position.y = 0.8
	var void_mat := StandardMaterial3D.new()
	void_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.9)
	void_mat.emission_enabled = true
	void_mat.emission = accent
	void_mat.emission_energy_multiplier = 6.0
	void_mat.roughness = 0.0
	void_mat.metallic = 1.0
	void_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	void_orb.material_override = void_mat
	island.add_child(void_orb)

	# Crimson beacon pillar
	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.08
	pillar_mesh.bottom_radius = 0.15
	pillar_mesh.height = 2.0
	var pillar := MeshInstance3D.new()
	pillar.mesh = pillar_mesh
	pillar.position.y = 1.8
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(accent.r, accent.g, accent.b, 0.70)
	pmat.emission_enabled = true
	pmat.emission = accent
	pmat.emission_energy_multiplier = 3.0
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pillar.material_override = pmat
	island.add_child(pillar)

	# Ominous red light
	var light := OmniLight3D.new()
	light.light_color = accent
	light.light_energy = 5.0
	light.omni_range = 12.0
	light.position.y = 1.5
	light.shadow_enabled = true
	island.add_child(light)

	# Chains hanging down (thin cylinders angled outward)
	for ci in range(4):
		var chain_angle: float = (float(ci) / 4.0) * TAU
		var chain_mesh := CylinderMesh.new()
		chain_mesh.top_radius = 0.03
		chain_mesh.bottom_radius = 0.03
		chain_mesh.height = 6.0
		var chain := MeshInstance3D.new()
		chain.mesh = chain_mesh
		chain.position = Vector3(cos(chain_angle) * 1.2, -4.0, sin(chain_angle) * 1.2)
		chain.rotation_degrees = Vector3(sin(chain_angle) * 15.0, 0, cos(chain_angle) * 15.0)
		var ch_mat := StandardMaterial3D.new()
		ch_mat.albedo_color = Color(0.20, 0.08, 0.12, 0.50)
		ch_mat.emission_enabled = true
		ch_mat.emission = Color(0.30, 0.05, 0.08)
		ch_mat.emission_energy_multiplier = 1.0
		ch_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		chain.material_override = ch_mat
		island.add_child(chain)

	_ow_world_root.add_child(island)
	_ow_region_markers["sublimini"] = island


# ── 2D Label Overlay (projected from 3D) ─────────────────────────────────────

func _ow_build_label_overlay() -> void:
	_ow_region_label_nodes.clear()
	for region in OVERWORLD_REGIONS:
		var rid: String = str(region["id"])
		# Sublimini label only shown when unlocked
		if rid == "sublimini" and not _ow_is_sublimini_unlocked():
			continue
		var accent: Color = region.get("accent", RimvaleColors.ACCENT)

		var lbl_panel := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.05, 0.03, 0.10, 0.75)
		st.border_color = Color(accent.r, accent.g, accent.b, 0.50)
		st.set_border_width_all(1)
		st.set_corner_radius_all(3)
		st.content_margin_left = 6; st.content_margin_right = 6
		st.content_margin_top = 2;  st.content_margin_bottom = 2
		lbl_panel.add_theme_stylebox_override("panel", st)
		lbl_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var lbl_hbox := HBoxContainer.new()
		lbl_hbox.add_theme_constant_override("separation", 4)
		lbl_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl_panel.add_child(lbl_hbox)

		var icon_lbl := Label.new()
		icon_lbl.text = str(region["icon"])
		icon_lbl.add_theme_font_size_override("font_size", 14)
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl_hbox.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.text = str(region["name"])
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", accent)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl_hbox.add_child(name_lbl)

		_ow_label_overlay.add_child(lbl_panel)
		_ow_region_label_nodes[rid] = lbl_panel

func _ow_update_labels() -> void:
	if not _ow_camera or not _ow_viewport or not _ow_map_container: return
	var vp_size: Vector2 = Vector2(_ow_viewport.size)
	var cs: Vector2 = _ow_map_container.size

	for region in OVERWORLD_REGIONS:
		var rid: String = str(region["id"])
		if not _ow_region_label_nodes.has(rid): continue
		var panel: Control = _ow_region_label_nodes[rid]

		# Hide non-focused labels when zoomed
		if _ow_zoomed_region != "" and rid != _ow_zoomed_region:
			panel.visible = false
			continue

		var wpos: Vector3 = Vector3.ZERO
		if _ow_region_markers.has(rid):
			if rid == "sublimini":
				wpos = _ow_region_markers[rid].global_position + Vector3(0, 3.5, 0)
			else:
				wpos = _ow_region_markers[rid].global_position + Vector3(0, 2.2, 0)

		if not _ow_camera.is_position_behind(wpos):
			var sp: Vector2 = _ow_camera.unproject_position(wpos)
			sp.x = sp.x * cs.x / vp_size.x
			sp.y = sp.y * cs.y / vp_size.y
			panel.position = Vector2(sp.x - panel.size.x * 0.5, sp.y - panel.size.y)
			panel.visible = true
		else:
			panel.visible = false

	for sub_data in _ow_subregion_label_nodes:
		var sub_panel: Control = sub_data["panel"]
		var sub_pos: Vector3 = sub_data["pos"]
		if not _ow_camera.is_position_behind(sub_pos):
			var sp: Vector2 = _ow_camera.unproject_position(sub_pos)
			sp.x = sp.x * cs.x / vp_size.x
			sp.y = sp.y * cs.y / vp_size.y
			sub_panel.position = Vector2(sp.x - sub_panel.size.x * 0.5, sp.y - sub_panel.size.y)
			sub_panel.visible = true
		else:
			sub_panel.visible = false


# ── Camera Control ───────────────────────────────────────────────────────────

func _ow_animate_camera(to_pos: Vector3, to_look: Vector3) -> void:
	if _ow_camera == null: return
	_ow_cam_from_pos = _ow_camera.position
	_ow_cam_from_look = _ow_camera.position + _ow_camera.basis * Vector3(0, 0, -20)
	_ow_cam_to_pos = to_pos
	_ow_cam_to_look = to_look
	_ow_cam_t = 0.0
	_ow_cam_animating = true

func _ow_zoom_to_region(rid: String) -> void:
	_ow_zoomed_region = rid
	if _ow_back_btn: _ow_back_btn.visible = true

	var region: Dictionary = _overworld_find_region(rid)
	if region.is_empty(): return

	if rid == "sublimini":
		# Sublimini is a floating island above the northern edge of the map
		var island_pos := Vector3(0.0, 12.0, -15.0)
		_ow_animate_camera(
			Vector3(island_pos.x + 3.0, island_pos.y + 6.0, island_pos.z + 8.0),
			island_pos
		)
	else:
		var wpos: Vector3 = _ow_region_world_pos(region)
		var p: Vector2 = region["pos"]
		var sample: Array = _ow_sample_terrain(p.x, p.y)
		var th: float = maxf(sample[0], 0.0)
		_ow_animate_camera(
			Vector3(wpos.x + 2.0, th + 10.0, wpos.z + 7.0),
			Vector3(wpos.x, th, wpos.z)
		)

	_ow_clear_subregion_labels()
	_ow_build_subregion_labels(region)

func _ow_zoom_out() -> void:
	_ow_zoomed_region = ""
	if _ow_back_btn: _ow_back_btn.visible = false
	_ow_clear_subregion_labels()
	_ow_animate_camera(Vector3(0, 28, 14), Vector3(0, 0, -2))

func _ow_clear_subregion_labels() -> void:
	for sub_data in _ow_subregion_label_nodes:
		if sub_data.has("panel") and is_instance_valid(sub_data["panel"]):
			sub_data["panel"].queue_free()
	_ow_subregion_label_nodes.clear()

func _ow_build_subregion_labels(region: Dictionary) -> void:
	var subs: Array = region.get("subregions", [])
	var accent: Color = region.get("accent", RimvaleColors.ACCENT)
	var rid: String = str(region["id"])
	var center: Vector3
	var base_h: float
	if rid == "sublimini":
		center = Vector3(0.0, 12.0, -15.0)
		base_h = 12.0
	else:
		center = _ow_region_world_pos(region)
		var p: Vector2 = region["pos"]
		var sample: Array = _ow_sample_terrain(p.x, p.y)
		base_h = maxf(sample[0], 0.0)

	for si in range(subs.size()):
		var sub_name: String = str(subs[si])
		var angle: float = (float(si) / float(maxi(subs.size(), 1))) * TAU
		var radius: float = 2.5
		var sub_pos := Vector3(
			center.x + cos(angle) * radius,
			base_h + 0.5,
			center.z + sin(angle) * radius
		)

		var panel := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.08, 0.05, 0.14, 0.85)
		st.border_color = accent
		st.set_border_width_all(1)
		st.set_corner_radius_all(3)
		st.content_margin_left = 8; st.content_margin_right = 8
		st.content_margin_top = 3;  st.content_margin_bottom = 3
		panel.add_theme_stylebox_override("panel", st)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var lbl := Label.new()
		lbl.text = sub_name
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", accent)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(lbl)

		_ow_label_overlay.add_child(panel)
		_ow_subregion_label_nodes.append({"panel": panel, "pos": sub_pos})


# ── 3D Input Handling ────────────────────────────────────────────────────────

func _ow_on_map_input(event: InputEvent) -> void:
	if not _ow_camera or not _ow_viewport: return

	# ── Mouse button: start/end drag or click ────────────────────────────
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_ow_dragging = true
			_ow_drag_start = event.position
			_ow_drag_moved = false
		else:
			_ow_dragging = false
			if not _ow_drag_moved:
				# This was a click, not a drag — try to pick a region
				_ow_try_pick_region(event.position)
		return

	# ── Mouse motion while dragging: pan camera ─────────────────────────
	if event is InputEventMouseMotion and _ow_dragging:
		var delta: Vector2 = event.relative
		if delta.length() > 2.0:
			_ow_drag_moved = true
		if _ow_drag_moved and not _ow_cam_animating:
			# Pan speed scales with camera height (higher = faster pan)
			var cam_h: float = _ow_camera.position.y
			var speed: float = cam_h * 0.0035
			# Move camera and look target along the ground plane
			var right: Vector3 = _ow_camera.basis.x
			var forward: Vector3 = _ow_camera.basis.z
			# Project to XZ plane
			right.y = 0; right = right.normalized()
			forward.y = 0; forward = forward.normalized()
			var offset: Vector3 = -right * delta.x * speed - forward * delta.y * speed
			_ow_camera.position += offset
			_ow_cam_look_target += offset
			_ow_camera.look_at(_ow_cam_look_target, Vector3.UP)


func _ow_try_pick_region(mouse_pos: Vector2) -> void:
	var container_size: Vector2 = _ow_svc.size if _ow_svc else Vector2(1024, 768)
	var vp_size: Vector2 = Vector2(_ow_viewport.size)
	var scaled_pos := Vector2(
		mouse_pos.x * vp_size.x / container_size.x,
		mouse_pos.y * vp_size.y / container_size.y
	)

	var from: Vector3 = _ow_camera.project_ray_origin(scaled_pos)
	var dir: Vector3 = _ow_camera.project_ray_normal(scaled_pos)

	var best_rid: String = ""
	var best_dist: float = 3.0
	for region in OVERWORLD_REGIONS:
		var rid: String = str(region["id"])
		if not _ow_region_markers.has(rid): continue
		if rid == "sublimini" and not _ow_is_sublimini_unlocked(): continue
		var marker_pos: Vector3 = _ow_region_markers[rid].global_position + Vector3(0, 0.9, 0)
		var to_marker: Vector3 = marker_pos - from
		var proj: float = to_marker.dot(dir)
		if proj < 0: continue
		var closest: Vector3 = from + dir * proj
		var d: float = closest.distance_to(marker_pos)
		if d < best_dist:
			best_dist = d
			best_rid = rid

	if best_rid != "":
		_ow_zoom_to_region(best_rid)
		_overworld_focus_region(best_rid)


func _overworld_refresh_region_highlights() -> void:
	# Update 3D marker brightness and label styles based on game state
	# Toggle Sublimini floating island visibility
	if _ow_region_markers.has("sublimini"):
		_ow_region_markers["sublimini"].visible = _ow_is_sublimini_unlocked()

	for region in OVERWORLD_REGIONS:
		var rid: String = str(region["id"])
		var accent: Color = region.get("accent", RimvaleColors.ACCENT)
		var is_current: bool = GameState.current_region == rid
		var is_visited: bool = rid in GameState.visited_regions
		var badge: String = str(region.get("badge", ""))
		var has_badge: bool = (not badge.is_empty()) and badge in GameState.story_earned_badges

		# Adjust marker light intensity
		if _ow_region_markers.has(rid):
			var marker_node: Node3D = _ow_region_markers[rid]
			for child in marker_node.get_children():
				if child is OmniLight3D:
					child.light_energy = (
						4.0 if has_badge
						else 3.0 if is_current
						else 1.5 if is_visited
						else 1.0
					)

		# Update label styling
		if _ow_region_label_nodes.has(rid):
			var lp: PanelContainer = _ow_region_label_nodes[rid]
			var lst := StyleBoxFlat.new()
			lst.bg_color = (
				Color(0.20, 0.16, 0.05, 0.85) if has_badge
				else Color(0.12, 0.08, 0.18, 0.85) if is_current
				else Color(0.05, 0.03, 0.10, 0.75)
			)
			lst.border_color = Color(accent.r, accent.g, accent.b, 0.70 if is_current else 0.40)
			lst.set_border_width_all(1)
			lst.set_corner_radius_all(3)
			lst.content_margin_left = 6; lst.content_margin_right = 6
			lst.content_margin_top = 2;  lst.content_margin_bottom = 2
			lp.add_theme_stylebox_override("panel", lst)

			var lbl_hbox = lp.get_child(0)
			if lbl_hbox and lbl_hbox.get_child_count() >= 2:
				var name_lbl: Label = lbl_hbox.get_child(1) as Label
				var mk: String = ""
				if has_badge: mk = " 🏅"
				elif is_current: mk = " ●"
				elif is_visited: mk = " ·"
				name_lbl.text = str(region["name"]) + mk


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
	# m_data: [id, title, region, teaser, flavor, xp, is_boss, boss_name, boss_level, boss_apex_idx]
	var mid: String     = m_data[0]
	var mtitle: String  = m_data[1]
	var mregion: String = m_data[2]
	var mteaser: String = m_data[3]
	var mxp: int        = m_data[5]
	var is_boss: bool   = m_data[6]
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
	var cap_m_data: Array = m_data.duplicate()
	play_btn.pressed.connect(func():
		_on_story_mission_play(cap_m_data))
	actions.add_child(play_btn)

	# Debug auto-complete button
	if GameState.debug_mode and not completed:
		var auto_btn = RimvaleUtils.button("Auto ⚡", RimvaleColors.WARNING, 24, 10)
		auto_btn.custom_minimum_size = Vector2(60, 24)
		var cap_mid: String = mid
		var cap_mxp: int = mxp
		auto_btn.pressed.connect(func():
			_debug_auto_complete_mission(cap_mid, cap_mxp)
		)
		actions.add_child(auto_btn)

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

# ── Quest Board Tab ────────────────────────────────────────────────────────────

func _build_quests_tab(parent: Control) -> void:
	var tab_panel = RimvaleUtils.card(RimvaleColors.BG_DARK, RimvaleColors.DIVIDER, 0, 0)
	tab_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(tab_panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	tab_panel.add_child(vbox)

	# Header
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(header_hbox)

	var region_name: String = _get_region_display_name(GameState.current_region)
	header_hbox.add_child(RimvaleUtils.label(
		"⚔️  Quest Board — %s" % region_name, 18, RimvaleColors.ACCENT))

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	var generate_btn = RimvaleUtils.button("Generate New Quest", RimvaleColors.ACCENT, 50, 13)
	generate_btn.pressed.connect(_on_generate_quest)
	header_hbox.add_child(generate_btn)

	vbox.add_child(RimvaleUtils.separator())

	# Main content in two columns
	var content_hbox = HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(content_hbox)

	# Left column: Available quests
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 8)
	content_hbox.add_child(left_vbox)

	left_vbox.add_child(RimvaleUtils.label("Available Quests", 14, RimvaleColors.TEXT_WHITE))

	_quest_board_vbox = VBoxContainer.new()
	_quest_board_vbox.add_theme_constant_override("separation", 6)
	var quest_scroll = ScrollContainer.new()
	quest_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quest_scroll.add_child(_quest_board_vbox)
	left_vbox.add_child(quest_scroll)

	# Right column: Active quests
	var right_vbox = VBoxContainer.new()
	right_vbox.custom_minimum_size.x = 300
	right_vbox.add_theme_constant_override("separation", 8)
	content_hbox.add_child(right_vbox)

	right_vbox.add_child(RimvaleUtils.label("Active Quests (%d/3)" % GameState.active_quests.size(), 14, RimvaleColors.TEXT_WHITE))

	_quest_active_vbox = VBoxContainer.new()
	_quest_active_vbox.add_theme_constant_override("separation", 6)
	var active_scroll = ScrollContainer.new()
	active_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_scroll.add_child(_quest_active_vbox)
	right_vbox.add_child(active_scroll)

	# Initial refresh
	_refresh_quest_board()

func _refresh_quest_board() -> void:
	# Clear and rebuild available quests
	for child in _quest_board_vbox.get_children():
		child.queue_free()

	if _quest_board_quests.is_empty():
		_quest_board_vbox.add_child(RimvaleUtils.label(
			"No quests available. Generate new ones.", 11, RimvaleColors.TEXT_GRAY))
		return

	for quest in _quest_board_quests:
		var card = RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.DIVIDER, 6, 6)
		var cvbox = VBoxContainer.new()
		cvbox.add_theme_constant_override("separation", 4)
		card.add_child(cvbox)

		# Quest title and type
		var title_hbox = HBoxContainer.new()
		title_hbox.add_theme_constant_override("separation", 6)
		cvbox.add_child(title_hbox)

		var qtype: String = str(quest.get("type", "Standard"))
		title_hbox.add_child(RimvaleUtils.chip(qtype, true, 10))
		title_hbox.add_child(RimvaleUtils.label(str(quest.get("title", "Untitled")), 12, RimvaleColors.TEXT_WHITE))

		# Description
		var desc = RimvaleUtils.label(str(quest.get("description", "")), 9, RimvaleColors.TEXT_GRAY)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cvbox.add_child(desc)

		# Location
		cvbox.add_child(RimvaleUtils.label(
			"📍 %s" % str(quest.get("location", "Unknown")), 9, RimvaleColors.TEXT_LIGHT))

		# Difficulty and rewards row
		var info_hbox = HBoxContainer.new()
		info_hbox.add_theme_constant_override("separation", 8)
		cvbox.add_child(info_hbox)

		var difficulty: String = str(quest.get("difficulty", "Normal"))
		var diff_color: Color = RimvaleColors.TEXT_LIGHT
		match difficulty:
			"Easy": diff_color = Color(0.5, 1.0, 0.5)
			"Hard": diff_color = Color(1.0, 0.7, 0.5)
			"Dangerous": diff_color = Color(1.0, 0.3, 0.3)
		info_hbox.add_child(RimvaleUtils.label(difficulty, 9, diff_color))

		info_hbox.add_child(RimvaleUtils.label(
			"%d gold | %d xp" % [int(quest.get("reward_gold", 0)), int(quest.get("reward_xp", 0))],
			9, RimvaleColors.GOLD))

		# Objectives list
		var objectives: Array = quest.get("objectives", [])
		if not objectives.is_empty():
			cvbox.add_child(RimvaleUtils.label("Objectives:", 9, RimvaleColors.TEXT_LIGHT))
			for obj in objectives:
				cvbox.add_child(RimvaleUtils.label("  • %s" % str(obj), 8, RimvaleColors.TEXT_GRAY))

		# Accept button (disabled if 3 active quests)
		var accept_btn = RimvaleUtils.button("Accept Quest", RimvaleColors.ACCENT, 28, 10)
		accept_btn.disabled = GameState.active_quests.size() >= 3
		var quest_copy = quest.duplicate()
		accept_btn.pressed.connect(func():
			_on_accept_quest(quest_copy)
		)
		cvbox.add_child(accept_btn)
		_quest_board_vbox.add_child(card)

	_refresh_active_quests()

func _refresh_active_quests() -> void:
	# Clear and rebuild active quests
	for child in _quest_active_vbox.get_children():
		child.queue_free()

	if GameState.active_quests.is_empty():
		_quest_active_vbox.add_child(RimvaleUtils.label(
			"No active quests.", 11, RimvaleColors.TEXT_GRAY))
		return

	for i in range(GameState.active_quests.size()):
		var quest = GameState.active_quests[i]
		var card = RimvaleUtils.card(RimvaleColors.BG_CARD_DARK, RimvaleColors.DIVIDER, 6, 6)
		var cvbox = VBoxContainer.new()
		cvbox.add_theme_constant_override("separation", 3)
		card.add_child(cvbox)

		cvbox.add_child(RimvaleUtils.label(str(quest.get("title", "Untitled")), 11, RimvaleColors.ACCENT))

		# Objectives with checkboxes
		var objectives: Array = quest.get("objectives", [])
		var completed_count: int = int(quest.get("completed_objectives", 0))

		for j in range(objectives.size()):
			var is_completed: bool = j < completed_count
			var obj_text: String = ("✓ " if is_completed else "○ ") + str(objectives[j])
			var obj_color: Color = RimvaleColors.TEXT_GRAY if is_completed else RimvaleColors.TEXT_LIGHT
			cvbox.add_child(RimvaleUtils.label(obj_text, 8, obj_color))

		var progress_text: String = "%d/%d objectives" % [completed_count, objectives.size()]
		cvbox.add_child(RimvaleUtils.label(progress_text, 9, RimvaleColors.TEXT_GRAY))

		# Complete button (enabled when all objectives done)
		var complete_btn = RimvaleUtils.button("Complete", RimvaleColors.ACCENT, 20, 9)
		complete_btn.disabled = completed_count < objectives.size()
		complete_btn.pressed.connect(func():
			_on_complete_quest(i)
		)
		cvbox.add_child(complete_btn)
		_quest_active_vbox.add_child(card)

func _generate_fallback_quests() -> Array:
	# Fallback quest generation when WorldSystems is not available
	var quest_types = ["Bounty", "Delivery", "Escort", "Investigation", "Exploration"]
	var locations = ["Marketplace", "Forest", "Ruins", "Castle", "Underground"]
	var difficulties = ["Easy", "Normal", "Hard", "Dangerous"]

	var quests: Array = []
	for i in range(3):
		var qtype = quest_types[randi() % quest_types.size()]
		var location = locations[randi() % locations.size()]
		var difficulty = difficulties[randi() % difficulties.size()]
		var gold_reward = (i + 1) * 50
		var xp_reward = (i + 1) * 100

		quests.append({
			"id": "quest_%d_%d" % [GameState.game_day, i],
			"type": qtype,
			"title": "%s in %s" % [qtype, location],
			"description": "A quest awaits you in the %s." % location,
			"location": location,
			"difficulty": difficulty,
			"reward_gold": gold_reward,
			"reward_xp": xp_reward,
			"objectives": ["Travel to %s" % location, "Complete the task", "Return to quest board"],
		})
	return quests

func _on_accept_quest(quest: Dictionary) -> void:
	if GameState.active_quests.size() >= 3:
		return

	var quest_with_state = quest.duplicate()
	quest_with_state["completed_objectives"] = 0
	quest_with_state["accepted_on_day"] = GameState.game_day
	GameState.active_quests.append(quest_with_state)

	# Remove from board
	_quest_board_quests.erase(quest)
	GameState.save_game()
	_refresh_quest_board()

func _on_complete_quest(idx: int) -> void:
	if idx < 0 or idx >= GameState.active_quests.size():
		return

	var quest = GameState.active_quests[idx]
	var gold_reward: int = int(quest.get("reward_gold", 0))
	var xp_reward: int = int(quest.get("reward_xp", 0))

	GameState.earn_gold(gold_reward)
	GameState.player_xp += xp_reward
	GameState.check_level_up()

	var qid: String = str(quest.get("id", quest.get("title", "")))
	if qid != "" and qid not in GameState.completed_quest_ids:
		GameState.completed_quest_ids.append(qid)

	GameState.active_quests.remove_at(idx)
	GameState.save_game()
	_refresh_quest_board()

func _get_region_display_name(region_id: String) -> String:
	# Simple region name display helper
	match region_id:
		"plains": return "Plains"
		"forest": return "Forest"
		"mountain": return "Mountain"
		"swamp": return "Swamp"
		"desert": return "Desert"
		"coast": return "Coast"
		_: return region_id.capitalize()
