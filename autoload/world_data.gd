class_name WorldData

# Static utility class for Rimvale world data
# Contains factions, divine aspects, ACF hierarchy, and regional information

static func get_factions() -> Array:
	return [
		{
			"name": "Arcane Containment Foundation",
			"region": "The Metropolitan",
			"influence": "Safeguards reality from magical instability. Containment, artifact recovery, arcane anomaly suppression.",
			"territory_feature": "Magical items cannot trigger Overreach unless intentionally pushed. Passive containment fields stabilize spell matrices.",
			"ranks": [
				{"name": "Novice Seeker", "benefit": "Advantage on Arcane checks to identify anomalies, detect unstable magic 30ft 1/rest"},
				{"name": "Containment Agent", "benefit": "Arcane Seal 1/rest DC15, resistance to Overreach backlash"},
				{"name": "Senior Specialist", "benefit": "Suppress magical effect 15ft reaction 1/rest, +1 SP containment spells"},
				{"name": "Archmage Containment Director", "benefit": "Null zone 10ft 1min 1/rest, immunity to Overreach in ACF territory"}
			]
		},
		{
			"name": "The Circle of the Verdant Oak",
			"region": "Forest of SubEden",
			"influence": "Guardians of nature and primal magic, sacred groves, living ley lines.",
			"territory_feature": "+1 HP per hour rest, advantage on Survival checks involving plants/terrain.",
			"ranks": [
				{"name": "Initiate of the Grove", "benefit": "+1d4 Survival natural terrain, auto-identify herbs"},
				{"name": "Warden of the Wilds", "benefit": "Entangle foes DC13 1/rest, poison resistance"},
				{"name": "Druidic Elder", "benefit": "Speak with plants/beasts at will, +1 HP/hr rest everywhere"},
				{"name": "High Keeper of the Verdant Oak", "benefit": "Sanctuary grove 30ft 1hr 1/rest, 1d4 HP/round heal, advantage nature checks"}
			]
		},
		{
			"name": "The Order of the Crimson Blade",
			"region": "The Mortal Arena",
			"influence": "Warrior brotherhood, martial excellence, tournaments, legendary weapons.",
			"territory_feature": "+1d4 attack in duels, resistance to fear in combat.",
			"ranks": [
				{"name": "Initiate of the Blade", "benefit": "+1 attack in duels, challenge foe to duel 1/rest"},
				{"name": "Shadowstriker", "benefit": "Advantage initiative, +1d4 damage first attack"},
				{"name": "Bloodblade", "benefit": "At half HP +1d6 melee damage 1min, parry 1/short rest no AP"},
				{"name": "Crimson Lord", "benefit": "Crimson Challenge 1min disadvantage vs you +1d8 damage 1/rest"}
			]
		},
		{
			"name": "The Iron Legion",
			"region": "Vulcan Valley",
			"influence": "War machines, siegecraft, heavy armor, mercenary defenders.",
			"territory_feature": "Armor durability doubled, resistance to bludgeoning from environmental hazards.",
			"ranks": [
				{"name": "Iron Recruit", "benefit": "+1 AC heavy armor, repair 10 HP armor free/short rest"},
				{"name": "Legionnaire", "benefit": "Resistance bludgeoning non-magical, carry double weight"},
				{"name": "Iron Captain", "benefit": "Allies 10ft +1 AC, command ally extra reaction 1/rest"},
				{"name": "Warbringer", "benefit": "Siege Zone 30ft 1min 1/rest: +1 AC, +1d4 ranged, ignore difficult terrain, double damage to structures"}
			]
		},
		{
			"name": "The Guild of Shadows",
			"region": "The Shadows Beneath",
			"influence": "Espionage, illusion, subterfuge, underbellies of cities.",
			"territory_feature": "Advantage Sneak checks, move through crowds no penalty, illusion spells -1 SP.",
			"ranks": [
				{"name": "Rook", "benefit": "Advantage Sneak urban, hide in dim light free action"},
				{"name": "Shadowblade", "benefit": "Minor illusion 4SP or less 1/short rest, +1d4 damage from stealth"},
				{"name": "Nightlord", "benefit": "Teleport shadows 30ft 1/short rest, psychic resistance"},
				{"name": "Guildmaster of Shadows", "benefit": "Shadow veil 15ft 1min 1/rest invisibility allies, illusion spells -1 SP permanent"}
			]
		},
		{
			"name": "The Order of the Golden Dawn",
			"region": "City of Eternal Light",
			"influence": "Divine magic, celestial harmony, healing, temples.",
			"territory_feature": "Healing +1d4 HP, spiritual spells -1 SP, necrotic resistance.",
			"ranks": [
				{"name": "Acolyte of the Dawn", "benefit": "+1d4 healing spells, detect undead 30ft 1/rest"},
				{"name": "Knight of the Sun", "benefit": "Radiant +1 damage/die, necrotic resistance"},
				{"name": "Holy Sentinel", "benefit": "Shield ally from death 1/rest leave 1 HP, spiritual -1 SP"},
				{"name": "Lightbringer", "benefit": "Radiant aura 30ft 1min 1/rest: 1d6 heal/round, blind undead, fear immunity"}
			]
		},
		{
			"name": "The Silver Serpents",
			"region": "The Metropolitan (Upper Forty)",
			"influence": "Mercantile syndicate, trade routes, markets, economics.",
			"territory_feature": "Reroll failed Speechcraft 1/day, rare items 10% cheaper.",
			"ranks": [
				{"name": "Serpent Initiate", "benefit": "+1d4 Speechcraft, instant appraise"},
				{"name": "Silver Agent", "benefit": "Reroll Barter 2/day, +10% sell profit"},
				{"name": "Serpent Master", "benefit": "Trade favor 1/rest rare item/info/transport, charm resistance"},
				{"name": "Grandmaster of the Coil", "benefit": "Manipulate market prices 20% 1/rest, +2 all trade social checks"}
			]
		},
		{
			"name": "The Scholars of the Eternal Library",
			"region": "Eternal Library",
			"influence": "Knowledge, magical theory, historical truth, spell cataloging.",
			"territory_feature": "Take 10 on Arcane/Learnedness 1/short rest if familiar topic.",
			"ranks": [
				{"name": "Student of the Tome", "benefit": "+1d4 Arcane, auto-identify magic items"},
				{"name": "Lorekeeper", "benefit": "Record memory in tome 1/rest, share for advantage on related check"},
				{"name": "Archivist", "benefit": "Store one spell in tome, Arcane Seal rules"},
				{"name": "Grand Sage", "benefit": "Knowledge archive 30ft 1hr 1/rest, advantage Arcane/Learnedness all allies"}
			]
		},
		{
			"name": "The FlameWardens",
			"region": "Vulcan Valley",
			"influence": "Elemental fire, volcanic shrines, sacred flame, sanctified weapons.",
			"territory_feature": "Fire resistance, ignite objects no AP, fire spells +1 damage/die.",
			"ranks": [
				{"name": "Ember Recruit", "benefit": "Fire resistance, light fires no AP/SP"},
				{"name": "Flame Adept", "benefit": "Fire +1 damage/die, fire spell -2 SP min 1 1/short rest"},
				{"name": "Fire Marshal", "benefit": "Fire shield 15ft 1min 1/rest 1d4 fire to attackers, burn immunity"},
				{"name": "Grand Flamewarden", "benefit": "Pyre Field 20ft 2SP 1min: 2d6 fire enemies, +1d4 attack allies, fear resistance"}
			]
		},
		{
			"name": "The Storm Walkers",
			"region": "The Astral Tear",
			"influence": "Storms, astral phenomena, weather manipulation, sky spirits.",
			"territory_feature": "Immunity weather movement penalties, lightning +1d4 1/rest.",
			"ranks": [
				{"name": "Skybound", "benefit": "Weather movement immunity"},
				{"name": "Stormcaller", "benefit": "Lightning +1d4, fly 10ft in storms"},
				{"name": "Tempest Master", "benefit": "Summon storm 30ft 1min 1/rest 1d6 lightning/round, thunder resistance"},
				{"name": "Thunderlord", "benefit": "Chain Lightning 1/rest no SP, lightning +2d6 ignore resistance"}
			]
		}
	]

static func get_divine_aspects() -> Array:
	return [
		{
			"name": "Chaos",
			"tenets": [
				"Chaos is not mere destruction: it is the breath of possibility, the dance of entropy, and the fire that burns stagnation.",
				"Unchain the Pattern: Never allow tradition or routine to calcify into law.",
				"Celebrate the Unexpected: Treat unpredictability as sacred.",
				"Kindle Wildfire: Spread ideas that disrupt the status quo.",
				"Honor the Mad and the Misunderstood: Listen to those deemed irrational.",
				"Never Die the Same Way Twice: If you fall, rise changed."
			],
			"tiers": [
				{"tier_num": 1, "title": "Blessed Initiate of Chaos", "benefit": "+1d4 in unpredictable situations", "passive": "Reroll failed save 1/rest"},
				{"tier_num": 2, "title": "Divine Acolyte of Chaos", "benefit": "+1d6 random elemental damage (fire/lightning/acid/cold)", "passive": "Resistance to confusion/madness"},
				{"tier_num": 3, "title": "Celestial Champion of Chaos", "benefit": "Trigger overreach on creature casting within 30ft 1/rest", "passive": "Advantage vs control/suppression"},
				{"tier_num": 4, "title": "Ascendant Paragon of Chaos", "benefit": "Alter reality (terrain/weather/gravity) 30ft 1min 1/rest", "passive": "+1 SP unpredictable spells"},
				{"tier_num": 5, "title": "Echo of Chaos", "benefit": "Chaotic anomaly zone 30ft 1/rest, 50% overreach enemies, disadvantage enemies advantage allies", "passive": "Immune forced alignment, ignore 1 crit fail/day"}
			]
		},
		{
			"name": "Unity",
			"tenets": [
				"Unity is not conformity: it is the weaving of many into one, the harmony of difference.",
				"Mend What Is Broken: Seek reconciliation over revenge.",
				"Illuminate the Path: Be a beacon in darkness.",
				"Protect the Weave: Defend communities and relationships.",
				"Speak with Many Voices: Embrace diversity.",
				"Sacrifice for the Whole: When the many suffer, offer your strength."
			],
			"tiers": [
				{"tier_num": 1, "title": "Blessed Initiate of Unity", "benefit": "+1d4 Intuition/Speechcraft peaceful conflict", "passive": "Allies 10ft +1 saves vs fear"},
				{"tier_num": 2, "title": "Divine Acolyte of Unity", "benefit": "Healing +1d6 to allies below half HP", "passive": "Aura +1 Intuition"},
				{"tier_num": 3, "title": "Celestial Champion of Unity", "benefit": "Beacon of Light 30ft 1min absorb 20 damage/ally 1/rest", "passive": "Necrotic resistance, advantage vs corruption"},
				{"tier_num": 4, "title": "Ascendant Paragon of Unity", "benefit": "Spiritual spells -1 SP, revive fallen ally 1HP 1/rest", "passive": "Aura +1d4 saves 15ft"},
				{"tier_num": 5, "title": "Echo of Unity", "benefit": "Divine miracle 1/rest full heal 30ft, resurrect dead within 10min", "passive": "Immune fear/darkness, disrupt shadow magic 30ft"}
			]
		},
		{
			"name": "The Void",
			"tenets": [
				"The Void is not absence: it is the space between, the keeper of secrets.",
				"Guard the Threshold: Stand between extremes.",
				"Seek the Hidden Truth: Truth is buried beneath illusion.",
				"Honor the Forgotten: Remember the lost and unseen.",
				"Balance the Blade: Strike with purpose, protect without pride.",
				"Become the Shadow: Be present without being seen."
			],
			"tiers": [
				{"tier_num": 1, "title": "Blessed Initiate of The Void", "benefit": "Advantage Sneak/Intuition in dim light, auto-succeed sneak DC10 or lower", "passive": "See through magical darkness 30ft"},
				{"tier_num": 2, "title": "Divine Acolyte of The Void", "benefit": "Vanish into shadow 1min intangible 1/rest", "passive": "Psychic resistance, +1 SP illusion/shadow spells"},
				{"tier_num": 3, "title": "Celestial Champion of The Void", "benefit": "Shadow chains DC15 Speed restrained 1 round 1/rest", "passive": "Advantage Deception/Arcane hidden truths"},
				{"tier_num": 4, "title": "Ascendant Paragon of The Void", "benefit": "Cloak allies 15ft invisibility 1min 1/rest", "passive": "Immune charm/scrying, teleport shadows 30ft 3AP"},
				{"tier_num": 5, "title": "Echo of The Void", "benefit": "Veil of silence 60ft 1min blocks divination suppresses Unity magic", "passive": "Permanent invisibility in darkness, telepathy 60ft allies"}
			]
		}
	]

static func get_acf_hierarchy() -> Dictionary:
	return {
		"grand_overseer": [
			{"name": "Thalindra Vaelan", "lineage": "Elf", "role": "Grand Overseer", "region": "forest_of_subeden", "description": "An enigmatic Elf known for deep understanding of ancient magics and unyielding resolve."}
		],
		"council": [
			{"name": "Auron Velkari", "lineage": "Boreal Human", "role": "Archmage", "region": "argent_hall", "description": "Former monk turned sorcerer, expert in chaotic magic of the peaks."},
			{"name": "Nymara Aelaris", "lineage": "Abyssari", "role": "Archmage", "region": "lito", "description": "Deep-sea dweller who mastered water magic and oceanic artifacts."},
			{"name": "Oren Vos'Kor", "lineage": "Arcanite Human", "role": "Archmage", "region": "upper_forty", "description": "Rune-marked wizard specializing in urban magical threats."},
			{"name": "Seraphine", "lineage": "Echo-Touched", "role": "Archmage", "region": "the_darkness", "description": "Shadow sorceress born of nightmares and chaos echoes."},
			{"name": "Kaeldor Thorne", "lineage": "Tombwalker", "role": "Archmage", "region": "crypt_at_end_of_valley", "description": "Necromancer bound by ancient pacts walking between life and death."}
		],
		"wardens": [
			{"name": "Lyria Sunspear", "lineage": "Vulpin", "role": "Warden", "region": "gloamfen_hollow", "description": "Clever foxfolk ranger protecting vast open lands."},
			{"name": "Orlin Darkforge", "lineage": "Ferrusk", "role": "Warden", "region": "vulcan_valley", "description": "Biomechanical dwarf crafting powerful wards and binding weapons."},
			{"name": "Thalia Starseeker", "lineage": "Dreamer", "role": "Warden", "region": "arcane_collapse", "description": "Mystic gnome with deep connection to astral anomalies."}
		],
		"commanders": [
			{"name": "Elira Dorne", "lineage": "Elf", "role": "Commander", "region": "gloamfen_hollow", "description": "Battle-hardened strategist from SubEden."},
			{"name": "Torak Dreadmaw", "lineage": "Boreal Human", "role": "Commander", "region": "argent_hall", "description": "Raised among blizzards, slew a frost giant."},
			{"name": "Valin Torvesh", "lineage": "Arcanite Human", "role": "Commander", "region": "upper_forty", "description": "Master of urban tactics and intrigue."},
			{"name": "Selene Varros", "lineage": "Abyssari", "role": "Commander", "region": "lito", "description": "Former pirate queen turned containment officer."},
			{"name": "Ignar Frostblood", "lineage": "Ferrusk", "role": "Commander", "region": "vulcan_valley", "description": "Forged in gladiatorial pits, nearly indestructible."},
			{"name": "Zethar Iros", "lineage": "Dreamer", "role": "Commander", "region": "arcane_collapse", "description": "Star-navigator who manipulates space-time."},
			{"name": "Lysara Velnos", "lineage": "Corvian", "role": "Commander", "region": "the_darkness", "description": "Ascended through ruthless cunning and necromantic mastery."},
			{"name": "Cassia Serael", "lineage": "Obsidian Seraph", "role": "Commander", "region": "crypt_at_end_of_valley", "description": "Radiant figure with divine clarity, a living verdict."}
		],
		"division_heads": [
			{"name": "Lucan Ferris", "lineage": "Arcanite Human", "role": "Head of Artifacts Division", "region": "lower_forty", "description": "Master of arcane engineering and artifact stabilization."},
			{"name": "Esme Nightveil", "lineage": "Shadewretch", "role": "Head of Entities Division", "region": "lower_forty", "description": "Void-touched enchantress, foremost entity expert."}
		],
		"specialists": [
			{"name": "Dr. Amara Kelzen", "lineage": "Arcanite Human", "role": "Specialist", "region": "house_of_arachana", "description": "Technomagical biologist mastering venomous entities."},
			{"name": "Rorek Stoneshield", "lineage": "Ferrusk", "role": "Specialist", "region": "kingdom_of_qunorum", "description": "Former defender, tactical expertise in arcane neutralization."},
			{"name": "Vylian Darithar", "lineage": "Elf", "role": "Specialist", "region": "wilds_of_endero", "description": "Ranger with deep beast/nature connection."},
			{"name": "Shira Leafshadow", "lineage": "Vulpin", "role": "Specialist", "region": "forest_of_subeden", "description": "Druidic protector with agility and illusion magic."},
			{"name": "Seraphis Moonshade", "lineage": "Shardwraith", "role": "Specialist", "region": "pharaohs_den", "description": "Former cultist turned necromantic expert."},
			{"name": "Kelvor Dharkris", "lineage": "Shadewretch", "role": "Specialist", "region": "the_darkness", "description": "Uses void-touched lineage to manipulate shadows."},
			{"name": "Professor Daren Invesh", "lineage": "Dreamer", "role": "Specialist", "region": "upper_forty", "description": "Brilliant technomancer interfacing with arcane tech."},
			{"name": "Horgrim Ironclad", "lineage": "Ferrusk", "role": "Specialist", "region": "lower_forty", "description": "Master engineer of industrial arcane hazards."},
			{"name": "Dr. Talura Inox", "lineage": "Abyssari", "role": "Specialist", "region": "depths_of_denorim", "description": "Marine biologist communicating with aquatic anomalies."},
			{"name": "Nethar Vex", "lineage": "Dreamer", "role": "Specialist", "region": "moroboros", "description": "Rogue scholar stabilizing chaotic zones."},
			{"name": "Inquisitor Alistra", "lineage": "Boreal Human", "role": "Specialist", "region": "sacral_separation", "description": "Devout enforcer of interplanar law."},
			{"name": "Zariel Flamebrand", "lineage": "Ashenborn", "role": "Specialist", "region": "infernal_machine", "description": "Former infernal general controlling fire magic."},
			{"name": "Gorath Strongarm", "lineage": "Ferrusk", "role": "Specialist", "region": "vulcan_valley", "description": "Titan-souled warrior facing colossal threats."},
			{"name": "Darius Velcor", "lineage": "Arcanite Human", "role": "Specialist", "region": "mortal_arena", "description": "Famed gladiator containing magical champions."},
			{"name": "Zaira Thelemis", "lineage": "Dreamer", "role": "Specialist", "region": "beating_heart_of_the_void", "description": "Master illusionist manipulating thought-based anomalies."},
			{"name": "Velka Shadowsworn", "lineage": "Parallax Watchers", "role": "Specialist", "region": "west_end_gullet", "description": "Shadowmancer navigating reality distortions."},
			{"name": "Morvan Harrow", "lineage": "Shadewretch", "role": "Specialist", "region": "corrupted_marshes", "description": "Former servant of the lich, now contains necrotic corruption."},
			{"name": "Kraven Thorn", "lineage": "Shadewretch", "role": "Specialist", "region": "spindle_yorks_schism", "description": "Former smuggler with dimensional awareness."},
			{"name": "Malikai Greymoor", "lineage": "Tombwalker", "role": "Specialist", "region": "crypt_at_end_of_valley", "description": "Self-made lich controlling death magic."},
			{"name": "Aristelle Vox", "lineage": "Arcanite Human", "role": "Specialist", "region": "land_of_tomorrow", "description": "Scholar channeling divine and arcane energies."},
			{"name": "Viran Dawnspire", "lineage": "Glimmerfolk", "role": "Specialist", "region": "city_of_eternal_light", "description": "Guardian with radiant power and divine insight."},
			{"name": "High Priestess Serafina", "lineage": "Arcanite Human", "role": "Specialist", "region": "hallowed_sacrament", "description": "Revered cleric with ritual precision."}
		],
		"apprentices": [
			{"name": "Talia Auren", "lineage": "Arcanite Human", "role": "Apprentice", "region": "house_of_arachana", "description": "Studies venom manipulation under Dr. Kelzen."},
			{"name": "Korik Blackstone", "lineage": "Ferrusk", "role": "Apprentice", "region": "kingdom_of_qunorum", "description": "Warrior apprenticed to Rorek Stoneshield."},
			{"name": "Zanathor Greymane", "lineage": "Vulpin", "role": "Apprentice", "region": "wilds_of_endero", "description": "Raised by druids, bonds with beasts of Endero."},
			{"name": "Evelyn Mistwood", "lineage": "Elf", "role": "Apprentice", "region": "forest_of_subeden", "description": "Quick-witted archer with forest-born stealth."},
			{"name": "Ralos Venir", "lineage": "Shadewretch", "role": "Apprentice", "region": "pharaohs_den", "description": "Former graverobber seeking redemption."},
			{"name": "Nylira Darkveil", "lineage": "Felinar", "role": "Apprentice", "region": "the_darkness", "description": "Up-and-coming shadowmancer."},
			{"name": "Lex Braven", "lineage": "Dreamer", "role": "Apprentice", "region": "upper_forty", "description": "Genius inventor stabilizing magical disruptions."},
			{"name": "Garrek Thalron", "lineage": "Ferrusk", "role": "Apprentice", "region": "lower_forty", "description": "Burly blacksmith with mechanical insight."},
			{"name": "Mira Delvos", "lineage": "Abyssari", "role": "Apprentice", "region": "depths_of_denorim", "description": "Skilled swimmer assisting deep-sea research."},
			{"name": "Thalia Syren", "lineage": "Dreamer", "role": "Apprentice", "region": "moroboros", "description": "Studies warped magic and psychic anomalies."},
			{"name": "Gareth Volven", "lineage": "Boreal Human", "role": "Apprentice", "region": "sacral_separation", "description": "Inquisitor-in-training with planar endurance."},
			{"name": "Brogar Flamefist", "lineage": "Ferrusk", "role": "Apprentice", "region": "vulcan_valley", "description": "Young gladiator with fire resistance."},
			{"name": "Drayven Kane", "lineage": "Arcanite Human", "role": "Apprentice", "region": "mortal_arena", "description": "Rising star honing combat and containment."},
			{"name": "Valen Arclight", "lineage": "Dreamer", "role": "Apprentice", "region": "beating_heart_of_the_void", "description": "Talented illusionist with surreal magic control."},
			{"name": "Jorin Blackcloak", "lineage": "Twilightkin", "role": "Apprentice", "region": "west_end_gullet", "description": "Stealthy rogue detecting reality distortions."},
			{"name": "Eira Thorne", "lineage": "Gravetouched", "role": "Apprentice", "region": "corrupted_marshes", "description": "Masters necromantic containment."},
			{"name": "Soren Bloodbane", "lineage": "Umbrawyrm", "role": "Apprentice", "region": "spindle_yorks_schism", "description": "Former spy tracking magical anomalies."},
			{"name": "Lydia Darkspire", "lineage": "Tombwalker", "role": "Apprentice", "region": "crypt_at_end_of_valley", "description": "Novice necromancer, guardian of cryptic energies."},
			{"name": "Theron Vox", "lineage": "Obsidian Seraph", "role": "Apprentice", "region": "land_of_tomorrow", "description": "Trains in celestial magic to safeguard the future."},
			{"name": "Silas Morningstar", "lineage": "Glimmerfolk", "role": "Apprentice", "region": "city_of_eternal_light", "description": "Studies radiant magic."}
		],
		"field_agents": [
			{"name": "Maka Venomfang", "lineage": "Bilecrawler", "role": "Specialist", "region": "house_of_arachana", "description": "Field agent specializing in venomous entities."},
			{"name": "Kess Webweaver", "lineage": "Beetlefolk", "role": "Apprentice", "region": "house_of_arachana", "description": "Field agent in training for arachnid containment."},
			{"name": "Tula Silkspinner", "lineage": "Arachnid-Touched", "role": "Initiate", "region": "house_of_arachana", "description": "Field initiate learning from experienced agents."},
			{"name": "Brennor Shieldwall", "lineage": "Ferrusk", "role": "Specialist", "region": "kingdom_of_qunorum", "description": "Field specialist in defensive containment tactics."},
			{"name": "Kyn Stonefist", "lineage": "Dwarven Descendant", "role": "Apprentice", "region": "kingdom_of_qunorum", "description": "Field apprentice training in structural magic."},
			{"name": "Torvik Forgeborn", "lineage": "Boreal Human", "role": "Initiate", "region": "kingdom_of_qunorum", "description": "Field initiate with forging expertise."},
			{"name": "Kieran Pathfinder", "lineage": "Elf", "role": "Specialist", "region": "wilds_of_endero", "description": "Field specialist navigating wild terrain and creatures."},
			{"name": "Raska Wolfrunner", "lineage": "Vulpin", "role": "Apprentice", "region": "wilds_of_endero", "description": "Field apprentice bonding with wild beasts."},
			{"name": "Thorne Beastwhisperer", "lineage": "Druid-Blooded", "role": "Initiate", "region": "wilds_of_endero", "description": "Field initiate with animal communication."},
			{"name": "Zara Greenroot", "lineage": "Elf", "role": "Specialist", "region": "forest_of_subeden", "description": "Field specialist protecting sacred groves."},
			{"name": "Verrin Sulaf", "lineage": "Vulpin", "role": "Apprentice", "region": "forest_of_subeden", "description": "Field apprentice training in forest magic."},
			{"name": "Dellan Bramblefoot", "lineage": "Boreal Human", "role": "Initiate", "region": "forest_of_subeden", "description": "Field initiate learning druidic ways."},
			{"name": "Kael Icevein", "lineage": "Frostborn", "role": "Specialist", "region": "argent_hall", "description": "Field specialist handling cryogenic anomalies."},
			{"name": "Lira Snowstep", "lineage": "Glaceari", "role": "Apprentice", "region": "argent_hall", "description": "Field apprentice trained in ice magic containment."},
			{"name": "Bren Hollowgale", "lineage": "Nimbari", "role": "Initiate", "region": "argent_hall", "description": "Field initiate with wind magic affinity."},
			{"name": "Karesh Deathwhisper", "lineage": "Tombwalker", "role": "Specialist", "region": "pharaohs_den", "description": "Field specialist in undead containment and binding."},
			{"name": "Nethys Cursebreaker", "lineage": "Mummy-Touched", "role": "Apprentice", "region": "pharaohs_den", "description": "Field apprentice breaking curse mechanisms."},
			{"name": "Zarath Graveguard", "lineage": "Shade-Touched", "role": "Initiate", "region": "pharaohs_den", "description": "Field initiate protecting against grave disturbances."}
		]
	}

static func get_acf_agents_for_region(region_key: String) -> Array:
	var all_agents = []
	var hierarchy = get_acf_hierarchy()

	# Collect from all hierarchy levels
	for level_key in hierarchy.keys():
		var level_npcs = hierarchy[level_key]
		if level_npcs is Array:
			for npc in level_npcs:
				if npc.get("region") == region_key:
					all_agents.append(npc)

	return all_agents

static func get_faction_for_region(region_key: String) -> Dictionary:
	var region_faction_map = {
		"upper_forty": ["Silver Serpents", "Arcane Containment Foundation"],
		"lower_forty": ["Arcane Containment Foundation"],
		"kingdom_of_qunorum": ["Arcane Containment Foundation"],
		"house_of_arachana": ["Arcane Containment Foundation"],
		"wilds_of_endero": ["Arcane Containment Foundation"],
		"forest_of_subeden": ["The Circle of the Verdant Oak"],
		"eternal_library": ["The Scholars of the Eternal Library"],
		"mortal_arena": ["The Order of the Crimson Blade"],
		"pharaohs_den": ["Arcane Containment Foundation"],
		"corrupted_marshes": ["Arcane Containment Foundation"],
		"spindle_yorks_schism": ["Arcane Containment Foundation"],
		"crypt_at_end_of_valley": ["Arcane Containment Foundation"],
		"argent_hall": ["Arcane Containment Foundation"],
		"sacral_separation": ["Arcane Containment Foundation"],
		"infernal_machine": ["The FlameWardens"],
		"depths_of_denorim": ["Arcane Containment Foundation"],
		"moroboros": ["Arcane Containment Foundation"],
		"gloamfen_hollow": ["Arcane Containment Foundation"],
		"vulcan_valley": ["The Iron Legion", "The FlameWardens"],
		"lito": ["Arcane Containment Foundation"],
		"west_end_gullet": ["The Guild of Shadows"],
		"cradling_depths": ["Arcane Containment Foundation"],
		"city_of_eternal_light": ["The Order of the Golden Dawn"],
		"hallowed_sacrament": ["Arcane Containment Foundation"],
		"land_of_tomorrow": ["Arcane Containment Foundation"],
		"beating_heart_of_the_void": ["Arcane Containment Foundation"],
		"the_darkness": ["The Guild of Shadows"],
		"arcane_collapse": ["The Storm Walkers"]
	}

	# Get faction names for this region
	var faction_names = region_faction_map.get(region_key, ["Arcane Containment Foundation"])

	# Return first faction's full dictionary
	var all_factions = get_factions()
	for faction in all_factions:
		if faction["name"] == faction_names[0]:
			return faction

	# Fallback to ACF if not found
	for faction in all_factions:
		if faction["name"] == "Arcane Containment Foundation":
			return faction

	return {}

## Convert a display subregion name (e.g. "Upper Forty") to a region key (e.g. "upper_forty").
static func subregion_to_key(subregion: String) -> String:
	var lookup: Dictionary = {
		"Upper Forty": "upper_forty",
		"Lower Forty": "lower_forty",
		"Kingdom of Qunorum": "kingdom_of_qunorum",
		"House of Arachana": "house_of_arachana",
		"Wilds of Endero": "wilds_of_endero",
		"Forest of SubEden": "forest_of_subeden",
		"Eternal Library": "eternal_library",
		"Mortal Arena": "mortal_arena",
		"Pharaoh's Den": "pharaohs_den",
		"Corrupted Marshes": "corrupted_marshes",
		"Spindle York's Schism": "spindle_yorks_schism",
		"Crypt at End of Valley": "crypt_at_end_of_valley",
		"Argent Hall": "argent_hall",
		"Sacral Separation": "sacral_separation",
		"Infernal Machine": "infernal_machine",
		"Depths of Denorim": "depths_of_denorim",
		"Moroboros": "moroboros",
		"Gloamfen Hollow": "gloamfen_hollow",
		"Vulcan Valley": "vulcan_valley",
		"L.I.T.O.": "lito",
		"West End Gullet": "west_end_gullet",
		"Cradling Depths": "cradling_depths",
		"The Cradling Depths": "cradling_depths",
		"City of Eternal Light": "city_of_eternal_light",
		"Hallowed Sacrament": "hallowed_sacrament",
		"The Hallowed Sacrament": "hallowed_sacrament",
		"Land of Tomorrow": "land_of_tomorrow",
		"Beating Heart of The Void": "beating_heart_of_the_void",
		"The Darkness": "the_darkness",
		"Arcane Collapse": "arcane_collapse",
	}
	return lookup.get(subregion, subregion.to_snake_case())
